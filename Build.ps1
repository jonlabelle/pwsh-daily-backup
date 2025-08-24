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

function Test-Prerequisites
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

function Invoke-UnitTests
{
    Write-BuildMessage 'Running unit tests...'

    $testPath = Join-Path $ProjectRoot 'test'
    if (!(Test-Path $testPath))
    {
        Write-BuildMessage 'No test directory found, skipping unit tests' -Type Warning
        return
    }

    # Run Pester tests if available
    $pesterTest = Join-Path $testPath "$ModuleName.Tests.ps1"
    if (Test-Path $pesterTest)
    {
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $pesterTest
        $pesterConfig.Output.Verbosity = 'Detailed'
        $pesterConfig.CodeCoverage.Enabled = $true
        $pesterConfig.CodeCoverage.Path = @($ModuleScript)

        $results = Invoke-Pester -Configuration $pesterConfig

        if ($results.Result -eq 'Failed')
        {
            throw 'Unit tests failed'
        }

        Write-BuildMessage "Unit tests passed: $($results.PassedCount)/$($results.TotalCount)" -Type Success
    }

    Write-BuildMessage 'Unit tests completed' -Type Success
}

function Invoke-IntegrationTests
{
    Write-BuildMessage 'Running integration tests...'

    $integrationTest = Join-Path $ProjectRoot 'test\IntegrationTests.ps1'
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

    # Copy module files
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
            Copy-Item -Path $file -Destination $OutputPath -Force
            Write-BuildMessage "Copied: $(Split-Path $file -Leaf)"
        }
        else
        {
            Write-BuildMessage "File not found: $file" -Type Warning
        }
    }

    # Update version for release builds
    if ($Configuration -eq 'Release')
    {
        $manifest = Join-Path $OutputPath "$ModuleName.psd1"
        $content = Get-Content $manifest -Raw

        # You could implement version bumping logic here
        # For now, just ensure the manifest is valid
        Test-ModuleManifest $manifest | Out-Null
    }

    Write-BuildMessage "Module package created at: $OutputPath" -Type Success
}

function Invoke-Build
{
    Write-BuildMessage "Starting build process for $ModuleName..."

    Test-Prerequisites

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
                Invoke-UnitTests
                Invoke-IntegrationTests
            }
        }
        'Build'
        {
            Invoke-StaticAnalysis
            if (-not $SkipTests)
            {
                Invoke-UnitTests
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
                Invoke-UnitTests
                Invoke-IntegrationTests
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
