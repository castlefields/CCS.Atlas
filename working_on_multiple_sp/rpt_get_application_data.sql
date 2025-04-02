/****** Object:  StoredProcedure [dbo].[rpt_get_application_data]    Script Date: 01/04/2025 21:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_application_data]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL,
    @facility_lender NVARCHAR(50) = NULL
AS
BEGIN
    -- This procedure retrieves and aggregates application data
    
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get application data for each facility in the group
        SELECT
            a.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            a.facility_used_by_id,
            SUM(a.accept_val) AS accept_val,
            SUM(a.accept) AS accept,
            SUM(a.decline) AS decline,
            SUM(a.pending) AS pending
        FROM dbo.get_account_application_last_4_years_by_facility_code a
            INNER JOIN #FilteredMoments m ON a.year_month = m.year_month
            INNER JOIN #Facilities f ON a.facility_used_by_id = f.facility_used_by_id
        WHERE a.facility_used_by_report_group_id = @report_group_id
            AND (@facility_lender IS NULL OR UPPER(a.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            a.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            a.facility_used_by_id;
    END
    ELSE
    BEGIN
        -- Traditional Mode - Get application data based on facility_used_by_id
        SELECT
            a.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            a.facility_used_by_id,
            SUM(a.accept_val) AS accept_val,
            SUM(a.accept) AS accept,
            SUM(a.decline) AS decline,
            SUM(a.pending) AS pending
        FROM dbo.get_account_application_last_4_years_by_facility_code a
            INNER JOIN #FilteredMoments m ON a.year_month = m.year_month
        WHERE (@facility_used_by_id IS NULL OR a.facility_used_by_id = @facility_used_by_id)
            AND (@facility_lender IS NULL OR UPPER(a.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            a.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            a.facility_used_by_id;
    END;
END;