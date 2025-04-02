/****** Object:  StoredProcedure [dbo].[rpt_mth_account_ecof_application_paid]    Script Date: 26/03/2025 12:03:20 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[rpt_mth_account_ecof_application_paid]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    -- Optional filter for specific account
    @report_group_id NVARCHAR(50) = NULL,
    -- Optional filter for report group
    @facility_lender NVARCHAR(50) = NULL,
    -- Optional filter for specific lender
    @period NVARCHAR(10) = 'L12M',
    -- Optional period filter (L12M, P12M, C12M, or NULL for no filter)
    @group_by NVARCHAR(20) = 'year_month'
-- Optional grouping parameter (year_month, year, month, quarter, year_quarter)
AS
BEGIN
    -- Validate the period parameter
    IF @period IS NOT NULL AND @period NOT IN ('L12M', 'P12M', 'C12M')
    BEGIN
        RAISERROR('Invalid @period parameter. Valid values are L12M, P12M, C12M, or NULL.', 16, 1)
        RETURN
    END

    -- Validate the group_by parameter
    IF @group_by IS NOT NULL AND @group_by NOT IN ('year_month', 'year', 'month', 'quarter', 'year_quarter')
    BEGIN
        RAISERROR('Invalid @group_by parameter. Valid values are year_month, year, month, quarter, year_quarter.', 16, 1)
        RETURN
    END

    -- Create a mapping table to join the year_month values to their corresponding year, month, quarter values
    CREATE TABLE #TimeMapping
    (
        year_month NVARCHAR(7),
        year INT,
        month INT,
        quarter INT,
        year_quarter NVARCHAR(7),
        group_by_value NVARCHAR(20)
    );

    -- Populate the mapping table with all distinct year_month values from moment table
    -- And compute the group_by_value based on the selected @group_by parameter
    INSERT INTO #TimeMapping
        (year_month, year, month, quarter, year_quarter, group_by_value)
    SELECT
        year_month,
        year,
        month,
        quarter,
        year_quarter,
        CASE @group_by
            WHEN 'year_month' THEN year_month
            WHEN 'year' THEN CAST(year AS NVARCHAR(20))
            WHEN 'month' THEN CAST(month AS NVARCHAR(20))
            WHEN 'quarter' THEN CAST(quarter AS NVARCHAR(20))
            WHEN 'year_quarter' THEN year_quarter
        END AS group_by_value
    FROM dbo.moment;

    -- Use temporary tables instead of table variables for better performance with large datasets
    CREATE TABLE #Ecof
    (
        group_by_value NVARCHAR(20),
        ecof_count INT,
        ecof_advance DECIMAL(18,2)
    );

    CREATE TABLE #Applications
    (
        group_by_value NVARCHAR(20),
        accept_val DECIMAL(18,2),
        accept INT,
        decline INT,
        pending INT
    );

    CREATE TABLE #Paids
    (
        group_by_value NVARCHAR(20),
        advance DECIMAL(18,2),
        advance_count INT,
        commission DECIMAL(18,2),
        commission_rate_avg DECIMAL(18,4)
    );

    -- Create a table to hold the filtered moments based on selected period
    CREATE TABLE #FilteredMoments
    (
        group_by_value NVARCHAR(20)
    );

    -- Declare a variable to store the report name
    DECLARE @report_name NVARCHAR(255);

    -- Populate the #FilteredMoments table based on @period
    IF @period IS NOT NULL
    BEGIN
        -- For L12M, P12M, C12M periods, join with the period view and our mapping table
        DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO #FilteredMoments (group_by_value)
        SELECT DISTINCT tm.group_by_value
        FROM dbo.get_moment_' + @period + ' m
        JOIN #TimeMapping tm ON m.year_month = tm.year_month';

        EXEC sp_executesql @sql;
    END
    ELSE
    BEGIN
        -- If @period is NULL, include all year_month values from the data
        INSERT INTO #FilteredMoments
            (group_by_value)
        SELECT DISTINCT tm.group_by_value
        FROM dbo.get_account_application_last_4_years_by_facility_code a
            JOIN #TimeMapping tm ON a.year_month = tm.year_month;

        -- Also include year_month values from paid data
        INSERT INTO #FilteredMoments
            (group_by_value)
        SELECT DISTINCT tm.group_by_value
        FROM dbo.get_account_paid_last_4_years_by_facility_code p
            JOIN #TimeMapping tm ON p.year_month = tm.year_month
        WHERE tm.group_by_value NOT IN (SELECT group_by_value
        FROM #FilteredMoments);
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

    -- Insert into #Ecof - using the mapping table to get the group_by_value
    INSERT INTO #Ecof
        (group_by_value, ecof_count, ecof_advance)
    SELECT
        tm.group_by_value,
        SUM(e.ecof_count) AS ecof_count,
        SUM(e.ecof_advance) AS ecof_advance
    FROM dbo.get_account_ecof e
        JOIN #TimeMapping tm ON e.year_month = tm.year_month
        JOIN #FilteredMoments fm ON tm.group_by_value = fm.group_by_value
    WHERE
        (@facility_used_by_id IS NULL OR e.facility_used_by_id = @facility_used_by_id)
        AND (@report_group_id IS NULL OR e.facility_used_by_report_group_id = @report_group_id)
    GROUP BY tm.group_by_value;

    -- Insert into #Paids - using the mapping table to get the group_by_value
    INSERT INTO #Paids
        (group_by_value, advance, advance_count, commission, commission_rate_avg)
    SELECT
        tm.group_by_value,
        SUM(p.advance) AS advance,
        SUM(p.advance_count) AS advance_count,
        SUM(p.commission) AS commission,
        CASE 
            WHEN SUM(p.advance) > 0 THEN 
                SUM(p.commission) / NULLIF(SUM(p.advance), 0)
            ELSE NULL 
        END AS commission_rate_avg
    FROM dbo.get_account_paid_last_4_years_by_facility_code p
        JOIN #TimeMapping tm ON p.year_month = tm.year_month
        JOIN #FilteredMoments fm ON tm.group_by_value = fm.group_by_value
    WHERE
        (@facility_used_by_id IS NULL OR p.facility_used_by_id = @facility_used_by_id)
        AND (@report_group_id IS NULL OR p.facility_used_by_report_group_id = @report_group_id)
        AND (@facility_lender IS NULL OR p.facility_lender = @facility_lender)
    GROUP BY tm.group_by_value;

    -- Insert into #Applications - using the mapping table to get the group_by_value
    INSERT INTO #Applications
        (group_by_value, accept_val, accept, decline, pending)
    SELECT
        tm.group_by_value,
        SUM(a.accept_val) AS accept_val,
        SUM(a.accept) AS accept,
        SUM(a.decline) AS decline,
        SUM(a.pending) AS pending
    FROM dbo.get_account_application_last_4_years_by_facility_code a
        JOIN #TimeMapping tm ON a.year_month = tm.year_month
        JOIN #FilteredMoments fm ON tm.group_by_value = fm.group_by_value
    WHERE
        (@facility_used_by_id IS NULL OR a.facility_used_by_id = @facility_used_by_id)
        AND (@report_group_id IS NULL OR a.facility_used_by_report_group_id = @report_group_id)
        AND (@facility_lender IS NULL OR a.facility_lender = @facility_lender)
    GROUP BY tm.group_by_value;

    -- Final result set - use filtered moments as the base in requested order
    SELECT
        @report_name AS report_name,
        fm.group_by_value AS group_by,
        result.ecof_count AS ecof_count,
        result.ecof_advance AS ecof_advance,
        result.proposed AS proposed_count,
        result.accept AS accept_count,
        result.accept_val AS accept_val,
        result.accept_avg AS accept_avg,
        result.accept_rate AS accept_rate,
        result.decline AS decline_count,
        result.pending AS pending_count,
        result.advance_count AS advance_count,
        result.advance AS advance_val,
        result.advance_avg AS advance_avg,
        result.commission AS commission_val,
        result.commission_rate_avg AS commission_rate_avg
    FROM
        (SELECT DISTINCT group_by_value
        FROM #FilteredMoments) fm
        LEFT JOIN (
        SELECT
            a.group_by_value,
            SUM(a.accept_val) AS accept_val,
            SUM(a.accept) AS accept,
            SUM(a.decline) AS decline,
            SUM(a.pending) AS pending,
            SUM(a.accept + a.decline) AS proposed,
            CASE
                WHEN (SUM(a.accept) + SUM(a.decline)) > 0 THEN
                    CAST(SUM(a.accept) * 1.0 / NULLIF(SUM(a.accept) + SUM(a.decline), 0) AS DECIMAL(18,4))
                ELSE NULL
            END AS accept_rate,
            CASE
                WHEN SUM(a.accept) > 0 THEN
                    SUM(a.accept_val) / NULLIF(SUM(a.accept), 0)
                ELSE NULL
            END AS accept_avg,
            SUM(p.advance_count) AS advance_count,
            SUM(p.advance) AS advance,
            CASE
                WHEN SUM(p.advance_count) > 0 THEN
                    SUM(p.advance) / NULLIF(SUM(p.advance_count), 0)
                ELSE NULL
            END AS advance_avg,
            SUM(p.commission) AS commission,
            AVG(p.commission_rate_avg) AS commission_rate_avg,
            -- Added eCOF data
            SUM(e.ecof_count) AS ecof_count,
            SUM(e.ecof_advance) AS ecof_advance
        FROM
            #Applications a
            LEFT JOIN #Paids p ON a.group_by_value = p.group_by_value
            LEFT JOIN #Ecof e ON a.group_by_value = e.group_by_value
        GROUP BY
            a.group_by_value
    ) AS result ON fm.group_by_value = result.group_by_value
    ORDER BY fm.group_by_value;

    -- Clean up temporary tables
    DROP TABLE #Applications;
    DROP TABLE #Paids;
    DROP TABLE #FilteredMoments;
    DROP TABLE #Ecof;
    DROP TABLE #TimeMapping;
END;