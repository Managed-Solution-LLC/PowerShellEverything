# Get-PBIWorkspaceUsageReport

## Overview

`Get-PBIWorkspaceUsageReport.ps1` generates a comprehensive Power BI workspace and report usage report. It inventories all reports across all workspaces (including personal workspaces), correlates them with Power BI Activity Log data for the last 30 days by default (up to 90 days for Fabric/Premium capacities), and produces a detailed usage analysis showing view counts and unique users per report. Supports both Service Principal and interactive user authentication. Outputs in CSV or JSON format.

## Features

- **Full Workspace Inventory** - Enumerates all shared and personal workspaces using Power BI Admin APIs
- **Activity Log Correlation** - Matches reports with `ViewReport` events from the Power BI Activity Log
- **Usage Metrics** - View counts and unique user lists per report for configurable time periods
- **User Detail Report** - Per-user view counts per report for granular access analysis
- **Stale Report Identification** - Reports with zero views are surfaced for potential cleanup
- **CSV and JSON Export** - Choose output format; JSON uses proper arrays for user lists
- **Pre-Flight Validation** - Validates PowerShell version, output directory, and write permissions before starting
- **Dual Authentication Modes** - Service Principal (client credentials) for automated/pipeline use, or interactive browser login via `-UseInteractiveAuth` for ad-hoc runs

## Prerequisites

### PowerShell Version
- **PowerShell 5.1 or later** (validated at runtime)

### Required Permissions

The script calls Power BI `/admin/` endpoints. Three things must all be in place:

#### 1. Entra App Registration Permissions
Add the following API permissions to the app registration in [Entra ID](https://entra.microsoft.com) and grant admin consent:

| API | Permission | Type |
|-----|-----------|------|
| Power BI Service | `Tenant.Read.All` | Application |

#### 2. Fabric Admin RBAC Role (required to access Admin Portal settings)
The person configuring the Fabric tenant settings must hold the **Fabric Administrator** (or Global Administrator) role in Entra ID.

> Without this role, the [Fabric Admin Portal](https://app.powerbi.com/admin-portal/tenantSettings) tenant settings will not be accessible or editable.

To assign the role:  
**Entra ID → Roles and administrators → Fabric Administrator → Add assignment**

#### 3. Fabric Admin Portal — Admin API Settings
Once you have the Fabric Administrator role, navigate to:

**[https://app.powerbi.com/admin-portal/tenantSettings](https://app.powerbi.com/admin-portal/tenantSettings)**

Scroll to the **Admin API settings** section and configure:

- **Setting:** "Service principals can access read-only admin APIs"
- **Toggle:** Enabled
- **Apply to:** Specific security groups
- **Action:** Add the security group that contains your app registration's service principal

> ⚠️ **Common confusion:** "Service principals can call Fabric public APIs" (under Developer settings) is a **different setting** that covers regular endpoints only. The `/admin/` endpoints used by this script require the **Admin API settings** toggle above.

### Azure App Registration Setup (Service Principal auth)
1. Register an App in Entra ID
2. Create a client secret
3. Grant `Tenant.Read.All` (Power BI Service) with admin consent
4. Add the service principal to the security group allowed in the Admin API settings above
5. No Microsoft Graph API permissions are needed — only Power BI REST API access

### Interactive Authentication (`-UseInteractiveAuth`)
Use this for ad-hoc runs or while Service Principal permissions are still propagating.

**Requirements:**
- The `MicrosoftPowerBIMgmt` PowerShell module: `Install-Module MicrosoftPowerBIMgmt -Scope CurrentUser`
- Sign in with a **Power BI Administrator** or **Fabric Administrator** account
- `TenantId` is still required; `ClientId` and `ClientSecret` are not used

> ℹ️ The same Admin API settings (above) apply — the signed-in user account must have Power BI Admin access to the tenant.

### Output Directory
- Write permissions to the `OutputPath` directory (validated at runtime)

## Parameters

### TenantId
**Type:** String  
**Required:** Yes  
**Description:** Azure AD / Entra ID Tenant ID.

### ClientId
**Type:** String  
**Required:** Yes *(Service Principal auth only)*  
**Description:** App Registration (Service Principal) Client ID. Not used when `-UseInteractiveAuth` is specified.

### ClientSecret
**Type:** String  
**Required:** Yes *(Service Principal auth only)*  
**Description:** App Registration Client Secret. For production use, retrieve from Azure Key Vault rather than hardcoding. Not used when `-UseInteractiveAuth` is specified.

### UseInteractiveAuth
**Type:** Switch  
**Required:** No  
**Description:** Use interactive browser login instead of a service principal client secret. Requires the `MicrosoftPowerBIMgmt` module. When specified, `ClientId` and `ClientSecret` are not needed. `TenantId` is still required.

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
**Default:** `30`  
**Valid Range:** 1–90  
**Description:** Number of days of Power BI activity history to retrieve. Standard Power BI audit log retains **30 days**; tenants with Fabric or Premium capacity may retain up to 90 days. Requesting dates outside the tenant's retention window returns a 400 error (skipped automatically per day).

## Usage Examples

### Example 1: Interactive Auth (Recommended for Ad-Hoc Use)
```powershell
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -UseInteractiveAuth `
    -OutputPath "C:\Reports\PBI" `
    -OutputFormat "json"
```
Opens a browser login prompt. Use a Power BI Administrator account. No app registration needed.

### Example 2: Service Principal (Automated / Pipeline Use)
```powershell
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -ClientId "abcdefab-1234-1234-1234-abcdefabcdef" `
    -ClientSecret "your-client-secret"
```

### Example 3: Extended Window (Fabric/Premium Tenants)
```powershell
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -UseInteractiveAuth `
    -OutputPath "C:\Reports\PowerBI" `
    -ActivityDays 90
```
> ⚠️ Only use `-ActivityDays` values above 30 if the tenant has Fabric or Premium capacity with extended audit retention. Standard tenants will see per-day failures for dates beyond 30 days (skipped automatically).

### Example 4: Identify Stale Reports
```powershell
# Run report
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "12345678-1234-1234-1234-123456789012" `
    -UseInteractiveAuth `
    -OutputPath "C:\Reports\PowerBI"

# Filter stale reports from the usage CSV
$usage = Import-Csv "C:\Reports\PowerBI\PBI_Report_Usage_*.csv"
$stale = $usage | Where-Object { [int]$_.TotalViews_90d -eq 0 }
Write-Host "Stale reports (0 views in last 30 days): $($stale.Count)"
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
| TotalViews_90d | Total ViewReport events in the activity window |
| UniqueUsers_90d | Count of distinct users who viewed |
| UserList_90d | Semicolon-delimited list of user IDs (CSV) or JSON array (JSON format) |
| DatasetId | Power BI Dataset GUID backing the report |
| ReportWebUrl | Direct URL to open the report in Power BI Service |

### User Details (`PBI_Report_UserDetails_<timestamp>.<ext>`)
Per-user, per-report view counts.

| Column | Description |
|--------|-------------|
| ReportId | Power BI Report GUID |
| ReportName | Display name of the report |
| UserId | Azure AD User UPN or Object ID |
| ViewCount_90d | Number of times this user viewed the report |
| LastViewed | Timestamp of the user's most recent view event |
| WorkspaceName | Workspace containing the report |
| WorkspaceType | `Shared` or `Personal` |

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
**Root Cause:**  
The script calls `/admin/` endpoints. `Tenant.Read.All` being granted and the "Service principals can call Fabric public APIs" setting being enabled is **not sufficient** — the Admin API setting is controlled by a separate toggle.

**Resolution steps:**

**Step 1 — Verify you have Fabric Admin access to configure tenant settings:**  
The person making changes must hold the **Fabric Administrator** (or Global Administrator) role.  
> Entra ID → Roles and administrators → Fabric Administrator → Add assignment

**Step 2 — Enable Admin API access in the Fabric Admin Portal:**  
Navigate to: **[https://app.powerbi.com/admin-portal/tenantSettings](https://app.powerbi.com/admin-portal/tenantSettings)**  

Scroll to **Admin API settings** and configure:
- Enable: **"Service principals can access read-only admin APIs"**
- Set **Apply to:** Specific security groups
- Add the security group containing your app registration's service principal

> ⚠️ **Common confusion:** "Service principals can call Fabric public APIs" (Developer settings) covers regular/public endpoints only — it does **not** grant access to `/admin/` endpoints used by this script.

### Issue: No workspaces returned
**Cause:** Insufficient Power BI admin permissions.

**Solution:** Verify the service principal has `Tenant.Read.All` in Power BI and admin API access is enabled.

### Issue: Activity log returns empty results or per-day failures
**Cause:**  
- Standard Power BI audit log retains only **30 days** of data. Requesting dates older than 30 days returns 400 errors (the script skips those days automatically and reports a count at the end)
- Tenant may have activity logging disabled

**Solution:**  
- Use the default `ActivityDays 30` or explicitly pass `-ActivityDays 30` for standard tenants
- Only use higher values (up to 90) if the tenant has **Fabric or Premium capacity** with extended retention
- Verify Power BI activity logging is enabled in the Power BI Admin Portal

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
- **v1.2.0** (2026-03-20) - Added `-UseInteractiveAuth` switch for interactive login via `MicrosoftPowerBIMgmt` module; switched activity event collection to `Get-PowerBIActivityEvent` cmdlet with client-side `ViewReport` filtering; changed default `ActivityDays` from 90 to 30 to match standard Power BI audit retention

## See Also

- [Power BI Admin REST API](https://docs.microsoft.com/rest/api/power-bi/admin)
- [Power BI Activity Log](https://docs.microsoft.com/power-bi/admin/service-admin-auditing)
- [Allow Service Principals to Use Power BI APIs](https://docs.microsoft.com/power-bi/admin/enable-service-principal-access-api)
- [Get-PBIWorkspaceUsageReport.ps1 Source](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Graph%20Commands/Get-PBIWorkspaceUsageReport.ps1)
