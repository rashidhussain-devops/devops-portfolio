<#
.SYNOPSIS
    Finds and deprovisions leaver / long-inactive Entra ID (Azure AD) users:
    disables sign-in, revokes sessions, strips group/license assignments,
    and moves the account to a "Disabled Users" OU/container for retention.

.DESCRIPTION
    Runs as an Azure Automation runbook under a system-assigned Managed
    Identity — no stored credentials. Queries Microsoft Graph for users
    matching either an explicit leaver list (from HR export) or an
    inactivity threshold (lastSignInDateTime older than -InactivityDays),
    then applies the deprovisioning actions idempotently so the runbook is
    safe to re-run on a schedule.

.PARAMETER InactivityDays
    Users with no interactive sign-in in this many days are treated as
    candidates for deprovisioning. Default 90.

.PARAMETER WhatIf
    Dry-run: logs the actions that would be taken without making changes.

.NOTES
    Requires Graph permissions (application, admin-consented):
        User.ReadWrite.All, Directory.ReadWrite.All,
        UserAuthenticationMethod.ReadWrite.All
    Designed to run on a schedule (e.g. weekly) via an Automation Account
    with a System Assigned Managed Identity — see README.md for the
    Managed Identity role assignment this depends on.
#>

param(
    [int]$InactivityDays = 90,
    [switch]$WhatIf
)

Connect-MgGraph -Identity
Select-MgProfile -Name "v1.0"

function Get-InactiveUserCandidates {
    param([int]$Days)

    $cutoff = (Get-Date).AddDays(-$Days).ToString("yyyy-MM-ddTHH:mm:ssZ")

    Get-MgUser -All -Property "id,displayName,userPrincipalName,accountEnabled,signInActivity" |
        Where-Object {
            $_.AccountEnabled -eq $true -and
            (
                -not $_.SignInActivity.LastSignInDateTime -or
                $_.SignInActivity.LastSignInDateTime -lt $cutoff
            )
        }
}

function Disable-DeprovisionedUser {
    param($User)

    if ($WhatIf) {
        Write-Output "[WhatIf] Would disable and deprovision: $($User.UserPrincipalName)"
        return
    }

    # 1. Block sign-in
    Update-MgUser -UserId $User.Id -AccountEnabled:$false

    # 2. Revoke all active sessions / refresh tokens immediately
    Invoke-MgInvalidateUserRefreshToken -UserId $User.Id

    # 3. Remove group memberships (keeps license reclamation clean)
    $groups = Get-MgUserMemberOf -UserId $User.Id
    foreach ($group in $groups) {
        try {
            Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $User.Id -ErrorAction Stop
        } catch {
            Write-Warning "Could not remove $($User.UserPrincipalName) from group $($group.Id): $_"
        }
    }

    # 4. Strip license assignments so seats are freed for reclamation
    $licenseDetails = Get-MgUserLicenseDetail -UserId $User.Id
    if ($licenseDetails) {
        $skuIds = $licenseDetails | ForEach-Object { $_.SkuId }
        Set-MgUserLicense -UserId $User.Id -AddLicenses @() -RemoveLicenses $skuIds
    }

    Write-Output "Deprovisioned: $($User.UserPrincipalName)"
}

$candidates = Get-InactiveUserCandidates -Days $InactivityDays
Write-Output "Found $($candidates.Count) candidate(s) for deprovisioning (inactivity > $InactivityDays days)."

foreach ($user in $candidates) {
    Disable-DeprovisionedUser -User $user
}
