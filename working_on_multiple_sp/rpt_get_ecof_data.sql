/****** Object:  StoredProcedure [dbo].[rpt_get_ecof_data]    Script Date: 01/04/2025 21:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_ecof_data]
    @facility_used_by_id UNIQUEIDENTIFIER = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL,
    @facility_lender NVARCHAR(50) = NULL
AS
BEGIN
    -- This procedure retrieves and aggregates ECOF (Electronic Confirmation of Facility) data
    
    IF @report_group_id IS NOT NULL
    BEGIN
        -- Report Group Mode - Get ecof data for each facility in the group
        SELECT
            e.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            e.facility_used_by_id,
            SUM(e.ecof_count) AS ecof_count,
            SUM(e.ecof_advance) AS ecof_advance
        FROM dbo.get_account_ecof e
            INNER JOIN #FilteredMoments m ON e.year_month = m.year_month
            INNER JOIN #Facilities f ON e.facility_used_by_id = f.facility_used_by_id
        WHERE e.report_group_id = @report_group_id
            AND (@facility_lender IS NULL OR UPPER(e.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            e.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            e.facility_used_by_id;
    END
    ELSE
    BEGIN
        -- Traditional Mode - Get ecof data based on facility_used_by_id
        SELECT
            e.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            e.facility_used_by_id,
            SUM(e.ecof_count) AS ecof_count,
            SUM(e.ecof_advance) AS ecof_advance
        FROM dbo.get_account_ecof e
            INNER JOIN #FilteredMoments m ON e.year_month = m.year_month
        WHERE (@facility_used_by_id IS NULL OR e.facility_used_by_id = @facility_used_by_id)
            AND (@facility_lender IS NULL OR UPPER(e.facility_lender) = UPPER(@facility_lender))
        GROUP BY 
            e.year_month,
            m.year,
            m.month,
            m.quarter,
            m.year_quarter,
            e.facility_used_by_id;
    END;
END;