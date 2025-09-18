function Remove-ItemAlternative
{
    <#
    .SYNOPSIS
        Removes files and folders using an alternative method for cloud storage compatibility.

    .DESCRIPTION
        Removes all files and folders within a specified path using the .NET Delete() methods
        instead of PowerShell's Remove-Item cmdlet. This approach resolves access denied issues
        commonly encountered when deleting items from cloud-synced folders like Apple iCloud,
        Microsoft OneDrive, or Google Drive. The function supports ShouldProcess for safe testing.

    .PARAMETER LiteralPath
        The path to the directory to remove. The value is used exactly as typed without
        wildcard interpretation. If the path contains escape characters, enclose it in
        single quotes to prevent PowerShell from interpreting them as escape sequences.

    .PARAMETER SkipTopLevelFolder
        When specified, only the contents of the folder are deleted, leaving the top-level
        folder intact. This is useful when you want to clear a directory but keep the
        folder structure.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        None. This function does not return any objects.

    .NOTES
        - Uses SupportsShouldProcess for WhatIf and Confirm support
        - Specifically designed to work with cloud storage providers (iCloud, OneDrive)
        - Falls back to .NET Delete() methods when PowerShell Remove-Item fails
        - Processes files first, then directories, then the root folder if not skipped
        - Continues processing even if individual items fail to delete

    .EXAMPLE
        PS > Remove-ItemAlternative -LiteralPath "C:\Users\John\OneDrive\OldBackups"

        Removes the entire OldBackups folder and all its contents

    .EXAMPLE
        PS > Remove-ItemAlternative -LiteralPath "C:\Users\John\iCloud\TempFiles" -SkipTopLevelFolder

        Clears the TempFiles folder contents but keeps the folder itself

    .EXAMPLE
        PS > Remove-ItemAlternative -LiteralPath "C:\CloudFolder\Data" -WhatIf

        Shows what would be deleted without actually removing anything

    .LINK
        https://evotec.xyz/remove-item-access-to-the-cloud-file-is-denied-while-deleting-files-from-onedrive/

    .LINK
        https://jonlabelle.com/snippets/view/powershell/powershell-remove-item-access-denied-fix
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]
        $LiteralPath,

        [Parameter()]
        [switch]
        $SkipTopLevelFolder
    )

    if ($LiteralPath -and (Test-Path -LiteralPath $LiteralPath))
    {
        $items = Get-ChildItem -LiteralPath $LiteralPath -Recurse
        foreach ($item in $items)
        {
            if ($item.PSIsContainer -eq $false)
            {
                try
                {
                    if ($PSCmdlet.ShouldProcess($item.Name))
                    {
                        $item.Delete()
                    }
                }
                catch
                {
                    Write-Warning "Remove-ItemAlternative> Couldn't delete $($item.FullName), error: $($_.Exception.Message)"
                }
            }
        }

        $items = Get-ChildItem -LiteralPath $LiteralPath -Recurse
        foreach ($item in $items)
        {
            try
            {
                if ($PSCmdlet.ShouldProcess($item.Name))
                {
                    $item.Delete()
                }
            }
            catch
            {
                Write-Warning "Remove-ItemAlternative> Couldn't delete '$($item.FullName)', Error: $($_.Exception.Message)"
            }
        }

        if (-not $SkipTopLevelFolder)
        {
            $item = Get-Item -LiteralPath $LiteralPath
            try
            {
                if ($PSCmdlet.ShouldProcess($item.Name))
                {
                    $item.Delete($true)
                }
            }
            catch
            {
                Write-Warning "Remove-ItemAlternative> Couldn't delete '$($item.FullName)', Error: $($_.Exception.Message)"
            }
        }
    }
    else
    {
        Write-Warning "Remove-ItemAlternative> Path '$LiteralPath' doesn't exist. Skipping."
    }
}
