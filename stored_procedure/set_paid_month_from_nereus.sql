SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[set_paid_month_from_nereus]
    @schema_name NVARCHAR(50) = 'dbo' -- Optional: Default schema is dbo
AS
BEGIN
    -- Log the start of the procedure
    INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
    VALUES ('Database.StoredProcedure.set_paid_month_from_nereus', 'Information', 'Procedure started', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

    SET NOCOUNT ON;

    BEGIN TRY
        -- Declare variables
        DECLARE @tableName NVARCHAR(MAX) = QUOTENAME(@schema_name) + '.' + QUOTENAME('paid_mth');
        DECLARE @sql NVARCHAR(MAX);

        -- Log the start of data processing
        INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
        VALUES ('Database.StoredProcedure.set_paid_month_from_nereus', 'Information', 'Starting data processing', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

        -- Create a temporary table to hold the new data
        CREATE TABLE #temp_paid_mth (
            id INT NOT NULL,
            lender_id TINYINT NULL,
            facility_code VARCHAR(15) NULL,
            upload_legal_name NVARCHAR(50) NULL,
            product_code NVARCHAR(15) NULL,
            defer_by INT NULL,
            apr DECIMAL(18, 10) NULL,
            term INT NULL,
            advance DECIMAL(10, 0) NULL,
            date DATETIME NULL,
            return_rate DECIMAL(10, 4) NULL,
            month INT NULL,
            year INT NULL,
            upload_date DATETIME NULL
        );

        -- Insert data into the temporary table
        SET @sql = 'INSERT INTO #temp_paid_mth (
                        id,
                        lender_id,
                        facility_code,
                        upload_legal_name,
                        product_code,
                        defer_by,
                        apr,
                        term,
                        advance,
                        date,
                        return_rate,
                        month,
                        year,
                        upload_date
                    )
                    SELECT
                        PK,
                        lenderID,
                        branchNumber,
                        branchName,
                        product,
                        defer,
                        rate,
                        term,
                        advance,
                        decDate,
                        commPercent,
                        month,
                        year,
                        importDate
                    FROM [dbo].[tb_paids]';
        EXEC sp_executesql @sql;

        -- Check for rows to update and print the ID
        DECLARE @UpdateCheckSQL NVARCHAR(MAX);
        SET @UpdateCheckSQL = '
        DECLARE @updatingId INT;
        IF EXISTS (SELECT 1 FROM #temp_paid_mth t INNER JOIN ' + @tableName + ' am ON am.id = t.id WHERE (
            am.lender_id <> t.lender_id OR
            am.facility_code <> t.facility_code OR
            am.upload_legal_name <> t.upload_legal_name OR
            am.product_code <> t.product_code OR
            am.defer_by <> t.defer_by OR
            am.apr <> t.apr OR
            am.term <> t.term OR
            am.advance <> t.advance OR
            am.date <> t.date OR
            am.return_rate <> t.return_rate OR
            am.month <> t.month OR
            am.year <> t.year OR
            am.upload_date <> t.upload_date
        ))
        BEGIN
            SELECT TOP 1 @updatingId = id FROM #temp_paid_mth;
            PRINT ''Updating ID: '' + CAST(@updatingId AS VARCHAR(10));
        END';
        EXEC sp_executesql @UpdateCheckSQL;

        -- Update existing rows in paid_mth where ID matches but upload_date does not
        DECLARE @UpdateSQL NVARCHAR(MAX);
        SET @UpdateSQL = '
        UPDATE ' + @tableName + '
        SET
            lender_id = t.lender_id,
            facility_code = t.facility_code,
            upload_legal_name = t.upload_legal_name,
            product_code = t.product_code,
            defer_by = t.defer_by,
            apr = t.apr,
            term = t.term,
            advance = t.advance,
            date = t.date,
            return_rate = t.return_rate,
            month = t.month,
            year = t.year,
            upload_date = t.upload_date
        FROM #temp_paid_mth t
        WHERE ' + @tableName + '.id = t.id
        AND (
            ' + @tableName + '.lender_id <> t.lender_id OR
            ' + @tableName + '.facility_code <> t.facility_code OR
            ' + @tableName + '.upload_legal_name <> t.upload_legal_name OR
            ' + @tableName + '.product_code <> t.product_code OR
            ' + @tableName + '.defer_by <> t.defer_by OR
            ' + @tableName + '.apr <> t.apr OR
            ' + @tableName + '.term <> t.term OR
            ' + @tableName + '.advance <> t.advance OR
            ' + @tableName + '.date <> t.date OR
            ' + @tableName + '.return_rate <> t.return_rate OR
            ' + @tableName + '.month <> t.month OR
            ' + @tableName + '.year <> t.year OR
            ' + @tableName + '.upload_date <> t.upload_date
        );';

        PRINT 'Table Name: ' + @tableName;
        PRINT 'Update SQL: ' + @UpdateSQL;

        EXEC sp_executesql @UpdateSQL;

        DECLARE @rowsUpdated INT = @@ROWCOUNT;

        PRINT 'Rows Updated: ' + CAST(@rowsUpdated AS VARCHAR(10));

        IF @rowsUpdated = 0
            INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
            VALUES ('Database.StoredProcedure.set_paid_month_from_nereus', 'Information', 'No updates required in paid_mth', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));
        ELSE
            INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
            VALUES ('Database.StoredProcedure.set_paid_month_from_nereus', 'Information', FORMATMESSAGE('%i rows updated in paid_mth', @rowsUpdated), GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

        -- Insert new rows from the temporary table into paid_mth where ID does not exist
        DECLARE @InsertSQL NVARCHAR(MAX);
        SET @InsertSQL = '
        DECLARE @insertingId INT;
        IF EXISTS (SELECT 1 FROM #temp_paid_mth t WHERE NOT EXISTS (SELECT 1 FROM ' + @tableName + ' WHERE id = t.id))
        BEGIN
            SELECT TOP 1 @insertingId = id FROM #temp_paid_mth;
            PRINT ''Inserting ID: '' + CAST(@insertingId AS VARCHAR(10));
        END

        INSERT INTO ' + @tableName + ' (
            id,
            lender_id,
            facility_code,
            upload_legal_name,
            product_code,
            defer_by,
            apr,
            term,
            advance,
            date,
            return_rate,
            month,
            year,
            upload_date
        )
        SELECT
            t.id,
            t.lender_id,
            t.facility_code,
            t.upload_legal_name,
            t.product_code,
            t.defer_by,
            t.apr,
            t.term,
            t.advance,
            t.date,
            t.return_rate,
            t.month,
            t.year,
            t.upload_date
        FROM #temp_paid_mth t
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
            VALUES ('Database.StoredProcedure.set_paid_month_from_nereus', 'Information', 'No new data found for paid_mth', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));
        ELSE
            INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
            VALUES ('Database.StoredProcedure.set_paid_month_from_nereus', 'Information', FORMATMESSAGE('%i rows inserted into paid_mth', @rowsInserted), GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

        -- Drop the temporary table
        DROP TABLE #temp_paid_mth;

        -- Log the end of data processing
        INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
        VALUES ('Database.StoredProcedure.set_paid_month_from_nereus', 'Information', 'Data processing completed', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

        -- Report success
        DECLARE @RecordCount INT;
        SET @sql = 'SELECT @RecordCountOUT = COUNT(*) FROM ' + @tableName;
        EXEC sp_executesql @sql, N'@RecordCountOUT INT OUTPUT', @RecordCountOUT = @RecordCount OUTPUT;

        PRINT 'Successfully refreshed paid_mth table with ' +
              CAST(@RecordCount AS VARCHAR(20)) +
              ' records.';
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        -- Log the error
        INSERT INTO dbo.log_global (applicationName, logType, message, innerExceptionMessage, dateCreated, day, month, year)
        VALUES ('Database.StoredProcedure.set_paid_month_from_nereus', 'Error', @ErrorMessage, ERROR_MESSAGE(), GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH

    -- Log the end of the procedure
    INSERT INTO dbo.log_global (applicationName, logType, message, dateCreated, day, month, year)
    VALUES ('Database.StoredProcedure.set_paid_month_from_nereus', 'Information', 'Procedure finished', GETDATE(), DATEPART(dayofyear, GETDATE()), DATEPART(month, GETDATE()), DATEPART(year, GETDATE()));
END
GO
