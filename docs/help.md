# DailyBackup Module Help Documentation

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Detailed Usage](#detailed-usage)
5. [Parameters](#parameters)
6. [Examples](#examples)
7. [Configuration](#configuration)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)
10. [FAQ](#faq)

## Overview

The DailyBackup PowerShell module provides a simple yet powerful solution for creating automated daily backups of your important files and directories. The module creates compressed ### 7. Monitoring

- **Logging**: Enable verbose logg### Example 16: Backup Without Cleanup

```powershell
# Create backup without removing old ones (manual cleanup)
New-DailyBackup -Path "C:\Projects" -Destination "D:\Backups" -NoCleanup

# Create backup with Keep setting but skip cleanup this time
New-DailyBackup -Path "C:\Projects" -Destination "D:\Backups" -Keep 7 -NoCleanup
```

### Example 17: Force Replace Existing Backup

```powershell
# Replace existing backup for today without prompting
New-DailyBackup -Path "C:\CriticalData" -Destination "D:\Backups" -Force

# Automation-friendly backup with force and cleanup
New-DailyBackup -Path "C:\ImportantFiles" -Destination "D:\Backups" -Keep 30 -Force -Verbose

# Force backup in scheduled script (no user interaction needed)
New-DailyBackup -Path @("C:\Documents", "C:\Projects") -Destination "D:\AutoBackups" -Force -Keep 14
```utomated backups
- **Notifications**: Set up alerts for backup failures
- **Validation**: Regularly verify backup integrity using `Test-DailyBackup`rchives organized by date, making it easy to track and manage your backup history.

### Key Features

- **Date-organized backups**: Automatically creates folders with YYYY-MM-DD format
- **Multiple source paths**: Backup multiple files and directories in a single operation
- **Automatic cleanup**: Configurable retention policy to automatically remove old backups
- **Cross-platform**: Works on Windows, macOS, and Linux with PowerShell Core
- **WhatIf support**: Test your backup operations without making changes
- **Verbose logging**: Detailed output for troubleshooting and monitoring
- **Progress tracking**: Visual progress indicators for long operations

## Installation

### From PowerShell Gallery (Recommended)

```powershell
Install-Module -Name DailyBackup -Scope CurrentUser
```

### From GitHub

```powershell
# Download and extract the latest release
Invoke-WebRequest -Uri "https://github.com/jonlabelle/pwsh-daily-backup/archive/main.zip" -OutFile "DailyBackup.zip"
Expand-Archive -Path "DailyBackup.zip" -DestinationPath "."

# Import the module
Import-Module "./pwsh-daily-backup-main/DailyBackup.psd1"
```

### Manual Installation

1. Download the module files from GitHub
2. Create a folder named `DailyBackup` in your PowerShell modules directory
3. Copy `DailyBackup.psd1` and `DailyBackup.psm1` to the folder
4. Import the module: `Import-Module DailyBackup`

## Quick Start

### Basic Backup

Create a backup of a single directory:

```powershell
New-DailyBackup -Path "C:\MyDocuments" -Destination "C:\Backups"
```

### Multiple Sources

Backup multiple locations at once:

```powershell
New-DailyBackup -Path @("C:\Documents", "C:\Pictures", "C:\Projects") -Destination "D:\Backups"
```

### With Cleanup

Keep only the last 7 backups:

```powershell
New-DailyBackup -Path "C:\Important" -Destination "C:\Backups" -Keep 7
```

### Test Run

Preview what would be backed up without actually creating files:

```powershell
New-DailyBackup -Path "C:\Data" -Destination "C:\Backups" -WhatIf
```

## Quick Start - Restore

### Basic Restore

Restore the most recent backup to a specific location:

```powershell
Restore-DailyBackup -BackupRoot "C:\Backups" -DestinationPath "C:\Restored"
```

### Restore to Original Locations

Restore files to their original paths using metadata:

```powershell
Restore-DailyBackup -BackupRoot "C:\Backups" -UseOriginalPaths
```

### Restore Specific Date

Restore backups from a specific date:

```powershell
Restore-DailyBackup -BackupRoot "C:\Backups" -Date "2025-09-15" -DestinationPath "C:\Emergency"
```

### Get Backup Information

View available backups before restoring:

```powershell
Get-DailyBackup -BackupRoot "C:\Backups"
```

### Test Restore

Preview what would be restored without actually extracting files:

```powershell
Restore-DailyBackup -BackupRoot "C:\Backups" -DestinationPath "C:\Test" -WhatIf
```

## Detailed Usage

### Backup Commands

#### New-DailyBackup

```powershell
New-DailyBackup
    -Path <String[]>
    [-Destination <String>]
    [-Keep <Int32>]
    [-FileBackupMode <String>]
    [-NoHash]
    [-NoCleanup]
    [-Force]
    [-WhatIf]
    [-Verbose]
    [<CommonParameters>]
```

### Restore Commands

#### Restore-DailyBackup

```powershell
Restore-DailyBackup
    -BackupRoot <String>
    [-DestinationPath <String>]
    [-Date <String>]
    [-BackupName <String>]
    [-UseOriginalPaths]
    [-PreservePaths]
    [-Force]
    [-WhatIf]
    [-Verbose]
    [<CommonParameters>]
```

#### Get-DailyBackup

```powershell
Get-DailyBackup
    -BackupRoot <String>
    [-Date <String>]
    [<CommonParameters>]
```

### Management Commands

#### Remove-DailyBackup

```powershell
Remove-DailyBackup
    -Path <String>
    [-Keep <Int32>]
    [-Date <String>]
    [-Force]
    [-WhatIf]
    [-Verbose]
    [<CommonParameters>]
```

Removes old backup directories based on retention policies or specific dates.

#### Test-DailyBackup

```powershell
Test-DailyBackup
    -BackupRoot <String>
    [-Date <String>]
    [-BackupName <String>]
    [-VerifySource]
    [-WhatIf]
    [-Verbose]
    [<CommonParameters>]
```

Verifies backup integrity using SHA-256 hash values stored in backup metadata. Can verify individual backup archives or compare with source files to detect changes.

### Pipeline Support

The cmdlet supports pipeline input for the Path parameter:

```powershell
@("C:\Folder1", "C:\Folder2") | New-DailyBackup -Destination "C:\Backups"
```

```powershell
Get-ChildItem C:\Projects -Directory | ForEach-Object { $_.FullName } | New-DailyBackup -Destination "D:\ProjectBackups"
```

## Parameters

### -Path (Required)

**Type**: `String[]`
**Position**: 0
**Pipeline Input**: Yes (ByValue, ByPropertyName)

Specifies the source file or directory path(s) to backup. Supports:

- Absolute paths: `C:\Users\John\Documents`
- Relative paths: `.\MyFolder` or `..\ParentFolder`
- Multiple paths: `@("Path1", "Path2", "Path3")`
- Wildcard patterns: `C:\Data\*.txt` (resolved before backup)

### -Destination

**Type**: `String`
**Position**: 1
**Default**: Current directory (`.`)

The root directory where daily backup folders will be created. Each backup session creates a subfolder named with the current date (YYYY-MM-DD format).

### -Keep

**Type**: `Int32`
**Default**: `-1` (keep all backups)
**Alias**: `DailyBackupsToKeep`

Number of daily backup folders to retain. When exceeded, the oldest backups are deleted first. Set to -1 to keep all backups indefinitely.

**Examples:**

- `-1`: Keep all backups (no cleanup)
- `0`: Delete all existing backups
- `1`: Keep only today's backup
- `7`: Keep the last week of backups
- `30`: Keep the last month of backups

### -NoCleanup

**Type**: `SwitchParameter`
**Default**: `$false`

Skips automatic cleanup of old backup directories. When specified, the Keep parameter is ignored and no old backups will be removed regardless of the retention policy. Use this when you want to manually manage backup cleanup or when running backups that should not affect existing backup retention.

**Examples:**

```powershell
# Create backup without any cleanup
New-DailyBackup -Path "C:\Data" -Destination "D:\Backups" -NoCleanup

# Create backup with Keep setting but skip cleanup
New-DailyBackup -Path "C:\Data" -Destination "D:\Backups" -Keep 7 -NoCleanup
```

### -Force

**Type**: `SwitchParameter`
**Default**: `$false`

Replace existing backup directory for the same date without prompting. When specified, any existing backup directory with today's date will be automatically removed before creating the new backup. Without this parameter, the function will prompt for confirmation when a backup directory for today already exists.

**Examples:**

```powershell
# Replace existing backup without prompting
New-DailyBackup -Path "C:\ImportantFiles" -Destination "D:\Backups" -Force

# Combine with automation-friendly parameters
New-DailyBackup -Path "C:\Data" -Destination "D:\Backups" -Keep 30 -Force -Verbose
```

### -FileBackupMode

**Type**: `String`
**Default**: `Auto`
**ValidateSet**: `Individual`, `Combined`, `Auto`

Controls how multiple files are packaged into backup archives. This parameter provides flexibility in organizing your backups based on your restoration and storage needs.

**Modes:**

- **`Individual`**: Creates separate ZIP archives for each source path
  - Best for: Selective restoration, smaller individual backups
  - Example: `file1.txt` → `file1.txt.zip`, `file2.txt` → `file2.txt.zip`

- **`Combined`**: Creates a single ZIP archive containing all source paths
  - Best for: Fewer archive files, backing up related files together
  - Example: `file1.txt`, `file2.txt` → `CombinedFiles_123456.zip`

- **`Auto`**: Intelligently chooses the best mode based on input
  - Uses Combined mode for 4+ files (files only, no directories)
  - Uses Individual mode for 3 or fewer files, or when directories are included
  - Best for: Hands-off operation with optimal packaging

**Examples:**

```powershell
# Individual mode - each file gets its own archive
New-DailyBackup -Path @("file1.txt", "file2.txt") -Destination "D:\Backups" -FileBackupMode Individual

# Combined mode - all files in one archive
New-DailyBackup -Path @("*.txt") -Destination "D:\Backups" -FileBackupMode Combined

# Auto mode - intelligent selection (default)
New-DailyBackup -Path @("file1.txt", "file2.txt", "docs\") -Destination "D:\Backups" -FileBackupMode Auto
```

## Restore Parameters

### -BackupRoot (Required)

**Type**: `String`
**Position**: 0
**Pipeline Input**: No

The root directory containing daily backup folders in YYYY-MM-DD format. This should be the same directory that was used as the `-Destination` parameter when creating backups with `New-DailyBackup`.

### -DestinationPath

**Type**: `String`
**Position**: Named
**Pipeline Input**: No

The destination directory where restored files will be placed. Required unless `-UseOriginalPaths` is specified.

### -Date

**Type**: `String`
**Position**: Named
**Pipeline Input**: No
**Validation**: Must match YYYY-MM-DD pattern

Specific backup date to restore from. If not specified, uses the most recent backup date available.

### -BackupName

**Type**: `String`
**Position**: Named
**Pipeline Input**: No

Optional pattern to match specific backup files by name. Supports wildcards (e.g., `*Documents*`, `*.pdf*`). If not specified, restores all backups from the specified date.

### -UseOriginalPaths

**Type**: `Switch`
**Position**: Named
**Pipeline Input**: No

When enabled, attempts to restore files to their original source locations using metadata information. Requires metadata files to be present. When disabled, restores all files to the specified `-DestinationPath`.

### -PreservePaths

**Type**: `Switch`
**Position**: Named
**Pipeline Input**: No

Controls whether directory structure within backups is preserved during restoration. When enabled, maintains folder hierarchy from the backup.

### -Force

**Type**: `Switch`
**Position**: Named
**Pipeline Input**: No

Overwrites existing files during restoration without prompting. Use with caution as this can replace current files.

### Common Parameters

The cmdlet supports all PowerShell common parameters:

- `-WhatIf`: Preview operations without making changes
- `-Verbose`: Show detailed operation information
- `-ErrorAction`: Control how errors are handled
- `-WarningAction`: Control how warnings are handled

## Remove-DailyBackup Parameters

### Remove-DailyBackup -Path (Required)

**Type**: `String`
**Position**: 0
**Pipeline Input**: Yes (ByValue, ByPropertyName)
**Aliases**: `BackupRoot`, `DestinationPath`

The root directory path where daily backup folders are stored, or the specific backup directory to remove when using -Date parameter. This should be the parent directory containing date-named subdirectories (e.g., '2025-08-24').

### Remove-DailyBackup -Keep

**Type**: `Int32`
**Default**: `7`
**Position**: Named
**Aliases**: `BackupsToKeep`
**Validation**: Must be 0 or greater

The minimum number of backup directories to retain when using retention-based cleanup. Older backups beyond this number will be deleted, sorted by date with oldest removed first. Set to 0 to remove all backups. Cannot be used with -Date parameter.

### Remove-DailyBackup -Date

**Type**: `String`
**Position**: Named
**Validation**: Must match YYYY-MM-DD pattern

Specific backup date to remove (yyyy-MM-dd format). When specified, only the backup directory for this date will be removed. Cannot be used with -Keep parameter.

### Remove-DailyBackup -Force

**Type**: `SwitchParameter`
**Default**: `$false`

Bypass confirmation prompts and remove backups without user interaction. Use with caution as this will permanently delete backup data.

## Test-DailyBackup Parameters

### Test-DailyBackup -BackupRoot (Required)

**Type**: `String`
**Position**: 0
**Pipeline Input**: No

The root directory path containing daily backup folders in YYYY-MM-DD format. This should be the same directory that was used as the `-Destination` parameter when creating backups with `New-DailyBackup`.

### Test-DailyBackup -Date

**Type**: `String`
**Position**: Named
**Pipeline Input**: No
**Validation**: Must match YYYY-MM-DD pattern

Specific backup date to verify (yyyy-MM-dd format). If not specified, verifies the most recent backup date available.

### Test-DailyBackup -BackupName

**Type**: `String`
**Position**: Named
**Pipeline Input**: No

Optional pattern to match specific backup files by name. Supports wildcards (e.g., `*Documents*`, `*.pdf*`). If not specified, verifies all backups from the specified date.

### Test-DailyBackup -VerifySource

**Type**: `SwitchParameter`
**Default**: `$false`

When enabled, also verifies that source files still match their original SHA-256 hashes stored in backup metadata. This helps detect if source files have been modified since backup. Only works if source files are still accessible.

## Examples

### Example 1: Daily Document Backup

```powershell
# Backup documents folder daily, keeping last 30 days
New-DailyBackup -Path "C:\Users\$env:USERNAME\Documents" -Destination "D:\Backups\Documents" -Keep 30 -Verbose
```

### Example 2: Multiple Project Folders

```powershell
# Backup all project directories
$ProjectPaths = @(
    "C:\Development\Project1",
    "C:\Development\Project2",
    "C:\Development\Project3"
)

New-DailyBackup -Path $ProjectPaths -Destination "E:\ProjectBackups" -Keep 14
```

### Example 3: System Configuration Backup

```powershell
# Backup important system configurations (Windows)
$SystemPaths = @(
    "$env:APPDATA\Microsoft\Windows\PowerShell",
    "$env:USERPROFILE\.ssh",
    "$env:USERPROFILE\.gitconfig"
)

New-DailyBackup -Path $SystemPaths -Destination "C:\SystemBackups" -Keep 7 -Verbose
```

### Example 4: Scheduled Task Integration

Create a scheduled task to run daily backups:

```powershell
# Create a scheduled task for daily backups
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command `"Import-Module DailyBackup; New-DailyBackup -Path 'C:\Important' -Destination 'D:\Backups' -Keep 30 -Force`""
$Trigger = New-ScheduledTaskTrigger -Daily -At "2:00 AM"
Register-ScheduledTask -TaskName "DailyBackup" -Action $Action -Trigger $Trigger -Description "Automated daily backup using DailyBackup module"
```

### Example 5: Cross-Platform Home Directory Backup

```powershell
# Works on Windows, macOS, and Linux
$HomeDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
    $env:USERPROFILE
} else {
    $env:HOME
}

New-DailyBackup -Path "$HomeDir/Documents" -Destination "$HomeDir/Backups" -Keep 7
```

### Example 6: Error Handling

```powershell
try {
    New-DailyBackup -Path "C:\ImportantData" -Destination "D:\Backups" -Keep 30 -ErrorAction Stop
    Write-Host "Backup completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Backup failed: $_"
    # Send notification, log to file, etc.
}
```

### Example 7: Restore Latest Backup

```powershell
# Restore the most recent backup to a new location
Restore-DailyBackup -BackupRoot "D:\Backups\Documents" -DestinationPath "C:\Restored\Documents" -Verbose
```

### Example 8: Restore Specific Date

```powershell
# Restore backup from a specific date
Restore-DailyBackup -BackupRoot "D:\Backups\Documents" -Date "2024-01-15" -DestinationPath "C:\Restored\January15" -Verbose
```

### Example 9: Restore to Original Locations

```powershell
# Restore files back to their original source locations
Restore-DailyBackup -BackupRoot "D:\Backups\Documents" -UseOriginalPaths -Force -Verbose
```

### Example 10: Restore Specific Files

```powershell
# Restore only specific files matching a pattern
Restore-DailyBackup -BackupRoot "D:\Backups" -BackupName "*Project*" -DestinationPath "C:\Restored\Projects" -Verbose
```

### Example 11: Preview Restore Operation

```powershell
# See what would be restored without actually doing it
Restore-DailyBackup -BackupRoot "D:\Backups\Documents" -DestinationPath "C:\Restored" -WhatIf -Verbose
```

### Example 12: Get Backup Information

```powershell
# List all available backups
Get-DailyBackup -BackupRoot "D:\Backups\Documents"

# Get detailed info for a specific date
Get-DailyBackup -BackupRoot "D:\Backups\Documents" -Date "2024-01-15" -Verbose

# Find backups matching a pattern
Get-DailyBackup -BackupRoot "D:\Backups" -BackupName "*Documents*"
```

### Example 13: Remove Old Backups

```powershell
# Remove old backups, keeping only the last 7 days
Remove-DailyBackup -Path "D:\Backups" -Keep 7

# Remove all backups older than 30 days
Remove-DailyBackup -Path "D:\Backups" -Keep 30 -Verbose

# Preview what would be removed
Remove-DailyBackup -Path "D:\Backups" -Keep 7 -WhatIf
```

### Example 14: Remove Specific Backup Date

```powershell
# Remove backup for a specific date
Remove-DailyBackup -Path "D:\Backups" -Date "2024-01-15"

# Force removal without confirmation
Remove-DailyBackup -Path "D:\Backups" -Date "2024-01-15" -Force

# Pipeline support
"D:\Backups" | Remove-DailyBackup -Date "2024-01-15"
```

### Example 15: Backup Without Cleanup

```powershell
# Create backup without removing old ones (manual cleanup)
New-DailyBackup -Path "C:\Projects" -Destination "D:\Backups" -NoCleanup

# Create backup with Keep setting but skip cleanup this time
New-DailyBackup -Path "C:\Projects" -Destination "D:\Backups" -Keep 7 -NoCleanup
```

### Example 16: Verify Backup Integrity

```powershell
# Verify integrity of most recent backups
Test-DailyBackup -BackupRoot "D:\Backups"

# Verify specific backup date
Test-DailyBackup -BackupRoot "D:\Backups" -Date "2024-01-15" -Verbose

# Verify only specific backup files
Test-DailyBackup -BackupRoot "D:\Backups" -BackupName "*Documents*"

# Verify backups and check if source files have changed
Test-DailyBackup -BackupRoot "D:\Backups" -Date "2024-01-15" -VerifySource -Verbose
```

## Configuration

### Default Behavior

- **Destination**: Current directory if not specified
- **Retention**: Keeps all backups (no cleanup) if not specified
- **Compression**: Uses ZIP compression for all archives
- **Naming**: Uses YYYY-MM-DD format for date folders
- **Duplicates**: Appends random string if backup already exists

### Customizing Behavior

The module uses sensible defaults for all operations. You can customize behavior by:

- Using different parameter values for each backup operation
- Creating wrapper scripts with your preferred settings
- Setting up scheduled tasks with specific configurations

## Troubleshooting

### Common Issues

#### Issue: "Access Denied" Errors

**Symptoms**: Cannot delete or access certain files/folders
**Cause**: Insufficient permissions or files in use
**Solution**:

- Run PowerShell as Administrator
- Close applications that might be using the files
- Use the `-Verbose` parameter to identify problematic files

```powershell
# Example with verbose output
New-DailyBackup -Path "C:\MyData" -Destination "D:\Backup" -Verbose
```

#### Issue: Long Path Names

**Symptoms**: Errors about path length exceeding limits
**Cause**: Windows has a 260-character path length limit
**Solution**:

- Use shorter destination paths
- Enable long path support in Windows 10/11
- Use UNC paths for network locations

#### Issue: Large File Performance

**Symptoms**: Backup takes very long time or fails
**Cause**: Very large files or many small files
**Solution**:

- Exclude unnecessary large files
- Use SSD storage for better performance
- Consider breaking up very large directories

### Debugging

Enable detailed logging:

```powershell
# Maximum verbosity
$VerbosePreference = "Continue"
New-DailyBackup -Path "C:\Data" -Destination "C:\Backup" -Verbose
```

Check for module issues:

```powershell
# Test module import
Import-Module DailyBackup -Force -Verbose

# Check module information
Get-Module DailyBackup | Format-List

# Test with WhatIf first
New-DailyBackup -Path "C:\TestData" -Destination "C:\TestBackup" -WhatIf -Verbose
```

## Best Practices

### 1. Backup Strategy

- **Regular Schedule**: Run backups daily at the same time
- **Multiple Destinations**: Consider backing up to both local and remote locations
- **Test Restores**: Regularly test that you can restore from your backups
- **Version Control**: Use appropriate retention periods for your needs

### 2. Path Management

- **Absolute Paths**: Use full paths in scripts for reliability
- **Path Validation**: Test paths before running automated backups
- **Special Characters**: Be careful with paths containing spaces or special characters

```powershell
# Good practice: validate paths first
$BackupPaths = @("C:\Documents", "C:\Pictures")
foreach ($Path in $BackupPaths) {
    if (-not (Test-Path $Path)) {
        Write-Warning "Path not found: $Path"
        continue
    }
    New-DailyBackup -Path $Path -Destination "D:\Backups"
}
```

### 3. Storage Management

- **Monitor Disk Space**: Regularly check backup destination free space
- **Retention Policy**: Set appropriate `Keep` values
- **Compression**: ZIP compression is automatic but consider external tools for better compression

### 4. Restore Strategy

- **Test Restores**: Regularly test restore operations to verify backup integrity
- **Restore Location**: Never restore directly over live data without backups
- **Preview First**: Use `-WhatIf` to preview restore operations
- **Document Procedures**: Document restore procedures for emergency situations

```powershell
# Good practice: test restore to temporary location first
Restore-DailyBackup -BackupRoot "D:\Backups" -DestinationPath "C:\RestoreTest" -WhatIf -Verbose

# If satisfied, perform actual restore
Restore-DailyBackup -BackupRoot "D:\Backups" -DestinationPath "C:\RestoreTest" -Verbose
```

### 5. Backup Integrity Verification

- **Regular Verification**: Use `Test-DailyBackup` to verify backup archives
- **Hash Calculation**: Enabled by default using SHA-256 for all backups
- **Performance Trade-off**: Use `-NoHash` for simple scenarios where verification isn't needed
- **Source Verification**: Use `-VerifySource` to check if original files have changed

```powershell
# Verify recent backup integrity
Test-DailyBackup -BackupRoot "D:\Backups" -Verbose

# Verify specific date with source file checking
Test-DailyBackup -BackupRoot "D:\Backups" -Date "2025-09-15" -VerifySource

# Performance mode for large backups
New-DailyBackup -Path "C:\BigData" -Destination "D:\Backups" -NoHash
```

### 6. Security

- **Permissions**: Ensure backup destinations have appropriate access controls
- **Encryption**: Consider encrypting backup destinations
- **Network Security**: Use secure protocols for remote backups
- **Integrity Verification**: Use built-in hash verification to detect corruption

### 7. Monitoring

- **Logging**: Enable verbose logging for automated backups
- **Notifications**: Set up alerts for backup failures
- **Validation**: Regularly verify backup integrity

```powershell
# Example: Backup with notification
try {
    New-DailyBackup -Path "C:\Important" -Destination "D:\Backup" -Keep 7
    # Send success notification
}
catch {
    # Send failure notification
    Send-MailMessage -To "admin@company.com" -Subject "Backup Failed" -Body $_.Exception.Message
}
```

## FAQ

### Q: Can I backup to network locations?

**A**: Yes, you can use UNC paths or mapped network drives:

```powershell
New-DailyBackup -Path "C:\Data" -Destination "\\server\backups\mycomputer"
```

### Q: What happens if I run the backup multiple times in one day?

**A**: The module will detect existing backups for the current date and append a random identifier to avoid conflicts.

### Q: Can I exclude certain files or folders?

**A**: The current version doesn't have built-in exclusion filters, but you can pre-filter your paths:

```powershell
$FilteredPaths = Get-ChildItem "C:\Data" -Directory | Where-Object { $_.Name -notlike "temp*" }
$FilteredPaths | ForEach-Object { New-DailyBackup -Path $_.FullName -Destination "D:\Backup" }
```

### Q: How do I restore files from a backup?

**A**: Use the built-in restore functionality for the best experience:

```powershell
# Restore the latest backup
Restore-DailyBackup -BackupRoot "D:\Backups" -DestinationPath "C:\Restored"

# Or restore to original locations
Restore-DailyBackup -BackupRoot "D:\Backups" -UseOriginalPaths
```

You can also extract ZIP files manually using any ZIP utility:

```powershell
# Manual extraction using PowerShell
Expand-Archive -Path "D:\Backups\2023-12-01\MyData.zip" -DestinationPath "C:\Restored"
```

### Q: Can I compress backups with different algorithms?

**A**: The module uses .NET's built-in ZIP compression. For different compression formats, extract the files after backup and recompress with your preferred tool.

### Q: Does the module support incremental backups?

**A**: No, the current version creates full backups each time. Each backup is independent and complete.

### Q: What PowerShell versions are supported?

**A**:

- PowerShell 5.1 (Windows PowerShell)
- PowerShell 6.0+ (PowerShell Core) on Windows, macOS, and Linux

### Q: How do I automate backups?

**A**: Use Windows Task Scheduler, cron jobs, or PowerShell scheduled jobs:

```powershell
# Windows Task Scheduler (PowerShell)
Register-ScheduledTask -TaskName "DailyBackup" -Action $Action -Trigger $Trigger

# PowerShell Scheduled Job
Register-ScheduledJob -Name "DailyBackup" -ScriptBlock {
    Import-Module DailyBackup
    New-DailyBackup -Path "C:\Important" -Destination "D:\Backups" -Keep 30
} -Trigger (New-JobTrigger -Daily -At "3:00 AM")
```

### Q: Can I get email notifications?

**A**: The module doesn't have built-in email notifications, but you can add them to your scripts:

```powershell
try {
    New-DailyBackup -Path "C:\Data" -Destination "D:\Backup"
    Send-MailMessage -To "me@email.com" -Subject "Backup Success" -Body "Daily backup completed successfully"
}
catch {
    Send-MailMessage -To "me@email.com" -Subject "Backup Failed" -Body "Backup failed: $_"
}
```

---

For more information, visit the [project repository](https://github.com/jonlabelle/pwsh-daily-backup) or file an issue for support.
