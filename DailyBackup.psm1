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
# - Matches invalid dates such as February 31st
# - Accepts dashes, forward slashes and dots as date separators.
# -----------------------------------------------
$script:DefaultFolderDateFormat = 'yyyy-MM-dd'
$script:DefaultFolderDateRegex = '\b(19|20)[0-9]{2}[-/.](0[1-9]|1[012])[-/.](0[1-9]|[12][0-9]|3[01])\b'
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

    # replace directory separators with underscores
    $backupName = ($pathWithoutPrefix -replace '[\\/]', '__').Trim('__')

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

    if ($PSCmdlet.ShouldProcess("$backupPath.zip", 'Compress-Archive'))
    {
        Write-Verbose ('New-DailyBackup:CompressBackup> Compressing backup ''{0}''' -f "$backupPath.zip")
        Compress-Archive -LiteralPath $Path -DestinationPath "$backupPath.zip" -WhatIf:$WhatIfPreference -Verbose:$VerboseEnabled -ErrorAction Continue
    }
    else
    {
        Write-Verbose ('New-DailyBackup:CompressBackup> Dry-run only, backup ''{0}'' will not be created' -f "$backupPath.zip")
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

    $qualifiedBackupDirs = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction 'SilentlyContinue' | Where-Object { $_.Name -cmatch $script:DefaultFolderDateRegex })
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

    .INPUTS
        [String[]]
        File or directory paths can be piped to this function. Supports pipeline input
        from Get-ChildItem, Get-Item, or any command that outputs path strings.

    .OUTPUTS
        None. This function creates backup files but does not return objects.
        Progress information is displayed during operation.

    .NOTES
        - Supports ShouldProcess for WhatIf and Confirm scenarios
        - Creates date-stamped subdirectories (yyyy-MM-dd format)
        - Generates unique backup filenames to prevent overwrites
        - Automatically resolves relative paths from current directory
        - Continues processing remaining paths if individual items fail
        - Uses cloud-storage-compatible deletion methods for cleanup
        - Displays progress bar for multiple source paths

    .EXAMPLE
        PS > New-DailyBackup -Path 'C:\Documents' -Destination 'D:\Backups'

        Creates a backup of Documents folder in D:\Backups\2025-08-24\

    .EXAMPLE
        PS > New-DailyBackup -Path 'file1.txt', 'C:\Photos', 'D:\Projects' -Destination 'E:\DailyBackups' -Verbose

        Backs up multiple paths with detailed output

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
        [int] $Keep = -1
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

Export-ModuleMember -Function New-DailyBackup
