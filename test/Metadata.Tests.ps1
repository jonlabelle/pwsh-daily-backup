#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    Initialize-TestModule
    $TestEnv = Initialize-TestEnvironment -TestName 'Metadata'
}

Describe 'Metadata and Path Type Detection' {
    Context 'Path Type Detection' {
        It 'Correctly identifies file types' {
            $testFile = Join-Path $TestEnv.SourceDir 'test1.txt'
            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $metadata = Test-MetadataContent -MetadataPath $result.MetadataFiles[0].FullName

            $metadata.Content.PathType | Should -Be 'File'
        }

        It 'Correctly identifies directory types' {
            $testDir = Join-Path $TestEnv.SourceDir 'SubFolder'
            New-DailyBackup -Path $testDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $metadata = Test-MetadataContent -MetadataPath $result.MetadataFiles[0].FullName

            $metadata.Content.PathType | Should -Be 'Directory'
        }

        It 'Handles mixed file and directory paths' {
            $testFile = Join-Path $TestEnv.SourceDir 'test1.txt'
            $testDir = Join-Path $TestEnv.SourceDir 'SubFolder'

            New-DailyBackup -Path @($testFile, $testDir) -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir -ExpectedMetadataCount 2

            $pathTypes = @()
            foreach ($metadataFile in $result.MetadataFiles) {
                $metadata = Test-MetadataContent -MetadataPath $metadataFile.FullName
                $pathTypes += $metadata.Content.PathType
            }

            $pathTypes | Should -Contain 'File'
            $pathTypes | Should -Contain 'Directory'
        }
    }

    Context 'Metadata Structure Validation' {
        It 'Creates valid JSON metadata files' {
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir

            foreach ($metadataFile in $result.MetadataFiles) {
                $metadata = Test-MetadataContent -MetadataPath $metadataFile.FullName
                $metadata.IsValid | Should -Be $true
            }
        }

        It 'Includes all required metadata properties' {
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $metadata = Test-MetadataContent -MetadataPath $result.MetadataFiles[0].FullName

            $metadata.HasSourcePath | Should -Be $true
            $metadata.HasBackupCreated | Should -Be $true
            $metadata.HasPathType | Should -Be $true
            $metadata.HasBackupVersion | Should -Be $true
        }

        It 'Uses correct backup version format' {
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $metadata = Test-MetadataContent -MetadataPath $result.MetadataFiles[0].FullName

            $metadata.Content.BackupVersion | Should -Be '2.0'
        }

        It 'Preserves original source path information' {
            $testFile = Join-Path $TestEnv.SourceDir 'test1.txt'
            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $metadata = Test-MetadataContent -MetadataPath $result.MetadataFiles[0].FullName

            $metadata.Content.SourcePath | Should -Be $testFile
        }

        It 'Includes timestamp information' {
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $metadata = Test-MetadataContent -MetadataPath $result.MetadataFiles[0].FullName

            $metadata.Content.BackupCreated | Should -Not -BeNullOrEmpty
            { [DateTime]::Parse($metadata.Content.BackupCreated) } | Should -Not -Throw
        }
    }

    Context 'Special Character and Path Handling' {
        It 'Handles paths with spaces correctly' {
            $spacePath = Join-Path $TestEnv.SourceDir 'file with spaces.txt'
            'Special content' | Out-File -FilePath $spacePath -Encoding UTF8

            New-DailyBackup -Path $spacePath -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $metadata = Test-MetadataContent -MetadataPath $result.MetadataFiles[0].FullName

            $metadata.Content.SourcePath | Should -Be $spacePath
        }

        It 'Handles Unicode characters in paths' {
            $unicodePath = Join-Path $TestEnv.SourceDir 'файл.txt'
            'Unicode content' | Out-File -FilePath $unicodePath -Encoding UTF8

            { New-DailyBackup -Path $unicodePath -Destination $TestEnv.BackupDir -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Processes deep directory structures' {
            $deepPath = Join-Path $TestEnv.SourceDir 'level1'
            $deepPath = Join-Path $deepPath 'level2'
            $deepPath = Join-Path $deepPath 'level3'
            New-Item -Path $deepPath -ItemType Directory -Force | Out-Null
            'Deep content' | Out-File -FilePath (Join-Path $deepPath 'deep.txt') -Encoding UTF8

            { New-DailyBackup -Path $deepPath -Destination $TestEnv.BackupDir } | Should -Not -Throw

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $result.ZipCount | Should -BeGreaterThan 0
        }
    }
}

AfterAll {
    Remove-TestEnvironment -TestRoot $TestEnv.TestRoot
}
