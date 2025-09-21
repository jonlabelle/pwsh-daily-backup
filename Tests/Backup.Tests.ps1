#Requires -Module Pester

<#
.SYNOPSIS
    Tests for New-DailyBackup core functionality and backup operations.

.DESCRIPTION
    This test suite validates the primary backup functionality of the DailyBackup module,
    including file and directory backup operations, metadata generation, cleanup operations,
    and various parameter combinations.

    Test Areas Covered:
    - Basic backup operations with file and directory sources
    - Date-organized folder structure creation
    - Metadata manifest generation and validation
    - Multiple source path handling
    - File naming and special character handling
    - Backup cleanup operations and retention policies
    - FileBackupMode parameter validation
    - Force parameter behavior
    - WhatIf and dry-run support

.NOTES
    This test file uses the TestHelpers.ps1 functions for environment setup and validation.
    Each test creates an isolated environment to ensure test independence.

.EXAMPLE
    # Run all backup tests
    Invoke-Pester -Path "Backup.Tests.ps1"

.EXAMPLE
    # Run only basic operations tests
    Invoke-Pester -Path "Backup.Tests.ps1" -TagFilter "BasicOperations"
#>

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    Initialize-TestModule
    $TestEnv = Initialize-TestEnvironment -TestName 'Backup'

    # Ensure cleanup happens even if tests fail
    $script:TestEnvironmentPath = $TestEnv.TestRoot
}

Describe 'New-DailyBackup Core Functionality' {
    Context 'Basic Backup Operations' {
        It 'Creates backup with date-organized folder structure' {
            # Test: Verify that backups are organized into date-based folders (YYYY-MM-DD format)
            # This ensures consistent organization and prevents conflicts between daily backup runs
            # Example: C:\Backups\2025-09-21\Users__jon__Documents.zip
            try
            {
                New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

                $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
                $result.BackupLocationExists | Should -Be $true
                $result.ZipCount | Should -BeGreaterThan 0
            }
            catch
            {
                # Ensure cleanup on test failure
                Write-Warning "Test failed, ensuring cleanup: $($_.Exception.Message)"
                throw
            }
        }

        It 'Creates metadata manifest for each backup date' {
            # Test: Verify that backup-manifest.json is created with complete metadata
            # Manifest contains backup version, module version, date, and backup entries for restore operations
            # Example: backup-manifest.json with BackupVersion, ModuleVersion, BackupDate, Backups[]
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $result.MetadataCount | Should -Be 1
            $result.ManifestFile | Should -Not -BeNullOrEmpty

            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName
            $manifest.IsValid | Should -Be $true
            $manifest.HasBackupDate | Should -Be $true
            $manifest.HasBackupVersion | Should -Be $true
        }

        It 'Handles multiple source paths correctly' {
            # Test: Verify that multiple source files/directories can be backed up in a single operation
            # Each source should get its own archive entry and metadata record
            $file1 = Join-Path $TestEnv.SourceDir 'test1.txt'
            $file2 = Join-Path $TestEnv.SourceDir 'test2.txt'

            New-DailyBackup -Path @($file1, $file2) -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $result.ZipCount | Should -Be 2
            $result.MetadataCount | Should -Be 1  # One manifest file

            # Check manifest content for multiple backups
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName
            $manifest.BackupCount | Should -Be 2
        }

        It 'Differentiates between file and directory backups' {
            # Test: Verify that mixed file and directory sources are handled correctly
            # PathType metadata should accurately reflect whether the source was a file or directory
            $testFile = Join-Path $TestEnv.SourceDir 'test1.txt'
            $testDir = Join-Path $TestEnv.SourceDir 'SubFolder'

            New-DailyBackup -Path @($testFile, $testDir) -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $result.ZipCount | Should -Be 2
            $result.MetadataCount | Should -Be 1  # One manifest file

            # Check manifest content for multiple backups
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName
            $manifest.BackupCount | Should -Be 2

            # Verify metadata contains correct PathType for each backup
            $fileBackup = $manifest.Content.Backups | Where-Object { $_.PathType -eq 'File' }
            $dirBackup = $manifest.Content.Backups | Where-Object { $_.PathType -eq 'Directory' }
            $fileBackup | Should -Not -BeNullOrEmpty
            $dirBackup | Should -Not -BeNullOrEmpty
        }
    }

    Context 'File Naming and Paths' {
        It 'Handles files with special characters' {
            $specialFile = Join-Path $TestEnv.SourceDir 'file with spaces.txt'
            'Special content' | Out-File -FilePath $specialFile -Encoding UTF8

            { New-DailyBackup -Path $specialFile -Destination $TestEnv.BackupDir } | Should -Not -Throw

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $result.ZipCount | Should -BeGreaterThan 0
        }

        It 'Preserves original path information in metadata' {
            $testFile = Join-Path $TestEnv.SourceDir 'test1.txt'
            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            # Get the first backup entry from the manifest
            $backup = $manifest.Content.Backups[0]
            $backup.SourcePath | Should -Be $testFile
        }

        It 'Handles tilde expansion in source paths' {
            # Skip test if not on Unix-like system where HOME is available
            if (-not $env:HOME)
            {
                Set-ItResult -Skipped -Because 'Test only applicable on Unix-like systems with HOME environment variable'
                return
            }

            # Create a test file in a subdirectory of HOME
            $testSubDir = Join-Path $env:HOME '.test-tilde-backup'
            $testFile = Join-Path $testSubDir 'tilde-test.txt'

            try
            {
                New-Item -Path $testSubDir -ItemType Directory -Force | Out-Null
                'Tilde expansion test content' | Out-File -FilePath $testFile -Encoding UTF8

                # Use tilde path for backup
                $tildePath = $testFile -replace [regex]::Escape($env:HOME), '~'

                { New-DailyBackup -Path $tildePath -Destination $TestEnv.BackupDir } | Should -Not -Throw

                $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
                $result.ZipCount | Should -BeGreaterThan 0

                # Check that the backup was created and metadata has the expanded path
                $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName
                $backup = $manifest.Content.Backups[0]
                $backup.SourcePath | Should -Be $testFile  # Should be the full expanded path
            }
            finally
            {
                Remove-Item $testSubDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Cleanup Operations' {
        It 'Removes old backups when Keep limit is specified' {
            # Create old backup folders
            $oldDates = @(
                (Get-Date).AddDays(-5).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')
            )

            foreach ($date in $oldDates)
            {
                New-Item -Path (Join-Path $TestEnv.BackupDir $date) -ItemType Directory -Force | Out-Null
            }

            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -Keep 2

            $backupFolders = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '\d{4}-\d{2}-\d{2}' }
            $backupFolders.Count | Should -BeLessOrEqual 2
        }

        It 'Keeps all backups when Keep is -1 (default)' {
            # Create old backup folders
            $oldDates = @(
                (Get-Date).AddDays(-5).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')
            )

            foreach ($date in $oldDates)
            {
                New-Item -Path (Join-Path $TestEnv.BackupDir $date) -ItemType Directory -Force | Out-Null
            }

            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $backupFolders = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '\d{4}-\d{2}-\d{2}' }
            $backupFolders.Count | Should -Be 3  # 2 old + 1 new
        }

        It 'Deletes all old backups when Keep is 0' {
            # Create old backup folders
            $oldDate = (Get-Date).AddDays(-5).ToString('yyyy-MM-dd')
            New-Item -Path (Join-Path $TestEnv.BackupDir $oldDate) -ItemType Directory -Force | Out-Null

            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -Keep 0

            $backupFolders = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '\d{4}-\d{2}-\d{2}' }
            $backupFolders.Count | Should -Be 0
        }

        It 'Skips cleanup when NoCleanup parameter is specified' {
            # Create old backup folders
            $oldDates = @(
                (Get-Date).AddDays(-5).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')
            )

            foreach ($date in $oldDates)
            {
                New-Item -Path (Join-Path $TestEnv.BackupDir $date) -ItemType Directory -Force | Out-Null
            }

            # Run backup with NoCleanup - should preserve all old backups
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -Keep 1 -NoCleanup

            $backupFolders = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '\d{4}-\d{2}-\d{2}' }
            $backupFolders.Count | Should -Be 3  # 2 old + 1 new (no cleanup despite Keep=1)
        }

        It 'NoCleanup parameter overrides Keep setting' {
            # Create multiple old backup folders
            $oldDates = @(
                (Get-Date).AddDays(-10).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-7).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-5).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')
            )

            foreach ($date in $oldDates)
            {
                New-Item -Path (Join-Path $TestEnv.BackupDir $date) -ItemType Directory -Force | Out-Null
            }

            # Run backup with NoCleanup and aggressive Keep setting
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -Keep 0 -NoCleanup

            $backupFolders = Get-ChildItem -Path $TestEnv.BackupDir -Directory | Where-Object { $_.Name -match '\d{4}-\d{2}-\d{2}' }
            $backupFolders.Count | Should -Be 5  # 4 old + 1 new (no cleanup despite Keep=0)
        }
    }

    Context 'FileBackupMode Parameter' {
        It 'Accepts valid FileBackupMode values without errors' {
            { New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -FileBackupMode 'Individual' -WhatIf } | Should -Not -Throw
            { New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -FileBackupMode 'Combined' -WhatIf } | Should -Not -Throw
            { New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -FileBackupMode 'Auto' -WhatIf } | Should -Not -Throw
        }
    }

    Context 'Force Parameter' {
        BeforeEach {
            # Create a fresh test environment for Force tests
            $TestEnv.ForceTestDir = Join-Path $TestEnv.TestRoot 'ForceTest'
            $TestEnv.ForceSourceDir = Join-Path $TestEnv.ForceTestDir 'Source'
            $TestEnv.ForceBackupDir = Join-Path $TestEnv.ForceTestDir 'Backup'

            New-Item -Path $TestEnv.ForceSourceDir -ItemType Directory -Force | Out-Null
            'Test content for Force parameter' | Out-File -FilePath (Join-Path $TestEnv.ForceSourceDir 'force-test.txt')
        }

        It 'Replaces existing backup directory when Force is specified' {
            # Create initial backup
            New-DailyBackup -Path $TestEnv.ForceSourceDir -Destination $TestEnv.ForceBackupDir

            # Verify backup exists
            $todayFolder = Get-Date -Format 'yyyy-MM-dd'
            $todayBackupDir = Join-Path $TestEnv.ForceBackupDir $todayFolder
            $todayBackupDir | Should -Exist

            # Second backup with Force should succeed without prompting
            { New-DailyBackup -Path $TestEnv.ForceSourceDir -Destination $TestEnv.ForceBackupDir -Force } | Should -Not -Throw

            # Verify backup directory still exists
            $todayBackupDir | Should -Exist
        }

        It 'Works with WhatIf when backup directory already exists' {
            # Create initial backup
            New-DailyBackup -Path $TestEnv.ForceSourceDir -Destination $TestEnv.ForceBackupDir

            # WhatIf should work even when directory exists
            { New-DailyBackup -Path $TestEnv.ForceSourceDir -Destination $TestEnv.ForceBackupDir -WhatIf } | Should -Not -Throw
            { New-DailyBackup -Path $TestEnv.ForceSourceDir -Destination $TestEnv.ForceBackupDir -Force -WhatIf } | Should -Not -Throw
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
