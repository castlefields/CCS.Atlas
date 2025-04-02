# Testing Framework for Budget Calculation in Stored Procedures

This folder contains scripts to test the budget calculation functionality in stored procedures. The system is designed to automatically test all SQL stored procedures found in the `/code` folder.

## Usage Instructions

Run these batch files in sequence:

1. **1_check_db_connection.bat** - Verifies connection to the Atlas database and shows available stored procedures
2. **2_run_all_tests.bat** - Automatically runs all test cases for each stored procedure in the `/code` folder
3. **3_compare_results.bat** - Automatically compares test results with the same ID across different procedure versions

Alternatively, run `0_run_all_in_sequence.bat` to execute all steps in order.

## How It Works

### Testing Process
1. The system identifies all `.sql` files in the `/code` folder
2. For each stored procedure, it creates a dedicated results folder with the same name
3. It runs all test cases defined in `test_parameters.csv` against each procedure
4. It saves the results in the appropriate procedure-specific folder

### Comparison Process
1. The comparison tool finds all procedure folders in the `/results` directory
2. It identifies test results with the same test ID across different procedure folders
3. It compares these results and highlights key differences in budget calculations
4. It generates a summary report in the root of the `/results` folder

## Test Parameters

The `test_parameters.csv` file in the root test folder contains various parameter combinations:

- Tests with different facility IDs (Brackenwood Windows)
- Tests with different lenders (Novuna, Omni)
- Tests with different grouping levels (month, quarter, year)
- Tests with different time periods (L12M, P12M, C12M)

## Result Files

All test results are stored in the `/results/[procedure_name]` folders:
- `test_X_result.csv` - The data returned by the stored procedure
- `test_X_query.sql` - The SQL query used to call the procedure

Comparison files are stored in the root `/results` folder:
- `comparison_summary.txt` - Overview of all test comparisons across procedures
- `comparison_X_proc1_vs_proc2.txt` - Detailed comparison of a specific test across two procedures

## Modifying Tests

To add new test cases, edit the `test_parameters.csv` file in the root test folder and add new rows with different parameter combinations.

To test a new stored procedure, simply add the SQL file to the `/code` folder and run the test scripts.
