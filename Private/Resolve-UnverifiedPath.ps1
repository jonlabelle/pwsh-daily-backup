function Resolve-UnverifiedPath
{
    <#
    .SYNOPSIS
        Resolves file paths whether they exist or not, unlike Resolve-Path.

    .DESCRIPTION
        A wrapper around PowerShell's Resolve-Path cmdlet that handles both existing
        and non-existing paths gracefully. While Resolve-Path throws an exception for
        non-existing paths, this function returns the resolved path string regardless
        of whether the path exists on the filesystem.

    .PARAMETER Path
        The path to resolve. Can be relative or absolute, existing or non-existing.
        Supports pipeline input for processing multiple paths.

    .INPUTS
        [String]
        Path string that can be piped to this function.

    .OUTPUTS
        [String]
        The fully resolved path string. For existing paths, returns the provider path.
        For non-existing paths, returns the resolved target path that would exist.

    .NOTES
        This function was originally from the PowerShellForGitHub module.
        It's particularly useful for backup operations where destination paths
        may not exist yet but need to be resolved for path construction.

    .EXAMPLE
        PS > Resolve-UnverifiedPath -Path 'c:\windows\notepad.exe'

        Returns: C:\Windows\notepad.exe (if it exists)

    .EXAMPLE
        PS > Resolve-UnverifiedPath -Path '..\notepad.exe'

        Returns: C:\Windows\notepad.exe (resolved relative to current directory)

    .EXAMPLE
        PS > Resolve-UnverifiedPath -Path '..\nonexistent.txt'

        Returns: C:\Windows\nonexistent.txt (resolved even though file doesn't exist)

    .EXAMPLE
        PS > 'file1.txt', 'file2.txt' | Resolve-UnverifiedPath

        Resolves multiple paths from pipeline input

    .LINK
        https://aka.ms/PowerShellForGitHub
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string] $Path
    )

    process
    {
        $resolvedPath = Resolve-Path -Path $Path -ErrorVariable resolvePathError -ErrorAction SilentlyContinue

        if ($null -eq $resolvedPath)
        {
            Write-Output -InputObject ($resolvePathError[0].TargetObject)
        }
        else
        {
            Write-Output -InputObject ($resolvedPath.ProviderPath)
        }
    }
}
