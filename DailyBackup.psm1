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

# Get public and private function definition files
$PublicFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
$PrivateFunctions = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

# Dot source the functions
foreach ($function in @($PublicFunctions + $PrivateFunctions))
{
    try
    {
        . $function.FullName
    }
    catch
    {
        Write-Error -Message "Failed to import function $($function.FullName): $_"
    }
}

# Export only the public functions
Export-ModuleMember -Function $PublicFunctions.BaseName
