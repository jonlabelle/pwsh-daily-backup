function Add-BackupMetadataFile
{
    <#
    .SYNOPSIS
        Adds metadata information to a backup archive.

    .DESCRIPTION
        Creates a metadata file containing information about the original source,
        backup creation time, file attributes, and other relevant details. This
        metadata is stored as a JSON file alongside the backup archive.

    .PARAMETER SourcePath
        The original path that was backed up.

    .PARAMETER BackupPath
        The path to the created backup archive (without .zip extension).

    .PARAMETER PathType
        The type of the source path ('File' or 'Directory').

    .OUTPUTS
        None. Creates a .metadata.json file alongside the backup archive.

    .NOTES
        This function helps preserve important information about backed up items
        for potential restoration or auditing purposes.

    .EXAMPLE
        PS > Add-BackupMetadataFile -SourcePath 'C:\Documents\report.pdf' -BackupPath 'C:\Backups\2025-09-15\Documents__report.pdf' -PathType 'File'

        Creates C:\Backups\2025-09-15\Documents__report.pdf.metadata.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,

        [Parameter(Mandatory = $true)]
        [string] $BackupPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('File', 'Directory')]
        [string] $PathType
    )

    try
    {
        $metadata = @{
            SourcePath = $SourcePath
            BackupCreated = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
            PathType = $PathType
            BackupVersion = '2.0'
        }

        if (Test-Path -Path $SourcePath)
        {
            $item = Get-Item -Path $SourcePath
            $metadata.OriginalName = $item.Name
            $metadata.LastWriteTime = $item.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $metadata.Attributes = $item.Attributes.ToString()

            if ($PathType -eq 'File')
            {
                $metadata.Size = $item.Length
                $metadata.Extension = $item.Extension
            }
        }

        $metadataPath = "$BackupPath.metadata.json"
        $metadata | ConvertTo-Json -Depth 3 | Out-File -FilePath $metadataPath -Encoding UTF8
        Write-Verbose "Add-BackupMetadataFile> Metadata saved to: $metadataPath"
    }
    catch
    {
        Write-Warning "Add-BackupMetadataFile> Failed to create metadata for $SourcePath : $_"
    }
}
