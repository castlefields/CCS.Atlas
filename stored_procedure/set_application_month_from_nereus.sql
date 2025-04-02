SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[set_application_month_from_nereus]
    @schema_name NVARCHAR(50) = 'dbo' -- Optional: Default schema is dbo
AS
BEGIN
    -- Log the start of the procedure
    INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
    VALUES ('Database.StoredProcedure.set_application_month_from_nereus', 'Information', 'Procedure started', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

    BEGIN TRY
        -- Declare variables for the table name
        DECLARE @tableName NVARCHAR(MAX);
        SET @tableName = QUOTENAME(@schema_name) + '.' + QUOTENAME('application_mth');

        -- Log the start of data processing
        INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
        VALUES ('Database.StoredProcedure.set_application_month_from_nereus', 'Information', 'Starting data processing', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

        -- Create a temporary table to hold the new data
        CREATE TABLE #temp_application_mth (
            id INT NOT NULL,
            lender_id TINYINT NULL,
            facility_code VARCHAR(15) NULL,
            upload_legal_name NVARCHAR(50) NULL,
            accept INT NULL,
            accept_val DECIMAL(10, 0) NULL,
            decline INT NULL,
            decline_val DECIMAL(10, 0) NULL,
            pending INT NULL,
            pending_val DECIMAL(10, 0) NULL,
            month INT NULL,
            year INT NULL,
            upload_date DATETIME NULL
        );

        -- Insert data into the temporary table
        INSERT INTO #temp_application_mth (
            id,
            lender_id,
            facility_code,
            upload_legal_name,
            accept,
            accept_val,
            decline,
            decline_val,
            pending,
            pending_val,
            month,
            year,
            upload_date
        )
        SELECT
            ID,
            lenderID,
            branchNumber,
            branchName,
            Accepts,
            AcceptsVal,
            Declines,
            DeclinesVal,
            Pending,
            PendingVal,
            month,
            year,
            importDate
        FROM [dbo].[apps];

        -- Update existing rows in application_mth where ID matches but upload_date does not
        DECLARE @UpdateSQL NVARCHAR(MAX);
        SET @UpdateSQL = '
        DECLARE @updatingId INT;

        IF EXISTS (SELECT 1 FROM #temp_application_mth t INNER JOIN ' + @tableName + ' am ON am.id = t.id WHERE (
            am.lender_id <> t.lender_id OR
            am.facility_code <> t.facility_code OR
            am.upload_legal_name <> t.upload_legal_name OR
            am.accept <> t.accept OR
            am.accept_val <> t.accept_val OR
            am.decline <> t.decline OR
            am.decline_val <> t.decline_val OR
            am.pending <> t.pending OR
            am.pending_val <> t.pending_val OR
            am.month <> t.month OR
            am.year <> t.year
        ))
        BEGIN
            SELECT TOP 1 @updatingId = id FROM #temp_application_mth;
            PRINT ''Updating ID: '' + CAST(@updatingId AS VARCHAR(10));
        END

        UPDATE ' + @tableName + '
        SET
            lender_id = t.lender_id,
            facility_code = t.facility_code,
            upload_legal_name = t.upload_legal_name,
            accept = t.accept,
            accept_val = t.accept_val,
            decline = t.decline,
            decline_val = t.decline_val,
            pending = t.pending,
            pending_val = t.pending_val,
            month = t.month,
            year = t.year,
            upload_date = t.upload_date
        FROM #temp_application_mth t
        WHERE ' + @tableName + '.id = t.id
        AND (
            ' + @tableName + '.lender_id <> t.lender_id OR
            ' + @tableName + '.facility_code <> t.facility_code OR
            ' + @tableName + '.upload_legal_name <> t.upload_legal_name OR
            ' + @tableName + '.accept <> t.accept OR
            ' + @tableName + '.accept_val <> t.accept_val OR
            ' + @tableName + '.decline <> t.decline OR
            ' + @tableName + '.decline_val <> t.decline_val OR
            ' + @tableName + '.pending <> t.pending OR
            ' + @tableName + '.pending_val <> t.pending_val OR
            ' + @tableName + '.month <> t.month OR
            ' + @tableName + '.year <> t.year
        );';

        PRINT 'Table Name: ' + @tableName;
        PRINT 'Update SQL: ' + @UpdateSQL;

        EXEC sp_executesql @UpdateSQL;

        DECLARE @rowsUpdated INT = @@ROWCOUNT;

        PRINT 'Rows Updated: ' + CAST(@rowsUpdated AS VARCHAR(10));

        IF @rowsUpdated = 0
            INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
            VALUES ('Database.StoredProcedure.set_application_month_from_nereus', 'Information', 'No updates required in application_mth', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));
        ELSE
            INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
            VALUES ('Database.StoredProcedure.set_application_month_from_nereus', 'Information', FORMATMESSAGE('%i rows updated in application_mth', @rowsUpdated), GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

        -- Insert new rows from the temporary table into application_mth where ID does not exist
        DECLARE @InsertSQL NVARCHAR(MAX);
        SET @InsertSQL = '
        DECLARE @insertingId INT;

        IF EXISTS (SELECT 1 FROM #temp_application_mth t WHERE NOT EXISTS (SELECT 1 FROM ' + @tableName + ' WHERE id = t.id))
        BEGIN
            SELECT TOP 1 @insertingId = id FROM #temp_application_mth;
            PRINT ''Inserting ID: '' + CAST(@insertingId AS VARCHAR(10));
        END

        INSERT INTO ' + @tableName + ' (
            id,
            lender_id,
            facility_code,
            upload_legal_name,
            accept,
            accept_val,
            decline,
            decline_val,
            pending,
            pending_val,
            month,
            year,
            upload_date
        )
        SELECT
            t.id,
            t.lender_id,
            t.facility_code,
            t.upload_legal_name,
            t.accept,
            t.accept_val,
            t.decline,
            t.decline_val,
            t.pending,
            t.pending_val,
            t.month,
            t.year,
            t.upload_date
        FROM #temp_application_mth t
        WHERE NOT EXISTS (
            SELECT 1
            FROM ' + @tableName + '
            WHERE id = t.id
        );';

        PRINT 'Table Name: ' + @tableName;
        PRINT 'Insert SQL: ' + @InsertSQL;

        EXEC sp_executesql @InsertSQL;

        DECLARE @rowsInserted INT = @@ROWCOUNT;

        PRINT 'Rows Inserted: ' + CAST(@rowsInserted AS VARCHAR(10));

        IF @rowsInserted = 0
            INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
            VALUES ('Database.StoredProcedure.set_application_month_from_nereus', 'Information', 'No new data found for application_mth', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));
        ELSE
            INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
            VALUES ('Database.StoredProcedure.set_application_month_from_nereus', 'Information', FORMATMESSAGE('%i rows inserted into application_mth', @rowsInserted), GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

        -- Drop the temporary table
        DROP TABLE #temp_application_mth;

        -- Log the end of data processing
        INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
        VALUES ('Database.StoredProcedure.set_application_month_from_nereus', 'Information', 'Data processing completed', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

    END TRY
    BEGIN CATCH
        -- Handle errors
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();

        -- Log the error
        INSERT INTO dbo.log_global (applicationName, logType, message, innerExceptionMessage, dateCreated, day, month, year)
        VALUES ('Database.StoredProcedure.set_application_month_from_nereus', 'Error', @ErrorMessage, ERROR_MESSAGE(), GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH

    -- Log the end of the procedure
    INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
    VALUES ('Database.StoredProcedure.set_application_month_from_nereus', 'Information', 'Procedure finished', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));
END
GO
GO
