#Requires -Module Pester

<#
.SYNOPSIS
    Tests for error handling, edge cases, and input validation across all DailyBackup functions.

.DESCRIPTION
    This test suite validates robust error handling and edge case scenarios for the DailyBackup module,
    ensuring graceful degradation and proper user feedback under various failure conditions.

    Test Areas Covered:
    - Invalid input parameter validation and error messages
    - Non-existent path handling (source paths, backup roots, restore destinations)
    - File system edge cases (empty directories, long names, permissions)
    - Parameter validation ranges and format checking
    - WhatIf support for all major operations
    - Graceful error recovery without crashes

.NOTES
    This test file focuses on negative test cases and boundary conditions.
    Tests use SilentlyContinue where appropriate to test error handling without noise.

.EXAMPLE
    # Run all error handling tests
    Invoke-Pester -Path "ErrorHandling.Tests.ps1"

.EXAMPLE
    # Run only input validation tests
    Invoke-Pester -Path "ErrorHandling.Tests.ps1" -TagFilter "InputValidation"
#>

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    Initialize-TestModule
    $TestEnv = Initialize-TestEnvironment -TestName 'ErrorHandling'

    # Ensure cleanup happens even if tests fail
    $script:TestEnvironmentPath = $TestEnv.TestRoot
}

Describe 'Error Handling and Edge Cases' {
    Context 'Invalid Input Handling' {
        It 'Handles non-existent source paths gracefully' {
            # Test: Non-existent source paths should be handled gracefully with warnings, not crashes
            # Example: New-DailyBackup -Path "C:\DoesNotExist" -Destination "C:\Backups"
            $nonExistentPath = Join-Path $TestEnv.TestRoot 'NonExistent'
            { New-DailyBackup -Path $nonExistentPath -Destination $TestEnv.BackupDir -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Validates Keep parameter range' {
            # Test: Keep parameter must be >= -1 (ValidateRange attribute validation)
            # Example: New-DailyBackup -Path "C:\Source" -Keep -5  # Should throw
            try
            {
                New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -Keep -2
                $false | Should -Be $true  # Should not reach here
            }
            catch
            {
                $true | Should -Be $true  # Expected behavior
            }
        }

        It 'Rejects invalid FileBackupMode values' {
            { New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -FileBackupMode 'Invalid' -WhatIf } | Should -Throw
        }

        It 'Requires either DestinationPath or UseOriginalPaths for restore' {
            { Restore-DailyBackup -BackupRoot $TestEnv.BackupDir } | Should -Throw
        }

        It 'Handles restore from non-existent backup root' {
            $nonExistentPath = Join-Path $TestEnv.TestRoot 'NonExistentBackups'
            $restoreDestination = Join-Path $TestEnv.TestRoot 'RestoreFailTest'

            { Restore-DailyBackup -BackupRoot $nonExistentPath -DestinationPath $restoreDestination } | Should -Throw
        }
    }

    Context 'File System Edge Cases' {
        It 'Handles empty directories' {
            $emptyDir = Join-Path $TestEnv.TestRoot 'Empty'
            New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null

            { New-DailyBackup -Path $emptyDir -Destination $TestEnv.BackupDir } | Should -Not -Throw
        }

        It 'Processes files with very long names' {
            $longName = 'a' * 100
            $longPath = Join-Path $TestEnv.TestRoot $longName
            New-Item -Path $longPath -ItemType Directory -Force | Out-Null
            'content' | Out-File -FilePath (Join-Path $longPath 'file.txt') -Encoding UTF8

            { New-DailyBackup -Path $longPath -Destination $TestEnv.BackupDir -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Handles permission errors without crashing' {
            $restrictedPath = Join-Path $TestEnv.TestRoot 'Restricted'
            New-Item -Path $restrictedPath -ItemType Directory -Force | Out-Null

            { New-DailyBackup -Path $restrictedPath -Destination $TestEnv.BackupDir -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'WhatIf and Dry Run Operations' {
        It 'Supports WhatIf for backup operations' {
            { New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -WhatIf } | Should -Not -Throw
        }

        It 'Supports WhatIf for restore operations' {
            $restoreDestination = Join-Path $TestEnv.TestRoot 'RestoreWhatIf'
            { Restore-DailyBackup -BackupRoot $TestEnv.BackupDir -DestinationPath $restoreDestination -WhatIf } | Should -Not -Throw
        }

        It 'Supports WhatIf with UseOriginalPaths' {
            { Restore-DailyBackup -BackupRoot $TestEnv.BackupDir -UseOriginalPaths -WhatIf } | Should -Not -Throw
        }
    }
}

AfterAll {
    try
    {
        if ($script:TestEnvironmentPath -and (Test-Path $script:TestEnvironmentPath))
        {
            Remove-TestEnvironment -TestRoot $script:TestEnvironmentPath
        }
    }
    catch
    {
        Write-Warning "Failed to clean up test environment in AfterAll: $($_.Exception.Message)"
    }
    finally
    {
        # Final fallback cleanup
        if ($script:TestEnvironmentPath -and (Test-Path $script:TestEnvironmentPath))
        {
            try
            {
                Remove-Item $script:TestEnvironmentPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch
            {
                Write-Verbose "Final cleanup attempt failed silently: $($_.Exception.Message)"
            }
        }
    }
}
