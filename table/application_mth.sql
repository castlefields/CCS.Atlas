SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER TABLE [dbo].[application_mth]
ADD [year_month]  AS (CONVERT(VARCHAR(7), [upload_date], 126))
GO

CREATE NONCLUSTERED INDEX IX_application_mth_year_month
ON [dbo].[application_mth] ([year_month])
GO
