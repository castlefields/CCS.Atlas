/****** Object:  StoredProcedure [dbo].[rpt_mth_account_ecof_application_paid]    Script Date: 01/04/2025 21:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_mth_account_ecof_application_paid]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    -- Optional filter for specific account
    @report_group_id UNIQUEIDENTIFIER = NULL,
    -- Optional filter for report group
    @facility_lender NVARCHAR(50) = NULL,
    -- Optional filter for specific lender
    @period NVARCHAR(10) = 'L12M',
    -- Optional period filter (L12M, P12M, C12M, or NULL for no filter)
    @group_by NVARCHAR(50) = 'year_month'
-- Optional group by column (year_month, year, month, quarter, year_quarter)
AS
BEGIN
    -- Validate parameters
    IF @period IS NOT NULL AND @period NOT IN ('L12M', 'P12M', 'C12M')
    BEGIN
        RAISERROR('Invalid @period parameter. Valid values are L12M, P12M, C12M, or NULL.', 16, 1)
        RETURN
    END

    IF @group_by NOT IN ('year_month', 'year', 'month', 'quarter', 'year_quarter')
    BEGIN
        RAISERROR('Invalid @group_by parameter. Valid values are year_month, year, month, quarter, year_quarter.', 16, 1)
        RETURN
    END

    -- Get filtered moments
    CREATE TABLE #FilteredMoments (
        year_month NVARCHAR(7),
        year INT,
        month INT,
        quarter INT,
        year_quarter NVARCHAR(7)
    );
    
    INSERT INTO #FilteredMoments
    EXEC dbo.rpt_get_filtered_moments @period;
    
    -- Get facilities for report
    CREATE TABLE #Facilities (
        facility_used_by_id UNIQUEIDENTIFIER,
        facility_used_by_name NVARCHAR(255)
    );
    
    INSERT INTO #Facilities
    EXEC dbo.rpt_get_facilities_for_report @facility_used_by_id, @report_group_id;
    
    -- Get budget data
    CREATE TABLE #Budget (
        year_month NVARCHAR(7),
        year INT,
        month INT,
        quarter INT,
        year_quarter NVARCHAR(7),
        facility_used_by_id UNIQUEIDENTIFIER,
        budget DECIMAL(18,2)
    );
    
    INSERT INTO #Budget
    EXEC dbo.rpt_get_budget_data 
        @facility_used_by_id,
        @report_group_id,
        @facility_lender;
    
    -- Get ECOF data
    CREATE TABLE #Ecof (
        year_month NVARCHAR(7),
        year INT,
        month INT,
        quarter INT,
        year_quarter NVARCHAR(7),
        facility_used_by_id UNIQUEIDENTIFIER,
        ecof_count INT,
        ecof_advance DECIMAL(18,2)
    );
    
    INSERT INTO #Ecof
    EXEC dbo.rpt_get_ecof_data 
        @facility_used_by_id,
        @report_group_id,
        @facility_lender;
    
    -- Get application data
    CREATE TABLE #Applications (
        year_month NVARCHAR(7),
        year INT,
        month INT,
        quarter INT,
        year_quarter NVARCHAR(7),
        facility_used_by_id UNIQUEIDENTIFIER,
        accept_val DECIMAL(18,2),
        accept INT,
        decline INT,
        pending INT
    );
    
    INSERT INTO #Applications
    EXEC dbo.rpt_get_application_data 
        @facility_used_by_id,
        @report_group_id,
        @facility_lender;
    
    -- Get paid data
    CREATE TABLE #Paids (
        year_month NVARCHAR(7),
        year INT,
        month INT,
        quarter INT,
        year_quarter NVARCHAR(7),
        facility_used_by_id UNIQUEIDENTIFIER,
        advance DECIMAL(18,2),
        advance_count INT,
        commission DECIMAL(18,2),
        commission_rate_avg DECIMAL(18,4)
    );
    
    INSERT INTO #Paids
    EXEC dbo.rpt_get_paid_data 
        @facility_used_by_id,
        @report_group_id,
        @facility_lender;
    
    -- Create final results table
    CREATE TABLE #Results (
        report_name NVARCHAR(255),
        moment NVARCHAR(7),
        ecof_count INT,
        ecof_advance DECIMAL(18,2),
        proposed_count INT,
        accept_count INT,
        accept_val DECIMAL(18,2),
        accept_avg DECIMAL(18,2),
        accept_rate DECIMAL(18,6),
        decline_count INT,
        pending_count INT,
        advance_count INT,
        advance_val DECIMAL(18,2),
        advance_avg DECIMAL(18,2),
        commission_val DECIMAL(18,2),
        commission_rate_avg DECIMAL(18,4),
        budget DECIMAL(18,2),
        budget_rate DECIMAL(18,6)
    );
    
    -- Build and execute the final results
    EXEC dbo.rpt_build_final_results 
        @facility_lender,
        @report_group_id,
        @group_by,
        @Results = '#Results' -- Output parameter that will hold the results table name
    
    -- Select final results with appropriate filtering
    IF @report_group_id IS NOT NULL
    BEGIN
        -- For report_group_id queries, filter out empty rows
        SELECT
            report_name,
            moment,
            ecof_count,
            ecof_advance,
            proposed_count,
            accept_count,
            accept_val,
            accept_avg,
            accept_rate,
            decline_count,
            pending_count,
            advance_count,
            advance_val,
            advance_avg,
            commission_val,
            commission_rate_avg,
            budget,
            budget_rate
        FROM #Results
        WHERE
            COALESCE(ecof_count, 0) > 0 OR
            COALESCE(ecof_advance, 0) > 0 OR
            COALESCE(proposed_count, 0) > 0 OR
            COALESCE(accept_count, 0) > 0 OR
            COALESCE(accept_val, 0) > 0 OR
            COALESCE(decline_count, 0) > 0 OR
            COALESCE(pending_count, 0) > 0 OR
            COALESCE(advance_count, 0) > 0 OR
            COALESCE(advance_val, 0) > 0 OR
            COALESCE(commission_val, 0) > 0 OR
            COALESCE(budget, 0) > 0
        ORDER BY report_name, moment;
    END
    ELSE
    BEGIN
        -- For traditional queries (no report_group_id), show all rows
        SELECT
            report_name,
            moment,
            ecof_count,
            ecof_advance,
            proposed_count,
            accept_count,
            accept_val,
            accept_avg,
            accept_rate,
            decline_count,
            pending_count,
            advance_count,
            advance_val,
            advance_avg,
            commission_val,
            commission_rate_avg,
            budget,
            budget_rate
        FROM #Results
        ORDER BY moment;
    END
    
    -- Clean up temporary tables
    DROP TABLE #Results;
    DROP TABLE #Applications;
    DROP TABLE #Paids;
    DROP TABLE #Budget;
    DROP TABLE #FilteredMoments;
    DROP TABLE #Ecof;
    DROP TABLE #Facilities;
END;