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

    .PARAMETER NoHash
        Skip hash calculation to improve performance in simple backup scenarios.
        When specified, backup integrity verification will not be available.

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
        PS > Compress-BackupCombined -Paths @("C:\Docs", "C:\Projects\file.txt") -DestinationPath "D:\Backups\2025-09-17"

        Creates a combined archive containing both the directory and the file
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
        [switch] $NoHash
    )

    $currentTimestamp = Get-Date -Format 'HHmmss'
    $generatedCombinedArchiveName = "CombinedFiles_$currentTimestamp"
    $fullCombinedArchivePath = Join-MultiplePaths -Segments @($DestinationPath, "$generatedCombinedArchiveName.zip")

    Write-Verbose "Compress-BackupCombined> Creating combined archive: $fullCombinedArchivePath"
    Write-Verbose "Compress-BackupCombined> Including $($Paths.Count) source paths"

    if ($PSCmdlet.ShouldProcess($fullCombinedArchivePath, 'Create combined backup archive'))
    {
        try
        {
            # Create the ZIP archive with all paths
            Write-Verbose "Compress-BackupCombined> Compressing paths to: $fullCombinedArchivePath"
            Compress-Archive -Path $Paths -DestinationPath $fullCombinedArchivePath -CompressionLevel Optimal -ErrorAction Stop

            # Create metadata for combined archive - add each source path to manifest
            if (-not $NoHash)
            {
                Write-Verbose 'Compress-BackupCombined> Adding metadata to manifest for combined archive'
                foreach ($currentSourcePath in $Paths)
                {
                    $detectedPathType = Get-PathType -Path $currentSourcePath
                    Add-BackupToManifest -SourcePath $currentSourcePath -BackupPath $fullCombinedArchivePath.Replace('.zip', '') -PathType $detectedPathType -DatePath $DestinationPath -NoHash:$NoHash
                }
            }
            else
            {
                Write-Verbose 'Compress-BackupCombined> Skipping metadata creation (NoHash specified)'
            }

            Write-Verbose "Compress-BackupCombined> Successfully created combined archive: $fullCombinedArchivePath"
        }
        catch
        {
            Write-Warning "Compress-BackupCombined> Failed to create combined archive '$fullCombinedArchivePath': $($_.Exception.Message)"
            throw
        }
    }
}
