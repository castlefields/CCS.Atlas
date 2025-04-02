SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[paid_mth](
	[id] [int] NOT NULL,
	[lender_id] [tinyint] NULL,
	[facility_code] [varchar](15) NULL,
	[upload_legal_name] [nvarchar](50) NULL,
	[product_code] [nvarchar](15) NULL,
	[defer_by] [int] NULL,
	[apr] [decimal](18, 10) NULL,
	[term] [int] NULL,
	[advance] [decimal](10, 0) NULL,
	[date] [datetime] NULL,
	[return_rate] [decimal](10, 4) NULL,
	[month] [int] NULL,
	[year] [int] NULL,
	[upload_date] [datetime] NULL,
	[year_month]  AS ((CONVERT([varchar](4),[year])+'-')+right('0'+CONVERT([varchar](2),[month]),(2))) PERSISTED
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [IX_paid_mth_facility_code] ON [dbo].[paid_mth]
(
	[facility_code] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [IX_paid_mth_product_code] ON [dbo].[paid_mth]
(
	[product_code] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_paid_mth_year_month] ON [dbo].[paid_mth]
(
	[year] ASC,
	[month] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
CREATE NONCLUSTERED INDEX [IX_paid_mth_year_month_computed] ON [dbo].[paid_mth]
(
	[year_month] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, DROP_EXISTING = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
