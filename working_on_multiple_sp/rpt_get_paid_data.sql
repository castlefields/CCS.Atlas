/****** Object:  StoredProcedure [dbo].[rpt_get_paid_data]    Script Date: 01/04/2025 21:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_paid_data]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL,
    @facility_lender NVARCHAR(50) = NULL
AS
BEGIN
    -- This procedure retrieves and aggregates payment data
    
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get paid data for each facility in the group
        SELECT
            p.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            p.facility_used_by_id,
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
            INNER JOIN #Facilities f ON p.facility_used_by_id = f.facility_used_by_id
        WHERE p.facility_used_by_report_group_id = @report_group_id
            AND (@facility_lender IS NULL OR UPPER(p.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            p.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            p.facility_used_by_id;
    END
    ELSE
    BEGIN
        -- Traditional Mode - Get paid data based on facility_used_by_id
        SELECT
            p.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            p.facility_used_by_id,
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
        WHERE (@facility_used_by_id IS NULL OR p.facility_used_by_id = @facility_used_by_id)
            AND (@facility_lender IS NULL OR UPPER(p.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            p.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            p.facility_used_by_id;
    END;
END;