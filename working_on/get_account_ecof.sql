SELECT        TOP (100) PERCENT a.facility_used_by_report_group_id AS report_group_id, a.facility_used_by_report_group, a.facility_used_by_id, a.facility_used_by_legal_name, v.selected_lender AS facility_lender, COUNT(v.doc_type) 
                         AS ecof_count, SUM(v.selected_balance) AS ecof_advance, CAST(v.year AS VARCHAR) + '-' + RIGHT('0' + CAST(v.month AS VARCHAR), 2) AS year_month
FROM            dbo.vw_ecof_all AS v INNER JOIN
                         dbo.account_ecof AS ae ON v.company_key = ae.ecof_key INNER JOIN
                             (SELECT DISTINCT account_id, facility_used_by_report_group_id, facility_used_by_report_group, facility_used_by_id, facility_used_by_legal_name
                               FROM            dbo.account) AS a ON ae.account_id = a.account_id
WHERE        (v.selected_funding_option <> N'cash')
GROUP BY CAST(v.year AS VARCHAR) + '-' + RIGHT('0' + CAST(v.month AS VARCHAR), 2), a.facility_used_by_id, a.facility_used_by_legal_name, a.facility_used_by_report_group_id, a.facility_used_by_report_group, v.selected_lender