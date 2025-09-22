function Remove-DailyBackupInternal
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
        PS > Remove-DailyBackupInternal -Path 'C:\Backups' -BackupsToKeep 7

        Keeps the 7 most recent daily backup folders, removes older ones

    .EXAMPLE
        PS > Remove-DailyBackupInternal -Path '/home/user/backups' -BackupsToKeep 3 -WhatIf

        Shows which backup directories would be deleted without actually removing them

    .EXAMPLE
        PS > Remove-DailyBackupInternal -Path 'C:\DailyBackups' -BackupsToKeep 14

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
        [int] $BackupsToKeep
    )

    $qualifiedBackupDirs = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction 'SilentlyContinue' | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' })
    if ($qualifiedBackupDirs.Length -eq 0)
    {
        Write-Verbose "Remove-DailyBackupInternal> No qualified backup directories to delete were detected in: $Path"
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
                Write-Verbose "Remove-DailyBackupInternal> Removing old backup directory: $backupPath"
                Remove-ItemAlternative -LiteralPath $backupPath -WhatIf:$WhatIfPreference
                Write-Verbose "Remove-DailyBackupInternal> Successfully removed: $backupPath"
            }
        }
    }
    else
    {
        Write-Verbose 'Remove-DailyBackupInternal> No surplus daily backups to delete'
    }
}
