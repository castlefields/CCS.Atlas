# Configuration
$serverInstance = "ccs-reporting.database.windows.net"
$database = "atlas"
$username = "gatekeeper"
$password = "65HWfr7Ada!4Swg9#o2D"

# Base folder paths
$codeFolder = "$PSScriptRoot\..\code"
$baseOutputFolder = "$PSScriptRoot\..\results"

# Read test parameters from CSV
$testCases = Import-Csv -Path "$PSScriptRoot\..\test_parameters.csv"  # From root test folder
Write-Host "Loaded $($testCases.Count) test cases from CSV"

# Function to handle NULL values in CSV
function Format-SqlParameter {
    param($value)
    if ($value -eq "NULL") { return "NULL" }
    return "'$value'"
}

# Function to extract procedure name from SQL file name
function Get-ProcedureNameFromFileName {
    param([string]$fileName)
    return [System.IO.Path]::GetFileNameWithoutExtension($fileName)
}

Write-Host "Testing connection to database..."
try {
    $testQuery = "SELECT DB_NAME() AS [Database];"
    $result = Invoke-Sqlcmd -ServerInstance $serverInstance -Database $database `
        -Username $username -Password $password -Query $testQuery
    
    Write-Host "Connected to database: $($result.Database)" -ForegroundColor Green
    
    # Get all SQL files in the code folder
    $sqlFiles = Get-ChildItem -Path $codeFolder -Filter "*.sql"
    
    if ($sqlFiles.Count -eq 0) {
        Write-Host "No SQL files found in $codeFolder" -ForegroundColor Yellow
        exit
    }
    
    Write-Host "Found $($sqlFiles.Count) SQL files to process" -ForegroundColor Cyan
    
    # Process each SQL file
    foreach ($sqlFile in $sqlFiles) {
        $procedureName = Get-ProcedureNameFromFileName $sqlFile.Name
        Write-Host "`n=============================================" -ForegroundColor Cyan
        Write-Host "Processing stored procedure: $procedureName" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        
        # Create a specific output folder for this procedure
        $procOutputFolder = "$baseOutputFolder\$procedureName"
        if (-not (Test-Path $procOutputFolder)) {
            New-Item -ItemType Directory -Path $procOutputFolder -Force | Out-Null
            Write-Host "Created output folder: $procOutputFolder"
        }
        
        # Find existing stored procedure in the database
        $procQuery = "SELECT name FROM sys.procedures WHERE name = '$procedureName';"
        $proc = Invoke-Sqlcmd -ServerInstance $serverInstance -Database $database `
            -Username $username -Password $password -Query $procQuery
        
        if ($proc -eq $null) {
            Write-Host "Stored procedure '$procedureName' not found in database!" -ForegroundColor Yellow
            Write-Host "Skipping tests for this procedure"
            continue
        }
        
        Write-Host "Found stored procedure in database: $procedureName" -ForegroundColor Green
        
        # Execute each test case for this procedure
        foreach ($test in $testCases) {
            $testIdValue = $test.test_id
            $descriptionValue = $test.description
            $outputFile = "$procOutputFolder\test_${testIdValue}_result.csv"
            
            Write-Host ("Running Test #{0}: {1}" -f $testIdValue, $descriptionValue)
            
            # Format parameters properly for SQL
            $facilityUsedById = Format-SqlParameter $test.facility_used_by_id
            $reportGroupId = Format-SqlParameter $test.report_group_id
            $facilityLender = Format-SqlParameter $test.facility_lender
            $period = Format-SqlParameter $test.period
            $groupBy = Format-SqlParameter $test.group_by
            
            # Build SQL query
            $sqlQuery = @"
            SET NOCOUNT ON;
            CREATE TABLE #Results (
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

            INSERT INTO #Results
            EXEC [dbo].[$procedureName]
                @facility_used_by_id = $facilityUsedById,
                @report_group_id = $reportGroupId,
                @facility_lender = $facilityLender,
                @period = $period,
                @group_by = $groupBy;

            SELECT * FROM #Results
            ORDER BY moment;

            DROP TABLE #Results;
"@

            # Save the SQL query for reference
            $sqlQuery | Out-File -FilePath "$procOutputFolder\test_${testIdValue}_query.sql" -Encoding utf8
            
            # Execute the query and save results to CSV
            try {
                Invoke-Sqlcmd -ServerInstance $serverInstance -Database $database `
                    -Username $username -Password $password `
                    -Query $sqlQuery | Export-Csv -Path $outputFile -NoTypeInformation
                
                Write-Host ("  Results saved to: {0}" -f $outputFile) -ForegroundColor Green
            }
            catch {
                Write-Host ("  Error executing SQL: {0}" -f $_) -ForegroundColor Red
            }
            
            Write-Host ("  SQL query saved to: {0}" -f "$procOutputFolder\test_${testIdValue}_query.sql")
        }
        
        Write-Host "Completed tests for procedure: $procedureName" -ForegroundColor Green
    }
    
    Write-Host "`nAll procedures tested. Check $baseOutputFolder for results." -ForegroundColor Cyan
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}