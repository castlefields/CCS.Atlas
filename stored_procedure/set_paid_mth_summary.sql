SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[set_paid_mth_summary]
    @TruncateFirst BIT = 0  -- Set to 1 to truncate the table before inserting
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @EndTime DATETIME;
    DECLARE @RowCount INT = 0;
    DECLARE @PreviousYearMonth VARCHAR(7);
    DECLARE @LogMessage NVARCHAR(MAX) = '';
    DECLARE @ExecutionStatus VARCHAR(20) = 'Success';
    DECLARE @ApplicationName VARCHAR(50) = 'Database.StoredProcedure.set_paid_mth_summary';
    DECLARE @HasFPP BIT = 0; -- Flag to track if FPP exists
    
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
    
    -- Check if source data exists for the previous month
    IF NOT EXISTS (SELECT 1 FROM dbo.paid_mth WHERE year_month = @PreviousYearMonth)
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
    IF EXISTS (SELECT 1 FROM dbo.paid_mth_summary WHERE year_month = @PreviousYearMonth) AND @TruncateFirst = 0
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
    
    -- Log processing start
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
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Optionally truncate the table first
        IF @TruncateFirst = 1
        BEGIN
            TRUNCATE TABLE [dbo].[paid_mth_summary];
            
            SET @LogMessage = 'Table [dbo].[paid_mth_summary] truncated.';
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
        ELSE
        BEGIN
            -- Delete only the previous month data for targeted update
            DELETE FROM [dbo].[paid_mth_summary] 
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
        
        -- Insert the summarized data for the previous month only
        INSERT INTO [dbo].[paid_mth_summary]
        (
            [facility_used_by_id],
            [facility_used_by_legal_name],
            [facility_used_by_trading_style],
            [facility_used_by_report_group_id],
            [account_report_group],
            [facility_used_by_business_manager_email],
            [facility_code],
            [product_code],
            [funding_option_uc],
            [advance_count],
            [advance_total],
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
            p.facility_code,
            p.product_code,
            lpc.funding_option_uc,
            COUNT(p.advance) AS advance_count,
            SUM(p.advance) AS advance_total,
            p.year_month,
            GETDATE() -- Current timestamp
        FROM dbo.paid_mth p
        INNER JOIN dbo.account a ON p.facility_code = a.facility_code
        INNER JOIN dbo.lender_product_code lpc ON p.product_code = lpc.product_code
        WHERE p.year_month = @PreviousYearMonth -- Filter for previous month only
        GROUP BY
            p.facility_code,
            p.product_code,
            a.facility_used_by_id,
            a.facility_used_by_report_group_id,
            a.account_report_group,
            a.facility_used_by_legal_name,
            a.facility_used_by_trading_style,
            a.facility_used_by_business_manager_email,
            lpc.funding_option_uc,
            p.year_month;
            
        SET @RowCount = @@ROWCOUNT;
        
        COMMIT TRANSACTION;
        
        SET @EndTime = GETDATE();
        
        -- Check if any rows with product_code = 'FPP' exist in the paid_mth_summary table for the specific month
		IF EXISTS (SELECT 1 FROM dbo.paid_mth_summary 
				   WHERE product_code = 'FPP' 
				   AND year_month = @PreviousYearMonth)
		BEGIN
			SET @HasFPP = 1;  -- FPP exists for this month
		END
        
        -- Add execution summary to log message based on FPP existence
        IF @HasFPP = 1
        BEGIN
            SET @LogMessage = 'set_paid_mth_summary first phase completed successfully. Rows inserted for ' + 
                           @PreviousYearMonth + ': ' + CAST(@RowCount AS VARCHAR(20)) + 
                           '. Execution time: ' + CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(10)) + ' seconds';
        END
        ELSE
        BEGIN
            SET @LogMessage = 'set_paid_mth_summary second phase completed successfully. Rows inserted for ' + 
                           @PreviousYearMonth + ': ' + CAST(@RowCount AS VARCHAR(20)) + 
                           '. Execution time: ' + CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(10)) + ' seconds';
        END
        
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
        
        -- Log error to the log table
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
