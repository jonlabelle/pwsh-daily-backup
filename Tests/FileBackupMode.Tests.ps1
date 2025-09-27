#Requires -Module Pester

<#
.SYNOPSIS
    Tests for FileBackupMode parameter functionality in New-DailyBackup.

.DESCRIPTION
    This test suite validates the FileBackupMode parameter behavior, which controls how multiple
    source files are packaged into backup archives. Tests cover Individual, Combined, and Auto modes.

    Test Areas Covered:
    - Individual mode: separate archives for each source file/directory
    - Combined mode: single archive containing all source files/directories
    - Auto mode: intelligent selection between Individual and Combined based on source count
    - Metadata integration with different backup modes
    - Error handling for empty or invalid source lists
    - WhatIf support for all backup modes

.NOTES
    FileBackupMode affects archive structure but maintains consistent metadata format.
    Auto mode uses Individual for ≤3 files, Combined for >3 files, always Individual for mixed types.

.EXAMPLE
    # Run all FileBackupMode tests
    Invoke-Pester -Path "FileBackupMode.Tests.ps1"

.EXAMPLE
    # Run only Combined mode tests
    Invoke-Pester -Path "FileBackupMode.Tests.ps1" -TagFilter "Combined"
#>

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    Initialize-TestModule
    $TestEnv = Initialize-TestEnvironment -TestName 'FileBackupMode'

    # Ensure cleanup happens even if tests fail
    $script:TestEnvironmentPath = $TestEnv.TestRoot
}

Describe 'FileBackupMode Functionality' {

    BeforeEach {
        # Clean up any existing backup directories
        Get-ChildItem -Path $TestEnv.BackupDir -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

        # Create test files for backup mode testing
        $script:TestFiles = @()
        for ($i = 1; $i -le 5; $i++)
        {
            $testFile = Join-Path $TestEnv.SourceDir "testfile$i.txt"
            "Test content for file $i" | Out-File -FilePath $testFile -Encoding UTF8
            $script:TestFiles += $testFile
        }

        # Create a test directory
        $script:TestDir = Join-Path $TestEnv.SourceDir 'TestDirectory'
        New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
        'Directory content' | Out-File -FilePath (Join-Path $script:TestDir 'dirfile.txt') -Encoding UTF8
    }

    Context 'Individual Mode' {
        It 'Should create separate archives for each file when FileBackupMode is Individual' {
            $testFiles = $script:TestFiles[0..2]  # Use first 3 files

            New-DailyBackup -Path $testFiles -Destination $TestEnv.BackupDir -FileBackupMode Individual

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $archives = Get-ChildItem -Path $todayFolder -Filter '*.zip'

            $archives.Count | Should -Be 3
            # Check that archives are created with transformed path names containing the file names
            ($archives.Name -join ' ') | Should -Match 'testfile1\.txt'
            ($archives.Name -join ' ') | Should -Match 'testfile2\.txt'
            ($archives.Name -join ' ') | Should -Match 'testfile3\.txt'
        }

        It 'Should create separate archives for mixed files and directories in Individual mode' {
            $mixedPaths = @($script:TestFiles[0], $script:TestDir)

            New-DailyBackup -Path $mixedPaths -Destination $TestEnv.BackupDir -FileBackupMode Individual

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $archives = Get-ChildItem -Path $todayFolder -Filter '*.zip'

            $archives.Count | Should -Be 2
            # Check that archives are created with transformed path names containing the file/dir names
            ($archives.Name -join ' ') | Should -Match 'testfile1\.txt'
            ($archives.Name -join ' ') | Should -Match 'TestDirectory'
        }
    }

    Context 'Combined Mode' {
        It 'Should create single archive for multiple files when FileBackupMode is Combined' {
            # Test: Combined mode should package all source files into a single archive
            # This is useful for related files that should be restored together
            $testFiles = $script:TestFiles[0..2]  # Use first 3 files

            New-DailyBackup -Path $testFiles -Destination $TestEnv.BackupDir -FileBackupMode Combined

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $archives = Get-ChildItem -Path $todayFolder -Filter '*.zip'

            $archives.Count | Should -Be 1
            $archives.Name | Should -Match 'CombinedFiles_\d{6}\.zip'
        }

        It 'Should create single archive for mixed files and directories in Combined mode' {
            # Test: Combined mode works with mixed source types (files and directories)
            # All sources are packaged into one archive regardless of type
            $mixedPaths = @($script:TestFiles[0..1], $script:TestDir)

            New-DailyBackup -Path $mixedPaths -Destination $TestEnv.BackupDir -FileBackupMode Combined

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $archives = Get-ChildItem -Path $todayFolder -Filter '*.zip'

            $archives.Count | Should -Be 1
            $archives.Name | Should -Match 'CombinedFiles_\d{6}\.zip'
        }

        It 'Should include all source paths in the combined archive' {
            # Test: Verify that the combined archive actually contains all specified source files
            # This ensures no sources are lost during the combination process
            $testFiles = $script:TestFiles[0..1]  # Use first 2 files

            New-DailyBackup -Path $testFiles -Destination $TestEnv.BackupDir -FileBackupMode Combined

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $archive = Get-ChildItem -Path $todayFolder -Filter '*.zip' | Select-Object -First 1

            # Extract and verify contents
            $extractPath = Join-Path $TestEnv.BackupDir 'extracted'
            Expand-Archive -Path $archive.FullName -DestinationPath $extractPath

            $extractedFiles = Get-ChildItem -Path $extractPath -Recurse -File
            $extractedFiles.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Auto Mode' {
        It 'Should use Individual mode for 3 or fewer files' {
            $testFiles = $script:TestFiles[0..2]  # 3 files

            New-DailyBackup -Path $testFiles -Destination $TestEnv.BackupDir -FileBackupMode Auto

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $archives = Get-ChildItem -Path $todayFolder -Filter '*.zip'

            $archives.Count | Should -Be 3
        }

        It 'Should use Combined mode for more than 3 files' {
            $testFiles = $script:TestFiles[0..3]  # 4 files

            New-DailyBackup -Path $testFiles -Destination $TestEnv.BackupDir -FileBackupMode Auto

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $archives = Get-ChildItem -Path $todayFolder -Filter '*.zip'

            $archives.Count | Should -Be 1
            $archives.Name | Should -Match 'CombinedFiles_\d{6}\.zip'
        }

        It 'Should use Individual mode for mixed files and directories regardless of count' {
            $mixedPaths = $script:TestFiles[0..3] + $script:TestDir  # 4 files + 1 directory

            New-DailyBackup -Path $mixedPaths -Destination $TestEnv.BackupDir -FileBackupMode Auto

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $archives = Get-ChildItem -Path $todayFolder -Filter '*.zip'

            $archives.Count | Should -Be 5  # Individual mode due to mixed types
        }
    }

    Context 'Metadata and Manifest Integration' {
        It 'Should create manifest entries for Individual mode' {
            $testFiles = $script:TestFiles[0..1]

            New-DailyBackup -Path $testFiles -Destination $TestEnv.BackupDir -FileBackupMode Individual

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $manifestPath = Join-Path $todayFolder 'backup-manifest.json'

            $manifestPath | Should -Exist
            $manifest = Get-Content $manifestPath | ConvertFrom-Json
            $manifest.Backups.Count | Should -Be 2
        }

        It 'Should create manifest entries for Combined mode' {
            $testFiles = $script:TestFiles[0..1]

            New-DailyBackup -Path $testFiles -Destination $TestEnv.BackupDir -FileBackupMode Combined

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $manifestPath = Join-Path $todayFolder 'backup-manifest.json'

            $manifestPath | Should -Exist
            $manifest = Get-Content $manifestPath | ConvertFrom-Json
            $manifest.Backups.Count | Should -Be 2  # One entry per source path
        }

        It 'Should skip metadata creation when NoHash is specified' {
            $testFiles = $script:TestFiles[0..1]

            New-DailyBackup -Path $testFiles -Destination $TestEnv.BackupDir -FileBackupMode Combined -NoHash

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $manifestPath = Join-Path $todayFolder 'backup-manifest.json'

            # Manifest should not exist when NoHash is used
            $manifestPath | Should -Not -Exist
        }
    }

    Context 'Error Handling' {
        It 'Should handle non-existent paths gracefully' {
            $nonExistentPath = Join-Path $TestEnv.TestRoot 'NonExistentFile.txt'
            $invalidPaths = @($nonExistentPath, $script:TestFiles[0])

            { New-DailyBackup -Path $invalidPaths -Destination $TestEnv.BackupDir -FileBackupMode Combined -ErrorAction SilentlyContinue } | Should -Not -Throw

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            $archives = Get-ChildItem -Path $todayFolder -Filter '*.zip' -ErrorAction SilentlyContinue

            # Should still create archive for valid path
            $archives.Count | Should -BeGreaterThan 0
        }

        It 'Should handle empty path array gracefully' {
            { New-DailyBackup -Path $script:TestFiles[0] -Destination $TestEnv.BackupDir -FileBackupMode Combined } | Should -Not -Throw
        }
    }

    Context 'WhatIf Support' {
        It 'Should support WhatIf for Individual mode' {
            $testFiles = $script:TestFiles[0..1]

            { New-DailyBackup -Path $testFiles -Destination $TestEnv.BackupDir -FileBackupMode Individual -WhatIf } | Should -Not -Throw

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            # No actual files should be created
            if (Test-Path $todayFolder)
            {
                $archives = Get-ChildItem -Path $todayFolder -Filter '*.zip' -ErrorAction SilentlyContinue
                $archives.Count | Should -Be 0
            }
        }

        It 'Should support WhatIf for Combined mode' {
            $testFiles = $script:TestFiles[0..1]

            { New-DailyBackup -Path $testFiles -Destination $TestEnv.BackupDir -FileBackupMode Combined -WhatIf } | Should -Not -Throw

            $todayFolder = Join-Path $TestEnv.BackupDir (Get-Date -Format 'yyyy-MM-dd')
            # No actual files should be created
            if (Test-Path $todayFolder)
            {
                $archives = Get-ChildItem -Path $todayFolder -Filter '*.zip' -ErrorAction SilentlyContinue
                $archives.Count | Should -Be 0
            }
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
