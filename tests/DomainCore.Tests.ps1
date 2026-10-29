BeforeAll {
    $env:PSModulePath = "$PSScriptRoot/fixtures$([IO.Path]::PathSeparator)$env:PSModulePath"
    Import-Module "$PSScriptRoot/../module/DomainCore/DomainCore.psd1" -Force
}

Describe 'DomainCore input safeguards' {
    It 'rejects invalid account names before calling AD' {
        { New-DomainCoreUser -SamAccountName 'bad/name' -UserPrincipalName 'a@example.test' -GivenName A -Surname B -Path 'OU=Users,DC=example,DC=test' -InitialPassword ([Security.SecureString]::new()) -WhatIf } | Should -Throw
    }

    It 'does not create a user in WhatIf mode' {
        $password=[Security.SecureString]::new()
        New-DomainCoreUser -SamAccountName 'new.user' -UserPrincipalName 'new.user@example.test' -GivenName Lab -Surname User -Path 'OU=Users,DC=example,DC=test' -InitialPassword $password -WhatIf
    }

    It 'rejects an invalid UPN' {
        { New-DomainCoreUser -SamAccountName 'lab.user' -UserPrincipalName 'not-an-email' -GivenName Lab -Surname User -Path 'OU=Users,DC=example,DC=test' -InitialPassword ([Security.SecureString]::new()) -WhatIf } | Should -Throw
    }

    It 'retains user objects when disabling accounts' {
        Disable-DomainCoreUser -SamAccountName 'existing.user' -WhatIf
    }

    It 'bounds stale-account reporting input' {
        { Get-DomainCoreAccountReport -SearchBase 'OU=Users,DC=example,DC=test' -StaleAfterDays 1 } | Should -Throw
    }

    It 'validates the whole bulk batch before WhatIf provisioning' {
        $csv = Join-Path $TestDrive 'users.csv'
        @('SamAccountName,UserPrincipalName,GivenName,Surname','new.one,new.one@example.test,New,One','new.two,new.two@example.test,New,Two') | Set-Content -LiteralPath $csv
        $passwords = @{ 'new.one'=[Security.SecureString]::new(); 'new.two'=[Security.SecureString]::new() }
        Import-DomainCoreUserBatch -CsvPath $csv -Path 'OU=Users,DC=example,DC=test' -PasswordByAccount $passwords -WhatIf
    }

    It 'rejects a batch with an existing account before any new user is processed' {
        $csv = Join-Path $TestDrive 'collision.csv'
        @('SamAccountName,UserPrincipalName,GivenName,Surname','new.one,new.one@example.test,New,One','already.exists,already.exists@example.test,Already,Exists') | Set-Content -LiteralPath $csv
        $passwords = @{ 'new.one'=[Security.SecureString]::new(); 'already.exists'=[Security.SecureString]::new() }
        { Import-DomainCoreUserBatch -CsvPath $csv -Path 'OU=Users,DC=example,DC=test' -PasswordByAccount $passwords -WhatIf } | Should -Throw '*batch rejected before changes*'
    }
}
