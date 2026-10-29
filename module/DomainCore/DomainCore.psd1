@{
    RootModule = 'DomainCore.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'cb179df8-0fee-48f1-8b62-52e38868d700'
    Author = 'Pratik Aeraple'
    Description = 'Preview-first Active Directory lifecycle and inventory helpers for an authorized Windows lab.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('New-DomainCoreUser','Import-DomainCoreUserBatch','Disable-DomainCoreUser','New-DomainCoreOrganizationalUnit','New-DomainCoreSecurityGroup','Add-DomainCoreGroupMember','Get-DomainCoreAccountReport','Get-DomainCoreWorkstationInventory','Get-DomainCoreConfigurationReport','Test-DomainCoreDnsRecord')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{ PSData = @{ Tags = @('ActiveDirectory','PowerShell','EndpointManagement','DefensiveIT'); ProjectUri = 'https://github.com/PratikAeraple/DOMAINCORE' } }
}
