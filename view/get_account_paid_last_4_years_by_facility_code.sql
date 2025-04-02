SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER VIEW [dbo].[get_account_paid_last_4_years_by_facility_code]
AS
    SELECT account_id, facility_used_by_id, facility_used_by_business_manager_initials, facility_used_by_report_group_id, facility_used_by_report_group, facility_used_by_legal_name, facility_used_by_trading_style, facility_lender,
        facility_code, SUM(advance) AS advance, COUNT(advance) AS advance_count, month, year, year_month
    FROM dbo.get_account_paid_last_4_years
    GROUP BY account_id, facility_used_by_business_manager_initials, facility_used_by_report_group, facility_used_by_legal_name, facility_used_by_trading_style, facility_lender, facility_code, month, year, year_month, 
                         facility_used_by_report_group_id, facility_used_by_id
GO
