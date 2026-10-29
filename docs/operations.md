# Operator workflow and safety

The PowerShell module requires Windows PowerShell 5.1 or PowerShell 7 on a supported Windows host with RSAT ActiveDirectory and appropriate delegated permissions. This Linux host has no Windows domain or RSAT module; commands here are not represented as executed against AD.

1. Review the proposed change and validate the target OU/group with the identity owner.
2. Import the module from a trusted checked-out path and authenticate through the normal Windows session; never embed credentials.
3. Supply a `SecureString` password from a protected interactive process, then use `-WhatIf` for the first pass.
4. Review every action/output and obtain the organization's normal change approval.
5. Re-run without `-WhatIf`, verify the resulting object and audit record, and report exceptions.

```powershell
Import-Module ./module/DomainCore/DomainCore.psd1
$password = Read-Host 'Temporary initial password' -AsSecureString
New-DomainCoreUser -SamAccountName 'jane.doe' `
  -UserPrincipalName 'jane.doe@example.invalid' -GivenName Jane -Surname Doe `
  -Path 'OU=Users,DC=example,DC=invalid' -InitialPassword $password -WhatIf
```

The `.invalid` suffix is an example reserved for documentation. Replace it only inside an authorized test domain. The module does not generate, store, email or log passwords. Bulk onboarding prompts for one separate hidden `SecureString` per account; the values are held only in process memory and the temporary map is cleared after the batch. New accounts are disabled unless `-Enabled` is explicitly provided. The module preflights the complete CSV, OU existence and existing account collisions before making changes; AD operations are not transactional, so review results and reconcile if a concurrent change or directory failure interrupts a batch. Offboarding disables and retains an account; deletion and mailbox/session cleanup are intentionally outside this module.
