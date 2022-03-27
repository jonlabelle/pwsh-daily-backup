$testDir = Split-Path $script:MyInvocation.MyCommand.Path

$projectRootDir = (Get-Item $testDir).Parent.FullName
Import-Module (Join-Path "$projectRootDir" "Backup-File.ps1")

$sources = (Join-Path "$projectRootDir" "test" "stubs" "files-to-backup")
$destination = (Join-Path "$projectRootDir" "test" "stubs" "files-backed-up")

$dryRun = $false
$verboseEnabled = $true

Backup-File -Path $sources -Destination $destination -DeleteBackupsOldThanDays 7 -WhatIf:$dryRun -Verbose:$verboseEnabled
