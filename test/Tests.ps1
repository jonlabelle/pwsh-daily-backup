$testDir = Split-Path $script:MyInvocation.MyCommand.Path
$projectRootDir = (Get-Item $testDir).Parent.FullName

$moduleName = "Backup-File"
$modulePath = (Join-Path "$projectRootDir" "${moduleName}.ps1")

if ($null -eq (Get-Module -ListAvailable -Name $moduleName))
{
    if (-not($Env:CI))
    {
        Write-Output "Removing module: $moduleName"
        Remove-Module $moduleName
    }
}

Import-Module $modulePath

$sources = (Join-Path "$projectRootDir" "test" "stubs" "files-to-backup")
$destination = (Join-Path "$projectRootDir" "test" "stubs" "files-backed-up")
$dryRun = $false
$verboseEnabled = $true
Backup-File -Path $sources -Destination $destination -DeleteBackupsOlderThanDays 7 -WhatIf:$dryRun -Verbose:$verboseEnabled
