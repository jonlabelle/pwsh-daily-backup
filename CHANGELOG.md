# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
