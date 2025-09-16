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

        # Check for consolidated manifest
        $manifestPath = Join-Path $datePath 'backup-manifest.json'
        $manifestData = $null

        if (Test-Path $manifestPath)
        {
            try
            {
                $manifestData = Get-Content $manifestPath -Raw | ConvertFrom-Json
                Write-Verbose "Get-BackupInfo> Using consolidated manifest for $dateFolder"
            }
            catch
            {
                Write-Warning "Failed to read backup manifest for $dateFolder : $_"
            }
        }

        $backups = @()
        foreach ($zipFile in $zipFiles)
        {
            $backupInfo = [PSCustomObject]@{
                Name = $zipFile.Name
                Path = $zipFile.FullName
                Size = $zipFile.Length
                Created = $zipFile.CreationTime
                Metadata = $null
            }

            # Try to get metadata from consolidated manifest
            if ($manifestData -and $manifestData.Backups)
            {
                $metadata = $manifestData.Backups | Where-Object { $_.ArchiveName -eq $zipFile.Name }
                if ($metadata)
                {
                    $backupInfo.Metadata = $metadata
                }
            }

            $backups += $backupInfo
        }

        $totalSize = ($zipFiles | Measure-Object -Property Length -Sum).Sum

        # Count metadata sources (manifest file)
        $metadataCount = if ($manifestData) { 1 } else { 0 }

        $results += [PSCustomObject]@{
            Date = $dateFolder
            Path = $datePath
            Backups = $backups
            TotalSize = $totalSize
            BackupCount = $zipFiles.Count
            MetadataCount = $metadataCount
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
