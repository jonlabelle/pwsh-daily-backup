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

- Source path: `C:\Users\Ron\Documents`
- Destination path: `C:\Users\Ron\iCloudDrive`

## Usage

To backup path `C:\Users\Ron\Documents` to
`C:\Users\Ron\iCloudDrive\{mm-dd-yyyy}`, deleting backups older than 7 days in
the destination, and with dry-run only mode enabled (operations will not be
performed).

```powershell
Backup-File `
    -Path 'C:\Users\Ron\Documents' `
    -Destination 'C:\Users\Ron\iCloudDrive' `
    -DeleteBackupsOlderThanDays 7 `
    -WhatIf `
    -Verbose
```

## Author

Jon LaBelle

## License

[MIT License](LICENSE.txt)
