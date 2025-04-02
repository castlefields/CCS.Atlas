SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[log_global](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[applicationName] [varchar](50) NOT NULL,
	[logType] [varchar](20) NOT NULL,
	[message] [nvarchar](max) NULL,
	[innerExceptionMessage] [nvarchar](max) NULL,
	[stackTrace] [nvarchar](max) NULL,
	[path] [varchar](300) NULL,
	[httpMethod] [nchar](10) NULL,
	[requestPayload] [nvarchar](max) NULL,
	[responsePayload] [nvarchar](max) NULL,
	[dateCreated] [datetime2](7) NOT NULL,
	[day] [int] NOT NULL,
	[month] [int] NOT NULL,
	[year] [int] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[log_global] ADD  CONSTRAINT [PK_log] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[log_global] ADD  CONSTRAINT [DF_log_dateCreated]  DEFAULT (getdate()) FOR [dateCreated]
GO
ALTER TABLE [dbo].[log_global] ADD  CONSTRAINT [DF_log_day]  DEFAULT (datepart(dayofyear,getdate())) FOR [day]
GO
ALTER TABLE [dbo].[log_global] ADD  CONSTRAINT [DF_log_month]  DEFAULT (datepart(month,getdate())) FOR [month]
GO
ALTER TABLE [dbo].[log_global] ADD  CONSTRAINT [DF_log_year]  DEFAULT (datepart(year,getdate())) FOR [year]
GO
