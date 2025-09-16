#Requires -Module Pester

<#
.SYNOPSIS
    Legacy test file - tests have been refactored into focused modules.

.DESCRIPTION
    The original monolithic test file has been refactored into smaller, focused test files:
    - Backup.Tests.ps1: Core backup functionality and operations
    - Restore.Tests.ps1: Restore operations and Get-DailyBackup functionality
    - ErrorHandling.Tests.ps1: Error handling, edge cases, and validation
    - Metadata.Tests.ps1: Metadata generation and path type detection

    Use RunAllTests.ps1 to execute all tests, or run individual test files directly.

.EXAMPLE
    # Run all focused test files
    .\RunAllTests.ps1

.EXAMPLE
    # Run specific test area
    Invoke-Pester .\Backup.Tests.ps1

.EXAMPLE
    # Run backup-related tests only
    .\RunAllTests.ps1 -TestName "Backup"
#>

# Legacy compatibility - redirect to new test runner
Write-Host 'This test file has been refactored into focused modules.' -ForegroundColor Yellow
Write-Host 'Use RunAllTests.ps1 or run individual test files directly:' -ForegroundColor Gray
Write-Host '  - Backup.Tests.ps1' -ForegroundColor Gray
Write-Host '  - Restore.Tests.ps1' -ForegroundColor Gray
Write-Host '  - ErrorHandling.Tests.ps1' -ForegroundColor Gray
Write-Host '  - Metadata.Tests.ps1' -ForegroundColor Gray
Write-Host ''
Write-Host 'Running all focused tests...' -ForegroundColor Green

# Execute the new test runner
& "$PSScriptRoot\RunAllTests.ps1" @args
