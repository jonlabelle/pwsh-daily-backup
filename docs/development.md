# Development Guide

This guide covers testing, development setup, and contribution guidelines for the PowerShell Daily Backup module.

## Testing & Quality Assurance

This module includes comprehensive testing to ensure reliability and professional quality.

### Test Suite Overview

The module uses a **focused test architecture** with separate test files for different areas of concern:

- **Backup.Tests.ps1** - Core backup functionality and operations
- **Restore.Tests.ps1** - Restore operations and Get-BackupInfo functionality
- **ErrorHandling.Tests.ps1** - Error handling, edge cases, and validation
- **Metadata.Tests.ps1** - Metadata generation and path type detection
- **TestHelpers.ps1** - Shared test utilities and setup functions
- **IntegrationTests.ps1** - Real-world backup scenarios
- **Static analysis** - Code quality and PowerShell best practices (PSScriptAnalyzer)
- **Cross-platform** - Tested on Windows, macOS, and Linux

### Running Tests Locally

#### Prerequisites

```powershell
# Install test dependencies
Install-Module Pester -Scope CurrentUser
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

#### Focused Unit Tests

```powershell
# Run all focused test suites (43+ test cases)
./Tests/RunAllTests.ps1

# Run specific test area
Invoke-Pester ./Tests/Backup.Tests.ps1
Invoke-Pester ./Tests/Restore.Tests.ps1
Invoke-Pester ./Tests/ErrorHandling.Tests.ps1
Invoke-Pester ./Tests/Metadata.Tests.ps1

# Run tests with filtering
./Tests/RunAllTests.ps1 -TestName "Backup"
./Tests/RunAllTests.ps1 -OutputFormat "Detailed"

# Legacy test runner (redirects to focused tests)
Invoke-Pester ./Tests/DailyBackup.Tests.ps1
```

#### Integration Tests

```powershell
# Run integration tests (6 scenarios)
./Tests/IntegrationTests.ps1

# Run with verbose output
./Tests/IntegrationTests.ps1 -Verbose
```

#### Run All Tests

```powershell
# Run comprehensive test suite via build system
./Build.ps1 -Task Test

# Run focused test runner directly
./Tests/RunAllTests.ps1

# Run with verbose output
./Tests/RunAllTests.ps1 -OutputFormat "Detailed"

# Run legacy script (now uses focused tests internally)
./scripts/run-all-tests.ps1 -Verbose
```

**VS Code Integration:**

- Task: `Ctrl+Shift+P` → "Tasks: Run Task" → Choose from available build tasks:
  - **"Build: All"** - Complete build and test suite
  - **"Build: Test"** - Run focused test suites via build system
  - **"Build: Analyze"** - Static analysis only
  - **"Build: Package"** - Create release package
  - **"Run all tests"** - Legacy test runner (now uses focused tests)
- Debug: `F5` → "PowerShell: Run all tests"

The build system automatically detects and uses the new focused test structure:

- **RunAllTests.ps1** - Discovers and runs all focused test files
- **Legacy compatibility** - DailyBackup.Tests.ps1 redirects to focused tests
- **Build integration** - Build.ps1 prefers focused tests over legacy
- **Comprehensive reporting** - Detailed pass/fail status and exit codes

#### Test Architecture Benefits

The focused test structure provides:

- **Maintainability** - Smaller, focused test files are easier to understand and modify
- **Parallel development** - Multiple developers can work on different test areas
- **Selective testing** - Run only relevant tests during development
- **Clear organization** - Tests are grouped by functional area
- **Reduced complexity** - No more monolithic 500+ line test files

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

#### Module Organization

The module follows PowerShell best practices with a clean separation between public and private functionality:

- **Public Functions** - User-facing commands exported by the module (located in `/Public/` folder)
- **Private Functions** - Internal helper functions that support the public API (located in `/Private/` folder)
- **Modular Design** - Each function has a single responsibility and follows PowerShell Verb-Noun naming conventions

For the current list of available commands, use:

```powershell
# List all exported commands
Get-Command -Module DailyBackup

# Get detailed help for any command
Get-Help New-DailyBackup -Full
```

#### File Structure

```text
DailyBackup.psm1              # Main module with import logic
DailyBackup.psd1              # Module manifest and metadata
Public/                       # Public (exported) functions
└── *.ps1                     # User-facing commands
Private/                      # Private (internal) functions
└── *.ps1                     # Helper functions and utilities
README.md                     # Primary documentation
docs/help.md                  # Comprehensive user guide
docs/development.md           # This development guide
Tests/                        # Focused test architecture
├── TestHelpers.ps1           # Shared test utilities
├── RunAllTests.ps1           # Test discovery and runner
├── DailyBackup.Tests.ps1     # Legacy compatibility (redirects)
├── *.Tests.ps1               # Focused test files by area
└── IntegrationTests.ps1      # Integration scenarios
scripts/                      # Build and utility scripts
└── *.ps1                     # Various automation scripts
Build.ps1                     # Build and package automation
```

#### Metadata System

The module automatically creates a consolidated metadata manifest alongside backups:

- **Purpose**: Enable intelligent restore operations with reduced file clutter
- **Content**: Consolidated backup manifest containing all backup metadata for the date
- **Format**: JSON structure with array of backup entries for cross-platform compatibility
- **Usage**: Powers `-UseOriginalPaths` restore functionality and `Get-BackupInfo` operations
- **File**: Single `backup-manifest.json` per date folder instead of individual `.metadata.json` files

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
New-DailyBackup -Path ./Tests/stubs -Destination ./temp -WhatIf
```

## Debugging and Troubleshooting

### Common Development Issues

#### Test Failures

```powershell
# Run specific test with detailed output
Invoke-Pester ./Tests/Backup.Tests.ps1 -TestName "*backup directory*" -Detailed

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
    New-DailyBackup -Path ./Tests/stubs -Destination ./temp
}

# Profile specific operations
$null = Trace-Command -Name ParameterBinding -Expression {
    New-DailyBackup -Path ./Tests/stubs -Destination ./temp -WhatIf
} -PSHost
```

## Release Process

Releases are published to the PowerShell Gallery by [manually dispatching](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/release.yml) the [`release.yml`](../.github/workflows/release.yml) workflow. The workflow automates version updates, testing, tagging, and publishing.

### Version Management

1. **[Manually trigger release workflow](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/release.yml)** via GitHub Actions workflow dispatch with desired version number
2. **Automated process** handles:
   - Full build and test validation
   - Version update in `DailyBackup.psd1`
   - Git commit and tag creation
   - Publication to PowerShell Gallery

### Manual Steps (if needed)

1. **Update changelog** in `CHANGELOG.md`
2. **Run full test suite** to ensure quality before triggering release
3. **Verify version format** follows semantic versioning (x.y.z)

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
