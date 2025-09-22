function Restore-DailyBackup
{
    <#
    .SYNOPSIS
        Restores files and directories from daily backup archives.

    .DESCRIPTION
        Restores backed up files and directories from compressed ZIP archives created
        by New-DailyBackup. Supports restoring specific backups by date, individual
        files by name pattern, or entire backup sets. Can restore to original locations
        using metadata or to custom destinations.

    .PARAMETER BackupRoot
        The root directory containing daily backup folders (yyyy-MM-dd format).
        This should be the same directory used as -Destination in New-DailyBackup.

    .PARAMETER DestinationPath
        The destination directory where restored files will be placed.
        If not specified and -UseOriginalPaths is enabled, attempts to restore
        to original source locations using metadata.

    .PARAMETER Date
        Specific backup date to restore from (yyyy-MM-dd format).
        If not specified, uses the most recent backup date available.

    .PARAMETER BackupName
        Optional pattern to match specific backup files by name.
        Supports wildcards (e.g., "*Documents*", "*.pdf*").
        If not specified, restores all backups from the specified date.

    .PARAMETER UseOriginalPaths
        When enabled, attempts to restore files to their original source locations
        using metadata information. Requires metadata files to be present.
        When disabled, restores all files to the specified DestinationPath.

    .PARAMETER PreservePaths
        Controls whether directory structure within backups is preserved during
        restoration. When enabled, maintains folder hierarchy from the backup.

    .PARAMETER Force
        Overwrites existing files during restoration without prompting.
        Use with caution as this can replace current files.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        [System.Object[]]
        Returns an array of restore operation results, including success status,
        paths processed, and any errors encountered for each backup file.

    .NOTES
        - Requires backup files created by New-DailyBackup
        - Supports ShouldProcess for WhatIf and Confirm scenarios
        - Automatically handles file timestamp and attribute restoration when possible
        - Creates destination directories as needed
        - Provides detailed progress reporting for multiple files

    .EXAMPLE
        PS > Restore-DailyBackup -BackupRoot 'D:\Backups' -DestinationPath 'C:\Restored'

        Restores the most recent backup set to C:\Restored

    .EXAMPLE
        PS > Restore-DailyBackup -BackupRoot 'D:\Backups' -Date '2025-09-15' -UseOriginalPaths

        Restores backups from September 15, 2025 to their original source locations

    .EXAMPLE
        PS > Restore-DailyBackup -BackupRoot 'D:\Backups' -BackupName '*Documents*' -DestinationPath 'C:\Restored'

        Restores only backup files matching "*Documents*" pattern

    .EXAMPLE
        PS > Restore-DailyBackup -BackupRoot 'D:\Backups' -Date '2025-09-10' -WhatIf

        Shows what would be restored without actually performing the restoration

    .EXAMPLE
        PS > Restore-DailyBackup -BackupRoot '\\server\backups' -DestinationPath 'C:\Emergency' -Force

        Restores from network backup location, overwriting existing files

    .LINK
        New-DailyBackup
        Get-DailyBackup
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.Object[]])]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The root directory containing daily backup folders.'
        )]
        [ValidateNotNullOrEmpty()]
        [string] $BackupRoot,

        [Parameter(
            HelpMessage = 'The destination directory where restored files will be placed.'
        )]
        [string] $DestinationPath,

        [Parameter(
            HelpMessage = 'Specific backup date to restore from (yyyy-MM-dd format).'
        )]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $Date,

        [Parameter(
            HelpMessage = 'Pattern to match specific backup files by name (supports wildcards).'
        )]
        [string] $BackupName,

        [Parameter(
            HelpMessage = 'Restore files to their original source locations using metadata.'
        )]
        [switch] $UseOriginalPaths,

        [Parameter(
            HelpMessage = 'Preserve directory structure within backups during restoration.'
        )]
        [switch] $PreservePaths,

        [Parameter(
            HelpMessage = 'Overwrite existing files during restoration without prompting.'
        )]
        [switch] $Force
    )

    begin
    {
        # Resolve paths to absolute paths
        $BackupRoot = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BackupRoot)

        # If $DestinationPath is not null of whitespace only, convert it with GetUnresolvedProviderPathFromPSPath
        $DestinationPath = if ($DestinationPath -and -not [string]::IsNullOrWhiteSpace($DestinationPath))
        {
            $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
        }
        else
        {
            $null
        }

        if (-not $UseOriginalPaths -and -not $DestinationPath)
        {
            throw 'Either DestinationPath must be specified or UseOriginalPaths must be enabled'
        }

        if (-not (Test-Path $BackupRoot -PathType Container))
        {
            throw "Backup root directory not found: $BackupRoot"
        }

        Write-Verbose "Restore-DailyBackup> Starting restore operation from $BackupRoot"
    }

    process
    {
        $availableBackupInformation = Get-DailyBackup -BackupRoot $BackupRoot
        if ($Date)
        {
            $availableBackupInformation = $availableBackupInformation | Where-Object { $_.Date -eq $Date }
        }

        if ($availableBackupInformation.Count -eq 0)
        {
            Write-Warning "No backups found in $BackupRoot$(if ($Date) { " for date $Date" })"
            return @()
        }

        # Use most recent backup if no date specified
        if (-not $Date)
        {
            $targetBackupSession = $availableBackupInformation | Sort-Object Date -Descending | Select-Object -First 1
            Write-Verbose "Restore-DailyBackup> Using most recent backup from $($targetBackupSession.Date)"
        }
        else
        {
            $targetBackupSession = $availableBackupInformation | Where-Object { $_.Date -eq $Date } | Select-Object -First 1
            if (-not $targetBackupSession)
            {
                throw "No backup found for date: $Date"
            }
        }

        # Filter backups by name pattern if specified
        $filteredBackupFiles = @(if ($BackupName)
            {
                $targetBackupSession.Backups | Where-Object { $_.Name -like $BackupName }
            }
            else
            {
                $targetBackupSession.Backups
            })

        if ($filteredBackupFiles.Count -eq 0)
        {
            Write-Warning 'No backup files match the specified criteria'
            return @()
        }

        Write-Host "Found $($filteredBackupFiles.Count) backup file(s) to restore from $($targetBackupSession.Date)" -ForegroundColor Green

        # Process each backup file
        $restoreOperationResults = @()
        $totalBackupFilesToRestore = $filteredBackupFiles.Count
        $currentBackupFileIndex = 0

        foreach ($currentBackupFile in $filteredBackupFiles)
        {
            $currentBackupFileIndex++
            Write-Progress -Activity 'Restoring Daily Backups' -Status "Restoring backup $currentBackupFileIndex of $totalBackupFilesToRestore" -PercentComplete (($currentBackupFileIndex / $totalBackupFilesToRestore) * 100)

            try
            {
                # Determine target for ShouldProcess
                $restoreTargetPath = if ($UseOriginalPaths -and $currentBackupFile.Metadata -and $currentBackupFile.Metadata.SourcePath)
                {
                    $currentBackupFile.Metadata.SourcePath
                }
                else
                {
                    $DestinationPath
                }

                $restoreOperationDescription = "Restore backup '$($currentBackupFile.Name)'"

                if ($PSCmdlet.ShouldProcess($restoreTargetPath, $restoreOperationDescription))
                {
                    $backupFileRestoreParameters = @{
                        BackupFilePath = $currentBackupFile.Path
                        UseOriginalPath = $UseOriginalPaths
                        PreservePaths = $PreservePaths
                    }

                    if ($DestinationPath)
                    {
                        $backupFileRestoreParameters.DestinationPath = $DestinationPath
                    }

                    if ($Force)
                    {
                        $backupFileRestoreParameters.Force = $true
                    }

                    $individualRestoreResult = Restore-BackupFile @backupFileRestoreParameters
                    $restoreOperationResults += $individualRestoreResult

                    if ($individualRestoreResult.Success)
                    {
                        Write-Host "[SUCCESS] $($individualRestoreResult.Message)" -ForegroundColor Green
                    }
                    else
                    {
                        Write-Warning "[FAILED] $($individualRestoreResult.Message)"
                    }
                }
                else
                {
                    # Create a "what-if" result for skipped operations
                    $simulatedRestoreResult = [PSCustomObject]@{
                        Success = $true
                        SourcePath = $currentBackupFile.Path
                        DestinationPath = $restoreTargetPath
                        Metadata = $currentBackupFile.Metadata
                        Message = "Would restore $($currentBackupFile.Name) to $restoreTargetPath"
                    }
                    $restoreOperationResults += $simulatedRestoreResult
                    Write-Host "[WHAT-IF] $($simulatedRestoreResult.Message)" -ForegroundColor Yellow
                }
            }
            catch
            {
                $failedRestoreResult = [PSCustomObject]@{
                    Success = $false
                    SourcePath = $currentBackupFile.Path
                    DestinationPath = $DestinationPath
                    Metadata = $currentBackupFile.Metadata
                    Message = "Failed to restore $($currentBackupFile.Name): $_"
                }
                $restoreOperationResults += $failedRestoreResult
                Write-Error $failedRestoreResult.Message -ErrorAction Continue
            }
        }

        Write-Progress -Activity 'Restoring Daily Backups' -Completed
    }

    end
    {
        $successfulRestoreOperations = @($restoreOperationResults | Where-Object { $_.Success })
        $numberOfSuccessfulRestores = $successfulRestoreOperations.Count
        $totalRestoreAttempts = $restoreOperationResults.Count

        Write-Host "`nRestore Summary:" -ForegroundColor Cyan
        Write-Host "   Successful: $numberOfSuccessfulRestores" -ForegroundColor Green
        Write-Host "   Failed: $($totalRestoreAttempts - $numberOfSuccessfulRestores)" -ForegroundColor Red
        Write-Host "   Total: $totalRestoreAttempts" -ForegroundColor Blue

        Write-Verbose 'Restore-DailyBackup> Restore operation completed'
        return $restoreOperationResults
    }
}
