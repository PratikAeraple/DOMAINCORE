@{
    RootModule = 'ActiveDirectory.psm1'
    ModuleVersion = '1.0.0'
    GUID = '8f811729-c2a7-4839-b9c1-06a808a73cf6'
    Author = 'DOMAINCORE test fixture'
    Description = 'Non-mutating fake AD commands for isolated unit tests only.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('Get-ADUser','New-ADUser','Disable-ADAccount','Get-ADOrganizationalUnit')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
