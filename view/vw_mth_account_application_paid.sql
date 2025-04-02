CREATE OR ALTER VIEW dbo.vw_mth_account_application_paid
AS
WITH DistinctLenders AS (
    SELECT DISTINCT facility_lender, facility_used_by_id
    FROM dbo.account
),
DistinctApplicationData AS (
    SELECT
        dl.facility_lender,
        dl.facility_used_by_id,
        m.year,
        m.month,
        a.legal_name,
        a.trading_style,
        a.is_reporting,
        SUM(ISNULL(data.decline, 0)) AS decline,
        SUM(ISNULL(data.accept, 0)) AS accept,
        SUM(ISNULL(data.accept_val, 0)) AS accept_val,
        SUM(ISNULL(data.pending, 0)) AS pending
    FROM DistinctLenders dl
    CROSS JOIN dbo.moment m
    LEFT JOIN dbo.account a
        ON a.facility_lender = dl.facility_lender
        AND a.facility_used_by_id = dl.facility_used_by_id
    LEFT JOIN dbo.application_mth data
        ON a.facility_code = data.facility_code
        AND m.year = data.year
        AND m.month = data.month
    WHERE (m.year = 2025 AND m.month = 1)
       OR (m.year = 2024 AND m.month = 12)
    GROUP BY
        dl.facility_lender,
        dl.facility_used_by_id,
        m.year,
        m.month,
        a.legal_name,
        a.trading_style,
        a.is_reporting
),
ApplicationDataSummary AS (
    SELECT 
        facility_lender, 
        year, 
        month, 
        CAST(year AS VARCHAR) + '-' + RIGHT('0' + CAST(month AS VARCHAR), 2) AS year_month,
        legal_name, 
        trading_style, 
        facility_used_by_id, 
        is_reporting,
        SUM(decline) AS decline, 
        SUM(accept) AS accept, 
        SUM(accept_val) AS accept_val, 
        SUM(pending) AS pending,
        SUM(accept) + SUM(decline) AS proposed,
        CONCAT(
            CAST(SUM(accept) + SUM(decline) AS VARCHAR), 
            CASE 
                WHEN SUM(pending) > 0 
                THEN CONCAT(' (+', CAST(SUM(pending) AS VARCHAR), ' Ref)') 
                ELSE ''
            END
        ) AS proposed_text,
        CASE 
            WHEN SUM(accept) + SUM(decline) = 0 
            THEN 'N/A'
            ELSE CONCAT(
                CAST(
                    ROUND(
                        CAST(SUM(accept) AS FLOAT) / 
                        NULLIF(CAST((SUM(accept) + SUM(decline)) AS FLOAT), 0) * 100, 0)
                    AS VARCHAR), '%') 
        END AS accept_rate,
        CONCAT('£', FORMAT(SUM(accept_val), 'N0')) AS accept_val_text
    FROM DistinctApplicationData
    GROUP BY 
        facility_lender, 
        year, 
        month, 
        legal_name, 
        trading_style, 
        facility_used_by_id, 
        is_reporting
),
PaidData AS (
    SELECT
        dl.facility_lender,
        dl.facility_used_by_id,
        m.year,
        m.month,
        SUM(DISTINCT p.advance) AS advance_total,
        COUNT(DISTINCT p.id) AS advance_count
    FROM DistinctLenders dl
    CROSS JOIN dbo.moment m
    LEFT JOIN dbo.account a
        ON a.facility_lender = dl.facility_lender
        AND a.facility_used_by_id = dl.facility_used_by_id
    LEFT JOIN dbo.paid_mth p
        ON a.facility_code = p.facility_code
        AND p.year = m.year
        AND p.month = m.month
    WHERE (m.year = 2025 AND m.month = 1)
       OR (m.year = 2024 AND m.month = 12)
    GROUP BY dl.facility_lender, dl.facility_used_by_id, m.year, m.month
),
PaidDataSummary AS (
    SELECT 
        facility_lender,
        year,
        month,
        CAST(year AS VARCHAR) + '-' + RIGHT('0' + CAST(month AS VARCHAR), 2) AS year_month,
        ISNULL(advance_total, 0) AS advance_total,
        ISNULL(advance_count, 0) AS advance_count,
        CONCAT('£', FORMAT(ISNULL(advance_total, 0), 'N0')) AS advance_text
    FROM PaidData
)
-- Merge the two result sets on facility_lender and year_month
SELECT 
    a.facility_lender,
    a.year_month,
    a.legal_name,
    a.trading_style,
    a.facility_used_by_id,
    a.is_reporting,
    a.decline,
    a.accept,
    a.accept_val,
    a.pending,
    a.proposed,
    a.proposed_text,
    a.accept_rate,
    a.accept_val_text,
    p.advance_total,
    p.advance_count,
    p.advance_text,
    -- New Conversion Column (as percentage)
    CASE 
        WHEN a.proposed = 0 THEN 0 -- Handle division by zero
        ELSE ROUND(CAST(p.advance_count AS FLOAT) / NULLIF(CAST(a.proposed AS FLOAT), 0) * 100, 0)
    END AS conversion,
    -- New Conversion Text Column (formatted as 77%)
    CASE 
        WHEN a.proposed = 0 THEN 'N/A' -- Handle division by zero
        ELSE CONCAT(
            CAST(
                ROUND(CAST(p.advance_count AS FLOAT) / NULLIF(CAST(a.proposed AS FLOAT), 0) * 100, 0)
            AS VARCHAR), '%')
    END AS conversion_text
FROM ApplicationDataSummary a
LEFT JOIN PaidDataSummary p
    ON a.facility_lender = p.facility_lender
    AND a.year_month = p.year_month;