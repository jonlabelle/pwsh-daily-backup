#Requires -Module Pester

<#
.SYNOPSIS
    Shared test helpers for DailyBackup module tests.

.DESCRIPTION
    Contains common setup, teardown, and utility functions used across
    all DailyBackup test files.
#>

# Import the module for testing
<#
.SYNOPSIS
    Initializes and imports the DailyBackup module for testing.

.DESCRIPTION
    Removes any existing module instances and imports a fresh copy
    of the module for testing purposes.

.PARAMETER ModuleName
    The name of the module to import. Defaults to 'DailyBackup'.

.EXAMPLE
    Initialize-TestModule

.EXAMPLE
    Initialize-TestModule -ModuleName 'MyModule'
#>
function Initialize-TestModule
{
    param(
        [string]$ModuleName = 'DailyBackup'
    )

    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModulePath = Join-Path $ModuleRoot "$ModuleName.psd1"

    # Remove any existing module instances
    Get-Module $ModuleName | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import the module for testing
    Import-Module $ModulePath -Force
}

# Setup test directories and files
<#
.SYNOPSIS
    Initializes a test environment with directories and sample files.

.DESCRIPTION
    Creates a comprehensive test environment including source directories,
    backup directories, and sample test files. Automatically registers
    cleanup handlers to ensure proper cleanup even if tests fail.

.PARAMETER TestName
    A unique name for this test environment, used to create isolated directories.

.OUTPUTS
    Hashtable containing TestRoot, SourceDir, and BackupDir paths.

.EXAMPLE
    $TestEnv = Initialize-TestEnvironment -TestName 'BackupTests'
    $TestEnv.SourceDir  # Path to source directory
    $TestEnv.BackupDir  # Path to backup directory
#>
function Initialize-TestEnvironment
{
    param(
        [string]$TestName
    )

    $script:TestRoot = Join-Path $PSScriptRoot "TestData_$TestName"
    $script:SourceDir = Join-Path $script:TestRoot 'Source'
    $script:BackupDir = Join-Path $script:TestRoot 'Backup'

    # Clean up any existing test environment first
    if (Test-Path $script:TestRoot)
    {
        Remove-TestEnvironment -TestRoot $script:TestRoot
    }

    # Create test directories
    try
    {
        New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
        New-Item -Path $script:SourceDir -ItemType Directory -Force | Out-Null
        New-Item -Path $script:BackupDir -ItemType Directory -Force | Out-Null

        # Register cleanup handler for this test environment
        Register-TestCleanupHandler -TestRoot $script:TestRoot

        # Create test files
        'Test content 1' | Out-File -FilePath (Join-Path $script:SourceDir 'test1.txt') -Encoding UTF8
        'Test content 2' | Out-File -FilePath (Join-Path $script:SourceDir 'test2.txt') -Encoding UTF8

        # Create a subdirectory with files
        $SubDir = Join-Path $script:SourceDir 'SubFolder'
        New-Item -Path $SubDir -ItemType Directory -Force | Out-Null
        'Sub content' | Out-File -FilePath (Join-Path $SubDir 'subfile.txt') -Encoding UTF8

        Write-Verbose "Test environment initialized: $script:TestRoot"

        return @{
            TestRoot = $script:TestRoot
            SourceDir = $script:SourceDir
            BackupDir = $script:BackupDir
        }
    }
    catch
    {
        # Clean up on failure
        if (Test-Path $script:TestRoot)
        {
            Remove-TestEnvironment -TestRoot $script:TestRoot
        }
        throw "Failed to initialize test environment: $($_.Exception.Message)"
    }
}

# Cleanup test environment
<#
.SYNOPSIS
    Removes a test environment directory and all its contents.

.DESCRIPTION
    Safely removes a test environment directory with enhanced error handling,
    retry logic, and unlocking of read-only files.

.PARAMETER TestRoot
    The root path of the test environment to remove.

.EXAMPLE
    Remove-TestEnvironment -TestRoot "C:\TestData_Backup"
#>
function Remove-TestEnvironment
{
    param(
        [string]$TestRoot
    )

    if ($TestRoot -and (Test-Path $TestRoot))
    {
        try
        {
            # Force unlock any locked files
            Get-ChildItem -Path $TestRoot -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            ForEach-Object { $_.IsReadOnly = $false }

            Remove-Item $TestRoot -Recurse -Force -ErrorAction Stop
            Write-Verbose "Successfully removed test environment: $TestRoot"
        }
        catch
        {
            Write-Warning "Failed to remove test environment '$TestRoot': $($_.Exception.Message)"
            # Try alternative cleanup method
            try
            {
                Start-Sleep -Milliseconds 100
                Remove-Item $TestRoot -Recurse -Force -ErrorAction Stop
                Write-Verbose "Successfully removed test environment on retry: $TestRoot"
            }
            catch
            {
                Write-Error "Critical: Unable to clean up test environment '$TestRoot': $($_.Exception.Message)"
            }
        }
    }
}

# Register cleanup handler for unexpected termination
<#
.SYNOPSIS
    Registers cleanup handlers for unexpected script termination.

.DESCRIPTION
    Sets up event handlers and trap blocks to ensure test environments
    are cleaned up even if the script is interrupted or crashes.

.PARAMETER TestRoot
    The root path of the test environment to clean up on termination.

.EXAMPLE
    Register-TestCleanupHandler -TestRoot "C:\TestData_Backup"
#>
function Register-TestCleanupHandler
{
    param(
        [string]$TestRoot
    )

    if ($TestRoot)
    {
        $script:TestCleanupPath = $TestRoot

        # Register cleanup for Ctrl+C and other termination events
        $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
            if ($script:TestCleanupPath -and (Test-Path $script:TestCleanupPath))
            {
                Write-Host "Cleaning up test environment on exit: $script:TestCleanupPath" -ForegroundColor Yellow
                Remove-Item $script:TestCleanupPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        # Also handle process termination via trap
        trap
        {
            if ($script:TestCleanupPath -and (Test-Path $script:TestCleanupPath))
            {
                Write-Host "Cleaning up test environment on error: $script:TestCleanupPath" -ForegroundColor Yellow
                Remove-Item $script:TestCleanupPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            throw $_
        }
    }
}

# Force cleanup of all test environments
<#
.SYNOPSIS
    Cleans up all orphaned test environment directories.

.DESCRIPTION
    Searches for and removes all test environment directories matching the
    'TestData_*' pattern. Useful for cleaning up after failed test runs.

.PARAMETER TestsDirectory
    The directory to search for test environments. Defaults to the current script directory.

.EXAMPLE
    Clear-AllTestEnvironment

.EXAMPLE
    Clear-AllTestEnvironment -TestsDirectory "C:\MyTests"
#>
function Clear-AllTestEnvironment
{
    param(
        [string]$TestsDirectory = $PSScriptRoot
    )

    $testDataPaths = Get-ChildItem -Path $TestsDirectory -Directory |
    Where-Object { $_.Name -like 'TestData_*' }

    foreach ($path in $testDataPaths)
    {
        Write-Verbose "Cleaning up orphaned test environment: $($path.FullName)"
        Remove-TestEnvironment -TestRoot $path.FullName
    }
}

# Create backup files for restore testing
function New-TestBackup
{
    param(
        [string]$SourcePath,
        [string]$BackupPath
    )

    New-DailyBackup -Path $SourcePath -Destination $BackupPath

    # Return backup info
    $DateFolder = Get-Date -Format 'yyyy-MM-dd'
    $BackupLocation = Join-Path $BackupPath $DateFolder
    $manifestPath = Join-Path $BackupLocation 'backup-manifest.json'

    return @{
        BackupLocation = $BackupLocation
        Date = $DateFolder
        ZipFiles = Get-ChildItem -Path $BackupLocation -Filter '*.zip' -ErrorAction SilentlyContinue
        ManifestFile = if (Test-Path $manifestPath) { Get-Item $manifestPath } else { $null }
    }
}

# Verify backup structure
function Test-BackupStructure
{
    param(
        [string]$BackupPath,
        [int]$ExpectedZipCount = 1,
        [int]$ExpectedMetadataCount = 1
    )

    $DateFolder = Get-Date -Format 'yyyy-MM-dd'
    $BackupLocation = Join-Path $BackupPath $DateFolder

    $result = @{
        BackupLocationExists = Test-Path $BackupLocation
        ZipFiles = @()
        ZipCount = 0
        MetadataCount = 0
    }

    if ($result.BackupLocationExists)
    {
        $result.ZipFiles = Get-ChildItem -Path $BackupLocation -Filter '*.zip' -ErrorAction SilentlyContinue
        $manifestPath = Join-Path $BackupLocation 'backup-manifest.json'
        $result.ManifestFile = if (Test-Path $manifestPath) { Get-Item $manifestPath } else { $null }
        $result.ZipCount = $result.ZipFiles.Count
        $result.MetadataCount = if ($result.ManifestFile) { 1 } else { 0 }
    }

    return $result
}

# Test backup manifest content
function Test-BackupManifest
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $ManifestPath
    )

    if (-not (Test-Path $ManifestPath))
    {
        return $null
    }

    try
    {
        $content = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
        return @{
            IsValid = $true
            Content = $content
            HasBackupDate = -not [string]::IsNullOrEmpty($content.BackupDate)
            HasBackupVersion = $content.BackupVersion -eq '1.0'
            HasModuleVersion = -not [string]::IsNullOrEmpty($content.ModuleVersion)
            HasBackupsArray = $content.Backups -is [Array]
            BackupCount = if ($content.Backups) { $content.Backups.Count } else { 0 }
            HasHashData = if ($content.Backups -and $content.Backups.Count -gt 0)
            {
                -not [string]::IsNullOrEmpty($content.Backups[0].SourceHash) -or
                -not [string]::IsNullOrEmpty($content.Backups[0].ArchiveHash)
            }
            else { $false }
        }
    }
    catch
    {
        return @{
            IsValid = $false
            Error = $_.Exception.Message
        }
    }
}

# Verify metadata content
function Test-MetadataContent
{
    param(
        [string]$MetadataPath
    )

    if (-not (Test-Path $MetadataPath))
    {
        return $null
    }

    try
    {
        $content = Get-Content -Path $MetadataPath -Raw | ConvertFrom-Json
        return @{
            IsValid = $true
            Content = $content
            HasSourcePath = -not [string]::IsNullOrEmpty($content.SourcePath)
            HasBackupCreated = -not [string]::IsNullOrEmpty($content.BackupCreated)
            HasPathType = $content.PathType -match '^(File|Directory)$'
            HasBackupVersion = $content.BackupVersion -eq '2.0'
        }
    }
    catch
    {
        return @{
            IsValid = $false
            Error = $_.Exception.Message
        }
    }
}
