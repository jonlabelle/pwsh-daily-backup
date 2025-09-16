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

    .PARAMETER VerboseEnabled
        Controls whether verbose output is displayed during the compression operation.
        When $true, detailed progress information is shown.

    .OUTPUTS
        None. This function creates a .zip file but does not return any objects.

    .NOTES
        - Uses SupportsShouldProcess for WhatIf and Confirm support
        - Automatically generates unique filenames to prevent overwrites
        - Leverages PowerShell's built-in Compress-Archive cmdlet
        - Continues on individual file errors rather than stopping completely

    .EXAMPLE
        PS > Compress-Backup -Path 'C:\Documents' -DestinationPath 'C:\Backups\2025-08-24' -VerboseEnabled $true

        Creates a backup archive of the Documents folder with verbose output

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
        [bool] $VerboseEnabled = $false,

        [Parameter(Mandatory = $false)]
        [switch] $NoHash
    )

    $backupPath = New-BackupPath -Path $Path -DestinationPath $DestinationPath
    $pathType = Get-PathType -Path $Path

    if ($PSCmdlet.ShouldProcess("$backupPath.zip", 'Compress-Archive'))
    {
        Write-Verbose ('New-DailyBackup:Compress-Backup> Compressing {0} backup ''{1}''' -f $pathType.ToLower(), "$backupPath.zip")

        try
        {
            Compress-Archive -LiteralPath $Path -DestinationPath "$backupPath.zip" -WhatIf:$WhatIfPreference -Verbose:$VerboseEnabled -ErrorAction Stop

            # Add backup to consolidated daily manifest
            if (-not $WhatIfPreference)
            {
                $datePath = Split-Path $backupPath
                Add-BackupToManifest -SourcePath $Path -BackupPath $backupPath -PathType $pathType -DatePath $datePath -NoHash:$NoHash
            }
        }
        catch
        {
            Write-Warning ('New-DailyBackup:Compress-Backup> Failed to compress {0} ''{1}'': {2}' -f $pathType.ToLower(), $Path, $_.Exception.Message)
        }
    }
    else
    {
        Write-Verbose ('New-DailyBackup:Compress-Backup> Dry-run only, {0} backup ''{1}'' will not be created' -f $pathType.ToLower(), "$backupPath.zip")
    }
}
