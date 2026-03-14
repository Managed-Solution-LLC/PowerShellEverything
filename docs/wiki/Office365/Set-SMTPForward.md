# Set-SMTPForward.ps1

## Overview

Configures SMTP forwarding on Exchange Online mailboxes in bulk. Supports setting, clearing, or toggling `DeliverToMailboxAndForward` for any number of mailboxes via CSV file, in-memory array, or single-user parameters. Commonly used during tenant migrations, offboarding workflows, and domain transitions.

## Features

- **Set or clear forwarding** — Set `ForwardingSmtpAddress` or leave blank to clear it
- **Deliver-to-mailbox control** — Toggle `DeliverToMailboxAndForward` per mailbox
- **Bulk operation** — CSV file, array, or single-identity input
- **Auto-forward policy management** — Optional `-AllowAutoForward` updates the tenant outbound spam filter to permit external auto-forwarding
- **WhatIf support** — Preview all changes without applying them
- **Timestamped CSV report** — Full per-mailbox results
- **Template generation** — `-GenerateTemplate` creates a pre-formatted input CSV

## Prerequisites

### PowerShell Version
- PowerShell 5.1 or later (PowerShell 7 recommended)

### Required Module

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

### Required Permissions

| Role | Purpose |
|---|---|
| Exchange Online Administrator _or_ Exchange Recipient Administrator | Set forwarding on mailboxes |
| Exchange Online Administrator | Update outbound spam filter policy (`-AllowAutoForward`) |

## Parameters

### Input Parameters (Mutually Exclusive)

| Parameter | Type | Description |
|---|---|---|
| `-CsvPath` | String | Path to CSV file. Required columns: `Identity`, `ForwardingAddress`, `DeliverToMailboxAndForward`. |
| `-UserArray` | Object[] | Array of PSCustomObjects/hashtables with the same properties as the CSV. |
| `-Identity` | String | Single mailbox UPN or SMTP address. Use with `-ForwardingAddress`. |

### Single-User Parameters (used with `-Identity`)

| Parameter | Default | Description |
|---|---|---|
| `-ForwardingAddress` | `""` | Target SMTP address. Leave empty to **clear** forwarding. |
| `-DeliverToMailboxAndForward` | `$true` | Keep a copy in the original mailbox while forwarding. |

### Behavior Options

| Parameter | Description |
|---|---|
| `-AllowAutoForward` | Updates the Default outbound spam filter policy to `AutoForwardingMode = On`. **Tenant-wide change** — use only with documented approval. |
| `-WhatIf` | Simulate all changes without applying them. |

### Output

| Parameter | Default | Description |
|---|---|---|
| `-OutputDirectory` | `C:\Reports\CSV_Exports` | Directory where the results CSV is saved. |
| `-GenerateTemplate` | — | Creates a blank CSV template and exits. |

## CSV Format

### Input CSV

```csv
Identity,ForwardingAddress,DeliverToMailboxAndForward
jsmith@contoso.com,jsmith@fabrikam.com,TRUE
agarcia@contoso.com,agarcia@fabrikam.com,FALSE
departed@contoso.com,,FALSE
```

| Column | Required | Description |
|---|---|---|
| `Identity` | Yes | UPN or primary SMTP of the source mailbox |
| `ForwardingAddress` | Yes | Target SMTP address. **Leave blank to clear forwarding.** |
| `DeliverToMailboxAndForward` | Yes | `TRUE` = keep a copy in source mailbox; `FALSE` = forward only |

> **Note:** A blank `ForwardingAddress` with any `DeliverToMailboxAndForward` value will **clear** forwarding from the mailbox.

### Output CSV Columns

| Column | Description |
|---|---|
| `Identity` | Source mailbox identity |
| `ForwardingAddress` | Forwarding address that was set or cleared |
| `DeliverToMailboxAndForward` | Value applied |
| `Status` | Success / Cleared / WhatIf-Set / WhatIf-Clear / Failed |
| `Details` | Additional context for warnings or errors |
| `Timestamp` | Time the mailbox was processed |

## Usage Examples

### Set Forwarding — Single Mailbox

```powershell
.\Set-SMTPForward.ps1 -Identity "jsmith@contoso.com" -ForwardingAddress "jsmith@fabrikam.com"
```

Keeps a copy in the original mailbox (default: `DeliverToMailboxAndForward = $true`).

### Set Forwarding — Forward Only (No Local Copy)

```powershell
.\Set-SMTPForward.ps1 -Identity "jsmith@contoso.com" `
    -ForwardingAddress "jsmith@fabrikam.com" `
    -DeliverToMailboxAndForward $false
```

### Clear Forwarding — Single Mailbox

```powershell
.\Set-SMTPForward.ps1 -Identity "jsmith@contoso.com"
```

Omitting `-ForwardingAddress` clears any existing forwarding.

### Bulk from CSV

```powershell
.\Set-SMTPForward.ps1 -CsvPath "C:\Data\forwards.csv"
```

### Bulk from CSV — With Auto-Forward Policy

```powershell
.\Set-SMTPForward.ps1 -CsvPath "C:\Data\forwards.csv" -AllowAutoForward
```

### Preview Without Making Changes

```powershell
.\Set-SMTPForward.ps1 -CsvPath "C:\Data\forwards.csv" -WhatIf
```

### From Array

```powershell
$forwards = @(
    [PSCustomObject]@{ Identity = "alice@contoso.com"; ForwardingAddress = "alice@fabrikam.com"; DeliverToMailboxAndForward = $true  }
    [PSCustomObject]@{ Identity = "bob@contoso.com";   ForwardingAddress = "bob@fabrikam.com";   DeliverToMailboxAndForward = $false }
    [PSCustomObject]@{ Identity = "old@contoso.com";   ForwardingAddress = "";                   DeliverToMailboxAndForward = $false }
)
.\Set-SMTPForward.ps1 -UserArray $forwards
```

### Generate CSV Template

```powershell
.\Set-SMTPForward.ps1 -GenerateTemplate -OutputDirectory "C:\Data"
# Creates: C:\Data\SMTPForward_Template.csv
```

## Behavior Notes

### Auto-Forwarding Policy (`-AllowAutoForward`)
By default, Microsoft 365 tenants block external auto-forwarding via the outbound spam filter. The `-AllowAutoForward` switch updates the **Default** outbound spam filter policy to `AutoForwardingMode = On`, which is a **tenant-wide setting**. This should only be used when:
- External forwarding is a documented business requirement
- The change has been reviewed and approved
- You plan to revert it after the migration or task is complete

AutoForwardingMode values:
| Value | Behavior |
|---|---|
| `Automatic` | Respects Remote Domain auto-forward setting (default) |
| `On` | Permits auto-forwarding regardless of Remote Domain settings |
| `Off` | Blocks all auto-forwarding tenant-wide |

### Clearing Forwarding
A blank or empty `ForwardingAddress` value in CSV or array will call `Set-Mailbox -ForwardingSmtpAddress $null`, which removes any existing forwarding configuration.

### Session Reuse
If you are already connected to Exchange Online in the same session, the script detects the existing connection and reuses it without prompting for credentials again.

## Output

```
Output file: C:\Reports\CSV_Exports\SMTPForward_Results_YYYYMMDD_HHmmss.csv
```

## Common Issues & Troubleshooting

### Forwarding Blocked by Tenant Policy
If forwarding is configured correctly but emails are not arriving at the destination, check the outbound spam filter policy. Run with `-AllowAutoForward` or manually set:
```powershell
Set-HostedOutboundSpamFilterPolicy -Identity Default -AutoForwardingMode On
```

### "Mailbox Not Found"
Verify the UPN or primary SMTP address. The account must have an Exchange Online mailbox.

### Module Not Found
```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

### Target Address in Another Tenant's `onmicrosoft.com` Domain
You may need to confirm the exact target address with the destination tenant before setting up forwarding. Unconfirmed `onmicrosoft.com` addresses should be skipped until verified.

## Version History

- **v1.0** (2026-03-13): Initial release — bulk SMTP forwarding, clear support, array/CSV/single input, `-AllowAutoForward`, WhatIf, template generation

## See Also

- [Microsoft Docs: Set-Mailbox](https://learn.microsoft.com/powershell/module/exchange/set-mailbox)
- [Microsoft Docs: Set-HostedOutboundSpamFilterPolicy](https://learn.microsoft.com/powershell/module/exchange/set-hostedoutboundspamfilterpolicy)
- [[Set-EmailToSharedAccount]] — Convert mailboxes to Shared and remove licenses
- [[Invoke-UserSignOutAndBlock]] — Block sign-in and revoke sessions
