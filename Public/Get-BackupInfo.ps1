function Get-BackupInfo
{
    <#
    .SYNOPSIS
        Retrieves information about available backups in a backup directory.

    .DESCRIPTION
        Scans a backup directory structure to find available backups, organized by date.
        Returns detailed information about each backup including metadata, file types,
        and backup dates. This function is used internally by Restore-DailyBackup
        and can also be used independently to browse available backups.

    .PARAMETER BackupRoot
        The root directory containing daily backup folders (yyyy-MM-dd format).

    .PARAMETER Date
        Optional. Specific date to retrieve backup information for (yyyy-MM-dd format).
        If not specified, returns information for all available backup dates.

    .OUTPUTS
        [PSCustomObject[]]
        Returns an array of backup information objects containing:
        - Date: Backup date (yyyy-MM-dd)
        - Path: Full path to the backup directory
        - Backups: Array of individual backup files with metadata
        - TotalSize: Total size of all backups for that date
        - BackupCount: Number of individual backup files

    .NOTES
        This function helps users understand what backups are available before
        performing restore operations.

    .EXAMPLE
        PS > Get-BackupInfo -BackupRoot 'D:\Backups'

        Lists all available backup dates and their contents

    .EXAMPLE
        PS > Get-BackupInfo -BackupRoot 'D:\Backups' -Date '2025-09-15'

        Shows detailed information for backups from September 15, 2025
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupRoot,

        [Parameter()]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $Date
    )

    if (-not (Test-Path -Path $BackupRoot -PathType Container))
    {
        Write-Warning "Backup root directory not found: $BackupRoot"
        return @()
    }

    $backupDates = if ($Date)
    {
        $matchedDirs = Get-ChildItem -Path $BackupRoot -Directory -Name | Where-Object { $_ -eq $Date }
        if ($matchedDirs) { @($matchedDirs) } else { @() }
    }
    else
    {
        $matchedDirs = Get-ChildItem -Path $BackupRoot -Directory -Name | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Descending
        if ($matchedDirs) { @($matchedDirs) } else { @() }
    }

    $results = @()
    foreach ($dateFolder in $backupDates)
    {
        if (-not $dateFolder) { continue }

        $datePath = Join-Path $BackupRoot $dateFolder
        if (-not (Test-Path $datePath -PathType Container)) { continue }

        $zipFiles = @(Get-ChildItem -Path $datePath -Filter '*.zip')
        $metadataFiles = @(Get-ChildItem -Path $datePath -Filter '*.metadata.json')

        $backups = @()
        foreach ($zipFile in $zipFiles)
        {
            $baseName = $zipFile.BaseName
            $metadataPath = Join-Path $datePath "$baseName.metadata.json"

            $backupInfo = [PSCustomObject]@{
                Name = $zipFile.Name
                Path = $zipFile.FullName
                Size = $zipFile.Length
                Created = $zipFile.CreationTime
                Metadata = $null
            }

            if (Test-Path $metadataPath)
            {
                try
                {
                    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
                    $backupInfo.Metadata = $metadata
                }
                catch
                {
                    Write-Warning "Failed to read metadata for $($zipFile.Name): $_"
                }
            }

            $backups += $backupInfo
        }

        $totalSize = ($zipFiles | Measure-Object -Property Length -Sum).Sum

        $results += [PSCustomObject]@{
            Date = $dateFolder
            Path = $datePath
            Backups = $backups
            TotalSize = $totalSize
            BackupCount = $zipFiles.Count
            MetadataCount = $metadataFiles.Count
        }
    }

    # Ensure we always return an array for PowerShell 5.1 compatibility
    if (-not $results)
    {
        Write-Output @() -NoEnumerate
    }
    elseif ($results.Count -eq 0)
    {
        Write-Output @() -NoEnumerate
    }
    else
    {
        Write-Output @($results) -NoEnumerate
    }
}
