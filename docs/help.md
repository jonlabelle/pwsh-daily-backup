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

The DailyBackup PowerShell module provides a simple yet powerful solution for creating automated daily backups of your important files and directories. The module creates compressed ZIP archives organized by date, making it easy to track and manage your backup history.

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

## Detailed Usage

### Command Syntax

```powershell
New-DailyBackup
    -Path <String[]>
    [-Destination <String>]
    [-Keep <Int32>]
    [-WhatIf]
    [-Verbose]
    [<CommonParameters>]
```

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

### Common Parameters

The cmdlet supports all PowerShell common parameters:

- `-WhatIf`: Preview operations without making changes
- `-Verbose`: Show detailed operation information
- `-ErrorAction`: Control how errors are handled
- `-WarningAction`: Control how warnings are handled

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
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command `"Import-Module DailyBackup; New-DailyBackup -Path 'C:\Important' -Destination 'D:\Backups' -Keep 30`""
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

## Configuration

### Default Behavior

- **Destination**: Current directory if not specified
- **Retention**: Keeps all backups (no cleanup) if not specified
- **Compression**: Uses ZIP compression for all archives
- **Naming**: Uses YYYY-MM-DD format for date folders
- **Duplicates**: Appends random string if backup already exists

### Customizing Behavior

#### Environment Variables

Set these environment variables to change default behavior:

```powershell
$env:DAILYBACKUP_DEFAULT_DESTINATION = "D:\MyBackups"
$env:DAILYBACKUP_DEFAULT_RETENTION = "14"
```

#### Configuration File

Create a `DailyBackup.config.psd1` file in the module directory or user profile to customize settings (see DailyBackup.config.psd1 for full options).

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

### 4. Security

- **Permissions**: Ensure backup destinations have appropriate access controls
- **Encryption**: Consider encrypting backup destinations
- **Network Security**: Use secure protocols for remote backups

### 5. Monitoring

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

**A**: Backups are standard ZIP files. Extract them using any ZIP utility:

```powershell
# Using PowerShell
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
