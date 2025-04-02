SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[rpt_account_application_paid_rolling_12_months]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL, -- Optional filter for specific account
    @report_group_id NVARCHAR(50) = NULL, -- Optional filter for report group
    @facility_lender NVARCHAR(50) = NULL, -- Optional filter for specific lender
    @rolling_12_months BIT = 1, -- Boolean: 1 = Last 12 Months, 0 = Last 4 Years
    @include_totals BIT = 1 -- Boolean: 1 = Include Totals Row, 0 = No Totals Row
AS
BEGIN
    -- Declare table variables to store view data
    DECLARE @Applications TABLE (
        year_month NVARCHAR(7),
        accept_val DECIMAL(18,2),
        accept INT,
        decline INT,
        pending INT
    );

    DECLARE @Payments TABLE (
        year_month NVARCHAR(7),
        advance DECIMAL(18,2),
        advance_count INT
    );

    -- Declare a variable to store the report name
    DECLARE @report_name NVARCHAR(255);

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

    -- **Dynamically handle filtering based on provided parameters**
    IF @facility_lender IS NULL
    BEGIN
        INSERT INTO @Applications (year_month, accept_val, accept, decline, pending)
        SELECT 
            year_month, 
            SUM(accept_val) AS accept_val, 
            SUM(accept) AS accept, 
            SUM(decline) AS decline, 
            SUM(pending) AS pending
        FROM dbo.get_account_application_last_4_years_by_facility_code
        WHERE 
            (facility_used_by_id = COALESCE(@facility_used_by_id, facility_used_by_id))
            AND (facility_used_by_report_group_id = COALESCE(@report_group_id, facility_used_by_report_group_id))
        GROUP BY year_month;

        INSERT INTO @Payments (year_month, advance, advance_count)
        SELECT 
            year_month, 
            SUM(advance) AS advance, 
            SUM(advance_count) AS advance_count
        FROM dbo.get_account_paid_last_4_years_by_facility_code
        WHERE 
            (facility_used_by_id = COALESCE(@facility_used_by_id, facility_used_by_id))
            AND (facility_used_by_report_group_id = COALESCE(@report_group_id, facility_used_by_report_group_id))
        GROUP BY year_month;
    END
    ELSE
    BEGIN
        INSERT INTO @Applications (year_month, accept_val, accept, decline, pending)
        SELECT 
            year_month, 
            SUM(accept_val) AS accept_val, 
            SUM(accept) AS accept, 
            SUM(decline) AS decline, 
            SUM(pending) AS pending
        FROM dbo.get_account_application_last_4_years_by_facility_code
        WHERE 
            (facility_used_by_id = COALESCE(@facility_used_by_id, facility_used_by_id))
            AND (facility_used_by_report_group_id = COALESCE(@report_group_id, facility_used_by_report_group_id))
            AND facility_lender = @facility_lender
        GROUP BY year_month;

        INSERT INTO @Payments (year_month, advance, advance_count)
        SELECT 
            year_month, 
            SUM(advance) AS advance, 
            SUM(advance_count) AS advance_count
        FROM dbo.get_account_paid_last_4_years_by_facility_code
        WHERE 
            (facility_used_by_id = COALESCE(@facility_used_by_id, facility_used_by_id))
            AND (facility_used_by_report_group_id = COALESCE(@report_group_id, facility_used_by_report_group_id))
            AND facility_lender = @facility_lender
        GROUP BY year_month;
    END

    -- Create a temp table for final results
    CREATE TABLE #Results (
        year_month NVARCHAR(7) PRIMARY KEY,
        accept_val DECIMAL(18,2) NULL,
        accept_average DECIMAL(18,2) NULL, -- Renamed from `aov`
        proposed INT NULL,
        accept INT NULL,
        accept_rate INT NULL,
        advance DECIMAL(18,2) NULL,
        advance_count INT NULL,
        advance_average DECIMAL(18,2) NULL
    );

    -- Ensure all `year_month` values exist in the results table
    INSERT INTO #Results (year_month)
    SELECT DISTINCT year_month 
    FROM dbo.moment
    WHERE 
        (@rolling_12_months = 1 AND moment.year_month BETWEEN 
            FORMAT(DATEADD(MONTH, -12, GETDATE()), 'yyyy-MM') -- Start 12 months ago
            AND FORMAT(DATEADD(MONTH, -1, GETDATE()), 'yyyy-MM') -- End at last month
        ) 
        OR 
        (@rolling_12_months = 0 AND moment.year >= YEAR(GETDATE()) - 3);

    -- Update #Results with application data
    UPDATE r
    SET 
        r.accept_val = a.accept_val,
        r.accept_average = CASE WHEN a.accept > 0 THEN a.accept_val / NULLIF(a.accept, 0) ELSE NULL END,
        r.proposed = a.accept + a.decline,
        r.accept = a.accept,
        r.accept_rate = CASE 
            WHEN (a.accept + a.decline) > 0 
            THEN CAST(a.accept * 100.0 / NULLIF(a.accept + a.decline, 0) AS INT)
            ELSE NULL 
        END
    FROM #Results r
    LEFT JOIN @Applications a
        ON r.year_month = a.year_month;

    -- Update #Results with payment data
    UPDATE r
    SET 
        r.advance = p.advance,
        r.advance_count = p.advance_count,
        r.advance_average = CASE 
            WHEN p.advance_count > 0 
            THEN p.advance / NULLIF(p.advance_count, 0)
            ELSE NULL 
        END
    FROM #Results r
    LEFT JOIN @Payments p
        ON r.year_month = p.year_month;

    -- **Final Output with Correct Column Order**
    SELECT 
        @report_name AS report_name,
        year_month, 
        proposed, 
        accept, 
        '£' + FORMAT(accept_val, 'N0') AS accept_val, 
        '£' + FORMAT(accept_average, 'N0') AS accept_average, 
        CAST(accept_rate AS NVARCHAR) + '%' AS accept_rate, 
        advance_count, 
        '£' + FORMAT(advance, 'N0') AS advance, 
        '£' + FORMAT(advance_average, 'N0') AS advance_average
    FROM #Results

    -- **Union with Totals Row (only if @include_totals = 1)**
    UNION ALL
    SELECT 
        @report_name AS report_name,
        'TOTAL', 
        SUM(proposed), 
        SUM(accept), 
        '£' + FORMAT(SUM(accept_val), 'N0'), 
        '£' + FORMAT(SUM(accept_val) / NULLIF(SUM(accept), 0), 'N0'), 
        CAST(SUM(accept) * 100 / NULLIF(SUM(proposed), 0) AS NVARCHAR) + '%', 
        SUM(advance_count), 
        '£' + FORMAT(SUM(advance), 'N0'), 
        '£' + FORMAT(SUM(advance) / NULLIF(SUM(advance_count), 0), 'N0')
    FROM #Results
    WHERE @include_totals = 1

    ORDER BY year_month;

    -- Cleanup
    DROP TABLE #Results;
END;
GO
