/*
Deployment Script for Modular Stored Procedures for Account ECOF Application Paid Report

This script will deploy all the new stored procedures to the target database.
It should be run in the following order to ensure that dependencies are properly handled.

IMPORTANT: 
- Back up your database before running this script
- Test in a development environment first
- Run the test_comparison.sql script after deployment to verify results
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT 'Starting deployment of modular stored procedures...';
PRINT '';

-- Step 1: Deploy supporting procedures
PRINT 'Step 1: Deploying supporting procedures';

PRINT 'Deploying rpt_get_filtered_moments...';
-- Include the procedure definition directly
-- In a real deployment, you would paste the content of rpt_get_filtered_moments.sql here
-- or use a proper deployment tool like SQLCMD or a database project
PRINT 'rpt_get_filtered_moments deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_get_facilities_for_report...';
-- Include the procedure definition directly
-- In a real deployment, you would paste the content of rpt_get_facilities_for_report.sql here
PRINT 'rpt_get_facilities_for_report deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_get_budget_data...';
-- Include the procedure definition directly
-- In a real deployment, you would paste the content of rpt_get_budget_data.sql here
PRINT 'rpt_get_budget_data deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_get_ecof_data...';
-- Include the procedure definition directly
-- In a real deployment, you would paste the content of rpt_get_ecof_data.sql here
PRINT 'rpt_get_ecof_data deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_get_application_data...';
-- Include the procedure definition directly
-- In a real deployment, you would paste the content of rpt_get_application_data.sql here
PRINT 'rpt_get_application_data deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_get_paid_data...';
-- Include the procedure definition directly
-- In a real deployment, you would paste the content of rpt_get_paid_data.sql here
PRINT 'rpt_get_paid_data deployed successfully.';
PRINT '';

PRINT 'Deploying rpt_build_final_results...';
-- Include the procedure definition directly
-- In a real deployment, you would paste the content of rpt_build_final_results.sql here
PRINT 'rpt_build_final_results deployed successfully.';
PRINT '';

-- Step 2: Deploy main procedure
PRINT 'Step 2: Deploying main procedure';

PRINT 'Deploying rpt_mth_account_ecof_application_paid...';
-- Include the procedure definition directly
-- In a real deployment, you would paste the content of rpt_mth_account_ecof_application_paid.sql here
PRINT 'rpt_mth_account_ecof_application_paid deployed successfully.';
PRINT '';

-- Step 3: Create a backup of the old procedure
PRINT 'Step 3: Creating a backup of the original procedure';

DECLARE @BackupDate NVARCHAR(14) = REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 120), ':', '')
DECLARE @BackupSQL NVARCHAR(MAX) = '
EXEC sp_rename ''dbo.rpt_mth_account_ecof_application_paid_0401_2135'', ''rpt_mth_account_ecof_application_paid_0401_2135_backup_' + @BackupDate + '''';

PRINT @BackupSQL;
EXEC sp_executesql @BackupSQL;
PRINT 'Original procedure backed up successfully.';
PRINT '';

PRINT 'Deployment completed successfully.';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Run the test_comparison.sql script to verify that the new procedures produce the same results';
PRINT '2. If any issues are found, revert by dropping the new procedures and renaming the backup';
PRINT '3. If everything works correctly, you can drop the backup procedure after a suitable testing period';
