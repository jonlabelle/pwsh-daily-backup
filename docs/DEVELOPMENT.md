# Development Guide

This guide covers testing, development setup, and contribution guidelines for the PowerShell Daily Backup module.

## 🧪 Testing & Quality Assurance

This module includes comprehensive testing to ensure reliability and professional quality.

### Test Suite Overview

- ✅ **14 unit tests** - Module functions, parameters, error handling
- ✅ **6 integration tests** - Real-world backup scenarios
- ✅ **Static analysis** - Code quality and PowerShell best practices
- ✅ **Cross-platform** - Tested on Windows, macOS, and Linux

### Running Tests Locally

#### Prerequisites

```powershell
# Install test dependencies
Install-Module Pester -Scope CurrentUser
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

#### Full Build Pipeline

```powershell
# Run complete build and test suite
./Build.ps1 -Task All

# Available tasks:
./Build.ps1 -Task Clean      # Clean build artifacts
./Build.ps1 -Task Test       # Run all tests
./Build.ps1 -Task Analyze    # Run static analysis
./Build.ps1 -Task Build      # Build module package
```

### Continuous Integration

The project uses GitHub Actions for automated testing:

- **Multi-platform testing** - Windows, macOS, Linux
- **PowerShell version matrix** - 5.1, 7.x
- **Automated quality gates** - All tests must pass
- **Static analysis** - PSScriptAnalyzer validation
- **Build verification** - Module packaging validation

## 🛠️ Development Setup

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

### Development Workflow

1. **Create a branch** for your feature/fix:

   ```powershell
   git checkout -b feature/your-feature-name
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
   git commit -m "Add: your feature description"
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request** on GitHub

### Project Structure

```plaintext
pwsh-daily-backup/
├── DailyBackup.psd1           # Module manifest
├── DailyBackup.psm1           # Main module file
├── Build.ps1                  # Build automation script
├── PSScriptAnalyzerSettings.psd1  # Code analysis settings
├── .github/workflows/         # CI/CD pipeline
├── docs/                      # Documentation
│   ├── HELP.md               # User documentation
│   └── DEVELOPMENT.md        # This file
├── test/                      # Test suite
│   ├── DailyBackup.Tests.ps1 # Unit tests
│   ├── IntegrationTests.ps1  # Integration tests
│   └── stubs/                # Test data
└── scripts/                   # Utility scripts
```

## 🤝 Contributing Guidelines

We welcome contributions! Here's how to help:

### Ways to Contribute

1. **🐛 Report Issues** - [GitHub Issues](https://github.com/jonlabelle/pwsh-daily-backup/issues)
2. **💡 Suggest Features** - [GitHub Discussions](https://github.com/jonlabelle/pwsh-daily-backup/discussions)
3. **🔧 Submit Pull Requests** - Code improvements and bug fixes
4. **📝 Improve Documentation** - Help expand guides and examples
5. **🧪 Add Tests** - Improve test coverage and scenarios

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
Import-Module ./DailyBackup.psm1 -Force

# Basic functionality works
New-DailyBackup -Path ./test/stubs -Destination ./temp -WhatIf
```

## 🔍 Debugging and Troubleshooting

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
Invoke-ScriptAnalyzer ./DailyBackup.psm1 -Settings ./PSScriptAnalyzerSettings.psd1

# Fix common issues automatically
Invoke-ScriptAnalyzer ./DailyBackup.psm1 -Fix
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

## 📊 Release Process

### Version Management

1. **Update version** in `DailyBackup.psd1`
2. **Update changelog** in `CHANGELOG.md`
3. **Run full test suite** to ensure quality
4. **Create release tag** following semantic versioning
5. **Publish to PowerShell Gallery** (automated via CI/CD)

### Quality Gates

Before any release:

- ✅ All tests pass on all supported platforms
- ✅ Static analysis passes with no errors
- ✅ Documentation is updated
- ✅ Changelog is updated
- ✅ Version numbers are consistent

## 📞 Development Support

- **📚 Documentation** - [Complete User Guide](HELP.md)
- **❓ Questions** - [GitHub Discussions](https://github.com/jonlabelle/pwsh-daily-backup/discussions)
- **🐛 Issues** - [GitHub Issues](https://github.com/jonlabelle/pwsh-daily-backup/issues)
- **💬 Community** - [PowerShell Gallery](https://www.powershellgallery.com/packages/DailyBackup)

---

Happy coding! 🚀
