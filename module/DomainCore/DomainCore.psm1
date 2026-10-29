Set-StrictMode -Version Latest

function Assert-DomainCoreActiveDirectory {
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw 'The RSAT ActiveDirectory PowerShell module is required. No domain changes were made.'
    }
    Import-Module ActiveDirectory -ErrorAction Stop
}

<#[
.SYNOPSIS
Creates a user in an explicitly selected Active Directory OU.
.DESCRIPTION
Uses validated values and SupportsShouldProcess. New accounts start disabled unless -Enabled is supplied.
#>
function New-DomainCoreUser {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]{0,19}$')][string]$SamAccountName,
        [Parameter(Mandatory)][ValidateLength(3,256)][ValidatePattern('^[^\s@]+@[^\s@]+\.[^\s@]+$')][string]$UserPrincipalName,
        [Parameter(Mandatory)][ValidateLength(1,64)][string]$GivenName,
        [Parameter(Mandatory)][ValidateLength(1,64)][string]$Surname,
        [Parameter(Mandatory)][ValidatePattern('^OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}(,OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63})*,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62}(,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62})+$')][string]$Path,
        [Parameter(Mandatory)][Security.SecureString]$InitialPassword,
        [switch]$Enabled
    )
    Assert-DomainCoreActiveDirectory
    if ($SamAccountName -match '["''\\]') { throw 'The account name contains a disallowed character.' }
    $existing = Get-ADUser -Identity $SamAccountName -ErrorAction SilentlyContinue
    if ($existing) { throw "Account '$SamAccountName' already exists; no changes were made." }
    $displayName = "$GivenName $Surname"
    if ($PSCmdlet.ShouldProcess("$displayName <$SamAccountName>", 'Create AD user in approved OU')) {
        $parameters = @{
            SamAccountName = $SamAccountName; UserPrincipalName = $UserPrincipalName
            GivenName = $GivenName; Surname = $Surname; Name = $displayName; DisplayName = $displayName
            Path = $Path; AccountPassword = $InitialPassword; ChangePasswordAtLogon = $true
            Enabled = [bool]$Enabled; ErrorAction = 'Stop'
        }
        New-ADUser @parameters
        Get-ADUser -Identity $SamAccountName -Properties Enabled, DistinguishedName
    }
}

<#[
.SYNOPSIS
Preflights and provisions a CSV batch with a separate SecureString per account.
.DESCRIPTION
Validates the complete batch, target OU, password map and existing account collisions before any write.
#>
function Import-DomainCoreUserBatch {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)][ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})][string]$CsvPath,
        [Parameter(Mandatory)][ValidatePattern('^OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}(,OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63})*,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62}(,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62})+$')][string]$Path,
        [Parameter(Mandatory)][ValidateNotNull()][hashtable]$PasswordByAccount,
        [switch]$Enabled
    )
    Assert-DomainCoreActiveDirectory
    $rows = @(Import-Csv -LiteralPath $CsvPath -ErrorAction Stop)
    if ($rows.Count -eq 0) { throw 'The CSV contains no user rows.' }
    $required = @('SamAccountName','UserPrincipalName','GivenName','Surname')
    $missing = @($required | Where-Object { $_ -notin $rows[0].PSObject.Properties.Name })
    if ($missing.Count) { throw "CSV schema is missing required columns: $($missing -join ', ')" }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($row in $rows) {
        if (-not $seen.Add([string]$row.SamAccountName)) { throw 'Duplicate SamAccountName in CSV; batch rejected before changes.' }
        foreach ($field in $required) {
            if ([string]::IsNullOrWhiteSpace([string]$row.$field)) { throw "CSV row has an empty required field: $field" }
        }
        if ($row.SamAccountName -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]{0,19}$' -or $row.UserPrincipalName -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
            throw 'CSV contains an invalid account name or UPN; batch rejected before changes.'
        }
    }
    $passwordNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($key in $PasswordByAccount.Keys) {
        if (-not $passwordNames.Add([string]$key)) { throw 'PasswordByAccount contains duplicate account keys ignoring case.' }
    }
    if ($passwordNames.Count -ne $rows.Count -or @($rows | Where-Object { -not $passwordNames.Contains([string]$_.SamAccountName) }).Count) {
        throw 'PasswordByAccount must contain one distinct SecureString entry for each CSV account and no extras.'
    }
    foreach ($row in $rows) {
        if ($PasswordByAccount[$row.SamAccountName] -isnot [Security.SecureString]) { throw 'Each account requires its own SecureString initial password.' }
    }
    $targetOu = Get-ADOrganizationalUnit -Identity $Path -ErrorAction Stop
    $collisions = @($rows | Where-Object { Get-ADUser -Identity $_.SamAccountName -ErrorAction SilentlyContinue })
    if ($collisions.Count) {
        $names = @($collisions | ForEach-Object { $_.SamAccountName }) -join ', '
        throw "Existing accounts found ($names); batch rejected before changes."
    }
    foreach ($row in $rows) {
        New-DomainCoreUser -SamAccountName $row.SamAccountName -UserPrincipalName $row.UserPrincipalName `
            -GivenName $row.GivenName -Surname $row.Surname -Path $targetOu.DistinguishedName `
            -InitialPassword $PasswordByAccount[$row.SamAccountName] -Enabled:$Enabled -WhatIf:$WhatIfPreference
    }
}

<#[
.SYNOPSIS
Disables sign-in while retaining the directory object for approved offboarding.
#>
function Disable-DomainCoreUser {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param([Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]{0,19}$')][string]$SamAccountName)
    Assert-DomainCoreActiveDirectory
    $user = Get-ADUser -Identity $SamAccountName -Properties Enabled -ErrorAction Stop
    if (-not $user.Enabled) { return $user }
    if ($PSCmdlet.ShouldProcess($SamAccountName, 'Disable AD sign-in; retain object and memberships')) {
        Disable-ADAccount -Identity $user -ErrorAction Stop
        Get-ADUser -Identity $SamAccountName -Properties Enabled
    }
}

<#[
.SYNOPSIS
Creates a protected organizational unit if it does not already exist.
#>
function New-DomainCoreOrganizationalUnit {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}$')][string]$Name,
          [Parameter(Mandatory)][ValidatePattern('^(OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63},)*(DC=[A-Za-z0-9][A-Za-z0-9-]{0,62})(,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62})+$')][string]$ParentPath)
    Assert-DomainCoreActiveDirectory
    $dn = "OU=$Name,$ParentPath"
    $existing = Get-ADOrganizationalUnit -Identity $dn -ErrorAction SilentlyContinue
    if ($existing) { return $existing }
    if ($PSCmdlet.ShouldProcess($dn, 'Create protected organizational unit')) {
        New-ADOrganizationalUnit -Name $Name -Path $ParentPath -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
        Get-ADOrganizationalUnit -Identity $dn
    }
}

<#[
.SYNOPSIS
Creates a validated security or distribution group in a selected OU.
#>
function New-DomainCoreSecurityGroup {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param([Parameter(Mandatory)][ValidatePattern('^[A-Z][A-Z0-9-]{2,19}$')][string]$Name,
          [Parameter(Mandatory)][ValidatePattern('^OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}(,OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63})*,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62}(,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62})+$')][string]$Path,
          [ValidateSet('Global','Universal','DomainLocal')][string]$Scope='Global',
          [ValidateSet('Security','Distribution')][string]$Category='Security')
    Assert-DomainCoreActiveDirectory
    $existing = Get-ADGroup -Identity $Name -ErrorAction SilentlyContinue
    if ($existing) { return $existing }
    if ($PSCmdlet.ShouldProcess($Name, "Create $Scope $Category group")) {
        New-ADGroup -Name $Name -SamAccountName $Name -GroupScope $Scope -GroupCategory $Category -Path $Path -ErrorAction Stop
        Get-ADGroup -Identity $Name
    }
}

<#[
.SYNOPSIS
Adds a validated user to an existing security group when not already a member.
#>
function Add-DomainCoreGroupMember {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param([Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]{0,19}$')][string]$SamAccountName,
          [Parameter(Mandatory)][ValidatePattern('^[A-Z][A-Z0-9-]{2,19}$')][string]$Group)
    Assert-DomainCoreActiveDirectory
    $user = Get-ADUser -Identity $SamAccountName -ErrorAction Stop
    $target = Get-ADGroup -Identity $Group -ErrorAction Stop
    if ($target.GroupCategory -ne 'Security') { throw 'Distribution groups are not accepted by this security-group helper.' }
    $alreadyMember = @(Get-ADPrincipalGroupMembership -Identity $user -ErrorAction Stop | Where-Object { $_.DistinguishedName -eq $target.DistinguishedName })
    if ($alreadyMember.Count) { return $alreadyMember | Select-Object Name,GroupScope,GroupCategory }
    if ($PSCmdlet.ShouldProcess("$SamAccountName -> $Group", 'Add member to security group')) {
        Add-ADGroupMember -Identity $target -Members $user -ErrorAction Stop
        Get-ADPrincipalGroupMembership -Identity $user | Select-Object Name, GroupScope, GroupCategory
    }
}

<#[
.SYNOPSIS
Reports account state and review candidates under a selected OU.
#>
function Get-DomainCoreAccountReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidatePattern('^OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}(,OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63})*,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62}(,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62})+$')][string]$SearchBase,
          [ValidateRange(30,3650)][int]$StaleAfterDays=90)
    Assert-DomainCoreActiveDirectory
    $cutoff = (Get-Date).AddDays(-$StaleAfterDays)
    Get-ADUser -Filter * -SearchBase $SearchBase -Properties Enabled,LastLogonDate,PasswordLastSet,PasswordNeverExpires,AccountExpirationDate,DistinguishedName |
        Select-Object SamAccountName,UserPrincipalName,Enabled,LastLogonDate,PasswordLastSet,PasswordNeverExpires,AccountExpirationDate,DistinguishedName,
            @{Name='Stale';Expression={ -not $_.LastLogonDate -or $_.LastLogonDate -lt $cutoff }}
}

<#[
.SYNOPSIS
Returns a bounded computer inventory from a selected OU.
#>
function Get-DomainCoreWorkstationInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidatePattern('^OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}(,OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63})*,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62}(,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62})+$')][string]$SearchBase)
    Assert-DomainCoreActiveDirectory
    Get-ADComputer -Filter * -SearchBase $SearchBase -Properties Enabled,DNSHostName,OperatingSystem,OperatingSystemVersion,LastLogonDate,IPv4Address |
        Select-Object Name,DNSHostName,Enabled,OperatingSystem,OperatingSystemVersion,LastLogonDate
}

<#[
.SYNOPSIS
Summarizes read-only forest and domain configuration.
#>
function Get-DomainCoreConfigurationReport {
    [CmdletBinding()]
    param()
    Assert-DomainCoreActiveDirectory
    $domain = Get-ADDomain -ErrorAction Stop
    $forest = Get-ADForest -ErrorAction Stop
    [pscustomobject]@{ Domain=$domain.DNSRoot; Forest=$forest.Name; DomainMode=$domain.DomainMode; ForestMode=$forest.ForestMode; PDCEmulator=$domain.PDCEmulator; RIDMaster=$domain.RIDMaster; InfrastructureMaster=$domain.InfrastructureMaster; GlobalCatalogs=@($forest.GlobalCatalogs); CollectedAt=(Get-Date).ToUniversalTime() }
}

<#[
.SYNOPSIS
Performs a bounded DNS record query and reports resolution status.
#>
function Test-DomainCoreDnsRecord {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidatePattern('^(?=.{1,253}$)([A-Za-z0-9_](?:[A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?)(\.([A-Za-z0-9_](?:[A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?))*\.?$')][string]$Name,
          [ValidateSet('A','AAAA','CNAME','MX','SRV','TXT')][string]$Type='A',
          [switch]$QuickTimeout)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        $parameters = @{Name=$Name;Type=$Type;DnsOnly=$true;ErrorAction='Stop'}
        if ($QuickTimeout) { $parameters.QuickTimeout=$true }
        $records = @(Resolve-DnsName @parameters)
        [pscustomobject]@{ Query=$Name; Type=$Type; Result='RESOLVED'; Records=$records; DurationMs=$timer.ElapsedMilliseconds; Error=$null }
    } catch {
        [pscustomobject]@{ Query=$Name; Type=$Type; Result='FAILED'; Records=@(); DurationMs=$timer.ElapsedMilliseconds; Error=$_.Exception.GetType().Name }
    }
}

Export-ModuleMember -Function New-DomainCoreUser,Import-DomainCoreUserBatch,Disable-DomainCoreUser,New-DomainCoreOrganizationalUnit,New-DomainCoreSecurityGroup,Add-DomainCoreGroupMember,Get-DomainCoreAccountReport,Get-DomainCoreWorkstationInventory,Get-DomainCoreConfigurationReport,Test-DomainCoreDnsRecord
