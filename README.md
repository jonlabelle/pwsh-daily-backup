# PowerShell Daily Backup

[![ci](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/jonlabelle/pwsh-daily-backup/actions/workflows/ci.yml)

> PowerShell module for performing simple daily backups.

## Usage

To perform a daily backup of directories `C:\Users\Ron\Documents` and
`C:\Users\Ron\Music`, and store them as `C:\Users\Ron\iCloudDrive\{MM-dd-yyyy}\{basename}.zip`,
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
