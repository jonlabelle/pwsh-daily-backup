$script:ErrorActionPreference = 'Stop'
$script:ProgressPreference = 'SilentlyContinue'

$script:DirectorySeperator = [IO.Path]::DirectorySeparatorChar

# -----------------------------------------------
# - Date format: MM-dd-yyyy
# - Date range: 01-01-1900 through 12-31-2099
# - Matches invalid dates such as February 31st
# - Accepts dashes as date separators
# -----------------------------------------------
$script:DefaultFolderDateFormat = 'MM-dd-yyyy'
$script:DefaultFolderDateRegex = '\A\b(0[1-9]|1[012])[-](0[1-9]|[12][0-9]|3[01])[-](19|20)[0-9]{2}\b\z'

<#
.SYNOPSIS
    Generates a random file name without the file extension.

.OUTPUTS
    System.string. The random generated file name.
#>
function GetRandomFileName
{
    $randomFileName = [System.IO.Path]::GetRandomFileName()
    return $randomFileName.Substring(0, $randomFileName.IndexOf('.'))
}

<#
.SYNOPSIS
    Generates a backup file name by replacing directory seperator
    characters and spaces with underscores.

.PARAMETER Path
    The source path for the backup.

.PARAMETER VerboseEnabled
    Whether or not to enable verbose output.

.OUTPUTS
    System.string. The backup name (without the file extension).
#>
function GenerateBackupName
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $pathWithoutPrefix = (Split-Path -Path $Path -NoQualifier)
    $pathSegments = $pathWithoutPrefix -split $script:DirectorySeperator

    $backupName = [System.Text.StringBuilder]::new()

    foreach ($segment in $pathSegments)
    {
        $segment = $segment.replace(' ', '_').Trim('_')

        [void]$backupName.Append("{0}_" -f $segment)
    }

    return $backupName.ToString().Trim('_')
}

<#
.CompressBackup
    Creates a compressed archive, or zipped file, from specified files and directories.

.PARAMETER Path
    The path of the file or directory to compress.

.PARAMETER DestinationPath
    The destination path of the compressed file.

.PARAMETER DryRun
    Whether or not to perform the Compress-Archive operation.
    Internally sets the value of the -WhatIf parameter when running the Compress-Archive cmdlet.

.PARAMETER VerboseEnabled
    Whether or not to commands will be invoked with the -Verbose parameter.
#>
function CompressBackup
{
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

    # $backupName = (Split-Path -Path $Path -Leaf)
    # $backupPath = (Join-Path -Path $DestinationPath -ChildPath $backupName)

    $backupName = (GenerateBackupName -Path $Path)
    $backupPath = (Join-Path -Path $DestinationPath -ChildPath $backupName)

    if ((Test-Path -Path "$backupPath.zip"))
    {
        $randomFileName = (GetRandomFileName)
        $backupPath = ("{0}_{1}" -f $backupPath, $randomFileName)

        Write-Warning ("Backup-File:CompressBackup> A backup with the same name '{0}' already exists the destination '{1}', so '__{2}' was automatically appended to its name for uniqueness" -f "$backupName.zip", $DestinationPath, $randomFileName)
    }

    if ($DryRun -eq $true)
    {
        Write-Verbose ("Backup-File:CompressBackup> Dry-run only, otherwise '{0}' would be backed up to '{1}'" -f $Path, "$backupPath.zip") -Verbose:$VerboseEnabled
    }
    else
    {
        Write-Verbose ("Backup-File:CompressBackup> Compressing backup '{0}' to '{1}'" -f $Path, "$backupPath.zip") -Verbose:$VerboseEnabled
        Compress-Archive -LiteralPath $Path -DestinationPath "$backupPath.zip" -ErrorAction Continue -WhatIf:$DryRun
    }
}

function DeleteBackups
{
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

    $deletedBackupCount = 0
    $qualifiedBackupDirs = (Get-ChildItem -LiteralPath $Path -Directory -Depth 1 -ErrorAction 'SilentlyContinue' | Where-Object { $_.Name -cmatch $script:DefaultFolderDateRegex })

    if ($qualifiedBackupDirs.Length -le 0)
    {
        Write-Verbose ("Backup-File:DeleteBackups> No qualified backup directories to delete were detected in: {0}" -f $Path) -Verbose:$VerboseEnabled
        return
    }

    # Create a hashtable so we can sort backup directories based on
    # their dated folder name ('MM-dd-yyyy')
    $backups = @{}
    foreach ($backupDir in $qualifiedBackupDirs)
    {
        $backups.Add($backupDir.FullName, [System.DateTime]$backupDir.Name)
    }

    $sortedBackupPaths = ($backups.GetEnumerator() |
        Sort-Object -Property Value | ForEach-Object { $_.Key })

    if ($sortedBackupPaths.Count -gt $BackupsToKeep)
    {
        for ($backup = 0; $backup -lt ($sortedBackupPaths.Count - $BackupsToKeep); $backup++)
        {
            $backupPath = $sortedBackupPaths[$backup]

            if ($DryRun -eq $true)
            {
                Write-Verbose ("Backup-File:DeleteBackups> Dry-run only, otherwise backup '{0}' would have been deleted" -f $backupPath) -Verbose:$VerboseEnabled
            }
            else
            {
                Write-Verbose ("Backup-File:DeleteBackups> Deleting backup: {0}" -f $backupPath) -Verbose:$VerboseEnabled
                Remove-Item -Path $backupPath -Force -Recurse -WhatIf:$DryRun -Verbose:$VerboseEnabled
            }

            $deletedBackupCount++
        }
    }
    else
    {
        Write-Verbose "Backup-File:DeleteBackups> No surplus backups to delete" -Verbose:$VerboseEnabled
    }

    if ($DryRun -eq $true)
    {
        Write-Verbose ("Backup-File:DeleteBackups> Dry-run only, otherwise {0} backup(s) would have been deleted" -f $deletedBackupCount) -Verbose:$VerboseEnabled
    }
    else
    {
        Write-Verbose ("Backup-File:DeleteBackups> Total backups deleted: {0}" -f $deletedBackupCount) -Verbose:$VerboseEnabled
    }
}

<#
.Backup-File
    PowerShell script to backup files.

.SYNOPSIS
    PowerShell script to backup files.

.PARAMETER Path
    The files or directories to backup.

.PARAMETER Destination
    The root directory path where backup files will be stored.
    NOTE: The current day formatted as 'MM-dd-yyyy' will be prepended to each backup run.

.PARAMETER DailyBackupsToKeep
    The number of daily backups to keep.
    The value cannot be less than zero.

.EXAMPLE
    To import the Backup-File module in your session:
    Import-Module Backup-File.ps1

.EXAMPLE
    To backup a list of paths:
    Backup-Files -Path $('source/path/1', 'source/path/2') -Destination destination/path -Verbose

.EXAMPLE
    To see what would happen if files were backed up (e.g. Dry-run):
    Backup-Files -Path source/path -Destination destination/path -WhatIf

.NOTES
    Version: 1.0.0
    Date: March 26, 2022
    Author: Jon LaBelle

.LINK
    https://github.com/jonlabelle/dad-backup
#>
function Backup-File
{
    [CmdletBinding(
        DefaultParameterSetName = 'File',
        SupportsShouldProcess)]
    Param(
        [Parameter(
            ParameterSetName = 'File',
            Position = 0,
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $True)
        ]
        [Alias("PSPath", "FullName", "SourcePath")]
        [string[]] $Path,

        [Parameter(
            ParameterSetName = 'String',
            Position = 0,
            Mandatory = $true)
        ]
        [string[]] $String,

        [Parameter(
            Position = 1,
            Mandatory = $true)
        ]
        [Alias("DestinationPath", "TargetPath")]
        [string] $Destination,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int] $DailyBackupsToKeep
    )
    Begin
    {
        $verboseEnabled = $false
        if ($VerbosePreference -eq 'Continue')
        {
            $verboseEnabled = $true
            Write-Verbose "Backup-File:Begin> Verbose mode is enabled" -Verbose:$verboseEnabled
        }

        $dryRun = $true
        if ( $PSCmdlet.ShouldProcess($Path) -and (-not($Env:CI)))
        {
            Write-Verbose "Backup-File:Begin> Dry-run is not enabled" -Verbose:$verboseEnabled
            $dryRun = $false
        }
        else
        {
            Write-Verbose "Backup-File:Begin> Dry-run is enabled" -Verbose:$verboseEnabled
        }

        if ($DailyBackupsToKeep -lt 0)
        {
            Write-Error ("Backup-File:Begin> DailyBackupsToKeep parameter cannot be less than zero." -f $DailyBackupsToKeep)
            exit 1
        }

        $folderName = (Get-Date -Format $script:DefaultFolderDateFormat)
        $datedDestinationDir = (Join-Path -Path $Destination -ChildPath $folderName)
        if ((Test-Path -Path $datedDestinationDir -PathType Container))
        {
            Write-Verbose ("Backup-File:Begin> Removing existing backup destination directory: {0}" -f $datedDestinationDir) -Verbose:$verboseEnabled
            Remove-Item -LiteralPath $datedDestinationDir -Recurse -Force -WhatIf:$dryRun -Verbose:$verboseEnabled -ErrorAction 'SilentlyContinue'
        }

        Write-Verbose ("Backup-File:Begin> Creating backup destination directory: {0}" -f $datedDestinationDir) -Verbose:$verboseEnabled
        New-Item -Path $datedDestinationDir -ItemType Directory -WhatIf:$dryRun -Verbose:$verboseEnabled -ErrorAction 'SilentlyContinue' | Out-Null
    }
    Process
    {
        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            $items = $Path
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'String')
        {
            $items = $String
        }

        foreach ($item in $items)
        {
            if ($PSCmdlet.ParameterSetName -eq 'File')
            {
                if (-not [System.IO.Path]::IsPathRooted($item))
                {
                    Write-Verbose ("Backup-File:Process> {0} is not a full path, prepending current directory: {1}" -f $item, $pwd) -Verbose:$verboseEnabled
                    $item = (Join-Path -Path $pwd -ChildPath $item)
                }

                $resolvedPath = (Resolve-Path $item -ErrorAction SilentlyContinue -Verbose:$verboseEnabled).ProviderPath
                if ($null -eq $resolvedPath)
                {
                    Write-Warning ("Backup-File:Process> Failed to resolve path for: {0}" -f $item)
                    Continue
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
                        Write-Warning ("Backup-File:Process> Backup source path does not exist: {0}" -f $resolvedPath)
                    }
                    else
                    {
                        CompressBackup -Path $resolvedPath -DestinationPath $datedDestinationDir -DryRun $dryRun -VerboseEnabled $verboseEnabled
                    }
                }
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'String')
            {
                CompressBackup -Path $item -DestinationPath $datedDestinationDir -DryRun $dryRun -VerboseEnabled $verboseEnabled
            }
        }
    }
    End
    {
        Write-Verbose "Backup-File:End> Running post backup operations" -Verbose:$verboseEnabled
        DeleteBackups -Path $Destination -BackupsToKeep $DailyBackupsToKeep -DryRun $dryRun -VerboseEnabled $verboseEnabled
        Write-Verbose "Backup-File:End> Finished" -Verbose:$verboseEnabled
    }
}
