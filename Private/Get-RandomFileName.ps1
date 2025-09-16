function Get-RandomFileName
{
    <#
    .SYNOPSIS
        Generates a random file name without extension for uniqueness.

    .DESCRIPTION
        Creates a random file name by using the .NET System.IO.Path.GetRandomFileName() method
        and removing the file extension part. This is used internally to ensure backup file
        uniqueness when duplicate names are detected.

    .OUTPUTS
        [String]
        Returns a random filename string without the file extension (e.g., "kdjf3k2j").

    .NOTES
        This is an internal helper function used by New-BackupPath to create unique
        backup filenames when duplicates are detected.

    .EXAMPLE
        PS > $randomName = Get-RandomFileName

        Returns something like "kdjf3k2j"
    #>
    $randomFileName = [System.IO.Path]::GetRandomFileName()
    return $randomFileName.Substring(0, $randomFileName.IndexOf('.'))
}
