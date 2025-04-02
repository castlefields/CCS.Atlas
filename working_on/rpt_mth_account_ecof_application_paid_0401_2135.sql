/****** Object:  StoredProcedure [dbo].[rpt_mth_account_ecof_application_paid_0401_2135]    Script Date: 01/04/2025 21:35:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_mth_account_ecof_application_paid_0401_2135]
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
    -- Validate the period parameter
    IF @period IS NOT NULL AND @period NOT IN ('L12M', 'P12M', 'C12M')
    BEGIN
        RAISERROR('Invalid @period parameter. Valid values are L12M, P12M, C12M, or NULL.', 16, 1)
        RETURN
    END

    -- Validate the group_by parameter
    IF @group_by NOT IN ('year_month', 'year', 'month', 'quarter', 'year_quarter')
    BEGIN
        RAISERROR('Invalid @group_by parameter. Valid values are year_month, year, month, quarter, year_quarter.', 16, 1)
        RETURN
    END

    -- Use temporary tables instead of table variables for better performance with large datasets
    CREATE TABLE #Budget
    (
        year_month NVARCHAR(7),
        year INT,
        month INT,
        quarter INT,
        year_quarter NVARCHAR(7),
        facility_used_by_id UNIQUEIDENTIFIER,
        budget DECIMAL(18,2)
    );

    CREATE TABLE #Ecof
    (
        year_month NVARCHAR(7),
        year INT,
        month INT,
        quarter INT,
        year_quarter NVARCHAR(7),
        facility_used_by_id UNIQUEIDENTIFIER,
        ecof_count INT,
        ecof_advance DECIMAL(18,2)
    );

    CREATE TABLE #Applications
    (
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

    CREATE TABLE #Paids
    (
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

    -- Create a table to hold the filtered moments
    CREATE TABLE #FilteredMoments
    (
        year_month NVARCHAR(7),
        year INT,
        month INT,
        quarter INT,
        year_quarter NVARCHAR(7)
    );

    -- Create a table to hold the final results
    CREATE TABLE #Results
    (
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

    -- Create a table to hold the facilities
    CREATE TABLE #Facilities
    (
        facility_used_by_id UNIQUEIDENTIFIER,
        facility_used_by_name NVARCHAR(255)
    );

    -- Populate the #FilteredMoments table based on @period
    IF @period IS NOT NULL
    BEGIN
        DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO #FilteredMoments (year_month, year, month, quarter, year_quarter)
        SELECT year_month, year, month, quarter, year_quarter FROM dbo.get_moment_' + @period

        EXEC sp_executesql @sql
    END
    ELSE
    BEGIN
        -- If @period is NULL, include all year_month values from the data
        INSERT INTO #FilteredMoments
            (year_month, year, month, quarter, year_quarter)
        SELECT DISTINCT
            year_month,
            CAST(LEFT(year_month, 4) AS INT) AS year,
            CAST(RIGHT(year_month, 2) AS INT) AS month,
            (CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1 AS quarter,
            LEFT(year_month, 4) + '-' + CAST(((CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1) AS NVARCHAR) AS year_quarter
        FROM dbo.get_account_application_last_4_years_by_facility_code

        -- Also include year_month values from paid data
        INSERT INTO #FilteredMoments
            (year_month, year, month, quarter, year_quarter)
        SELECT DISTINCT
            year_month,
            CAST(LEFT(year_month, 4) AS INT) AS year,
            CAST(RIGHT(year_month, 2) AS INT) AS month,
            (CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1 AS quarter,
            LEFT(year_month, 4) + '-' + CAST(((CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1) AS NVARCHAR) AS year_quarter
        FROM dbo.get_account_paid_last_4_years_by_facility_code
        WHERE year_month NOT IN (SELECT year_month
        FROM #FilteredMoments)
    END

    -- If report_group_id is specified, get all facilities in that group
    -- Otherwise use the traditional approach
    IF @report_group_id IS NOT NULL
    BEGIN
        -- When using report_group_id, list all facilities in that group
        INSERT INTO #Facilities (facility_used_by_id, facility_used_by_name)
        SELECT DISTINCT facility_used_by_id, facility_used_by_trading_style
        FROM dbo.account
        WHERE facility_used_by_report_group_id = @report_group_id
        ORDER BY facility_used_by_trading_style;

        -- Check if any facilities were found for this report_group_id
        IF NOT EXISTS (SELECT 1 FROM #Facilities)
        BEGIN
            -- If no facilities found, use a default placeholder
            INSERT INTO #Facilities (facility_used_by_id, facility_used_by_name)
            VALUES (NULL, 'Unknown Group');
        END
    END
    ELSE
    BEGIN
        -- When not using report_group_id, create a single facility entry
        -- This preserves the original behavior of the stored procedure
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
        WHERE (@facility_used_by_id IS NOT NULL AND facility_used_by_id = @facility_used_by_id);

        -- Ensure @report_name is not NULL
        IF @report_name IS NULL
            SET @report_name = 'Consumer Credit Solutions';

        -- Add the facility to the #Facilities table
        INSERT INTO #Facilities (facility_used_by_id, facility_used_by_name)
        VALUES (@facility_used_by_id, @report_name);
    END

    -- Insert into #Budget with proper grouping and all date-related fields
    -- Handle both report_group_id mode and traditional mode
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get budget data for each facility in the group
        INSERT INTO #Budget
            (year_month, year, month, quarter, year_quarter, facility_used_by_id, budget)
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
        INSERT INTO #Budget
            (year_month, year, month, quarter, year_quarter, facility_used_by_id, budget)
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

    -- Insert into #Ecof with proper grouping and all date-related fields
    -- Handle both report_group_id mode and traditional mode
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get ecof data for each facility in the group
        INSERT INTO #Ecof
            (year_month, year, month, quarter, year_quarter, facility_used_by_id, ecof_count, ecof_advance)
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
        INSERT INTO #Ecof
            (year_month, year, month, quarter, year_quarter, facility_used_by_id, ecof_count, ecof_advance)
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

    -- Insert into #Paids with proper grouping including facility_used_by_id
    -- Handle both report_group_id mode and traditional mode
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get paid data for each facility in the group
        INSERT INTO #Paids
            (year_month, year, month, quarter, year_quarter, facility_used_by_id, advance, advance_count, commission, commission_rate_avg)
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
        INSERT INTO #Paids
            (year_month, year, month, quarter, year_quarter, facility_used_by_id, advance, advance_count, commission, commission_rate_avg)
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

    -- Insert into #Applications with proper grouping including facility_used_by_id
    -- Handle both report_group_id mode and traditional mode
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get application data for each facility in the group
        INSERT INTO #Applications
            (year_month, year, month, quarter, year_quarter, facility_used_by_id, accept_val, accept, decline, pending)
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
        INSERT INTO #Applications
            (year_month, year, month, quarter, year_quarter, facility_used_by_id, accept_val, accept, decline, pending)
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

    -- Build and execute the dynamic SQL to populate the results table
    DECLARE @final_sql NVARCHAR(MAX) = N'
    INSERT INTO #Results
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
        m.' + @group_by + ''

    EXEC sp_executesql @final_sql, N'@facility_lender NVARCHAR(50)', @facility_lender;

    -- Select the final results with appropriate filtering
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