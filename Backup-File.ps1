$ErrorActionPreference = "SilentlyContinue"

function Backup-File
{
    <#
    .SYNOPSIS
        PowerShell script to backup files.

    .DESCRIPTION
        PowerShell script to backup files.

    .PARAMETER Path
        The files or directories to backup.

    .PARAMETER Destination
        The root directory path where backup files will be stored.
        NOTE: The current day formatted as 'mm-dd-yyyy' will be prepended to each backup run.

    .PARAMETER DeleteBackupsOldThanDays
        The number of days to keep a backup archives before deleting.

    .EXAMPLE
        To import the Backup-File module in your session:
        Import-Module Backup-File.ps1

    .EXAMPLE
        To backup a list of paths:
        Backup-Files -Path $('source/path/1', 'source/path/2') -Destination destination/path -Verbose

    .EXAMPLE
        To see what would happen if files were backed up (e.g. dry run):
        Backup-Files -Path source/path -Destination destination/path -WhatIf

    .NOTES
        Version: 1.0.0
        Date: March 26, 2022
        Author: Jon LaBelle

    .LINK
        https://github.com/jonlabelle/dad-backup (TODO: not yet created)
    #>
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
        [string[]]$Path,

        [Parameter(
            ParameterSetName = 'String',
            Position = 0,
            Mandatory = $true)
        ]
        [string[]]$String,

        [Parameter(
            Position = 1,
            Mandatory = $true)
        ]
        [Alias("DestinationPath", "TargetPath")]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int] $DeleteBackupsOldThanDays
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
        if ($PSCmdlet.ShouldProcess($Path))
        {
            Write-Verbose "Backup-File:Begin> Dry run was not be enabled" -Verbose:$verboseEnabled
            $dryRun = $false
        }
        else
        {
            Write-Verbose "Backup-File:Begin> Dry run is enabled" -Verbose:$verboseEnabled
        }

        $date = (Get-Date -Format "MM-dd-yyyy")
        $datedDestinationDir = (Join-Path -Path $Destination -ChildPath $date)

        if ((Test-Path -Path $datedDestinationDir -PathType Container))
        {
            Write-Verbose ("Backup-File:Begin> Removing existing destination directory: {0}" -f $datedDestinationDir) -Verbose:$verboseEnabled
            Remove-Item -Path $datedDestinationDir -ItemType Directory -Force -Recurse -WhatIf:$dryRun -Verbose:$verboseEnabled
        }

        Write-Verbose ("Backup-File:Begin> Creating destination directory: {0}" -f $datedDestinationDir) -Verbose:$verboseEnabled
        New-Item -Path $datedDestinationDir -ItemType Directory -WhatIf:$dryRun -Verbose:$verboseEnabled | Out-Null
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
                    Write-Host "Backup-File:Process> Backup source path does not exist: $item" -ForegroundColor Red
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
        DeleteOldBackups -Path $Destination -DaysSinceLastModified $DeleteBackupsOldThanDays -Filter *.zip -DryRun $dryRun -VerboseEnabled $verboseEnabled
        DeleteEmptyDirectories -Path $Destination -DryRun $dryRun -VerboseEnabled $verboseEnabled
        Write-Verbose "Backup-File:End> Finished" -Verbose:$verboseEnabled
    }
}

function DeleteEmptyDirectories
{
    <#
    .SYNOPSIS
        Delete old files and empty directories.

    .PARAMETER Path
        The path containing empty directories.

    .PARAMETER DryRun
        Whether or not to perform the Remove-Item operation.
        Internally sets the value of the -WhatIf parameter when running the Remove-Item cmdlet.

    .PARAMETER VerboseEnabled
        Whether or not to commands will be invoked with the -Verbose parameter.
    #>
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

    Write-Verbose ("Backup-File:DeleteEmptyDirectories> Deleting empty directories in {0}" -f $Path) -Verbose:$VerboseEnabled

    if ($DryRun -eq $true)
    {
        Write-Verbose "Backup-File:DeleteEmptyDirectories> Only searching for empty directories, nothing will be deleted dry run is enabled" -Verbose:$VerboseEnabled

        # Just list the directories in dry-run mode
        (Get-ChildItem -Path $Path -Directory -Recurse -Force | Where-Object { $_.PSIsContainer -eq $True }) |
        Where-Object { $_.GetFileSystemInfos().Count -eq 0 } |
        Select-Object FullName
    }
    else
    {
        # This operation will loop indefinately if run if -WhatIf is $true,
        # so it has its own seperate (non chained) command block
        # See: https://stackoverflow.com/a/28631669
        do
        {
            $emptyDirs = Get-ChildItem $Path -Directory -Recurse | Where-Object { (Get-ChildItem $_.fullName -Force).count -eq 0 } | Select-Object -ExpandProperty FullName
            $emptyDirs | ForEach-Object { Remove-Item $_ -Verbose:$VerboseEnabled }
        } while ($emptyDirs.count -gt 0)
    }
}

function DeleteOldBackups
{
    <#
    .SYNOPSIS
        Delete old files and empty directories.

    .PARAMETER Path
        The root path to delete files.

    .PARAMETER Filter
        The file filter. e.g. '*.zip'

    .PARAMETER DaysSinceLastModified
        The number of days since a file was last modified before it can be deleted.

    .PARAMETER DryRun
        Whether or not to perform the Remove-Item operation.
        Internally sets the value of the -WhatIf parameter when running the Remove-Item cmdlet.

    .PARAMETER VerboseEnabled
        Whether or not to commands will be invoked with the -Verbose parameter.

    .LINK
        https://social.technet.microsoft.com/Forums/en-US/c59d77c6-ee9e-4ea4-be63-5eb24b8ceeab/remove-old-files-and-empty-folders?forum=winserverpowershell
    #>
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Filter,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int] $DaysSinceLastModified,

        [Parameter(Mandatory = $false)]
        [bool] $DryRun = $false,

        [Parameter(Mandatory = $false)]
        [bool] $VerboseEnabled = $false
    )

    Write-Verbose ("Backup-File:DeleteOldBackups> Deleting {0} files older than {1} days from {2}" -f $Filter, $DaysSinceLastModified, $Path) -Verbose:$VerboseEnabled

    $lastModfiedDate = (Get-Date).AddDays(-$DaysSinceLastModified)

    Get-ChildItem -LiteralPath $Path -File -Filter $Filter -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $lastModfiedDate } |
    Remove-Item -ErrorAction SilentlyContinue -WhatIf:$DryRun -Verbose:$VerboseEnabled
}

function CompressBackup
{
    <#
    .SYNOPSIS
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

    Write-Verbose ("Backup-File:CompressBackup> Compressing '{0}' to '{1}'" -f $Path, "${compressedFilePath}.zip") -Verbose:$VerboseEnabled
    Compress-Archive -LiteralPath $Path -DestinationPath "$compressedFilePath.zip" -WhatIf:$DryRun -Verbose:$VerboseEnabled
}
