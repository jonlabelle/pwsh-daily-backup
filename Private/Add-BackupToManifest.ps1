function Add-BackupToManifest
{
    <#
    .SYNOPSIS
        Adds backup information to a daily backup manifest file.

    .DESCRIPTION
        Creates or updates a daily backup manifest (backup-manifest.json) containing
        metadata for all backups created on a specific date. This approach maintains
        full restoration capabilities for all backed up files and directories.

    .PARAMETER SourcePath
        The original path that was backed up.

    .PARAMETER BackupPath
        The path to the created backup archive (without .zip extension).

    .PARAMETER PathType
        The type of the source path ('File' or 'Directory').

    .PARAMETER DatePath
        The date-organized backup directory path (e.g., /backups/2025-09-15).

    .PARAMETER NoHash
        Skip hash calculation to improve performance in simple backup scenarios.

    .PARAMETER HashAlgorithm
        The hash algorithm to use for calculating hashes.
        Available options: SHA1, SHA256, SHA384, SHA512, MD5.
        Defaults to SHA256.

    .OUTPUTS
        None. Creates or updates backup-manifest.json in the date directory.

    .NOTES
        This function creates a single backup-manifest.json file per backup date,
        containing metadata for all backups created on that date.

    .EXAMPLE
        PS > Add-BackupToManifest -SourcePath 'C:\Documents\report.pdf' -BackupPath 'C:\Backups\2025-09-15\Documents__report.pdf' -PathType 'File' -DatePath 'C:\Backups\2025-09-15'

        Adds backup entry to C:\Backups\2025-09-15\backup-manifest.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('File', 'Directory')]
        [string] $PathType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DatePath,

        [Parameter(Mandatory = $false)]
        [switch] $NoHash,

        [Parameter(Mandatory = $false)]
        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5')]
        [string] $HashAlgorithm = 'SHA256'
    )

    try
    {
        # Validate and resolve paths
        if (-not (Test-Path -Path $DatePath -PathType Container))
        {
            Write-Warning "Add-BackupToManifest> Date path does not exist: $DatePath"
            return
        }

        # Validate source path exists
        if (-not (Test-Path -Path $SourcePath))
        {
            Write-Warning "Add-BackupToManifest> Source path does not exist: $SourcePath"
            return
        }

        $backupManifestFilePath = Join-MultiplePaths -Segments @($DatePath, 'backup-manifest.json')
        $generatedArchiveFileName = [System.IO.Path]::GetFileName($BackupPath) + '.zip'

        # Get module version dynamically
        $currentModuleInfo = Get-Module -Name DailyBackup
        $detectedModuleVersion = if ($currentModuleInfo) { $currentModuleInfo.Version.ToString() } else { '1.0.0' }

        # Create backup entry
        $newBackupEntryObject = @{
            ArchiveName = $generatedArchiveFileName
            SourcePath = $SourcePath
            PathType = $PathType
            BackupCreated = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
        }

        # Calculate hashes unless disabled
        if (-not $NoHash)
        {
            Write-Verbose "Add-BackupToManifest> Calculating source hash for: $SourcePath"
            $calculatedSourceHash = Get-PathHash -Path $SourcePath -Algorithm $HashAlgorithm

            if ($calculatedSourceHash)
            {
                $newBackupEntryObject.SourceHash = $calculatedSourceHash
                $newBackupEntryObject.HashAlgorithm = $HashAlgorithm
                Write-Verbose "Add-BackupToManifest> Source hash: $calculatedSourceHash"

                # Calculate archive hash after it's created
                $fullArchiveFilePath = "$BackupPath.zip"
                if (Test-Path $fullArchiveFilePath)
                {
                    Write-Verbose "Add-BackupToManifest> Calculating archive hash for: $fullArchiveFilePath"
                    $calculatedArchiveHashObject = Get-FileHash -Path $fullArchiveFilePath -Algorithm $HashAlgorithm
                    $newBackupEntryObject.ArchiveHash = $calculatedArchiveHashObject.Hash
                    Write-Verbose "Add-BackupToManifest> Archive hash: $($calculatedArchiveHashObject.Hash)"
                }
                else
                {
                    Write-Warning "Add-BackupToManifest> Archive not found for hash calculation: $fullArchiveFilePath"
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
            $sourceFileOrDirectoryItem = Get-Item -Path $SourcePath
            $newBackupEntryObject.OriginalName = $sourceFileOrDirectoryItem.Name
            $newBackupEntryObject.LastWriteTime = $sourceFileOrDirectoryItem.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $newBackupEntryObject.Attributes = $sourceFileOrDirectoryItem.Attributes.ToString()

            if ($PathType -eq 'File')
            {
                $newBackupEntryObject.Size = $sourceFileOrDirectoryItem.Length
                $newBackupEntryObject.Extension = $sourceFileOrDirectoryItem.Extension
            }
        }

        # Load existing manifest or create new one
        $loadedManifestObject = $null
        if (Test-Path $backupManifestFilePath)
        {
            try
            {
                $manifestFileContent = Get-Content $backupManifestFilePath -Raw -ErrorAction Stop
                if ($manifestFileContent -and $manifestFileContent.Trim())
                {
                    $loadedManifestObject = $manifestFileContent | ConvertFrom-Json -ErrorAction Stop

                    # Validate manifest structure
                    if (-not $loadedManifestObject.PSObject.Properties['Backups'])
                    {
                        Write-Verbose 'Add-BackupToManifest> Adding missing Backups array to existing manifest'
                        $loadedManifestObject | Add-Member -NotePropertyName 'Backups' -NotePropertyValue @() -Force
                    }
                    elseif ($null -eq $loadedManifestObject.Backups)
                    {
                        $loadedManifestObject.Backups = @()
                    }
                }
                else
                {
                    Write-Verbose 'Add-BackupToManifest> Manifest file is empty, creating new manifest'
                    $loadedManifestObject = $null
                }
            }
            catch
            {
                Write-Warning "Add-BackupToManifest> Failed to read existing manifest, creating new one: $_"
                $loadedManifestObject = $null
            }
        }

        # Create new manifest structure if needed or validate existing one
        if (-not $loadedManifestObject)
        {
            $extractedBackupDate = Split-Path $DatePath -Leaf
            $loadedManifestObject = @{
                BackupDate = $extractedBackupDate
                BackupVersion = '1.0'
                ModuleVersion = $detectedModuleVersion
                Backups = @()
            }
        }
        elseif (-not $loadedManifestObject.PSObject.Properties['Backups'] -or $null -eq $loadedManifestObject.Backups)
        {
            # Ensure Backups array exists
            $loadedManifestObject | Add-Member -NotePropertyName 'Backups' -NotePropertyValue @() -Force
        }

        # Add new backup entry
        $loadedManifestObject.Backups += $newBackupEntryObject

        # Save updated manifest
        $loadedManifestObject | ConvertTo-Json -Depth 4 | Out-File -FilePath $backupManifestFilePath -Encoding UTF8
        Write-Verbose "Add-BackupToManifest> Added backup to manifest: $backupManifestFilePath"
    }
    catch
    {
        Write-Warning "Add-BackupToManifest> Failed to update manifest for $SourcePath : $_"
    }
}
