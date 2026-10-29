# GPO baseline proposal (DESIGNED, not applied)

Apply in a controlled Windows lab, link to dedicated test OUs, validate resultant policy, and document rollback before broader use. No GPO in this list has been created or tested on a Windows domain.

| Policy area | Proposed setting | Scope / validation note |
| --- | --- | --- |
| Account policy | Password and lockout policy aligned to current organizational risk and Microsoft's current guidance | Domain policy; test service-account impact and recovery procedures |
| Workstation lock | Screen saver/lock timeout and secure resume | Workstation OU; test accessibility requirements |
| Defender | Real-time protection, cloud protection and tamper-protection strategy | Endpoint management may own some controls; check policy conflicts |
| Windows Firewall | Enabled for all profiles with managed inbound exceptions | Test remote administration before enforcement |
| Removable media | Restrict by data classification and approved exception process | Avoid blanket deployment without operational review |
| Updates | Ring-based deployment with deadline and restart communication | Coordinate with Intune/WSUS ownership; do not create conflicting policies |
| Browser baseline | Supported-browser updates, SmartScreen/reputation controls, extension governance | Validate enterprise applications and current vendor templates |
| Local administrators | Role-based assignment and LAPS-managed local recovery | No shared static local admin password |
| PowerShell | Script block/module logging and transcription with protected log access | Review privacy, storage and log forwarding before enablement |
| Audit policy | Account, logon, directory access, policy change and process events as justified | Size event logs and define collection/retention before enabling |

GPO change workflow: export/backup existing policy → test on a pilot OU → inspect `gpresult` and event logs → verify recovery path → staged rollout → monitor → restore prior policy if impact is detected.
