#Requires -Module Pester

<#
.SYNOPSIS
    Shared test helpers for DailyBackup module tests.

.DESCRIPTION
    Contains common setup, teardown, and utility functions used across
    all DailyBackup test files.
#>

# Import the module for testing
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
function Initialize-TestEnvironment
{
    param(
        [string]$TestName
    )

    $script:TestRoot = Join-Path $PSScriptRoot "TestData_$TestName"
    $script:SourceDir = Join-Path $script:TestRoot 'Source'
    $script:BackupDir = Join-Path $script:TestRoot 'Backup'

    # Create test directories
    if (Test-Path $script:TestRoot)
    {
        Remove-Item $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
    New-Item -Path $script:SourceDir -ItemType Directory -Force | Out-Null
    New-Item -Path $script:BackupDir -ItemType Directory -Force | Out-Null

    # Create test files
    'Test content 1' | Out-File -FilePath (Join-Path $script:SourceDir 'test1.txt') -Encoding UTF8
    'Test content 2' | Out-File -FilePath (Join-Path $script:SourceDir 'test2.txt') -Encoding UTF8

    # Create a subdirectory with files
    $SubDir = Join-Path $script:SourceDir 'SubFolder'
    New-Item -Path $SubDir -ItemType Directory -Force | Out-Null
    'Sub content' | Out-File -FilePath (Join-Path $SubDir 'subfile.txt') -Encoding UTF8

    return @{
        TestRoot = $script:TestRoot
        SourceDir = $script:SourceDir
        BackupDir = $script:BackupDir
    }
}

# Cleanup test environment
function Remove-TestEnvironment
{
    param(
        [string]$TestRoot
    )

    if (Test-Path $TestRoot)
    {
        Remove-Item $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
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
        MetadataFiles = @()  # Legacy compatibility
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
        MetadataFiles = @()
        ZipCount = 0
        MetadataCount = 0
    }

    if ($result.BackupLocationExists)
    {
        $result.ZipFiles = Get-ChildItem -Path $BackupLocation -Filter '*.zip' -ErrorAction SilentlyContinue
        $manifestPath = Join-Path $BackupLocation 'backup-manifest.json'
        $result.ManifestFile = if (Test-Path $manifestPath) { Get-Item $manifestPath } else { $null }
        $result.MetadataFiles = @()  # Legacy compatibility
        $result.ZipCount = $result.ZipFiles.Count
        $result.MetadataCount = if ($result.ManifestFile) { 1 } else { 0 }
    }

    return $result
}

# Test consolidated backup manifest content
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
