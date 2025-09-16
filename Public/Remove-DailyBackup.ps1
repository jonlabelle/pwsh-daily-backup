function Remove-DailyBackup
{
    <#
    .SYNOPSIS
        Removes daily backup directories and files based on specified criteria.

    .DESCRIPTION
        Removes daily backup directories and files from a backup location. Supports multiple
        removal modes including date-based cleanup, retention policies, and specific backup
        removal. The function can clean up old backups while preserving recent ones, or
        remove specific backup dates. Only directories matching the yyyy-MM-dd date pattern
        are considered for removal operations.

    .PARAMETER Path
        The root directory path where daily backup folders are stored, or the specific
        backup directory to remove when using -Date parameter. This should be the parent
        directory containing date-named subdirectories (e.g., '2025-08-24').

    .PARAMETER Keep
        The minimum number of backup directories to retain when using retention-based cleanup.
        Older backups beyond this number will be deleted, sorted by date with oldest removed
        first. Set to 0 to remove all backups. Cannot be used with -Date parameter.

        Note: BackupsToKeep is an alias for this parameter.

    .PARAMETER Date
        Specific backup date to remove (yyyy-MM-dd format). When specified, only the backup
        directory for this date will be removed. Cannot be used with -Keep parameter.

    .PARAMETER Force
        Bypass confirmation prompts and remove backups without user interaction. Use with
        caution as this will permanently delete backup data.

    .INPUTS
        [String]
        Backup root path can be piped to this function.

    .OUTPUTS
        None. This function does not return any objects but may display verbose information
        about the removal process.

    .NOTES
        - Only directories matching the yyyy-MM-dd date pattern are processed
        - Supports ShouldProcess for WhatIf and Confirm functionality
        - Uses cross-platform compatible removal methods
        - Continues operation even if individual directory deletions fail
        - Verbose output provides detailed information about removal operations

    .EXAMPLE
        PS > Remove-DailyBackup -Path 'C:\Backups' -Keep 7

        Keeps the 7 most recent daily backup folders, removes older ones

    .EXAMPLE
        PS > Remove-DailyBackup -Path 'C:\Backups' -Date '2025-09-01'

        Removes only the backup directory for September 1, 2025

    .EXAMPLE
        PS > Remove-DailyBackup -Path '/home/user/backups' -Keep 3 -WhatIf

        Shows which backup directories would be deleted without actually removing them

    .EXAMPLE
        PS > Remove-DailyBackup -Path 'D:\Backups' -Keep 0 -Force

        Removes all backup directories without confirmation prompts

    .EXAMPLE
        PS > 'C:\MyBackups' | Remove-DailyBackup -Keep 14

        Pipeline input: maintains a 2-week retention policy (14 days) for backup directories
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Retention')]
    param
    (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'The root directory path where daily backup folders are stored.'
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('BackupRoot', 'DestinationPath')]
        [string] $Path,

        [Parameter(
            ParameterSetName = 'Retention',
            HelpMessage = 'The number of daily backup directories to retain.'
        )]
        [ValidateRange(0, [int]::MaxValue)]
        [Alias('BackupsToKeep')]
        [int] $Keep = 7,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'SpecificDate',
            HelpMessage = 'Specific backup date to remove (yyyy-MM-dd format).'
        )]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $Date,

        [Parameter(
            HelpMessage = 'Bypass confirmation prompts and remove backups without user interaction.'
        )]
        [switch] $Force
    )

    begin
    {
        $verboseEnabled = $VerbosePreference -eq 'Continue'
        Write-Verbose 'Remove-DailyBackup:Begin> Starting backup removal operation' -Verbose:$verboseEnabled
    }

    process
    {
        # Validate input path first
        if ([string]::IsNullOrWhiteSpace($Path))
        {
            Write-Error "Remove-DailyBackup:Process> Path parameter cannot be null or empty"
            return
        }

        Write-Verbose "Remove-DailyBackup:Process> Input path: '$Path'" -Verbose:$verboseEnabled

        # Resolve the path to ensure it exists
        try
        {
            $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
            $backupRoot = $resolvedPath.Path
        }
        catch
        {
            Write-Error "Remove-DailyBackup:Process> Cannot access path '$Path': $($_.Exception.Message)"
            return
        }

        Write-Verbose "Remove-DailyBackup:Process> Processing backup root: $backupRoot" -Verbose:$verboseEnabled

        # Get qualified backup directories (matching yyyy-MM-dd pattern)
        $qualifiedBackupDirs = @(Get-ChildItem -LiteralPath $backupRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' })

        if ($qualifiedBackupDirs.Length -eq 0)
        {
            Write-Verbose "Remove-DailyBackup:Process> No qualified backup directories found in: $backupRoot" -Verbose:$verboseEnabled
            return
        }

        Write-Verbose "Remove-DailyBackup:Process> Found $($qualifiedBackupDirs.Length) qualified backup directories" -Verbose:$verboseEnabled

        if ($PSCmdlet.ParameterSetName -eq 'SpecificDate')
        {
            # Remove specific date
            $targetDir = $qualifiedBackupDirs | Where-Object { $_.Name -eq $Date }
            if (-not $targetDir)
            {
                Write-Warning "Remove-DailyBackup:Process> No backup found for date: $Date"
                return
            }

            $confirmMessage = "Remove backup directory for date $Date"
            if ($Force -or $PSCmdlet.ShouldProcess($targetDir.FullName, $confirmMessage))
            {
                Write-Verbose "Remove-DailyBackup:Process> Removing backup directory: $($targetDir.FullName)" -Verbose:$verboseEnabled
                try
                {
                    Remove-ItemAlternative -LiteralPath $targetDir.FullName -WhatIf:$WhatIfPreference -Verbose:$verboseEnabled
                    Write-Verbose "Remove-DailyBackup:Process> Successfully removed: $($targetDir.FullName)" -Verbose:$verboseEnabled
                }
                catch
                {
                    Write-Error "Remove-DailyBackup:Process> Failed to remove directory '$($targetDir.FullName)': $($_.Exception.Message)"
                }
            }
        }
        else
        {
            # Retention-based cleanup
            if ($qualifiedBackupDirs.Length -le $Keep)
            {
                Write-Verbose "Remove-DailyBackup:Process> Current backup count ($($qualifiedBackupDirs.Length)) does not exceed retention limit ($Keep)" -Verbose:$verboseEnabled
                return
            }

            # Create hashtable to sort backup directories by date
            $backups = @{ }
            foreach ($backupDir in $qualifiedBackupDirs)
            {
                try
                {
                    $backups.Add($backupDir.FullName, [System.DateTime]::ParseExact($backupDir.Name, 'yyyy-MM-dd', $null))
                }
                catch
                {
                    Write-Warning "Remove-DailyBackup:Process> Skipping directory with invalid date format: $($backupDir.Name)"
                }
            }

            # Sort by date and remove oldest backups
            $sortedBackupPaths = ($backups.GetEnumerator() | Sort-Object -Property Value | ForEach-Object { $_.Key })
            $backupsToRemove = $sortedBackupPaths.Count - $Keep

            Write-Verbose "Remove-DailyBackup:Process> Will remove $backupsToRemove old backup directories (keeping $Keep)" -Verbose:$verboseEnabled

            for ($i = 0; $i -lt $backupsToRemove; $i++)
            {
                $backupPath = $sortedBackupPaths[$i]
                $backupDate = Split-Path -Leaf $backupPath

                $confirmMessage = "Remove old backup directory for date $backupDate"
                if ($Force -or $PSCmdlet.ShouldProcess($backupPath, $confirmMessage))
                {
                    Write-Verbose "Remove-DailyBackup:Process> Removing old backup directory: $backupPath" -Verbose:$verboseEnabled
                    try
                    {
                        Remove-ItemAlternative -LiteralPath $backupPath -WhatIf:$WhatIfPreference -Verbose:$verboseEnabled
                        Write-Verbose "Remove-DailyBackup:Process> Successfully removed: $backupPath" -Verbose:$verboseEnabled
                    }
                    catch
                    {
                        Write-Error "Remove-DailyBackup:Process> Failed to remove directory '$backupPath': $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    end
    {
        Write-Verbose 'Remove-DailyBackup:End> Backup removal operation completed' -Verbose:$verboseEnabled
    }
}
