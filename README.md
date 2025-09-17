# PowerShell Daily Backup

[![ci](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml)
[![release](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/release.yml/badge.svg)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/release.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/DailyBackup)](https://www.powershellgallery.com/packages/DailyBackup)
[![Tests](https://img.shields.io/badge/tests-passing-brightgreen)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml)
[![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE.txt)

> A PowerShell module for creating automated daily backups.

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
  - [Installation](#installation)
  - [Basic Usage](#basic-usage)
- [Command Reference](#command-reference)
  - [`New-DailyBackup`](#new-dailybackup)
  - [`Restore-DailyBackup`](#restore-dailybackup)
  - [`Get-DailyBackup`](#get-dailybackup)
  - [`Test-DailyBackup`](#test-dailybackup)
  - [`Remove-DailyBackup`](#remove-dailybackup)
- [Examples](#examples)
  - [Example 1: Basic Daily Backup](#example-1-basic-daily-backup)
  - [Example 2: Individual File Backup](#example-2-individual-file-backup)
  - [Example 3: Multiple Sources with Cleanup](#example-3-multiple-sources-with-cleanup)
  - [Example 4: Test Run (WhatIf)](#example-4-test-run-whatif)
  - [Example 5: Basic Restore](#example-5-basic-restore)
  - [Example 6: Restore to Original Locations](#example-6-restore-to-original-locations)
  - [Example 7: Selective Restore](#example-7-selective-restore)
  - [Example 8: Scheduled Backup Script](#example-8-scheduled-backup-script)
  - [Example 9: Cross-Platform Home Backup](#example-9-cross-platform-home-backup)
  - [Example 10: Remove Old Backups](#example-10-remove-old-backups)
  - [Example 11: Backup Without Automatic Cleanup](#example-11-backup-without-automatic-cleanup)
- [Advanced Usage](#advanced-usage)
  - [Automation with Task Scheduler](#automation-with-task-scheduler)
  - [Handling Hash Conflicts and Integrity Issues](#handling-hash-conflicts-and-integrity-issues)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Complete backup and restore solution** - Full-featured backup creation and intelligent restoration
- **Enhanced file and directory support** - Intelligent handling of individual files with optimized naming and metadata
- **Date-organized backups** - Automatically creates folders with YYYY-MM-DD format
- **Multiple source support** - Backup multiple files and directories in a single operation
- **Automatic cleanup** - Configurable retention policy to automatically remove old backups
- **Metadata preservation** - Stores detailed information about backed up items for tracking and restoration
- **Flexible restore options** - Restore to original locations or custom destinations with filtering
- **Cross-platform** - Works on Windows, macOS, and Linux

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

### Backup Integrity Verification

```powershell
# Verify integrity of recent backups
Test-DailyBackup -BackupRoot "D:\Backups"

# Verify specific date and source files
Test-DailyBackup -BackupRoot "D:\Backups" -Date "2025-09-15" -VerifySource

# Performance mode (skip hash calculation)
New-DailyBackup -Path "C:\Documents" -Destination "D:\Backups" -NoHash
```

### Updating

```powershell
Update-Module -Name DailyBackup
```

## Command Reference

### `New-DailyBackup`

Creates automated daily backups with progress tracking and cleanup.

```powershell
New-DailyBackup [-Path] <String[]> [-Destination <String>] [-Keep <Int32>] [-FileBackupMode <String>] [-NoHash] [-NoCleanup] [-WhatIf] [-Verbose]
```

**Parameters:**

- **`-Path`** (required): Source file(s) or directory(ies) to backup
- **`-Destination`**: Root directory for backups (default: current directory)
- **`-Keep`**: Number of daily backups to retain (default: -1, keep all)
- **`-FileBackupMode`**: How to handle files - Individual, Combined, or Auto (default: Auto)
- **`-NoHash`**: Skip hash calculation for improved performance (disables integrity verification)
- **`-NoCleanup`**: Skip automatic cleanup of old backups, ignoring Keep setting

### `Restore-DailyBackup`

Restores files and directories from backup archives with flexible destination options.

```powershell
Restore-DailyBackup [-BackupRoot] <String> [-DestinationPath <String>] [-Date <String>] [-BackupName <String>] [-UseOriginalPaths] [-PreservePaths] [-Force] [-WhatIf] [-Verbose]
```

**Parameters:**

- **`-BackupRoot`** (required): Root directory containing daily backup folders
- **`-DestinationPath`**: Where to restore files (required unless -UseOriginalPaths)
- **`-Date`**: Specific backup date to restore (YYYY-MM-DD format, default: latest)
- **`-BackupName`**: Pattern to match specific backup files (supports wildcards)
- **`-UseOriginalPaths`**: Restore to original source locations using metadata
- **`-PreservePaths`**: Maintain directory structure during extraction
- **`-Force`**: Overwrite existing files without prompting

### `Get-DailyBackup`

Retrieves detailed information about available backups.

```powershell
Get-DailyBackup [-BackupRoot] <String> [-Date <String>]
```

**Parameters:**

- **`-BackupRoot`** (required): Root directory containing daily backup folders
- **`-Date`**: Specific date to query (YYYY-MM-DD format, default: all dates)

### `Test-DailyBackup`

Verifies backup integrity using SHA-256 hash values stored in backup metadata.

```powershell
Test-DailyBackup [-BackupRoot] <String> [-Date <String>] [-BackupName <String>] [-VerifySource]
```

**Parameters:**

- **`-BackupRoot`** (required): Root directory containing daily backup folders
- **`-Date`**: Specific backup date to verify (YYYY-MM-DD format, default: latest)
- **`-BackupName`**: Pattern to match specific backup files (supports wildcards)
- **`-VerifySource`**: Also verify that source files still match their original hashes

### `Remove-DailyBackup`

Removes old backup directories based on retention policies or removes specific backup dates. (Note: This is an internal helper function; for public cleanup, use the -Keep parameter in New-DailyBackup.)

```powershell
Remove-DailyBackup [-Path] <String> [-Keep <Int32>] [-Date <String>] [-Force] [-WhatIf] [-Verbose]
```

**Parameters:**

- **`-Path`** (required): Root directory containing daily backup folders
- **`-Keep`**: Number of backup directories to retain (default: 7, cannot be used with -Date)
- **`-Date`**: Specific backup date to remove (YYYY-MM-DD format, cannot be used with -Keep)
- **`-Force`**: Bypass confirmation prompts

## Examples

### Example 1: Basic Daily Backup

Create a backup in `D:\Backups\2025-09-15` with ZIP files containing your documents and a consolidated metadata manifest.

```powershell
New-DailyBackup -Path "C:\Users\$env:USERNAME\Documents" -Destination "D:\Backups"
```

### Example 2: Individual File Backup

Create a backup of a single file with enhanced naming: `D:\Backups\2025-09-15\Users__[username]__important-report.pdf.zip`.

```powershell
New-DailyBackup -Path "C:\Users\$env:USERNAME\important-report.pdf" -Destination "D:\Backups"
```

### Example 3: Multiple Sources with Cleanup

Back up multiple directories and files, keeping only the latest 7 daily backups with detailed progress output and consolidated metadata.

```powershell
New-DailyBackup `
    -Path @('C:\Users\Jon\Documents', 'C:\Users\Jon\Music', 'C:\Users\Jon\config.json') `
    -Destination 'C:\Users\Jon\iCloudDrive' `
    -Keep 7 `
    -Verbose
```

### Example 4: Test Run (WhatIf)

Show exactly what would be backed up without actually creating any files.

```powershell
New-DailyBackup -Path "C:\Important" -Destination "D:\Backup" -WhatIf -Verbose
```

### Example 5: Basic Restore

Restore the most recent backup set to `C:\Restored` directory.

```powershell
Restore-DailyBackup -BackupRoot "D:\Backups" -DestinationPath "C:\Restored"
```

### Example 6: Restore to Original Locations

Restore backups from September 15, 2025 to their original source locations using metadata.

```powershell
Restore-DailyBackup -BackupRoot "D:\Backups" -Date "2025-09-15" -UseOriginalPaths
```

### Example 7: Selective Restore

Restore only backup files matching the "_Documents_" pattern to an emergency recovery location.

```powershell
Restore-DailyBackup -BackupRoot "D:\Backups" -BackupName "*Documents*" -DestinationPath "C:\Emergency"
```

### Example 8: Scheduled Backup Script

Create a script for Windows Task Scheduler that backs up key directories with error handling and notifications.

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

### Example 9: Cross-Platform Home Backup

This works on Windows, macOS, and Linux by dynamically setting the home directory and backing up documents with a 14-day retention.

```powershell
# Works on Windows, macOS, and Linux
$HomeDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
    $env:USERPROFILE
} else {
    $env:HOME
}

New-DailyBackup -Path "$HomeDir/Documents" -Destination "$HomeDir/Backups" -Keep 14
```

### Example 10: Remove Old Backups

Remove old backups to keep only the last 7 days, remove a specific date, or preview what would be removed.

```powershell
# Remove old backups keeping only the last 7 days
Remove-DailyBackup -Path "D:\Backups" -Keep 7

# Remove a specific backup date
Remove-DailyBackup -Path "D:\Backups" -Date "2025-09-01" -Force

# Preview what would be removed
Remove-DailyBackup -Path "D:\Backups" -Keep 14 -WhatIf
```

### Example 11: Backup Without Automatic Cleanup

Create a backup without removing old ones, then manually clean up old backups later.

```powershell
# Create backup without removing old ones
New-DailyBackup -Path "C:\Projects" -Destination "D:\Backups" -NoCleanup

# Later, manually clean up old backups
Remove-DailyBackup -Path "D:\Backups" -Keep 30
```

## Advanced Usage

### Automation with Task Scheduler

```powershell
# Create scheduled task (Windows)
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-Command `"Import-Module DailyBackup; New-DailyBackup -Path 'C:\Important' -Destination 'D:\Backups' -Keep 30`""
$Trigger = New-ScheduledTaskTrigger -Daily -At "2:00 AM"
Register-ScheduledTask -TaskName "DailyBackup" -Action $Action -Trigger $Trigger
```

### Handling Hash Conflicts and Integrity Issues

Real-world scenarios for dealing with corrupted backups, changed source files, and integrity verification.

```powershell
# 1. Check backup integrity before restoration
$integrityResults = Test-DailyBackup -BackupRoot "D:\Backups" -Date "2025-09-15"
$corruptedBackups = $integrityResults | Where-Object { -not $_.ArchiveIntegrityValid }
if ($corruptedBackups) {
    Write-Warning "Found $($corruptedBackups.Count) corrupted backup(s). Restoring from previous day..."
    Restore-DailyBackup -BackupRoot "D:\Backups" -Date "2025-09-14" -DestinationPath "C:\Recovery"
}

# 2. Handle source file changes since backup
$sourceResults = Test-DailyBackup -BackupRoot "D:\Backups" -VerifySource -Verbose
$changedSources = $sourceResults | Where-Object { $_.SourceIntegrityValid -eq $false }
foreach ($changed in $changedSources) {
    Write-Host "Source changed: $($changed.Metadata.SourcePath)" -ForegroundColor Yellow
    # Decision: restore original or keep current version
}

# 3. Restore specific files when some backups are corrupted
$validBackups = $integrityResults | Where-Object { $_.ArchiveIntegrityValid -and $_.BackupName -like "*Documents*" }
if ($validBackups) {
    Restore-DailyBackup -BackupRoot "D:\Backups" -Date "2025-09-15" -BackupName "*Documents*" -DestinationPath "C:\SafeRestore"
}

# 4. Create new backup when integrity check fails
if ($corruptedBackups.Count -gt 0) {
    Write-Host "Creating fresh backup due to corruption..." -ForegroundColor Red
    New-DailyBackup -Path @("C:\Important", "C:\Projects") -Destination "D:\Backups" -Verbose
}

# 5. Compare backup dates to find best restore point
$allBackups = Get-DailyBackup -BackupRoot "D:\Backups"
$recentValid = foreach ($backup in $allBackups | Sort-Object Date -Descending) {
    $test = Test-DailyBackup -BackupRoot "D:\Backups" -Date $backup.Date
    if (($test | Where-Object { $_.ArchiveIntegrityValid }).Count -eq $test.Count) {
        $backup.Date; break
    }
}
Write-Host "Most recent valid backup: $recentValid" -ForegroundColor Green
```

## Additional Documentation

- **[Help](docs/help.md)** - Comprehensive user guide with examples and troubleshooting
- **[Development Guide](docs/development.md)** - Testing, contributing, and development setup
- **[Changelog](CHANGELOG.md)** - Version history and improvements

## Contributing

We welcome contributions! Please see the [Development Guide](docs/development.md) for setup instructions. Report [issues](https://github.com/jonlabelle/pwsh-daily-backup/issues) or submit [pull requests](https://github.com/jonlabelle/pwsh-daily-backup/pulls) on GitHub.

## License

[MIT](LICENSE.txt)
