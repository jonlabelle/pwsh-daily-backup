# PowerShell Daily Backup

[![ci](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml)
[![release](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/release.yml/badge.svg)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/release.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/DailyBackup)](https://www.powershellgallery.com/packages/DailyBackup)
[![Tests](https://img.shields.io/badge/tests-passing-brightgreen)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml)
[![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE.txt)

> A PowerShell module for creating automated daily backups.

## Features

- **📅 Date-organized backups** - Automatically creates folders with YYYY-MM-DD format
- **📁 Multiple source support** - Backup multiple files and directories in a single operation
- **🧹 Automatic cleanup** - Configurable retention policy to automatically remove old backups
- **🌐 Cross-platform** - Works on Windows, macOS, and Linux with PowerShell Core

## 🚀 Quick Start

### Installation

```powershell
Install-Module -Name DailyBackup -Scope CurrentUser
```

### Basic Usage

```powershell
# Simple backup
New-DailyBackup -Path "C:\MyDocuments" -Destination "D:\Backups"

# Multiple sources with cleanup (keep last 7 days)
New-DailyBackup -Path @("C:\Documents", "C:\Pictures") -Destination "D:\Backups" -Keep 7

# Test run (see what would be backed up)
New-DailyBackup -Path "C:\Important" -Destination "D:\Backups" -WhatIf -Verbose
```

### Updating

```powershell
Update-Module -Name DailyBackup
```

## Documentation

### Complete Reference

- **[Full Documentation](docs/help.md)** - Comprehensive user guide with examples and troubleshooting
- **[Development Guide](docs/development.md)** - Testing, contributing, and development setup
- **[Parameter Reference](#parameters)** - Detailed parameter descriptions (below)
- **[Changelog](CHANGELOG.md)** - Version history and improvements

### Command Reference

```console
NAME
    New-DailyBackup

SYNOPSIS
    Perform a daily backup with progress tracking and automatic cleanup.

SYNTAX
    New-DailyBackup [-Path] <String[]> [-Destination <String>] [-Keep <Int32>] [-WhatIf] [-Verbose]
```

## Parameters

### -Path &lt;String[]&gt;

The source file or directory path(s) to backup.

- **Required:** Yes
- **Position:** 1
- **Pipeline input:** Yes (ByValue, ByPropertyName)
- **Wildcards:** No

### -Destination &lt;String&gt;

The root directory path where daily backups will be stored.

- **Required:** No
- **Position:** 2
- **Default:** Current working directory (`.`)
- **Pipeline input:** No
- **Wildcards:** No

### -Keep &lt;Int32&gt;

The number of daily backups to keep when purging old backups. Oldest backups are deleted first.

- **Required:** No
- **Position:** Named
- **Default:** -1 (keep all backups)
- **Range:** -1 to 2147483647
- **Pipeline input:** No
- **Aliases:** DailyBackupsToKeep

### Common Parameters

Supports all PowerShell common parameters: `-WhatIf`, `-Verbose`, `-ErrorAction`, `-WarningAction`, etc.

[Learn more about CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216)

## Examples

### Example 1: Basic Daily Backup

```powershell
New-DailyBackup -Path "C:\Users\$env:USERNAME\Documents" -Destination "D:\Backups"
```

Creates a backup in `D:\Backups\2025-08-24` with ZIP files containing your documents.

### Example 2: Multiple Sources with Cleanup

```powershell
New-DailyBackup `
    -Path @('C:\Users\Ron\Documents', 'C:\Users\Ron\Music') `
    -Destination 'C:\Users\Ron\iCloudDrive' `
    -Keep 7 `
    -Verbose
```

Backs up multiple directories and keeps only the latest 7 daily backups, with detailed progress output.

### Example 3: Test Run (WhatIf)

```powershell
New-DailyBackup -Path "C:\Important" -Destination "D:\Backup" -WhatIf -Verbose
```

Shows exactly what would be backed up without actually creating any files.

### Example 4: Scheduled Backup Script

```powershell
# Create a script for Windows Task Scheduler
$BackupPaths = @(
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Pictures",
    "$env:USERPROFILE\.ssh"
)

try {
    New-DailyBackup -Path $BackupPaths -Destination "D:\DailyBackups" -Keep 30 -Verbose
    Write-Host "✅ Backup completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "❌ Backup failed: $_"
    # Send email notification, write to event log, etc.
}
```

### Example 5: Cross-Platform Home Backup

```powershell
# Works on Windows, macOS, and Linux
$HomeDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
    $env:USERPROFILE
} else {
    $env:HOME
}

New-DailyBackup -Path "$HomeDir/Documents" -Destination "$HomeDir/Backups" -Keep 14
```

## Advanced Usage

### Automation with Task Scheduler

```powershell
# Create scheduled task (Windows)
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command `"Import-Module DailyBackup; New-DailyBackup -Path 'C:\Important' -Destination 'D:\Backups' -Keep 30`""
$Trigger = New-ScheduledTaskTrigger -Daily -At "2:00 AM"
Register-ScheduledTask -TaskName "DailyBackup" -Action $Action -Trigger $Trigger
```

## License

[MIT](LICENSE.txt)
