# PowerShell Daily Backup

[![ci](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml)

> PowerShell module for performing simple daily backups.

## Usage

### New-DailyBackup

```console
PS /> Get-Help New-DailyBackup

NAME
    New-DailyBackup

SYNOPSIS
    Perform a daily backup.

SYNTAX
    New-DailyBackup [-Path] <String[]> [-Destination] <String> -DailyBackupsToKeep <Int32> [-WhatIf] [-Confirm]
    [<CommonParameters>]

    New-DailyBackup [-String] <String[]> [-Destination] <String> -DailyBackupsToKeep <Int32> [-WhatIf] [-Confirm]
    [<CommonParameters>]

DESCRIPTION
    Create a new daily backup storing the compressed (.zip) contents in
    a destination folder formatted by day ('yyyy-MM-dd').
```

## Examples

To perform a daily backup of directories `C:\Users\Ron\Documents` and
`C:\Users\Ron\Music`, and store them as `C:\Users\Ron\iCloudDrive\{yyyy-MM-dd}\{basename}.zip`,
keeping only the latest 7 backups.

```powershell
Import-Module DailyBackup

New-DailyBackup `
    -Path 'C:\Users\Ron\Documents', 'C:\Users\Ron\Music' `
    -Destination 'C:\Users\Ron\iCloudDrive' `
    -DailyBackupsToKeep 7 `
```

> **NOTE** If running multiple backups on the same day, the previous backup(s)
> will be destroyed and overwritten with the current backup.
> TODO: Maybe consider using the -Force option instead.

### To remove the all instances of the previous module and force reload

```powershell
$modulePath = '/Users/jon/projects/pwsh-daily-backup'
$moduleName = 'DailyBackup.psd1'
$moduleAbsolutePath = Join-Path -Path $modulePath -ChildPath $moduleName

Get-Module -Name $moduleAbsolutePath -ListAvailable -All | Remove-Module -Force
$module = Get-Module -Name $moduleAbsolutePath -ListAvailable
Import-Module -Name $module.Path -Force -ErrorAction Stop
```

> **Reference:** [The Pester Book](https://leanpub.com/pesterbook), *Modules and Dot-Sourced Script Gotchas:Importing Modules*

## Author

Jon LaBelle

## License

[MIT License](LICENSE.txt)
