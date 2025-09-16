function Get-PathType
{
    <#
    .SYNOPSIS
        Determines whether a path represents a file or directory.

    .DESCRIPTION
        Analyzes a given path to determine if it represents a file or directory.
        For existing paths, uses Test-Path with PathType parameter. For non-existing
        paths, attempts to infer the type based on file extension presence.

    .PARAMETER Path
        The path to analyze. Can be existing or non-existing.

    .OUTPUTS
        [String]
        Returns 'File' if the path represents a file, 'Directory' if it represents a directory.

    .NOTES
        This function is used internally to optimize backup naming and compression strategies
        for different path types.

    .EXAMPLE
        PS > Get-PathType -Path 'C:\Users\John\document.txt'
        File

    .EXAMPLE
        PS > Get-PathType -Path 'C:\Users\John\Documents'
        Directory

    .EXAMPLE
        PS > Get-PathType -Path 'C:\NonExistent\file.pdf'
        File
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    if (Test-Path -Path $Path -PathType Leaf)
    {
        return 'File'
    }
    elseif (Test-Path -Path $Path -PathType Container)
    {
        return 'Directory'
    }
    else
    {
        # For non-existent paths, infer from extension
        if ([System.IO.Path]::HasExtension($Path))
        {
            return 'File'
        }
        else
        {
            return 'Directory'
        }
    }
}
