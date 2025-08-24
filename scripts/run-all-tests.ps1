#Requires -Version 5.1
<#
.SYNOPSIS
    Run all tests for the DailyBackup module.

.DESCRIPTION
    This script runs all available tests: PSScriptAnalyzer, Pester unit tests,
    integration tests, and original compatibility tests.

    Use -Verbose to enable detailed output for all test operations.

.EXAMPLE
    .\run-all-tests.ps1 -Verbose
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$verboseOutput = ($VerbosePreference -eq 'Continue')

$projectRoot = Split-Path $PSScriptRoot -Parent
$moduleName = 'DailyBackup'

Write-Host "=== Running All Tests for $moduleName ===" -ForegroundColor Cyan
Write-Host "Project Root: $projectRoot" -ForegroundColor Gray
Write-Host ''

$totalErrors = 0

# Test 1: PSScriptAnalyzer
Write-Host '--- 1. Static Analysis (PSScriptAnalyzer) ---' -ForegroundColor Yellow
try
{
    $analysisResults = Invoke-ScriptAnalyzer -Settings (Join-Path $projectRoot 'PSScriptAnalyzerSettings.psd1') -Path $projectRoot -Recurse
    $errors = $analysisResults | Where-Object { $_.Severity -eq 'Error' }
    $warnings = $analysisResults | Where-Object { $_.Severity -eq 'Warning' }

    if ($errors.Count -gt 0)
    {
        Write-Host "✗ Static analysis found $($errors.Count) error(s) and $($warnings.Count) warning(s)" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  ERROR: $_" -ForegroundColor Red }
        $totalErrors += $errors.Count
    }
    else
    {
        Write-Host "✓ Static analysis passed ($($warnings.Count) warnings)" -ForegroundColor Green
    }
}
catch
{
    Write-Host "✗ Static analysis failed: $_" -ForegroundColor Red
    $totalErrors++
}

# Test 2: Pester Unit Tests
Write-Host "`n--- 2. Unit Tests (Pester) ---" -ForegroundColor Yellow
try
{
    $pesterTestPath = Join-Path -Path $projectRoot -ChildPath 'test' -AdditionalChildPath "$moduleName.Tests.ps1"
    if (Test-Path $pesterTestPath)
    {
        $testResults = Invoke-Pester $pesterTestPath -PassThru -Verbose:$verboseOutput
        if ($testResults.FailedCount -gt 0)
        {
            Write-Host "✗ Unit tests failed: $($testResults.FailedCount) failed, $($testResults.PassedCount) passed" -ForegroundColor Red
            $totalErrors += $testResults.FailedCount
        }
        else
        {
            Write-Host "✓ Unit tests passed: $($testResults.PassedCount) passed" -ForegroundColor Green
        }
    }
    else
    {
        Write-Host "⚠ Unit test file not found: $pesterTestPath" -ForegroundColor Yellow
    }
}
catch
{
    Write-Host "✗ Unit tests failed: $_" -ForegroundColor Red
    $totalErrors++
}

# Test 3: Integration Tests
Write-Host "`n--- 3. Integration Tests ---" -ForegroundColor Yellow
try
{
    $integrationTestPath = Join-Path -Path $projectRoot -ChildPath 'test' -AdditionalChildPath 'IntegrationTests.ps1'
    if (Test-Path $integrationTestPath)
    {
        & $integrationTestPath -Verbose:$verboseOutput -CleanupAfterTests:$true
        Write-Host '✓ Integration tests completed' -ForegroundColor Green
    }
    else
    {
        Write-Host "⚠ Integration test file not found: $integrationTestPath" -ForegroundColor Yellow
    }
}
catch
{
    Write-Host "✗ Integration tests failed: $_" -ForegroundColor Red
    $totalErrors++
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
if ($totalErrors -eq 0)
{
    Write-Host '🎉 All tests passed successfully!' -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "❌ $totalErrors error(s) found across all tests" -ForegroundColor Red
    exit 1
}
