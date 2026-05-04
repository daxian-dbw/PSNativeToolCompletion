@{

# Script module or binary module file associated with this manifest.
RootModule = '.\PSNativeToolCompletion.psm1'

# Version number of this module.
ModuleVersion = '1.0.0'

# ID used to uniquely identify this module
GUID = 'd42488ac-2973-48e6-a21f-5da7482ff00a'

# Author of this module
Author = 'Dongbo Wang'

# Copyright statement for this module
Copyright = '(c) Dongbo Wang. All rights reserved.'

# Description of the functionality provided by this module
Description = 'This module enables lazy loading of argument completion scripts for native commands.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '7.6'

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Get-CompletionScript', 'Add-CompletionScript')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{
        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/daxian-dbw/PSNativeToolCompletion'
    }

}

}
