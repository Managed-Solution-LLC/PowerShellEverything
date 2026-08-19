# Invoke-UserSignOutAndBlock.ps1

## Overview

Immediately blocks sign-in, revokes all active sessions and refresh tokens, and optionally disables Entra ID-registered devices for one or more Microsoft 365 / Entra ID accounts. Designed for offboarding, incident response, and account compromise scenarios where rapid access revocation is required.

## Features

- **Block sign-in** — Sets `AccountEnabled = $false` so no new authentication attempts succeed
- **Revoke sessions** — Calls Microsoft Graph to invalidate all refresh tokens and active sessions immediately
- **Device reporting** — Lists all Entra ID-registered and Entra ID-joined devices owned by each account
- **Device disablement** — Optionally sets `AccountEnabled = $false` on each owned device in Entra ID (`-DisableDevices`)
- **Multiple input methods** — CSV file, in-memory array, or single UPN/Object ID
- **WhatIf support** — Preview all actions without making changes
- **Timestamped CSV results** — Full per-account report of every action taken

## Prerequisites

### PowerShell Version
- PowerShell 5.1 or PowerShell 7+

### Required Modules

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
```

### Required Permissions (Microsoft Graph)

| Permission | Purpose |
|---|---|
| `User.ReadWrite.All` | Block sign-in, read user details |
| `Directory.ReadWrite.All` | Revoke sign-in sessions |
| `Device.ReadWrite.All` | Disable Entra ID-registered devices |

## Parameters

### Input Parameters (Mutually Exclusive)

| Parameter | Type | Description |
|---|---|---|
| `-CsvPath` | String | Path to CSV file. Required column: `Identity`. Optional column: `Reason`. |
| `-UserArray` | Object[] | Array of PSCustomObjects/hashtables with at minimum an `Identity` property. |
| `-Identity` | String | Single UPN or Entra Object ID for a one-off operation. |

### Behavior Switches

| Parameter | Description |
|---|---|
| `-DisableDevices` | Also disable all Entra ID-registered/joined devices owned by each account. Without this switch, devices are reported but not modified. |
| `-SkipBlockSignIn` | Skip setting `AccountEnabled = $false`. Useful when you only want to revoke sessions. |
| `-SkipRevokeSession` | Skip session revocation. Useful when you only want to block sign-in or disable devices. |
| `-WhatIf` | Show what changes would be made without applying them. |

### Output

| Parameter | Default | Description |
|---|---|---|
| `-OutputDirectory` | `C:\Reports\CSV_Exports` | Directory where the results CSV is saved. |
| `-GenerateTemplate` | — | Creates a blank CSV template and exits. |

## CSV Format

### Input CSV

```csv
Identity,Reason
jdoe@contoso.com,Offboarding - last day 2026-03-13
jsmith@contoso.com,Account compromise - INC0012345
```

| Column | Required | Description |
|---|---|---|
| `Identity` | Yes | UPN or Entra Object ID |
| `Reason` | No | Logged to the results report for audit purposes |

### Output CSV Columns

| Column | Description |
|---|---|
| `Identity` | Input identity value |
| `DisplayName` | Resolved display name from Entra ID |
| `Reason` | Reason provided in input |
| `SignInBlocked` | Success / Failed / Skipped / WhatIf |
| `SessionsRevoked` | Success / Failed / Skipped / WhatIf |
| `DevicesFound` | Count of Entra ID-registered devices |
| `DevicesDisabled` | Count of devices disabled (requires `-DisableDevices`) |
| `DeviceNames` | Pipe-delimited list of device names and OS |
| `Status` | Success / CompletedWithErrors / Failed |
| `ErrorDetails` | Error messages if any step failed |
| `Timestamp` | Time the account was processed |

## Usage Examples

### Single Account — Block and Revoke Sessions

```powershell
.\Invoke-UserSignOutAndBlock.ps1 -Identity "jdoe@contoso.com"
```

### Single Account — Also Disable Devices

```powershell
.\Invoke-UserSignOutAndBlock.ps1 -Identity "jdoe@contoso.com" -DisableDevices
```

### Bulk from CSV

```powershell
.\Invoke-UserSignOutAndBlock.ps1 -CsvPath "C:\Data\offboard.csv" -DisableDevices
```

### From Array (scripted/automation scenarios)

```powershell
$accounts = @(
    [PSCustomObject]@{ Identity = "jdoe@contoso.com";   Reason = "Offboarding" }
    [PSCustomObject]@{ Identity = "jsmith@contoso.com"; Reason = "Account compromise" }
)
.\Invoke-UserSignOutAndBlock.ps1 -UserArray $accounts -DisableDevices
```

### Preview Without Making Changes

```powershell
.\Invoke-UserSignOutAndBlock.ps1 -CsvPath "C:\Data\offboard.csv" -WhatIf
```

### Generate CSV Template

```powershell
.\Invoke-UserSignOutAndBlock.ps1 -GenerateTemplate -OutputDirectory "C:\Data"
```

### Revoke Sessions Only (Don't Block Sign-In)

```powershell
.\Invoke-UserSignOutAndBlock.ps1 -Identity "jdoe@contoso.com" -SkipBlockSignIn
```

### Block Sign-In Only (Don't Revoke Sessions)

```powershell
.\Invoke-UserSignOutAndBlock.ps1 -Identity "jdoe@contoso.com" -SkipRevokeSession
```

## Important Behavior Notes

### Session Revocation vs. Access Token Expiry
Revoking sessions invalidates all **refresh tokens** immediately — the user cannot silently renew access. However, existing short-lived **access tokens** (typically 1-hour lifetime) remain valid until they naturally expire. Blocking sign-in (`AccountEnabled = $false`) prevents any renewal of those tokens, so combining both actions is the most effective approach.

### Device Disablement Scope
Disabling a device in Entra ID prevents it from authenticating to cloud services. However:
- The user's **local Windows session** on the device is not immediately terminated
- The device is **not wiped or retired** from Intune — use the Intune portal or a dedicated script for remote wipe

### What `-DisableDevices` Targets
Only devices where the user is the **registered owner** in Entra ID are affected. Shared/unowned devices used by the account are not modified.

## Output

```
Output file: C:\Reports\CSV_Exports\UserSignOutAndBlock_Results_YYYYMMDD_HHmmss.csv
```

## Common Issues & Troubleshooting

### "The property 'Count' cannot be found on this object"
This was a known issue with PowerShell 5.1 when `Get-MgUserOwnedDevice` returns a single object. Fixed in v1.0 by wrapping the result in `@()`.

### Module Not Found
```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
```

### Insufficient Permissions
Ensure the connecting account (or app registration) has `User.ReadWrite.All`, `Directory.ReadWrite.All`, and `Device.ReadWrite.All` granted in Entra ID.

### User Not Found
The script will log a `Failed` status for accounts that cannot be resolved and continue processing remaining accounts.

## Version History

- **v1.0** (2026-03-13): Initial release — block sign-in, revoke sessions, report/disable devices; CSV/array/single input; WhatIf support

## See Also

- [Microsoft Docs: Revoke Sign-In Sessions](https://learn.microsoft.com/en-us/graph/api/user-revokesigninsessions)
- [Microsoft Docs: Update User (AccountEnabled)](https://learn.microsoft.com/en-us/graph/api/user-update)
- [Microsoft Docs: Update Device](https://learn.microsoft.com/en-us/graph/api/device-update)
- [Set-EmailToSharedAccount](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Set-EmailToSharedAccount) — Convert offboarded mailboxes to shared and remove licenses
- [Set-SMTPForward](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Set-SMTPForward) — Configure SMTP forwarding during offboarding or migration
