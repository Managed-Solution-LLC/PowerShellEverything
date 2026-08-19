# Get-AzureResourcePaging

## Overview

`Get-AzureResourcePaging.ps1` handles OData pagination automatically for Microsoft Graph and Azure REST API endpoints. When Graph API responses span multiple pages (via `@odata.nextLink`), this function follows each link and aggregates all results into a single array, eliminating the need to write pagination loops in every script.

## Features

- **Automatic Page Following** - Iterates `@odata.nextLink` until all pages are collected
- **Single Result Array** - Returns all resources combined, regardless of page count
- **Universal Compatibility** - Works with any Microsoft Graph or Azure REST API endpoint that uses OData paging
- **Minimal Dependencies** - Requires only an authenticated headers hashtable

## Prerequisites

### PowerShell Version
- PowerShell 5.1 or later

### Dependencies
- An authenticated headers hashtable from [Get-GraphHeaders](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-GraphHeaders)
- Network access to the Microsoft Graph or Azure REST API endpoint

## Parameters

### URL
**Type:** String  
**Required:** Yes  
**Description:** The initial Microsoft Graph or Azure REST API endpoint URL to query. All subsequent `@odata.nextLink` pages are followed automatically.

### AuthHeader
**Type:** Hashtable  
**Required:** Yes  
**Description:** The authorization header hashtable returned by `Get-GraphHeaders`. Must contain a valid Bearer token.

## Usage Examples

### Example 1: Get All Users
```powershell
$token   = Get-GraphToken -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>"
$headers = Get-GraphHeaders -accessToken $token

$allUsers = Get-AzureResourcePaging `
    -URL "https://graph.microsoft.com/v1.0/users" `
    -AuthHeader $headers

Write-Host "Total users: $($allUsers.Count)"
```

### Example 2: Get All App Registrations
```powershell
$token   = Get-GraphToken -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>"
$headers = Get-GraphHeaders -accessToken $token

$allApps = Get-AzureResourcePaging `
    -URL "https://graph.microsoft.com/v1.0/applications" `
    -AuthHeader $headers

$allApps | Select-Object displayName, appId | Format-Table
```

### Example 3: Filtered Query with Paging
```powershell
$token   = Get-GraphToken -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>"
$headers = Get-GraphHeaders -accessToken $token

# Use OData filter with paging
$url = "https://graph.microsoft.com/v1.0/users?`$filter=accountEnabled eq true&`$select=id,displayName,userPrincipalName"
$activeUsers = Get-AzureResourcePaging -URL $url -AuthHeader $headers

Write-Host "Active users: $($activeUsers.Count)"
```

### Example 4: Azure Resource Manager API
```powershell
$token   = Get-GraphToken -TenantId "<tenant-id>" -Scope @("https://management.azure.com/.default")
$headers = Get-GraphHeaders -accessToken $token

$subscriptionId = "<subscription-id>"
$url = "https://management.azure.com/subscriptions/$subscriptionId/resources?api-version=2021-04-01"
$allResources = Get-AzureResourcePaging -URL $url -AuthHeader $headers
```

## Output

Returns an array (`[array]`) of all resource objects collected across all pages. The structure matches the individual items in the `value` property of each API response page.

**Example output structure for `/users` endpoint:**
```powershell
@(
    @{ id = "..."; displayName = "John Smith"; userPrincipalName = "john.smith@contoso.com" }
    @{ id = "..."; displayName = "Jane Doe";   userPrincipalName = "jane.doe@contoso.com"   }
    # ... all remaining users from all pages
)
```

## How It Works

1. Makes initial GET request to the provided URL
2. Extracts the `value` array from the response
3. Checks for `@odata.nextLink` in the response
4. If present, repeats the GET request with the next link URL
5. Continues until `@odata.nextLink` is null (no more pages)
6. Returns the aggregated array of all collected resources

## Common Issues & Troubleshooting

### Issue: "401 Unauthorized" on subsequent pages
**Cause:** Token expired mid-pagination on large datasets.

**Solution:** For very large tenants, re-acquire the token before calling this function. Tokens are valid for 1 hour.

### Issue: Empty result set
**Causes:**
- The API endpoint returned no results
- Filter conditions excluded all items
- App lacks permissions to read the resource

**Solution:**
1. Test the URL directly in Graph Explorer to confirm results
2. Check permissions on the app registration
3. Verify the filter syntax is correct

### Issue: "Request throttled" / 429 errors
**Cause:** Too many API requests in a short time period.

**Solution:** Add retry logic around the call:
```powershell
$maxRetries = 3
for ($i = 0; $i -lt $maxRetries; $i++) {
    try {
        $results = Get-AzureResourcePaging -URL $url -AuthHeader $headers
        break
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 429) {
            Start-Sleep -Seconds 60
        } else { throw }
    }
}
```

## Related Scripts

- [Get-GraphToken](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-GraphToken) - Acquire the access token needed for headers
- [Get-GraphHeaders](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-GraphHeaders) - Build the AuthHeader parameter
- [Get-EnterpriseAppUsage](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-EnterpriseAppUsage) - Uses this function for app enumeration

## Version History

- **v1.0** (2025-06-25) - Initial public release

## See Also

- [Microsoft Graph Paging](https://docs.microsoft.com/graph/paging)
- [OData Query Parameters](https://docs.microsoft.com/graph/query-parameters)
- [Get-AzureResourcePaging.ps1 Source](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Graph%20Commands/Get-AzureResourcePaging.ps1)
