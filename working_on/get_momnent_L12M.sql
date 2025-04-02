SELECT DISTINCT TOP (12) year_month, year, month, quarter, year_quarter
FROM            dbo.moment
WHERE        (date >= DATEADD(month, - 12, DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0))) AND (date < DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0))