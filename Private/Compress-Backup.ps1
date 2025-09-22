function Compress-Backup
{
    <#
    .SYNOPSIS
        Creates a compressed archive (.zip) from a file or directory.

    .DESCRIPTION
        Compresses a specified file or directory into a ZIP archive using PowerShell's
        Compress-Archive cmdlet. The function supports WhatIf/ShouldProcess for safe
        testing and generates a unique backup filename automatically. If WhatIf is specified,
        the operation is simulated without creating the actual archive.

    .PARAMETER Path
        The path of the file or directory to compress into the backup archive.
        This can be a single file or an entire directory structure.

    .PARAMETER DestinationPath
        The destination directory where the compressed backup file will be created.
        The actual filename is generated automatically based on the source path.

    .PARAMETER NoHash
        Skip hash calculation to improve performance in simple backup scenarios.
        When specified, backup integrity verification will not be available.

    .OUTPUTS
        None. This function creates a .zip file but does not return any objects.

    .NOTES
        - Uses SupportsShouldProcess for WhatIf and Confirm support
        - Automatically generates unique filenames to prevent overwrites
        - Leverages PowerShell's built-in Compress-Archive cmdlet
        - Continues on individual file errors rather than stopping completely

    .EXAMPLE
        PS > Compress-Backup -Path 'C:\Documents' -DestinationPath 'C:\Backups\2025-08-24'

        Creates a backup archive of the Documents folder

    .EXAMPLE
        PS > Compress-Backup -Path 'C:\MyFile.txt' -DestinationPath 'C:\Backups\2025-08-24' -WhatIf

        Shows what would be compressed without actually creating the archive
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationPath,

        [Parameter(Mandatory = $false)]
        [switch] $NoHash
    )

    $generatedBackupPath = New-BackupPath -Path $Path -DestinationPath $DestinationPath
    $detectedPathType = Get-PathType -Path $Path

    if ($PSCmdlet.ShouldProcess("$generatedBackupPath.zip", 'Compress-Archive'))
    {
        Write-Verbose "Compress-Backup> Compressing $($detectedPathType.ToLower()) backup: $generatedBackupPath.zip"

        try
        {
            Compress-Archive -LiteralPath $Path -DestinationPath "$generatedBackupPath.zip" -WhatIf:$WhatIfPreference -ErrorAction Stop

            # Add backup to daily manifest
            if (-not $WhatIfPreference)
            {
                $parentDateDirectoryPath = Split-Path $generatedBackupPath
                Add-BackupToManifest -SourcePath $Path -BackupPath $generatedBackupPath -PathType $detectedPathType -DatePath $parentDateDirectoryPath -NoHash:$NoHash
            }
        }
        catch
        {
            Write-Warning "Compress-Backup> Failed to compress $($detectedPathType.ToLower()) '$Path': $($_.Exception.Message)"
        }
    }
    else
    {
        Write-Verbose "Compress-Backup> Dry-run only, $($detectedPathType.ToLower()) backup '$generatedBackupPath.zip' will not be created"
    }
}
