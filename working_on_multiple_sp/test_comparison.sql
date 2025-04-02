-- This script tests that the new modular approach produces the same results as the original stored procedure
-- We'll test with various parameter combinations and compare the results

-- Test Case 1: Default parameters (L12M, year_month grouping)
PRINT 'Test Case 1: Default parameters';

-- Create a temp table to hold original results
CREATE TABLE #OriginalResults1 (
    report_name NVARCHAR(255),
    moment NVARCHAR(7),
    ecof_count INT,
    ecof_advance DECIMAL(18,2),
    proposed_count INT,
    accept_count INT,
    accept_val DECIMAL(18,2),
    accept_avg DECIMAL(18,2),
    accept_rate DECIMAL(18,6),
    decline_count INT,
    pending_count INT,
    advance_count INT,
    advance_val DECIMAL(18,2),
    advance_avg DECIMAL(18,2),
    commission_val DECIMAL(18,2),
    commission_rate_avg DECIMAL(18,4),
    budget DECIMAL(18,2),
    budget_rate DECIMAL(18,6)
);

-- Create a temp table to hold new results
CREATE TABLE #NewResults1 (
    report_name NVARCHAR(255),
    moment NVARCHAR(7),
    ecof_count INT,
    ecof_advance DECIMAL(18,2),
    proposed_count INT,
    accept_count INT,
    accept_val DECIMAL(18,2),
    accept_avg DECIMAL(18,2),
    accept_rate DECIMAL(18,6),
    decline_count INT,
    pending_count INT,
    advance_count INT,
    advance_val DECIMAL(18,2),
    advance_avg DECIMAL(18,2),
    commission_val DECIMAL(18,2),
    commission_rate_avg DECIMAL(18,4),
    budget DECIMAL(18,2),
    budget_rate DECIMAL(18,6)
);

-- Execute the original stored procedure
INSERT INTO #OriginalResults1
EXEC dbo.rpt_mth_account_ecof_application_paid_0401_2135;

-- Execute the new modular stored procedure
INSERT INTO #NewResults1
EXEC dbo.rpt_mth_account_ecof_application_paid;

-- Compare results
SELECT 
    'Differences in Test Case 1' AS TestCase,
    COUNT(*) AS DifferenceCount
FROM (
    SELECT report_name, moment FROM #OriginalResults1
    EXCEPT
    SELECT report_name, moment FROM #NewResults1
    UNION ALL
    SELECT report_name, moment FROM #NewResults1
    EXCEPT
    SELECT report_name, moment FROM #OriginalResults1
) AS Diff;

-- Report any differences in the detail rows
IF EXISTS (
    SELECT 1 FROM (
        SELECT report_name, moment FROM #OriginalResults1
        EXCEPT
        SELECT report_name, moment FROM #NewResults1
        UNION ALL
        SELECT report_name, moment FROM #NewResults1
        EXCEPT
        SELECT report_name, moment FROM #OriginalResults1
    ) AS Diff
)
BEGIN
    SELECT 'Original Results' AS Source, * FROM #OriginalResults1
    UNION ALL
    SELECT 'New Results' AS Source, * FROM #NewResults1
    ORDER BY moment, Source;
END

-- Clean up
DROP TABLE #OriginalResults1;
DROP TABLE #NewResults1;

-- Test Case 2: Specific facility with quarterly grouping
PRINT 'Test Case 2: Specific facility with quarterly grouping';

-- Use a known facility ID for testing
DECLARE @test_facility_id UNIQUEIDENTIFIER = '178a2d56-2e0a-e711-80e3-1458d043b558'; -- Example ID, replace with a valid one

-- Create temp tables for results
CREATE TABLE #OriginalResults2 (
    report_name NVARCHAR(255),
    moment NVARCHAR(7),
    ecof_count INT,
    ecof_advance DECIMAL(18,2),
    proposed_count INT,
    accept_count INT,
    accept_val DECIMAL(18,2),
    accept_avg DECIMAL(18,2),
    accept_rate DECIMAL(18,6),
    decline_count INT,
    pending_count INT,
    advance_count INT,
    advance_val DECIMAL(18,2),
    advance_avg DECIMAL(18,2),
    commission_val DECIMAL(18,2),
    commission_rate_avg DECIMAL(18,4),
    budget DECIMAL(18,2),
    budget_rate DECIMAL(18,6)
);

CREATE TABLE #NewResults2 (
    report_name NVARCHAR(255),
    moment NVARCHAR(7),
    ecof_count INT,
    ecof_advance DECIMAL(18,2),
    proposed_count INT,
    accept_count INT,
    accept_val DECIMAL(18,2),
    accept_avg DECIMAL(18,2),
    accept_rate DECIMAL(18,6),
    decline_count INT,
    pending_count INT,
    advance_count INT,
    advance_val DECIMAL(18,2),
    advance_avg DECIMAL(18,2),
    commission_val DECIMAL(18,2),
    commission_rate_avg DECIMAL(18,4),
    budget DECIMAL(18,2),
    budget_rate DECIMAL(18,6)
);

-- Execute the original stored procedure
INSERT INTO #OriginalResults2
EXEC dbo.rpt_mth_account_ecof_application_paid_0401_2135 
    @facility_used_by_id = @test_facility_id, 
    @group_by = 'year_quarter';

-- Execute the new modular stored procedure
INSERT INTO #NewResults2
EXEC dbo.rpt_mth_account_ecof_application_paid 
    @facility_used_by_id = @test_facility_id, 
    @group_by = 'year_quarter';

-- Compare results
SELECT 
    'Differences in Test Case 2' AS TestCase,
    COUNT(*) AS DifferenceCount
FROM (
    SELECT report_name, moment FROM #OriginalResults2
    EXCEPT
    SELECT report_name, moment FROM #NewResults2
    UNION ALL
    SELECT report_name, moment FROM #NewResults2
    EXCEPT
    SELECT report_name, moment FROM #OriginalResults2
) AS Diff;

-- Report any differences in the detail rows
IF EXISTS (
    SELECT 1 FROM (
        SELECT report_name, moment FROM #OriginalResults2
        EXCEPT
        SELECT report_name, moment FROM #NewResults2
        UNION ALL
        SELECT report_name, moment FROM #NewResults2
        EXCEPT
        SELECT report_name, moment FROM #OriginalResults2
    ) AS Diff
)
BEGIN
    SELECT 'Original Results' AS Source, * FROM #OriginalResults2
    UNION ALL
    SELECT 'New Results' AS Source, * FROM #NewResults2
    ORDER BY moment, Source;
END

-- Clean up
DROP TABLE #OriginalResults2;
DROP TABLE #NewResults2;

PRINT 'Test completed.';
