#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    Initialize-TestModule
    $TestEnv = Initialize-TestEnvironment -TestName 'Hash'

    # Ensure cleanup happens even if tests fail
    $script:TestEnvironmentPath = $TestEnv.TestRoot
}

Describe 'Hash Functionality' {
    Context 'Backup Creation with Hash Calculation' {
        It 'Calculates and stores hash for a single file' {
            $testFile = Join-Path $TestEnv.SourceDir 'hash-test.txt'
            'Hash test content' | Out-File -FilePath $testFile -Encoding UTF8

            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backup = $manifest.Content.Backups[0]
            $backup.SourceHash | Should -Not -BeNullOrEmpty
            $backup.SourceHash | Should -Match '^[A-F0-9]{64}$'  # SHA-256 format
            $backup.ArchiveHash | Should -Not -BeNullOrEmpty
            $backup.ArchiveHash | Should -Match '^[A-F0-9]{64}$'  # SHA-256 format
            $backup.HashAlgorithm | Should -Be 'SHA256'
        }

        It 'Calculates composite hash for a directory' {
            $testDir = Join-Path $TestEnv.SourceDir 'hash-dir'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            'File 1' | Out-File -FilePath (Join-Path $testDir 'file1.txt') -Encoding UTF8
            'File 2' | Out-File -FilePath (Join-Path $testDir 'file2.txt') -Encoding UTF8

            New-DailyBackup -Path $testDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backup = $manifest.Content.Backups[0]
            $backup.PathType | Should -Be 'Directory'
            $backup.SourceHash | Should -Not -BeNullOrEmpty
            $backup.SourceHash | Should -Match '^[A-F0-9]{64}$'  # SHA-256 format
        }

        It 'Returns consistent hash for same content' {
            $testFile1 = Join-Path $TestEnv.SourceDir 'consistent1.txt'
            $testFile2 = Join-Path $TestEnv.SourceDir 'consistent2.txt'
            'Consistent content' | Out-File -FilePath $testFile1 -Encoding UTF8
            'Consistent content' | Out-File -FilePath $testFile2 -Encoding UTF8

            New-DailyBackup -Path @($testFile1, $testFile2) -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $hash1 = $manifest.Content.Backups[0].SourceHash
            $hash2 = $manifest.Content.Backups[1].SourceHash
            $hash1 | Should -Be $hash2
        }

        It 'Returns different hash for different content' {
            $testFile1 = Join-Path $TestEnv.SourceDir 'different1.txt'
            $testFile2 = Join-Path $TestEnv.SourceDir 'different2.txt'
            'Content 1' | Out-File -FilePath $testFile1 -Encoding UTF8
            'Content 2' | Out-File -FilePath $testFile2 -Encoding UTF8

            New-DailyBackup -Path @($testFile1, $testFile2) -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $hash1 = $manifest.Content.Backups[0].SourceHash
            $hash2 = $manifest.Content.Backups[1].SourceHash
            $hash1 | Should -Not -Be $hash2
        }

        It 'Handles empty directory' {
            $emptyDir = Join-Path $TestEnv.SourceDir 'empty-dir'
            New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null

            New-DailyBackup -Path $emptyDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backup = $manifest.Content.Backups[0]
            $backup.SourceHash | Should -Not -BeNullOrEmpty
            $backup.SourceHash | Should -Match '^[A-F0-9]{64}$'
        }
    }

    Context 'Backup Creation with Hashes' {
        It 'Creates backup with hash information by default' {
            $testFile = Join-Path $TestEnv.SourceDir 'backup-hash-test.txt'
            'Backup hash test content' | Out-File -FilePath $testFile -Encoding UTF8

            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backup = $manifest.Content.Backups[0]
            $backup.SourceHash | Should -Not -BeNullOrEmpty
            $backup.ArchiveHash | Should -Not -BeNullOrEmpty
            $backup.HashAlgorithm | Should -Be 'SHA256'
        }

        It 'Skips hash calculation with -NoHash parameter' {
            $testFile = Join-Path $TestEnv.SourceDir 'no-hash-test.txt'
            'No hash test content' | Out-File -FilePath $testFile -Encoding UTF8

            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir -NoHash

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backup = $manifest.Content.Backups[0]
            $backup.PSObject.Properties.Name | Should -Not -Contain 'SourceHash'
            $backup.PSObject.Properties.Name | Should -Not -Contain 'ArchiveHash'
            $backup.PSObject.Properties.Name | Should -Not -Contain 'HashAlgorithm'
        }

        It 'Calculates different hashes for different files' {
            $testFile1 = Join-Path $TestEnv.SourceDir 'unique1.txt'
            $testFile2 = Join-Path $TestEnv.SourceDir 'unique2.txt'
            'Unique content 1' | Out-File -FilePath $testFile1 -Encoding UTF8
            'Unique content 2' | Out-File -FilePath $testFile2 -Encoding UTF8

            New-DailyBackup -Path @($testFile1, $testFile2) -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $manifest.Content.Backups.Count | Should -Be 2
            $hash1 = $manifest.Content.Backups[0].SourceHash
            $hash2 = $manifest.Content.Backups[1].SourceHash
            $hash1 | Should -Not -Be $hash2
        }

        It 'Handles directory backup with hash calculation' {
            $testDir = Join-Path $TestEnv.SourceDir 'hash-backup-dir'
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            'Dir file 1' | Out-File -FilePath (Join-Path $testDir 'dirfile1.txt') -Encoding UTF8
            'Dir file 2' | Out-File -FilePath (Join-Path $testDir 'dirfile2.txt') -Encoding UTF8

            New-DailyBackup -Path $testDir -Destination $TestEnv.BackupDir

            $result = Test-BackupStructure -BackupPath $TestEnv.BackupDir
            $manifest = Test-BackupManifest -ManifestPath $result.ManifestFile.FullName

            $backup = $manifest.Content.Backups[0]
            $backup.PathType | Should -Be 'Directory'
            $backup.SourceHash | Should -Not -BeNullOrEmpty
            $backup.ArchiveHash | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Test-DailyBackup Function' {
        BeforeEach {
            # Clean backup directory for each test
            if (Test-Path $TestEnv.BackupDir)
            {
                Remove-Item $TestEnv.BackupDir -Recurse -Force
            }
            New-Item -Path $TestEnv.BackupDir -ItemType Directory -Force | Out-Null
        }

        It 'Verifies valid backup integrity' {
            $testFile = Join-Path $TestEnv.SourceDir 'integrity-valid.txt'
            'Valid integrity test' | Out-File -FilePath $testFile -Encoding UTF8

            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            $result = Test-DailyBackup -BackupRoot $TestEnv.BackupDir
            $result | Should -Not -BeNullOrEmpty
            $result[0].ArchiveIntegrityValid | Should -Be $true
            $result[0].ArchiveHashMatch | Should -Be $true
            $result[0].HasHashData | Should -Be $true
        }

        It 'Detects corrupted backup archive' {
            $testFile = Join-Path $TestEnv.SourceDir 'integrity-corrupt.txt'
            'Corruption test content' | Out-File -FilePath $testFile -Encoding UTF8

            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            # Get the backup file and corrupt it by changing one byte
            $dateFolder = Get-Date -Format 'yyyy-MM-dd'
            $backupPath = Join-Path $TestEnv.BackupDir $dateFolder
            $zipFile = Get-ChildItem $backupPath -Filter '*.zip' | Select-Object -First 1

            # Corrupt the zip file by appending data
            'corrupt' | Add-Content -Path $zipFile.FullName -Encoding ASCII

            $result = Test-DailyBackup -BackupRoot $TestEnv.BackupDir
            $result[0].ArchiveIntegrityValid | Should -Be $false
            $result[0].ArchiveHashMatch | Should -Be $false
            $result[0].ErrorMessage | Should -Match 'corrupted'
        }

        It 'Handles backups without hash data' {
            $testFile = Join-Path $TestEnv.SourceDir 'no-hash-integrity.txt'
            'No hash integrity test' | Out-File -FilePath $testFile -Encoding UTF8

            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir -NoHash

            $result = Test-DailyBackup -BackupRoot $TestEnv.BackupDir
            $result[0].HasHashData | Should -Be $false
            $result[0].ErrorMessage | Should -Match 'No hash data available'
        }

        It 'Verifies source file integrity when requested' {
            $testFile = Join-Path $TestEnv.SourceDir 'source-integrity.txt'
            'Source integrity test' | Out-File -FilePath $testFile -Encoding UTF8

            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            $result = Test-DailyBackup -BackupRoot $TestEnv.BackupDir -VerifySource
            $result[0].SourceIntegrityValid | Should -Be $true
            $result[0].SourceHashMatch | Should -Be $true
        }

        It 'Detects changed source files' {
            $testFile = Join-Path $TestEnv.SourceDir 'source-changed.txt'
            'Original content' | Out-File -FilePath $testFile -Encoding UTF8

            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            # Modify source file after backup
            'Modified content' | Out-File -FilePath $testFile -Encoding UTF8

            $result = Test-DailyBackup -BackupRoot $TestEnv.BackupDir -VerifySource
            $result[0].SourceIntegrityValid | Should -Be $false
            $result[0].SourceHashMatch | Should -Be $false
            $result[0].ErrorMessage | Should -Match 'Source files have changed'
        }

        It 'Handles missing source files' {
            $testFile = Join-Path $TestEnv.SourceDir 'source-missing.txt'
            'Content that will be deleted' | Out-File -FilePath $testFile -Encoding UTF8

            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            # Delete source file after backup
            Remove-Item $testFile -Force

            $result = Test-DailyBackup -BackupRoot $TestEnv.BackupDir -VerifySource
            $result[0].SourceIntegrityValid | Should -Be $false
            $result[0].ErrorMessage | Should -Match 'Source path no longer exists'
        }

        It 'Filters backups by name pattern' {
            $testFile1 = Join-Path $TestEnv.SourceDir 'filter1.txt'
            $testFile2 = Join-Path $TestEnv.SourceDir 'document.txt'
            'Filter test 1' | Out-File -FilePath $testFile1 -Encoding UTF8
            'Document content' | Out-File -FilePath $testFile2 -Encoding UTF8

            New-DailyBackup -Path @($testFile1, $testFile2) -Destination $TestEnv.BackupDir

            $result = Test-DailyBackup -BackupRoot $TestEnv.BackupDir -BackupName '*document*'
            $result.Count | Should -Be 1
            $result[0].BackupName | Should -Match 'document'
        }

        It 'Returns empty array for no backups found' {
            $result = Test-DailyBackup -BackupRoot $TestEnv.BackupDir
            $result | Should -Be @()
        }
    }

    Context 'Integration with Get-DailyBackup' {
        It 'Includes hash information in backup metadata' {
            $testFile = Join-Path $TestEnv.SourceDir 'info-hash.txt'
            'Info hash test' | Out-File -FilePath $testFile -Encoding UTF8

            New-DailyBackup -Path $testFile -Destination $TestEnv.BackupDir

            $backupInfo = Get-DailyBackup -BackupRoot $TestEnv.BackupDir
            $metadata = $backupInfo[0].Backups[0].Metadata

            $metadata.SourceHash | Should -Not -BeNullOrEmpty
            $metadata.ArchiveHash | Should -Not -BeNullOrEmpty
            $metadata.HashAlgorithm | Should -Be 'SHA256'
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
