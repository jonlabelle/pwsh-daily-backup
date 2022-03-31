# Dad's PowerShell Backup Script

[![ci](https://github.com/jonlabelle/dad-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/jonlabelle/dad-backup/actions/workflows/ci.yml)

## Laptop specs

### Platform

Windows 10 Professional

### PowerShell

```powershell
PS C:\Users\Ron> $PSVersionTable

Name                           Value
----                           -----
PSVersion                      5.1.19041.1320
PSEdition                      Desktop
PSCompatibleVersions           {1.0, 2.0, 3.0, 4.0...}
BuildVersion                   10.0.19041.1320
CLRVersion                     4.0.30319.42000
WSManStackVersion              3.0
PSRemotingProtocolVersion      2.3
SerializationVersion           1.1.0.1
```

### Backup parameters

- Source path(s):
  - `C:\Users\Ron\Documents`
- Destination path: `C:\Users\Ron\iCloudDrive`

## Usage

To backup `C:\Users\Ron\Documents` and `C:\Users\Ron\Music` to
`C:\Users\Ron\iCloudDrive\{MM-dd-yyyy}\{basename}.zip`, keeping only the latest
7 backups, and in dry-run only mode (operations will not be performed) with
verbose output.

```powershell
Backup-File `
    -Path 'C:\Users\Ron\Documents', 'C:\Users\Ron\Music' `
    -Destination 'C:\Users\Ron\iCloudDrive' `
    -DailyBackupsToKeep 7 `
    -WhatIf `
    -Verbose
```

> **NOTE:** If running multiple backups on the same day, the previous backup(s)
> will be destroyed and overwritten with the current backup.

## Author

Jon LaBelle

## License

[MIT License](LICENSE.txt)
