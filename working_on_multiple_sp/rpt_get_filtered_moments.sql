/****** Object:  StoredProcedure [dbo].[rpt_get_filtered_moments]    Script Date: 01/04/2025 21:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[rpt_get_filtered_moments]
    @period NVARCHAR(10) = NULL
AS
BEGIN
    -- This procedure returns a table of filtered dates based on the specified period
    
    IF @period IS NOT NULL
    BEGIN
        -- Use dynamic SQL to call the appropriate period view
        DECLARE @sql NVARCHAR(MAX) = N'
        SELECT year_month, year, month, quarter, year_quarter 
        FROM dbo.get_moment_' + @period;
        
        EXEC sp_executesql @sql;
    END
    ELSE
    BEGIN
        -- If @period is NULL, include all year_month values from the data
        SELECT DISTINCT
            year_month,
            CAST(LEFT(year_month, 4) AS INT) AS year,
            CAST(RIGHT(year_month, 2) AS INT) AS month,
            (CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1 AS quarter,
            LEFT(year_month, 4) + '-' + CAST(((CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1) AS NVARCHAR) AS year_quarter
        FROM dbo.get_account_application_last_4_years_by_facility_code
        
        UNION
        
        SELECT DISTINCT
            year_month,
            CAST(LEFT(year_month, 4) AS INT) AS year,
            CAST(RIGHT(year_month, 2) AS INT) AS month,
            (CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1 AS quarter,
            LEFT(year_month, 4) + '-' + CAST(((CAST(RIGHT(year_month, 2) AS INT) - 1) / 3 + 1) AS NVARCHAR) AS year_quarter
        FROM dbo.get_account_paid_last_4_years_by_facility_code
        WHERE year_month NOT IN (
            SELECT DISTINCT year_month
            FROM dbo.get_account_application_last_4_years_by_facility_code
        );
    END
END;