[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ModuleName = 'DailyBackup'
)

$verboseEnabled = $false
if ($VerbosePreference -eq 'Continue')
{
    $verboseEnabled = $true
}

$dryRun = $true
if ($PSCmdlet.ShouldProcess($ModuleName) -or $WhatIfPreference -eq $false)
{
    $dryRun = $false
}

$projectRootDir = (Split-Path $PSScriptRoot -Parent)
$modulePath = (Join-Path -Path $projectRootDir -ChildPath $ModuleName)

Get-Module $ModuleName | Remove-Module -Verbose:$verboseEnabled -Force -ErrorAction SilentlyContinue
Import-Module -Name $modulePath -Force -Verbose:$verboseEnabled

$path1 = [System.IO.Path]::Combine($projectRootDir, 'test', 'stubs', 'files-to-backup')
$path2 = [System.IO.Path]::Combine($projectRootDir, '.github')
$path3 = [System.IO.Path]::Combine($projectRootDir, '.github')
$destination = [System.IO.Path]::Combine($projectRootDir, 'test', 'stubs', 'files-backed-up')

Write-Verbose ('Running: {0}' -f $ModuleName)

New-DailyBackup `
    -Path $path1, $path2, $path3 `
    -Destination $destination `
    -DailyBackupsToKeep 2 `
    -WhatIf:$dryRun `
    -Verbose:$verboseEnabled
