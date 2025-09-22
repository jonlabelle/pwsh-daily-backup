function New-BackupPath
{
    <#
    .SYNOPSIS
        Generates a unique backup file path from a source path.

    .DESCRIPTION
        Creates a backup file path by transforming the source path into a safe filename.
        Directory separators and drive prefixes are replaced with underscores to create
        a flat naming structure. If a file with the same name already exists, a random
        suffix is automatically appended to ensure uniqueness.

    .PARAMETER Path
        The source file or directory path that will be backed up.
        This path is used to generate the backup filename.

    .PARAMETER DestinationPath
        The destination directory where the backup file will be created.
        This is used to check for existing files and construct the full backup path.

    .OUTPUTS
        [String]
        Returns the full path to the backup file (without the .zip extension).
        The filename will be unique within the destination directory.

    .NOTES
        - Drive prefixes (e.g., 'C:') are removed from the source path
        - Directory separators ('\' and '/') are replaced with double underscores ('__')
        - If the generated path would exceed 255 characters, an error is thrown
        - Duplicate filenames are handled by appending a random suffix

    .EXAMPLE
        PS > New-BackupPath -Path 'C:\Users\John\Documents' -DestinationPath 'C:\Backups\2025-08-24'

        Returns: C:\Backups\2025-08-24\Users__John__Documents

    .EXAMPLE
        PS > New-BackupPath -Path '/home/user/photos' -DestinationPath '/backups/daily'

        Returns: /backups/daily/home__user__photos
    #>
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationPath
    )

    # Removes the drive part (e.g. 'C:')
    $sourcePathWithoutDrivePrefix = (Split-Path -Path $Path -NoQualifier)

    # Handle files vs directories differently for better naming
    if (Test-Path -Path $Path -PathType Leaf)
    {
        # For files, preserve more of the original structure in the name
        $extractedDirectoryPortion = Split-Path -Path $sourcePathWithoutDrivePrefix -Parent
        $extractedFileName = Split-Path -Path $sourcePathWithoutDrivePrefix -Leaf
        $constructedBackupName = if ($extractedDirectoryPortion)
        {
            ($extractedDirectoryPortion -replace '[\\/]', '__') + '__' + $extractedFileName
        }
        else
        {
            $extractedFileName
        }
    }
    else
    {
        # For directories, use existing strategy
        $constructedBackupName = ($sourcePathWithoutDrivePrefix -replace '[\\/]', '__').Trim('__')
    }

    $generatedBackupPath = Join-Path -Path $DestinationPath -ChildPath $constructedBackupName

    if ((Test-Path -Path "$generatedBackupPath.zip"))
    {
        $generatedRandomFileName = (Get-RandomFileName)
        $generatedBackupPath = ('{0}__{1}' -f $generatedBackupPath, $generatedRandomFileName)

        Write-Warning "New-BackupPath> A backup with the same filename '$constructedBackupName.zip' already exists in destination path '$DestinationPath', '$generatedRandomFileName' was automatically appended to the backup filename for uniqueness"
    }

    if ($generatedBackupPath.Length -ge 255)
    {
        Write-Error "New-BackupPath> The backup file path '$generatedBackupPath' is greater than or equal the maximum allowed filename length (255)" -ErrorAction Stop
    }

    return $generatedBackupPath
}
