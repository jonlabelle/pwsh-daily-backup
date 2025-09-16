#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    Initialize-TestModule
    $TestEnv = Initialize-TestEnvironment -TestName 'Backup'
}

Describe 'New-DailyBackup Core Functionality' {
    Context 'Basic Backup Operations' {
        It 'Creates backup with date-organized folder structure' {
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $result.BackupLocationExists | Should -Be $true
            $result.ZipCount | Should -BeGreaterThan 0
        }

        It 'Creates metadata files for each backup' {
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $result.MetadataCount | Should -BeGreaterThan 0

            $metadata = Test-MetadataContent -MetadataPath $result.MetadataFiles[0].FullName
            $metadata.IsValid | Should -Be $true
            $metadata.HasSourcePath | Should -Be $true
            $metadata.HasBackupVersion | Should -Be $true
        }

        It 'Handles multiple source paths correctly' {
            $file1 = Join-Path $TestEnv.SourceDir 'test1.txt'
            $file2 = Join-Path $TestEnv.SourceDir 'test2.txt'

            New-DailyBackup -Path @($file1, $file2) -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir -ExpectedZipCount 2 -ExpectedMetadataCount 2
            $result.ZipCount | Should -Be 2
            $result.MetadataCount | Should -Be 2
        }

        It 'Differentiates between file and directory backups' {
            $testFile = Join-Path $TestEnv.SourceDir 'test1.txt'
            $testDir = Join-Path $TestEnv.SourceDir 'SubFolder'

            New-DailyBackup -Path @($testFile, $testDir) -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir -ExpectedZipCount 2 -ExpectedMetadataCount 2

            # Verify metadata contains correct PathType
            foreach ($metadataFile in $result.MetadataFiles) {
                $metadata = Test-MetadataContent -MetadataPath $metadataFile.FullName
                $metadata.Content.PathType | Should -Match '^(File|Directory)$'
            }
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
            $metadata = Test-MetadataContent -MetadataPath $result.MetadataFiles[0].FullName

            $metadata.Content.SourcePath | Should -Be $testFile
        }
    }

    Context 'Cleanup Operations' {
        It 'Removes old backups when Keep limit is specified' {
            # Create old backup folders
            $oldDates = @(
                (Get-Date).AddDays(-5).ToString('yyyy-MM-dd'),
                (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')
            )

            foreach ($date in $oldDates) {
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

            foreach ($date in $oldDates) {
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
    }

    Context 'FileBackupMode Parameter' {
        It 'Accepts valid FileBackupMode values without errors' {
            { New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -FileBackupMode 'Individual' -WhatIf } | Should -Not -Throw
            { New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -FileBackupMode 'Combined' -WhatIf } | Should -Not -Throw
            { New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir -FileBackupMode 'Auto' -WhatIf } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-TestEnvironment -TestRoot $TestEnv.TestRoot
}
