# Development Guide

This guide covers testing, development setup, and contribution guidelines for the PowerShell Daily Backup module.

## Testing & Quality Assurance

This module includes comprehensive testing to ensure reliability and professional quality.

### Test Suite Overview

- **unit tests** - Module functions, parameters, error handling
- **integration tests** - Real-world backup scenarios
- **Static analysis** - Code quality and PowerShell best practices
- **Cross-platform** - Tested on Windows, macOS, and Linux

### Running Tests Locally

#### Prerequisites

```powershell
# Install test dependencies
# Install-Module Pester -Scope CurrentUser

# Install Pester v4 specifically for compatibility
Install-Module Pester -RequiredVersion 4.10.1 -Force -SkipPublisherCheck -ErrorAction Stop

Install-Module PSScriptAnalyzer -Scope CurrentUser
```

#### Unit Tests

```powershell
# Run unit tests (14 test cases)
Invoke-Pester ./test/DailyBackup.Tests.ps1

# Run with detailed output
Invoke-Pester ./test/DailyBackup.Tests.ps1 -Detailed
```

#### Integration Tests

```powershell
# Run integration tests (6 scenarios)
./test/IntegrationTests.ps1

# Run with verbose output
./test/IntegrationTests.ps1 -Verbose
```

#### Run All Tests

```powershell
# Run comprehensive test suite
./scripts/run-all-tests.ps1

# Run with verbose output
./scripts/run-all-tests.ps1 -Verbose
```

**VS Code Integration:**

- Task: `Ctrl+Shift+P` → "Tasks: Run Task" → Choose from available build tasks:
  - **"Build: All"** - Complete build and test suite
  - **"Build: Test"** - Run all tests only
  - **"Build: Analyze"** - Static analysis only
  - **"Build: Package"** - Create release package
  - **"Run all tests"** - Legacy test runner (scripts/run-all-tests.ps1)
- Debug: `F5` → "PowerShell: Run all tests"

The comprehensive test runner executes:

- Static analysis (PSScriptAnalyzer)
- Unit tests (Pester)
- Integration tests
- Provides detailed reporting with pass/fail status

#### Full Build Pipeline

```powershell
# Run complete build and test suite
./Build.ps1 -Task All

# Available tasks:
./Build.ps1 -Task Test       # Run all tests
./Build.ps1 -Task Analyze    # Run static analysis
./Build.ps1 -Task Package    # Create module package
./Build.ps1 -Task Build      # Build and validate (alias for Package)
```

### Continuous Integration

The project uses GitHub Actions for automated testing:

- **Multi-platform testing** - Windows, macOS, Linux
- **PowerShell version matrix** - 5.1, 6.x, 7.x
- **Automated quality gates** - All tests must pass
- **Static analysis** - PSScriptAnalyzer validation
- **Build verification** - Module packaging validation

## Development Setup

### Module Architecture

The DailyBackup module consists of three primary commands:

#### Core Commands

- **`New-DailyBackup`** - Creates compressed backup archives with automatic cleanup
- **`Restore-DailyBackup`** - Restores files from backup archives to specified locations
- **`Get-BackupInfo`** - Discovers and analyzes available backups

#### Internal Functions

```powershell
# Backup-related functions
CompressBackup           # Creates ZIP archives from source paths
RemoveDailyBackup        # Cleanup old backup directories
GenerateBackupFileName   # Creates unique backup filenames
CreateMetadata           # Generates backup metadata files

# Restore-related functions
ExtractBackup            # Extracts ZIP archives to destinations
ReadMetadata             # Reads backup metadata information
ResolveRestorePath       # Determines appropriate restore paths

# Utility functions
ResolveUnverifiedPath    # Path resolution and validation
RemoveItemAlternative    # Cloud storage compatible file deletion
Test-ValidDateString     # Date format validation
```

#### File Structure

```text
DailyBackup.psm1              # Main module with import logic
DailyBackup.psd1              # Module manifest and metadata
Public/                       # Public (exported) functions
├── Get-BackupInfo.ps1
├── New-DailyBackup.ps1
└── Restore-DailyBackup.ps1
Private/                      # Private (internal) functions
├── Add-BackupMetadataFile.ps1
├── Compress-Backup.ps1
├── Get-PathType.ps1
├── Get-RandomFileName.ps1
├── New-BackupPath.ps1
├── Remove-DailyBackup.ps1
├── Remove-ItemAlternative.ps1
├── Resolve-UnverifiedPath.ps1
└── Restore-BackupFile.ps1
README.md                     # Primary documentation
docs/help.md                  # Comprehensive user guide
docs/development.md           # This development guide
test/DailyBackup.Tests.ps1    # Unit tests (43 test cases)
test/IntegrationTests.ps1     # Integration scenarios
scripts/run-all-tests.ps1     # Test runner
Build.ps1                     # Build and package automation
```

#### Metadata System

The module automatically creates metadata files alongside backups:

- **Purpose**: Enable intelligent restore operations
- **Content**: Original source paths, creation timestamps, system information
- **Format**: JSON structure for cross-platform compatibility
- **Usage**: Powers `-UseOriginalPaths` restore functionality

### Initial Setup

```powershell
# 1. Clone the repository
git clone https://github.com/jonlabelle/pwsh-daily-backup.git
cd pwsh-daily-backup

# 2. Install development dependencies
Install-Module Pester, PSScriptAnalyzer -Scope CurrentUser

# 3. Verify setup by running tests
./Build.ps1 -Task Test
```

### VS Code Development

This project includes VS Code configuration for an optimal development experience:

#### Available Tasks

Use `Ctrl+Shift+P` → "Tasks: Run Task" to access:

| Task               | Description             | Command                       |
| ------------------ | ----------------------- | ----------------------------- |
| **Build: All**     | Complete build pipeline | `./Build.ps1 -Task All`       |
| **Build: Test**    | Run all tests           | `./Build.ps1 -Task Test`      |
| **Build: Analyze** | Static analysis only    | `./Build.ps1 -Task Analyze`   |
| **Build: Package** | Create release package  | `./Build.ps1 -Task Package`   |
| **Run all tests**  | Legacy test runner      | `./scripts/run-all-tests.ps1` |

#### Launch Configurations

Use `F5` or Debug panel to run:

- **PowerShell: Run Pester unit tests** - Execute unit test suite
- **PowerShell: Run integration tests** - Execute integration tests
- **PowerShell: Run all tests** - Execute complete test suite
- **PowerShell: Run PSScriptAnalyzer** - Static code analysis
- **PowerShell: Interactive session** - Start debugging session

#### Recommended Extensions

- **PowerShell** - Official PowerShell extension
- **PowerShell Pro Tools** - Advanced PowerShell development features

### Development Workflow

1. **Create a branch** for your feature/fix:

   ```powershell
   git checkout -b feat/your-feature-name
   ```

2. **Make your changes** following PowerShell best practices

3. **Run tests** to ensure nothing breaks:

   ```powershell
   ./Build.ps1 -Task Test
   ```

4. **Run static analysis** to check code quality:

   ```powershell
   ./Build.ps1 -Task Analyze
   ```

5. **Commit and push** your changes:

   ```powershell
   git add .
   git commit -m "feat: your feature description"
   git push origin feat/your-feature-name
   ```

6. **Create a Pull Request** on GitHub

## Contributing Guidelines

We welcome contributions! Here's how to help:

### Ways to Contribute

1. **Report Issues** - [GitHub Issues](https://github.com/jonlabelle/pwsh-daily-backup/issues)
2. **Suggest Features** - [GitHub Discussions](https://github.com/jonlabelle/pwsh-daily-backup/discussions)
3. **Submit Pull Requests** - Code improvements and bug fixes
4. **Improve Documentation** - Help expand guides and examples
5. **Add Tests** - Improve test coverage and scenarios

### Code Standards

- **PowerShell Best Practices** - Follow official PowerShell style guidelines
- **PSScriptAnalyzer** - All code must pass static analysis
- **Comprehensive Testing** - New features require corresponding tests
- **Documentation** - Update docs for any user-facing changes
- **Backward Compatibility** - Maintain compatibility when possible

### Pull Request Guidelines

1. **Clear Description** - Explain what your PR does and why
2. **Test Coverage** - Include tests for new functionality
3. **Documentation Updates** - Update relevant documentation
4. **Small, Focused Changes** - Keep PRs focused on a single improvement
5. **Follow Conventions** - Match existing code style and patterns

### Testing Your Changes

Before submitting a PR, ensure:

```powershell
# All tests pass
./Build.ps1 -Task Test

# Code analysis passes
./Build.ps1 -Task Analyze

# Module loads correctly
Import-Module ./DailyBackup.psd1 -Force

# Basic functionality works
New-DailyBackup -Path ./test/stubs -Destination ./temp -WhatIf
```

## Debugging and Troubleshooting

### Common Development Issues

#### Test Failures

```powershell
# Run specific test with detailed output
Invoke-Pester ./test/DailyBackup.Tests.ps1 -TestName "Should create backup directory" -Detailed

# Check for module conflicts
Get-Module DailyBackup -ListAvailable
Remove-Module DailyBackup -Force
```

#### Static Analysis Warnings

```powershell
# Run analysis with detailed output
Invoke-ScriptAnalyzer ./Public/*.ps1 ./Private/*.ps1 -Settings ./PSScriptAnalyzerSettings.psd1

# Fix common issues automatically
Invoke-ScriptAnalyzer ./Public/*.ps1 ./Private/*.ps1 -Fix
```

#### Cross-Platform Issues

```powershell
# Test cross-platform path handling
$TestPath = Join-Path $PWD "test"
Test-Path $TestPath  # Should work on all platforms

# Check PowerShell version compatibility
$PSVersionTable.PSVersion  # Should be 5.1+ or 7.x
```

### Performance Profiling

```powershell
# Measure backup performance
Measure-Command {
    New-DailyBackup -Path ./test/stubs -Destination ./temp
}

# Profile specific operations
$null = Trace-Command -Name ParameterBinding -Expression {
    New-DailyBackup -Path ./test/stubs -Destination ./temp -WhatIf
} -PSHost
```

## Release Process

### Version Management

1. **Update version** in `DailyBackup.psd1`
2. **Update changelog** in `CHANGELOG.md`
3. **Run full test suite** to ensure quality
4. **Create release tag** following semantic versioning
5. **Publish to PowerShell Gallery** (automated via CI/CD)

### Quality Gates

Before any release:

- All tests pass on all supported platforms
- Static analysis passes with no errors
- Documentation is updated
- Changelog is updated
- Version numbers are consistent

## Development Support

- [Complete User Guide](help.md)
- [GitHub Issues](https://github.com/jonlabelle/pwsh-daily-backup/issues)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/DailyBackup)
