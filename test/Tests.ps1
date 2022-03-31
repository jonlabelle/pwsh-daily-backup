$testDir = Split-Path $script:MyInvocation.MyCommand.Path
$projectRootDir = (Get-Item $testDir).Parent.FullName

$moduleName = "Backup-File"
$modulePath = (Join-Path -Path "$projectRootDir" -ChildPath "$moduleName.ps1")

$dryRun = $true
$verboseEnabled = $true

if (-not ($null -eq (Get-ChildItem -Path Function:\$moduleName -ErrorAction 'SilentlyContinue')))
{
    Write-Verbose ("Removing old {0} from memory" -f "Function:\$moduleName") -Verbose:$verboseEnabled

    try
    {
        Remove-Item -Path Function:\$moduleName
    }
    catch
    {
        Write-Warning -Message "An error occured attempting to remove Function:\$moduleName from memory" -Verbose:$verboseEnabled
    }
}

Write-Verbose ("Loading {0} into memory" -f "Function:\$moduleName") -Verbose:$verboseEnabled
. $modulePath

$path1 = (Join-Path "$projectRootDir" "test" "stubs" "files-to-backup")
$path2 = (Join-Path "$projectRootDir" ".github")

$destination = (Join-Path "$projectRootDir" "test" "stubs" "files-backed-up")

Write-Verbose ("Calling {0} cmdlet" -f "$moduleName") -Verbose:$verboseEnabled
Backup-File -Path $path1, $path2 -Destination $destination -DailyBackupsToKeep 2 -WhatIf:$dryRun -Verbose:$verboseEnabled
