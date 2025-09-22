function Get-BackupMetadataInfo
{
    <#
    .SYNOPSIS
        Retrieves backup metadata from the daily backup manifest.

    .DESCRIPTION
        Reads metadata from the backup-manifest.json format for a specific backup file.

    .PARAMETER BackupFilePath
        The path to the backup archive (.zip file).

    .OUTPUTS
        PSObject containing backup metadata, or $null if not found.

    .NOTES
        This function reads from the backup-manifest.json format.

    .EXAMPLE
        PS > Get-BackupMetadataInfo -BackupFilePath 'C:\Backups\2025-09-15\Documents__report.pdf.zip'

        Returns metadata object for the specified backup file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $BackupFilePath
    )

    try
    {
        $parentBackupDirectory = Split-Path $BackupFilePath
        $extractedBackupName = [System.IO.Path]::GetFileNameWithoutExtension($BackupFilePath)

        # Read from backup manifest
        $locatedManifestPath = Join-Path $parentBackupDirectory 'backup-manifest.json'
        if (Test-Path $locatedManifestPath)
        {
            try
            {
                $loadedManifestObject = Get-Content $locatedManifestPath -Raw | ConvertFrom-Json
                $matchingBackupEntry = $loadedManifestObject.Backups | Where-Object { $_.ArchiveName -eq ([System.IO.Path]::GetFileName($BackupFilePath)) }

                if ($matchingBackupEntry)
                {
                    Write-Verbose "Get-BackupMetadataInfo> Found metadata in backup manifest for $extractedBackupName"
                    return $matchingBackupEntry
                }
            }
            catch
            {
                Write-Warning "Get-BackupMetadataInfo> Failed to read manifest: $_"
            }
        }

        Write-Verbose "Get-BackupMetadataInfo> No metadata found for $extractedBackupName"
        return $null
    }
    catch
    {
        Write-Warning "Get-BackupMetadataInfo> Error retrieving metadata for $BackupFilePath : $_"
        return $null
    }
}
