/****** Object:  StoredProcedure [dbo].[rpt_mth_account_ecof_application_paid_saved]    Script Date: 26/03/2025 12:01:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER     PROCEDURE [dbo].[rpt_mth_account_ecof_application_paid_saved]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    -- Optional filter for specific account
    @report_group_id NVARCHAR(50) = NULL,
    -- Optional filter for report group
    @facility_lender NVARCHAR(50) = NULL,
    -- Optional filter for specific lender
    @period NVARCHAR(10) = 'L12M'
-- Optional period filter (L12M, P12M, C12M, or NULL for no filter)
AS
BEGIN
    -- Validate the period parameter
    IF @period IS NOT NULL AND @period NOT IN ('L12M', 'P12M', 'C12M')
    BEGIN
        RAISERROR('Invalid @period parameter. Valid values are L12M, P12M, C12M, or NULL.', 16, 1)
        RETURN
    END

    -- Use temporary tables instead of table variables for better performance with large datasets
    CREATE TABLE #Ecof
    (
        year_month NVARCHAR(7),
        ecof_count INT,
        ecof_advance DECIMAL(18,2)
    );

    CREATE TABLE #Applications
    (
        year_month NVARCHAR(7),
        accept_val DECIMAL(18,2),
        accept INT,
        decline INT,
        pending INT
    );

    CREATE TABLE #Paids
    (
        year_month NVARCHAR(7),
        advance DECIMAL(18,2),
        advance_count INT,
        commission DECIMAL(18,2),
        commission_rate_avg DECIMAL(18,4)
    );

    -- Create a table to hold the filtered moments
    CREATE TABLE #FilteredMoments
    (
        year_month NVARCHAR(7)
    );

    -- Declare a variable to store the report name
    DECLARE @report_name NVARCHAR(255);

    -- Populate the #FilteredMoments table based on @period
    IF @period IS NOT NULL
    BEGIN
        DECLARE @sql NVARCHAR(MAX) = N'
        INSERT INTO #FilteredMoments (year_month)
        SELECT year_month FROM dbo.get_moment_' + @period

        EXEC sp_executesql @sql
    END
    ELSE
    BEGIN
        -- If @period is NULL, include all year_month values from the data
        INSERT INTO #FilteredMoments
            (year_month)
        SELECT DISTINCT year_month
        FROM dbo.get_account_application_last_4_years_by_facility_code

        -- Also include year_month values from paid data
        INSERT INTO #FilteredMoments
            (year_month)
        SELECT DISTINCT year_month
        FROM dbo.get_account_paid_last_4_years_by_facility_code
        WHERE year_month NOT IN (SELECT year_month
        FROM #FilteredMoments)
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

    -- Insert into #Ecof
    INSERT INTO #Ecof
        (year_month, ecof_count, ecof_advance)
    SELECT
        e.year_month,
        SUM(e.ecof_count) AS ecof_count,
        SUM(e.ecof_advance) AS ecof_advance
    FROM dbo.get_account_ecof e
        INNER JOIN #FilteredMoments m ON e.year_month = m.year_month
    WHERE
        (@facility_used_by_id IS NULL OR e.facility_used_by_id = @facility_used_by_id)
        AND (@report_group_id IS NULL OR e.facility_used_by_report_group_id = @report_group_id)
    GROUP BY e.year_month;

    -- Insert into #Paids
    INSERT INTO #Paids
        (year_month, advance, advance_count, commission, commission_rate_avg)
    SELECT
        p.year_month,
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
        p.year_month;

    -- Insert into #Applications
    INSERT INTO #Applications
        (year_month, accept_val, accept, decline, pending)
    SELECT
        a.year_month,
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
    GROUP BY a.year_month;

    -- Final result set - use filtered moments as the base in requested order
    SELECT
        @report_name AS report_name,
        m.year_month,
        result.ecof_count AS ecof_count,
        result.ecof_advance AS ecof_advance,
        CASE WHEN result.ecof_advance IS NULL THEN NULL ELSE '£' + FORMAT(result.ecof_advance, 'N0') END AS ecof_advance_text,
        result.proposed AS proposed_count,
        result.accept AS accept_count,
        result.accept_val AS accept_val,
        CASE WHEN result.accept_val IS NULL THEN NULL ELSE '£' + FORMAT(result.accept_val, 'N0') END AS accept_text,
        CASE WHEN result.accept_avg IS NULL THEN NULL ELSE '£' + FORMAT(result.accept_avg, 'N0') END AS accept_avg_text,
        CASE WHEN result.accept_rate IS NULL THEN NULL ELSE CAST(result.accept_rate AS NVARCHAR) + '%' END AS accept_rate_text,
        result.decline AS decline_count,
        result.pending AS pending_count,
        result.advance_count AS advance_count,
        result.advance AS advance_val,
        CASE WHEN result.advance IS NULL THEN NULL ELSE '£' + FORMAT(result.advance, 'N0') END AS advance_text,
        CASE WHEN result.advance_avg IS NULL THEN NULL ELSE '£' + FORMAT(result.advance_avg, 'N0') END AS advance_avg_text,
        result.commission AS commission_val,
        CASE WHEN result.commission IS NULL THEN NULL ELSE '£' + FORMAT(result.commission, 'N0') END AS commission_text,
        result.commission_rate_avg AS commission_rate_avg,
        CASE WHEN result.commission_rate_avg IS NULL THEN NULL 
         ELSE FORMAT(result.commission_rate_avg * 100, 'N2') + '%' END AS commission_rate_avg_text
    FROM
        #FilteredMoments m
        LEFT JOIN (
        SELECT
            a.year_month,
            SUM(a.accept_val) AS accept_val,
            SUM(a.accept) AS accept,
            SUM(a.decline) AS decline,
            SUM(a.pending) AS pending,
            SUM(a.accept + a.decline) AS proposed,
            CASE
                WHEN (SUM(a.accept) + SUM(a.decline)) > 0 THEN
                    CAST(SUM(a.accept) * 100.0 / NULLIF(SUM(a.accept) + SUM(a.decline), 0) AS INT)
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
            LEFT JOIN #Paids p ON a.year_month = p.year_month
            LEFT JOIN #Ecof e ON a.year_month = e.year_month
        GROUP BY
            a.year_month
    ) AS result ON m.year_month = result.year_month
    ORDER BY m.year_month;

    -- Clean up temporary tables
    DROP TABLE #Applications;
    DROP TABLE #Paids;
    DROP TABLE #FilteredMoments;
    DROP TABLE #Ecof;
END;