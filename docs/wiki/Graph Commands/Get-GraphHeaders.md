# Get-GraphHeaders

## Overview

`Get-GraphHeaders.ps1` is a lightweight helper function that constructs the authorization header hashtable required for all Microsoft Graph REST API calls. It wraps a Bearer token into the standard `Authorization` and `Content-Type` headers expected by the Graph API.

## Features

- **Simple One-Call Setup** - Converts a raw access token into a ready-to-use headers hashtable
- **Standard Format** - Outputs headers compatible with `Invoke-RestMethod` and `Invoke-WebRequest`
- **JSON Content-Type** - Pre-sets `Content-Type: application/json` for all requests

## Prerequisites

### PowerShell Version
- PowerShell 5.1 or later

### Dependencies
- An access token from [Get-GraphToken](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-GraphToken) or any other OAuth2 token source

## Parameters

### accessToken
**Type:** String  
**Required:** Yes  
**Description:** The OAuth2 Bearer access token to embed in the Authorization header. Obtain this from `Get-GraphToken` or another token acquisition method.

## Usage Examples

### Example 1: Standard Workflow
```powershell
# Get token first
$token = Get-GraphToken -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>"

# Build headers
$headers = Get-GraphHeaders -accessToken $token

# Use with any Graph API call
$response = Invoke-RestMethod `
    -Uri "https://graph.microsoft.com/v1.0/users" `
    -Headers $headers `
    -Method Get
```

### Example 2: With Pagination Helper
```powershell
$token   = Get-GraphToken -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>"
$headers = Get-GraphHeaders -accessToken $token

# Pass headers directly to pagination helper
$allApps = Get-AzureResourcePaging `
    -URL "https://graph.microsoft.com/v1.0/applications" `
    -AuthHeader $headers
```

### Example 3: PATCH/POST Request
```powershell
$headers = Get-GraphHeaders -accessToken $token

$body = @{ displayName = "Updated Name" } | ConvertTo-Json

Invoke-RestMethod `
    -Uri "https://graph.microsoft.com/v1.0/users/<user-id>" `
    -Headers $headers `
    -Method Patch `
    -Body $body
```

## Output

Returns a hashtable with the following structure:

```powershell
@{
    "Authorization" = "Bearer eyJ0eXAiOiJKV1Qi..."
    "Content-Type"  = "application/json"
}
```

## Common Issues & Troubleshooting

### Issue: "401 Unauthorized"
**Cause:** Access token is expired or invalid.

**Solution:** Re-acquire a fresh token:
```powershell
$token   = Get-GraphToken -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>"
$headers = Get-GraphHeaders -accessToken $token
```

### Issue: "403 Forbidden"
**Cause:** Token is valid but the app lacks the required permissions for the endpoint.

**Solution:** Ensure the app registration has the required API permissions with admin consent granted.

## Related Scripts

- [Get-GraphToken](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-GraphToken) - Acquire the access token passed to this function
- [Get-AzureResourcePaging](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-AzureResourcePaging) - Uses these headers for paginated Graph calls

## Version History

- **v1.0** (2025-06-25) - Initial public release

## See Also

- [Microsoft Graph Authentication Headers](https://docs.microsoft.com/graph/auth/auth-concepts)
- [Get-GraphHeaders.ps1 Source](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Graph%20Commands/Get-GraphHeaders.ps1)
- [Get-GraphToken.ps1 Source](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Graph%20Commands/Get-GraphToken.ps1)
