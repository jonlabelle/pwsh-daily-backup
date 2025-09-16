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
        [PSCustomObject[]]
        Returns an array of restore operation results, including success status,
        paths processed, and any errors encountered for each backup file.

    .NOTES
        - Requires backup files created by New-DailyBackup with version 2.0+ metadata
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
        $verboseEnabled = ($VerbosePreference -eq 'Continue')

        if (-not $UseOriginalPaths -and -not $DestinationPath)
        {
            throw 'Either DestinationPath must be specified or UseOriginalPaths must be enabled'
        }

        if (-not (Test-Path $BackupRoot -PathType Container))
        {
            throw "Backup root directory not found: $BackupRoot"
        }

        Write-Verbose "Restore-DailyBackup:Begin> Starting restore operation from $BackupRoot"
    }

    process
    {
        $backupInfo = Get-DailyBackup -BackupRoot $BackupRoot
        if ($Date)
        {
            $backupInfo = $backupInfo | Where-Object { $_.Date -eq $Date }
        }

        if ($backupInfo.Count -eq 0)
        {
            Write-Warning "No backups found in $BackupRoot$(if ($Date) { " for date $Date" })"
            return @()
        }

        # Use most recent backup if no date specified
        if (-not $Date)
        {
            $selectedBackup = $backupInfo | Sort-Object Date -Descending | Select-Object -First 1
            Write-Verbose "Restore-DailyBackup> Using most recent backup from $($selectedBackup.Date)"
        }
        else
        {
            $selectedBackup = $backupInfo | Where-Object { $_.Date -eq $Date } | Select-Object -First 1
            if (-not $selectedBackup)
            {
                throw "No backup found for date: $Date"
            }
        }

        # Filter backups by name pattern if specified
        $backupsToRestore = @(if ($BackupName)
            {
                $selectedBackup.Backups | Where-Object { $_.Name -like $BackupName }
            }
            else
            {
                $selectedBackup.Backups
            })

        if ($backupsToRestore.Count -eq 0)
        {
            Write-Warning 'No backup files match the specified criteria'
            return @()
        }

        Write-Host "Found $($backupsToRestore.Count) backup file(s) to restore from $($selectedBackup.Date)" -ForegroundColor Green

        # Process each backup file
        $results = @()
        $totalBackups = $backupsToRestore.Count
        $currentBackup = 0

        foreach ($backup in $backupsToRestore)
        {
            $currentBackup++
            Write-Progress -Activity 'Restoring Daily Backups' -Status "Restoring backup $currentBackup of $totalBackups" -PercentComplete (($currentBackup / $totalBackups) * 100)

            try
            {
                $restoreParams = @{
                    BackupFilePath = $backup.Path
                    UseOriginalPath = $UseOriginalPaths
                    PreservePaths = $PreservePaths
                    VerboseEnabled = $verboseEnabled
                }

                if ($DestinationPath)
                {
                    $restoreParams.DestinationPath = $DestinationPath
                }

                if ($Force)
                {
                    $restoreParams.Force = $true
                }

                $result = Restore-BackupFile @restoreParams
                $results += $result

                if ($result.Success)
                {
                    Write-Host "[SUCCESS] $($result.Message)" -ForegroundColor Green
                }
                else
                {
                    Write-Warning "[FAILED] $($result.Message)"
                }
            }
            catch
            {
                $errorResult = [PSCustomObject]@{
                    Success = $false
                    SourcePath = $backup.Path
                    DestinationPath = $DestinationPath
                    Metadata = $backup.Metadata
                    Message = "Failed to restore $($backup.Name): $_"
                }
                $results += $errorResult
                Write-Error $errorResult.Message -ErrorAction Continue
            }
        }

        Write-Progress -Activity 'Restoring Daily Backups' -Completed
    }

    end
    {
        $successfulResults = @($results | Where-Object { $_.Success })
        $successCount = $successfulResults.Count
        $totalCount = $results.Count

        Write-Host "`nRestore Summary:" -ForegroundColor Cyan
        Write-Host "   Successful: $successCount" -ForegroundColor Green
        Write-Host "   Failed: $($totalCount - $successCount)" -ForegroundColor Red
        Write-Host "   Total: $totalCount" -ForegroundColor Blue

        Write-Verbose 'Restore-DailyBackup:End> Restore operation completed'
        return $results
    }
}
