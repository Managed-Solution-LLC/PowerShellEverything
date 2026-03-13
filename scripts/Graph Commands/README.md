# Graph Commands

Reusable Microsoft Graph API helper functions for authentication, pagination, and reporting across all PowerShell scripts in this repository.

## 📁 Scripts in this Directory

### Get-GraphToken.ps1
Acquires an OAuth2 access token for Microsoft Graph using MSAL.PS. Supports both client secret (app-only) and interactive authentication flows.

**Quick Start:**
```powershell
# Client credentials (app-only)
$token = Get-GraphToken -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>"

# Interactive (delegated)
$token = Get-GraphToken -TenantId "<tenant-id>" -Scope @("User.Read.All", "Directory.Read.All")
```

---

### Get-GraphHeaders.ps1
Builds the authorization header hashtable required for Microsoft Graph REST API calls.

**Quick Start:**
```powershell
$headers = Get-GraphHeaders -accessToken $token
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users" -Headers $headers -Method Get
```

---

### Get-AzureResourcePaging.ps1
Handles OData pagination automatically for Microsoft Graph and Azure REST API endpoints, collecting all pages into a single result array.

**Quick Start:**
```powershell
$allUsers = Get-AzureResourcePaging -URL "https://graph.microsoft.com/v1.0/users" -AuthHeader $headers
```

---

### Get-EnterpriseAppUsage.ps1
Reports usage and ownership of all Azure AD Enterprise Applications (App Registrations) including sign-in counts for a configurable timeframe.

**Quick Start:**
```powershell
Get-EnterpriseAppUsage -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>" -TimeFrame 30
```

---

### Get-ExchangeErrorsGraph.ps1
Retrieves users with Exchange Online provisioning errors from Microsoft Graph beta endpoint, with optional JSON export.

**Quick Start:**
```powershell
Get-ExchangeErrorsGraph -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>" -export
```

---

### Get-PBIWorkspaceUsageReport.ps1
Generates a comprehensive Power BI workspace and report usage report across all workspaces (including personal), correlating report inventory with activity log data for up to 90 days.

**Quick Start:**
```powershell
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "<tenant-id>" `
    -ClientId "<client-id>" `
    -ClientSecret "<secret>" `
    -OutputPath "C:\Reports\PBI"
```

---

## 🚀 Prerequisites

### Required Modules
- **MSAL.PS** - OAuth2 authentication (auto-installed by Get-GraphToken)
- **Microsoft.Graph** - Used by EnterpriseAppUsage and ExchangeErrors scripts

```powershell
Install-Module MSAL.PS -Scope CurrentUser
Install-Module Microsoft.Graph -Scope CurrentUser
```

### Common Permissions

| Script | Permission |
|--------|-----------|
| Get-GraphToken | None (auth only) |
| Get-GraphHeaders | None (formatting only) |
| Get-AzureResourcePaging | Depends on URL called |
| Get-EnterpriseAppUsage | `AuditLog.Read.All`, `Directory.Read.All` |
| Get-ExchangeErrorsGraph | `Directory.Read.All` |
| Get-PBIWorkspaceUsageReport | Power BI `Tenant.Read.All`, `Tenant.ReadWrite.All` |

---

## 🔧 Common Workflow

These helper functions are designed to be used together:

```powershell
# 1. Get token
$token = Get-GraphToken -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret "<secret>"

# 2. Build headers
$headers = Get-GraphHeaders -accessToken $token

# 3. Call API with automatic pagination
$allUsers = Get-AzureResourcePaging -URL "https://graph.microsoft.com/v1.0/users" -AuthHeader $headers
```

---

## 📝 Wiki Documentation

| Script | Wiki Page |
|--------|-----------|
| Get-GraphToken.ps1 | [[Get-GraphToken]] |
| Get-GraphHeaders.ps1 | [[Get-GraphHeaders]] |
| Get-AzureResourcePaging.ps1 | [[Get-AzureResourcePaging]] |
| Get-EnterpriseAppUsage.ps1 | [[Get-EnterpriseAppUsage]] |
| Get-ExchangeErrorsGraph.ps1 | [[Get-ExchangeErrorsGraph]] |
| Get-PBIWorkspaceUsageReport.ps1 | [[Get-PBIWorkspaceUsageReport]] |
