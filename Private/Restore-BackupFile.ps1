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
        [switch] $PreservePaths
    )

    if (-not $UseOriginalPath -and -not $DestinationPath)
    {
        throw 'Either DestinationPath must be specified or UseOriginalPath must be enabled'
    }

    if (-not (Test-Path $BackupFilePath))
    {
        throw "Backup file not found: $BackupFilePath"
    }

    $extractedBackupName = [System.IO.Path]::GetFileNameWithoutExtension($BackupFilePath)

    # Get backup metadata
    $retrievedBackupMetadata = Get-BackupMetadataInfo -BackupFilePath $BackupFilePath
    if ($retrievedBackupMetadata)
    {
        Write-Verbose "Restore-BackupFile> Loaded metadata for $extractedBackupName"
    }

    # Determine restore destination
    $determinedFinalDestination = if ($UseOriginalPath -and $retrievedBackupMetadata -and $retrievedBackupMetadata.SourcePath)
    {
        if ($retrievedBackupMetadata.PathType -eq 'File')
        {
            Split-Path $retrievedBackupMetadata.SourcePath
        }
        else
        {
            $retrievedBackupMetadata.SourcePath
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

    Write-Verbose "Restore-BackupFile> Final destination determined as: $determinedFinalDestination"

    # Ensure destination exists
    if (-not (Test-Path $determinedFinalDestination))
    {
        if ($PSCmdlet.ShouldProcess($determinedFinalDestination, 'Create Directory'))
        {
            New-Item -Path $determinedFinalDestination -ItemType Directory -Force | Out-Null
            Write-Verbose "Restore-BackupFile> Created destination directory: $determinedFinalDestination"
        }
    }

    # Extract the backup
    if ($PSCmdlet.ShouldProcess($BackupFilePath, 'Expand-Archive'))
    {
        try
        {
            Write-Verbose "Restore-BackupFile> Extracting $BackupFilePath to $determinedFinalDestination"

            if ($PreservePaths)
            {
                Expand-Archive -Path $BackupFilePath -DestinationPath $determinedFinalDestination -Force
            }
            else
            {
                # Extract to a temp location first, then move files to preserve structure
                $availableTempDirectory = if ($env:TEMP) { $env:TEMP } elseif ($env:TMP) { $env:TMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { '/tmp' }
                $generatedTempExtractionPath = Join-MultiplePaths -Segments @($availableTempDirectory, "DailyBackupRestore_$(Get-Random)")
                Write-Verbose "Restore-BackupFile> Extracting to temp path: $generatedTempExtractionPath"
                Expand-Archive -Path $BackupFilePath -DestinationPath $generatedTempExtractionPath -Force

                # Verify temp path exists and has content
                if (-not (Test-Path $generatedTempExtractionPath))
                {
                    throw "Extraction failed: temp path $generatedTempExtractionPath does not exist"
                }

                Write-Verbose "Restore-BackupFile> Temp path contents: $(Get-ChildItem $generatedTempExtractionPath -Name)"

                # Move extracted items to final destination
                $discoveredExtractedItems = Get-ChildItem $generatedTempExtractionPath -Recurse
                foreach ($currentExtractedItem in $discoveredExtractedItems)
                {
                    if ($currentExtractedItem.PSIsContainer)
                    {
                        $targetDirectoryPath = Join-MultiplePaths -Segments @($determinedFinalDestination, $currentExtractedItem.Name)
                        if (-not (Test-Path $targetDirectoryPath))
                        {
                            New-Item -Path $targetDirectoryPath -ItemType Directory -Force | Out-Null
                        }
                    }
                    else
                    {
                        $targetFilePath = Join-MultiplePaths -Segments @($determinedFinalDestination, $currentExtractedItem.Name)
                        Copy-Item $currentExtractedItem.FullName $targetFilePath -Force
                    }
                }

                # Clean up temp directory
                Remove-Item $generatedTempExtractionPath -Recurse -Force -ErrorAction SilentlyContinue
            }

            # Attempt to restore metadata if available
            if ($retrievedBackupMetadata -and $retrievedBackupMetadata.PathType -eq 'File' -and $retrievedBackupMetadata.LastWriteTime)
            {
                try
                {
                    $discoveredRestoredFiles = Get-ChildItem $determinedFinalDestination -File -Recurse
                    foreach ($currentRestoredFile in $discoveredRestoredFiles)
                    {
                        $currentRestoredFile.LastWriteTime = [DateTime]::Parse($retrievedBackupMetadata.LastWriteTime)
                    }
                    Write-Verbose 'Restore-BackupFile> Restored file timestamps'
                }
                catch
                {
                    Write-Warning "Restore-BackupFile> Failed to restore file timestamps: $_"
                }
            }

            return [PSCustomObject]@{
                Success = $true
                SourcePath = $BackupFilePath
                DestinationPath = $determinedFinalDestination
                Metadata = $retrievedBackupMetadata
                Message = "Successfully restored $extractedBackupName"
            }
        }
        catch
        {
            return [PSCustomObject]@{
                Success = $false
                SourcePath = $BackupFilePath
                DestinationPath = $determinedFinalDestination
                Metadata = $retrievedBackupMetadata
                Message = "Failed to restore $extractedBackupName : $_"
            }
        }
    }
    else
    {
        return [PSCustomObject]@{
            Success = $true
            SourcePath = $BackupFilePath
            DestinationPath = $determinedFinalDestination
            Metadata = $retrievedBackupMetadata
            Message = "Dry-run: Would restore $extractedBackupName to $determinedFinalDestination"
        }
    }
}
