SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Create the stored procedure
ALTER PROCEDURE [dbo].[set_application_mth_summary]
    @TruncateFirst BIT = 0,        -- Set to 1 to truncate the table before inserting
    @ProcessAllMonths BIT = 0      -- Set to 1 to process all months instead of just previous month
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @EndTime DATETIME;
    DECLARE @RowCount INT = 0;
    DECLARE @PreviousYearMonth VARCHAR(7);
    DECLARE @LogMessage NVARCHAR(MAX) = '';
    DECLARE @ExecutionStatus VARCHAR(20) = 'Success';
    DECLARE @ApplicationName VARCHAR(50) = 'Database.StoredProcedure.set_application_mth_summary';
    
    -- Calculate previous month's year_month in YYYY-MM format
    SET @PreviousYearMonth = FORMAT(DATEADD(MONTH, -1, GETDATE()), 'yyyy-MM');
    
    -- Begin building log message
    SET @LogMessage = 'Execution started at ' + CONVERT(VARCHAR, @StartTime, 120);

	-- Log start of execution
	INSERT INTO [dbo].[log_global] (
		[applicationName], 
		[logType], 
		[message],
		[dateCreated],
		[day],
		[month],
		[year]
	)
	VALUES (
		@ApplicationName, 
		'Information', 
		@LogMessage,
		GETDATE(),
		DAY(GETDATE()),
		MONTH(GETDATE()),
		YEAR(GETDATE())
	);
    
    -- For processing all months, check if any source data exists
    IF @ProcessAllMonths = 1
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.application_mth)
        BEGIN
            SET @LogMessage = 'No source data found in application_mth table. Procedure execution canceled.';
            SET @ExecutionStatus = 'Warning';
            
            -- Log to the local log table
            INSERT INTO [dbo].[log_global] (
                [applicationName], 
                [logType], 
                [message],
                [dateCreated],
                [day],
                [month],
                [year]
            )
            VALUES (
                @ApplicationName, 
                @ExecutionStatus, 
                @LogMessage,
                GETDATE(),
                DAY(GETDATE()),
                MONTH(GETDATE()),
                YEAR(GETDATE())
            );
            
            PRINT @LogMessage;
            RETURN; -- Exit the procedure if no source data exists
        END
        
        SET @LogMessage = 'Processing ALL available months.';
        SET @ExecutionStatus = 'Information';
        
        -- Log information message
        INSERT INTO [dbo].[log_global] (
            [applicationName], 
            [logType], 
            [message],
            [dateCreated],
            [day],
            [month],
            [year]
        )
        VALUES (
            @ApplicationName, 
            @ExecutionStatus, 
            @LogMessage,
            GETDATE(),
            DAY(GETDATE()),
            MONTH(GETDATE()),
            YEAR(GETDATE())
        );
        
        PRINT @LogMessage;
    END
    ELSE -- For processing just the previous month
    BEGIN
        -- Check if source data exists for the previous month
        IF NOT EXISTS (SELECT 1 FROM dbo.application_mth WHERE year_month = @PreviousYearMonth)
        BEGIN
            SET @LogMessage = 'No source data found for previous month: ' + @PreviousYearMonth + '. Procedure execution canceled.';
            SET @ExecutionStatus = 'Warning';
            
            -- Log to the log table
            INSERT INTO [dbo].[log_global] (
                [applicationName], 
                [logType], 
                [message],
                [dateCreated],
                [day],
                [month],
                [year]
            )
            VALUES (
                @ApplicationName, 
                @ExecutionStatus, 
                @LogMessage,
                GETDATE(),
                DAY(GETDATE()),
                MONTH(GETDATE()),
                YEAR(GETDATE())
            );
            
            PRINT @LogMessage;
            RETURN; -- Exit the procedure if no source data exists
        END
        
        -- Check if summary data already exists for the previous month
        IF EXISTS (SELECT 1 FROM dbo.application_mth_summary WHERE year_month = @PreviousYearMonth) AND @TruncateFirst = 0
        BEGIN
            SET @LogMessage = 'Summary data already exists for previous month: ' + @PreviousYearMonth;
            SET @ExecutionStatus = 'Information';
            
            -- Log to the log table
            INSERT INTO [dbo].[log_global] (
                [applicationName], 
                [logType], 
                [message],
                [dateCreated],
                [day],
                [month],
                [year]
            )
            VALUES (
                @ApplicationName, 
                @ExecutionStatus, 
                @LogMessage,
                GETDATE(),
                DAY(GETDATE()),
                MONTH(GETDATE()),
                YEAR(GETDATE())
            );
            
            PRINT @LogMessage;
            RETURN; -- Exit if data already exists in the summary table
        END
        
        SET @LogMessage = 'Processing data for previous month: ' + @PreviousYearMonth;
        SET @ExecutionStatus = 'Information';
        
        -- Log information message
        INSERT INTO [dbo].[log_global] (
            [applicationName], 
            [logType], 
            [message],
            [dateCreated],
            [day],
            [month],
            [year]
        )
        VALUES (
            @ApplicationName, 
            @ExecutionStatus, 
            @LogMessage,
            GETDATE(),
            DAY(GETDATE()),
            MONTH(GETDATE()),
            YEAR(GETDATE())
        );
        
        PRINT @LogMessage;
    END
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Optionally truncate the table first
        IF @TruncateFirst = 1
        BEGIN
            TRUNCATE TABLE [dbo].[application_mth_summary];
            
            SET @LogMessage = 'Table [dbo].[application_mth_summary] truncated.';
            SET @ExecutionStatus = 'Information';
            
            -- Log truncate action
            INSERT INTO [dbo].[log_global] (
                [applicationName], 
                [logType], 
                [message],
                [dateCreated],
                [day],
                [month],
                [year]
            )
            VALUES (
                @ApplicationName, 
                @ExecutionStatus, 
                @LogMessage,
                GETDATE(),
                DAY(GETDATE()),
                MONTH(GETDATE()),
                YEAR(GETDATE())
            );
            
            PRINT @LogMessage;
        END
        ELSE IF @ProcessAllMonths = 0 -- Only delete previous month if not processing all months
        BEGIN
            -- Delete only the previous month data for targeted update
            DELETE FROM [dbo].[application_mth_summary] 
            WHERE [year_month] = @PreviousYearMonth;
            
            SET @LogMessage = 'Deleted existing data for year_month: ' + @PreviousYearMonth;
            SET @ExecutionStatus = 'Information';
            
            -- Log delete action
            INSERT INTO [dbo].[log_global] (
                [applicationName], 
                [logType], 
                [message],
                [dateCreated],
                [day],
                [month],
                [year]
            )
            VALUES (
                @ApplicationName, 
                @ExecutionStatus, 
                @LogMessage,
                GETDATE(),
                DAY(GETDATE()),
                MONTH(GETDATE()),
                YEAR(GETDATE())
            );
            
            PRINT @LogMessage;
        END
        
        -- Insert the summarized data 
        INSERT INTO [dbo].[application_mth_summary]
        (
            [facility_used_by_id],
            [facility_used_by_legal_name],
            [facility_used_by_trading_style],
            [facility_used_by_report_group_id],
            [account_report_group],
            [facility_used_by_business_manager_email],
            [facility_code],
            [accept_count],
            [accept_total],
            [decline_count],
            [decline_total],
            [pending_count],
            [pending_total],
            [year_month],
            [last_updated]
        )
        SELECT
            a.facility_used_by_id,
            a.facility_used_by_legal_name,
            a.facility_used_by_trading_style,
            a.facility_used_by_report_group_id,
            a.account_report_group,
            a.facility_used_by_business_manager_email,
            app.facility_code,
            app.accept AS accept_count,
            SUM(ISNULL(app.accept_val, 0)) AS accept_total,
            COUNT(app.decline) AS decline_count,
            SUM(ISNULL(app.decline_val, 0)) AS decline_total,
            COUNT(app.pending) AS pending_count,
            SUM(ISNULL(app.pending_val, 0)) AS pending_total,
            app.year_month,
            GETDATE() -- Current timestamp
        FROM dbo.application_mth app
        INNER JOIN dbo.account a ON app.facility_code = a.facility_code
        WHERE (@ProcessAllMonths = 1 OR app.year_month = @PreviousYearMonth) -- Filter by month only if not processing all
        GROUP BY
            app.facility_code,
            a.facility_used_by_id,
            a.facility_used_by_report_group_id,
            a.account_report_group,
            a.facility_used_by_legal_name,
            a.facility_used_by_trading_style,
            a.facility_used_by_business_manager_email,
            app.year_month;
            
        SET @RowCount = @@ROWCOUNT;
        
        COMMIT TRANSACTION;
        
        SET @EndTime = GETDATE();
        
        -- Add execution summary to log message
		SET @LogMessage = 'set_application_mth_summary completed successfully. Rows inserted: ' + CAST(@RowCount AS VARCHAR(20)) + 
                '. Execution time: ' + CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(10)) + ' seconds';

        SET @ExecutionStatus = 'Success';
        
        -- Print execution summary
        PRINT @LogMessage;
        
        -- Log successful execution to the log table
        INSERT INTO [dbo].[log_global] (
            [applicationName], 
            [logType], 
            [message],
            [dateCreated],
            [day],
            [month],
            [year]
        )
        VALUES (
            @ApplicationName, 
            @ExecutionStatus, 
            @LogMessage,
            GETDATE(),
            DAY(GETDATE()),
            MONTH(GETDATE()),
            YEAR(GETDATE())
        );
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SET @EndTime = GETDATE();
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        DECLARE @ErrorLine INT = ERROR_LINE();
        
        -- Create error log message
        SET @LogMessage = 'Error occurred at line ' + CAST(@ErrorLine AS VARCHAR) + ': ' + @ErrorMessage;
        SET @ExecutionStatus = 'Error';
        
        PRINT 'Error occurred: ' + @ErrorMessage;
        
        -- Log error to the local log table
        INSERT INTO [dbo].[log_global] (
            [applicationName], 
            [logType], 
            [message],
            [stackTrace],
            [dateCreated],
            [day],
            [month],
            [year]
        )
        VALUES (
            @ApplicationName, 
            @ExecutionStatus, 
            @LogMessage,
            'Error Line: ' + CAST(@ErrorLine AS VARCHAR) + ', Error Severity: ' + CAST(@ErrorSeverity AS VARCHAR) + ', Error State: ' + CAST(@ErrorState AS VARCHAR),
            GETDATE(),
            DAY(GETDATE()),
            MONTH(GETDATE()),
            YEAR(GETDATE())
        );
        
        -- Re-throw the error
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END
GO
