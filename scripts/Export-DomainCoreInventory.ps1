[CmdletBinding()]
param([Parameter(Mandatory)][ValidateScript({Test-Path -LiteralPath $_ -PathType Container})][string]$OutputDirectory,
      [Parameter(Mandatory)][ValidatePattern('^OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}(,OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63})*,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62}(,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62})+$')][string]$UserSearchBase,
      [Parameter(Mandatory)][ValidatePattern('^OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}(,OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63})*,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62}(,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62})+$')][string]$ComputerSearchBase,
      [ValidateRange(30,3650)][int]$StaleAfterDays=90)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../module/DomainCore/DomainCore.psd1') -Force
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
Get-DomainCoreAccountReport -SearchBase $UserSearchBase -StaleAfterDays $StaleAfterDays | Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath (Join-Path $OutputDirectory "accounts-$stamp.csv")
Get-DomainCoreWorkstationInventory -SearchBase $ComputerSearchBase | Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath (Join-Path $OutputDirectory "workstations-$stamp.csv")
Get-DomainCoreConfigurationReport | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $OutputDirectory "domain-$stamp.json")
