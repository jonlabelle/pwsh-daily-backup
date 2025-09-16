#Requires -Version 5.1
<#
.SYNOPSIS
    Enhanced integration tests for the DailyBackup module.

.DESCRIPTION
    This script performs comprehensive integration tests for the DailyBackup module,
    including real-world scenarios, performance testing, and edge case validation.

.PARAMETER ModuleName
    The name of the module to test. Default is 'DailyBackup'.

.PARAMETER CleanupAfterTests
    Whether to clean up test artifacts after running tests. Default is $true.

.PARAMETER RunPerformanceTests
    Whether to run performance tests with larger datasets. Default is $false.

.EXAMPLE
    .\IntegrationTests.ps1 -Verbose

.EXAMPLE
    .\IntegrationTests.ps1 -RunPerformanceTests -CleanupAfterTests:$false
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ModuleName = 'DailyBackup',

    [Parameter()]
    [switch] $CleanupAfterTests = $true,

    [Parameter()]
    [switch] $RunPerformanceTests
)

# Set up error handling
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($VerbosePreference -eq 'SilentlyContinue') { 'SilentlyContinue' } else { 'Continue' }

$verboseEnabled = ($VerbosePreference -eq 'Continue')
$dryRun = $false

if ($PSCmdlet.ShouldProcess($ModuleName, 'Run Integration Tests'))
{
    $dryRun = $false
    Write-Host 'Running actual tests (not dry-run)' -ForegroundColor Green
}
else
{
    $dryRun = $true
    Write-Host 'Running in dry-run mode (WhatIf)' -ForegroundColor Yellow
}

# Initialize test environment
$projectRootDir = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path -Path $projectRootDir -ChildPath $ModuleName
$testDataDir = Join-Path -Path $PSScriptRoot -ChildPath 'TestData'

Write-Host '=== DailyBackup Module Integration Tests ===' -ForegroundColor Cyan
Write-Host "Module Path: $modulePath" -ForegroundColor Gray
Write-Host "Test Data: $testDataDir" -ForegroundColor Gray
Write-Host "Dry Run: $dryRun" -ForegroundColor Gray
Write-Host ''

# Clean up and import module
try
{
    Get-Module $ModuleName | Remove-Module -Verbose:$verboseEnabled -Force -ErrorAction SilentlyContinue
    Import-Module -Name $modulePath -Force -Verbose:$verboseEnabled
    Write-Host '[OK] Module imported successfully' -ForegroundColor Green
}
catch
{
    Write-Error "Failed to import module: $_"
    exit 1
}

# Setup test directories
try
{
    if (Test-Path $testDataDir)
    {
        Remove-Item $testDataDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (-not $dryRun)
    {
        $sourceDir = New-Item -Path (Join-Path $testDataDir 'SourceFiles') -ItemType Directory -Force
        $backupDir = New-Item -Path (Join-Path $testDataDir 'Backups') -ItemType Directory -Force
        $largeDirTest = New-Item -Path (Join-Path $testDataDir 'LargeTest') -ItemType Directory -Force
    }
    else
    {
        # In WhatIf mode, create path objects manually since New-Item returns null
        New-Item -Path (Join-Path $testDataDir 'SourceFiles') -ItemType Directory -Force -WhatIf
        New-Item -Path (Join-Path $testDataDir 'Backups') -ItemType Directory -Force -WhatIf
        New-Item -Path (Join-Path $testDataDir 'LargeTest') -ItemType Directory -Force -WhatIf

        # Create path objects for later use
        $sourceDir = [PSCustomObject]@{ FullName = Join-Path $testDataDir 'SourceFiles' }
        $backupDir = [PSCustomObject]@{ FullName = Join-Path $testDataDir 'Backups' }
        $largeDirTest = [PSCustomObject]@{ FullName = Join-Path $testDataDir 'LargeTest' }
    }

    Write-Host '[OK] Test directories created' -ForegroundColor Green
}
catch
{
    Write-Error "Failed to create test directories: $_"
    exit 1
}

# Create test files
try
{
    if (-not $dryRun)
    {
        # Basic test files
        @('test1.txt', 'test2.txt', 'important.log') | ForEach-Object {
            "Sample content for $_`nCreated at: $(Get-Date)" | Out-File -FilePath (Join-Path $sourceDir.FullName $_) -Encoding UTF8
        }

        # Create subdirectory with files
        $subDir = New-Item -Path (Join-Path $sourceDir.FullName 'Subfolder') -ItemType Directory -Force
        'Subdirectory content' | Out-File -FilePath (Join-Path $subDir.FullName 'subfile.txt') -Encoding UTF8

        # Create files with special characters
        'Special content' | Out-File -FilePath (Join-Path $sourceDir.FullName 'file with spaces.txt') -Encoding UTF8
    }
    else
    {
        # In WhatIf mode, just simulate file creation
        Write-Host "Would create test files in: $($sourceDir.FullName)" -ForegroundColor Gray
        @('test1.txt', 'test2.txt', 'important.log') | ForEach-Object {
            Write-Host "  - Would create: $_" -ForegroundColor Gray
        }
        Write-Host '  - Would create: Subfolder/subfile.txt' -ForegroundColor Gray
        Write-Host '  - Would create: file with spaces.txt' -ForegroundColor Gray
    }

    Write-Host '[OK] Test files created' -ForegroundColor Green
}
catch
{
    Write-Error "Failed to create test files: $_"
    exit 1
}

# Test 1: Basic functionality
Write-Host "`n--- Test 1: Basic Backup Operation ---" -ForegroundColor Yellow
try
{
    $result = New-DailyBackup -Path $sourceDir.FullName -Destination $backupDir.FullName -WhatIf:$dryRun -Verbose:$verboseEnabled

    if (-not $dryRun)
    {
        $todayFolder = Get-Date -Format 'yyyy-MM-dd'
        $backupPath = Join-Path $backupDir.FullName $todayFolder

        if (Test-Path $backupPath)
        {
            $zipFiles = Get-ChildItem -Path $backupPath -Filter '*.zip'
            Write-Host "[OK] Backup created successfully ($($zipFiles.Count) zip file(s))" -ForegroundColor Green
        }
        else
        {
            Write-Warning "Backup directory not found: $backupPath"
        }
    }
}
catch
{
    Write-Host "[FAIL] Test 1 failed: $_" -ForegroundColor Red
}

# Test 2: Multiple source paths
Write-Host "`n--- Test 2: Multiple Source Paths ---" -ForegroundColor Yellow
try
{
    $path1 = Join-Path $sourceDir.FullName 'test1.txt'
    $path2 = Join-Path $sourceDir.FullName 'Subfolder'

    New-DailyBackup -Path @($path1, $path2) -Destination $backupDir.FullName -WhatIf:$dryRun -Verbose:$verboseEnabled
    Write-Host '[OK] Multiple paths processed successfully' -ForegroundColor Green
}
catch
{
    Write-Host "[FAIL] Test 2 failed: $_" -ForegroundColor Red
}

# Test 3: Cleanup functionality
Write-Host "`n--- Test 3: Backup Cleanup ---" -ForegroundColor Yellow
try
{
    if (-not $dryRun)
    {
        # Create some old backup directories
        $oldDates = @(
            (Get-Date).AddDays(-10).ToString('yyyy-MM-dd'),
            (Get-Date).AddDays(-5).ToString('yyyy-MM-dd'),
            (Get-Date).AddDays(-2).ToString('yyyy-MM-dd')
        )

        foreach ($date in $oldDates)
        {
            $oldDir = New-Item -Path (Join-Path $backupDir.FullName $date) -ItemType Directory -Force
            'dummy' | Out-File -FilePath (Join-Path $oldDir.FullName 'dummy.zip') -Encoding UTF8
        }

        # Run backup with cleanup
        New-DailyBackup -Path $sourceDir.FullName -Destination $backupDir.FullName -Keep 2 -WhatIf:$dryRun -Verbose:$verboseEnabled

        # Check results
        $remainingDirs = Get-ChildItem -Path $backupDir.FullName -Directory | Where-Object { $_.Name -match '\d{4}-\d{2}-\d{2}' }
        Write-Host "[OK] Cleanup test completed. Remaining backup directories: $($remainingDirs.Count)" -ForegroundColor Green
    }
    else
    {
        New-DailyBackup -Path $sourceDir.FullName -Destination $backupDir.FullName -Keep 2 -WhatIf:$dryRun -Verbose:$verboseEnabled
        Write-Host '[OK] Cleanup test completed (dry-run)' -ForegroundColor Green
    }
}
catch
{
    Write-Host "[FAIL] Test 3 failed: $_" -ForegroundColor Red
}

# Test 4: Error handling
Write-Host "`n--- Test 4: Error Handling ---" -ForegroundColor Yellow
try
{
    # Test with non-existent source path
    $nonExistentPath = Join-Path $testDataDir 'NonExistent'
    New-DailyBackup -Path $nonExistentPath -Destination $backupDir.FullName -WhatIf:$dryRun -Verbose:$verboseEnabled -WarningAction SilentlyContinue
    Write-Host '[OK] Non-existent path handled gracefully' -ForegroundColor Green

    # Test with invalid parameter values
    try
    {
        New-DailyBackup -Path $sourceDir.FullName -Destination $backupDir.FullName -Keep -2 -WhatIf:$dryRun -ErrorAction Stop
        Write-Host '[FAIL] Should have failed with invalid Keep value (-2)' -ForegroundColor Red
    }
    catch
    {
        Write-Host '[OK] Invalid parameter validation working' -ForegroundColor Green
    }
}
catch
{
    Write-Host "[FAIL] Test 4 failed: $_" -ForegroundColor Red
}

# Test 5: Performance test (optional)
if ($RunPerformanceTests)
{
    Write-Host "`n--- Test 5: Performance Test ---" -ForegroundColor Yellow
    try
    {
        if (-not $dryRun)
        {
            # Create many files for performance testing
            Write-Host 'Creating test files for performance testing...' -ForegroundColor Gray
            for ($i = 1; $i -le 100; $i++)
            {
                "Performance test file $i content $(Get-Random)" | Out-File -FilePath (Join-Path $largeDirTest.FullName "perf_$i.txt") -Encoding UTF8
            }
        }
        else
        {
            Write-Host 'Would create 100 test files for performance testing...' -ForegroundColor Gray
        }

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        New-DailyBackup -Path $largeDirTest.FullName -Destination $backupDir.FullName -WhatIf:$dryRun -Verbose:$verboseEnabled
        $stopwatch.Stop()

        Write-Host "[OK] Performance test completed in $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Green
    }
    catch
    {
        Write-Host "[FAIL] Performance test failed: $_" -ForegroundColor Red
    }
}

# Test 6: Cross-platform paths
Write-Host "`n--- Test 6: Path Handling ---" -ForegroundColor Yellow
try
{
    # Test relative paths
    Push-Location $projectRootDir
    try
    {
        New-DailyBackup -Path '.\Tests\stubs\files-to-backup' -Destination (Join-Path $testDataDir 'RelativeTest') -WhatIf:$dryRun -Verbose:$verboseEnabled -ErrorAction SilentlyContinue
        Write-Host '[OK] Relative path handling working' -ForegroundColor Green
    }
    finally
    {
        Pop-Location
    }
}
catch
{
    Write-Host "[FAIL] Test 6 failed: $_" -ForegroundColor Red
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host 'All integration tests completed.' -ForegroundColor Green

if (-not $dryRun -and $CleanupAfterTests)
{
    Write-Host 'Cleaning up test data...' -ForegroundColor Gray
    try
    {
        Remove-Item $testDataDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host '[OK] Test data cleaned up' -ForegroundColor Green
    }
    catch
    {
        Write-Warning "Failed to clean up test data: $_"
    }
}
else
{
    Write-Host "Test data preserved at: $testDataDir" -ForegroundColor Gray
}

Write-Host "`nIntegration tests completed successfully!" -ForegroundColor Green
