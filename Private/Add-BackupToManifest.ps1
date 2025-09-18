function Add-BackupToManifest
{
    <#
    .SYNOPSIS
        Adds backup information to a consolidated daily manifest file.

    .DESCRIPTION
        Creates or updates a daily backup manifest (backup-manifest.json) containing
        metadata for all backups created on a specific date. This consolidated approach
        reduces file clutter while maintaining full restoration capabilities.

    .PARAMETER SourcePath
        The original path that was backed up.

    .PARAMETER BackupPath
        The path to the created backup archive (without .zip extension).

    .PARAMETER PathType
        The type of the source path ('File' or 'Directory').

    .PARAMETER DatePath
        The date-organized backup directory path (e.g., /backups/2025-09-15).

    .OUTPUTS
        None. Creates or updates backup-manifest.json in the date directory.

    .NOTES
        This function replaces individual .metadata.json files with a single
        consolidated manifest per backup date, dramatically reducing file clutter.

    .EXAMPLE
        PS > Add-BackupToManifest -SourcePath 'C:\Documents\report.pdf' -BackupPath 'C:\Backups\2025-09-15\Documents__report.pdf' -PathType 'File' -DatePath 'C:\Backups\2025-09-15'

        Adds backup entry to C:\Backups\2025-09-15\backup-manifest.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [string] $BackupPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('File', 'Directory')]
        [string] $PathType,

        [Parameter(Mandatory = $true)]
        [string] $DatePath,

        [Parameter(Mandatory = $false)]
        [switch] $NoHash
    )

    try
    {
        $manifestPath = Join-Path $DatePath 'backup-manifest.json'
        $archiveName = [System.IO.Path]::GetFileName($BackupPath) + '.zip'

        # Get module version dynamically
        $moduleInfo = Get-Module -Name DailyBackup
        $moduleVersion = if ($moduleInfo) { $moduleInfo.Version.ToString() } else { '1.5.3' }

        # Create backup entry
        $backupEntry = @{
            ArchiveName = $archiveName
            SourcePath = $SourcePath
            PathType = $PathType
            BackupCreated = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
        }

        # Calculate hashes unless disabled
        if (-not $NoHash)
        {
            Write-Verbose "Add-BackupToManifest> Calculating source hash for: $SourcePath"
            $sourceHash = Get-PathHash -Path $SourcePath -Algorithm 'SHA256'

            if ($sourceHash)
            {
                $backupEntry.SourceHash = $sourceHash
                $backupEntry.HashAlgorithm = 'SHA256'
                Write-Verbose "Add-BackupToManifest> Source hash: $sourceHash"

                # Calculate archive hash after it's created
                $archiveFullPath = "$BackupPath.zip"
                if (Test-Path $archiveFullPath)
                {
                    Write-Verbose "Add-BackupToManifest> Calculating archive hash for: $archiveFullPath"
                    $archiveHash = Get-FileHash -Path $archiveFullPath -Algorithm SHA256
                    $backupEntry.ArchiveHash = $archiveHash.Hash
                    Write-Verbose "Add-BackupToManifest> Archive hash: $($archiveHash.Hash)"
                }
                else
                {
                    Write-Warning "Add-BackupToManifest> Archive not found for hash calculation: $archiveFullPath"
                }
            }
            else
            {
                Write-Warning "Add-BackupToManifest> Failed to calculate source hash for: $SourcePath"
            }
        }

        # Add file/directory specific metadata
        if (Test-Path -Path $SourcePath)
        {
            $item = Get-Item -Path $SourcePath
            $backupEntry.OriginalName = $item.Name
            $backupEntry.LastWriteTime = $item.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $backupEntry.Attributes = $item.Attributes.ToString()

            if ($PathType -eq 'File')
            {
                $backupEntry.Size = $item.Length
                $backupEntry.Extension = $item.Extension
            }
        }

        # Load existing manifest or create new one
        $manifest = if (Test-Path $manifestPath)
        {
            try
            {
                Get-Content $manifestPath -Raw | ConvertFrom-Json
            }
            catch
            {
                Write-Warning "Add-BackupToManifest> Failed to read existing manifest, creating new one: $_"
                $null
            }
        }
        else
        {
            $null
        }

        # Create new manifest structure if needed
        if (-not $manifest)
        {
            $backupDate = Split-Path $DatePath -Leaf
            $manifest = @{
                BackupDate = $backupDate
                BackupVersion = '1.0'
                ModuleVersion = $moduleVersion
                Backups = @()
            }
        }

        # Add new backup entry
        $manifest.Backups += $backupEntry

        # Save updated manifest
        $manifest | ConvertTo-Json -Depth 4 | Out-File -FilePath $manifestPath -Encoding UTF8
        Write-Verbose "Add-BackupToManifest> Added backup to manifest: $manifestPath"
    }
    catch
    {
        Write-Warning "Add-BackupToManifest> Failed to update manifest for $SourcePath : $_"
    }
}
