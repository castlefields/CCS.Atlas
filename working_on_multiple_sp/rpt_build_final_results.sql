/****** Object:  StoredProcedure [dbo].[rpt_build_final_results]    Script Date: 01/04/2025 21:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_build_final_results]
    @facility_lender NVARCHAR(50) = NULL,
    @report_group_id UNIQUEIDENTIFIER = NULL,
    @group_by NVARCHAR(50) = 'year_month',
    @Results NVARCHAR(128) = '#Results' -- Name of the results table to populate
AS
BEGIN
    -- This procedure combines all data sets and builds the final results
    
    -- Build and execute the dynamic SQL to populate the results table
    DECLARE @sql NVARCHAR(MAX) = N'
    INSERT INTO ' + @Results + '
    SELECT
        f.facility_used_by_name + '' : '' + COALESCE(@facility_lender, ''All'') AS report_name,
        m.' + @group_by + ' AS moment,
        SUM(result.ecof_count) AS ecof_count,
        SUM(result.ecof_advance) AS ecof_advance,
        SUM(result.proposed) AS proposed_count,
        SUM(result.accept) AS accept_count,
        SUM(result.accept_val) AS accept_val,
        CASE WHEN SUM(result.accept) > 0 THEN SUM(result.accept_val) / NULLIF(SUM(result.accept), 0) END AS accept_avg,
        CASE WHEN SUM(result.accept + result.decline) > 0 THEN CAST(SUM(result.accept) * 1.0 / NULLIF(SUM(result.accept + result.decline), 0) AS DECIMAL(18,6)) END AS accept_rate,
        SUM(result.decline) AS decline_count,
        SUM(result.pending) AS pending_count,
        SUM(result.advance_count) AS advance_count,
        SUM(result.advance) AS advance_val,
        CASE WHEN SUM(result.advance_count) > 0 THEN SUM(result.advance) / NULLIF(SUM(result.advance_count), 0) END AS advance_avg,
        SUM(result.commission) AS commission_val,
        CASE WHEN SUM(result.advance) > 0 THEN SUM(result.commission) / NULLIF(SUM(result.advance), 0) END AS commission_rate_avg,
        SUM(result.budget) AS budget,
        CASE WHEN SUM(result.budget) > 0 THEN CAST(SUM(result.advance) * 1.0 / NULLIF(SUM(result.budget), 0) AS DECIMAL(18,6)) END AS budget_rate
    FROM
        #FilteredMoments m
        CROSS JOIN #Facilities f
        LEFT JOIN (
        SELECT
            a.year_month,
            a.year,
            a.month,
            a.quarter,
            a.year_quarter,
            a.facility_used_by_id,
            SUM(a.accept_val) AS accept_val,
            SUM(a.accept) AS accept,
            SUM(a.decline) AS decline,
            SUM(a.pending) AS pending,
            SUM(a.accept + a.decline) AS proposed,
            SUM(p.advance_count) AS advance_count,
            SUM(p.advance) AS advance,
            SUM(p.commission) AS commission,
            SUM(e.ecof_count) AS ecof_count,
            SUM(e.ecof_advance) AS ecof_advance,
            SUM(b.budget) AS budget
        FROM
            #Applications a
            LEFT JOIN #Paids p ON a.year_month = p.year_month AND (a.facility_used_by_id = p.facility_used_by_id OR (a.facility_used_by_id IS NULL AND p.facility_used_by_id IS NULL))
            LEFT JOIN #Ecof e ON a.year_month = e.year_month AND (a.facility_used_by_id = e.facility_used_by_id OR (a.facility_used_by_id IS NULL AND e.facility_used_by_id IS NULL))
            LEFT JOIN #Budget b ON a.year_month = b.year_month AND (a.facility_used_by_id = b.facility_used_by_id OR (a.facility_used_by_id IS NULL AND b.facility_used_by_id IS NULL))
        GROUP BY
            a.year_month,
            a.year,
            a.month,
            a.quarter,
            a.year_quarter,
            a.facility_used_by_id
    ) AS result ON m.' + @group_by + ' = result.' + @group_by + ' AND (f.facility_used_by_id = result.facility_used_by_id OR (f.facility_used_by_id IS NULL AND result.facility_used_by_id IS NULL))
    GROUP BY
        f.facility_used_by_name,
        m.' + @group_by

    EXEC sp_executesql @sql, N'@facility_lender NVARCHAR(50)', @facility_lender;
END;