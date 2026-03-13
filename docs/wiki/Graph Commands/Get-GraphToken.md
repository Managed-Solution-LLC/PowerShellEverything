# Get-GraphToken

## Overview

`Get-GraphToken.ps1` acquires an OAuth2 access token for Microsoft Graph using the MSAL.PS module. It serves as the authentication foundation for all Graph API scripts in this repository, supporting both unattended (client secret) and interactive authentication flows.

## Features

- **Client Credentials Flow** - App-only auth using client ID and secret (for automation/pipelines)
- **Interactive Flow** - Delegated auth with browser prompt (for user-context scripts)
- **Auto-Install MSAL.PS** - Detects and installs MSAL.PS module if not present
- **Custom Scope Support** - Request specific Graph permission scopes
- **Default Client ID** - Falls back to Microsoft Graph PowerShell client if no client ID provided

## Prerequisites

### PowerShell Version
- PowerShell 5.1 or later

### Required Modules
- `MSAL.PS` (auto-installed if missing)

### Required Permissions
Permissions depend on the scopes requested. Common examples:
- `User.Read.All` - Read all users
- `Directory.Read.All` - Read directory data
- `AuditLog.Read.All` - Read audit logs
- `https://graph.microsoft.com/.default` - All permissions granted to the app registration

### Azure App Registration (for client credentials)
1. Register an App in Azure AD
2. Create a client secret
3. Grant the app the required API permissions
4. Grant admin consent

## Parameters

### TenantId
**Type:** String  
**Required:** Yes  
**Description:** The Azure AD / Entra ID tenant ID to authenticate against.

### ClientId
**Type:** String  
**Required:** No  
**Default:** `14d82eec-204b-4c2f-b7e8-296a70dab67e` (Microsoft Graph PowerShell)  
**Description:** The application (client) ID of the app registration.

### ClientSecret
**Type:** String  
**Required:** No  
**Description:** The client secret for app-only authentication. If omitted, interactive browser authentication is used.

### Scope
**Type:** Array  
**Required:** No  
**Default:** `@("https://graph.microsoft.com/.default")`  
**Description:** OAuth2 scopes to request. Use `.default` for app-only flows; specify explicit scopes for delegated flows.

## Usage Examples

### Example 1: App-Only Authentication
```powershell
$token = Get-GraphToken `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "abcdefab-1234-1234-1234-abcdefabcdef" `
    -ClientSecret "your-client-secret-here"
```

### Example 2: Interactive (Delegated) Authentication
```powershell
$token = Get-GraphToken `
    -TenantId "12345678-1234-1234-1234-123456789012"
```

### Example 3: Custom Scopes
```powershell
$token = Get-GraphToken `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -Scope @("User.Read.All", "Directory.Read.All", "AuditLog.Read.All")
```

### Example 4: Full Workflow with Headers
```powershell
# 1. Get token
$token = Get-GraphToken -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>"

# 2. Build headers
$headers = Get-GraphHeaders -accessToken $token

# 3. Call Graph API
$users = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users" -Headers $headers -Method Get
```

## Output

Returns an access token string (`$accessToken`) ready for use in Authorization headers.

```
Access token retrieved successfully.
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIm...
```

## Common Issues & Troubleshooting

### Issue: "MSAL.PS module not found"
**Solution:** The script will auto-install. If it fails, install manually:
```powershell
Install-Module MSAL.PS -Scope CurrentUser -Force
```

### Issue: "Failed to retrieve access token"
**Causes:**
- Incorrect TenantId, ClientId, or ClientSecret
- Client secret expired
- App registration doesn't have required permissions

**Solutions:**
1. Verify app registration details in Azure Portal
2. Check that client secret hasn't expired
3. Confirm admin consent has been granted for required permissions

### Issue: Interactive prompt doesn't appear
**Solution:** Ensure PowerShell window is interactive (not a background job/service). Use `-ClientSecret` for non-interactive scenarios.

### Issue: Token expires mid-script
**Solution:** Tokens are typically valid for 1 hour. For long-running scripts, re-acquire the token periodically.

## Related Scripts

- [[Get-GraphHeaders]] - Build authorization headers using this token
- [[Get-AzureResourcePaging]] - Use with headers for paginated API calls

## Version History

- **v1.0** (2025-06-25) - Initial public release

## See Also

- [Microsoft Graph Authentication](https://docs.microsoft.com/graph/auth/)
- [MSAL.PS Module](https://github.com/AzureAD/MSAL.PS)
- [App Registration in Azure AD](https://docs.microsoft.com/azure/active-directory/develop/quickstart-register-app)
- [Get-GraphHeaders](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Graph%20Commands/Get-GraphHeaders.ps1)
- [Get-GraphToken.ps1 Source](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Graph%20Commands/Get-GraphToken.ps1)
