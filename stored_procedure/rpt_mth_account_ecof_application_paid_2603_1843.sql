CREATE OR ALTER PROCEDURE [dbo].[rpt_mth_account_ecof_application_paid_1843]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    -- Optional filter for specific account
    @report_group_id NVARCHAR(50) = NULL,
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
    CREATE TABLE #Ecof
    (
        year_month NVARCHAR(7),
        year INT,
        month INT,
        quarter INT,
        year_quarter NVARCHAR(7),
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

    -- Declare a variable to store the report name
    DECLARE @report_name NVARCHAR(255);

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
            LEFT(year_month, 4) + 'Q' + CAST(((CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1) AS NVARCHAR) AS year_quarter
        FROM dbo.get_account_application_last_4_years_by_facility_code

        -- Also include year_month values from paid data
        INSERT INTO #FilteredMoments
            (year_month, year, month, quarter, year_quarter)
        SELECT DISTINCT 
            year_month,
            CAST(LEFT(year_month, 4) AS INT) AS year,
            CAST(RIGHT(year_month, 2) AS INT) AS month,
            (CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1 AS quarter,
            LEFT(year_month, 4) + 'Q' + CAST(((CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1) AS NVARCHAR) AS year_quarter
        FROM dbo.get_account_paid_last_4_years_by_facility_code
        WHERE year_month NOT IN (SELECT year_month FROM #FilteredMoments)
    END

    -- Fetch the appropriate report_name based on facility_used_by_id or report_group_id
    SELECT TOP 1
        @report_name = 
            COALESCE(
                CASE 
                    WHEN @report_group_id IS NOT NULL THEN facility_used_by_report_group
                    WHEN @facility_used_by_id IS NOT NULL THEN facility_used_by_legal_name
                    ELSE 'Consumer Credit Solutions'
                END, 
                'Consumer Credit Solutions'
            ) + ' : ' + COALESCE(@facility_lender, 'All')
    FROM dbo.account
    WHERE (@facility_used_by_id IS NOT NULL AND facility_used_by_id = @facility_used_by_id)
        OR (@report_group_id IS NOT NULL AND facility_used_by_report_group_id = @report_group_id);

    -- Ensure @report_name is not NULL
    IF @report_name IS NULL
        SET @report_name = 'Consumer Credit Solutions : ' + COALESCE(@facility_lender, 'All');

    -- Insert into #Ecof with proper grouping and all date-related fields
    INSERT INTO #Ecof
        (year_month, year, month, quarter, year_quarter, ecof_count, ecof_advance)
    SELECT
        e.year_month,
        m.year,
        m.month,
        m.quarter,
        m.year_quarter,
        SUM(e.ecof_count) AS ecof_count,
        SUM(e.ecof_advance) AS ecof_advance
    FROM dbo.get_account_ecof e
        INNER JOIN #FilteredMoments m ON e.year_month = m.year_month
    WHERE
        (@facility_used_by_id IS NULL OR e.facility_used_by_id = @facility_used_by_id)
        AND (@report_group_id IS NULL OR e.report_group_id = @report_group_id)
        AND (@facility_lender IS NULL OR e.facility_lender = @facility_lender)
    GROUP BY 
        e.year_month,
        m.year,
        m.month,
        m.quarter,
        m.year_quarter;

    -- Insert into #Paids with proper grouping
    INSERT INTO #Paids
        (year_month, year, month, quarter, year_quarter, advance, advance_count, commission, commission_rate_avg)
    SELECT
        p.year_month,
        m.year,
        m.month,
        m.quarter,
        m.year_quarter,
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
    WHERE
        (@facility_used_by_id IS NULL OR p.facility_used_by_id = @facility_used_by_id)
        AND (@report_group_id IS NULL OR p.facility_used_by_report_group_id = @report_group_id)
        AND (@facility_lender IS NULL OR p.facility_lender = @facility_lender)
    GROUP BY 
        p.year_month,
        m.year,
        m.month,
        m.quarter,
        m.year_quarter;

    -- Insert into #Applications with proper grouping
    INSERT INTO #Applications
        (year_month, year, month, quarter, year_quarter, accept_val, accept, decline, pending)
    SELECT
        a.year_month,
        m.year,
        m.month,
        m.quarter,
        m.year_quarter,
        SUM(a.accept_val) AS accept_val,
        SUM(a.accept) AS accept,
        SUM(a.decline) AS decline,
        SUM(a.pending) AS pending
    FROM dbo.get_account_application_last_4_years_by_facility_code a
        INNER JOIN #FilteredMoments m ON a.year_month = m.year_month
    WHERE
        (@facility_used_by_id IS NULL OR a.facility_used_by_id = @facility_used_by_id)
        AND (@report_group_id IS NULL OR a.facility_used_by_report_group_id = @report_group_id)
        AND (@facility_lender IS NULL OR a.facility_lender = @facility_lender)
    GROUP BY 
        a.year_month,
        m.year,
        m.month,
        m.quarter,
        m.year_quarter;

    -- Final result set with dynamic grouping
    DECLARE @final_sql NVARCHAR(MAX) = N'
    SELECT
        @report_name AS report_name,
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
        CASE WHEN SUM(result.advance) > 0 THEN SUM(result.commission) / NULLIF(SUM(result.advance), 0) END AS commission_rate_avg
    FROM
        #FilteredMoments m
        LEFT JOIN (
        SELECT
            a.year_month,
            a.year,
            a.month,
            a.quarter,
            a.year_quarter,
            SUM(a.accept_val) AS accept_val,
            SUM(a.accept) AS accept,
            SUM(a.decline) AS decline,
            SUM(a.pending) AS pending,
            SUM(a.accept + a.decline) AS proposed,
            SUM(p.advance_count) AS advance_count,
            SUM(p.advance) AS advance,
            SUM(p.commission) AS commission,
            SUM(e.ecof_count) AS ecof_count,
            SUM(e.ecof_advance) AS ecof_advance
        FROM
            #Applications a
            LEFT JOIN #Paids p ON a.year_month = p.year_month
            LEFT JOIN #Ecof e ON a.year_month = e.year_month
        GROUP BY
            a.year_month,
            a.year,
            a.month,
            a.quarter,
            a.year_quarter
    ) AS result ON m.' + @group_by + ' = result.' + @group_by + '
    GROUP BY m.' + @group_by + '
    ORDER BY m.' + @group_by;

    EXEC sp_executesql @final_sql, N'@report_name NVARCHAR(255)', @report_name;

    -- Clean up temporary tables
    DROP TABLE #Applications;
    DROP TABLE #Paids;
    DROP TABLE #FilteredMoments;
    DROP TABLE #Ecof;
END; 