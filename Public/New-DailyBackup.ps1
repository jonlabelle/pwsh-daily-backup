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

    .PARAMETER NoHash
        Skip hash calculation to improve performance in simple backup scenarios.
        When specified, backup integrity verification will not be available for
        these backups. Hash calculation is enabled by default for all backups.

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
        - Creates consolidated metadata manifest (backup-manifest.json) for tracking
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

    .EXAMPLE
        PS > New-DailyBackup -Path 'C:\ImportantFiles' -Destination 'D:\Backups' -NoHash

        Creates backup without hash calculation for improved performance

    .LINK
        Test-DailyBackupIntegrity
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
        [string] $FileBackupMode = 'Auto',

        [Parameter(
            HelpMessage = 'Skip hash calculation to improve performance in simple backup scenarios.'
        )]
        [switch] $NoHash
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

        $Destination = Resolve-UnverifiedPath -Path $Destination
        $folderName = (Get-Date -Format $script:DefaultFolderDateFormat)
        $datedDestinationDir = (Join-Path -Path $Destination -ChildPath $folderName)

        if ((Test-Path -Path $datedDestinationDir -PathType Container))
        {
            Write-Verbose ('New-DailyBackup:Begin> Removing existing backup destination directory: {0}' -f $datedDestinationDir) -Verbose:$verboseEnabled
            Remove-ItemAlternative -LiteralPath $datedDestinationDir -WhatIf:$WhatIfPreference -Verbose:$verboseEnabled
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
                # Handle long paths on Windows
                $pathToResolve = $item
                if ($PSVersionTable.Platform -eq 'Win32NT' -and $item.Length -ge 260)
                {
                    Write-Verbose ('New-DailyBackup:Process> Long path detected ({0} characters), using extended path syntax' -f $item.Length) -Verbose:$verboseEnabled
                    $pathToResolve = "\\?\$item"
                }

                $resolvedPath = (Resolve-Path $pathToResolve -ErrorAction SilentlyContinue -Verbose:$verboseEnabled).ProviderPath
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
                        try
                        {
                            Compress-Backup -Path $globItem -DestinationPath $datedDestinationDir -VerboseEnabled $verboseEnabled -NoHash:$NoHash -WhatIf:$WhatIfPreference
                        }
                        catch
                        {
                            Write-Warning ('New-DailyBackup:Process> Error compressing {0}: {1}' -f $globItem, $_.Exception.Message)
                        }
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
                        try
                        {
                            Compress-Backup -Path $resolvedPath -DestinationPath $datedDestinationDir -VerboseEnabled $verboseEnabled -NoHash:$NoHash -WhatIf:$WhatIfPreference
                        }
                        catch
                        {
                            Write-Warning ('New-DailyBackup:Process> Error compressing {0}: {1}' -f $resolvedPath, $_.Exception.Message)
                        }
                    }
                }
            }
            catch
            {
                Write-Warning ('New-DailyBackup:Process> Error processing path {0}: {1}' -f $item, $_.Exception.Message)
            }
        }

        Write-Progress -Activity 'Creating Daily Backup' -Completed
    }
    end
    {
        Write-Verbose 'New-DailyBackup:End> Running post backup operations' -Verbose:$verboseEnabled

        if ($Keep -ge 0)
        {
            Remove-DailyBackup -Path $Destination -BackupsToKeep $Keep -VerboseEnabled $verboseEnabled -WhatIf:$WhatIfPreference
        }

        Write-Verbose 'New-DailyBackup:End> Finished' -Verbose:$verboseEnabled
    }
}
