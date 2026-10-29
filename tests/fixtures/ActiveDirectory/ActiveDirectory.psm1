function Get-ADUser {
    param([string]$Identity,[string[]]$Properties)
    if ($Identity -eq 'already.exists') { return [pscustomobject]@{SamAccountName='already.exists';Enabled=$true} }
    if ($Identity -eq 'existing.user') { return [pscustomobject]@{SamAccountName='existing.user';Enabled=$true} }
    return $null
}
function Get-ADOrganizationalUnit { param([string]$Identity) [pscustomobject]@{DistinguishedName=$Identity} }
function New-ADUser {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Identity)
    throw 'Test fixture prevents directory writes.'
}
function Disable-ADAccount { throw 'Test fixture prevents directory writes.' }
