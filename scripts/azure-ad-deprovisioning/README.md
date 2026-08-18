# Entra ID Automated Deprovisioning

An Azure Automation runbook that finds leaver / long-inactive accounts and
deprovisions them: disable sign-in, revoke active sessions, strip group
membership, and reclaim licenses — idempotent, so it's safe to run on a
recurring schedule rather than as a one-off.

## Why Managed Identity instead of an app registration secret

The runbook authenticates via the Automation Account's system-assigned
Managed Identity (`Connect-MgGraph -Identity`). That means there's no client
secret to rotate, store, or accidentally leak in runbook output — the
identity's Graph permissions are the entire credential surface, and they're
scoped to exactly the four permissions the script uses.

## Setup

1. Enable a system-assigned Managed Identity on the Automation Account.
2. Grant it these Graph **application** permissions (admin consent
   required): `User.ReadWrite.All`, `Directory.ReadWrite.All`,
   `UserAuthenticationMethod.ReadWrite.All`.
3. Import `Microsoft.Graph` modules into the Automation Account's module
   gallery.
4. Publish `Deprovision-InactiveUsers.ps1` as a PowerShell runbook, schedule
   weekly, run once with `-WhatIf` first to validate the candidate list.

## Safety notes

- Always dry-run (`-WhatIf`) after any change to the inactivity threshold
  or candidate query before letting a scheduled run apply changes.
- Group removal is wrapped in try/catch per group so one protected/
  role-assignable group doesn't abort the whole run for that user.
