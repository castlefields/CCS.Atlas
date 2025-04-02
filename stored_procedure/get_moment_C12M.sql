SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER VIEW [dbo].[get_moment_C12M]
AS
    SELECT DISTINCT TOP (100) PERCENT
        year_month, year, month, quarter, year_quarter
    FROM dbo.moment
    WHERE        (YEAR(date) = YEAR(GETDATE()))
    ORDER BY year_month
GO
