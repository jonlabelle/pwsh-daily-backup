[cmdletbinding()]
param(
    [Alias('DryRun', 'NoOp')]
    [Switch]
    $WhatIf = $false
)

$projectRootDir = (Join-Path -Path $PSScriptRoot -ChildPath '..')
$moduleName = 'Backup-File'
$modulePath = (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath $moduleName)

Get-Module $moduleName | Remove-Module -Verbose -ErrorAction SilentlyContinue
Import-Module -Name "$modulePath" -Force -Verbose

$path1 = (Join-Path -Path "$projectRootDir" -ChildPath 'test' -AdditionalChildPath 'stubs', 'files-to-backup')
$path2 = (Join-Path -Path "$projectRootDir" -ChildPath '.github')
$destination = (Join-Path -Path "$projectRootDir" -ChildPath 'test' -AdditionalChildPath 'stubs', 'files-backed-up')

Write-Verbose ('Running: {0}' -f "$moduleName") -Verbose:$verboseEnabled
Backup-File -Path $path1, $path2 -Destination $destination -DailyBackupsToKeep 2 -WhatIf:$WhatIf -Verbose:$Verbose
