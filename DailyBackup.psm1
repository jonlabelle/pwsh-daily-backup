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
        Generates a random file name.

    .DESCRIPTION
        Generates a random file name without the file extension.

    .OUTPUTS
        [String]
    #>
    $randomFileName = [System.IO.Path]::GetRandomFileName()
    return $randomFileName.Substring(0, $randomFileName.IndexOf('.'))
}

function GenerateBackupPath
{
    <#
    .SYNOPSIS
        Generates a backup file name.

    .DESCRIPTION
        Generates a backup file name by replacing directory seperator
        characters and spaces with underscores.

    .PARAMETER Path
        The source path for the backup.

    .PARAMETER DestinationPath
        The destination path of the compressed file.

    .PARAMETER VerboseEnabled
        Whether or not invoke commands with the -Verbose parameter.

    .OUTPUTS
        [String]
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

    # replace directory seperators with underscores
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
        Creates a compressed archive.

    .DESCRIPTION
        Creates a compressed archive, or zipped file, from specified files
        and or directories.

    .PARAMETER Path
        The path of the file or directory to compress.

    .PARAMETER DestinationPath
        The destination path of the compressed file.

    .PARAMETER DryRun
        Whether or not to perform the Compress-Archive operation.
        Internally sets the value of the -WhatIf parameter when running the Compress-Archive cmdlet.

    .PARAMETER VerboseEnabled
        Whether or not invoke commands with the -Verbose parameter.
    #>
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationPath,

        [Parameter(Mandatory = $false)]
        [bool] $DryRun = $false,

        [Parameter(Mandatory = $false)]
        [bool] $VerboseEnabled = $false
    )

    $backupPath = GenerateBackupPath -Path $Path -DestinationPath $DestinationPath

    if ($DryRun)
    {
        Write-Verbose ('New-DailyBackup:CompressBackup> Dry-run only, backup ''{0}'' will not be created' -f "$backupPath.zip")
    }
    else
    {
        Write-Verbose ('New-DailyBackup:CompressBackup> Compressing backup ''{0}''' -f "$backupPath.zip")
        Compress-Archive -LiteralPath $Path -DestinationPath "$backupPath.zip" -WhatIf:$DryRun -Verbose:$VerboseEnabled -ErrorAction Continue
    }
}

function ResolveUnverifiedPath
{
    <#
    .SYNOPSIS
        A wrapper around Resolve-Path that works for paths that exist as well
        as for paths that don't (Resolve-Path normally throws an exception if
        the path doesn't exist.)

    .DESCRIPTION
        A wrapper around Resolve-Path that works for paths that exist as well
        as for paths that don't (Resolve-Path normally throws an exception if
        the path doesn't exist.)

        The Git repo for this module can be found here:
        https://aka.ms/PowerShellForGitHub

    .EXAMPLE
        ResolveUnverifiedPath -Path 'c:\windows\notepad.exe'

        Returns the string 'c:\windows\notepad.exe'.

    .EXAMPLE
        ResolveUnverifiedPath -Path '..\notepad.exe'

        Returns the string 'c:\windows\notepad.exe', assuming that it's
        executed from within 'c:\windows\system32' or some other sub-directory.

    .EXAMPLE
        ResolveUnverifiedPath -Path '..\foo.exe'

        Returns the string 'c:\windows\foo.exe', assuming that it's executed
        from within 'c:\windows\system32' or some other sub-directory, evenÎ
        though this file doesn't exist.

    .OUTPUTS
        [String]. The fully resolved path
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
        Removes all files and folders within given path.

    .DESCRIPTION
        Removes all files and folders within given path.
        A workaround for the access denied issue when attempting to Remove-Item(s) from an Apple iCloud or OneDrive path.

    .PARAMETER LiteralPath
        Path to location.
        The value of LiteralPath is used exactly as it's typed.
        No characters are interpreted as wildcards.
        If the path includes escape characters, enclose it in single quotation marks.
        Single quotation marks tell PowerShell not to interpret any characters as escape sequences.

    .PARAMETER SkipTopLevelFolder
        If present, the top-level folder will not be deleted.

    .EXAMPLE
        RemoveItemAlternative -LiteralPath "C:\Support\GitHub\GpoZaurr\Docs"

    .NOTES
        https://evotec.xyz/remove-item-access-to-the-cloud-file-is-denied-while-deleting-files-from-onedrive/
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
        Write-Warning "New-DailyBackup:RemoveItemAlternative> Path '$Path' doesn't exist. Skipping."
    }
}

function RemoveDailyBackup
{
    <#
    .SYNOPSIS
        Delete daily backups.

    .DESCRIPTION
        Delete daily backups with an option to keep minimum number of previous
        backups, deleting the oldest backups first.

    .PARAMETER Path
        The root path where backups are stored.

    .PARAMETER BackupsToKeep
        The minimum number of backups to keep before deleting.

    .PARAMETER DryRun
        Whether or not to perform the actual delete operation.
        Internally sets the value of the -WhatIf parameter when running the Remove-Item cmdlet.

    .PARAMETER VerboseEnabled
        Whether or not invoke commands with the -Verbose parameter.
    #>
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int] $BackupsToKeep,

        [Parameter(Mandatory = $false)]
        [bool] $DryRun = $false,

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
            RemoveItemAlternative -LiteralPath $backupPath -WhatIf:$dryRun -Verbose:$verboseEnabled
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
        Perform a daily backup.

    .DESCRIPTION
        Create a new daily backup storing the compressed (.zip) contents in
        a destination folder formatted by day ('yyyy-MM-dd').

    .PARAMETER Path
        The source file or directory path(s) to backup.

    .PARAMETER Destination
        The root directory path where daily backups will be stored.
        The default destination is the current working directory.

    .PARAMETER DailyBackupsToKeep
        The number of daily backups to keep when purging old backups.
        The oldest backups will be deleted first.
        This value cannot be less than zero.
        The default value is 0, which will not remove any backups.

    .EXAMPLE
        To import the DailyBackup module in your session:

        Import-Module DailyBackup

    .EXAMPLE
        To create a new daily backup from a list of paths:

        New-DailyBackup -Path 'source/path/1', 'source/path/2' -Destination 'root/destination/directory' -Verbose

    .EXAMPLE
        To perform a dry-run/what-if of the daily backup operations:

        New-DailyBackup -Path source/path -Destination destination/path -WhatIf

    .EXAMPLE
        To delete old backups, keeping only the last 3 folder/dates of backup:

        New-DailyBackup -Path source/path -Destination destination/path -Keep 3

    .EXAMPLE
        To backup files to the current working directory:

        New-DailyBackup -Path source/path

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
        [ValidateNotNullOrEmpty()]
        [Alias('Keep')]
        [int] $DailyBackupsToKeep = 0
    )
    begin
    {
        $verboseEnabled = $false
        if ($VerbosePreference -eq 'Continue')
        {
            $verboseEnabled = $true
            Write-Verbose 'New-DailyBackup:Begin> Verbose mode is enabled' -Verbose:$verboseEnabled
        }

        $dryRun = $true
        if ($PSCmdlet.ShouldProcess('New-DailyBackup', 'Begin'))
        {
            Write-Verbose 'New-DailyBackup:Begin> Dry-run is not enabled' -Verbose:$verboseEnabled
            $dryRun = $false
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
            RemoveItemAlternative -LiteralPath $datedDestinationDir -WhatIf:$dryRun -Verbose:$verboseEnabled
        }

        Write-Verbose ('New-DailyBackup:Begin> Creating backup destination directory: {0}' -f $datedDestinationDir) -Verbose:$verboseEnabled
        New-Item -Path $datedDestinationDir -ItemType Directory -WhatIf:$dryRun -Verbose:$verboseEnabled -ErrorAction 'SilentlyContinue' | Out-Null
    }
    process
    {
        foreach ($item in $Path)
        {
            if (-not [System.IO.Path]::IsPathRooted($item))
            {
                Write-Verbose ('New-DailyBackup:Process> {0} is not a full path, prepending current directory: {1}' -f $item, $pwd) -Verbose:$verboseEnabled
                $item = (Join-Path -Path $pwd -ChildPath $item)
            }

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
                    CompressBackup -Path $globItem -DestinationPath $datedDestinationDir -DryRun $dryRun -VerboseEnabled $verboseEnabled
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
                    CompressBackup -Path $resolvedPath -DestinationPath $datedDestinationDir -DryRun $dryRun -VerboseEnabled $verboseEnabled
                }
            }
        }
    }
    end
    {
        Write-Verbose 'New-DailyBackup:End> Running post backup operations' -Verbose:$verboseEnabled

        if ($DailyBackupsToKeep -gt 0)
        {
            RemoveDailyBackup -Path $Destination -BackupsToKeep $DailyBackupsToKeep -DryRun $dryRun -VerboseEnabled $verboseEnabled
        }

        Write-Verbose 'New-DailyBackup:End> Finished' -Verbose:$verboseEnabled
    }
}

Export-ModuleMember -Function New-DailyBackup
