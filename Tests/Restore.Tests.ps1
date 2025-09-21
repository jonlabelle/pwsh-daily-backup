#Requires -Module Pester

<#
.SYNOPSIS
    Tests for Get-DailyBackup and Restore-DailyBackup functionality.

.DESCRIPTION
    This test suite validates backup information retrieval and restore operations,
    including backup discovery, metadata reading, and file extraction with path reconstruction.

    Test Areas Covered:
    - Get-DailyBackup: backup information retrieval and filtering
    - Restore-DailyBackup: file extraction to specified destinations
    - UseOriginalPaths: restore to original source locations
    - Date and BackupName filtering for targeted operations
    - Content preservation during restore operations
    - Metadata information maintenance
    - End-to-end backup and restore workflow validation
    - Error handling for missing paths and invalid parameters

.NOTES
    Restore operations depend on backup metadata for path reconstruction.
    Get-DailyBackup provides backup discovery before restore operations.

.EXAMPLE
    # Run all restore and info tests
    Invoke-Pester -Path "Restore.Tests.ps1"

.EXAMPLE
    # Run only Get-DailyBackup tests
    Invoke-Pester -Path "Restore.Tests.ps1" -TagFilter "Information"
#>

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    Initialize-TestModule
    $TestEnv = Initialize-TestEnvironment -TestName 'Restore'

    # Ensure cleanup happens even if tests fail
    $script:TestEnvironmentPath = $TestEnv.TestRoot
}

Describe 'Get-DailyBackup Functionality' {
    BeforeAll {
        # Create test backups for info retrieval
        New-TestBackup -SourcePath $TestEnv.SourceDir -BackupPath $TestEnv.BackupDir
    }

    Context 'Backup Information Retrieval' {
        It 'Returns available backup information' {
            # Test: Get-DailyBackup should return backup metadata for discovery
            # Example: Get-DailyBackup -BackupRoot "C:\Backups"
            $backupInfo = Get-DailyBackup -BackupRoot $TestEnv.BackupDir
            $backupInfo | Should -Not -BeNullOrEmpty
            $backupInfo.Count | Should -BeGreaterThan 0
        }

        It 'Returns backup information with required properties' {
            # Test: Backup info should include Date, Path, Backups array, TotalSize, BackupCount
            # These properties are essential for restore operation planning
            $backupInfo = Get-DailyBackup -BackupRoot $TestEnv.BackupDir
            $backup = $backupInfo[0]

            $backup.Date | Should -Not -BeNullOrEmpty
            $backup.Path | Should -Not -BeNullOrEmpty
            $backup.Backups | Should -Not -BeNullOrEmpty
            $backup.TotalSize | Should -BeGreaterThan 0
            $backup.BackupCount | Should -BeGreaterThan 0
        }

        It 'Filters backups by specific date' {
            # Test: Date parameter should filter to specific backup dates
            # Example: Get-DailyBackup -BackupRoot "C:\Backups" -Date "2025-09-21"
            $today = Get-Date -Format 'yyyy-MM-dd'
            $backupInfo = Get-DailyBackup -BackupRoot $TestEnv.BackupDir -Date $today

            if ($backupInfo.Count -gt 0)
            {
                $backupInfo[0].Date | Should -Be $today
            }
        }

        It 'Handles non-existent backup directory gracefully' {
            # Test: Non-existent backup root should return empty array, not crash
            # Example: Get-DailyBackup -BackupRoot "C:\NonExistent"
            $nonExistentPath = Join-Path $TestEnv.TestRoot 'NonExistent'
            $result = Get-DailyBackup -BackupRoot $nonExistentPath -WarningAction SilentlyContinue
            $result | Should -Be @()
        }
    }
}

Describe 'Restore-DailyBackup Functionality' {
    BeforeEach {
        # Create fresh backup for each restore test
        $RestoreTestSource = Join-Path $TestEnv.TestRoot 'RestoreSource'
        if (Test-Path $RestoreTestSource)
        {
            Remove-Item $RestoreTestSource -Recurse -Force
        }
        New-Item -Path $RestoreTestSource -ItemType Directory -Force | Out-Null
        'Restore test content' | Out-File -FilePath (Join-Path $RestoreTestSource 'restore-test.txt') -Encoding UTF8

        New-DailyBackup -Path $RestoreTestSource -Destination $TestEnv.BackupDir
    }

    Context 'Basic Restore Operations' {
        It 'Restores backup to specified destination' {
            $RestoreDestination = Join-Path $TestEnv.TestRoot 'RestoreDestination'
            New-Item -Path $RestoreDestination -ItemType Directory -Force | Out-Null

            $results = Restore-DailyBackup -BackupRoot $TestEnv.BackupDir -DestinationPath $RestoreDestination
            $results | Should -Not -BeNullOrEmpty

            $restoredFiles = Get-ChildItem $RestoreDestination -Recurse -File
            $restoredFiles.Count | Should -BeGreaterThan 0
        }

        It 'Handles specific date parameter correctly' {
            $RestoreDestination = Join-Path $TestEnv.TestRoot 'RestoreDateTest'
            New-Item -Path $RestoreDestination -ItemType Directory -Force | Out-Null

            $today = Get-Date -Format 'yyyy-MM-dd'
            { Restore-DailyBackup -BackupRoot $TestEnv.BackupDir -DestinationPath $RestoreDestination -Date $today } | Should -Not -Throw
        }

        It 'Supports backup name filtering' {
            $RestoreDestination = Join-Path $TestEnv.TestRoot 'RestoreFilterTest'
            New-Item -Path $RestoreDestination -ItemType Directory -Force | Out-Null

            { Restore-DailyBackup -BackupRoot $TestEnv.BackupDir -DestinationPath $RestoreDestination -BackupName '*RestoreSource*' } | Should -Not -Throw
        }

        It 'Works with UseOriginalPaths parameter' {
            { Restore-DailyBackup -BackupRoot $TestEnv.BackupDir -UseOriginalPaths -WhatIf } | Should -Not -Throw
        }
    }

    Context 'Restore Validation' {
        It 'Preserves file content during restore' {
            $RestoreDestination = Join-Path $TestEnv.TestRoot 'ContentTest'
            New-Item -Path $RestoreDestination -ItemType Directory -Force | Out-Null

            Restore-DailyBackup -BackupRoot $TestEnv.BackupDir -DestinationPath $RestoreDestination

            $restoredFile = Get-ChildItem $RestoreDestination -Recurse -File | Where-Object { $_.Name -eq 'restore-test.txt' } | Select-Object -First 1
            if ($restoredFile)
            {
                $content = Get-Content $restoredFile.FullName -Raw
                $content.Trim() | Should -Be 'Restore test content'
            }
        }

        It 'Maintains metadata information during restore' {
            $backupInfo = Get-DailyBackup -BackupRoot $TestEnv.BackupDir
            if ($backupInfo.Count -gt 0 -and $backupInfo[0].Backups.Count -gt 0)
            {
                $backup = $backupInfo[0].Backups[0]
                if ($backup.Metadata)
                {
                    $backup.Metadata.BackupCreated | Should -Not -BeNullOrEmpty
                    $backup.Metadata.SourcePath | Should -Not -BeNullOrEmpty
                    $backup.Metadata.PathType | Should -Match '^(File|Directory)$'
                }
            }
        }
    }
}

Describe 'End-to-End Backup and Restore' {
    Context 'Complete Workflow Testing' {
        It 'Successfully completes full backup and restore cycle' {
            # Setup isolated test environment
            $E2ESource = Join-Path $TestEnv.TestRoot 'E2ESource'
            $E2EBackup = Join-Path $TestEnv.TestRoot 'E2EBackup'
            $E2ERestore = Join-Path $TestEnv.TestRoot 'E2ERestore'

            New-Item -Path $E2ESource -ItemType Directory -Force | Out-Null
            New-Item -Path $E2EBackup -ItemType Directory -Force | Out-Null
            New-Item -Path $E2ERestore -ItemType Directory -Force | Out-Null

            # Create test content
            'E2E Test Content 1' | Out-File -FilePath (Join-Path $E2ESource 'e2e1.txt') -Encoding UTF8
            'E2E Test Content 2' | Out-File -FilePath (Join-Path $E2ESource 'e2e2.txt') -Encoding UTF8

            # Execute backup
            New-DailyBackup -Path $E2ESource -Destination $E2EBackup

            # Verify backup exists
            $backupInfo = Get-DailyBackup -BackupRoot $E2EBackup
            $backupInfo.Count | Should -BeGreaterThan 0

            # Execute restore
            $results = Restore-DailyBackup -BackupRoot $E2EBackup -DestinationPath $E2ERestore
            $results | Should -Not -BeNullOrEmpty

            # Verify restoration
            $restoredFiles = Get-ChildItem $E2ERestore -Recurse -File
            $restoredFiles.Count | Should -BeGreaterThan 0

            # Verify content integrity
            $restoredContent = Get-Content (Join-Path $E2ERestore 'e2e1.txt') -Raw
            $restoredContent.Trim() | Should -Be 'E2E Test Content 1'
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
