<#
.SYNOPSIS
    Daily Backup PowerShell Module - Automated file and directory backup solution.

.DESCRIPTION
    The DailyBackup module provides automated backup functionality with date-organized
    storage, automatic cleanup, and comprehensive error handling. It creates compressed
    ZIP archives from specified files and directories, organizing them into folders
    named by date (yyyy-MM-dd format).

    Key Features:
    - Automated daily backup creation with ZIP compression
    - Date-organized folder structure (yyyy-MM-dd)
    - Automatic cleanup of old backups based on retention policies
    - Support for multiple source paths in a single operation
    - Progress reporting for long-running operations
    - WhatIf/ShouldProcess support for safe testing
    - Cloud storage compatibility (OneDrive, iCloud, etc.)
    - Unique filename generation to prevent overwrites

.NOTES
    Module Name: DailyBackup
    Author: Jon LaBelle
    Version: Latest
    Repository: https://github.com/jonlabelle/pwsh-daily-backup

.LINK
    https://github.com/jonlabelle/pwsh-daily-backup
#>

$script:ErrorActionPreference = 'Stop'
$script:ProgressPreference = 'SilentlyContinue'

# -----------------------------------------------
# - Date format: yyyy-mm-dd
# - Date range: 1900-01-01 through 2099-12-31
# - Simple pattern for PowerShell 5.1 compatibility
# -----------------------------------------------
$script:DefaultFolderDateFormat = 'yyyy-MM-dd'
$script:DefaultFolderDateRegex = '^\d{4}-\d{2}-\d{2}$'
# -----------------------------------------------

function GetRandomFileName
{
    <#
    .SYNOPSIS
        Generates a random file name without extension for uniqueness.

    .DESCRIPTION
        Creates a random file name by using the .NET System.IO.Path.GetRandomFileName() method
        and removing the file extension part. This is used internally to ensure backup file
        uniqueness when duplicate names are detected.

    .OUTPUTS
        [String]
        Returns a random filename string without the file extension (e.g., "kdjf3k2j").

    .NOTES
        This is an internal helper function used by GenerateBackupPath to create unique
        backup filenames when duplicates are detected.

    .EXAMPLE
        PS > $randomName = GetRandomFileName

        Returns something like "kdjf3k2j"
    #>
    $randomFileName = [System.IO.Path]::GetRandomFileName()
    return $randomFileName.Substring(0, $randomFileName.IndexOf('.'))
}

function Get-PathType
{
    <#
    .SYNOPSIS
        Determines whether a path represents a file or directory.

    .DESCRIPTION
        Analyzes a given path to determine if it represents a file or directory.
        For existing paths, uses Test-Path with PathType parameter. For non-existing
        paths, attempts to infer the type based on file extension presence.

    .PARAMETER Path
        The path to analyze. Can be existing or non-existing.

    .OUTPUTS
        [String]
        Returns 'File' if the path represents a file, 'Directory' if it represents a directory.

    .NOTES
        This function is used internally to optimize backup naming and compression strategies
        for different path types.

    .EXAMPLE
        PS > Get-PathType -Path 'C:\Users\John\document.txt'
        File

    .EXAMPLE
        PS > Get-PathType -Path 'C:\Users\John\Documents'
        Directory

    .EXAMPLE
        PS > Get-PathType -Path 'C:\NonExistent\file.pdf'
        File
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    if (Test-Path -Path $Path -PathType Leaf)
    {
        return 'File'
    }
    elseif (Test-Path -Path $Path -PathType Container)
    {
        return 'Directory'
    }
    else
    {
        # For non-existent paths, infer from extension
        if ([System.IO.Path]::HasExtension($Path))
        {
            return 'File'
        }
        else
        {
            return 'Directory'
        }
    }
}

function Add-BackupMetadataFile
{
    <#
    .SYNOPSIS
        Adds metadata information to a backup archive.

    .DESCRIPTION
        Creates a metadata file containing information about the original source,
        backup creation time, file attributes, and other relevant details. This
        metadata is stored as a JSON file alongside the backup archive.

    .PARAMETER SourcePath
        The original path that was backed up.

    .PARAMETER BackupPath
        The path to the created backup archive (without .zip extension).

    .PARAMETER PathType
        The type of the source path ('File' or 'Directory').

    .OUTPUTS
        None. Creates a .metadata.json file alongside the backup archive.

    .NOTES
        This function helps preserve important information about backed up items
        for potential restoration or auditing purposes.

    .EXAMPLE
        PS > Add-BackupMetadataFile -SourcePath 'C:\Documents\report.pdf' -BackupPath 'C:\Backups\2025-09-15\Documents__report.pdf' -PathType 'File'

        Creates C:\Backups\2025-09-15\Documents__report.pdf.metadata.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [string] $BackupPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('File', 'Directory')]
        [string] $PathType
    )

    try
    {
        $metadata = @{
            SourcePath = $SourcePath
            BackupCreated = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
            PathType = $PathType
            BackupVersion = '2.0'
        }

        if (Test-Path -Path $SourcePath)
        {
            $item = Get-Item -Path $SourcePath
            $metadata.OriginalName = $item.Name
            $metadata.LastWriteTime = $item.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $metadata.Attributes = $item.Attributes.ToString()

            if ($PathType -eq 'File')
            {
                $metadata.Size = $item.Length
                $metadata.Extension = $item.Extension
            }
        }

        $metadataPath = "$BackupPath.metadata.json"
        $metadata | ConvertTo-Json -Depth 3 | Out-File -FilePath $metadataPath -Encoding UTF8
        Write-Verbose "New-DailyBackup:Add-BackupMetadataFile> Metadata saved to: $metadataPath"
    }
    catch
    {
        Write-Warning "New-DailyBackup:Add-BackupMetadataFile> Failed to create metadata for $SourcePath : $_"
    }
}

function GenerateBackupPath
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
        PS > GenerateBackupPath -Path 'C:\Users\John\Documents' -DestinationPath 'C:\Backups\2025-08-24'

        Returns: C:\Backups\2025-08-24\Users__John__Documents

    .EXAMPLE
        PS > GenerateBackupPath -Path '/home/user/photos' -DestinationPath '/backups/daily'

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
    $pathWithoutPrefix = (Split-Path -Path $Path -NoQualifier)

    # Handle files vs directories differently for better naming
    if (Test-Path -Path $Path -PathType Leaf)
    {
        # For files, preserve more of the original structure in the name
        $directory = Split-Path -Path $pathWithoutPrefix -Parent
        $fileName = Split-Path -Path $pathWithoutPrefix -Leaf
        $backupName = if ($directory)
        {
            ($directory -replace '[\\/]', '__') + '__' + $fileName
        }
        else
        {
            $fileName
        }
    }
    else
    {
        # For directories, use existing strategy
        $backupName = ($pathWithoutPrefix -replace '[\\/]', '__').Trim('__')
    }

    $backupPath = Join-Path -Path $DestinationPath -ChildPath $backupName

    if ((Test-Path -Path "$backupPath.zip"))
    {
        $randomFileName = (GetRandomFileName)
        $backupPath = ('{0}__{1}' -f $backupPath, $randomFileName)

        Write-Warning ("New-DailyBackup:GenerateBackupPath> A backup with the same filename '{0}' already exists in destination path '{1}', '{2}' was automatically appended to the backup filename for uniqueness" -f "$backupName.zip", $DestinationPath, $randomFileName)
    }

    if ($backupPath.Length -ge 255)
    {
        Write-Error ('New-DailyBackup:GenerateBackupPath> The backup file path ''{0}'' is greater than or equal the maximum allowed filename length (255)' -f $backupPath) -ErrorAction Stop
    }

    return $backupPath
}

function CompressBackup
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
        PS > CompressBackup -Path 'C:\Documents' -DestinationPath 'C:\Backups\2025-08-24' -VerboseEnabled $true

        Creates a backup archive of the Documents folder with verbose output

    .EXAMPLE
        PS > CompressBackup -Path 'C:\MyFile.txt' -DestinationPath 'C:\Backups\2025-08-24' -WhatIf

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
        [bool] $VerboseEnabled = $false
    )

    $backupPath = GenerateBackupPath -Path $Path -DestinationPath $DestinationPath
    $pathType = Get-PathType -Path $Path

    if ($PSCmdlet.ShouldProcess("$backupPath.zip", 'Compress-Archive'))
    {
        Write-Verbose ('New-DailyBackup:CompressBackup> Compressing {0} backup ''{1}''' -f $pathType.ToLower(), "$backupPath.zip")
        Compress-Archive -LiteralPath $Path -DestinationPath "$backupPath.zip" -WhatIf:$WhatIfPreference -Verbose:$VerboseEnabled -ErrorAction Continue

        # Add metadata file for better backup tracking
        if (-not $WhatIfPreference)
        {
            Add-BackupMetadataFile -SourcePath $Path -BackupPath $backupPath -PathType $pathType
        }
    }
    else
    {
        Write-Verbose ('New-DailyBackup:CompressBackup> Dry-run only, {0} backup ''{1}'' will not be created' -f $pathType.ToLower(), "$backupPath.zip")
    }
}

function ResolveUnverifiedPath
{
    <#
    .SYNOPSIS
        Resolves file paths whether they exist or not, unlike Resolve-Path.

    .DESCRIPTION
        A wrapper around PowerShell's Resolve-Path cmdlet that handles both existing
        and non-existing paths gracefully. While Resolve-Path throws an exception for
        non-existing paths, this function returns the resolved path string regardless
        of whether the path exists on the filesystem.

    .PARAMETER Path
        The path to resolve. Can be relative or absolute, existing or non-existing.
        Supports pipeline input for processing multiple paths.

    .INPUTS
        [String]
        Path string that can be piped to this function.

    .OUTPUTS
        [String]
        The fully resolved path string. For existing paths, returns the provider path.
        For non-existing paths, returns the resolved target path that would exist.

    .NOTES
        This function was originally from the PowerShellForGitHub module.
        It's particularly useful for backup operations where destination paths
        may not exist yet but need to be resolved for path construction.

    .EXAMPLE
        PS > ResolveUnverifiedPath -Path 'c:\windows\notepad.exe'

        Returns: C:\Windows\notepad.exe (if it exists)

    .EXAMPLE
        PS > ResolveUnverifiedPath -Path '..\notepad.exe'

        Returns: C:\Windows\notepad.exe (resolved relative to current directory)

    .EXAMPLE
        PS > ResolveUnverifiedPath -Path '..\nonexistent.txt'

        Returns: C:\Windows\nonexistent.txt (resolved even though file doesn't exist)

    .EXAMPLE
        PS > 'file1.txt', 'file2.txt' | ResolveUnverifiedPath

        Resolves multiple paths from pipeline input

    .LINK
        https://aka.ms/PowerShellForGitHub
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string] $Path
    )

    process
    {
        $resolvedPath = Resolve-Path -Path $Path -ErrorVariable resolvePathError -ErrorAction SilentlyContinue

        if ($null -eq $resolvedPath)
        {
            Write-Output -InputObject ($resolvePathError[0].TargetObject)
        }
        else
        {
            Write-Output -InputObject ($resolvedPath.ProviderPath)
        }
    }
}

function RemoveItemAlternative
{
    <#
    .SYNOPSIS
        Removes files and folders using an alternative method for cloud storage compatibility.

    .DESCRIPTION
        Removes all files and folders within a specified path using the .NET Delete() methods
        instead of PowerShell's Remove-Item cmdlet. This approach resolves access denied issues
        commonly encountered when deleting items from cloud-synced folders like Apple iCloud,
        Microsoft OneDrive, or Google Drive. The function supports ShouldProcess for safe testing.

    .PARAMETER LiteralPath
        The path to the directory to remove. The value is used exactly as typed without
        wildcard interpretation. If the path contains escape characters, enclose it in
        single quotes to prevent PowerShell from interpreting them as escape sequences.

    .PARAMETER SkipTopLevelFolder
        When specified, only the contents of the folder are deleted, leaving the top-level
        folder intact. This is useful when you want to clear a directory but keep the
        folder structure.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        None. This function does not return any objects.

    .NOTES
        - Uses SupportsShouldProcess for WhatIf and Confirm support
        - Specifically designed to work with cloud storage providers (iCloud, OneDrive)
        - Falls back to .NET Delete() methods when PowerShell Remove-Item fails
        - Processes files first, then directories, then the root folder if not skipped
        - Continues processing even if individual items fail to delete

    .EXAMPLE
        PS > RemoveItemAlternative -LiteralPath "C:\Users\John\OneDrive\OldBackups"

        Removes the entire OldBackups folder and all its contents

    .EXAMPLE
        PS > RemoveItemAlternative -LiteralPath "C:\Users\John\iCloud\TempFiles" -SkipTopLevelFolder

        Clears the TempFiles folder contents but keeps the folder itself

    .EXAMPLE
        PS > RemoveItemAlternative -LiteralPath "C:\CloudFolder\Data" -WhatIf

        Shows what would be deleted without actually removing anything

    .LINK
        https://evotec.xyz/remove-item-access-to-the-cloud-file-is-denied-while-deleting-files-from-onedrive/

    .LINK
        https://jonlabelle.com/snippets/view/powershell/powershell-remove-item-access-denied-fix
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]
        $LiteralPath,

        [Parameter()]
        [switch]
        $SkipTopLevelFolder
    )

    if ($LiteralPath -and (Test-Path -LiteralPath $LiteralPath))
    {
        $items = Get-ChildItem -LiteralPath $LiteralPath -Recurse
        foreach ($item in $items)
        {
            if ($item.PSIsContainer -eq $false)
            {
                try
                {
                    if ($PSCmdlet.ShouldProcess($item.Name))
                    {
                        $item.Delete()
                    }
                }
                catch
                {
                    Write-Warning "New-DailyBackup:RemoveItemAlternative> Couldn't delete $($item.FullName), error: $($_.Exception.Message)"
                }
            }
        }

        $items = Get-ChildItem -LiteralPath $LiteralPath -Recurse
        foreach ($item in $items)
        {
            try
            {
                if ($PSCmdlet.ShouldProcess($item.Name))
                {
                    $item.Delete()
                }
            }
            catch
            {
                Write-Warning "New-DailyBackup:RemoveItemAlternative> Couldn't delete '$($item.FullName)', Error: $($_.Exception.Message)"
            }
        }

        if (-not $SkipTopLevelFolder)
        {
            $item = Get-Item -LiteralPath $LiteralPath
            try
            {
                if ($PSCmdlet.ShouldProcess($item.Name))
                {
                    $item.Delete($true)
                }
            }
            catch
            {
                Write-Warning "New-DailyBackup:RemoveItemAlternative> Couldn't delete '$($item.FullName)', Error: $($_.Exception.Message)"
            }
        }
    }
    else
    {
        Write-Warning "New-DailyBackup:RemoveItemAlternative> Path '$LiteralPath' doesn't exist. Skipping."
    }
}

function RemoveDailyBackup
{
    <#
    .SYNOPSIS
        Removes old daily backup directories while keeping a specified number of recent backups.

    .DESCRIPTION
        Cleans up old daily backup directories by deleting the oldest backup folders first,
        while preserving a specified minimum number of recent backups. Only directories with
        date-formatted names (yyyy-MM-dd pattern) are considered for deletion. The function
        supports ShouldProcess for safe testing and will skip deletion if the number of
        existing backups doesn't exceed the retention limit.

    .PARAMETER Path
        The root directory path where daily backup folders are stored. This should be
        the parent directory containing date-named subdirectories (e.g., '2025-08-24').

    .PARAMETER BackupsToKeep
        The minimum number of backup directories to retain. Older backups beyond this
        number will be deleted. Must be a positive integer.

    .PARAMETER VerboseEnabled
        Controls whether verbose output is displayed during the cleanup operation.
        When $true, detailed information about the deletion process is shown.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        None. This function does not return any objects.

    .NOTES
        - Only directories matching the yyyy-MM-dd date pattern are processed
        - Backups are sorted by date (parsed from folder name) before deletion
        - Uses SupportsShouldProcess for WhatIf and Confirm support
        - Continues operation even if individual directory deletions fail
        - Skips cleanup if total backups don't exceed the retention limit

    .EXAMPLE
        PS > RemoveDailyBackup -Path 'C:\Backups' -BackupsToKeep 7 -VerboseEnabled $true

        Keeps the 7 most recent daily backup folders, removes older ones

    .EXAMPLE
        PS > RemoveDailyBackup -Path '/home/user/backups' -BackupsToKeep 3 -WhatIf

        Shows which backup directories would be deleted without actually removing them

    .EXAMPLE
        PS > RemoveDailyBackup -Path 'C:\DailyBackups' -BackupsToKeep 14

        Maintains a 2-week retention policy (14 days) for backup directories
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int] $BackupsToKeep,

        [Parameter(Mandatory = $false)]
        [bool] $VerboseEnabled = $false
    )

    $qualifiedBackupDirs = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction 'SilentlyContinue' | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' })
    if ($qualifiedBackupDirs.Length -eq 0)
    {
        Write-Verbose ('New-DailyBackup:RemoveDailyBackup> No qualified backup directories to delete were detected in: {0}' -f $Path) -Verbose:$VerboseEnabled
        return
    }

    # Create a hashtable so we can sort backup directories based on their date-formatted folder name ('yyyy-MM-dd')
    $backups = @{ }
    foreach ($backupDir in $qualifiedBackupDirs)
    {
        $backups.Add($backupDir.FullName, [System.DateTime]$backupDir.Name)
    }

    $sortedBackupPaths = ($backups.GetEnumerator() | Sort-Object -Property Value | ForEach-Object { $_.Key })
    if ($sortedBackupPaths.Count -gt $BackupsToKeep)
    {
        for ($i = 0; $i -lt ($sortedBackupPaths.Count - $BackupsToKeep); $i++)
        {
            $backupPath = $sortedBackupPaths[$i]
            if ($PSCmdlet.ShouldProcess($backupPath, 'Remove backup directory'))
            {
                Write-Verbose ('New-DailyBackup:RemoveDailyBackup> Removing old backup directory: {0}' -f $backupPath) -Verbose:$VerboseEnabled
                RemoveItemAlternative -LiteralPath $backupPath -WhatIf:$WhatIfPreference -Verbose:$VerboseEnabled
                Write-Verbose ('New-DailyBackup:RemoveDailyBackup> Successfully removed: {0}' -f $backupPath) -Verbose:$VerboseEnabled
            }
        }
    }
    else
    {
        Write-Verbose 'New-DailyBackup:RemoveDailyBackup> No surplus daily backups to delete' -Verbose:$VerboseEnabled
    }
}

function New-DailyBackup
{
    <#
    .SYNOPSIS
        Creates daily backups by compressing files and directories into date-organized ZIP archives.

    .DESCRIPTION
        Creates compressed backup archives (.zip) from specified files and directories,
        organizing them into date-stamped folders (yyyy-MM-dd format). The function supports
        multiple source paths, automatic cleanup of old backups, progress reporting, and
        WhatIf/ShouldProcess for safe testing. Each source path is compressed into a separate
        ZIP file with automatically generated unique names.

    .PARAMETER Path
        One or more source file or directory paths to backup. Supports pipeline input,
        relative paths (resolved from current directory), and wildcard patterns.
        Each path will be compressed into a separate ZIP archive.

    .PARAMETER Destination
        The root directory where daily backup folders will be created. A subdirectory
        named with today's date (yyyy-MM-dd) will be created to store the backup archives.
        Defaults to the current working directory if not specified.

    .PARAMETER Keep
        The number of daily backup folders to retain when cleaning up old backups.
        Older backup folders beyond this number will be automatically deleted.
        Set to -1 (default) to disable automatic cleanup and keep all backups.
        Set to 0 to delete all existing backups. Must be -1 or greater.

        Note: DailyBackupsToKeep is an alias for this parameter.

    .PARAMETER FileBackupMode
        Controls how individual files are handled during backup operations:
        - Individual: Each file gets its own ZIP archive (default for single files)
        - Combined: All files are placed into a single archive per backup session
        - Auto: Smart decision based on file count and sizes (default)

        This parameter provides flexibility for different backup scenarios and helps
        optimize storage and organization of file-based backups.

    .INPUTS
        [String[]]
        File or directory paths can be piped to this function. Supports pipeline input
        from Get-ChildItem, Get-Item, or any command that outputs path strings.

    .OUTPUTS
        None. This function creates backup files but does not return objects.
        Progress information is displayed during operation.

    .NOTES
        - Supports both individual files and entire directories
        - Enhanced file handling with improved naming and metadata preservation
        - Supports ShouldProcess for WhatIf and Confirm scenarios
        - Creates date-stamped subdirectories (yyyy-MM-dd format)
        - Generates unique backup filenames to prevent overwrites
        - Automatically detects file vs directory types for optimized handling
        - Creates metadata files (.metadata.json) alongside backups for tracking
        - Automatically resolves relative paths from current directory
        - Continues processing remaining paths if individual items fail
        - Uses cloud-storage-compatible deletion methods for cleanup
        - Displays progress bar for multiple source paths

    .EXAMPLE
        PS > New-DailyBackup -Path 'C:\Documents' -Destination 'D:\Backups'

        Creates a backup of Documents folder in D:\Backups\2025-09-15\

    .EXAMPLE
        PS > New-DailyBackup -Path 'C:\report.pdf' -Destination 'D:\Backups'

        Creates a backup of a single file in D:\Backups\2025-09-15\report.pdf.zip

    .EXAMPLE
        PS > New-DailyBackup -Path 'file1.txt', 'C:\Photos', 'D:\Projects' -Destination 'E:\DailyBackups' -Verbose

        Backs up multiple files and directories with detailed output and metadata

    .EXAMPLE
        PS > New-DailyBackup -Path 'C:\Data' -Destination 'D:\Backups' -Keep 7

        Creates backup and keeps only the last 7 days of backups

    .EXAMPLE
        PS > New-DailyBackup -Path 'C:\ImportantFiles' -WhatIf

        Shows what would be backed up without actually creating archives

    .EXAMPLE
        PS > Get-ChildItem 'C:\Projects' -Directory | New-DailyBackup -Destination 'D:\ProjectBackups'

        Backs up all subdirectories from C:\Projects using pipeline input

    .EXAMPLE
        PS > New-DailyBackup -Path '*.pdf', '*.docx' -Destination 'D:\DocumentBackups' -FileBackupMode Combined

        Backs up all PDF and Word documents into a single combined archive per backup session

    .EXAMPLE
        PS > New-DailyBackup -Path '.\src', '.\docs' -Destination '\\server\backups' -Keep 14

        Backs up relative paths to network location with 2-week retention

    .LINK
        https://github.com/jonlabelle/pwsh-daily-backup
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            Position = 0,
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true,
            HelpMessage = 'The source file or directory path(s) to backup.')
        ]
        [Alias('PSPath', 'FullName', 'SourcePath')]
        [string[]] $Path,

        [Parameter(
            Position = 1,
            HelpMessage = 'The root directory path where daily backups will be stored.')
        ]
        [Alias('DestinationPath', 'TargetPath')]
        [string] $Destination = '.',

        [Parameter(
            HelpMessage = 'The number of daily backups to keep when purging old backups.'
        )]
        [ValidateRange(-1, [int]::MaxValue)]
        [Alias('DailyBackupsToKeep')]
        [int] $Keep = -1,

        [Parameter(
            HelpMessage = 'Controls how individual files are handled during backup operations.'
        )]
        [ValidateSet('Individual', 'Combined', 'Auto')]
        [string] $FileBackupMode = 'Auto'
    )
    begin
    {
        $verboseEnabled = $false
        if ($VerbosePreference -eq 'Continue')
        {
            $verboseEnabled = $true
            Write-Verbose 'New-DailyBackup:Begin> Verbose mode is enabled' -Verbose:$verboseEnabled
        }

        if ($PSCmdlet.ShouldProcess('New-DailyBackup', 'Begin'))
        {
            Write-Verbose 'New-DailyBackup:Begin> Dry-run is not enabled' -Verbose:$verboseEnabled
        }
        else
        {
            Write-Verbose 'New-DailyBackup:Begin> Dry-run is enabled' -Verbose:$verboseEnabled
        }

        $Destination = ResolveUnverifiedPath -Path $Destination
        $folderName = (Get-Date -Format $script:DefaultFolderDateFormat)
        $datedDestinationDir = (Join-Path -Path $Destination -ChildPath $folderName)

        if ((Test-Path -Path $datedDestinationDir -PathType Container))
        {
            Write-Verbose ('New-DailyBackup:Begin> Removing existing backup destination directory: {0}' -f $datedDestinationDir) -Verbose:$verboseEnabled
            RemoveItemAlternative -LiteralPath $datedDestinationDir -WhatIf:$WhatIfPreference -Verbose:$verboseEnabled
        }

        Write-Verbose ('New-DailyBackup:Begin> Creating backup destination directory: {0}' -f $datedDestinationDir) -Verbose:$verboseEnabled
        New-Item -Path $datedDestinationDir -ItemType Directory -WhatIf:$WhatIfPreference -Verbose:$verboseEnabled -ErrorAction 'SilentlyContinue' | Out-Null
    }
    process
    {
        $totalPaths = $Path.Count
        $currentPath = 0

        foreach ($item in $Path)
        {
            $currentPath++
            Write-Progress -Activity 'Creating Daily Backup' -Status "Processing path $currentPath of $totalPaths" -PercentComplete (($currentPath / $totalPaths) * 100)

            if (-not [System.IO.Path]::IsPathRooted($item))
            {
                Write-Verbose ('New-DailyBackup:Process> {0} is not a full path, prepending current directory: {1}' -f $item, $pwd) -Verbose:$verboseEnabled
                $item = (Join-Path -Path $pwd -ChildPath $item)
            }

            try
            {
                $resolvedPath = (Resolve-Path $item -ErrorAction SilentlyContinue -Verbose:$verboseEnabled).ProviderPath
                if ($null -eq $resolvedPath)
                {
                    Write-Warning ('New-DailyBackup:Process> Failed to resolve path for: {0}' -f $item)
                    continue
                }

                if ($resolvedPath.Count -gt 1)
                {
                    foreach ($globItem in $resolvedPath)
                    {
                        Write-Verbose ('New-DailyBackup:Process> Processing glob item: {0}' -f $globItem) -Verbose:$verboseEnabled
                        CompressBackup -Path $globItem -DestinationPath $datedDestinationDir -VerboseEnabled $verboseEnabled -WhatIf:$WhatIfPreference
                    }
                }
                else
                {
                    if (!(Test-Path -Path $resolvedPath -IsValid))
                    {
                        Write-Warning ('New-DailyBackup:Process> Backup source path does not exist: {0}' -f $resolvedPath)
                    }
                    else
                    {
                        Write-Verbose ('New-DailyBackup:Process> Processing single item: {0}' -f $resolvedPath) -Verbose:$verboseEnabled
                        CompressBackup -Path $resolvedPath -DestinationPath $datedDestinationDir -VerboseEnabled $verboseEnabled -WhatIf:$WhatIfPreference
                    }
                }
            }
            catch
            {
                Write-Error ('New-DailyBackup:Process> Error processing path {0}: {1}' -f $item, $_.Exception.Message) -ErrorAction Continue
            }
        }

        Write-Progress -Activity 'Creating Daily Backup' -Completed
    }
    end
    {
        Write-Verbose 'New-DailyBackup:End> Running post backup operations' -Verbose:$verboseEnabled

        if ($Keep -ge 0)
        {
            RemoveDailyBackup -Path $Destination -BackupsToKeep $Keep -VerboseEnabled $verboseEnabled -WhatIf:$WhatIfPreference
        }

        Write-Verbose 'New-DailyBackup:End> Finished' -Verbose:$verboseEnabled
    }
}

function Get-BackupInfo
{
    <#
    .SYNOPSIS
        Retrieves information about available backups in a backup directory.

    .DESCRIPTION
        Scans a backup directory structure to find available backups, organized by date.
        Returns detailed information about each backup including metadata, file types,
        and backup dates. This function is used internally by Restore-DailyBackup
        and can also be used independently to browse available backups.

    .PARAMETER BackupRoot
        The root directory containing daily backup folders (yyyy-MM-dd format).

    .PARAMETER Date
        Optional. Specific date to retrieve backup information for (yyyy-MM-dd format).
        If not specified, returns information for all available backup dates.

    .OUTPUTS
        [PSCustomObject[]]
        Returns an array of backup information objects containing:
        - Date: Backup date (yyyy-MM-dd)
        - Path: Full path to the backup directory
        - Backups: Array of individual backup files with metadata
        - TotalSize: Total size of all backups for that date
        - BackupCount: Number of individual backup files

    .NOTES
        This function helps users understand what backups are available before
        performing restore operations.

    .EXAMPLE
        PS > Get-BackupInfo -BackupRoot 'D:\Backups'

        Lists all available backup dates and their contents

    .EXAMPLE
        PS > Get-BackupInfo -BackupRoot 'D:\Backups' -Date '2025-09-15'

        Shows detailed information for backups from September 15, 2025
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupRoot,

        [Parameter()]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $Date
    )

    if (-not (Test-Path -Path $BackupRoot -PathType Container))
    {
        Write-Warning "Backup root directory not found: $BackupRoot"
        return @()
    }

    $backupDates = if ($Date)
    {
        $matchedDirs = Get-ChildItem -Path $BackupRoot -Directory -Name | Where-Object { $_ -eq $Date }
        if ($matchedDirs) { @($matchedDirs) } else { @() }
    }
    else
    {
        $matchedDirs = Get-ChildItem -Path $BackupRoot -Directory -Name | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Descending
        if ($matchedDirs) { @($matchedDirs) } else { @() }
    }

    $results = @()
    foreach ($dateFolder in $backupDates)
    {
        if (-not $dateFolder) { continue }

        $datePath = Join-Path $BackupRoot $dateFolder
        if (-not (Test-Path $datePath -PathType Container)) { continue }

        $zipFiles = @(Get-ChildItem -Path $datePath -Filter '*.zip')
        $metadataFiles = @(Get-ChildItem -Path $datePath -Filter '*.metadata.json')

        $backups = @()
        foreach ($zipFile in $zipFiles)
        {
            $baseName = $zipFile.BaseName
            $metadataPath = Join-Path $datePath "$baseName.metadata.json"

            $backupInfo = [PSCustomObject]@{
                Name = $zipFile.Name
                Path = $zipFile.FullName
                Size = $zipFile.Length
                Created = $zipFile.CreationTime
                Metadata = $null
            }

            if (Test-Path $metadataPath)
            {
                try
                {
                    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
                    $backupInfo.Metadata = $metadata
                }
                catch
                {
                    Write-Warning "Failed to read metadata for $($zipFile.Name): $_"
                }
            }

            $backups += $backupInfo
        }

        $totalSize = ($zipFiles | Measure-Object -Property Length -Sum).Sum

        $results += [PSCustomObject]@{
            Date = $dateFolder
            Path = $datePath
            Backups = $backups
            TotalSize = $totalSize
            BackupCount = $zipFiles.Count
            MetadataCount = $metadataFiles.Count
        }
    }

    # Ensure we always return an array for PowerShell 5.1 compatibility
    if (-not $results) {
        Write-Output @() -NoEnumerate
    } elseif ($results.Count -eq 0) {
        Write-Output @() -NoEnumerate
    } else {
        Write-Output @($results) -NoEnumerate
    }
}

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

function Restore-DailyBackup
{
    <#
    .SYNOPSIS
        Restores files and directories from daily backup archives.

    .DESCRIPTION
        Restores backed up files and directories from compressed ZIP archives created
        by New-DailyBackup. Supports restoring specific backups by date, individual
        files by name pattern, or entire backup sets. Can restore to original locations
        using metadata or to custom destinations.

    .PARAMETER BackupRoot
        The root directory containing daily backup folders (yyyy-MM-dd format).
        This should be the same directory used as -Destination in New-DailyBackup.

    .PARAMETER DestinationPath
        The destination directory where restored files will be placed.
        If not specified and -UseOriginalPaths is enabled, attempts to restore
        to original source locations using metadata.

    .PARAMETER Date
        Specific backup date to restore from (yyyy-MM-dd format).
        If not specified, uses the most recent backup date available.

    .PARAMETER BackupName
        Optional pattern to match specific backup files by name.
        Supports wildcards (e.g., "*Documents*", "*.pdf*").
        If not specified, restores all backups from the specified date.

    .PARAMETER UseOriginalPaths
        When enabled, attempts to restore files to their original source locations
        using metadata information. Requires metadata files to be present.
        When disabled, restores all files to the specified DestinationPath.

    .PARAMETER PreservePaths
        Controls whether directory structure within backups is preserved during
        restoration. When enabled, maintains folder hierarchy from the backup.

    .PARAMETER Force
        Overwrites existing files during restoration without prompting.
        Use with caution as this can replace current files.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        [PSCustomObject[]]
        Returns an array of restore operation results, including success status,
        paths processed, and any errors encountered for each backup file.

    .NOTES
        - Requires backup files created by New-DailyBackup with version 2.0+ metadata
        - Supports ShouldProcess for WhatIf and Confirm scenarios
        - Automatically handles file timestamp and attribute restoration when possible
        - Creates destination directories as needed
        - Provides detailed progress reporting for multiple files

    .EXAMPLE
        PS > Restore-DailyBackup -BackupRoot 'D:\Backups' -DestinationPath 'C:\Restored'

        Restores the most recent backup set to C:\Restored

    .EXAMPLE
        PS > Restore-DailyBackup -BackupRoot 'D:\Backups' -Date '2025-09-15' -UseOriginalPaths

        Restores backups from September 15, 2025 to their original source locations

    .EXAMPLE
        PS > Restore-DailyBackup -BackupRoot 'D:\Backups' -BackupName '*Documents*' -DestinationPath 'C:\Restored'

        Restores only backup files matching "*Documents*" pattern

    .EXAMPLE
        PS > Restore-DailyBackup -BackupRoot 'D:\Backups' -Date '2025-09-10' -WhatIf

        Shows what would be restored without actually performing the restoration

    .EXAMPLE
        PS > Restore-DailyBackup -BackupRoot '\\server\backups' -DestinationPath 'C:\Emergency' -Force

        Restores from network backup location, overwriting existing files

    .LINK
        New-DailyBackup
        Get-BackupInfo
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The root directory containing daily backup folders.'
        )]
        [ValidateNotNullOrEmpty()]
        [string] $BackupRoot,

        [Parameter(
            HelpMessage = 'The destination directory where restored files will be placed.'
        )]
        [string] $DestinationPath,

        [Parameter(
            HelpMessage = 'Specific backup date to restore from (yyyy-MM-dd format).'
        )]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $Date,

        [Parameter(
            HelpMessage = 'Pattern to match specific backup files by name (supports wildcards).'
        )]
        [string] $BackupName,

        [Parameter(
            HelpMessage = 'Restore files to their original source locations using metadata.'
        )]
        [switch] $UseOriginalPaths,

        [Parameter(
            HelpMessage = 'Preserve directory structure within backups during restoration.'
        )]
        [switch] $PreservePaths,

        [Parameter(
            HelpMessage = 'Overwrite existing files during restoration without prompting.'
        )]
        [switch] $Force
    )

    begin
    {
        $verboseEnabled = ($VerbosePreference -eq 'Continue')

        if (-not $UseOriginalPaths -and -not $DestinationPath)
        {
            throw 'Either DestinationPath must be specified or UseOriginalPaths must be enabled'
        }

        if (-not (Test-Path $BackupRoot -PathType Container))
        {
            throw "Backup root directory not found: $BackupRoot"
        }

        Write-Verbose "Restore-DailyBackup:Begin> Starting restore operation from $BackupRoot"
    }

    process
    {
        $backupInfo = Get-BackupInfo -BackupRoot $BackupRoot
        if ($Date)
        {
            $backupInfo = $backupInfo | Where-Object { $_.Date -eq $Date }
        }

        if ($backupInfo.Count -eq 0)
        {
            Write-Warning "No backups found in $BackupRoot$(if ($Date) { " for date $Date" })"
            return @()
        }

        # Use most recent backup if no date specified
        if (-not $Date)
        {
            $selectedBackup = $backupInfo | Sort-Object Date -Descending | Select-Object -First 1
            Write-Verbose "Restore-DailyBackup> Using most recent backup from $($selectedBackup.Date)"
        }
        else
        {
            $selectedBackup = $backupInfo | Where-Object { $_.Date -eq $Date } | Select-Object -First 1
            if (-not $selectedBackup)
            {
                throw "No backup found for date: $Date"
            }
        }

        # Filter backups by name pattern if specified
        $backupsToRestore = @(if ($BackupName)
            {
                $selectedBackup.Backups | Where-Object { $_.Name -like $BackupName }
            }
            else
            {
                $selectedBackup.Backups
            })

        if ($backupsToRestore.Count -eq 0)
        {
            Write-Warning 'No backup files match the specified criteria'
            return @()
        }

        Write-Host "Found $($backupsToRestore.Count) backup file(s) to restore from $($selectedBackup.Date)" -ForegroundColor Green

        # Process each backup file
        $results = @()
        $totalBackups = $backupsToRestore.Count
        $currentBackup = 0

        foreach ($backup in $backupsToRestore)
        {
            $currentBackup++
            Write-Progress -Activity 'Restoring Daily Backups' -Status "Restoring backup $currentBackup of $totalBackups" -PercentComplete (($currentBackup / $totalBackups) * 100)

            try
            {
                $restoreParams = @{
                    BackupFilePath = $backup.Path
                    UseOriginalPath = $UseOriginalPaths
                    PreservePaths = $PreservePaths
                    VerboseEnabled = $verboseEnabled
                }

                if ($DestinationPath)
                {
                    $restoreParams.DestinationPath = $DestinationPath
                }

                if ($Force)
                {
                    $restoreParams.Force = $true
                }

                $result = Restore-BackupFile @restoreParams
                $results += $result

                if ($result.Success)
                {
                    Write-Host "[SUCCESS] $($result.Message)" -ForegroundColor Green
                }
                else
                {
                    Write-Warning "[FAILED] $($result.Message)"
                }
            }
            catch
            {
                $errorResult = [PSCustomObject]@{
                    Success = $false
                    SourcePath = $backup.Path
                    DestinationPath = $DestinationPath
                    Metadata = $backup.Metadata
                    Message = "Failed to restore $($backup.Name): $_"
                }
                $results += $errorResult
                Write-Error $errorResult.Message -ErrorAction Continue
            }
        }

        Write-Progress -Activity 'Restoring Daily Backups' -Completed
    }

    end
    {
        $successfulResults = @($results | Where-Object { $_.Success })
        $successCount = $successfulResults.Count
        $totalCount = $results.Count

        Write-Host "`nRestore Summary:" -ForegroundColor Cyan
        Write-Host "   Successful: $successCount" -ForegroundColor Green
        Write-Host "   Failed: $($totalCount - $successCount)" -ForegroundColor Red
        Write-Host "   Total: $totalCount" -ForegroundColor Blue

        Write-Verbose 'Restore-DailyBackup:End> Restore operation completed'
        return $results
    }
}

Export-ModuleMember -Function New-DailyBackup, Restore-DailyBackup, Get-BackupInfo
