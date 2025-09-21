#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    Initialize-TestModule
    $TestEnv = Initialize-TestEnvironment -TestName 'Metadata'

    # Ensure cleanup happens even if tests fail
    $script:TestEnvironmentPath = $TestEnv.TestRoot
}

Describe 'Metadata and Path Type Detection' {
    Context 'Path Type Detection' {
        It 'Correctly identifies file types' {
            $testFile = Join-Path $TestEnv.SourceDir 'test1.txt'
            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backup = $manifest.Content.Backups[0]
            $backup.PathType | Should -Be 'File'
        }

        It 'Correctly identifies directory types' {
            $testDir = Join-Path $TestEnv.SourceDir 'SubFolder'
            New-DailyBackup -Path $testDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backup = $manifest.Content.Backups[0]
            $backup.PathType | Should -Be 'Directory'
        }

        It 'Handles mixed file and directory paths' {
            $testFile = Join-Path $TestEnv.SourceDir 'test1.txt'
            $testDir = Join-Path $TestEnv.SourceDir 'SubFolder'

            New-DailyBackup -Path @($testFile, $testDir) -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $pathTypes = $manifest.Content.Backups | ForEach-Object { $_.PathType }
            $pathTypes | Should -Contain 'File'
            $pathTypes | Should -Contain 'Directory'
        }
    }

    Context 'Metadata Structure Validation' {
        It 'Creates backup manifest with valid metadata' {
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $result.ManifestFile | Should -Not -BeNullOrEmpty
            $result.ManifestFile.Name | Should -Be 'backup-manifest.json'

            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName
            $manifest.IsValid | Should -Be $true
            $manifest.HasBackupDate | Should -Be $true
            $manifest.HasBackupVersion | Should -Be $true
            $manifest.HasModuleVersion | Should -Be $true
            $manifest.HasBackupsArray | Should -Be $true
            $manifest.BackupCount | Should -BeGreaterThan 0
        }

        It 'Uses correct backup version format in manifest' {
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $manifest.Content.BackupVersion | Should -Be '1.0'
        }

        It 'Includes hash information in metadata by default' {
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName
            $manifest.HasHashData | Should -Be $true

            $backup = $manifest.Content.Backups[0]
            $backup.SourceHash | Should -Not -BeNullOrEmpty
            $backup.ArchiveHash | Should -Not -BeNullOrEmpty
            $backup.HashAlgorithm | Should -Be 'SHA256'
        }

        It 'Preserves original source path information in manifest' {
            $testFile = Join-Path $TestEnv.SourceDir 'test1.txt'
            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backupEntry = $manifest.Content.Backups[0]
            $backupEntry.SourcePath | Should -Be $testFile
        }

        It 'Includes timestamp information' {
            New-DailyBackup -Path $TestEnv.SourceDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backup = $manifest.Content.Backups[0]
            $backup.BackupCreated | Should -Not -BeNullOrEmpty
            { [DateTime]::Parse($backup.BackupCreated) } | Should -Not -Throw
        }
    }

    Context 'Special Character and Path Handling' {
        It 'Handles paths with spaces correctly' {
            $spacePath = Join-Path $TestEnv.SourceDir 'file with spaces.txt'
            'Special content' | Out-File -FilePath $spacePath -Encoding UTF8

            New-DailyBackup -Path $spacePath -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backup = $manifest.Content.Backups[0]
            $backup.SourcePath | Should -Be $spacePath
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
