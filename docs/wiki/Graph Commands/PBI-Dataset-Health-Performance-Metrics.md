# Power BI Dataset Health & Performance Metrics

> **Related script:** `scripts/Graph Commands/Get-PBIWorkspaceUsageReport.ps1` (v1.5.0+)
> **Output file:** `PBI_Dataset_Health_$timestamp.csv`

---

## Overview

The Power BI Admin REST API does **not** expose byte-level dataset memory consumption.
This document explains what IS available via the admin API, how it maps to performance
risk, and where to go when you need actual memory numbers.

---

## What `PBI_Dataset_Health` Contains

Each row is one dataset. Fields are built from the workspace `$expand=datasets` call —
**no extra API calls** are needed for the base output.

| Column | Source | Notes |
|---|---|---|
| `WorkspaceId` | Workspace object | |
| `WorkspaceName` | Workspace object | |
| `WorkspaceType` | Workspace object | `Shared` or `Personal` |
| `DatasetId` | Dataset object | |
| `DatasetName` | Dataset object | |
| `TargetStorageMode` | `dataset.targetStorageMode` | Raw API value (see table below) |
| `StorageCategory` | Derived | Human-readable memory proxy |
| `IsRefreshable` | `dataset.isRefreshable` | `False` for DirectQuery, push, streaming |
| `IsOnPremGatewayRequired` | `dataset.isOnPremGatewayRequired` | On-premises data source dependency |
| `ConfiguredBy` | `dataset.configuredBy` | Owner UPN |
| `LastRefreshStart` | Refresh history API | Requires `-IncludeRefreshHistory` |
| `LastRefreshEnd` | Refresh history API | Requires `-IncludeRefreshHistory` |
| `LastRefreshDurationMin` | Calculated | `(EndTime - StartTime)` in minutes; proxy for dataset size |
| `LastRefreshStatus` | Refresh history API | `Completed` \| `Failed` \| `Cancelled` |

---

## TargetStorageMode Values and Memory Implications

| API Value | StorageCategory | Memory Behaviour |
|---|---|---|
| `Abf` | Import (In-Memory) | Dataset loaded into Analysis Services vertipaq engine. **Highest memory footprint.** Stored as `.abf` compressed columnar format. |
| `PremiumFiles` | Import (Large Format) | Same in-memory engine but uses Premium large dataset storage (`.pbi` files, up to 400 GB). Even higher memory footprint. |
| `Pbix` | Import (In-Memory) | Older small-dataset import format. Same engine as Abf. |
| `DirectQuery` | DirectQuery (No Memory) | No data stored in Power BI. Every visual fires a query to the source. **Zero memory footprint**, but source database bears the query load. |
| `Streaming` | Streaming | Real-time push data. Memory footprint managed by the streaming engine, not vertipaq. |
| `CompositeModel` | Composite | Mix of Import tables and DirectQuery tables in one dataset. Memory footprint is proportional to the imported partition of the model. |

> **Rule of thumb:** Any dataset where `StorageCategory` starts with `Import` is held in
> Analysis Services memory. If a Premium capacity is running hot, Import datasets are the
> first place to investigate.

---

## Refresh Duration as a Size Proxy

When `-IncludeRefreshHistory` is specified, the script calls:

```
GET /v1.0/myorg/admin/datasets/{datasetId}/refreshes?$top=1
```

| Refresh Duration | Rough Signal |
|---|---|
| < 5 min | Small dataset; low memory risk |
| 5 – 30 min | Medium dataset; worth monitoring |
| 30 – 60 min | Large dataset; may strain capacity during peak hours |
| > 60 min | Very large dataset; review partitioning, incremental refresh, or Premium capacity sizing |

> Refresh duration is influenced by source query time and network latency — not just model
> size — so treat it as a signal, not a precise measurement.

**Performance note:** This switch makes one API call per refreshable dataset. On large tenants
(hundreds or thousands of datasets) this can take several minutes and may hit rate limits.
The script adds a 200 ms delay between calls and handles errors per-dataset without stopping.

---

## What the Admin API Cannot Provide

| Metric | Why Not Available | Where to Get It |
|---|---|---|
| Dataset memory size (bytes / MB) | Not exposed in any REST endpoint | XMLA endpoint DMV: `SELECT * FROM $SYSTEM.DISCOVER_OBJECT_MEMORY_USAGE` (Premium / Fabric only) |
| Per-table memory breakdown | Not in REST API | XMLA: `SELECT * FROM $SYSTEM.DISCOVER_STORAGE_TABLES` |
| Query duration / render time | Not in Admin API | Azure Log Analytics → `PowerBIActivity` / `AzureDiagnostics` table |
| CPU consumption per dataset | Not in REST API | Fabric Capacity Metrics app (internal, no public API) |
| Throttling / overload events | Not in REST API | Fabric Capacity Metrics app or Azure Monitor alerts |
| Partition-level memory | Not in REST API | XMLA: `SELECT * FROM $SYSTEM.DISCOVER_STORAGE_TABLE_COLUMNS` |

---

## XMLA Memory Queries (Premium / Fabric Only)

For tenants on Premium or Fabric capacity, true memory metrics are available via the
XMLA read endpoint. Connect with SQL Server Management Studio (SSMS) or DAX Studio
to the workspace XMLA endpoint (`powerbi://api.powerbi.com/v1.0/myorg/WorkspaceName`).

### Total memory per dataset object
```sql
SELECT
    OBJECT_PARENT_PATH,
    OBJECT_NAME,
    OBJECT_TYPE,
    USED_SIZE / 1048576.0 AS UsedSizeMB,
    CREATED_TIME
FROM $SYSTEM.DISCOVER_OBJECT_MEMORY_USAGE
ORDER BY USED_SIZE DESC
```

### Storage size per table
```sql
SELECT
    TABLE_ID,
    USED_SIZE / 1048576.0 AS UsedSizeMB,
    ROWS_COUNT
FROM $SYSTEM.DISCOVER_STORAGE_TABLES
ORDER BY USED_SIZE DESC
```

### Column encoding and size
```sql
SELECT
    TABLE_ID,
    COLUMN_ID,
    COLUMN_TYPE,
    USED_SIZE / 1048576.0 AS UsedSizeMB,
    DICTIONARY_SIZE / 1048576.0 AS DictionarySizeMB
FROM $SYSTEM.DISCOVER_STORAGE_TABLE_COLUMNS
ORDER BY USED_SIZE DESC
```

> Requires the user or service principal to have **XMLA Read** access on the capacity
> (`Fabric Admin Portal → Capacity settings → Power BI workloads → XMLA Endpoint = Read`).

---

## Azure Log Analytics (Premium / Fabric)

If the workspace is linked to an Azure Log Analytics workspace
(`Workspace Settings → Azure connections → Log Analytics`), the following tables
are available in Log Analytics / Azure Monitor:

| Table | Useful Columns | What to Query |
|---|---|---|
| `PowerBIActivity` | `DurationMs`, `DatasetName`, `WorkspaceName` | Average query duration per dataset |
| `AzureDiagnostics` | `duration_d`, `dataset_s` | Refresh telemetry |

Example KQL — average query duration per dataset (last 7 days):
```kql
PowerBIActivity
| where TimeGenerated > ago(7d)
| where OperationName == "QueryEnd"
| summarize AvgDurationMs = avg(DurationMs), QueryCount = count()
    by DatasetName, WorkspaceName
| order by AvgDurationMs desc
```

---

## Using the Script

### Basic run (no refresh history)
```powershell
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId  "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -ClientId  "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" `
    -ClientSecret "your-secret"
```
Produces `PBI_Dataset_Health_$timestamp.csv` with `TargetStorageMode`, `StorageCategory`,
`IsRefreshable`, `IsOnPremGatewayRequired`, `ConfiguredBy` — all columns populated.
`LastRefresh*` columns present but empty.

### With refresh history (one extra API call per refreshable dataset)
```powershell
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId  "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -ClientId  "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" `
    -ClientSecret "your-secret" `
    -IncludeRefreshHistory
```
Populates `LastRefreshStart`, `LastRefreshEnd`, `LastRefreshDurationMin`, `LastRefreshStatus`
for all `IsRefreshable = True` datasets.

---

## Text Summary Section

The `PBI_Usage_Summary_$timestamp.txt` file now includes a **DATASET STORAGE MODE BREAKDOWN**
section showing a count of datasets per `StorageCategory`. Example output:

```
DATASET STORAGE MODE BREAKDOWN
  (Import = held in Analysis Services memory; DirectQuery = no memory footprint)
  Import (In-Memory)           142 dataset(s)
  DirectQuery (No Memory)       38 dataset(s)
  Composite                     12 dataset(s)
  Import (Large Format)          3 dataset(s)
```

A high ratio of Import datasets on a shared-capacity tenant is a common cause of
slow report loads and refresh failures — this breakdown helps identify whether
upgrading to Premium/Fabric would be beneficial.

---

*Last updated: 2026-04-03 | Managed Solution — Will Ford*
*See also: [PBI Admin API Reference](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/PBI-Admin-API-Reference)*
