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

# Test 1: PSScriptAnalyzer
Write-Host '--- 1. Static Analysis (PSScriptAnalyzer) ---' -ForegroundColor Yellow
$oldProgressPreference = $global:ProgressPreference
try
{
    # Disable progress bars for cleaner output
    $global:ProgressPreference = 'SilentlyContinue'

    $analysisResults = Invoke-ScriptAnalyzer -Settings (Join-Path $projectRoot 'PSScriptAnalyzerSettings.psd1') -Path $projectRoot -Recurse
    $errors = $analysisResults | Where-Object { $_.Severity -eq 'Error' }
    $warnings = $analysisResults | Where-Object { $_.Severity -eq 'Warning' }

    if ($errors.Count -gt 0)
    {
        Write-Host "[FAILED] Static analysis found $($errors.Count) error(s) and $($warnings.Count) warning(s)" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  ERROR: $_" -ForegroundColor Red }
        $errors
        exit 1
    }
    else
    {
        Write-Host "[PASSED] Static analysis passed ($($warnings.Count) warnings)" -ForegroundColor Green
    }
}
catch
{
    Write-Host "[FAILED] Static analysis failed: $_" -ForegroundColor Red
    throw $_
}
finally
{
    $global:ProgressPreference = $oldProgressPreference
}

# Test 2: Pester Unit Tests
Write-Host "`n--- 2. Unit Tests (Pester) ---" -ForegroundColor Yellow
$oldProgressPreference = $global:ProgressPreference
try
{
    # Disable progress bars for cleaner output
    $global:ProgressPreference = 'SilentlyContinue'

    $pesterTestPath = Join-Path -Path $projectRoot -ChildPath 'Tests' | Join-Path -ChildPath "$moduleName.Tests.ps1"
    if (Test-Path $pesterTestPath)
    {
        $testResults = Invoke-Pester $pesterTestPath -PassThru -Verbose:$verboseOutput
        if ($testResults.FailedCount -gt 0)
        {
            Write-Host "[FAILED] Unit tests failed: $($testResults.FailedCount) failed, $($testResults.PassedCount) passed" -ForegroundColor Red
            exit 1
        }
        else
        {
            Write-Host "[PASSED] Unit tests passed: $($testResults.PassedCount) passed" -ForegroundColor Green
        }
    }
    else
    {
        Write-Host "[WARNING] Unit test file not found: $pesterTestPath" -ForegroundColor Yellow
    }
}
catch
{
    Write-Host "[FAILED] Unit tests failed: $_" -ForegroundColor Red
    throw $_
}
finally
{
    $global:ProgressPreference = $oldProgressPreference
}

# Test 3: Integration Tests
Write-Host "`n--- 3. Integration Tests ---" -ForegroundColor Yellow
$oldProgressPreference = $global:ProgressPreference
try
{
    # Disable progress bars for cleaner output
    $global:ProgressPreference = 'SilentlyContinue'

    $integrationTestPath = Join-Path -Path $projectRoot -ChildPath 'Tests' | Join-Path -ChildPath 'IntegrationTests.ps1'
    if (Test-Path $integrationTestPath)
    {
        & $integrationTestPath -Verbose:$verboseOutput -CleanupAfterTests:$true
        Write-Host '[PASSED] Integration tests completed' -ForegroundColor Green
    }
    else
    {
        Write-Host "[WARNING] Integration test file not found: $integrationTestPath" -ForegroundColor Yellow
    }
}
catch
{
    Write-Host "[FAILED] Integration tests failed: $_" -ForegroundColor Red
    throw $_
}
finally
{
    $global:ProgressPreference = $oldProgressPreference
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host '[SUCCESS] All tests passed successfully!' -ForegroundColor Green
exit 0
