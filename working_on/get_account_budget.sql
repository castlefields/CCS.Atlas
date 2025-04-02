CREATE OR ALTER VIEW [dbo].[get_account_budget]
AS
    WITH
        MonthlyBudgets
        AS
        (
            SELECT 
                a.facility_used_by_id,
                a.facility_used_by_report_group_id,
                b.year,
                b.lender as facility_lender,
                -- Q1 months (Jan-Mar)
                CASE WHEN m.month BETWEEN 1 AND 3 THEN MAX(b.q1) / 3.0 ELSE 0 END as q1_monthly,
                -- Q2 months (Apr-Jun)
                CASE WHEN m.month BETWEEN 4 AND 6 THEN MAX(b.q2) / 3.0 ELSE 0 END as q2_monthly,
                -- Q3 months (Jul-Sep)
                CASE WHEN m.month BETWEEN 7 AND 9 THEN MAX(b.q3) / 3.0 ELSE 0 END as q3_monthly,
                -- Q4 months (Oct-Dec)
                CASE WHEN m.month BETWEEN 10 AND 12 THEN MAX(b.q4) / 3.0 ELSE 0 END as q4_monthly,
                m.month,
                (m.month - 1) / 3 + 1 as quarter,
                CAST(b.year AS NVARCHAR(4)) + '-' + CAST((m.month - 1) / 3 + 1 AS NVARCHAR) as year_quarter
            FROM dbo.account a
            INNER JOIN dbo.paid_budget b ON a.facility_used_by_id = b.account_id
            CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) AS m(month)
            WHERE a.facility_used_by_id = '178a2d56-2e0a-e711-80e3-1458d043b558'
            GROUP BY 
                a.facility_used_by_id, 
                a.facility_used_by_report_group_id,
                b.year,
                b.lender,
                m.month,
                (m.month - 1) / 3 + 1,
                CAST(b.year AS NVARCHAR(4)) + '-' + CAST((m.month - 1) / 3 + 1 AS NVARCHAR)
        )
    SELECT
        facility_used_by_report_group_id,
        facility_used_by_id,
        facility_lender,
        CAST(year AS NVARCHAR(4)) + '-' + RIGHT('0' + CAST(month AS NVARCHAR(2)), 2) as year_month,
        year,
        month,
        quarter,
        year_quarter,
        q1_monthly + q2_monthly + q3_monthly + q4_monthly as budget
    FROM MonthlyBudgets;