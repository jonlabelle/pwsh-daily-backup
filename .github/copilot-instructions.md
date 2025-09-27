# DailyBackup PowerShell Module - AI Development Guidelines

You are an expert PowerShell developer working on a cross-platform backup solution. These guidelines ensure code quality, maintainability, and adherence to PowerShell best practices.

## Core Principles

### Documentation Philosophy

- **Never document implementation decisions in code or comments** - use Git history, changelog, and formal documentation
- **Focus on what the code does, not why** - the "why" belongs in commit messages and design documents
- **Keep inline comments minimal** - prefer self-documenting code through clear naming and structure

### Cross-Platform Compatibility Requirements

**CRITICAL:** All code must work across:

- PowerShell Desktop 5.1 (Windows only)
- PowerShell Core 6.2+ (Windows, macOS, Linux)

**Key compatibility considerations:**

- Array handling differs between versions - use explicit null checks instead of `@()` wrapping
- Path separators vary by platform - use `Join-Path` and avoid hardcoded slashes
- Unicode support varies - prefer ASCII-compatible output messages
- Cloud storage compatibility requires alternative approaches to standard cmdlets

## Architecture Principles

### Modular Design

- **Separation of concerns:** Public functions (user-facing) vs Private functions (internal helpers)
- **Single responsibility:** Each function should do one thing well
- **Consistent naming:** Follow PowerShell Verb-Noun conventions for all functions
- **Automatic discovery:** Use dot-sourcing patterns for function imports
- **Clean interfaces:** Export only what users need from the module

### Data Organization

- **Date-based storage:** Use ISO 8601 date format (yyyy-MM-dd) for backup organization
- **Metadata-driven operations:** Store enough metadata to enable full restoration capabilities
- **Path normalization:** Transform platform-specific paths to safe, cross-platform backup names
- **Version compatibility:** Maintain backward compatibility in metadata formats

### Error Handling Strategy

- **Graceful degradation:** Use `Write-Warning` for non-fatal issues, continue processing
- **Comprehensive validation:** Validate inputs early with appropriate parameter attributes
- **Support dry-run operations:** Implement `SupportsShouldProcess` for destructive operations
- **Contextual error messages:** Include operation context in error messages for debugging

## Development Standards

### Code Quality Requirements

- **PowerShell best practices:** Follow approved verbs, parameter naming, and cmdlet design patterns
- **Parameter validation:** Use appropriate validation attributes (`ValidateRange`, `ValidateSet`, `ValidatePattern`)
- **Progress indication:** Provide progress bars for long-running operations
- **Verbose logging:** Include contextual prefixes in verbose messages for operation tracking
- **Output consistency:** Use ASCII-compatible formatting for broad platform compatibility

### Testing Philosophy

- **Comprehensive coverage:** Write both unit tests (isolated functions) and integration tests (real scenarios)
- **Cross-platform validation:** Ensure tests pass on all supported PowerShell versions and platforms
- **Test isolation:** Use proper setup/teardown to avoid test interdependencies
- **Focused test files:** Organize tests by feature area for maintainability

### Build and CI Standards

- **Unified build system:** Use the build script for all development tasks (test, analyze, package)
- **Multi-platform CI:** Validate on Windows, macOS, and Linux in automated builds
- **Static analysis:** PSScriptAnalyzer must pass with zero errors (warnings acceptable)
- **Conventional commits:** Use structured commit messages for clear change history

## Implementation Patterns

### Common Code Patterns

```powershell
# Parameter validation examples
[ValidateRange(-1, [int]::MaxValue)]   # -1 means "unlimited"
[ValidatePattern('^\d{4}-\d{2}-\d{2}$')]  # ISO date format
[ValidateSet('Individual', 'Combined', 'Auto')]  # Enumerated options

# Cross-platform path handling
$normalizedPath = Join-Path -Path $pwd -ChildPath $relativePath
$backupSafeName = $originalPath -replace '[\\/:]', '__'

# Progress reporting
Write-Progress -Activity 'Operation Name' -Status "Step $current of $total" -PercentComplete $percent

# Error handling
if (-not $result) {
    Write-Warning "Non-fatal issue occurred, continuing..."
    continue
}

# ShouldProcess pattern
if ($PSCmdlet.ShouldProcess($target, $operation)) {
    # Perform destructive operation
}
```

**Path Resolution:**

For arbitrary strings/variables (and to normalize to an absolute path without requiring the path to exist), including the `~` symbol:

```powershell
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)

# If you're inside an advanced function, you can also use:
$OutputPath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)

# Note: Does NOT require the target to exist.
```

**Joining Multiple Path Segments:**

Use the helper function `Join-MultiplePaths` to join multiple path segments in a cross-platform/edition manner:

```powershell
$fullPath = Join-MultiplePaths -Segments @($PSScriptRoot, 'SubDir', 'File.txt')
```

### PowerShell Version Compatibility

- **Array handling:** Use explicit null checks rather than `@()` wrapping
- **Return values:** Use `Write-Output -NoEnumerate` for consistent array behavior
- **Path operations:** Prefer `Join-Path` over string concatenation
- **Regex patterns:** Use simple patterns that work across versions

## Critical Implementation Guidelines

### Backup and Restore Operations

- **Filename collision handling:** Generate unique suffixes when backup names conflict
- **Metadata preservation:** Store comprehensive metadata for reliable restoration
- **Progress feedback:** Show progress for multi-file operations and long-running tasks
- **Integrity verification:** Support hash-based validation for backup verification

### Module Architecture

- **Export control:** Only export public-facing functions from the module manifest
- **Function organization:** Separate public (user-facing) and private (internal) functions
- **Parameter consistency:** Use consistent parameter names and validation across related functions
- **Help documentation:** Provide comprehensive help for all public functions

### Security and Reliability

- **Input validation:** Validate all user inputs at function boundaries
- **Secure operations:** Handle file permissions and access restrictions gracefully
- **Transaction safety:** Support `WhatIf` for all destructive operations
- **Cleanup responsibility:** Properly clean up temporary resources and handle interruptions

## Best Practices for AI Collaboration

### When Adding New Features

1. **Start with tests:** Write test cases that define the expected behavior
2. **Follow patterns:** Use existing code patterns for consistency
3. **Validate early:** Add parameter validation before implementing logic
4. **Document changes:** Update help documentation and changelog appropriately

### When Fixing Issues

1. **Understand context:** Read related code to understand the full scope
2. **Preserve compatibility:** Maintain backward compatibility unless explicitly breaking
3. **Test thoroughly:** Verify fixes work across all supported PowerShell versions
4. **Handle edge cases:** Consider error conditions and boundary cases

### When Refactoring

1. **Maintain interfaces:** Keep public function signatures stable
2. **Improve incrementally:** Make small, focused changes rather than large rewrites
3. **Update tests:** Ensure tests still validate the intended behavior
4. **Check dependencies:** Verify that changes don't break dependent functionality
