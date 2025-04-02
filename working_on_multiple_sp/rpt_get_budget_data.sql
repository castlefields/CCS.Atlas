/****** Object:  StoredProcedure [dbo].[rpt_get_budget_data]    Script Date: 01/04/2025 21:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_budget_data]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL,
    @facility_lender NVARCHAR(50) = NULL
AS
BEGIN
    -- This procedure retrieves and aggregates budget data
    
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get budget data for each facility in the group
        SELECT
            b.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            b.facility_used_by_id,
            SUM(b.budget) AS budget
        FROM dbo.get_account_budget b
            INNER JOIN #FilteredMoments m ON b.year_month = m.year_month
            INNER JOIN #Facilities f ON b.facility_used_by_id = f.facility_used_by_id
        WHERE b.facility_used_by_report_group_id = @report_group_id
            AND (@facility_lender IS NULL OR UPPER(b.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            b.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            b.facility_used_by_id;
    END
    ELSE
    BEGIN
        -- Traditional Mode - Get budget data based on facility_used_by_id
        SELECT
            b.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            b.facility_used_by_id,
            SUM(b.budget) AS budget
        FROM dbo.get_account_budget b
            INNER JOIN #FilteredMoments m ON b.year_month = m.year_month
        WHERE (@facility_used_by_id IS NULL OR b.facility_used_by_id = @facility_used_by_id)
            AND (@facility_lender IS NULL OR UPPER(b.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            b.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            b.facility_used_by_id;
    END;
END;