# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.0] - 2025-09-16

### Added

- **NEW FEATURE**: `Remove-DailyBackup` command for manual backup removal
  - Remove specific backups by date or name pattern
  - Support for removing multiple backups in one operation
  - Preview mode with `-WhatIf` support
  - Force removal option for read-only files and directories
  - Integration with existing cleanup functionality

## [1.6.0] - 2025-09-16

### Added

- **NEW FEATURE**: Backup integrity verification with SHA-256 hashes
  - Automatic hash calculation for all backup sources and archives
  - `Test-DailyBackup` command for verifying backup integrity
  - Support for detecting corrupted archives and changed source files
  - Hash information stored in backup manifests for comprehensive verification

- **NEW PARAMETER**: `-NoHash` option for `New-DailyBackup`
  - Skip hash calculation to improve performance in simple backup scenarios
  - Useful for large files or when integrity verification isn't needed

- **ENHANCEMENT**: Extended backup metadata with hash information
  - Source file/directory hash using SHA-256 algorithm
  - Archive file hash for corruption detection
  - Hash algorithm specification in metadata

### Technical Improvements

- Added `Get-PathHash` private function for consistent hash calculation
- Enhanced `Add-BackupToManifest` with hash computation capabilities
- Updated test suite with comprehensive hash functionality testing
- Cross-platform hash verification support

### Fixed

- **Tilde Path Expansion**: Fixed issue where paths starting with `~` (tilde) were not properly expanded to the user's home directory, causing backups to fail with empty destination folders

## [1.5.0] - 2025-09-15

### Added

- **NEW FEATURE**: `Restore-DailyBackup` command for restoring files from backups
  - Restore from specific dates or latest backup automatically
  - Support for restoring to original paths using metadata
  - Selective restoration using backup name patterns
  - Preview mode with `-WhatIf` support
  - Force overwrite option for existing files
- **NEW FEATURE**: `Get-DailyBackup` command for backup discovery and analysis
  - List all available backup dates and files
  - Filter by date ranges and backup name patterns

### Fixed

- **PowerShell 5.1 Compatibility**: Fixed critical array handling and return value issues
  - **CRITICAL**: Fixed `Get-DailyBackup` returning `$null` instead of empty arrays in PowerShell 5.1
  - Replaced `@()` array wrapping with explicit null checks and `Write-Output -NoEnumerate`
  - Simplified date folder regex pattern from complex word-boundary pattern to `^\d{4}-\d{2}-\d{2}$`
  - Resolved `Where-Object` result inconsistencies between PowerShell versions
  - Fixed array return semantics to ensure consistent behavior across all PowerShell versions
  - Ensured restore summary displays correctly in all PowerShell versions
  - All 43+ focused unit tests now pass in PowerShell 5.1, 6.x, and 7.x
  - Detailed backup metadata information
  - Cross-platform backup inventory management
- **Metadata System**: Automatic metadata generation for all backups
  - Records original source paths for restore operations
  - Tracks backup creation time and system information
  - Enables intelligent restore to original locations
- **Enhanced Documentation**: Comprehensive restore examples and best practices
  - Updated README.md with complete command reference
  - Added restore scenarios to help documentation
  - Included troubleshooting guide for restore operations

### Fixed

- **PowerShell 5.1 Compatibility**: Removed all Unicode characters from output messages
  - Replaced emoji icons with ASCII bracket notation (e.g., [SUCCESS], [FAILED])
  - Ensures compatibility across all PowerShell versions and platforms
  - Fixed output formatting issues in Windows PowerShell 5.1
- **CI/CD Pipeline**: Fixed Pester test compatibility issues causing CI failures
- **Testing Framework**: Updated unit tests to use Pester v5 syntax and proper test isolation
- **Build System**: Corrected Build.ps1 to use appropriate Pester configuration for CI environments
- **Cross-Platform Paths**: Improved temporary directory handling for all operating systems

### Changed

- **BREAKING**: Module now includes three commands instead of one
  - `New-DailyBackup`: Original backup functionality (unchanged)
  - `Restore-DailyBackup`: New restore functionality
  - `Get-DailyBackup`: New backup information retrieval
- **Output Format**: All status messages now use ASCII-compatible format
  - Changed from Unicode symbols to text-based indicators
  - Maintains readability while ensuring broad compatibility
- **Developer Experience**: Integrated `Build.ps1` throughout CI/CD and development workflows
- **GitHub Actions**: Simplified CI/CD workflows to use unified build script instead of inline commands
- **VS Code Integration**: Added comprehensive VS Code tasks for all build operations
- **Build System**: Enhanced `Build.ps1` package task to create proper PowerShell Gallery directory structure
- **Documentation**: Updated development guide with new VS Code tasks and build workflow

## [1.4.0] - 2025-08-24

### Added

- New test cases for improved Keep parameter behavior
- Enhanced parameter validation tests

### Changed

- **BREAKING**: Changed default Keep parameter value from `0` to `-1` for better semantics
- **BREAKING**: Keep parameter now uses `-1` to mean "keep all backups" instead of `0`
- **BREAKING**: Keep parameter now uses `0` to mean "delete all backups" (more intuitive)
- Improved parameter validation range to accept `-1` as minimum value
- Updated all documentation to reflect new Keep parameter behavior

### Fixed

- Integration tests updated to validate new Keep parameter behavior
- Unit tests updated for new parameter validation ranges

## [1.3.0] - 2025-08-24

### Added

- Comprehensive Pester unit tests covering all major functionality
- Enhanced error handling and input validation
- Progress indicators for backup operations
- Better documentation and inline help
- Performance improvements for large file operations

### Changed

- Improved internal function organization and naming conventions
- Enhanced verbose logging throughout the module
- Better handling of edge cases and error conditions

### Fixed

- Fixed variable scoping issues in RemoveDailyBackup function
- Corrected path resolution for relative paths
- Fixed potential issues with special characters in filenames
- Improved handling of long file paths

## [1.2.2] - 2022-04-21

### Features

- Initial module release
- Basic daily backup functionality
- Support for multiple source paths
- Automatic cleanup of old backups
- ZIP compression for backup archives

### Key Features

- Create daily backups with date-formatted folders (yyyy-MM-dd)
- Support for multiple source paths in a single operation
- Automatic cleanup of old backups based on retention policy
- WhatIf support for dry-run operations
- Verbose logging for detailed operation tracking
- Cross-platform compatibility (PowerShell 5.1+ and PowerShell Core)

## [1.2.1] - Previous Release

- Routine updates and maintenance

## [1.2.0] - Previous Release

- Feature enhancements and bug fixes

## [1.1.0] - Previous Release

- Initial feature set implementation

## [1.0.0] - Initial Release

- Basic backup functionality
