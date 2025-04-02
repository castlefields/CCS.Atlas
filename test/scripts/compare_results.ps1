# PowerShell script to compare test results between different procedure folders

# Configuration
$resultsFolder = "$PSScriptRoot\..\results"

# Function to compare two CSV files and highlight differences
function Compare-TestResults {
    param (
        [string]$baselineFile,
        [string]$comparisonFile,
        [string]$outputFile,
        [string]$baselineProcName,
        [string]$comparisonProcName,
        [string]$testId
    )
    
    if (-not (Test-Path $baselineFile) -or -not (Test-Path $comparisonFile)) {
        Write-Host "Error: One or both input files do not exist" -ForegroundColor Red
        return $null
    }
    
    $baseline = Import-Csv -Path $baselineFile
    $comparison = Import-Csv -Path $comparisonFile
    
    # Create a simple comparison report
    $reportLines = @()
    $reportLines += "# Test Results Comparison - Test ID: $testId"
    $reportLines += "Baseline: $baselineProcName ($(Split-Path $baselineFile -Leaf))"
    $reportLines += "Comparison: $comparisonProcName ($(Split-Path $comparisonFile -Leaf))"
    $reportLines += "Generated: $(Get-Date)"
    $reportLines += ""
    $reportLines += "## Summary"
    
    # Check if number of rows match
    $baselineRows = $baseline.Count
    $comparisonRows = $comparison.Count
    
    $reportLines += ""
    $reportLines += "- Baseline rows: $baselineRows"
    $reportLines += "- Comparison rows: $comparisonRows"
    
    if ($baselineRows -ne $comparisonRows) {
        $reportLines += ""
        $reportLines += "WARNING: Row count mismatch detected!"
    }
    
    # Compare columns
    $baselineColumns = $baseline[0].PSObject.Properties.Name
    $comparisonColumns = $comparison[0].PSObject.Properties.Name
    
    $reportLines += ""
    $reportLines += "## Columns"
    $reportLines += "- Baseline: $($baselineColumns -join ", ")"
    $reportLines += "- Comparison: $($comparisonColumns -join ", ")"
    
    $missingColumns = $baselineColumns | Where-Object { $comparisonColumns -notcontains $_ }
    $extraColumns = $comparisonColumns | Where-Object { $baselineColumns -notcontains $_ }
    
    if ($missingColumns) {
        $reportLines += ""
        $reportLines += "WARNING: Missing columns in comparison: $($missingColumns -join ", ")"
    }
    
    if ($extraColumns) {
        $reportLines += ""
        $reportLines += "WARNING: Extra columns in comparison: $($extraColumns -join ", ")"
    }
    
    # Compare data for matching moments
    $reportLines += ""
    $reportLines += "## Data Comparison"
    
    $compareColumns = @("budget", "budget_rate", "advance_val", "accept_rate")
    $differences = @()
    
    foreach ($baseRow in $baseline) {
        $moment = $baseRow.moment
        $compRow = $comparison | Where-Object { $_.moment -eq $moment }
        
        if ($compRow) {
            foreach ($col in $compareColumns) {
                if ($baseRow.$col -ne $compRow.$col) {
                    $diffObj = [PSCustomObject]@{
                        Moment = $moment
                        Column = $col
                        Baseline = $baseRow.$col
                        Comparison = $compRow.$col
                        Difference = $null
                        PercentChange = $null
                    }
                    
                    # Calculate difference
                    try {
                        $diffObj.Difference = [math]::Round(([double]$compRow.$col - [double]$baseRow.$col), 6)
                    } 
                    catch {
                        $diffObj.Difference = "N/A"
                    }
                    
                    # Calculate percent change
                    try {
                        if ([double]$baseRow.$col -ne 0) {
                            $diffObj.PercentChange = [math]::Round((([double]$compRow.$col - [double]$baseRow.$col) / [double]$baseRow.$col * 100), 2)
                        } 
                        else {
                            $diffObj.PercentChange = "N/A"
                        }
                    }
                    catch {
                        $diffObj.PercentChange = "N/A"
                    }
                    
                    $differences += $diffObj
                }
            }
        } 
        else {
            $differences += [PSCustomObject]@{
                Moment = $moment
                Column = "ALL"
                Baseline = "Present"
                Comparison = "Missing"
                Difference = "N/A"
                PercentChange = "N/A"
            }
        }
    }
    
    # Check for any moments in comparison that are not in baseline
    foreach ($compRow in $comparison) {
        $moment = $compRow.moment
        $baseRow = $baseline | Where-Object { $_.moment -eq $moment }
        
        if (-not $baseRow) {
            $differences += [PSCustomObject]@{
                Moment = $moment
                Column = "ALL"
                Baseline = "Missing"
                Comparison = "Present"
                Difference = "N/A"
                PercentChange = "N/A"
            }
        }
    }
    
    if ($differences.Count -eq 0) {
        $reportLines += ""
        $reportLines += "No differences found in key metrics ($($compareColumns -join ", "))!"
        $summary = "[MATCH] No differences found in key metrics."
    } 
    else {
        $reportLines += ""
        $reportLines += "Found $($differences.Count) differences in key metrics:"
        $reportLines += ""
        
        # Add table header without using pipes
        $reportLines += "Moment   Column      Baseline    Comparison  Difference  % Change"
        $reportLines += "-------  ----------  ----------  ----------  ----------  ----------"
        
        # Add each row without using pipes
        foreach ($diff in $differences) {
            $reportLines += "{0,-8} {1,-11} {2,-11} {3,-11} {4,-11} {5,-11}" -f 
                $diff.Moment, $diff.Column, $diff.Baseline, $diff.Comparison, 
                $diff.Difference, $diff.PercentChange
        }
        
        $summary = "[DIFF] Found $($differences.Count) differences in key metrics."
    }
    
    # Save the report
    $reportLines | Out-File -FilePath $outputFile -Encoding utf8
    Write-Host "Comparison report saved to: $outputFile" -ForegroundColor Green
    
    return [PSCustomObject]@{
        TestId = $testId
        BaseProcedure = $baselineProcName
        CompProcedure = $comparisonProcName
        DifferencesCount = $differences.Count
        Summary = $summary
    }
}

# Function to automatically compare tests across procedure folders
function Compare-AllSameTests {
    Write-Host "=== Automatic Test Comparison Tool ===" -ForegroundColor Cyan
    
    # Check if results folder exists
    if (-not (Test-Path $resultsFolder)) {
        Write-Host "Results folder '$resultsFolder' not found!" -ForegroundColor Red
        return
    }
    
    # Get all procedure folders
    $procFolders = Get-ChildItem -Path $resultsFolder -Directory | Where-Object { $_.Name -match '^rpt_' }
    
    if ($procFolders.Count -lt 2) {
        Write-Host "Need at least 2 procedure folders to compare. Only found $($procFolders.Count)." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Found $($procFolders.Count) procedure folders to compare" -ForegroundColor Green
    foreach ($folder in $procFolders) {
        Write-Host "  - $($folder.Name)" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # Create a summary report
    $summaryLines = @()
    $summaryLines += "# Test Comparison Summary Report"
    $summaryLines += "Generated: $(Get-Date)"
    $summaryLines += ""
    $summaryLines += "This report compares test results with the same test ID across different procedure versions."
    $summaryLines += ""
    $summaryLines += "## Procedures Compared"
    
    foreach ($folder in $procFolders) {
        $summaryLines += "- $($folder.Name)"
    }
    
    $summaryLines += ""
    $summaryLines += "## Test Comparisons"
    
    $comparisonResults = @()
    
    # Get all unique test IDs from all folders
    $allTestFiles = $procFolders | ForEach-Object { 
        Get-ChildItem -Path $_.FullName -Filter "test_*_result.csv" 
    }
    
    $allTestIds = $allTestFiles | ForEach-Object { 
        if ($_.Name -match 'test_(\d+)_result\.csv') { $matches[1] } 
    } | Sort-Object -Unique
    
    Write-Host "Found $($allTestIds.Count) unique test IDs to compare" -ForegroundColor Green
    
    # For each test ID, compare it across all procedure folders
    $testCount = 0
    foreach ($testId in $allTestIds) {
        Write-Host "Comparing Test ID: $testId" -ForegroundColor Yellow
        $testCount++
        
        # Use the first procedure as baseline
        $baseProc = $procFolders[0]
        $baseFile = Join-Path $baseProc.FullName "test_${testId}_result.csv"
        
        if (-not (Test-Path $baseFile)) {
            Write-Host "  Baseline file not found in $($baseProc.Name). Skipping test $testId." -ForegroundColor Yellow
            continue
        }
        
        # Compare with each other procedure
        for ($i = 1; $i -lt $procFolders.Count; $i++) {
            $compProc = $procFolders[$i]
            $compFile = Join-Path $compProc.FullName "test_${testId}_result.csv"
            
            if (-not (Test-Path $compFile)) {
                Write-Host "  Comparison file not found in $($compProc.Name). Skipping." -ForegroundColor Yellow
                continue
            }
            
            $outputFile = "$resultsFolder\comparison_${testId}_${($baseProc.Name)}_vs_${($compProc.Name)}.txt"
            
            Write-Host "  Comparing $($baseProc.Name) vs $($compProc.Name)" -ForegroundColor Cyan
            
            $result = Compare-TestResults `
                -baselineFile $baseFile `
                -comparisonFile $compFile `
                -outputFile $outputFile `
                -baselineProcName $baseProc.Name `
                -comparisonProcName $compProc.Name `
                -testId $testId
                
            if ($result) {
                $comparisonResults += $result
            }
        }
    }
    
    # Add the comparison results to the summary report
    if ($comparisonResults.Count -eq 0) {
        $summaryLines += ""
        $summaryLines += "No comparisons were performed. This could be because:"
        $summaryLines += "- No matching test IDs were found across different procedures"
        $summaryLines += "- Only one procedure folder exists"
    }
    else {
        $summaryLines += ""
        # Add table header without using pipes or dashes
        $summaryLines += "Test ID  Baseline    Comparison  Result"
        $summaryLines += "-------  ----------  ----------  ----------------------------------------"
        
        foreach ($result in $comparisonResults) {
            $summaryLines += "{0,-8} {1,-11} {2,-11} {3}" -f 
                $result.TestId, $result.BaseProcedure, $result.CompProcedure, $result.Summary
        }
    }
    
    # Save the summary report
    $summaryFile = "$resultsFolder\comparison_summary.txt"
    $summaryLines | Out-File -FilePath $summaryFile -Encoding utf8
    
    Write-Host "`nTest comparison completed!" -ForegroundColor Green
    Write-Host "Total tests compared: $testCount" -ForegroundColor Green
    Write-Host "Total comparisons performed: $($comparisonResults.Count)" -ForegroundColor Green
    Write-Host "Summary report saved to: $summaryFile" -ForegroundColor Green
}

# Interactive menu to select files to compare manually
function Show-ComparisonMenu {
    Clear-Host
    Write-Host "=== Test Results Comparison Tool ===" -ForegroundColor Cyan
    Write-Host
    Write-Host "1. Run automatic comparison of all same test IDs across procedures" -ForegroundColor Yellow
    Write-Host "2. Manually select files to compare" -ForegroundColor Yellow
    Write-Host "3. Exit" -ForegroundColor Yellow
    Write-Host
    Write-Host "Select an option (1-3): " -ForegroundColor Green -NoNewline
    
    $option = Read-Host
    
    switch ($option) {
        "1" { 
            Compare-AllSameTests
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor Cyan
            Read-Host | Out-Null
            Show-ComparisonMenu
        }
        "2" { 
            Show-ManualComparisonMenu
            Write-Host "`nPress Enter to return to menu..." -ForegroundColor Cyan
            Read-Host | Out-Null
            Show-ComparisonMenu
        }
        "3" { return }
        default {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-ComparisonMenu
        }
    }
}

# Function to manually select files to compare
function Show-ManualComparisonMenu {
    Clear-Host
    Write-Host "=== Manual File Comparison ===" -ForegroundColor Cyan
    
    # Get all result files from all procedure folders
    $resultFiles = Get-ChildItem -Path $resultsFolder -Recurse -Filter "*_result.csv" | Sort-Object FullName
    
    if ($resultFiles.Count -eq 0) {
        Write-Host "No test results found in $resultsFolder or its subfolders" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nAvailable test results:" -ForegroundColor Green
    for ($i = 0; $i -lt $resultFiles.Count; $i++) {
        # Show folder and file name for better clarity
        $relativePath = $resultFiles[$i].FullName.Substring($resultsFolder.Length + 1)
        Write-Host "  $($i+1). $relativePath" -ForegroundColor Cyan
    }
    
    try {
        Write-Host "`nSelect baseline file (1-$($resultFiles.Count)):" -ForegroundColor Yellow -NoNewline
        $baselineIndex = [int](Read-Host " ") - 1
        
        Write-Host "Select comparison file (1-$($resultFiles.Count)):" -ForegroundColor Yellow -NoNewline
        $comparisonIndex = [int](Read-Host " ") - 1
        
        if ($baselineIndex -lt 0 -or $baselineIndex -ge $resultFiles.Count -or 
            $comparisonIndex -lt 0 -or $comparisonIndex -ge $resultFiles.Count) {
            Write-Host "Invalid selection!" -ForegroundColor Red
            return
        }
        
        $baselineFile = $resultFiles[$baselineIndex].FullName
        $comparisonFile = $resultFiles[$comparisonIndex].FullName
        
        # Extract procedure names from paths
        $baselineProcName = Split-Path (Split-Path $baselineFile -Parent) -Leaf
        $comparisonProcName = Split-Path (Split-Path $comparisonFile -Parent) -Leaf
        
        # Extract test ID if possible
        $testId = "manual"
        if ($resultFiles[$baselineIndex].Name -match 'test_(\d+)_result\.csv') {
            $testId = $matches[1]
        }
        
        $outputFile = "$resultsFolder\manual_comparison_${baselineProcName}_vs_${comparisonProcName}.txt"
        
        Compare-TestResults `
            -baselineFile $baselineFile `
            -comparisonFile $comparisonFile `
            -outputFile $outputFile `
            -baselineProcName $baselineProcName `
            -comparisonProcName $comparisonProcName `
            -testId $testId
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

# Start the menu system
Show-ComparisonMenu