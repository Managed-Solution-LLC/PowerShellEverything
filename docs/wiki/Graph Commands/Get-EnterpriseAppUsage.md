# Get-EnterpriseAppUsage

## Overview

`Get-EnterpriseAppUsage.ps1` reports usage and ownership of all Azure AD Enterprise Applications (App Registrations) in a tenant. It retrieves each app's sign-in activity for a configurable timeframe, identifies application owners, and surfaces which apps are active vs. potentially stale. Results can be exported to JSON for further analysis.

## Features

- **Full App Inventory** - Retrieves all app registrations across the tenant
- **Sign-In Activity** - Correlates each app with audit sign-in events for a configurable number of days
- **Owner Identification** - Lists owner UPN, name, and Object ID for each app
- **Unowned App Detection** - Flags apps with no registered owners
- **Throttle Handling** - Implements automatic retry with back-off on 429 rate limit responses
- **JSON Export** - Optional export of all data to `EnterpriseAppUsage.json`
- **Client or Interactive Auth** - Supports both app-only and interactive authentication

## Prerequisites

### PowerShell Version
- PowerShell 5.1 or later

### Required Modules
- `Microsoft.Graph` (auto-installed if missing)
- `MSAL.PS` (installed by Get-GraphToken)

### Required Functions
- `Get-GraphToken` - Token acquisition
- `Get-GraphHeaders` - Authorization headers
- `Get-AzureResourcePaging` - Paginated app retrieval

### Required Permissions
| Permission | Type | Purpose |
|-----------|------|---------|
| `AuditLog.Read.All` | Application | Read sign-in activity |
| `Directory.Read.All` | Application | Read app registrations and owners |

## Parameters

### TenantId
**Type:** String  
**Required:** Yes  
**Description:** The Azure AD tenant ID to authenticate against.

### ClientId
**Type:** String  
**Required:** No  
**Description:** The app registration client ID. Omit to use interactive authentication.

### ClientSecret
**Type:** String  
**Required:** No  
**Description:** Client secret for app-only authentication. Omit for interactive flow.

### TimeFrame
**Type:** Integer  
**Required:** No  
**Default:** 30  
**Description:** Number of days to look back for sign-in activity. Larger values increase execution time.

### export
**Type:** Switch  
**Required:** No  
**Description:** If specified, exports all app data to `EnterpriseAppUsage.json` in the current directory.

## Usage Examples

### Example 1: Basic App Usage Report
```powershell
Get-EnterpriseAppUsage `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "abcdefab-1234-1234-1234-abcdefabcdef" `
    -ClientSecret "your-secret"
```

### Example 2: 60-Day Lookback with Export
```powershell
Get-EnterpriseAppUsage `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "abcdefab-1234-1234-1234-abcdefabcdef" `
    -ClientSecret "your-secret" `
    -TimeFrame 60 `
    -export
```

### Example 3: Interactive Authentication
```powershell
Get-EnterpriseAppUsage `
    -TenantId "12345678-1234-1234-1234-123456789012"
```

### Example 4: Find Stale or Unowned Apps
```powershell
# Get results and filter locally
Get-EnterpriseAppUsage `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "<client-id>" `
    -ClientSecret "<secret>" `
    -TimeFrame 90 `
    -export

# After export, analyze the JSON to identify stale apps
$data = Get-Content "EnterpriseAppUsage.json" | ConvertFrom-Json
$staleApps = $data | Where-Object { $_."Usage Count" -eq 0 -and $_."Owner UPN" -eq "NONE" }
$staleApps | Select-Object "App Name", "App AppID" | Format-Table
```

## Output

### Console Output
Displays a sorted table of apps by usage count:

```
App Name              Owner UPN                    Usage Count
--------              ---------                    -----------
Contoso-Sales-App     john.smith@contoso.com       247
Power BI Service      admin@contoso.com            198
Legacy-HR-System      NONE                         0
```

### JSON Export (`EnterpriseAppUsage.json`)
Full data including App ID, App AppID, Owner details, and usage counts:

```json
[
  {
    "App ID": "...",
    "App AppID": "...",
    "App Name": "Contoso-Sales-App",
    "Owner UPN": "john.smith@contoso.com",
    "Owner Name": "John Smith",
    "Owner ID": "...",
    "Usage Count": 247
  }
]
```

## Common Issues & Troubleshooting

### Issue: "Permission error getting sign-ins"
**Message:** `Required permissions: AuditLog.Read.All and Directory.Read.All`

**Solution:** Ensure the app registration has both `AuditLog.Read.All` and `Directory.Read.All` with admin consent granted.

### Issue: Script runs slowly on large tenants
**Cause:** Rate throttling on the sign-in audit API. The script automatically handles 429 retry with back-off (up to 5 retries).

**Solution:**
- Reduce `TimeFrame` to minimize API calls
- Run during off-peak hours
- `Start-Sleep -Seconds 1` is built in between each app to reduce throttling

### Issue: "Maximum retry attempts reached"
**Cause:** Persistent throttling from the audit log API.

**Solution:** Reduce `TimeFrame` or split the operation across multiple runs filtering by app ID range.

### Issue: No application data returned
**Cause:** Missing `Directory.Read.All` permission prevents reading app registrations.

**Solution:** Grant `Directory.Read.All` application permission with admin consent in Azure Portal.

## Related Scripts

- [[Get-GraphToken]] - Token acquisition
- [[Get-GraphHeaders]] - Authorization headers
- [[Get-AzureResourcePaging]] - Used internally for app paging

## Version History

- **v1.0** (2025-06-25) - Initial public release

## See Also

- [Microsoft Graph Applications API](https://docs.microsoft.com/graph/api/resources/application)
- [Microsoft Graph Sign-In Audit Logs](https://docs.microsoft.com/graph/api/resources/signinactivity)
- [Get-EnterpriseAppUsage.ps1 Source](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Graph%20Commands/Get-EnterpriseAppUsage.ps1)
