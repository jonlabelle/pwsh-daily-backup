# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **CI/CD Pipeline**: Fixed Pester test compatibility issues causing CI failures
- **Testing Framework**: Updated unit tests to use Pester v5 syntax and proper test isolation
- **Build System**: Corrected Build.ps1 to use appropriate Pester configuration for CI environments

### Changed

- **Developer Experience**: Integrated `Build.ps1` throughout CI/CD and development workflows
- **GitHub Actions**: Simplified CI/CD workflows to use unified build script instead of inline commands
- **VS Code Integration**: Added comprehensive VS Code tasks for all build operations
- **Build System**: Enhanced `Build.ps1` package task to create proper PowerShell Gallery directory structure
- **Documentation**: Updated development guide with new VS Code tasks and build workflow

### Added

- VS Code tasks for `Build: All`, `Build: Test`, `Build: Analyze`, and `Build: Package`
- Enhanced build script package validation for release builds
- Comprehensive developer documentation for VS Code integration

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
