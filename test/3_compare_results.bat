@echo off
echo =============================================
echo Step 3: Compare test results across procedures
echo =============================================
echo.
echo This tool automatically compares test results with the same ID
echo across different stored procedure versions.
echo.
echo Key features:
echo - Auto-compares test results with the same ID across all procedure folders
echo - Creates a summary comparison report in the results folder
echo - Allows manual selection of specific files to compare
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0scripts\compare_results.ps1"

echo.
echo Press any key to exit...
pause > nul