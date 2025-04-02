/****** Object:  StoredProcedure [dbo].[rpt_mth_account_application]    Script Date: 19/03/2025 12:17:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER   PROCEDURE [dbo].[rpt_mth_account_application]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    -- Optional filter for specific account
    @report_group_id NVARCHAR(50) = NULL,
    -- Optional filter for report group
    @facility_lender NVARCHAR(50) = NULL
-- Optional filter for specific lender
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

    DECLARE @Paids TABLE (
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

    INSERT INTO @Paids
        (year_month, advance, advance_count)
    SELECT
        year_month,
        SUM(advance) AS advance,
        SUM(advance_count) AS advance_count
    FROM dbo.get_account_paid_last_4_years_by_facility_code
    WHERE
  (facility_used_by_id = COALESCE(@facility_used_by_id, facility_used_by_id))
        AND (facility_used_by_report_group_id = COALESCE(@report_group_id, facility_used_by_report_group_id))
        AND (facility_lender = COALESCE(@facility_lender, facility_lender))
    GROUP BY
  year_month;

    IF @facility_lender IS NULL
    BEGIN
        INSERT INTO @Applications
            (year_month, accept_val, accept, decline, pending)
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
    END
    ELSE
    BEGIN
        INSERT INTO @Applications
            (year_month, accept_val, accept, decline, pending)
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
    END

    SELECT
        @report_name AS report_name,
        a.year_month,
        a.accept_val,
        a.accept,
        a.decline,
        a.pending,
        proposed,
        accept,
        '£' + FORMAT(accept_val, 'N0') AS accept_val,
        '£' + FORMAT(accept_average, 'N0') AS accept_average,
        CAST(accept_rate AS NVARCHAR) + '%' AS accept_rate,
        a.advance_count,
        '£' + FORMAT(a.advance, 'N0') AS advance,
        '£' + FORMAT(a.advance_average, 'N0') AS advance_average
    FROM
        (
 SELECT
            a.year_month,
            SUM(accept_val) AS accept_val,
            SUM(accept) AS accept,
            SUM(decline) AS decline,
            SUM(pending) AS pending,
            SUM(accept + decline) AS proposed,
            CASE
  WHEN (SUM(accept) + SUM(decline)) > 0 THEN
   CAST(SUM(accept) * 100.0 / NULLIF(SUM(accept) + SUM(decline), 0) AS INT)
  ELSE NULL
  END AS accept_rate,
            CASE
  WHEN SUM(accept) > 0 THEN
   SUM(accept_val) / NULLIF(SUM(accept), 0)
  ELSE NULL
  END AS accept_average,
            SUM(p.advance_count) AS advance_count,
            SUM(p.advance) AS advance,
            CASE
  WHEN SUM(p.advance) > 0 THEN
   SUM(p.advance) / NULLIF(SUM(p.advance_count), 0)
  ELSE NULL
  END AS advance_average
        FROM
            @Applications a
            INNER JOIN @Paids p ON a.year_month = p.year_month
        GROUP BY
  a.year_month
) AS a
    ORDER BY year_month;
END;
