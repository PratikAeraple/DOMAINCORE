[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})][string]$CsvPath,
    [Parameter(Mandatory)][ValidatePattern('^OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}(,OU=[A-Za-z0-9][A-Za-z0-9 ._-]{0,63})*,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62}(,DC=[A-Za-z0-9][A-Za-z0-9-]{0,62})+$')][string]$TargetOU,
    [switch]$EnableAccounts
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../module/DomainCore/DomainCore.psd1') -Force
$rows = @(Import-Csv -LiteralPath $CsvPath -ErrorAction Stop)
if (-not $rows.Count) { throw 'The CSV contains no user rows.' }
$passwords = @{}
try {
    foreach ($row in $rows) {
        if ($passwords.ContainsKey($row.SamAccountName)) { throw 'Duplicate account in CSV; no directory changes were made.' }
        $passwords[$row.SamAccountName] = Read-Host "Unique temporary password for $($row.SamAccountName) (input hidden)" -AsSecureString
    }
    Import-DomainCoreUserBatch -CsvPath $CsvPath -Path $TargetOU -PasswordByAccount $passwords -Enabled:$EnableAccounts -WhatIf:$WhatIfPreference
}
finally {
    foreach ($securePassword in $passwords.Values) { $securePassword.Dispose() }
    $passwords.Clear()
    $rows = $null
}
