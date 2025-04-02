SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* Retrieves the last 4 years including the current year*/
ALTER VIEW [dbo].[get_account_application_last_4_years_by_facility_code]
AS
    SELECT account.account_id, account.facility_used_by_id, account.facility_used_by_business_manager_initials, account.facility_used_by_report_group_id, account.facility_used_by_report_group, account.facility_used_by_legal_name,
        account.facility_used_by_trading_style, account.facility_lender, account.facility_code, application_mth.accept, application_mth.accept_val, application_mth.decline, application_mth.decline_val, application_mth.pending,
        application_mth.pending_val, application_mth.month, application_mth.year, moment.year_month
    FROM dbo.account INNER JOIN
        dbo.application_mth ON account.facility_code = application_mth.facility_code INNER JOIN
        dbo.moment ON application_mth.year = moment.year AND application_mth.month = moment.month AND moment.day = 1
    WHERE        (moment.year >= YEAR(GETDATE()) - 3)
GO
