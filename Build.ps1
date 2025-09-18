#Requires -Version 5.1
<#
.SYNOPSIS
    Build and test script for the DailyBackup module.

.DESCRIPTION
    This script provides a comprehensive build and test pipeline for the DailyBackup module.
    It can run static analysis, unit tests, integration tests, and prepare the module for publishing.

.PARAMETER Task
    The task to perform. Valid values: Build, Test, Analyze, Package, All

.PARAMETER Configuration
    Build configuration. Valid values: Debug, Release

.PARAMETER OutputPath
    Output path for build artifacts. Default is './dist'

.PARAMETER SkipTests
    Skip running tests during the build process.

.EXAMPLE
    .\Build.ps1 -Task All

.EXAMPLE
    .\Build.ps1 -Task Test -Configuration Debug
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Build', 'Test', 'Analyze', 'Package', 'All')]
    [string] $Task = 'All',

    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',

    [Parameter()]
    [string] $OutputPath = './dist',

    [Parameter()]
    [switch] $SkipTests
)

# Script variables
$ErrorActionPreference = 'Stop'
$ModuleName = 'DailyBackup'
$ProjectRoot = $PSScriptRoot
$ModuleManifest = Join-Path $ProjectRoot "$ModuleName.psd1"
$ModuleScript = Join-Path $ProjectRoot "$ModuleName.psm1"

# Helper functions
function Write-BuildMessage
{
    param(
        [string] $Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string] $Type = 'Info'
    )

    $colors = @{
        'Info' = 'White'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }

    $prefix = switch ($Type)
    {
        'Info' { '[INFO]' }
        'Success' { '[SUCCESS]' }
        'Warning' { '[WARNING]' }
        'Error' { '[ERROR]' }
    }

    Write-Host "$prefix $Message" -ForegroundColor $colors[$Type]
}

function Test-Prerequisite
{
    Write-BuildMessage 'Checking prerequisites...'

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5)
    {
        throw 'PowerShell 5.1 or higher is required'
    }

    # Check for required modules
    $requiredModules = @('PSScriptAnalyzer', 'Pester')
    foreach ($module in $requiredModules)
    {
        if (!(Get-Module -ListAvailable -Name $module))
        {
            Write-BuildMessage "Installing missing module: $module" -Type Warning
            Install-Module -Name $module -Scope CurrentUser -Force
        }
    }

    Write-BuildMessage 'Prerequisites check completed' -Type Success
}

function Invoke-StaticAnalysis
{
    Write-BuildMessage 'Running static analysis...'

    $settingsPath = Join-Path $ProjectRoot 'PSScriptAnalyzerSettings.psd1'
    $results = Invoke-ScriptAnalyzer -Path $ProjectRoot -Settings $settingsPath -Recurse

    if ($results)
    {
        $errors = $results | Where-Object Severity -EQ 'Error'
        $warnings = $results | Where-Object Severity -EQ 'Warning'

        Write-BuildMessage "Found $($errors.Count) errors and $($warnings.Count) warnings" -Type Warning

        if ($errors.Count -gt 0)
        {
            $results | Where-Object Severity -EQ 'Error' | Format-Table -AutoSize
            throw 'Static analysis found errors that must be fixed'
        }

        if ($warnings.Count -gt 0)
        {
            Write-BuildMessage 'Static analysis warnings:' -Type Warning
            $results | Where-Object Severity -EQ 'Warning' | Format-Table -AutoSize
        }
    }

    Write-BuildMessage 'Static analysis completed' -Type Success
}

function Invoke-UnitTest
{
    Write-BuildMessage 'Running unit tests...'

    $testPath = Join-Path $ProjectRoot 'Tests'
    if (!(Test-Path $testPath))
    {
        Write-BuildMessage 'No Tests directory found, skipping unit tests' -Type Warning
        return
    }

    # Run focused test suites via RunAllTests.ps1
    $testRunner = Join-Path $testPath 'RunAllTests.ps1'

    if (Test-Path $testRunner)
    {
        Write-BuildMessage 'Running focused test suites via RunAllTests.ps1' -Type Info

        # Use PowerShell to run the test runner script
        & pwsh -File $testRunner
        $exitCode = $LASTEXITCODE

        if ($exitCode -gt 0)
        {
            Write-BuildMessage "Unit tests failed: $exitCode test(s) failed" -Type Error
            throw "Unit tests failed with exit code: $exitCode"
        }

        Write-BuildMessage 'Focused test suites completed successfully' -Type Success
    }
    else
    {
        Write-BuildMessage 'No test runner found (RunAllTests.ps1)' -Type Warning
    }

    Write-BuildMessage 'Unit tests completed' -Type Success
}

function Invoke-IntegrationTest
{
    Write-BuildMessage 'Running integration tests...'

    $integrationTest = Join-Path $ProjectRoot 'Tests\IntegrationTests.ps1'
    if (Test-Path $integrationTest)
    {
        & $integrationTest -CleanupAfterTests:$true
    }
    else
    {
        Write-BuildMessage 'No integration tests found' -Type Warning
    }

    Write-BuildMessage 'Integration tests completed' -Type Success
}

function New-ModulePackage
{
    Write-BuildMessage 'Creating module package...'

    # Create output directory
    if (Test-Path $OutputPath)
    {
        Remove-Item $OutputPath -Recurse -Force
    }
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null

    # Create the proper module directory structure for PSGallery
    $modulePackagePath = Join-Path $OutputPath $ModuleName
    New-Item -Path $modulePackagePath -ItemType Directory -Force | Out-Null

    # Copy module files to the module subfolder
    $filesToCopy = @(
        $ModuleManifest,
        $ModuleScript,
        (Join-Path $ProjectRoot 'README.md'),
        (Join-Path $ProjectRoot 'LICENSE.txt'),
        (Join-Path $ProjectRoot 'CHANGELOG.md')
    )

    foreach ($file in $filesToCopy)
    {
        if (Test-Path $file)
        {
            Copy-Item -Path $file -Destination $modulePackagePath -Force
            Write-BuildMessage "Copied: $(Split-Path $file -Leaf)"
        }
        else
        {
            Write-BuildMessage "File not found: $file" -Type Warning
        }
    }

    # Copy Public and Private folders
    $foldersToRecursiveCopy = @('Public', 'Private')
    foreach ($folder in $foldersToRecursiveCopy)
    {
        $sourcePath = Join-Path $ProjectRoot $folder
        if (Test-Path $sourcePath)
        {
            $destinationPath = Join-Path $modulePackagePath $folder
            Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force
            Write-BuildMessage "Copied folder: $folder"
        }
        else
        {
            Write-BuildMessage "Folder not found: $folder" -Type Warning
        }
    }

    # Validate the module manifest
    $packagedManifest = Join-Path $modulePackagePath "$ModuleName.psd1"
    $manifest = Test-ModuleManifest $packagedManifest
    Write-BuildMessage "Module manifest validated. Name: $($manifest.Name), Version: $($manifest.Version)" -Type Success

    # Update version for release builds
    if ($Configuration -eq 'Release')
    {
        Write-BuildMessage "Release build - manifest version: $($manifest.Version)" -Type Success
    }

    Write-BuildMessage "Module package created at: $modulePackagePath" -Type Success
}

function Invoke-Build
{
    Write-BuildMessage "Starting build process for $ModuleName..."

    Test-Prerequisite

    switch ($Task)
    {
        'Analyze'
        {
            Invoke-StaticAnalysis
        }
        'Test'
        {
            if (-not $SkipTests)
            {
                Invoke-UnitTest
                Invoke-IntegrationTest
            }
        }
        'Build'
        {
            Invoke-StaticAnalysis
            if (-not $SkipTests)
            {
                Invoke-UnitTest
            }
        }
        'Package'
        {
            New-ModulePackage
        }
        'All'
        {
            Invoke-StaticAnalysis
            if (-not $SkipTests)
            {
                Invoke-UnitTest
                Invoke-IntegrationTest
            }
            New-ModulePackage
        }
    }

    Write-BuildMessage 'Build completed successfully!' -Type Success
}

# Main execution
try
{
    Invoke-Build
}
catch
{
    Write-BuildMessage "Build failed: $_" -Type Error
    exit 1
}
