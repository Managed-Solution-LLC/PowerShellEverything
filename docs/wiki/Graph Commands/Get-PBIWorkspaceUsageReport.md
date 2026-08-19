# Get-PBIWorkspaceUsageReport — Quick Usage Guide

> **v1.6 · PowerShell 5.1+ · Python 3.10+**
> Scripts: `scripts/Graph Commands/Get-PBIWorkspaceUsageReport.ps1` | `.py`

---

## Quick Start

### PowerShell

```powershell
# Interactive login (ad-hoc, no app registration needed)
.\Get-PBIWorkspaceUsageReport.ps1 -TenantId "<tid>" -UseInteractiveAuth

# Service Principal (automated / pipeline)
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "<tid>" -ClientId "<cid>" -ClientSecret "<secret>"

# Service account / ROPC (when SP is blocked at the PBI service layer)
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "<tid>" -ClientId "<cid>" `
    -Username "svc-pbi@domain.com" -Password (ConvertTo-SecureString $env:SVC_PBI_PASSWORD -AsPlainText -Force)

# Custom output path, JSON format, 60-day window, include refresh history
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "<tid>" -ClientId "<cid>" -ClientSecret "<secret>" `
    -OutputPath "C:\Reports\PBI" -OutputFormat json -ActivityDays 60 -IncludeRefreshHistory

# Upload reports to S3 after generation
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "<tid>" -ClientId "<cid>" -ClientSecret "<secret>" `
    -PublishToS3 -S3BucketName "my-pbi-reports" -S3KeyPrefix "powerbi/monthly" -S3Region "us-east-1"
```

### Python

```bash
# Install dependencies once
pip install -r "scripts/Graph Commands/requirements.txt"

# Service Principal
python Get-PBIWorkspaceUsageReport.py \
    --tenant-id <tid> --client-id <cid> --client-secret <secret>

# Interactive device-code flow (browser)
python Get-PBIWorkspaceUsageReport.py \
    --tenant-id <tid> --client-id <cid> --interactive

# ROPC / service account
python Get-PBIWorkspaceUsageReport.py \
    --tenant-id <tid> --client-id <cid> \
    --username svc@domain.com --password <pw>

# With refresh history + upload to S3
python Get-PBIWorkspaceUsageReport.py \
    --tenant-id <tid> --client-id <cid> --client-secret <secret> \
    --include-refresh-history \
    --s3-bucket my-pbi-reports --s3-prefix "powerbi/$(date +%Y-%m)" --s3-region us-east-1
```

---

## Parameters

### PowerShell

| Parameter | Required | Default | Description |
|---|---|---|---|
| `-TenantId` | Yes | — | Entra ID Tenant ID |
| `-ClientId` | SP / ROPC | — | App Registration Client ID |
| `-ClientSecret` | SP only | — | App Registration Client Secret |
| `-UseInteractiveAuth` | Interactive only | — | Browser login via `MicrosoftPowerBIMgmt` module |
| `-Username` | ROPC only | — | Service account UPN |
| `-Password` | ROPC only | — | Service account password (`SecureString`) |
| `-OutputPath` | No | `.` | Output directory (created if missing) |
| `-OutputFormat` | No | `csv` | `csv` or `json` |
| `-ActivityDays` | No | `30` | Days of activity history (max 90, standard retention = 30) |
| `-IncludeRefreshHistory` | No | off | Fetch last refresh per dataset (one extra API call each) |
| `-PublishToS3` | No | off | Upload all generated report files to S3 after local export |
| `-S3BucketName` | When `-PublishToS3` | — | Target S3 bucket name |
| `-S3KeyPrefix` | No | `""` | S3 key prefix (virtual folder path) e.g. `pbi-reports/monthly` |
| `-S3Region` | No | — | AWS region override; uses default AWS config if omitted |
| `-S3ProfileName` | No | — | Named AWS CLI credentials profile |

### Python

| Argument | Required | Default | Description |
|---|---|---|---|
| `--tenant-id` | Yes | — | Entra ID Tenant ID |
| `--client-id` | Yes | — | App Registration Client ID |
| `--client-secret` | SP only | — | Mutually exclusive with `--interactive` / `--password` |
| `--interactive` | — | — | Device-code flow (browser) |
| `--password` | ROPC only | — | Requires `--username` |
| `--username` | ROPC only | — | Service account UPN |
| `--output-path` | No | `.` | Output directory |
| `--output-format` | No | `csv` | `csv` or `json` |
| `--activity-days` | No | `30` | Days of activity (max 30 standard, 90 Fabric/Premium) |
| `--include-refresh-history` | No | off | Fetch last refresh per refreshable dataset |
| `--s3-bucket` | No | — | S3 bucket — triggers upload when set |
| `--s3-prefix` | No | `""` | S3 key prefix e.g. `powerbi/2026-04` |
| `--s3-region` | No | — | AWS region override |
| `--s3-profile` | No | — | Named AWS credentials profile |
| `--s3-kms-key` | No | — | KMS key ID/ARN for SSE-KMS encryption |
| `--s3-storage-class` | No | `STANDARD` | `STANDARD`, `INTELLIGENT_TIERING`, `GLACIER`, etc. |

---

## Output Files

All files are timestamped `YYYYMMDD_HHmmss` to prevent overwrites.

| File | Description |
|---|---|
| `PBI_Report_Inventory_*.csv/json` | Every report in the tenant — workspace, type, state, storage proxy fields |
| `PBI_Workspace_Size_*.csv/json` | One row per workspace — `StorageUsedMB` (Premium/Fabric only), dataset count, report count |
| `PBI_Dataset_Health_*.csv/json` | One row per dataset — `TargetStorageMode`, `StorageCategory`, `IsRefreshable`, gateway flag, configured-by |
| `PBI_Report_Usage_*.csv/json` | Per-report usage — total views, unique users, user list, device type breakdown |
| `PBI_Report_UserDetails_*.csv/json` | Per-user per-report — view count, last viewed timestamp |
| `PBI_DeviceType_Summary_*.csv/json` | Tenant-wide device type counts — Web, Desktop, Mobile, Excel, etc. |
| `PBI_Usage_Summary_*.txt` | Human-readable summary — top workspaces, top reports, device breakdown, storage mode breakdown |

### Key Columns — Dataset Health

| Column | Details |
|---|---|
| `TargetStorageMode` | Raw API value: `Abf`, `DirectQuery`, `PremiumFiles`, `CompositeModel`, `Streaming` |
| `StorageCategory` | Human-readable: `Import (In-Memory)`, `DirectQuery (No Memory)`, `Composite`, etc. |
| `IsRefreshable` | Whether the dataset supports scheduled refresh |
| `IsOnPremGatewayRequired` | Whether an on-prem data gateway is required |
| `LastRefreshStart/End` | Populated only when `-IncludeRefreshHistory` is set |
| `LastRefreshDurationMin` | Calculated refresh duration in minutes (proxy for dataset size/complexity) |
| `LastRefreshStatus` | `Completed`, `Failed`, or `Unknown` |

> **Memory note:** `StorageUsedMB` (workspace-level) and `StorageCategory` (dataset-level) are the closest proxies available via the REST API. Byte-level dataset memory requires XMLA DMV queries on Premium/Fabric (`DISCOVER_OBJECT_MEMORY_USAGE`).

---

## Permissions Setup

Three things must all be in place for the `/admin/` endpoints to work:

### 1. App Registration (Service Principal auth)

| API | Permission | Type |
|---|---|---|
| Power BI Service | `Tenant.Read.All` | Application |

Admin consent required.

### 2. Assign Fabric Administrator Role to the SP *(fastest)*

```
Entra ID → Roles and administrators → Fabric Administrator → Add assignment
```

**OR** use the Fabric Admin Portal setting instead (Option B below).

### 3. Fabric Admin Portal — Admin API Settings *(Option B)*

Navigate to **Fabric Admin Portal → Tenant settings → Admin API settings**

- Enable: **"Service principals can access read-only admin APIs"**
- Scope to the security group containing the SP

> **Common confusion:** "Service principals can call Fabric public APIs" (Developer settings) is a **different toggle** — it covers public endpoints, not `/admin/` endpoints.

### Interactive auth (`-UseInteractiveAuth` / `--interactive`)

```powershell
Install-Module MicrosoftPowerBIMgmt -Scope CurrentUser
```

Sign in with a **Power BI Administrator** or **Fabric Administrator** account. No app registration needed.

### ROPC / Service Account

- Account must have **Power BI Administrator** Entra role
- Account must **not** have MFA or device-compliance Conditional Access
- App registration must have **"Allow public client flows" = Yes**
  `Entra ID → App registrations → [App] → Authentication → Advanced settings`

---

## S3 Upload

Both the PowerShell and Python versions support uploading all generated report files to an Amazon S3 bucket.

### PowerShell

Requires `AWS.Tools.S3` (or the monolithic `AWSPowerShell`) module. Credentials are resolved via the standard AWS credential chain (environment variables, `~/.aws/credentials`, instance profile).

```powershell
Install-Module AWS.Tools.S3 -Scope CurrentUser
```

```powershell
# Basic upload
.\Get-PBIWorkspaceUsageReport.ps1 ... `
    -PublishToS3 -S3BucketName "my-pbi-reports" -S3KeyPrefix "powerbi/2026-05"

# Using a named AWS profile and specific region
.\Get-PBIWorkspaceUsageReport.ps1 ... `
    -PublishToS3 -S3BucketName "my-pbi-reports" `
    -S3KeyPrefix "powerbi/2026-05" -S3Region "us-west-2" -S3ProfileName "prod-profile"
```

### Python

AWS credentials are resolved automatically via the standard boto3 chain:
1. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` environment variables
2. `~/.aws/credentials` named profile (`--s3-profile`)
3. EC2 / ECS / Lambda instance role

```bash
# Basic upload
python Get-PBIWorkspaceUsageReport.py ... \
    --s3-bucket my-pbi-reports --s3-prefix powerbi/2026-04

# With KMS encryption and Intelligent-Tiering
python Get-PBIWorkspaceUsageReport.py ... \
    --s3-bucket my-pbi-reports \
    --s3-prefix powerbi/2026-04 \
    --s3-kms-key alias/pbi-reports \
    --s3-storage-class INTELLIGENT_TIERING

# Using a named AWS profile
python Get-PBIWorkspaceUsageReport.py ... \
    --s3-bucket my-pbi-reports \
    --s3-profile my-aws-profile
```

All 7 output files (+ summary text) are uploaded. S3 failures are reported per-file and do not abort the run.

---

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| `401 Unauthorized` | Admin API tenant setting not enabled | Enable "Service principals can access read-only admin APIs" in Fabric Admin Portal |
| `0 workspaces returned` | Insufficient PBI permissions | Verify `Tenant.Read.All` + admin API gate |
| `0 activity events` / per-day 400 errors | Dates outside retention window | Use `--activity-days 30`; only go higher on Fabric/Premium |
| `AADSTS50076` (MFA) | ROPC blocked by MFA policy | Exclude service account from MFA CA, or use `-UseInteractiveAuth` |
| `AADSTS90010` (public client) | ROPC app not configured | Enable "Allow public client flows" on app registration |
| `StorageUsedMB` is null | Shared-capacity workspace | Expected — only populated for Premium/Fabric workspaces |
| Device types all "Unknown" | `ClientType` used (wrong field) | Fixed in v1.4 — uses `ConsumptionMethod` / `UserAgent` parsing |
| `pip install boto3` error | S3 feature not needed | Omit `--s3-bucket` to skip upload entirely |
| `AWS.Tools.S3 module required` | PS S3 module missing | `Install-Module AWS.Tools.S3 -Scope CurrentUser` |

---

## Identify Stale Reports

```powershell
# PowerShell — filter zero-view reports from the usage CSV
$usage = Import-Csv "C:\Reports\PBI\PBI_Report_Usage_*.csv" | Select-Object -Last 1 -ExpandProperty PSPath |
    ForEach-Object { Import-Csv $_ }
$stale = Import-Csv (Get-ChildItem "C:\Reports\PBI\PBI_Report_Usage_*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
        | Where-Object { [int]$_.TotalViews_90d -eq 0 }
Write-Host "Stale reports: $($stale.Count)"
$stale | Select-Object ReportName, WorkspaceName, WorkspaceType | Format-Table
```

```python
# Python — find stale reports
import csv
with open("PBI_Report_Usage_20260403_120000.csv") as f:
    stale = [r for r in csv.DictReader(f) if int(r["TotalViews_90d"]) == 0]
print(f"Stale reports: {len(stale)}")
```

---

## Version History

| Version | Date | Changes |
|---|---|---|
| **v1.6.0** | 2026-05-07 | PowerShell S3 upload — `-PublishToS3`, `-S3BucketName`, `-S3KeyPrefix`, `-S3Region`, `-S3ProfileName` (requires `AWS.Tools.S3`) |
| **v1.5.1** | 2026-04-03 | Python port — S3 upload (`upload_to_s3`), all PS features parity |
| **v1.5.0** | 2026-04-03 | Dataset health export (`PBI_Dataset_Health`): `TargetStorageMode`, `StorageCategory`, `IsRefreshable`, gateway flag; `-IncludeRefreshHistory` switch for last refresh per dataset |
| **v1.4.0** | 2026-03-31 | Workspace size export (`PBI_Workspace_Size`): `StorageUsedMB`, dataset/report count; Device type breakdown using `ConsumptionMethod` / `UserAgent` (fixes `ClientType` not-a-field bug) |
| **v1.3.0** | 2026-03-26 | ROPC / service account auth (`-Username` / `-Password`) |
| **v1.2.0** | 2026-03-20 | `-UseInteractiveAuth` via `MicrosoftPowerBIMgmt`; default `ActivityDays` 90 → 30 |
| **v1.1.0** | 2026-03-12 | Pre-flight validation, improved error handling, verbose logging |
| **v1.0.0** | — | Initial release — core inventory + usage correlation |

---

## See Also

- [`PBI-Admin-API-Reference.md`](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/PBI-Admin-API-Reference) — full field-level reference for every Admin API endpoint used
- [Power BI Admin REST API docs](https://learn.microsoft.com/en-us/rest/api/power-bi/admin)
- [Power BI Activity Log](https://learn.microsoft.com/en-us/power-bi/admin/service-admin-auditing)
