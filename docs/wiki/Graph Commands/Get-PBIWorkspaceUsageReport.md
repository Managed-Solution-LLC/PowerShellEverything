# Get-PBIWorkspaceUsageReport

## Overview

`Get-PBIWorkspaceUsageReport.ps1` generates a comprehensive Power BI workspace and report usage report. It inventories all reports across all workspaces (including personal workspaces), correlates them with Power BI Activity Log data for up to 90 days, and produces a detailed usage analysis showing view counts and unique users per report. Outputs in CSV or JSON format.

## Features

- **Full Workspace Inventory** - Enumerates all shared and personal workspaces using Power BI Admin APIs
- **Activity Log Correlation** - Matches reports with `ViewReport` events from the Power BI Activity Log
- **Usage Metrics** - View counts and unique user lists per report for configurable time periods
- **User Detail Report** - Per-user view counts per report for granular access analysis
- **Stale Report Identification** - Reports with zero views are surfaced for potential cleanup
- **CSV and JSON Export** - Choose output format; JSON uses proper arrays for user lists
- **Pre-Flight Validation** - Validates PowerShell version, output directory, and write permissions before starting
- **Service Principal Auth** - Uses app registration with Power BI Admin APIs

## Prerequisites

### PowerShell Version
- **PowerShell 5.1 or later** (validated at runtime)

### Required Permissions
The service principal must be authorized for Power BI Admin APIs. One of:
- `Tenant.Read.All` permission in Power BI Service  
- `Tenant.ReadWrite.All` permission in Power BI Service

**AND** one of the following tenant-level configurations:
- Service principal added to the **Power BI Service Admins** security group
- Tenant setting **"Allow service principals to use Power BI admin APIs"** enabled in Power BI Admin Portal

### Azure App Registration Setup
1. Register an App in Azure AD / Entra ID
2. Create a client secret
3. Add the service principal to the Power BI Service Admin group OR enable the tenant setting
4. No Graph API permissions needed — only Power BI REST API access

### Output Directory
- Write permissions to the `OutputPath` directory (validated at runtime)

## Parameters

### TenantId
**Type:** String  
**Required:** Yes  
**Description:** Azure AD / Entra ID Tenant ID.

### ClientId
**Type:** String  
**Required:** Yes  
**Description:** App Registration (Service Principal) Client ID.

### ClientSecret
**Type:** String  
**Required:** Yes  
**Description:** App Registration Client Secret. For production use, retrieve from Azure Key Vault rather than hardcoding.

### OutputPath
**Type:** String  
**Required:** No  
**Default:** `.` (current directory)  
**Description:** Directory where all output files will be written. The directory will be created if it doesn't exist. Write permissions are validated before execution begins.

### OutputFormat
**Type:** String  
**Required:** No  
**Default:** `csv`  
**Valid Values:** `csv`, `json`  
**Description:** Output file format. JSON includes proper arrays for user lists and pretty-printed formatting.

### ActivityDays
**Type:** Integer  
**Required:** No  
**Default:** `90`  
**Valid Range:** 1–90  
**Description:** Number of days of Power BI activity history to retrieve. Maximum is 90 (Power BI API limitation).

## Usage Examples

### Example 1: Basic Report (CSV, Current Directory)
```powershell
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "abcdefab-1234-1234-1234-abcdefabcdef" `
    -ClientSecret "your-client-secret"
```

### Example 2: Custom Output Path and Format
```powershell
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "abcdefab-1234-1234-1234-abcdefabcdef" `
    -ClientSecret "your-client-secret" `
    -OutputPath "C:\Reports\PowerBI" `
    -OutputFormat "json"
```

### Example 3: 60-Day Lookback with CSV Export
```powershell
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "abcdefab-1234-1234-1234-abcdefabcdef" `
    -ClientSecret "your-client-secret" `
    -OutputPath "C:\Reports\PowerBI" `
    -ActivityDays 60
```

### Example 4: Identify Stale Reports
```powershell
# Run report
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "<client-id>" `
    -ClientSecret "<secret>" `
    -OutputPath "C:\Reports\PowerBI"

# Filter stale reports from the usage CSV
$usage = Import-Csv "C:\Reports\PowerBI\PBI_Report_Usage_*.csv" | Select-Object -First 1
$stale = $usage | Where-Object { [int]$_.TotalViews_90d -eq 0 }
Write-Host "Stale reports (0 views): $($stale.Count)"
$stale | Select-Object ReportName, WorkspaceName, WorkspaceType | Format-Table
```

## Output Files

All output files include a timestamp suffix (`YYYYMMDD_HHmmss`) to prevent overwrites.

### Report Inventory (`PBI_Report_Inventory_<timestamp>.<ext>`)
Full inventory of all reports across all workspaces.

| Column | Description |
|--------|-------------|
| ReportId | Power BI Report GUID |
| ReportName | Display name of the report |
| WorkspaceId | Power BI Workspace GUID |
| WorkspaceName | Display name of the workspace |
| WorkspaceType | `Shared` or `Personal` |

### Usage Summary (`PBI_Report_Usage_<timestamp>.<ext>`)
Per-report usage aggregation sorted by most-viewed.

| Column | Description |
|--------|-------------|
| ReportId | Power BI Report GUID |
| ReportName | Display name of the report |
| WorkspaceName | Workspace containing the report |
| WorkspaceType | `Shared` or `Personal` |
| TotalViews_90d | Total view events in the period |
| UniqueUsers_90d | Count of distinct users who viewed |

### User Details (`PBI_Report_UserDetails_<timestamp>.<ext>`)
Per-user, per-report view counts.

| Column | Description |
|--------|-------------|
| ReportId | Power BI Report GUID |
| ReportName | Display name of the report |
| UserId | Azure AD User Object ID or UPN |
| ViewCount_90d | Number of times this user viewed the report |

### Summary Text (`PBI_Usage_Summary_<timestamp>.txt`)
Human-readable summary including:
- Total reports, shared vs. personal breakdown
- Reports with and without usage
- Total view events and unique users
- Top 10 most-viewed reports

### Console Output
```
═══════════════════════════════════════════════════════════════
  Power BI Workspace Usage Report - Phase 1
  Managed Solution
  Output Format: CSV
═══════════════════════════════════════════════════════════════

[INVENTORY] Report Inventory Summary:
  Total Reports       : 412
  Shared Workspace    : 387
  Personal Workspace  : 25

✅ [EXPORT] Report inventory  -> C:\Reports\PowerBI\PBI_Report_Inventory_20260313_143052.csv
...
✅ [DONE] All reports generated successfully.
```

## Common Issues & Troubleshooting

### Issue: "Unauthorized" / 401 on Power BI API
**Causes:**
- Service principal not added to Power BI Service Admin group
- Tenant setting "Allow service principals to use Power BI admin APIs" not enabled

**Solutions:**
1. Add the service principal to the **Power BI Administrator** role in Azure AD
2. Or, in Power BI Admin Portal → Tenant settings → Enable "Allow service principals to use Power BI admin APIs" and add the security group containing your SP

### Issue: No workspaces returned
**Cause:** Insufficient Power BI admin permissions.

**Solution:** Verify the service principal has `Tenant.Read.All` in Power BI and admin API access is enabled.

### Issue: Activity log returns empty results
**Cause:**
- Activity logs only retain 90 days of data
- Tenant may have activity logging disabled

**Solution:** Verify Power BI activity logging is enabled in the Power BI Admin Portal.

### Issue: Pre-flight validation fails (PowerShell version)
**Cause:** Running on PowerShell 5.0 or earlier.

**Solution:**
```powershell
# Check your version
$PSVersionTable.PSVersion

# Upgrade to PowerShell 5.1 or install PowerShell 7
```

### Issue: Write permission denied for OutputPath
**Cause:** Account doesn't have write access to the output directory.

**Solution:** Specify a writable directory:
```powershell
-OutputPath "$env:USERPROFILE\Documents\PBI_Reports"
```

## Performance Considerations

- **ActivityDays:** Shorter periods reduce API calls significantly. Start with 30 days to validate.
- **Large Tenants:** Tenants with 1000+ reports and many users may take 20–30 minutes to complete.
- **Rate Limiting:** Built-in `$ProgressPreference = "SilentlyContinue"` speeds up API calls. The Power BI Activity API is paginated hourly and may take time on large tenants.

## Related Scripts

- [[Get-EnterpriseAppUsage]] - Similar usage pattern for Azure AD app registrations

## Version History

- **v1.0** - Initial release - Core inventory and usage correlation
- **v1.1** (2026-03-12) - Added pre-flight validation, improved error handling and authentication, Export-Data with verbose logging, and wrapped main auth in try/catch

## See Also

- [Power BI Admin REST API](https://docs.microsoft.com/rest/api/power-bi/admin)
- [Power BI Activity Log](https://docs.microsoft.com/power-bi/admin/service-admin-auditing)
- [Allow Service Principals to Use Power BI APIs](https://docs.microsoft.com/power-bi/admin/enable-service-principal-access-api)
- [Get-PBIWorkspaceUsageReport.ps1 Source](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Graph%20Commands/Get-PBIWorkspaceUsageReport.ps1)
