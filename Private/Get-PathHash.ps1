function Get-PathHash
{
    <#
    .SYNOPSIS
        Calculates SHA-256 hash for a file or directory.

    .DESCRIPTION
        Computes cryptographic hash values for files and directories to enable
        backup integrity verification and change detection. For directories,
        creates a composite hash based on all contained files and their paths.

    .PARAMETER Path
        The file or directory path to hash.

    .PARAMETER Algorithm
        The hash algorithm to use.
        Available options: SHA1, SHA256, SHA384, SHA512, MD5.
        Defaults to SHA256.

    .OUTPUTS
        String containing the computed hash value.

    .NOTES
        For directories, the hash is computed by:
        1. Getting all files recursively with their relative paths
        2. Computing hash for each file
        3. Creating sorted list of "path:hash" entries
        4. Hashing the concatenated string

        This provides meaningful change detection for directory structures.

    .EXAMPLE
        PS > Get-PathHash -Path 'C:\Documents\report.pdf'
        Returns SHA-256 hash of the file

    .EXAMPLE
        PS > Get-PathHash -Path 'C:\Documents'
        Returns composite SHA-256 hash of the directory contents
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5')]
        [string] $Algorithm = 'SHA256'
    )

    try
    {
        if (-not (Test-Path -Path $Path))
        {
            Write-Warning "Get-PathHash> Path does not exist: $Path"
            return $null
        }

        if (Test-Path -Path $Path -PathType Leaf)
        {
            # File hash - straightforward
            Write-Verbose "Get-PathHash> Computing $Algorithm hash for file: $Path"
            $calculatedFileHashObject = Get-FileHash -Path $Path -Algorithm $Algorithm
            return $calculatedFileHashObject.Hash
        }
        else
        {
            # Directory hash - composite approach
            Write-Verbose "Get-PathHash> Computing $Algorithm composite hash for directory: $Path"

            $discoveredFiles = Get-ChildItem -Path $Path -File -Recurse | Sort-Object FullName
            if (-not $discoveredFiles)
            {
                Write-Verbose 'Get-PathHash> Empty directory, returning hash of empty string'
                $emptyDirectoryHashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
                $emptyDirectoryHashBytes = $emptyDirectoryHashAlgorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(''))
                $emptyDirectoryHashAlgorithm.Dispose()
                return [System.BitConverter]::ToString($emptyDirectoryHashBytes) -replace '-', ''
            }

            $collectedHashEntries = @()
            $resolvedBasePath = (Resolve-Path $Path).Path

            foreach ($currentFile in $discoveredFiles)
            {
                try
                {
                    $calculatedRelativePath = $currentFile.FullName.Substring($resolvedBasePath.Length).TrimStart('\', '/')
                    $currentFileHashObject = Get-FileHash -Path $currentFile.FullName -Algorithm $Algorithm
                    $collectedHashEntries += "${calculatedRelativePath}:$($currentFileHashObject.Hash)"
                }
                catch
                {
                    Write-Warning "Get-PathHash> Failed to hash file $($currentFile.FullName): $_"
                    # Include path with error marker for consistency
                    $calculatedRelativePath = $currentFile.FullName.Substring($resolvedBasePath.Length).TrimStart('\', '/')
                    $collectedHashEntries += "${calculatedRelativePath}:ERROR"
                }
            }

            # Create composite hash from sorted entries
            $sortedHashEntries = $collectedHashEntries | Sort-Object
            $combinedCompositeString = $sortedHashEntries -join "`n"

            $finalHashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
            $finalHashBytes = $finalHashAlgorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($combinedCompositeString))
            $finalHashAlgorithm.Dispose()

            $computedFinalHash = [System.BitConverter]::ToString($finalHashBytes) -replace '-', ''
            Write-Verbose "Get-PathHash> Computed composite hash from $($discoveredFiles.Count) files"
            return $computedFinalHash
        }
    }
    catch
    {
        Write-Warning "Get-PathHash> Failed to compute hash for $Path : $_"
        return $null
    }
}
