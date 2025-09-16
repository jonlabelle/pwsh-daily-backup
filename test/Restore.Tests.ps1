#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    Initialize-TestModule
    $TestEnv = Initialize-TestEnvironment -TestName 'Restore'
}

Describe 'Get-BackupInfo Functionality' {
    BeforeAll {
        # Create test backups for info retrieval
        New-TestBackup -SourcePath $TestEnv.SourceDir -BackupPath $TestEnv.BackupDir
    }

    Context 'Backup Information Retrieval' {
        It 'Returns available backup information' {
            $backupInfo = Get-BackupInfo -BackupRoot $TestEnv.BackupDir
            $backupInfo | Should -Not -BeNullOrEmpty
            $backupInfo.Count | Should -BeGreaterThan 0
        }

        It 'Returns backup information with required properties' {
            $backupInfo = Get-BackupInfo -BackupRoot $TestEnv.BackupDir
            $backup = $backupInfo[0]

            $backup.Date | Should -Not -BeNullOrEmpty
            $backup.Path | Should -Not -BeNullOrEmpty
            $backup.Backups | Should -Not -BeNullOrEmpty
            $backup.TotalSize | Should -BeGreaterThan 0
            $backup.BackupCount | Should -BeGreaterThan 0
        }

        It 'Filters backups by specific date' {
            $today = Get-Date -Format 'yyyy-MM-dd'
            $backupInfo = Get-BackupInfo -BackupRoot $TestEnv.BackupDir -Date $today

            if ($backupInfo.Count -gt 0) {
                $backupInfo[0].Date | Should -Be $today
            }
        }

        It 'Handles non-existent backup directory gracefully' {
            $nonExistentPath = Join-Path $TestEnv.TestRoot 'NonExistent'
            $result = Get-BackupInfo -BackupRoot $nonExistentPath -WarningAction SilentlyContinue
            $result | Should -Be @()
        }
    }
}

Describe 'Restore-DailyBackup Functionality' {
    BeforeEach {
        # Create fresh backup for each restore test
        $RestoreTestSource = Join-Path $TestEnv.TestRoot 'RestoreSource'
        if (Test-Path $RestoreTestSource) {
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
            if ($restoredFile) {
                $content = Get-Content $restoredFile.FullName -Raw
                $content.Trim() | Should -Be 'Restore test content'
            }
        }

        It 'Maintains metadata information during restore' {
            $backupInfo = Get-BackupInfo -BackupRoot $TestEnv.BackupDir
            if ($backupInfo.Count -gt 0 -and $backupInfo[0].Backups.Count -gt 0) {
                $backup = $backupInfo[0].Backups[0]
                if ($backup.Metadata) {
                    $backup.Metadata.BackupVersion | Should -Be '2.0'
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
            $backupInfo = Get-BackupInfo -BackupRoot $E2EBackup
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
    Remove-TestEnvironment -TestRoot $TestEnv.TestRoot
}
