function Join-MultiplePaths
{
    <#
    .SYNOPSIS
        Join multiple path segments into a single cross-platform path.

    .DESCRIPTION
        Join-MultiplePaths joins an ordered list of path segments using Join-Path to ensure
        cross-platform correctness. The function validates input and emits concise verbose
        messages for tracking.

        PowerShell Desktop 5.1 does not support Join-Path's -AdditionalChildPath parameter.
        This function provides equivalent functionality for all PowerShell editions.

    .PARAMETER Segments
        An array of path segments to join. At least one segment is required.

    .EXAMPLE
        Join-MultiplePaths -Segments @('C:\Users','Public','Documents','file.txt')

        Returns: C:\Users\Public\Documents\file.txt (on Windows)

    .EXAMPLE
        Join-MultiplePaths -Segments @('usr','local','bin')

        Returns: usr/local/bin (on macOS/Linux) or usr\local\bin (on Windows)

    .EXAMPLE
        $parts = @('usr','local','bin'); Join-MultiplePaths -Segments $parts

        Returns: usr/local/bin (on macOS/Linux) or usr\local\bin (on Windows)

    .EXAMPLE
        Join-MultiplePaths -Segments @($PSScriptRoot, 'Public', '*.ps1')

        Returns: /path/to/module/Public/*.ps1 (cross-platform)

    .NOTES
        Compatible with PowerShell Desktop 5.1 and PowerShell Core 6.2+.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
                if ($null -eq $_) { throw 'Segments array cannot be null' }
                if ($_.Count -eq 0) { throw 'Segments array cannot be empty' }
                $validSegments = $_ | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                if ($validSegments.Count -eq 0) { throw 'At least one non-empty segment is required' }
                return $true
            })]
        [string[]]$Segments
    )

    begin
    {
        $prefix = 'Join-MultiplePaths>'
    }

    process
    {
        # Filter out null, empty, or whitespace-only segments (same as ValidateScript validation)
        $validSegments = $Segments | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        # Join all segments using Join-Path with explicit parameters
        $currentPath = $validSegments[0]
        for ($i = 1; $i -lt $validSegments.Count; $i++)
        {
            $currentPath = Join-Path -Path $currentPath -ChildPath $validSegments[$i]
        }

        Write-Verbose "$prefix Joined $($validSegments.Count) segments: $currentPath"
        Write-Output $currentPath
    }
}
