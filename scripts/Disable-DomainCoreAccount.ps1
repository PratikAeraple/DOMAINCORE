[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param([Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]{0,19}$')][string]$SamAccountName)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../module/DomainCore/DomainCore.psd1') -Force
Disable-DomainCoreUser -SamAccountName $SamAccountName -WhatIf:$WhatIfPreference
