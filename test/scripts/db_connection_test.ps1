# PowerShell script to check database connection

# Database connection parameters
$serverInstance = 'ccs-reporting.database.windows.net'
$database = 'atlas'
$username = 'gatekeeper'
$password = '65HWfr7Ada!4Swg9#o2D'

Write-Host "Attempting to connect to $database on $serverInstance as $username..."

try {
    # Test the connection with a simple query
    $query = "SELECT DB_NAME() AS [Database], SYSTEM_USER AS [Login];
              SELECT name FROM sys.procedures WHERE name LIKE 'rpt_mth_account_ecof_application_paid%' ORDER BY name;"
    
    Write-Host "Executing test query..."
    $result = Invoke-Sqlcmd -ServerInstance $serverInstance -Database $database -Username $username -Password $password -Query $query -ConnectionTimeout 30
    
    # Display the results
    Write-Host "Connection successful!" -ForegroundColor Green
    Write-Host "`nConnected to database: $($result[0].Database) as $($result[0].Login)" -ForegroundColor Green
    
    Write-Host "`nFound these stored procedures:" -ForegroundColor Cyan
    foreach ($proc in $result | Select-Object -Skip 1) {
        Write-Host "  - $($proc.name)"
    }
}
catch {
    Write-Host "Error connecting to database: $_" -ForegroundColor Red
}

Write-Host "`nPress Enter to continue..."
Read-Host
