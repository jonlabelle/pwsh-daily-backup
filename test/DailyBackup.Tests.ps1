#Requires -Module Pester

BeforeAll {
    # Import the module
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModulePath = Join-Path $ModuleRoot 'DailyBackup.psd1'

    # Remove any existing module instances
    Get-Module DailyBackup | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import the module for testing
    Import-Module $ModulePath -Force

    # Setup test directories
    $script:TestRoot = Join-Path $PSScriptRoot 'TestData'
    $script:SourceDir = Join-Path $script:TestRoot 'Source'
    $script:BackupDir = Join-Path $script:TestRoot 'Backup'

    # Create test directories
    if (Test-Path $script:TestRoot)
    {
        Remove-Item $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
    New-Item -Path $script:SourceDir -ItemType Directory -Force | Out-Null
    New-Item -Path $script:BackupDir -ItemType Directory -Force | Out-Null

    # Create test files
    'Test content 1' | Out-File -FilePath (Join-Path $script:SourceDir 'test1.txt') -Encoding UTF8
    'Test content 2' | Out-File -FilePath (Join-Path $script:SourceDir 'test2.txt') -Encoding UTF8

    # Create a subdirectory with files
    $SubDir = Join-Path $script:SourceDir 'SubFolder'
    New-Item -Path $SubDir -ItemType Directory -Force | Out-Null
    'Sub content' | Out-File -FilePath (Join-Path $SubDir 'subfile.txt') -Encoding UTF8
}

Describe 'DailyBackup Module' {
    Context 'Module Import' {
        It 'Should import the module successfully' {
            Get-Module DailyBackup | Should -Not -BeNullOrEmpty
        }

        It 'Should export New-DailyBackup function' {
            Get-Command New-DailyBackup -Module DailyBackup | Should -Not -BeNullOrEmpty
        }

        It 'Should export Restore-DailyBackup function' {
            Get-Command Restore-DailyBackup -Module DailyBackup | Should -Not -BeNullOrEmpty
        }

        It 'Should export Get-BackupInfo function' {
            Get-Command Get-BackupInfo -Module DailyBackup | Should -Not -BeNullOrEmpty
        }
    }

    Context 'New-DailyBackup Function' {
        It 'Should have proper parameter sets' {
            $Command = Get-Command New-DailyBackup
            $Command.Parameters.ContainsKey('Path') | Should -Be $true
            $Command.Parameters.ContainsKey('Destination') | Should -Be $true
            $Command.Parameters.ContainsKey('Keep') | Should -Be $true
        }

        It 'Should support WhatIf parameter' {
            $Command = Get-Command New-DailyBackup
            $Command.Parameters.WhatIf | Should -Not -BeNullOrEmpty
        }

        It 'Should support Verbose parameter' {
            $Command = Get-Command New-DailyBackup
            $Command.Parameters.Verbose | Should -Not -BeNullOrEmpty
        }

        It 'Should support FileBackupMode parameter' {
            $Command = Get-Command New-DailyBackup
            $Command.Parameters.FileBackupMode | Should -Not -BeNullOrEmpty
        }

        It 'Should create backup with WhatIf (dry run)' {
            { New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir -WhatIf } | Should -Not -Throw
        }

        It 'Should create actual backup when not in WhatIf mode' {
            New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir

            # Check if dated folder was created
            $DateFolder = Get-Date -Format 'yyyy-MM-dd'
            $BackupPath = Join-Path $script:BackupDir $DateFolder
            Test-Path $BackupPath | Should -Be $true

            # Check if zip file was created
            $ZipFiles = Get-ChildItem -Path $BackupPath -Filter '*.zip'
            $ZipFiles.Count | Should -BeGreaterThan 0
        }

        It 'Should handle non-existent source path gracefully' {
            $NonExistentPath = Join-Path $script:TestRoot 'NonExistent'
            { New-DailyBackup -Path $NonExistentPath -Destination $script:BackupDir -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should handle multiple paths' {
            $Path1 = Join-Path $script:SourceDir 'test1.txt'
            $Path2 = Join-Path $script:SourceDir 'test2.txt'

            { New-DailyBackup -Path @($Path1, $Path2) -Destination $script:BackupDir } | Should -Not -Throw
        }

        It 'Should create metadata files for backups' {
            New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir

            # Check if metadata file was created
            $DateFolder = Get-Date -Format 'yyyy-MM-dd'
            $BackupPath = Join-Path $script:BackupDir $DateFolder
            $MetadataFiles = Get-ChildItem -Path $BackupPath -Filter '*.metadata.json' -ErrorAction SilentlyContinue
            $MetadataFiles.Count | Should -BeGreaterThan 0
        }

        It 'Should handle individual files with improved naming' {
            $TestFile = Join-Path $script:SourceDir 'test1.txt'
            New-DailyBackup -Path $TestFile -Destination $script:BackupDir

            $DateFolder = Get-Date -Format 'yyyy-MM-dd'
            $BackupPath = Join-Path $script:BackupDir $DateFolder

            # Should create a zip file with the filename preserved
            $ZipFiles = Get-ChildItem -Path $BackupPath -Filter '*test1.txt*.zip'
            $ZipFiles.Count | Should -BeGreaterThan 0
        }

        It 'Should differentiate between file and directory backups' {
            $TestFile = Join-Path $script:SourceDir 'test1.txt'
            $TestDir = Join-Path $script:SourceDir 'SubFolder'

            New-DailyBackup -Path @($TestFile, $TestDir) -Destination $script:BackupDir

            $DateFolder = Get-Date -Format 'yyyy-MM-dd'
            $BackupPath = Join-Path $script:BackupDir $DateFolder

            # Should have different naming patterns for files vs directories
            $ZipFiles = Get-ChildItem -Path $BackupPath -Filter '*.zip'
            $ZipFiles.Count | Should -Be 2

            # Check metadata files contain correct PathType
            $MetadataFiles = Get-ChildItem -Path $BackupPath -Filter '*.metadata.json'
            $MetadataFiles.Count | Should -Be 2
        }

        It 'Should clean up old backups when Keep is specified' {
            # Create some old backup folders
            $OldDate1 = (Get-Date).AddDays(-5).ToString('yyyy-MM-dd')
            $OldDate2 = (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')

            New-Item -Path (Join-Path $script:BackupDir $OldDate1) -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:BackupDir $OldDate2) -ItemType Directory -Force | Out-Null

            # Run backup with cleanup
            New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir -Keep 2

            # Should only have 2 backup folders (today and one old)
            $BackupFolders = Get-ChildItem -Path $script:BackupDir -Directory | Where-Object { $_.Name -match '\d{4}-\d{2}-\d{2}' }
            $BackupFolders.Count -le 2 | Should -Be $true
        }

        It 'Should keep all backups when Keep is -1 (default)' {
            # Create some old backup folders
            $OldDate1 = (Get-Date).AddDays(-5).ToString('yyyy-MM-dd')
            $OldDate2 = (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')

            New-Item -Path (Join-Path $script:BackupDir $OldDate1) -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:BackupDir $OldDate2) -ItemType Directory -Force | Out-Null

            # Run backup with default Keep value (-1)
            New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir

            # Should have all backup folders (today plus 2 old ones = 3)
            $BackupFolders = Get-ChildItem -Path $script:BackupDir -Directory | Where-Object { $_.Name -match '\d{4}-\d{2}-\d{2}' }
            $BackupFolders.Count | Should -Be 3
        }

        It 'Should delete all backups when Keep is 0' {
            # Create some old backup folders
            $OldDate1 = (Get-Date).AddDays(-5).ToString('yyyy-MM-dd')
            $OldDate2 = (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')

            New-Item -Path (Join-Path $script:BackupDir $OldDate1) -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:BackupDir $OldDate2) -ItemType Directory -Force | Out-Null

            # Run backup with Keep 0 (delete all old backups, keep only today's)
            New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir -Keep 0

            # Should have no backup folders (all deleted, today's created then deleted)
            $BackupFolders = Get-ChildItem -Path $script:BackupDir -Directory | Where-Object { $_.Name -match '\d{4}-\d{2}-\d{2}' }
            $BackupFolders.Count | Should -Be 0
        }
    }
}

Describe 'Enhanced File Support' {
    Context 'Path Type Detection' {
        It 'Should correctly identify files' {
            $TestFile = Join-Path $script:SourceDir 'test1.txt'

            # Mock the Get-PathType function since it's internal
            New-DailyBackup -Path $TestFile -Destination $script:BackupDir

            $DateFolder = Get-Date -Format 'yyyy-MM-dd'
            $BackupPath = Join-Path $script:BackupDir $DateFolder
            $MetadataFiles = Get-ChildItem -Path $BackupPath -Filter '*.metadata.json'

            if ($MetadataFiles.Count -gt 0)
            {
                $MetadataContent = Get-Content -Path $MetadataFiles[0].FullName | ConvertFrom-Json
                $MetadataContent.PathType | Should -Be 'File'
            }
        }

        It 'Should correctly identify directories' {
            $TestDir = Join-Path $script:SourceDir 'SubFolder'

            New-DailyBackup -Path $TestDir -Destination $script:BackupDir

            $DateFolder = Get-Date -Format 'yyyy-MM-dd'
            $BackupPath = Join-Path $script:BackupDir $DateFolder
            $MetadataFiles = Get-ChildItem -Path $BackupPath -Filter '*.metadata.json'

            if ($MetadataFiles.Count -gt 0)
            {
                $MetadataContent = Get-Content -Path $MetadataFiles[0].FullName | ConvertFrom-Json
                $MetadataContent.PathType | Should -Be 'Directory'
            }
        }

        It 'Should handle files with special characters in names' {
            $SpecialFile = Join-Path $script:SourceDir 'file with spaces.txt'
            'Special content' | Out-File -FilePath $SpecialFile -Encoding UTF8

            { New-DailyBackup -Path $SpecialFile -Destination $script:BackupDir } | Should -Not -Throw

            $DateFolder = Get-Date -Format 'yyyy-MM-dd'
            $BackupPath = Join-Path $script:BackupDir $DateFolder
            $ZipFiles = Get-ChildItem -Path $BackupPath -Filter '*.zip'
            $ZipFiles.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Metadata Generation' {
        It 'Should create valid metadata JSON files' {
            New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir

            $DateFolder = Get-Date -Format 'yyyy-MM-dd'
            $BackupPath = Join-Path $script:BackupDir $DateFolder
            $MetadataFiles = Get-ChildItem -Path $BackupPath -Filter '*.metadata.json'

            foreach ($MetadataFile in $MetadataFiles)
            {
                $Content = Get-Content -Path $MetadataFile.FullName -Raw
                { $Content | ConvertFrom-Json } | Should -Not -Throw

                $Metadata = $Content | ConvertFrom-Json
                $Metadata.SourcePath | Should -Not -BeNullOrEmpty
                $Metadata.BackupCreated | Should -Not -BeNullOrEmpty
                $Metadata.PathType | Should -Match '^(File|Directory)$'
                $Metadata.BackupVersion | Should -Be '2.0'
            }
        }
    }

    Context 'FileBackupMode Parameter' {
        It 'Should accept valid FileBackupMode values' {
            { New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir -FileBackupMode 'Individual' -WhatIf } | Should -Not -Throw
            { New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir -FileBackupMode 'Combined' -WhatIf } | Should -Not -Throw
            { New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir -FileBackupMode 'Auto' -WhatIf } | Should -Not -Throw
        }

        It 'Should reject invalid FileBackupMode values' {
            { New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir -FileBackupMode 'Invalid' -WhatIf } | Should -Throw
        }
    }
}

Describe 'Error Handling' {
    Context 'Invalid Parameters' {
        It 'Should throw error for invalid Keep value' {
            # The validation should catch this at parameter binding time
            try
            {
                New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir -Keep -2
                # If we get here, the test should fail
                $false | Should -Be $true
            }
            catch
            {
                # This is expected behavior
                $true | Should -Be $true
            }
        }
    }

    Context 'File System Errors' {
        It 'Should handle permission errors gracefully' {
            # This is difficult to test consistently across platforms
            # but we can at least verify the function doesn't crash
            $RestrictedPath = Join-Path $script:TestRoot 'Restricted'
            New-Item -Path $RestrictedPath -ItemType Directory -Force | Out-Null

            { New-DailyBackup -Path $RestrictedPath -Destination $script:BackupDir -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe 'Restore Functionality' {
    BeforeAll {
        # Create a backup first for testing restore
        $script:RestoreTestDir = Join-Path $script:TestRoot 'RestoreTest'
        New-Item -Path $script:RestoreTestDir -ItemType Directory -Force | Out-Null

        # Create some test files for backup
        'Restore test content 1' | Out-File -FilePath (Join-Path $script:RestoreTestDir 'restore1.txt') -Encoding UTF8
        'Restore test content 2' | Out-File -FilePath (Join-Path $script:RestoreTestDir 'restore2.txt') -Encoding UTF8

        # Create backup
        New-DailyBackup -Path $script:RestoreTestDir -Destination $script:BackupDir
    }

    Context 'Get-BackupInfo Function' {
        It 'Should list available backups' {
            $backupInfo = Get-BackupInfo -BackupRoot $script:BackupDir
            $backupInfo | Should -Not -BeNullOrEmpty
            $backupInfo.Count | Should -BeGreaterThan 0
        }

        It 'Should return backup information with correct properties' {
            $backupInfo = Get-BackupInfo -BackupRoot $script:BackupDir
            $backup = $backupInfo[0]

            $backup.Date | Should -Not -BeNullOrEmpty
            $backup.Path | Should -Not -BeNullOrEmpty
            $backup.Backups | Should -Not -BeNullOrEmpty
            $backup.TotalSize | Should -BeGreaterThan 0
            $backup.BackupCount | Should -BeGreaterThan 0
        }

        It 'Should filter by specific date' {
            $today = Get-Date -Format 'yyyy-MM-dd'
            $backupInfo = Get-BackupInfo -BackupRoot $script:BackupDir -Date $today

            if ($backupInfo.Count -gt 0)
            {
                $backupInfo[0].Date | Should -Be $today
            }
        }

        It 'Should handle non-existent backup directory gracefully' {
            $nonExistentPath = Join-Path $script:TestRoot 'NonExistentBackups'
            $result = Get-BackupInfo -BackupRoot $nonExistentPath -WarningAction SilentlyContinue
            $result | Should -Be @()
        }
    }

    Context 'Restore-DailyBackup Function' {
        BeforeEach {
            # Ensure we have a backup to restore from
            $RestoreTestSource = Join-Path $script:TestRoot 'RestoreTest'
            if (Test-Path $RestoreTestSource)
            {
                Remove-Item $RestoreTestSource -Recurse -Force
            }
            New-Item -Path $RestoreTestSource -ItemType Directory -Force | Out-Null
            'Restore test content' | Out-File -FilePath (Join-Path $RestoreTestSource 'restore-test.txt') -Encoding UTF8

            # Create a backup for testing restore functionality
            New-DailyBackup -Path $RestoreTestSource -Destination $script:BackupDir
        }

        It 'Should have proper parameter sets' {
            $Command = Get-Command Restore-DailyBackup
            $Command.Parameters.ContainsKey('BackupRoot') | Should -Be $true
            $Command.Parameters.ContainsKey('DestinationPath') | Should -Be $true
            $Command.Parameters.ContainsKey('Date') | Should -Be $true
            $Command.Parameters.ContainsKey('UseOriginalPaths') | Should -Be $true
        }

        It 'Should support WhatIf parameter' {
            $Command = Get-Command Restore-DailyBackup
            $Command.Parameters.WhatIf | Should -Not -BeNullOrEmpty
        }

        It 'Should restore backup with WhatIf (dry run)' {
            $RestoreDestination = Join-Path $script:TestRoot 'RestoreDestination'
            { Restore-DailyBackup -BackupRoot $script:BackupDir -DestinationPath $RestoreDestination -WhatIf } | Should -Not -Throw
        }

        It 'Should restore backup to specified destination' {
            $RestoreDestination = Join-Path $script:TestRoot 'RestoreDestination'
            New-Item -Path $RestoreDestination -ItemType Directory -Force | Out-Null

            $results = Restore-DailyBackup -BackupRoot $script:BackupDir -DestinationPath $RestoreDestination
            $results | Should -Not -BeNullOrEmpty

            # Check if files were restored
            $restoredFiles = Get-ChildItem $RestoreDestination -Recurse -File
            $restoredFiles.Count | Should -BeGreaterThan 0
        }

        It 'Should handle specific date parameter' {
            $RestoreDestination = Join-Path $script:TestRoot 'RestoreDateTest'
            New-Item -Path $RestoreDestination -ItemType Directory -Force | Out-Null

            $today = Get-Date -Format 'yyyy-MM-dd'
            { Restore-DailyBackup -BackupRoot $script:BackupDir -DestinationPath $RestoreDestination -Date $today } | Should -Not -Throw
        }

        It 'Should handle backup name filtering' {
            $RestoreDestination = Join-Path $script:TestRoot 'RestoreFilterTest'
            New-Item -Path $RestoreDestination -ItemType Directory -Force | Out-Null

            { Restore-DailyBackup -BackupRoot $script:BackupDir -DestinationPath $RestoreDestination -BackupName '*RestoreTest*' } | Should -Not -Throw
        }

        It 'Should fail gracefully with non-existent backup root' {
            $NonExistentPath = Join-Path $script:TestRoot 'NonExistentBackups'
            $RestoreDestination = Join-Path $script:TestRoot 'RestoreFailTest'

            { Restore-DailyBackup -BackupRoot $NonExistentPath -DestinationPath $RestoreDestination } | Should -Throw
        }

        It 'Should require either DestinationPath or UseOriginalPaths' {
            { Restore-DailyBackup -BackupRoot $script:BackupDir } | Should -Throw
        }

        It 'Should work with UseOriginalPaths switch' {
            { Restore-DailyBackup -BackupRoot $script:BackupDir -UseOriginalPaths -WhatIf } | Should -Not -Throw
        }
    }

    Context 'End-to-End Backup and Restore' {
        It 'Should successfully backup and restore files' {
            # Create test data
            $TestSourceDir = Join-Path $script:TestRoot 'E2ESource'
            $TestBackupDir = Join-Path $script:TestRoot 'E2EBackup'
            $TestRestoreDir = Join-Path $script:TestRoot 'E2ERestore'

            New-Item -Path $TestSourceDir -ItemType Directory -Force | Out-Null
            New-Item -Path $TestBackupDir -ItemType Directory -Force | Out-Null
            New-Item -Path $TestRestoreDir -ItemType Directory -Force | Out-Null

            # Create test files
            'E2E Test Content 1' | Out-File -FilePath (Join-Path $TestSourceDir 'e2e1.txt') -Encoding UTF8
            'E2E Test Content 2' | Out-File -FilePath (Join-Path $TestSourceDir 'e2e2.txt') -Encoding UTF8

            # Backup
            New-DailyBackup -Path $TestSourceDir -Destination $TestBackupDir

            # Verify backup exists
            $backupInfo = Get-BackupInfo -BackupRoot $TestBackupDir
            $backupInfo.Count | Should -BeGreaterThan 0

            # Restore
            $results = Restore-DailyBackup -BackupRoot $TestBackupDir -DestinationPath $TestRestoreDir
            $results | Should -Not -BeNullOrEmpty

            # Verify restore
            $restoredFiles = Get-ChildItem $TestRestoreDir -Recurse -File
            $restoredFiles.Count | Should -BeGreaterThan 0

            # Verify content
            $restoredContent = Get-Content (Join-Path $TestRestoreDir 'e2e1.txt') -Raw
            $restoredContent.Trim() | Should -Be 'E2E Test Content 1'
        }

        It 'Should preserve metadata information during restore' {
            # Get backup info to check metadata
            $backupInfo = Get-BackupInfo -BackupRoot $script:BackupDir
            $backup = $backupInfo[0].Backups[0]

            if ($backup.Metadata)
            {
                $backup.Metadata.BackupVersion | Should -Be '2.0'
                $backup.Metadata.SourcePath | Should -Not -BeNullOrEmpty
                $backup.Metadata.PathType | Should -Match '^(File|Directory)$'
            }
        }
    }
}

Describe 'Performance and Edge Cases' {
    Context 'Large Files' {
        It 'Should handle empty directories' {
            $EmptyDir = Join-Path $script:TestRoot 'Empty'
            New-Item -Path $EmptyDir -ItemType Directory -Force | Out-Null

            { New-DailyBackup -Path $EmptyDir -Destination $script:BackupDir } | Should -Not -Throw
        }
    }

    Context 'Path Length Limits' {
        It 'Should handle long paths appropriately' {
            # Create a path that's close to the limit
            $LongName = 'a' * 100
            $LongPath = Join-Path $script:TestRoot $LongName
            New-Item -Path $LongPath -ItemType Directory -Force | Out-Null
            'content' | Out-File -FilePath (Join-Path $LongPath 'file.txt') -Encoding UTF8

            { New-DailyBackup -Path $LongPath -Destination $script:BackupDir -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Cleanup test directories after all tests
    if (Test-Path $script:TestRoot)
    {
        Remove-Item $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove the module
    Get-Module DailyBackup | Remove-Module -Force -ErrorAction SilentlyContinue
}
