@echo off
echo ===============================================
echo Step 2: Running all test cases for the procedures
echo ===============================================
echo.
echo Database: atlas on ccs-reporting.database.windows.net
echo Running tests for all stored procedures in code folder...
echo.

echo Creating results folders for each stored procedure...
echo.

echo Starting tests...
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\run_tests.ps1"

echo.
echo Press any key to continue...
pause > nul