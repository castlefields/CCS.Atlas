@echo off
echo ===================================================
echo Step 1: Checking database connection and procedures
echo ===================================================
echo.
echo Checking connection to atlas database on ccs-reporting.database.windows.net...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0scripts\db_connection_test.ps1"

echo.
echo Press any key to continue...
pause > nul
