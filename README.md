# PowerShell Daily Backup

[![ci](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml)
[![release](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/release.yml/badge.svg)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/release.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/DailyBackup)](https://www.powershellgallery.com/packages/DailyBackup)
[![Tests](https://img.shields.io/badge/tests-passing-brightgreen)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml)
[![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE.txt)

> A PowerShell module for creating automated daily backups.

## Features

- **Complete backup and restore solution** - Full-featured backup creation and intelligent restoration
- **Enhanced file and directory support** - Intelligent handling of individual files with optimized naming and metadata
- **Date-organized backups** - Automatically creates folders with YYYY-MM-DD format
- **Multiple source support** - Backup multiple files and directories in a single operation
- **Automatic cleanup** - Configurable retention policy to automatically remove old backups
- **Metadata preservation** - Stores detailed information about backed up items for tracking and restoration
- **Flexible restore options** - Restore to original locations or custom destinations with filtering
- **Cross-platform** - Works on Windows, macOS, and Linux with PowerShell Core

## Quick Start

### Installation

```powershell
Install-Module -Name DailyBackup -Scope CurrentUser
```

### Basic Usage

```powershell
# Simple directory backup
New-DailyBackup -Path "C:\MyDocuments" -Destination "D:\Backups"

# Individual file backup with metadata
New-DailyBackup -Path "C:\important-report.pdf" -Destination "D:\Backups"

# Multiple files and directories with cleanup (keep last 7 days)
New-DailyBackup -Path @("C:\Documents", "C:\Pictures", "C:\config.txt") -Destination "D:\Backups" -Keep 7

# Test run (see what would be backed up)
New-DailyBackup -Path "C:\Important" -Destination "D:\Backups" -WhatIf -Verbose
```

### Restore Usage

```powershell
# Restore most recent backup to a specific location
Restore-DailyBackup -BackupRoot "D:\Backups" -DestinationPath "C:\Restored"

# Restore specific date to original locations
Restore-DailyBackup -BackupRoot "D:\Backups" -Date "2025-09-15" -UseOriginalPaths

# Restore only specific files
Restore-DailyBackup -BackupRoot "D:\Backups" -BackupName "*Documents*" -DestinationPath "C:\Emergency"

# See what would be restored (dry run)
Restore-DailyBackup -BackupRoot "D:\Backups" -DestinationPath "C:\Test" -WhatIf
```

### Updating

```powershell
Update-Module -Name DailyBackup
```

## Documentation

### Complete Reference

- **[Full Documentation](docs/help.md)** - Comprehensive user guide with examples and troubleshooting
- **[Development Guide](docs/development.md)** - Testing, contributing, and development setup
- **[Command Reference](#command-reference)** - Detailed command and parameter descriptions (above)
- **[Changelog](CHANGELOG.md)** - Version history and improvements

### Command Reference

#### New-DailyBackup

Creates automated daily backups with progress tracking and cleanup.

```powershell
New-DailyBackup [-Path] <String[]> [-Destination <String>] [-Keep <Int32>] [-FileBackupMode <String>] [-WhatIf] [-Verbose]
```

**Parameters:**

- **-Path** (required): Source file(s) or directory(ies) to backup
- **-Destination**: Root directory for backups (default: current directory)
- **-Keep**: Number of daily backups to retain (default: -1, keep all)
- **-FileBackupMode**: How to handle files - Individual, Combined, or Auto (default: Auto)

#### Restore-DailyBackup

Restores files and directories from backup archives with flexible destination options.

```powershell
Restore-DailyBackup [-BackupRoot] <String> [-DestinationPath <String>] [-Date <String>] [-BackupName <String>] [-UseOriginalPaths] [-PreservePaths] [-Force] [-WhatIf] [-Verbose]
```

**Parameters:**

- **-BackupRoot** (required): Root directory containing daily backup folders
- **-DestinationPath**: Where to restore files (required unless -UseOriginalPaths)
- **-Date**: Specific backup date to restore (YYYY-MM-DD format, default: latest)
- **-BackupName**: Pattern to match specific backup files (supports wildcards)
- **-UseOriginalPaths**: Restore to original source locations using metadata
- **-PreservePaths**: Maintain directory structure during extraction
- **-Force**: Overwrite existing files without prompting

#### Get-BackupInfo

Retrieves detailed information about available backups.

```powershell
Get-BackupInfo [-BackupRoot] <String> [-Date <String>]
```

**Parameters:**

- **-BackupRoot** (required): Root directory containing daily backup folders
- **-Date**: Specific date to query (YYYY-MM-DD format, default: all dates)

## Examples

### Example 1: Basic Daily Backup

```powershell
New-DailyBackup -Path "C:\Users\$env:USERNAME\Documents" -Destination "D:\Backups"
```

Creates a backup in `D:\Backups\2025-09-15` with ZIP files containing your documents and a consolidated metadata manifest.

### Example 2: Individual File Backup

```powershell
New-DailyBackup -Path "C:\Users\$env:USERNAME\important-report.pdf" -Destination "D:\Backups"
```

Creates a backup of a single file with enhanced naming: `D:\Backups\2025-09-15\Users__[username]__important-report.pdf.zip`

### Example 2: Multiple Sources with Cleanup

```powershell
New-DailyBackup `
    -Path @('C:\Users\Ron\Documents', 'C:\Users\Ron\Music', 'C:\Users\Ron\config.json') `
    -Destination 'C:\Users\Ron\iCloudDrive' `
    -Keep 7 `
    -Verbose
```

Backs up multiple directories and files, keeps only the latest 7 daily backups, with detailed progress output and consolidated metadata.

### Example 3: Test Run (WhatIf)

```powershell
New-DailyBackup -Path "C:\Important" -Destination "D:\Backup" -WhatIf -Verbose
```

Shows exactly what would be backed up without actually creating any files.

### Example 4: Basic Restore

```powershell
Restore-DailyBackup -BackupRoot "D:\Backups" -DestinationPath "C:\Restored"
```

Restores the most recent backup set to `C:\Restored` directory.

### Example 5: Restore to Original Locations

```powershell
Restore-DailyBackup -BackupRoot "D:\Backups" -Date "2025-09-15" -UseOriginalPaths
```

Restores backups from September 15, 2025 to their original source locations using metadata.

### Example 6: Selective Restore

```powershell
Restore-DailyBackup -BackupRoot "D:\Backups" -BackupName "*Documents*" -DestinationPath "C:\Emergency"
```

Restores only backup files matching the "_Documents_" pattern to an emergency recovery location.

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
    Write-Host "[SUCCESS] Backup completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "[FAILED] Backup failed: $_"
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
