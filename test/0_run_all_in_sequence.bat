@echo off
echo ===================================================================
echo Budget Calculation Test Suite for Stored Procedures
echo ===================================================================
echo This script will run all test steps in sequence.
echo.
echo Press any key to start testing...
pause > nul

call "%~dp01_check_db_connection.bat"
call "%~dp02_run_all_tests.bat"
call "%~dp03_compare_results.bat"

echo All tests completed!