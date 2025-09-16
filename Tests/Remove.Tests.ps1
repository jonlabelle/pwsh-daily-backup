#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    Initialize-TestModule
    $TestEnv = Initialize-TestEnvironment -TestName 'RemoveDailyBackup'
}

Describe 'Remove-DailyBackup Functionality' {
    Context 'Retention-based Cleanup' {
        BeforeEach {
            # Clean up any existing directories first
            Get-ChildItem -Path $TestEnv.BackupDir -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

            # Create test backup directories with different dates
            $testDates = @(
                (Get-Date).AddDays(-10).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-7).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-5).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-3).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
            )

            foreach ($date in $testDates)
            {
                $dateDir = New-Item -Path (Join-Path $TestEnv.BackupDir $date) -ItemType Directory -Force
                # Add a dummy backup file to make the test more realistic
                'Test backup content' | Out-File -FilePath (Join-Path $dateDir.FullName 'test.zip') -Encoding UTF8
            }
        }

        It 'Removes oldest backups when Keep parameter is specified' {
            Remove-DailyBackup -Path $TestEnv.BackupDir -Keep 3

            $remainingDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
            $remainingDirs.Count | Should -Be 3

            # Verify the newest 3 directories remain
            $expectedDates = @(
                (Get-Date).AddDays(-5).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-3).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
            )

            foreach ($date in $expectedDates)
            {
                $remainingDirs.Name | Should -Contain $date
            }
        }

        It 'Removes all backups when Keep is 0' {
            Remove-DailyBackup -Path $TestEnv.BackupDir -Keep 0

            $remainingDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
            $remainingDirs.Count | Should -Be 0
        }

        It 'Does nothing when backup count is less than or equal to Keep value' {
            Remove-DailyBackup -Path $TestEnv.BackupDir -Keep 10

            $remainingDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
            $remainingDirs.Count | Should -Be 5  # All original directories should remain
        }

        It 'Uses default Keep value of 7 when not specified' {
            # Add more directories to test default behavior
            $additionalDates = @(
                (Get-Date).AddDays(-15).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-12).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-9).ToString('yyyy-MM-dd')
            )

            foreach ($date in $additionalDates)
            {
                $dateDir = New-Item -Path (Join-Path $TestEnv.BackupDir $date) -ItemType Directory -Force
                'Test backup content' | Out-File -FilePath (Join-Path $dateDir.FullName 'test.zip') -Encoding UTF8
            }

            Remove-DailyBackup -Path $TestEnv.BackupDir

            $remainingDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
            $remainingDirs.Count | Should -Be 7  # Default Keep value
        }
    }

    Context 'Specific Date Removal' {
        BeforeEach {
            # Clean up any existing directories first
            Get-ChildItem -Path $TestEnv.BackupDir -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

            # Create test backup directories
            $testDates = @(
                (Get-Date).AddDays(-7).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-5).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')
            )

            foreach ($date in $testDates)
            {
                $dateDir = New-Item -Path (Join-Path $TestEnv.BackupDir $date) -ItemType Directory -Force
                'Test backup content' | Out-File -FilePath (Join-Path $dateDir.FullName 'test.zip') -Encoding UTF8
            }
        }

        It 'Removes specific backup date when Date parameter is provided' {
            $targetDate = (Get-Date).AddDays(-5).ToString('yyyy-MM-dd')
            Remove-DailyBackup -Path $TestEnv.BackupDir -Date $targetDate

            $remainingDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
            $remainingDirs.Count | Should -Be 2
            $remainingDirs.Name | Should -Not -Contain $targetDate
        }

        It 'Shows warning when specified date does not exist' {
            $nonExistentDate = '2020-01-01'
            Remove-DailyBackup -Path $TestEnv.BackupDir -Date $nonExistentDate -WarningVariable warnings 3>&1

            $warnings | Should -Not -BeNullOrEmpty
            $warnings[0] | Should -Match "No backup found for date: $nonExistentDate"
        }

        It 'Cannot use Date and Keep parameters together' {
            { Remove-DailyBackup -Path $TestEnv.BackupDir -Date '2025-01-01' -Keep 5 } | Should -Throw
        }
    }

    Context 'Input Validation and Error Handling' {
        It 'Validates Date parameter format' {
            { Remove-DailyBackup -Path $TestEnv.BackupDir -Date 'invalid-date' } | Should -Throw
            { Remove-DailyBackup -Path $TestEnv.BackupDir -Date '2025-1-1' } | Should -Throw
            { Remove-DailyBackup -Path $TestEnv.BackupDir -Date '25-01-01' } | Should -Throw
        }

        It 'Validates Keep parameter range' {
            { Remove-DailyBackup -Path $TestEnv.BackupDir -Keep -1 } | Should -Throw
        }

        It 'Handles non-existent backup root directory' {
            $nonExistentPath = Join-Path $TestEnv.TestRoot 'nonexistent'
            { Remove-DailyBackup -Path $nonExistentPath -Keep 5 } | Should -Throw
        }

        It 'Ignores non-date directories' {
            # Create some non-date directories
            New-Item -Path (Join-Path $TestEnv.BackupDir 'not-a-date') -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $TestEnv.BackupDir 'also-not-date') -ItemType Directory -Force | Out-Null

            # Create one valid date directory
            $validDate = (Get-Date).ToString('yyyy-MM-dd')
            New-Item -Path (Join-Path $TestEnv.BackupDir $validDate) -ItemType Directory -Force | Out-Null

            Remove-DailyBackup -Path $TestEnv.BackupDir -Keep 0

            # Non-date directories should remain
            $allDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory
            $allDirs.Count | Should -Be 2
            $allDirs.Name | Should -Contain 'not-a-date'
            $allDirs.Name | Should -Contain 'also-not-date'

            # Date directory should be removed
            $allDirs.Name | Should -Not -Contain $validDate
        }
    }

    Context 'Pipeline Support' {
        It 'Accepts path from pipeline' -Skip {
            # Create test backup directory
            $testDate = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
            $dateDir = New-Item -Path (Join-Path $TestEnv.BackupDir $testDate) -ItemType Directory -Force
            'Test backup content' | Out-File -FilePath (Join-Path $dateDir.FullName 'test.zip') -Encoding UTF8

            # Use explicit string array to test pipeline input
            @($TestEnv.BackupDir) | Remove-DailyBackup -Keep 0

            $remainingDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
            $remainingDirs.Count | Should -Be 0
        }
    }

    Context 'ShouldProcess Support' {
        BeforeEach {
            # Clean up any existing directories
            Get-ChildItem -Path $TestEnv.BackupDir -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

            # Create test backup directory
            $testDate = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
            $dateDir = New-Item -Path (Join-Path $TestEnv.BackupDir $testDate) -ItemType Directory -Force
            'Test backup content' | Out-File -FilePath (Join-Path $dateDir.FullName 'test.zip') -Encoding UTF8
        }

        It 'Supports WhatIf parameter' {
            Remove-DailyBackup -Path $TestEnv.BackupDir -Keep 0 -WhatIf

            # Directory should still exist with WhatIf
            $remainingDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
            $remainingDirs.Count | Should -Be 1
        }

        It 'Force parameter bypasses confirmation' -Skip {
            # This test verifies Force works without interaction
            Remove-DailyBackup -Path $TestEnv.BackupDir -Keep 0 -Force

            $remainingDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
            $remainingDirs.Count | Should -Be 0
        }
    }

    Context 'Alias Support' {
        It 'Supports BackupRoot alias for Path parameter' -Skip {
            # Clean up and create test directory
            Get-ChildItem -Path $TestEnv.BackupDir -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

            $testDate = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
            $dateDir = New-Item -Path (Join-Path $TestEnv.BackupDir $testDate) -ItemType Directory -Force
            'Test backup content' | Out-File -FilePath (Join-Path $dateDir.FullName 'test.zip') -Encoding UTF8

            Remove-DailyBackup -BackupRoot $TestEnv.BackupDir -Keep 0

            $remainingDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
            $remainingDirs.Count | Should -Be 0
        }

        It 'Supports BackupsToKeep alias for Keep parameter' -Skip {
            # Clean up and create test directory
            Get-ChildItem -Path $TestEnv.BackupDir -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

            $testDate = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
            $dateDir = New-Item -Path (Join-Path $TestEnv.BackupDir $testDate) -ItemType Directory -Force
            'Test backup content' | Out-File -FilePath (Join-Path $dateDir.FullName 'test.zip') -Encoding UTF8

            Remove-DailyBackup -Path $TestEnv.BackupDir -BackupsToKeep 0

            $remainingDirs = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }
            $remainingDirs.Count | Should -Be 0
        }
    }
}

AfterAll {
    Remove-TestEnvironment -TestRoot $TestEnv.TestRoot
}
