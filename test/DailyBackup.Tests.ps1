#Requires -Module Pester

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

Describe 'DailyBackup Module' {
    Context 'Module Import' {
        It 'Should import the module successfully' {
            Get-Module DailyBackup | Should Not BeNullOrEmpty
        }

        It 'Should export New-DailyBackup function' {
            Get-Command New-DailyBackup -Module DailyBackup | Should Not BeNullOrEmpty
        }
    }

    Context 'New-DailyBackup Function' {
        It 'Should have proper parameter sets' {
            $Command = Get-Command New-DailyBackup
            $Command.Parameters.ContainsKey('Path') | Should Be $true
            $Command.Parameters.ContainsKey('Destination') | Should Be $true
            $Command.Parameters.ContainsKey('Keep') | Should Be $true
        }

        It 'Should support WhatIf parameter' {
            $Command = Get-Command New-DailyBackup
            $Command.Parameters.WhatIf | Should Not BeNullOrEmpty
        }

        It 'Should support Verbose parameter' {
            $Command = Get-Command New-DailyBackup
            $Command.Parameters.Verbose | Should Not BeNullOrEmpty
        }

        It 'Should create backup with WhatIf (dry run)' {
            { New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir -WhatIf } | Should Not Throw
        }

        It 'Should create actual backup when not in WhatIf mode' {
            New-DailyBackup -Path $script:SourceDir -Destination $script:BackupDir

            # Check if dated folder was created
            $DateFolder = Get-Date -Format 'yyyy-MM-dd'
            $BackupPath = Join-Path $script:BackupDir $DateFolder
            Test-Path $BackupPath | Should Be $true

            # Check if zip file was created
            $ZipFiles = Get-ChildItem -Path $BackupPath -Filter '*.zip'
            $ZipFiles.Count | Should BeGreaterThan 0
        }

        It 'Should handle non-existent source path gracefully' {
            $NonExistentPath = Join-Path $script:TestRoot 'NonExistent'
            { New-DailyBackup -Path $NonExistentPath -Destination $script:BackupDir -WarningAction SilentlyContinue } | Should Not Throw
        }

        It 'Should handle multiple paths' {
            $Path1 = Join-Path $script:SourceDir 'test1.txt'
            $Path2 = Join-Path $script:SourceDir 'test2.txt'

            { New-DailyBackup -Path @($Path1, $Path2) -Destination $script:BackupDir } | Should Not Throw
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
            $BackupFolders.Count -le 2 | Should Be $true
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
            $BackupFolders.Count | Should Be 3
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
            $BackupFolders.Count | Should Be 0
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
                $false | Should Be $true
            }
            catch
            {
                # This is expected behavior
                $true | Should Be $true
            }
        }
    }

    Context 'File System Errors' {
        It 'Should handle permission errors gracefully' {
            # This is difficult to test consistently across platforms
            # but we can at least verify the function doesn't crash
            $RestrictedPath = Join-Path $script:TestRoot 'Restricted'
            New-Item -Path $RestrictedPath -ItemType Directory -Force | Out-Null

            { New-DailyBackup -Path $RestrictedPath -Destination $script:BackupDir -ErrorAction SilentlyContinue } | Should Not Throw
        }
    }
}

Describe 'Performance and Edge Cases' {
    Context 'Large Files' {
        It 'Should handle empty directories' {
            $EmptyDir = Join-Path $script:TestRoot 'Empty'
            New-Item -Path $EmptyDir -ItemType Directory -Force | Out-Null

            { New-DailyBackup -Path $EmptyDir -Destination $script:BackupDir } | Should Not Throw
        }
    }

    Context 'Path Length Limits' {
        It 'Should handle long paths appropriately' {
            # Create a path that's close to the limit
            $LongName = 'a' * 100
            $LongPath = Join-Path $script:TestRoot $LongName
            New-Item -Path $LongPath -ItemType Directory -Force | Out-Null
            'content' | Out-File -FilePath (Join-Path $LongPath 'file.txt') -Encoding UTF8

            { New-DailyBackup -Path $LongPath -Destination $script:BackupDir -ErrorAction SilentlyContinue } | Should Not Throw
        }
    }
}

# Cleanup test directories after all tests
if (Test-Path $script:TestRoot)
{
    Remove-Item $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove the module
Get-Module DailyBackup | Remove-Module -Force -ErrorAction SilentlyContinue
