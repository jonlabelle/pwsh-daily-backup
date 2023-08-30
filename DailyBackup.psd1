# ----------------------------------------------------------------------
# Module manifest for module 'DailyBackup'
#
# Generated by: Jon LaBelle
# Generated on: 4/21/2022
#
# Command used to generate module manifest:
# PS> New-ModuleManifest -Path DailyBackup.psd1 -PassThru
#
# More information on New-ModuleManifest:
# https://docs.microsoft.com/powershell/module/microsoft.powershell.core/new-modulemanifest
# ----------------------------------------------------------------------

@{
  # Script module or binary module file associated with this manifest.
  RootModule = 'DailyBackup.psm1'

  # Version number of this module.
  ModuleVersion = '1.1.1'

  # Supported PSEditions
  # CompatiblePSEditions = @()

  # ID used to uniquely identify this module
  GUID = '015396f2-c652-4dfd-a53a-5a761c32a6d1'

  # Author of this module
  Author = 'Jon LaBelle'

  # Company or vendor of this module
  CompanyName = ''

  # Copyright statement for this module
  Copyright = '(c) Jon LaBelle. All rights reserved.'

  # Description of the functionality provided by this module
  Description = 'Perform simple, daily backups.'

  # Minimum version of the PowerShell engine required by this module
  PowerShellVersion = '5.1'

  # Name of the PowerShell host required by this module
  # PowerShellHostName = ''

  # Minimum version of the PowerShell host required by this module
  # PowerShellHostVersion = ''

  # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # DotNetFrameworkVersion = ''

  # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # ClrVersion = ''

  # Processor architecture (None, X86, Amd64) required by this module
  # ProcessorArchitecture = ''

  # Modules that must be imported into the global environment prior to importing this module
  # RequiredModules = @()

  # Assemblies that must be loaded prior to importing this module
  # RequiredAssemblies = @()

  # Script files (.ps1) that are run in the caller's environment prior to importing this module.
  # ScriptsToProcess = @()

  # Type files (.ps1xml) to be loaded when importing this module
  # TypesToProcess = @()

  # Format files (.ps1xml) to be loaded when importing this module
  # FormatsToProcess = @()

  # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
  # NestedModules = @()

  # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
  FunctionsToExport = @('New-DailyBackup')

  # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
  CmdletsToExport = @()

  # Variables to export from this module
  # VariablesToExport = '*'

  # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
  AliasesToExport = @()

  # DSC resources to export from this module
  # DscResourcesToExport = @()

  # List of all modules packaged with this module
  # ModuleList = @('DailyBackup.psm1')

  # List of all files packaged with this module
  FileList = @('DailyBackup.psm1', 'DailyBackup.psd1', 'README.md', 'LICENSE.txt')

  # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
  PrivateData = @{

    PSData = @{

      # Tags applied to this module. These help with module discovery in online galleries.
      Tags = @('backup', 'archive', 'daily', 'compress')

      # A URL to the license for this module.
      LicenseUri = 'https://github.com/jonlabelle/pwsh-daily-backup/blob/main/LICENSE.txt'

      # A URL to the main website for this project.
      ProjectUri = 'https://github.com/jonlabelle/pwsh-daily-backup'

      # A URL to an icon representing this module.
      # IconUri = ''

      # ReleaseNotes of this module
      ReleaseNotes = 'Routine updates and maintenance.'

      # Prerelease string of this module
      # Prerelease = ''

      # Flag to indicate whether the module requires explicit user acceptance for install/update/save
      RequireLicenseAcceptance = $false

      # External dependent modules of this module
      # ExternalModuleDependencies = @()

    } # End of PSData hashtable

  } # End of PrivateData hashtable

  # HelpInfo URI of this module
  HelpInfoURI = 'https://github.com/jonlabelle/pwsh-daily-backup/issues'

  # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
  # DefaultCommandPrefix = ''
}
