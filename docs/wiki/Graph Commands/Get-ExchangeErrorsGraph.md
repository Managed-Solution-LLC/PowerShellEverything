# Get-ExchangeErrorsGraph

## Overview

`Get-ExchangeErrorsGraph.ps1` retrieves users in a tenant that have Exchange Online provisioning errors via the Microsoft Graph beta endpoint. It parses the raw XML error detail stored in the `serviceProvisioningErrors` property, formats it for readability, and optionally exports the results to JSON for remediation tracking.

## Features

- **Provisioning Error Detection** - Queries all users and filters to those with Exchange provisioning errors
- **XML Error Parsing** - Extracts human-readable error descriptions from raw XML error payloads
- **Full Tenant Scan** - Handles OData paging to ensure all users are evaluated
- **Formatted Table Output** - Displays UPN and error details in a readable console table
- **JSON Export** - Exports results to `C:\temp\ExchangeErrors.json` for tracking and remediation
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

### Required Permissions
| Permission | Type | Purpose |
|-----------|------|---------|
| `Directory.Read.All` | Application | Read user provisioning error properties |

> **Note:** Uses the **Microsoft Graph beta endpoint** (`/beta/users`). Properties may change with future API updates.

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

### export
**Type:** Switch  
**Required:** No  
**Description:** If specified, exports results to `C:\temp\ExchangeErrors.json`. Creates `C:\temp` if it doesn't exist.

## Usage Examples

### Example 1: Console Report Only
```powershell
Get-ExchangeErrorsGraph `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "abcdefab-1234-1234-1234-abcdefabcdef" `
    -ClientSecret "your-secret"
```

### Example 2: Report with JSON Export
```powershell
Get-ExchangeErrorsGraph `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "abcdefab-1234-1234-1234-abcdefabcdef" `
    -ClientSecret "your-secret" `
    -export
```

### Example 3: Interactive Authentication
```powershell
Get-ExchangeErrorsGraph `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -export
```

### Example 4: Load and Review Export
```powershell
# Run with export
Get-ExchangeErrorsGraph -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>" -export

# Review the exported JSON
$errors = Get-Content "C:\temp\ExchangeErrors.json" | ConvertFrom-Json
$errors | ForEach-Object {
    Write-Host "User: $($_.userPrincipalName)" -ForegroundColor Cyan
    Write-Host "Error: $($_.Errors)" -ForegroundColor Red
    Write-Host ""
}
```

## Output

### Console Output
```
Found 3 users with provisioning errors.

UserPrincipalName                Errors
-----------------                ------
john.doe@contoso.com             Unable to set this property. The value associated with a linked role...
service.acct@contoso.com         The operation failed. Please refer to the error details for more info...
legacy.user@contoso.com          The email address "alias@domain.com" is already being used by another...
```

### JSON Export (`C:\temp\ExchangeErrors.json`)
```json
[
  {
    "userPrincipalName": "john.doe@contoso.com",
    "Errors": "Unable to set this property. The value associated with a linked role..."
  }
]
```

## Common Issues & Troubleshooting

### Issue: No users returned / "No users found with provisioning errors"
**Cause:**
- Tenant has no Exchange provisioning errors (ideal state!)
- Insufficient permissions to read `serviceProvisioningErrors`

**Solution:** Verify `Directory.Read.All` permission has admin consent granted:
```powershell
# Test read access
Connect-MgGraph -Scopes "Directory.Read.All"
Get-MgUser -Top 1 -Property serviceProvisioningErrors
```

### Issue: API request error / 400 or 404
**Cause:** The beta endpoint URL may change with Microsoft updates.

**Solution:** Verify current beta endpoint and property availability in [Microsoft Graph Explorer](https://developer.microsoft.com/graph/graph-explorer).

### Issue: "Error getting Graph Token"
**Solution:** Verify TenantId, ClientId, and ClientSecret are correct. Ensure the app registration exists and the secret hasn't expired.

### Issue: XML parse errors in error descriptions
**Cause:** Microsoft occasionally changes the XML schema of `serviceProvisioningErrors.errorDetail`.

**Solution:** Inspect the raw property value:
```powershell
$user = Get-MgUser -UserId "user@domain.com" -Property serviceProvisioningErrors
$user.serviceProvisioningErrors | ConvertTo-Json
```

## Related Scripts

- [[Get-GraphToken]] - Token acquisition
- [[Get-GraphHeaders]] - Authorization headers

## Version History

- **v1.0** (2025-06-25) - Initial public release

## See Also

- [Microsoft Graph serviceProvisioningErrors](https://docs.microsoft.com/graph/api/resources/serviceprovisioningerror)
- [Exchange Online Provisioning Errors](https://docs.microsoft.com/exchange/recipients/user-mailboxes/user-mailbox-provisioning)
- [Get-ExchangeErrorsGraph.ps1 Source](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Graph%20Commands/Get-ExchangeErrorsGraph.ps1)
