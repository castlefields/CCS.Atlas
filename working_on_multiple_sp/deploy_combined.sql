/*
Combined Deployment Script for Modular Stored Procedures for Account ECOF Application Paid Report

This script combines all the stored procedure definitions into a single script.
This approach avoids the need for the SQLCMD :r directive and works in all SQL environments.

IMPORTANT: 
- Back up your database before running this script
- Test in a development environment first
- Run the test_comparison.sql script after deployment to verify results
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT 'Starting deployment of modular stored procedures...';
PRINT '';

-- Step 1: Deploy supporting procedures
PRINT 'Step 1: Deploying supporting procedures';

PRINT 'Deploying rpt_get_filtered_moments...';
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_filtered_moments]
    @period NVARCHAR(10) = NULL
AS
BEGIN
    -- This procedure returns a table of filtered dates based on the specified period
    
    IF @period IS NOT NULL
    BEGIN
        -- Use dynamic SQL to call the appropriate period view
        DECLARE @sql NVARCHAR(MAX) = N'
        SELECT year_month, year, month, quarter, year_quarter 
        FROM dbo.get_moment_' + @period;
        
        EXEC sp_executesql @sql;
    END
    ELSE
    BEGIN
        -- If @period is NULL, include all year_month values from the data
        SELECT DISTINCT
            year_month,
            CAST(LEFT(year_month, 4) AS INT) AS year,
            CAST(RIGHT(year_month, 2) AS INT) AS month,
            (CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1 AS quarter,
            LEFT(year_month, 4) + '-' + CAST(((CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1) AS NVARCHAR) AS year_quarter
        FROM dbo.get_account_application_last_4_years_by_facility_code
        
        UNION
        
        SELECT DISTINCT
            year_month,
            CAST(LEFT(year_month, 4) AS INT) AS year,
            CAST(RIGHT(year_month, 2) AS INT) AS month,
            (CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1 AS quarter,
            LEFT(year_month, 4) + '-' + CAST(((CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1) AS NVARCHAR) AS year_quarter
        FROM dbo.get_account_paid_last_4_years_by_facility_code
        WHERE year_month NOT IN (
            SELECT DISTINCT year_month
            FROM dbo.get_account_application_last_4_years_by_facility_code
        );
    END
END;
GO
PRINT 'rpt_get_filtered_moments deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_get_facilities_for_report...';
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_facilities_for_report]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL
AS
BEGIN
    -- This procedure selects the facilities to include in the report based on parameters

    IF @report_group_id IS NOT NULL
    BEGIN
        -- When using report_group_id, list all facilities in that group
        SELECT DISTINCT 
            facility_used_by_id, 
            facility_used_by_trading_style AS facility_used_by_name
        FROM dbo.account
        WHERE facility_used_by_report_group_id = @report_group_id
        ORDER BY facility_used_by_trading_style;
        
        -- Check if any facilities were found for this report_group_id
        IF @@ROWCOUNT = 0
        BEGIN
            -- If no facilities found, use a default placeholder
            SELECT NULL AS facility_used_by_id, 'Unknown Group' AS facility_used_by_name;
        END
    END
    ELSE
    BEGIN
        -- When not using report_group_id, create a single facility entry
        DECLARE @report_name NVARCHAR(255);
        
        -- Fetch the appropriate report_name based on facility_used_by_id 
        SELECT TOP 1
            @report_name = 
                COALESCE(
                    CASE 
                        WHEN @facility_used_by_id IS NOT NULL THEN facility_used_by_legal_name
                        ELSE 'Consumer Credit Solutions'
                    END, 
                    'Consumer Credit Solutions'
                )
        FROM dbo.account
        WHERE (@facility_used_by_id IS NULL OR facility_used_by_id = @facility_used_by_id);
        
        -- Ensure @report_name is not NULL
        IF @report_name IS NULL
            SET @report_name = 'Consumer Credit Solutions';
        
        -- Return the facility information
        SELECT @facility_used_by_id AS facility_used_by_id, @report_name AS facility_used_by_name;
    END
END;
GO
PRINT 'rpt_get_facilities_for_report deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_get_budget_data...';
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_budget_data]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL,
    @facility_lender NVARCHAR(50) = NULL
AS
BEGIN
    -- This procedure retrieves and aggregates budget data
    
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get budget data for each facility in the group
        SELECT
            b.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            b.facility_used_by_id,
            SUM(b.budget) AS budget
        FROM dbo.get_account_budget b
            INNER JOIN #FilteredMoments m ON b.year_month = m.year_month
            INNER JOIN #Facilities f ON b.facility_used_by_id = f.facility_used_by_id
        WHERE b.facility_used_by_report_group_id = @report_group_id
            AND (@facility_lender IS NULL OR UPPER(b.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            b.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            b.facility_used_by_id;
    END
    ELSE
    BEGIN
        -- Traditional Mode - Get budget data based on facility_used_by_id
        SELECT
            b.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            b.facility_used_by_id,
            SUM(b.budget) AS budget
        FROM dbo.get_account_budget b
            INNER JOIN #FilteredMoments m ON b.year_month = m.year_month
        WHERE (@facility_used_by_id IS NULL OR b.facility_used_by_id = @facility_used_by_id)
            AND (@facility_lender IS NULL OR UPPER(b.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            b.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            b.facility_used_by_id;
    END;
END;
GO
PRINT 'rpt_get_budget_data deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_get_ecof_data...';
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_ecof_data]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL,
    @facility_lender NVARCHAR(50) = NULL
AS
BEGIN
    -- This procedure retrieves and aggregates ECOF (Electronic Confirmation of Facility) data
    
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get ecof data for each facility in the group
        SELECT
            e.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            e.facility_used_by_id,
            SUM(e.ecof_count) AS ecof_count,
            SUM(e.ecof_advance) AS ecof_advance
        FROM dbo.get_account_ecof e
            INNER JOIN #FilteredMoments m ON e.year_month = m.year_month
            INNER JOIN #Facilities f ON e.facility_used_by_id = f.facility_used_by_id
        WHERE e.report_group_id = @report_group_id
            AND (@facility_lender IS NULL OR UPPER(e.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            e.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            e.facility_used_by_id;
    END
    ELSE
    BEGIN
        -- Traditional Mode - Get ecof data based on facility_used_by_id
        SELECT
            e.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            e.facility_used_by_id,
            SUM(e.ecof_count) AS ecof_count,
            SUM(e.ecof_advance) AS ecof_advance
        FROM dbo.get_account_ecof e
            INNER JOIN #FilteredMoments m ON e.year_month = m.year_month
        WHERE (@facility_used_by_id IS NULL OR e.facility_used_by_id = @facility_used_by_id)
            AND (@facility_lender IS NULL OR UPPER(e.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            e.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            e.facility_used_by_id;
    END;
END;
GO
PRINT 'rpt_get_ecof_data deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_get_application_data...';
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_application_data]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL,
    @facility_lender NVARCHAR(50) = NULL
AS
BEGIN
    -- This procedure retrieves and aggregates application data
    
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get application data for each facility in the group
        SELECT
            a.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            a.facility_used_by_id,
            SUM(a.accept_val) AS accept_val,
            SUM(a.accept) AS accept,
            SUM(a.decline) AS decline,
            SUM(a.pending) AS pending
        FROM dbo.get_account_application_last_4_years_by_facility_code a
            INNER JOIN #FilteredMoments m ON a.year_month = m.year_month
            INNER JOIN #Facilities f ON a.facility_used_by_id = f.facility_used_by_id
        WHERE a.facility_used_by_report_group_id = @report_group_id
            AND (@facility_lender IS NULL OR UPPER(a.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            a.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            a.facility_used_by_id;
    END
    ELSE
    BEGIN
        -- Traditional Mode - Get application data based on facility_used_by_id
        SELECT
            a.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            a.facility_used_by_id,
            SUM(a.accept_val) AS accept_val,
            SUM(a.accept) AS accept,
            SUM(a.decline) AS decline,
            SUM(a.pending) AS pending
        FROM dbo.get_account_application_last_4_years_by_facility_code a
            INNER JOIN #FilteredMoments m ON a.year_month = m.year_month
        WHERE (@facility_used_by_id IS NULL OR a.facility_used_by_id = @facility_used_by_id)
            AND (@facility_lender IS NULL OR UPPER(a.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            a.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            a.facility_used_by_id;
    END;
END;
GO
PRINT 'rpt_get_application_data deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_get_paid_data...';
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_paid_data]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL,
    @facility_lender NVARCHAR(50) = NULL
AS
BEGIN
    -- This procedure retrieves and aggregates payment data
    
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get paid data for each facility in the group
        SELECT
            p.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            p.facility_used_by_id,
            SUM(p.advance) AS advance,
            SUM(p.advance_count) AS advance_count,
            SUM(p.commission) AS commission,
            CASE 
                WHEN SUM(p.advance) > 0 THEN 
                    SUM(p.commission) / NULLIF(SUM(p.advance), 0)
                ELSE NULL 
            END AS commission_rate_avg
        FROM dbo.get_account_paid_last_4_years_by_facility_code p
            INNER JOIN #FilteredMoments m ON p.year_month = m.year_month
            INNER JOIN #Facilities f ON p.facility_used_by_id = f.facility_used_by_id
        WHERE p.facility_used_by_report_group_id = @report_group_id
            AND (@facility_lender IS NULL OR UPPER(p.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            p.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            p.facility_used_by_id;
    END
    ELSE
    BEGIN
        -- Traditional Mode - Get paid data based on facility_used_by_id
        SELECT
            p.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            p.facility_used_by_id,
            SUM(p.advance) AS advance,
            SUM(p.advance_count) AS advance_count,
            SUM(p.commission) AS commission,
            CASE 
                WHEN SUM(p.advance) > 0 THEN 
                    SUM(p.commission) / NULLIF(SUM(p.advance), 0)
                ELSE NULL 
            END AS commission_rate_avg
        FROM dbo.get_account_paid_last_4_years_by_facility_code p
            INNER JOIN #FilteredMoments m ON p.year_month = m.year_month
        WHERE (@facility_used_by_id IS NULL OR p.facility_used_by_id = @facility_used_by_id)
            AND (@facility_lender IS NULL OR UPPER(p.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            p.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            p.facility_used_by_id;
    END;
END;
GO
PRINT 'rpt_get_paid_data deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_build_final_results...';
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_build_final_results]
    @facility_lender NVARCHAR(50) = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL,
    @group_by NVARCHAR(50) = 'year_month',
    @Results NVARCHAR(128) = '#Results' -- Name of the results table to populate
AS
BEGIN
    -- This procedure combines all data sets and builds the final results
    
    -- Build and execute the dynamic SQL to populate the results table
    DECLARE @sql NVARCHAR(MAX) = N'
    INSERT INTO ' + @Results + '
    SELECT
        f.facility_used_by_name + '' : '' + COALESCE(@facility_lender, ''All'') AS report_name,
        m.' + @group_by + ' AS moment,
        SUM(result.ecof_count) AS ecof_count,
        SUM(result.ecof_advance) AS ecof_advance,
        SUM(result.proposed) AS proposed_count,
        SUM(result.accept) AS accept_count,
        SUM(result.accept_val) AS accept_val,
        CASE WHEN SUM(result.accept) > 0 THEN SUM(result.accept_val) / NULLIF(SUM(result.accept), 0) END AS accept_avg,
        CASE WHEN SUM(result.accept + result.decline) > 0 THEN CAST(SUM(result.accept) * 1.0 / NULLIF(SUM(result.accept + result.decline), 0) AS DECIMAL(18,6)) END AS accept_rate,
        SUM(result.decline) AS decline_count,
        SUM(result.pending) AS pending_count,
        SUM(result.advance_count) AS advance_count,
        SUM(result.advance) AS advance_val,
        CASE WHEN SUM(result.advance_count) > 0 THEN SUM(result.advance) / NULLIF(SUM(result.advance_count), 0) END AS advance_avg,
        SUM(result.commission) AS commission_val,
        CASE WHEN SUM(result.advance) > 0 THEN SUM(result.commission) / NULLIF(SUM(result.advance), 0) END AS commission_rate_avg,
        SUM(result.budget) AS budget,
        CASE WHEN SUM(result.budget) > 0 THEN CAST(SUM(result.advance) * 1.0 / NULLIF(SUM(result.budget), 0) AS DECIMAL(18,6)) END AS budget_rate
    FROM
        #FilteredMoments m
        CROSS JOIN #Facilities f
        LEFT JOIN (
        SELECT
            a.year_month,
            a.year,
            a.month,
            a.quarter,
            a.year_quarter,
            a.facility_used_by_id,
            SUM(a.accept_val) AS accept_val,
            SUM(a.accept) AS accept,
            SUM(a.decline) AS decline,
            SUM(a.pending) AS pending,
            SUM(a.accept + a.decline) AS proposed,
            SUM(p.advance_count) AS advance_count,
            SUM(p.advance) AS advance,
            SUM(p.commission) AS commission,
            SUM(e.ecof_count) AS ecof_count,
            SUM(e.ecof_advance) AS ecof_advance,
            SUM(b.budget) AS budget
        FROM
            #Applications a
            LEFT JOIN #Paids p ON a.year_month = p.year_month AND (a.facility_used_by_id = p.facility_used_by_id OR (a.facility_used_by_id IS NULL AND p.facility_used_by_id IS NULL))
            LEFT JOIN #Ecof e ON a.year_month = e.year_month AND (a.facility_used_by_id = e.facility_used_by_id OR (a.facility_used_by_id IS NULL AND e.facility_used_by_id IS NULL))
            LEFT JOIN #Budget b ON a.year_month = b.year_month AND (a.facility_used_by_id = b.facility_used_by_id OR (a.facility_used_by_id IS NULL AND b.facility_used_by_id IS NULL))
        GROUP BY
            a.year_month,
            a.year,
            a.month,
            a.quarter,
            a.year_quarter,
            a.facility_used_by_id
    ) AS result ON m.' + @group_by + ' = result.' + @group_by + ' AND (f.facility_used_by_id = result.facility_used_by_id OR (f.facility_used_by_id IS NULL AND result.facility_used_by_id IS NULL))
    GROUP BY
        f.facility_used_by_name,
        m.' + @group_by

    EXEC sp_executesql @sql, N'@facility_lender NVARCHAR(50)', @facility_lender;
END;
GO
PRINT 'rpt_build_final_results deployed successfully.';
PRINT '';

-- Step 2: Deploy main procedure
PRINT 'Step 2: Deploying main procedure';

PRINT 'Deploying rpt_mth_account_ecof_application_paid...';
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
        @Results = '#Results'; -- Output parameter that will hold the results table name
    
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
GO
PRINT 'rpt_mth_account_ecof_application_paid deployed successfully.';
PRINT '';

-- Step 3: Create a backup of the old procedure
PRINT 'Step 3: Creating a backup of the original procedure';

DECLARE @BackupDate NVARCHAR(14) = REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 120), ':', '')
DECLARE @BackupSQL NVARCHAR(MAX) = '
EXEC sp_rename ''dbo.rpt_mth_account_ecof_application_paid_0401_2135'', ''rpt_mth_account_ecof_application_paid_0401_2135_backup_' + @BackupDate + '''';

PRINT @BackupSQL;
EXEC sp_executesql @BackupSQL;
PRINT 'Original procedure backed up successfully.';
PRINT '';

PRINT 'Deployment completed successfully.';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Run the test_comparison.sql script to verify that the new procedures produce the same results';
PRINT '2. If any issues are found, revert by dropping the new procedures and renaming the backup';
PRINT '3. If everything works correctly, you can drop the backup procedure after a suitable testing period';
