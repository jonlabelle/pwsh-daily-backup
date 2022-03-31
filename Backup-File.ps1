$ErrorActionPreference = 'Stop'

$script:DefaultFolderDateFormat = 'MM-dd-yyyy'

# -----------------------------------------------
# - Date format: MM-dd-yyyy
# - Date range: 01-01-1900 through 12-31-2099
# - Matches invalid dates such as February 31st
# - Accepts dashes as date separators
# -----------------------------------------------
$script:DefaultFolderDateRegex = '\A\b(0[1-9]|1[012])[-](0[1-9]|[12][0-9]|3[01])[-](19|20)[0-9]{2}\b\z'

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
            Write-Verbose ("Backup-File:Begin> Removing existing destination directory: {0}" -f $datedDestinationDir) -Verbose:$verboseEnabled
            Remove-Item -LiteralPath $datedDestinationDir -Recurse -Force -WhatIf:$dryRun -Verbose:$verboseEnabled -ErrorAction 'SilentlyContinue'
        }

        Write-Verbose ("Backup-File:Begin> Creating destination directory: {0}" -f $datedDestinationDir) -Verbose:$verboseEnabled
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

                if (!(Test-Path -Path $item))
                {
                    Write-Error ("Backup-File:Process> Backup source path does not exist: {0}" -f $item)
                    exit 1
                }

                $item = (Resolve-Path $item).ProviderPath
                CompressBackup -Path $item -DestinationPath $datedDestinationDir -DryRun $dryRun -VerboseEnabled $verboseEnabled
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

        # DeleteEmptyBackupDirectories -Path $Destination -DryRun $dryRun -VerboseEnabled $verboseEnabled
        DeleteBackups -Path $Destination -BackupsToKeep $DailyBackupsToKeep -DryRun $dryRun -VerboseEnabled $verboseEnabled

        Write-Verbose "Backup-File:End> Finished" -Verbose:$verboseEnabled
    }
}

<#
.DeleteEmptyBackupDirectories
    Delete old files and empty directories.

.PARAMETER Path
    The path containing empty directories.

.PARAMETER DryRun
    Whether or not to perform the Remove-Item operation.
    Internally sets the value of the -WhatIf parameter when running the Remove-Item cmdlet.

.PARAMETER VerboseEnabled
    Whether or not to commands will be invoked with the -Verbose parameter.
#>
function DeleteEmptyBackupDirectories
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory = $false)]
        [bool] $DryRun = $false,

        [Parameter(Mandatory = $false)]
        [bool] $VerboseEnabled = $false
    )

    Write-Verbose ("Backup-File:DeleteEmptyBackupDirectories> Deleting empty directories in {0}" -f $Path) -Verbose:$VerboseEnabled

    if ($DryRun -eq $true)
    {
        Write-Verbose "Backup-File:DeleteEmptyBackupDirectories> Only searching for empty directories, nothing will be deleted Dry-run is enabled" -Verbose:$VerboseEnabled

        # Just list the directories in dry-run mode
        (Get-ChildItem -Path $Path -Directory -Recurse -Force | Where-Object {
            $_.PSIsContainer -eq $True
        }) | Where-Object { $_.GetFileSystemInfos().Count -eq 0 } |
        Select-Object FullName
    }
    else
    {
        # This operation will loop indefinately if run if -WhatIf is $true,
        # so it has its own seperate (non chained) command block
        # See: https://stackoverflow.com/a/28631669
        do
        {
            $emptyDirs = Get-ChildItem $Path -Directory -Recurse | Where-Object {
                (Get-ChildItem $_.fullName -Force).count -eq 0
            } | Select-Object -ExpandProperty FullName
            $emptyDirs | ForEach-Object { Remove-Item $_ -Verbose:$VerboseEnabled }
        } while ($emptyDirs.count -gt 0)
    }
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

    $baseName = (Split-Path $Path -Leaf)
    $compressedFilePath = (Join-Path -Path $DestinationPath -ChildPath $baseName)

    if ((Test-Path -Path "$compressedFilePath.zip"))
    {
        $randomFileName = (GenerateRandomFileName)
        $compressedFilePath = ("{0}__{1}" -f $compressedFilePath, $randomFileName)
        Write-Warning ("Backup-File:CompressBackup> A backup with the same name '{0}' already exists the destination '{1}', so '__{2}' was automatically appended to its name for uniqueness" -f "$baseName.zip", $DestinationPath, $randomFileName)
    }

    if ($DryRun -eq $true)
    {
        Write-Verbose ("Backup-File:CompressBackup> Dry-run only, otherwise '{0}' would be backed up to '{1}'" -f $Path, "$compressedFilePath.zip") -Verbose:$VerboseEnabled
    }
    else
    {
        Write-Verbose ("Backup-File:CompressBackup> Compressing backup '{0}' to '{1}'" -f $Path, "$compressedFilePath.zip") -Verbose:$VerboseEnabled
        Compress-Archive -LiteralPath $Path -DestinationPath "$compressedFilePath.zip" -WhatIf:$DryRun -Verbose:$VerboseEnabled
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

    # $qualifiedBackupDirs = (Get-ChildItem -LiteralPath $Path -Directory -Depth 1 | Sort-Object -Property { $_.LastWriteTime } | Where-Object { $_.Name -cmatch $script:DefaultFolderDateRegex })
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

    if ($sortedBackupPaths.Length -gt $BackupsToKeep)
    {
        for ($backup = 0; $backup -lt ($sortedBackupPaths.Length - $BackupsToKeep); $backup++)
        {
            $backupPath = $sortedBackupPaths[$backup]

            if ($DryRun -eq $true)
            {
                Write-Verbose ("Backup-File:DeleteBackups> Dry-run only, otherwise backup {0} would be deleted" -f $backupPath) -Verbose:$VerboseEnabled
            }
            else
            {
                Write-Verbose ("Backup-File:DeleteBackups> Deleting backup: {0}" -f $backupPath) -Verbose:$VerboseEnabled
                Remove-Item -LiteralPath $backupPath -Force -Recurse -WhatIf:$DryRun -Verbose:$VerboseEnabled
            }

            $deletedBackupCount++
        }
    }
    else
    {
        Write-Verbose "Backup-File:DeleteBackups> No surplus backups to delete." -Verbose:$VerboseEnabled
    }

    if ($DryRun -eq $true)
    {
        Write-Verbose ("Backup-File:DeleteBackups> Dry-run only, otherwise {0} backup(s) would have been deleted." -f $deletedBackupCount) -Verbose:$VerboseEnabled
    }
    else
    {
        Write-Verbose ("Backup-File:DeleteBackups> Total backups deleted: {0}" -f $deletedBackupCount) -Verbose:$VerboseEnabled
    }
}

<#
.SYNOPSIS
    Generates a random file name without the file extension.

.OUTPUTS
    System.string. The random generated file name.
#>
function GenerateRandomFileName
{
    $randomFileName = [System.IO.Path]::GetRandomFileName()
    return $randomFileName.Substring(0, $randomFileName.IndexOf('.'))
}
