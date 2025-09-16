function Restore-BackupFile
{
    <#
    .SYNOPSIS
        Restores a single backup ZIP file to a specified location.

    .DESCRIPTION
        Extracts a backup ZIP file to a destination directory, optionally using
        metadata information to restore original paths, timestamps, and attributes.
        This is an internal helper function used by Restore-DailyBackup.

    .PARAMETER BackupFilePath
        The full path to the backup ZIP file to restore.

    .PARAMETER DestinationPath
        The destination directory where the backup should be restored.

    .PARAMETER UseOriginalPath
        If specified and metadata is available, attempts to restore to the original
        source path rather than the specified destination.

    .PARAMETER PreservePaths
        Controls whether directory structure within the ZIP is preserved during extraction.

    .PARAMETER VerboseEnabled
        Controls verbose output during the restore operation.

    .OUTPUTS
        [PSCustomObject]
        Returns information about the restore operation including success status,
        paths processed, and any errors encountered.

    .NOTES
        This function leverages PowerShell's Expand-Archive cmdlet for extraction
        and attempts to restore file attributes and timestamps when possible.

    .EXAMPLE
        PS > Restore-BackupFile -BackupFilePath 'D:\Backups\2025-09-15\Documents.zip' -DestinationPath 'C:\Restored'

        Extracts the Documents backup to C:\Restored
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $BackupFilePath,

        [Parameter()]
        [string] $DestinationPath,

        [Parameter()]
        [switch] $UseOriginalPath,

        [Parameter()]
        [switch] $PreservePaths,

        [Parameter()]
        [bool] $VerboseEnabled = $false
    )

    if (-not $UseOriginalPath -and -not $DestinationPath)
    {
        throw 'Either DestinationPath must be specified or UseOriginalPath must be enabled'
    }

    if (-not (Test-Path $BackupFilePath))
    {
        throw "Backup file not found: $BackupFilePath"
    }

    $backupName = [System.IO.Path]::GetFileNameWithoutExtension($BackupFilePath)
    $metadataPath = Join-Path (Split-Path $BackupFilePath) "$backupName.metadata.json"

    $metadata = $null
    if (Test-Path $metadataPath)
    {
        try
        {
            $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
            Write-Verbose "Restore-BackupFile> Loaded metadata for $backupName"
        }
        catch
        {
            Write-Warning "Failed to read metadata for $backupName : $_"
        }
    }

    # Determine restore destination
    $finalDestination = if ($UseOriginalPath -and $metadata -and $metadata.SourcePath)
    {
        if ($metadata.PathType -eq 'File')
        {
            Split-Path $metadata.SourcePath
        }
        else
        {
            $metadata.SourcePath
        }
    }
    elseif ($DestinationPath)
    {
        $DestinationPath
    }
    else
    {
        throw 'Cannot determine destination path: UseOriginalPath is enabled but no metadata source path available, and no DestinationPath specified'
    }

    Write-Verbose "Restore-BackupFile> Final destination determined as: $finalDestination"

    # Ensure destination exists
    if (-not (Test-Path $finalDestination))
    {
        if ($PSCmdlet.ShouldProcess($finalDestination, 'Create Directory'))
        {
            New-Item -Path $finalDestination -ItemType Directory -Force | Out-Null
            Write-Verbose "Restore-BackupFile> Created destination directory: $finalDestination"
        }
    }

    # Extract the backup
    if ($PSCmdlet.ShouldProcess($BackupFilePath, 'Expand-Archive'))
    {
        try
        {
            Write-Verbose "Restore-BackupFile> Extracting $BackupFilePath to $finalDestination"

            if ($PreservePaths)
            {
                Expand-Archive -Path $BackupFilePath -DestinationPath $finalDestination -Force
            }
            else
            {
                # Extract to a temp location first, then move files to preserve structure
                $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMP) { $env:TMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { '/tmp' }
                $tempPath = Join-Path $tempDir "DailyBackupRestore_$(Get-Random)"
                Write-Verbose "Restore-BackupFile> Extracting to temp path: $tempPath"
                Expand-Archive -Path $BackupFilePath -DestinationPath $tempPath -Force

                # Verify temp path exists and has content
                if (-not (Test-Path $tempPath))
                {
                    throw "Extraction failed: temp path $tempPath does not exist"
                }

                Write-Verbose "Restore-BackupFile> Temp path contents: $(Get-ChildItem $tempPath -Name)"

                # Move extracted items to final destination
                $extractedItems = Get-ChildItem $tempPath -Recurse
                foreach ($item in $extractedItems)
                {
                    if ($item.PSIsContainer)
                    {
                        $targetDir = Join-Path $finalDestination $item.Name
                        if (-not (Test-Path $targetDir))
                        {
                            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                        }
                    }
                    else
                    {
                        $targetFile = Join-Path $finalDestination $item.Name
                        Copy-Item $item.FullName $targetFile -Force
                    }
                }

                # Clean up temp directory
                Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }

            # Attempt to restore metadata if available
            if ($metadata -and $metadata.PathType -eq 'File' -and $metadata.LastWriteTime)
            {
                try
                {
                    $restoredFiles = Get-ChildItem $finalDestination -File -Recurse
                    foreach ($file in $restoredFiles)
                    {
                        $file.LastWriteTime = [DateTime]::Parse($metadata.LastWriteTime)
                    }
                    Write-Verbose 'Restore-BackupFile> Restored file timestamps'
                }
                catch
                {
                    Write-Warning "Failed to restore file timestamps: $_"
                }
            }

            return [PSCustomObject]@{
                Success = $true
                SourcePath = $BackupFilePath
                DestinationPath = $finalDestination
                Metadata = $metadata
                Message = "Successfully restored $backupName"
            }
        }
        catch
        {
            return [PSCustomObject]@{
                Success = $false
                SourcePath = $BackupFilePath
                DestinationPath = $finalDestination
                Metadata = $metadata
                Message = "Failed to restore $backupName : $_"
            }
        }
    }
    else
    {
        return [PSCustomObject]@{
            Success = $true
            SourcePath = $BackupFilePath
            DestinationPath = $finalDestination
            Metadata = $metadata
            Message = "Dry-run: Would restore $backupName to $finalDestination"
        }
    }
}
