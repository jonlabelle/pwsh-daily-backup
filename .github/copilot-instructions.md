# DailyBackup PowerShell Module - AI Coding Guidelines

## Cross-Platform Compatibility Requirements

**CRITICAL:** All code must be compatible with:

- PowerShell Desktop 5.1 (Windows only)
- PowerShell Core 6.2+ (Windows, macOS, Linux)

## Architecture Overview

This is a **modular PowerShell module** with separated Public and Private functions organized in dedicated folders. The module follows PowerShell best practices with three public functions and several internal helpers:

- **Public** (in `/Public/` folder): `New-DailyBackup`, `Restore-DailyBackup`, `Get-DailyBackupInfo`, `Test-DailyBackupIntegrity`
- **Private** (in `/Private/` folder): All helper functions following proper Verb-Noun naming conventions

### Module Structure

```
DailyBackup.psm1           # Main module with import logic
DailyBackup.psd1           # Module manifest
Public/                    # Public (exported) functions
├── Get-DailyBackupInfo.ps1
├── New-DailyBackup.ps1
└── Restore-DailyBackup.ps1
Private/                   # Private (internal) functions
├── Add-BackupMetadataFile.ps1
├── Compress-Backup.ps1
├── Get-PathType.ps1
├── Get-RandomFileName.ps1
├── New-BackupPath.ps1
├── Remove-DailyBackup.ps1
├── Remove-ItemAlternative.ps1
├── Resolve-UnverifiedPath.ps1
└── Restore-BackupFile.ps1
```

### Function Import Pattern

The main module (`DailyBackup.psm1`) uses dot-sourcing to import all functions:

```powershell
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
```

## Key Design Patterns

### Modular Function Organization

- **Public functions** in `/Public/` folder - exported and user-facing
- **Private functions** in `/Private/` folder - internal helpers with proper Verb-Noun naming
- **Automatic importing** via dot-sourcing pattern in main module
- **Clean separation** of concerns and improved maintainability

### PowerShell Naming Conventions

All private functions follow standard PowerShell Verb-Noun naming:

- `Get-PathType` (was `Get-PathType`)
- `Get-RandomFileName` (was `GetRandomFileName`)
- `New-BackupPath` (was `GenerateBackupPath`)
- `Compress-Backup` (was `CompressBackup`)
- `Add-BackupMetadataFile` (was `Add-BackupMetadataFile`)
- `Resolve-UnverifiedPath` (was `ResolveUnverifiedPath`)
- `Remove-ItemAlternative` (was `RemoveItemAlternative`)
- `Remove-DailyBackup` (was `RemoveDailyBackup`)
- `Restore-BackupFile` (was internal, now properly named)

### Date-Organized Storage Strategy

- Backups are stored in **yyyy-MM-dd** folders (e.g., `2025-09-15/`)
- Uses `$script:DefaultFolderDateFormat = 'yyyy-MM-dd'` and `$script:DefaultFolderDateRegex = '^\d{4}-\d{2}-\d{2}$'`
- Path transformation: `C:\Users\Jon\Documents` → `Users__Jon__Documents.zip`

### Metadata-Driven Restoration

- Each backup gets a `.metadata.json` file with original path, timestamps, and attributes
- Enables `Restore-DailyBackup -UseOriginalPaths` to restore to exact source locations
- Metadata format includes `BackupVersion = '2.0'`, `SourcePath`, `PathType` ('File'/'Directory')

### Cross-Platform Compatibility

- Uses `RemoveItemAlternative` function instead of `Remove-Item` for cloud storage compatibility
- Path handling works on Windows (`C:\`), macOS/Linux (`/home/`)
- Drive prefix removal: `Split-Path -NoQualifier` strips `C:` portion

## Development Workflow

### Build System

```powershell
# Use Build.ps1 for all development tasks
.\Build.ps1 -Task All         # Full build, test, analyze
.\Build.ps1 -Task Test        # Run Pester tests only
.\Build.ps1 -Task Analyze     # PSScriptAnalyzer only
```

### Testing Strategy

- **Unit tests**: `Tests/DailyBackup.Tests.ps1` (Pester-based, 14+ test cases)
- **Integration tests**: `Tests/IntegrationTests.ps1` (real backup scenarios)
- **Test setup**: Creates `TestData/Source` and `TestData/Backup` directories
- **CI**: Runs on Windows, macOS, Linux via `.github/workflows/ci.yml`

### CI Pipeline

- Tests run on macOS, Ubuntu, Windows with PowerShell Core
- Additional Windows-only test with PowerShell Desktop 5.1
- PSScriptAnalyzer must pass with zero errors
- Warnings are acceptable but tracked

### Commit Standards

- **Use Conventional Commits** for all commits to maintain clear change history
- Format: `<type>(<scope>): <description>`
- Common types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Examples:
  - `feat(backup): add metadata preservation for file restoration`
  - `fix(restore): handle cloud storage path compatibility`
  - `docs(readme): update installation instructions`
  - `refactor(module): extract functions into Public/Private folders`

## Critical Implementation Details

### Unique Filename Generation

When duplicate backup names exist, appends random suffix using `Get-RandomFileName`:

```powershell
$backupPath = '{0}__{1}' -f $backupPath, (Get-RandomFileName)
```

### Progress Reporting

Multi-path backups show progress bar:

```powershell
Write-Progress -Activity 'Creating Daily Backup' -Status "Processing path $currentPath of $totalPaths"
```

### ShouldProcess Pattern

All destructive operations support `-WhatIf` and implement `[CmdletBinding(SupportsShouldProcess)]`

### Parameter Validation

- `Keep` parameter: `[ValidateRange(-1, [int]::MaxValue)]` (-1 = keep all)
- Date validation: `[ValidatePattern('^\d{4}-\d{2}-\d{2}$')]`
- FileBackupMode: `[ValidateSet('Individual', 'Combined', 'Auto')]`

## Module Manifest Configuration

- **PowerShell 5.1+** compatible (`CompatiblePSEditions = @('Desktop', 'Core')`)
- **Three exported functions** only in `FunctionsToExport`
- **Version**: Currently 1.5.1 in `DailyBackup.psd1`

## Common Patterns When Editing

1. **Error handling**: Use `Write-Warning` for non-fatal issues, continue processing remaining items
2. **Verbose output**: Include contextual prefixes like `'New-DailyBackup:Begin>'`
3. **Path resolution**: Always use `Resolve-Path` and handle relative paths via `Join-Path -Path $pwd`
4. **Cross-platform paths**: Replace separators with `__` for backup filenames

## Testing Conventions

- Test directories: `$script:TestRoot`, `$script:SourceDir`, `$script:BackupDir`
- BeforeAll/BeforeEach setup in `Tests/DailyBackup.Tests.ps1`
- Verify backup creation, metadata files, and date folder structure
- Test both individual files and directory scenarios
