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
        $backupDir = Split-Path $BackupFilePath
        $backupName = [System.IO.Path]::GetFileNameWithoutExtension($BackupFilePath)

        # Read from backup manifest
        $manifestPath = Join-Path $backupDir 'backup-manifest.json'
        if (Test-Path $manifestPath)
        {
            try
            {
                $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
                $backup = $manifest.Backups | Where-Object { $_.ArchiveName -eq ([System.IO.Path]::GetFileName($BackupFilePath)) }

                if ($backup)
                {
                    Write-Verbose "Get-BackupMetadataInfo> Found metadata in backup manifest for $backupName"
                    return $backup
                }
            }
            catch
            {
                Write-Warning "Get-BackupMetadataInfo> Failed to read manifest: $_"
            }
        }

        Write-Verbose "Get-BackupMetadataInfo> No metadata found for $backupName"
        return $null
    }
    catch
    {
        Write-Warning "Get-BackupMetadataInfo> Error retrieving metadata for $BackupFilePath : $_"
        return $null
    }
}
