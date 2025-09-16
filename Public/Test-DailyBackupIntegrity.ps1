function Test-DailyBackupIntegrity
{
    <#
    .SYNOPSIS
        Verifies the integrity of backup archives using stored hash values.

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
        PS > Test-DailyBackupIntegrity -BackupRoot 'D:\Backups'

        Verifies integrity of the most recent backup

    .EXAMPLE
        PS > Test-DailyBackupIntegrity -BackupRoot 'D:\Backups' -Date '2025-09-15'

        Verifies integrity of backups from specific date

    .EXAMPLE
        PS > Test-DailyBackupIntegrity -BackupRoot 'D:\Backups' -BackupName '*Documents*' -VerifySource

        Verifies specific backups and their source files

    .LINK
        New-DailyBackup
        Get-DailyBackupInfo
    #>
    [CmdletBinding()]
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
        if (-not (Test-Path $BackupRoot))
        {
            throw "Backup root directory does not exist: $BackupRoot"
        }

        Write-Verbose "Test-DailyBackupIntegrity> Starting integrity verification for: $BackupRoot"

        # Get backup information
        $backupInfoParams = @{ BackupRoot = $BackupRoot }
        if ($Date) { $backupInfoParams.Date = $Date }

        $backupInfo = Get-DailyBackupInfo @backupInfoParams
        if (-not $backupInfo -or $backupInfo.Count -eq 0)
        {
            Write-Warning 'Test-DailyBackupIntegrity> No backups found to verify'
            return @()
        }

        $results = @()
        foreach ($dateInfo in $backupInfo)
        {
            Write-Verbose "Test-DailyBackupIntegrity> Verifying backups for date: $($dateInfo.Date)"

            $backupsToVerify = $dateInfo.Backups
            if ($BackupName)
            {
                $backupsToVerify = $backupsToVerify | Where-Object { $_.Name -like $BackupName }
            }

            foreach ($backup in $backupsToVerify)
            {
                $result = [PSCustomObject]@{
                    Date = $dateInfo.Date
                    BackupName = $backup.Name
                    BackupPath = $backup.Path
                    ArchiveIntegrityValid = $false
                    SourceIntegrityValid = $null
                    ArchiveHashMatch = $false
                    SourceHashMatch = $null
                    ErrorMessage = $null
                    Metadata = $backup.Metadata
                    HasHashData = $false
                }

                try
                {
                    if (-not $backup.Metadata)
                    {
                        $result.ErrorMessage = 'No metadata available for verification'
                        $results += $result
                        continue
                    }

                    # Check if hash data is available
                    $hasArchiveHash = -not [string]::IsNullOrEmpty($backup.Metadata.ArchiveHash)
                    $hasSourceHash = -not [string]::IsNullOrEmpty($backup.Metadata.SourceHash)
                    $result.HasHashData = $hasArchiveHash -or $hasSourceHash

                    if (-not $result.HasHashData)
                    {
                        $result.ErrorMessage = 'No hash data available for verification (backup may have been created with -NoHash)'
                        $results += $result
                        continue
                    }

                    # Verify archive hash
                    if ($hasArchiveHash)
                    {
                        Write-Verbose "Test-DailyBackupIntegrity> Verifying archive hash for: $($backup.Name)"

                        if (-not (Test-Path $backup.Path))
                        {
                            $result.ErrorMessage = "Archive file not found: $($backup.Path)"
                            $results += $result
                            continue
                        }

                        $currentArchiveHash = Get-FileHash -Path $backup.Path -Algorithm $backup.Metadata.HashAlgorithm
                        $result.ArchiveHashMatch = $currentArchiveHash.Hash -eq $backup.Metadata.ArchiveHash
                        $result.ArchiveIntegrityValid = $result.ArchiveHashMatch

                        if (-not $result.ArchiveHashMatch)
                        {
                            $result.ErrorMessage = 'Archive hash mismatch - backup may be corrupted'
                        }
                        else
                        {
                            Write-Verbose 'Test-DailyBackupIntegrity> Archive hash verified successfully'
                        }
                    }

                    # Verify source hash if requested and available
                    if ($VerifySource -and $hasSourceHash)
                    {
                        Write-Verbose "Test-DailyBackupIntegrity> Verifying source hash for: $($backup.Metadata.SourcePath)"

                        if (Test-Path $backup.Metadata.SourcePath)
                        {
                            $currentSourceHash = Get-PathHash -Path $backup.Metadata.SourcePath -Algorithm $backup.Metadata.HashAlgorithm
                            $result.SourceHashMatch = $currentSourceHash -eq $backup.Metadata.SourceHash
                            $result.SourceIntegrityValid = $result.SourceHashMatch

                            if (-not $result.SourceHashMatch)
                            {
                                if ($result.ErrorMessage)
                                {
                                    $result.ErrorMessage += '; Source files have changed since backup'
                                }
                                else
                                {
                                    $result.ErrorMessage = 'Source files have changed since backup'
                                }
                            }
                            else
                            {
                                Write-Verbose 'Test-DailyBackupIntegrity> Source hash verified successfully'
                            }
                        }
                        else
                        {
                            $result.SourceIntegrityValid = $false
                            if ($result.ErrorMessage)
                            {
                                $result.ErrorMessage += "; Source path no longer exists: $($backup.Metadata.SourcePath)"
                            }
                            else
                            {
                                $result.ErrorMessage = "Source path no longer exists: $($backup.Metadata.SourcePath)"
                            }
                        }
                    }

                    if (-not $result.ErrorMessage)
                    {
                        $result.ErrorMessage = 'Verification completed successfully'
                    }
                }
                catch
                {
                    $result.ErrorMessage = "Verification failed: $_"
                    Write-Warning "Test-DailyBackupIntegrity> Error verifying $($backup.Name): $_"
                }

                $results += $result
            }
        }

        # Summary
        $totalVerified = $results.Count
        $archiveValid = ($results | Where-Object { $_.ArchiveIntegrityValid }).Count
        $sourceValid = ($results | Where-Object { $_.SourceIntegrityValid -eq $true }).Count
        $withoutHashes = ($results | Where-Object { -not $_.HasHashData }).Count

        Write-Verbose "Test-DailyBackupIntegrity> Verification complete: $totalVerified backups checked"
        Write-Verbose "Test-DailyBackupIntegrity> Archive integrity: $archiveValid/$totalVerified valid"
        if ($VerifySource)
        {
            Write-Verbose "Test-DailyBackupIntegrity> Source integrity: $sourceValid/$totalVerified valid"
        }
        if ($withoutHashes -gt 0)
        {
            Write-Verbose "Test-DailyBackupIntegrity> $withoutHashes backups had no hash data for verification"
        }

        return $results
    }
    catch
    {
        Write-Error "Test-DailyBackupIntegrity> Failed to verify backup integrity: $_"
        return @()
    }
}
