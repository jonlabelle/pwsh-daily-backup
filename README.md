# PowerShell Daily Backup

[![ci/cd](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci-cd.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/DailyBackup)](https://www.powershellgallery.com/packages/DailyBackup)

> PowerShell module for performing simple daily backups.

## Installation

```powershell
Install-Module -Name DailyBackup
```

## Updating

```powershell
Update-Module -Name DailyBackup
```

## Usage

```console
NAME
    New-DailyBackup

SYNOPSIS
    Perform a daily backup.

SYNTAX
    New-DailyBackup [-Path] <String[]> [-Destination] <String> -DailyBackupsToKeep <Int32> [-WhatIf] [-Verbose]

DESCRIPTION
    Create a new daily backup storing the compressed (.zip) contents in a
    destination folder formatted by day ('yyyy-MM-dd').

PARAMETERS
    -Path <String[]>
        The source file or directory path(s) to backup.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       true (ByValue, ByPropertyName)
        Accept wildcard characters?  false

    -Destination <String>
        The root directory path where daily backups will be stored.
        The default destination is the current working directory.

        Required?                    false
        Position?                    2
        Default value                .
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -DailyBackupsToKeep <Int32>
        The number of daily backups to keep when purging old backups.
        The oldest backups will be deleted first.
        This value cannot be less than zero.
        The default value is 0, which will not remove any backups.

        Required?                    false
        Position?                    named
        Default value                0
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -WhatIf [<SwitchParameter>]
        When present, backup operations will not be performed.

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).
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

## Author

Jon LaBelle

## License

[MIT License](LICENSE.txt)
