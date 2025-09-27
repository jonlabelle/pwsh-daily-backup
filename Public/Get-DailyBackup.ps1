function Get-DailyBackup
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
        [System.Object[]]
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
        PS > Get-DailyBackup -BackupRoot 'D:\Backups'

        Lists all available backup dates and their contents

    .EXAMPLE
        PS > Get-DailyBackup -BackupRoot 'D:\Backups' -Date '2025-09-15'

        Shows detailed information for backups from September 15, 2025
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupRoot,

        [Parameter()]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $Date
    )

    # Normalize and resolve the backup root path
    $BackupRoot = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BackupRoot)

    if (-not (Test-Path -Path $BackupRoot -PathType Container))
    {
        Write-Warning "Backup root directory not found: $BackupRoot"
        return @()
    }

    $availableBackupDates = if ($Date)
    {
        $matchingDateDirectories = Get-ChildItem -Path $BackupRoot -Directory -Name | Where-Object { $_ -eq $Date }
        if ($matchingDateDirectories) { @($matchingDateDirectories) } else { @() }
    }
    else
    {
        $matchingDateDirectories = Get-ChildItem -Path $BackupRoot -Directory -Name | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Descending
        if ($matchingDateDirectories) { @($matchingDateDirectories) } else { @() }
    }

    $backupInformation = @()
    foreach ($currentBackupDate in $availableBackupDates)
    {
        if (-not $currentBackupDate) { continue }

        $backupDateDirectoryPath = Join-MultiplePaths -Segments @($BackupRoot, $currentBackupDate)
        if (-not (Test-Path $backupDateDirectoryPath -PathType Container)) { continue }

        $backupArchiveFiles = @(Get-ChildItem -Path $backupDateDirectoryPath -Filter '*.zip')

        # Check for backup manifest
        $backupManifestFilePath = Join-MultiplePaths -Segments @($backupDateDirectoryPath, 'backup-manifest.json')
        $backupManifestContent = $null

        if (Test-Path $backupManifestFilePath)
        {
            try
            {
                $backupManifestContent = Get-Content $backupManifestFilePath -Raw | ConvertFrom-Json
                Write-Verbose "Get-DailyBackup> Using backup manifest for $currentBackupDate"
            }
            catch
            {
                Write-Warning "Failed to read backup manifest for $currentBackupDate : $_"
            }
        }

        $individualBackupDetails = @()
        foreach ($currentArchiveFile in $backupArchiveFiles)
        {
            $archiveFileInformation = [PSCustomObject]@{
                Name = $currentArchiveFile.Name
                Path = $currentArchiveFile.FullName
                Size = $currentArchiveFile.Length
                Created = $currentArchiveFile.CreationTime
                Metadata = $null
            }

            # Try to get metadata from backup manifest
            if ($backupManifestContent -and $backupManifestContent.Backups)
            {
                $manifestMetadata = $backupManifestContent.Backups | Where-Object { $_.ArchiveName -eq $currentArchiveFile.Name }
                if ($manifestMetadata)
                {
                    $archiveFileInformation.Metadata = $manifestMetadata
                }
            }

            $individualBackupDetails += $archiveFileInformation
        }

        $totalBackupSize = ($backupArchiveFiles | Measure-Object -Property Length -Sum).Sum

        # Count metadata sources (manifest file)
        $availableMetadataCount = if ($backupManifestContent) { 1 } else { 0 }

        $backupInformation += [PSCustomObject]@{
            Date = $currentBackupDate
            Path = $backupDateDirectoryPath
            Backups = $individualBackupDetails
            TotalSize = $totalBackupSize
            BackupCount = $backupArchiveFiles.Count
            MetadataCount = $availableMetadataCount
        }
    }

    # Ensure we always return an array for PowerShell 5.1 compatibility
    if (-not $backupInformation)
    {
        Write-Output @() -NoEnumerate
    }
    elseif ($backupInformation.Count -eq 0)
    {
        Write-Output @() -NoEnumerate
    }
    else
    {
        Write-Output @($backupInformation) -NoEnumerate
    }
}
