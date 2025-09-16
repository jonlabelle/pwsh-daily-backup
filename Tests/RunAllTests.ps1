#Requires -Module Pester

<#
.SYNOPSIS
    Runs all DailyBackup module tests in focused test files.

.DESCRIPTION
    This script discovers and runs all *.Tests.ps1 files in the test directory,
    providing a comprehensive test suite for the DailyBackup module.

.PARAMETER TestName
    Optional filter to run specific test files (e.g., "Backup", "Restore").

.PARAMETER Tag
    Optional Pester tags to filter tests.

.PARAMETER OutputFormat
    Output format for test results. Default is 'Normal'.

.EXAMPLE
    .\RunAllTests.ps1

.EXAMPLE
    .\RunAllTests.ps1 -TestName "Backup"

.EXAMPLE
    .\RunAllTests.ps1 -OutputFormat "Detailed"
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$TestName,

    [Parameter()]
    [string[]]$Tag,

    [Parameter()]
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$OutputFormat = 'Normal'
)

# Discover test files
$testFiles = Get-ChildItem -Path $PSScriptRoot -Filter '*.Tests.ps1' | Where-Object { $_.Name -ne 'DailyBackup.Tests.ps1' }

if ($TestName)
{
    $testFiles = $testFiles | Where-Object { $_.BaseName -like "*$TestName*" }
}

if ($testFiles.Count -eq 0)
{
    Write-Warning 'No test files found matching criteria.'
    return
}

Write-Host "Found $($testFiles.Count) test file(s):" -ForegroundColor Green
$testFiles | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
Write-Host ''

# Configure Pester
$pesterConfig = @{
    Run = @{
        Path = $testFiles.FullName
        PassThru = $true
    }
    Output = @{
        Verbosity = $OutputFormat
    }
}

if ($Tag)
{
    $pesterConfig.Filter = @{
        Tag = $Tag
    }
}

# Run tests
$results = Invoke-Pester -Configuration $pesterConfig

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Total Tests: $($results.TotalCount)" -ForegroundColor White
Write-Host "Passed: $($results.PassedCount)" -ForegroundColor Green
Write-Host "Failed: $($results.FailedCount)" -ForegroundColor $(if ($results.FailedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "Skipped: $($results.SkippedCount)" -ForegroundColor Yellow

if ($results.FailedCount -gt 0)
{
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $results.Failed | ForEach-Object {
        Write-Host "  - $($_.FullName)" -ForegroundColor Red
    }
}

# Exit with appropriate code
exit $results.FailedCount
