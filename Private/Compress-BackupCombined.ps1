function Compress-BackupCombined
{
    <#
    .SYNOPSIS
        Creates a combined backup archive containing multiple source paths.

    .DESCRIPTION
        Creates a single ZIP archive containing all specified source paths. This function
        is used when FileBackupMode is set to 'Combined', allowing multiple files and
        directories to be packaged into a single archive file for easier management.

    .PARAMETER Paths
        Array of source file and directory paths to include in the combined archive.
        All paths will be compressed into a single ZIP file.

    .PARAMETER DestinationPath
        The destination directory where the combined archive will be created.

    .PARAMETER VerboseEnabled
        Controls whether verbose output is displayed during the backup operation.

    .PARAMETER NoHash
        Skip hash calculation to improve performance in simple backup scenarios.
        When specified, backup integrity verification will not be available.

    .PARAMETER WhatIf
        Shows what would happen if the function runs without actually performing any actions.

    .OUTPUTS
        None. This function creates backup files but does not return objects.

    .NOTES
        - Creates a single archive named with timestamp for uniqueness
        - Supports both files and directories in the same archive
        - Maintains relative path structure within the archive
        - Compatible with Restore-DailyBackup functionality

    .EXAMPLE
        PS > Compress-BackupCombined -Paths @("C:\file1.txt", "C:\file2.txt") -DestinationPath "D:\Backups\2025-09-17"

        Creates a combined archive containing both files

    .EXAMPLE
        PS > Compress-BackupCombined -Paths @("C:\Docs", "C:\Projects\file.txt") -DestinationPath "D:\Backups\2025-09-17" -VerboseEnabled $true

        Creates a combined archive with verbose output showing detailed progress
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Paths,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationPath,

        [Parameter(Mandatory = $false)]
        [bool] $VerboseEnabled = $false,

        [Parameter(Mandatory = $false)]
        [switch] $NoHash
    )

    $timestamp = Get-Date -Format 'HHmmss'
    $combinedArchiveName = "CombinedFiles_$timestamp"
    $archivePath = Join-Path -Path $DestinationPath -ChildPath "$combinedArchiveName.zip"

    Write-Verbose "Compress-BackupCombined> Creating combined archive: $archivePath" -Verbose:$VerboseEnabled
    Write-Verbose "Compress-BackupCombined> Including $($Paths.Count) source paths" -Verbose:$VerboseEnabled

    if ($PSCmdlet.ShouldProcess($archivePath, 'Create combined backup archive'))
    {
        try
        {
            # Create the ZIP archive with all paths
            Write-Verbose "Compress-BackupCombined> Compressing paths to: $archivePath" -Verbose:$VerboseEnabled
            Compress-Archive -Path $Paths -DestinationPath $archivePath -CompressionLevel Optimal -ErrorAction Stop

            # Create metadata for combined archive - add each source path to manifest
            if (-not $NoHash)
            {
                Write-Verbose "Compress-BackupCombined> Adding metadata to manifest for combined archive" -Verbose:$VerboseEnabled
                foreach ($sourcePath in $Paths)
                {
                    $pathType = Get-PathType -Path $sourcePath
                    Add-BackupToManifest -SourcePath $sourcePath -BackupPath $archivePath.Replace('.zip', '') -PathType $pathType -DatePath $DestinationPath -NoHash:$NoHash
                }
            }
            else
            {
                Write-Verbose "Compress-BackupCombined> Skipping metadata creation (NoHash specified)" -Verbose:$VerboseEnabled
            }

            Write-Verbose "Compress-BackupCombined> Successfully created combined archive: $archivePath" -Verbose:$VerboseEnabled
        }
        catch
        {
            Write-Error "Compress-BackupCombined> Failed to create combined archive '$archivePath': $($_.Exception.Message)"
            throw
        }
    }
}
