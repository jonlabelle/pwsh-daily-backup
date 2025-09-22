function Test-DailyBackup
{
    <#
    .SYNOPSIS
        Tests the integrity of daily backup archives using hash verification.

    .DESCRIPTION
        Validates backup integrity by comparing current hash values against those
        stored in the backup manifest. This function checks both source path hashes
        (if available) and archive file hashes to detect corruption or changes.

    .PARAMETER BackupRoot
        The root directory containing daily backup folders.

    .PARAMETER Date
        Specific backup date to verify (yyyy-MM-dd format). If not specified,
        verifies the most recent backup.

    .PARAMETER BackupName
        Pattern to match specific backup files by name (supports wildcards).
        If not specified, verifies all backups for the specified date.

    .PARAMETER VerifySource
        Also verify that source files still match their original hashes.
        This requires the source files to still exist at their original locations.

    .OUTPUTS
        PSCustomObject array containing verification results for each backup.

    .NOTES
        This function requires backups to have been created with hash information.
        Backups created with -NoHash cannot be verified using this function.

    .EXAMPLE
        PS > Test-DailyBackup -BackupRoot 'D:\Backups'

        Verifies integrity of the most recent backup

    .EXAMPLE
        PS > Test-DailyBackup -BackupRoot 'D:\Backups' -Date '2025-09-15'

        Verifies integrity of backups from specific date

    .EXAMPLE
        PS > Test-DailyBackup -BackupRoot 'D:\Backups' -BackupName '*Documents*' -VerifySource

        Verifies specific backups and their source files

    .LINK
        New-DailyBackup
        Get-DailyBackup
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupRoot,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $Date,

        [Parameter(Mandatory = $false)]
        [string] $BackupName,

        [Parameter(Mandatory = $false)]
        [switch] $VerifySource
    )

    try
    {
        if ([string]::IsNullOrWhiteSpace($BackupRoot))
        {
            Write-Error 'Test-DailyBackup> Backup root parameter cannot be null or empty'
            return
        }

        # Normalize and resolve the backup root path
        $BackupRoot = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BackupRoot)

        if (-not (Test-Path $BackupRoot))
        {
            Write-Error "Test-DailyBackup> Backup root directory does not exist: $BackupRoot"
        }

        Write-Verbose "Test-DailyBackup> Starting integrity verification for: $BackupRoot"

        # Get backup information
        $backupRetrievalParameters = @{ BackupRoot = $BackupRoot }
        if ($Date) { $backupRetrievalParameters.Date = $Date }

        $availableBackupSessions = Get-DailyBackup @backupRetrievalParameters
        if (-not $availableBackupSessions -or $availableBackupSessions.Count -eq 0)
        {
            Write-Warning 'Test-DailyBackup> No backups found to verify'
            return @()
        }

        $verificationResults = @()
        foreach ($currentBackupSession in $availableBackupSessions)
        {
            Write-Verbose "Test-DailyBackup> Verifying backups for date: $($currentBackupSession.Date)"

            $filteredBackupFiles = $currentBackupSession.Backups
            if ($BackupName)
            {
                $filteredBackupFiles = $filteredBackupFiles | Where-Object { $_.Name -like $BackupName }
            }

            foreach ($currentBackupFile in $filteredBackupFiles)
            {
                $currentVerificationResult = [PSCustomObject]@{
                    Date = $currentBackupSession.Date
                    BackupName = $currentBackupFile.Name
                    BackupPath = $currentBackupFile.Path
                    ArchiveIntegrityValid = $false
                    SourceIntegrityValid = $null
                    ArchiveHashMatch = $false
                    SourceHashMatch = $null
                    ErrorMessage = $null
                    Metadata = $currentBackupFile.Metadata
                    HasHashData = $false
                }

                try
                {
                    if (-not $currentBackupFile.Metadata)
                    {
                        $currentVerificationResult.ErrorMessage = 'No metadata available for verification'
                        $verificationResults += $currentVerificationResult
                        continue
                    }

                    # Check if hash data is available
                    $archiveHashIsAvailable = -not [string]::IsNullOrEmpty($currentBackupFile.Metadata.ArchiveHash)
                    $sourceHashIsAvailable = -not [string]::IsNullOrEmpty($currentBackupFile.Metadata.SourceHash)
                    $currentVerificationResult.HasHashData = $archiveHashIsAvailable -or $sourceHashIsAvailable

                    if (-not $currentVerificationResult.HasHashData)
                    {
                        $currentVerificationResult.ErrorMessage = 'No hash data available for verification (backup may have been created with -NoHash)'
                        $verificationResults += $currentVerificationResult
                        continue
                    }

                    # Verify archive hash
                    if ($archiveHashIsAvailable)
                    {
                        Write-Verbose "Test-DailyBackup> Verifying archive hash for: $($currentBackupFile.Name)"

                        if (-not (Test-Path $currentBackupFile.Path))
                        {
                            $currentVerificationResult.ErrorMessage = "Archive file not found: $($currentBackupFile.Path)"
                            $verificationResults += $currentVerificationResult
                            continue
                        }

                        $calculatedArchiveHash = Get-FileHash -Path $currentBackupFile.Path -Algorithm $currentBackupFile.Metadata.HashAlgorithm
                        $currentVerificationResult.ArchiveHashMatch = $calculatedArchiveHash.Hash -eq $currentBackupFile.Metadata.ArchiveHash
                        $currentVerificationResult.ArchiveIntegrityValid = $currentVerificationResult.ArchiveHashMatch

                        if (-not $currentVerificationResult.ArchiveHashMatch)
                        {
                            $currentVerificationResult.ErrorMessage = 'Archive hash mismatch - backup may be corrupted'
                        }
                        else
                        {
                            Write-Verbose 'Test-DailyBackup> Archive hash verified successfully'
                        }
                    }

                    # Verify source hash if requested and available
                    if ($VerifySource -and $sourceHashIsAvailable)
                    {
                        Write-Verbose "Test-DailyBackup> Verifying source hash for: $($currentBackupFile.Metadata.SourcePath)"

                        if (Test-Path $currentBackupFile.Metadata.SourcePath)
                        {
                            $calculatedSourceHash = Get-PathHash -Path $currentBackupFile.Metadata.SourcePath -Algorithm $currentBackupFile.Metadata.HashAlgorithm
                            $currentVerificationResult.SourceHashMatch = $calculatedSourceHash -eq $currentBackupFile.Metadata.SourceHash
                            $currentVerificationResult.SourceIntegrityValid = $currentVerificationResult.SourceHashMatch

                            if (-not $currentVerificationResult.SourceHashMatch)
                            {
                                if ($currentVerificationResult.ErrorMessage)
                                {
                                    $currentVerificationResult.ErrorMessage += '; Source files have changed since backup'
                                }
                                else
                                {
                                    $currentVerificationResult.ErrorMessage = 'Source files have changed since backup'
                                }
                            }
                            else
                            {
                                Write-Verbose 'Test-DailyBackup> Source hash verified successfully'
                            }
                        }
                        else
                        {
                            $currentVerificationResult.SourceIntegrityValid = $false
                            if ($currentVerificationResult.ErrorMessage)
                            {
                                $currentVerificationResult.ErrorMessage += "; Source path no longer exists: $($currentBackupFile.Metadata.SourcePath)"
                            }
                            else
                            {
                                $currentVerificationResult.ErrorMessage = "Source path no longer exists: $($currentBackupFile.Metadata.SourcePath)"
                            }
                        }
                    }

                    if (-not $currentVerificationResult.ErrorMessage)
                    {
                        $currentVerificationResult.ErrorMessage = 'Verification completed successfully'
                    }
                }
                catch
                {
                    $currentVerificationResult.ErrorMessage = "Verification failed: $_"
                    Write-Warning "Test-DailyBackup> Error verifying $($currentBackupFile.Name): $_"
                }

                $verificationResults += $currentVerificationResult
            }
        }

        # Summary
        $totalBackupsChecked = $verificationResults.Count
        $validArchiveBackups = ($verificationResults | Where-Object { $_.ArchiveIntegrityValid }).Count
        $validSourceBackups = ($verificationResults | Where-Object { $_.SourceIntegrityValid -eq $true }).Count
        $backupsWithoutHashData = ($verificationResults | Where-Object { -not $_.HasHashData }).Count

        Write-Verbose "Test-DailyBackup> Verification complete: $totalBackupsChecked backups checked"
        Write-Verbose "Test-DailyBackup> Archive integrity: $validArchiveBackups/$totalBackupsChecked valid"
        if ($VerifySource)
        {
            Write-Verbose "Test-DailyBackup> Source integrity: $validSourceBackups/$totalBackupsChecked valid"
        }
        if ($backupsWithoutHashData -gt 0)
        {
            Write-Verbose "Test-DailyBackup> $backupsWithoutHashData backups had no hash data for verification"
        }

        return $verificationResults
    }
    catch
    {
        Write-Error "Test-DailyBackup> Failed to verify backup integrity: $_"
        return @()
    }
}
