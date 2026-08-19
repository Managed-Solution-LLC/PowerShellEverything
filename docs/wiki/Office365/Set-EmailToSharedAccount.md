# Set-EmailToSharedAccount.ps1

## Overview

Converts regular Exchange Online user mailboxes to Shared Mailboxes and removes all assigned Microsoft 365 licenses in bulk. Commonly used during offboarding, tenant migrations, and cost-reduction initiatives where accounts need to remain accessible but no longer require a paid license.

## Features

- **Bulk conversion** — CSV file, in-memory array, or single-identity input
- **Mailbox type conversion** — `Set-Mailbox -Type Shared` via Exchange Online
- **License removal** — Strips all assigned SKUs via Microsoft Graph
- **Already-shared detection** — Skips conversion if mailbox is already a Shared type (non-fatal warning)
- **No-license graceful handling** — Skips license removal if no licenses are assigned (non-fatal)
- **WhatIf support** — Simulate all changes without applying them
- **Timestamped CSV report** — Full per-account results with conversion and license status
- **Template generation** — `-GenerateTemplate` creates a pre-formatted input CSV

## Prerequisites

### PowerShell Version
- PowerShell 5.1 or later (PowerShell 7 recommended)

### Required Modules

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser  # Only needed for license removal
```

> **Note:** If using `-SkipLicenseRemoval`, only `ExchangeOnlineManagement` is required.

### Required Permissions

| Role | Purpose |
|---|---|
| Exchange Online Administrator _or_ Exchange Recipient Administrator | Convert mailbox type |
| User Administrator _or_ License Administrator | Remove Microsoft 365 licenses |

## Parameters

### Input Parameters (Mutually Exclusive)

| Parameter | Type | Description |
|---|---|---|
| `-CsvPath` | String | Path to CSV file with an `Identity` column (UPN or primary SMTP). |
| `-UserArray` | Object[] | Array of PSCustomObjects/hashtables with an `Identity` property. |
| `-Identity` | String | Single UPN or primary SMTP for one-off conversion. |

### Behavior Options

| Parameter | Description |
|---|---|
| `-SkipLicenseRemoval` | Convert mailbox type only; do not remove licenses. Useful when license management is handled separately. |
| `-WhatIf` | Simulate all changes without applying them. |

### Output

| Parameter | Default | Description |
|---|---|---|
| `-OutputDirectory` | `C:\Reports\CSV_Exports` | Directory where the results CSV is saved. |
| `-GenerateTemplate` | — | Creates a blank CSV template and exits. |

## CSV Format

### Input CSV

```csv
Identity
jsmith@contoso.com
agarcia@contoso.com
departed@contoso.com
```

Only the `Identity` column is required.

### Output CSV Columns

| Column | Description |
|---|---|
| `Identity` | Input identity value |
| `MailboxConverted` | Success / AlreadyShared / WhatIf / No |
| `LicensesRemoved` | Count of SKUs removed, or "Skipped" / "None" / "N/A" |
| `LicensesSkipped` | Count of SKUs that failed removal |
| `Status` | Success / PartialSuccess / Failed |
| `Details` | Additional context for warnings or errors |
| `Timestamp` | Time the account was processed |

## Usage Examples

### Single Account

```powershell
.\Set-EmailToSharedAccount.ps1 -Identity "jsmith@contoso.com"
```

### Single Account — Convert Only (Keep License)

```powershell
.\Set-EmailToSharedAccount.ps1 -Identity "jsmith@contoso.com" -SkipLicenseRemoval
```

### Bulk from CSV

```powershell
.\Set-EmailToSharedAccount.ps1 -CsvPath "C:\Data\offboard.csv"
```

### Bulk from CSV — Preview First

```powershell
.\Set-EmailToSharedAccount.ps1 -CsvPath "C:\Data\offboard.csv" -WhatIf
```

### From Array

```powershell
$users = @(
    [PSCustomObject]@{ Identity = "alice@contoso.com" }
    [PSCustomObject]@{ Identity = "bob@contoso.com" }
)
.\Set-EmailToSharedAccount.ps1 -UserArray $users
```

### Generate CSV Template

```powershell
.\Set-EmailToSharedAccount.ps1 -GenerateTemplate -OutputDirectory "C:\Data"
# Creates: C:\Data\SharedMailbox_Template.csv
```

## Behavior Notes

### License Removal
All SKUs assigned to the account are removed via `Set-MgUserLicense`. If the account has no licenses, this step is silently skipped and logged as "None" — it is not treated as an error.

### Already-Shared Mailboxes
If the mailbox is already of type `SharedMailbox`, the conversion step is skipped with a warning. License removal still proceeds unless `-SkipLicenseRemoval` is specified.

### Partial Success
If the mailbox conversion succeeds but license removal fails (or vice versa), the row is logged as `PartialSuccess` rather than `Failed`.

### Shared Mailbox License Requirements
Shared mailboxes do not require a paid license as long as the total mailbox size stays under 50 GB. Above 50 GB, an Exchange Online Plan 2 license is required.

## Output

```
Output file: C:\Reports\CSV_Exports\SharedMailbox_Results_YYYYMMDD_HHmmss.csv
```

## Common Issues & Troubleshooting

### "Mailbox Not Found"
Verify the UPN or primary SMTP is correct. The account must have an Exchange Online mailbox (not just an Entra ID account).

### License Removal Fails but Conversion Succeeds
Check that the authenticated account has at least **User Administrator** or **License Administrator** role. The script logs these as `PartialSuccess` so they're easy to identify in the CSV.

### Module Not Found
```powershell
Install-Module ExchangeOnlineManagement, Microsoft.Graph.Users -Scope CurrentUser
```

### No Write Permission to Output Directory
Run the script as a user with write access to the output path, or specify a different `-OutputDirectory`.

## Version History

- **v1.0** (2026-03-13): Initial release — bulk shared mailbox conversion, license removal, CSV/array/single input, WhatIf support, template generation

## See Also

- [Microsoft Docs: Set-Mailbox](https://learn.microsoft.com/powershell/module/exchange/set-mailbox)
- [Microsoft Docs: Assign/Remove Licenses via Graph](https://learn.microsoft.com/graph/api/user-assignlicense)
- [Invoke-UserSignOutAndBlock](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Invoke-UserSignOutAndBlock) — Block sign-in and revoke sessions for offboarded accounts
- [Set-SMTPForward](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Set-SMTPForward) — Configure SMTP forwarding to redirect mail after conversion
