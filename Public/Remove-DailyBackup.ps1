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
        Write-Verbose 'Remove-DailyBackup> Starting backup removal operation'
    }

    process
    {
        # Validate input path first
        if ([string]::IsNullOrWhiteSpace($Path))
        {
            Write-Error 'Remove-DailyBackup> Path parameter cannot be null or empty'
            return
        }

        # Normalize and resolve the input path
        $Path = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

        Write-Verbose "Remove-DailyBackup> Input path: '$Path'"

        # Resolve the path to ensure it exists
        try
        {
            $validatedBackupRootPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
            $normalizedBackupRootPath = $validatedBackupRootPath.Path
        }
        catch
        {
            Write-Error "Remove-DailyBackup> Cannot access path '$Path': $($_.Exception.Message)"
            return
        }

        Write-Verbose "Remove-DailyBackup> Processing backup root: $normalizedBackupRootPath"

        # Get qualified backup directories (matching yyyy-MM-dd pattern)
        $dateMatchingBackupDirectories = @(Get-ChildItem -LiteralPath $normalizedBackupRootPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' })

        if ($dateMatchingBackupDirectories.Length -eq 0)
        {
            Write-Verbose "Remove-DailyBackup> No qualified backup directories found in: $normalizedBackupRootPath"
            return
        }

        Write-Verbose "Remove-DailyBackup> Found $($dateMatchingBackupDirectories.Length) qualified backup directories"

        if ($PSCmdlet.ParameterSetName -eq 'SpecificDate')
        {
            # Remove specific date
            $specificDateBackupDirectory = $dateMatchingBackupDirectories | Where-Object { $_.Name -eq $Date }
            if (-not $specificDateBackupDirectory)
            {
                Write-Warning "Remove-DailyBackup> No backup found for date: $Date"
                return
            }

            $removalConfirmationPrompt = "Remove backup directory for date $Date"
            if ($Force -or $PSCmdlet.ShouldProcess($specificDateBackupDirectory.FullName, $removalConfirmationPrompt))
            {
                Write-Verbose "Remove-DailyBackup> Removing backup directory: $($specificDateBackupDirectory.FullName)"
                try
                {
                    Remove-ItemAlternative -LiteralPath $specificDateBackupDirectory.FullName -WhatIf:$WhatIfPreference
                    Write-Verbose "Remove-DailyBackup> Successfully removed: $($specificDateBackupDirectory.FullName)"
                }
                catch
                {
                    Write-Error "Remove-DailyBackup> Failed to remove directory '$($specificDateBackupDirectory.FullName)': $($_.Exception.Message)"
                }
            }
        }
        else
        {
            # Retention-based cleanup
            if ($dateMatchingBackupDirectories.Length -le $Keep)
            {
                Write-Verbose "Remove-DailyBackup> Current backup count ($($dateMatchingBackupDirectories.Length)) does not exceed retention limit ($Keep)"
                return
            }

            # Create hashtable to sort backup directories by date
            $backupDirectoriesWithDates = @{ }
            foreach ($currentBackupDirectory in $dateMatchingBackupDirectories)
            {
                try
                {
                    $backupDirectoriesWithDates.Add($currentBackupDirectory.FullName, [System.DateTime]::ParseExact($currentBackupDirectory.Name, 'yyyy-MM-dd', $null))
                }
                catch
                {
                    Write-Warning "Remove-DailyBackup> Skipping directory with invalid date format: $($currentBackupDirectory.Name)"
                }
            }

            # Sort by date and remove oldest backups
            $backupDirectoriesOrderedByDate = ($backupDirectoriesWithDates.GetEnumerator() | Sort-Object -Property Value | ForEach-Object { $_.Key })
            $numberOfDirectoriesToRemove = $backupDirectoriesOrderedByDate.Count - $Keep

            Write-Verbose "Remove-DailyBackup> Will remove $numberOfDirectoriesToRemove old backup directories (keeping $Keep)"

            for ($removalIndex = 0; $removalIndex -lt $numberOfDirectoriesToRemove; $removalIndex++)
            {
                $currentDirectoryPath = $backupDirectoriesOrderedByDate[$removalIndex]
                $currentDirectoryDate = Split-Path -Leaf $currentDirectoryPath

                $removalConfirmationPrompt = "Remove old backup directory for date $currentDirectoryDate"
                if ($Force -or $PSCmdlet.ShouldProcess($currentDirectoryPath, $removalConfirmationPrompt))
                {
                    Write-Verbose "Remove-DailyBackup> Removing old backup directory: $currentDirectoryPath"
                    try
                    {
                        Remove-ItemAlternative -LiteralPath $currentDirectoryPath -WhatIf:$WhatIfPreference
                        Write-Verbose "Remove-DailyBackup> Successfully removed: $currentDirectoryPath"
                    }
                    catch
                    {
                        Write-Error "Remove-DailyBackup> Failed to remove directory '$currentDirectoryPath': $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    end
    {
        Write-Verbose 'Remove-DailyBackup> Backup removal operation completed'
    }
}
