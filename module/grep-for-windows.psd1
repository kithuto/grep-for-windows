# Module manifest for grep-for-windows.
# Source: https://github.com/kithuto/grep-for-windows
@{
    RootModule        = 'grep-for-windows.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'e76f5ede-fa94-4cd3-9e09-b250ec64c044'
    Author            = 'Ignasi Rovira'
    CompanyName       = 'kithuto'
    Copyright         = '(c) kithuto. MIT licensed.'
    Description       = 'Linux-style grep for PowerShell. Search files with familiar grep flags, colored output, recursion, glob filters, context lines and stdin support.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('grep', 'Uninstall-GrepForWindows')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags        = @('grep', 'search', 'find', 'cli', 'linux', 'unix', 'select-string')
            LicenseUri  = 'https://github.com/kithuto/grep-for-windows/blob/main/LICENSE'
            ProjectUri  = 'https://github.com/kithuto/grep-for-windows'
            ReleaseNotes = 'Restructured as a PowerShell module. Single line in $PROFILE replaces the inline 500-line block.'
        }
    }
}
