            SET NOCOUNT ON;
            CREATE TABLE #Results (
                report_name NVARCHAR(255),
                moment NVARCHAR(7),
                ecof_count INT,
                ecof_advance DECIMAL(18,2),
                proposed_count INT,
                accept_count INT,
                accept_val DECIMAL(18,2),
                accept_avg DECIMAL(18,2),
                accept_rate DECIMAL(18,6),
                decline_count INT,
                pending_count INT,
                advance_count INT,
                advance_val DECIMAL(18,2),
                advance_avg DECIMAL(18,2),
                commission_val DECIMAL(18,2),
                commission_rate_avg DECIMAL(18,4),
                budget DECIMAL(18,2),
                budget_rate DECIMAL(18,6)
            );

            INSERT INTO #Results
            EXEC [dbo].[rpt_mth_account_ecof_application_paid_0331_1527]
                @facility_used_by_id = '178a2d56-2e0a-e711-80e3-1458d043b558',
                @report_group_id = NULL,
                @facility_lender = 'novuna',
                @period = 'L12M',
                @group_by = 'year_month';

            SELECT * FROM #Results
            ORDER BY moment;

            DROP TABLE #Results;
