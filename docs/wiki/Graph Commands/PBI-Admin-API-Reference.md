# Power BI Admin REST API — What Can Be Accessed

> **Base URL:** `https://api.powerbi.com/v1.0/myorg/admin/`
> **Auth:** Bearer token — Service Principal (`client_credentials`) or delegated user with Power BI Administrator role
> **Key Requirement:** Fabric Admin Portal → Tenant settings → **Admin API settings** → "Service principals can access read-only admin APIs" must be enabled for SP auth to reach `/admin/` endpoints.

---

## Authentication Requirements

| Auth Method | Requirements | Notes |
|---|---|---|
| **Service Principal** | Entra App Registration + `Tenant.Read.All` PBI scope + Admin API gate enabled | Best for automation |
| **Interactive (delegated)** | Power BI Administrator Entra role + `MicrosoftPowerBIMgmt` module | Ad-hoc / dev use |
| **ROPC (service account)** | Power BI Administrator role + no MFA + "Allow public client flows" on app reg | Unattended fallback when SP auth is blocked at PBI service layer |
| **Fabric Administrator role** | Entra ID role assignment on the SP | Alternate to the Admin API tenant setting; grants access directly |

---

## Workspaces (Groups)

**Endpoint:** `GET /admin/groups`

| Field / Expand | Details |
|---|---|
| `id` | Workspace GUID |
| `name` | Display name (`null` for personal workspaces) |
| `type` | `PersonalGroup` \| `Workspace` \| `Group` |
| `state` | `Active` \| `Deleted` \| `Removing` |
| `isReadOnly` | Boolean |
| `isOnDedicatedCapacity` | `true` for Premium / Fabric |
| `capacityId` | GUID of the assigned capacity (Premium / Fabric only) |
| `storageUsed` | Storage in MB — **populated for Premium / Fabric only; null for shared** |
| `defaultDatasetStorageFormat` | `Small` \| `Large` |
| `$expand=reports` | Inline report list per workspace |
| `$expand=datasets` | Inline dataset list per workspace |
| `$expand=dashboards` | Inline dashboard list |
| `$expand=dataflows` | Inline dataflow list |
| `$expand=users` | Workspace members and their roles |
| `$top` | Max page size 5,000 |

> **What you cannot get here:** Dataset memory consumption, per-report performance metrics, query timings.

---

## Reports

**Endpoints:**
- `GET /admin/reports` — all reports across the tenant
- `GET /admin/groups/{groupId}/reports` — reports in a specific workspace

| Field | Details |
|---|---|
| `id` | Report GUID |
| `name` | Display name |
| `webUrl` | Browser URL to open the report |
| `embedUrl` | Embed URL |
| `datasetId` | Backing dataset GUID |
| `createdDateTime` | ISO 8601 timestamp |
| `modifiedDateTime` | ISO 8601 timestamp |
| `reportType` | `PowerBIReport` \| `PaginatedReport` \| `ExcelWorkbook` |

> **What you cannot get here:** Per-report memory, render time, query duration, page-level metrics. Those require XMLA or Log Analytics.

---

## Datasets

**Endpoints:**
- `GET /admin/datasets` — all datasets across the tenant
- `GET /admin/groups/{groupId}/datasets` — datasets in a workspace
- `GET /admin/datasets/{datasetId}/users` — dataset user permissions

| Field | Details |
|---|---|
| `id` | Dataset GUID |
| `name` | Display name |
| `configuredBy` | Owner UPN |
| `targetStorageMode` | `Import` (in-memory) \| `DirectQuery` \| `Streaming` \| `CompositeModel` |
| `isRefreshable` | Boolean — can it be refreshed via API |
| `addRowsAPIEnabled` | Boolean — Push dataset |
| `isOnPremGatewayRequired` | Boolean |
| `isEffectiveIdentityRequired` | Boolean — RLS required |
| `schemaRetrievalError` | Population error if schema could not be read |
| `upstreamDatasets` | Parent dataset references (chained datasets) |
| `contentProviderType` | `RealTime` \| `None` etc. |

**Refresh History:** `GET /datasets/{datasetId}/refreshes`

| Field | Details |
|---|---|
| `refreshType` | `Scheduled` \| `OnDemand` \| `ViaEnhancedApi` |
| `startTime` | ISO 8601 |
| `endTime` | ISO 8601 |
| `status` | `Completed` \| `Failed` \| `Unknown` |
| `serviceExceptionJson` | Error detail on failure |

> **Size / Memory:** `targetStorageMode` is the best REST proxy — `Import` = dataset loaded into Analysis Services memory. Actual byte-level memory is **not in the REST API**; requires XMLA DMV queries (Premium / Fabric only) or Azure Log Analytics.

---

## Dashboards

**Endpoints:**
- `GET /admin/dashboards` — all dashboards across the tenant
- `GET /admin/groups/{groupId}/dashboards` — dashboards in a workspace
- `GET /admin/dashboards/{dashboardId}/tiles` — tiles on a dashboard

| Field | Details |
|---|---|
| `id` | Dashboard GUID |
| `displayName` | Display name |
| `embedUrl` | Embed URL |
| `isReadOnly` | Boolean |
| `users` | Via `$expand=users` |
| `tiles[].reportId` | Backing report GUID (if from a report) |
| `tiles[].datasetId` | Backing dataset GUID |

---

## Dataflows

**Endpoints:**
- `GET /admin/dataflows` — all dataflows across the tenant
- `GET /admin/groups/{groupId}/dataflows` — dataflows in a workspace
- `GET /admin/dataflows/{dataflowId}/users` — dataflow permissions
- `GET /admin/dataflows/{dataflowId}/datasources` — data sources used

| Field | Details |
|---|---|
| `objectId` | Dataflow GUID |
| `name` | Display name |
| `configuredBy` | Owner UPN |
| `modifiedDateTime` | Last modified timestamp |
| `description` | Description text |
| `datasourceUsages` | Source connection references |

---

## Activity Log (Audit Events)

**Endpoint:** `GET /admin/activityevents?startDateTime=...&endDateTime=...`

- Scoped to **one UTC day per call** — loop day-by-day for multi-day windows
- Standard audit log retention: **30 days** (Fabric / Premium may extend this)
- Filters via `$filter=Activity eq 'ViewReport'` (or other activity type)

### Common Activity Types

| Activity | Description |
|---|---|
| `ViewReport` | User opened a report |
| `ExportReport` | User exported a report |
| `ViewDashboard` | User opened a dashboard |
| `ShareReport` | Report was shared |
| `PublishToWorkspace` | Report published |
| `CreateReport` | Report created |
| `DeleteReport` | Report deleted |
| `RefreshDataset` | Dataset refresh triggered |
| `ExportDataflow` | Dataflow exported |
| `CreateApp` | App created |
| `InstallApp` | App installed |
| `ViewApp` | App opened |

### Event Fields Returned

| Field | Details |
|---|---|
| `Id` | Event GUID |
| `RecordType` | Numeric record type |
| `CreationTime` | ISO 8601 UTC |
| `Operation` | Activity name (`ViewReport` etc.) |
| `UserId` | UPN of the acting user |
| `ReportId` | GUID of the report (ViewReport events) |
| `ReportName` | Display name |
| `WorkspaceId` | Workspace GUID |
| `WorkspaceName` | Workspace display name |
| `ArtifactId` | Generic artifact GUID (same as ReportId for reports) |
| `ArtifactName` | Generic artifact name |
| `ArtifactKind` | `Report` \| `Dashboard` \| `Dataset` etc. |
| `ClientIP` | Client IP address |
| `UserAgent` | Client user agent string — **use this to infer device type** |
| `ConsumptionMethod` | Present on newer / Fabric tenants (`OnDemand` etc.) |
| `IsSuccess` | Boolean |
| `RequestId` | Correlation GUID |
| `DatasetId` | Backing dataset GUID (where applicable) |
| `ReportType` | `PowerBIReport` \| `PaginatedReport` |
| `DistributionMethod` | `Workspace` \| `App` \| `Adhoc` |
| `MobileDeviceModel` | Populated for mobile clients |

> **`ClientType` is NOT a field in this API.** It belongs to the Unified Audit Log (M365 compliance center) format. Use `ConsumptionMethod` first, then parse `UserAgent`.

---

## Users & Permissions

**Endpoints:**
- `GET /admin/groups/{groupId}/users` — workspace members
- `GET /admin/reports/{reportId}/users` — report-level permissions
- `GET /admin/datasets/{datasetId}/users` — dataset permissions
- `GET /admin/dashboards/{dashboardId}/users` — dashboard permissions
- `GET /admin/apps/{appId}/users` — app subscribers

| Field | Details |
|---|---|
| `emailAddress` | User UPN |
| `displayName` | Display name |
| `groupUserAccessRight` | `Admin` \| `Contributor` \| `Member` \| `Viewer` |
| `principalType` | `User` \| `Group` \| `App` |
| `identifier` | Object ID |

---

## Capacities (Premium / Fabric)

**Endpoints:**
- `GET /admin/capacities` — all capacities in the tenant
- `PATCH /admin/capacities/{capacityId}/AssignWorkspaces` — assign workspaces
- `POST /admin/capacities/{capacityId}/UnassignWorkspaces` — unassign workspaces

| Field | Details |
|---|---|
| `id` | Capacity GUID |
| `displayName` | Display name |
| `sku` | SKU name (`P1`, `F64` etc.) |
| `state` | `Active` \| `Inactive` |
| `region` | Azure region string |
| `admins` | Capacity administrator UPNs |

> **Memory metrics** (utilization %, throttling, artifact memory) are **not in the REST API**. They are only accessible via the Fabric Capacity Metrics app or Azure Log Analytics.

---

## Apps

**Endpoints:**
- `GET /admin/apps` — all published apps in the tenant
- `GET /admin/apps/{appId}/users` — app subscribers

| Field | Details |
|---|---|
| `id` | App GUID |
| `name` | App name |
| `publishedBy` | Publisher UPN |
| `lastUpdate` | Last published timestamp |
| `description` | Description |
| `workspaceId` | Source workspace |

---

## Gateways

**Endpoints:**
- `GET /gateways` — gateways the calling user administers
- `GET /gateways/{gatewayId}/datasources` — data sources on the gateway

| Field | Details |
|---|---|
| `id` | Gateway GUID |
| `name` | Gateway display name |
| `type` | `Resource` (on-prem) \| `Personal` |
| `gatewayStatus` | `Live` \| `Unknown` |
| `gatewayAnnotation` | JSON blob with version, machine name, OS |
| `publicKey` | RSA public key for credential encryption |
| Datasources: `datasourceType` | `Sql` \| `SharePoint` \| `Exchange` etc. |
| Datasources: `connectionDetails` | JSON with server/database |

---

## Metadata Scanner API

The Scanner API performs deep tenant-wide scans and returns schema-level metadata not available through the standard endpoints.

**Workflow:**
1. `POST /admin/workspaces/getInfo` — initiate scan (pass workspace ID list or `lineage=true`, `datasetSchema=true`)
2. `GET /admin/workspaces/scanStatus/{scanId}` — poll until `status = Succeeded`
3. `GET /admin/workspaces/scanResult/{scanId}` — retrieve full results

### What Scanner Returns (beyond standard endpoints)

| Category | Fields |
|---|---|
| **Dataset tables** | Table name, row count estimate, storage mode per table |
| **Dataset columns** | Column name, data type, encoding, summarization |
| **Dataset measures** | DAX expression, table |
| **Dataset relationships** | From/to table+column, cardinality, cross-filter |
| **Dataset datasources** | Connection type, server, database, path |
| **Report pages** | Page name, display option, visuals |
| **Report visuals** | Visual type, title, dataset fields used |
| **Sensitivity labels** | Label ID, label name (if MIP integration enabled) |
| **Endorsement** | `Certified` \| `Promoted` \| `None` |
| **Upstream datasets** | Lineage chain |

> **Still not available via Scanner:** Byte-level memory consumption, query timings, render durations.

---

## Deployment Pipelines

**Endpoints:**
- `GET /pipelines` — pipelines the calling user can see
- `GET /pipelines/{pipelineId}/stages` — Dev / Test / Prod stages
- `GET /pipelines/{pipelineId}/stages/{stageOrder}/artifacts` — artifacts per stage

| Field | Details |
|---|---|
| `id` | Pipeline GUID |
| `displayName` | Pipeline name |
| Stages: `order` | 0 = Dev, 1 = Test, 2 = Prod |
| Stages: `workspaceId` | Linked workspace GUID |
| Artifacts: `artifactType` | `Report` \| `Dataset` \| `Dashboard` \| `Dataflow` |

---

## What the Admin API Cannot Provide

| Metric | Where to get it instead |
|---|---|
| Dataset memory consumption (MB) | XMLA endpoint DMV: `DISCOVER_OBJECT_MEMORY_USAGE` (Premium / Fabric only) |
| Per-table storage size | XMLA endpoint DMV: `DISCOVER_STORAGE_TABLES` |
| Query duration / render time | Azure Log Analytics (`PowerBIActivity` table) or Fabric Capacity Metrics app |
| CPU / throttling per dataset | Fabric Capacity Metrics app (internal APIs, not public) |
| Row-level data in datasets | Not accessible — Admin APIs are metadata only |
| Real-time streaming data | Not accessible via REST |
| Purview / data catalog lineage | Microsoft Purview API (separate) |
| Teams / SharePoint embed telemetry | M365 Usage Analytics (separate Graph reports) |

---

## Pagination

All list endpoints use OData-style pagination. Two patterns exist:

| Pattern | Endpoints | How to paginate |
|---|---|---|
| `odata.nextLink` | `reports`, `datasets`, `users`, `apps` | Follow the `odata.nextLink` URL |
| `continuationUri` + `continuationToken` | `activityevents` | Use `continuationUri` (fully formed URL) — do **not** reconstruct from `continuationToken` + original params |
| `$top` / `$skip` | `groups` (workspaces) | `$top=5000` is the max for groups |

---

## Rate Limits

| Limit | Value |
|---|---|
| Admin API calls per hour | ~200 requests (approx — varies by endpoint and tenant load) |
| Activity events calls per day | 1 call per day-range per token |
| `429 Too Many Requests` | Honour the `Retry-After` response header (usually 60s) |
| Scanner API | 1 active scan at a time per tenant |

---

## Useful PowerShell Patterns

```powershell
# Base headers for all calls
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

# Workspaces with reports + datasets expanded (max page = 5000)
$uri = "https://api.powerbi.com/v1.0/myorg/admin/groups?`$expand=reports,datasets&`$top=5000"

# Activity events — single day
$start = "'2026-04-01T00:00:00.000Z'"
$end   = "'2026-04-01T23:59:59.999Z'"
$uri   = "https://api.powerbi.com/v1.0/myorg/admin/activityevents?startDateTime=$start&endDateTime=$end"

# Scanner — initiate full tenant scan with schema
$body  = '{ "workspaces": [], "lineage": true, "datasetSchema": true, "datasetExpressions": true }'
$scan  = Invoke-RestMethod -Uri ".../admin/workspaces/getInfo?lineage=true&datasetSchema=true" `
             -Method POST -Headers $headers -Body $body
```

---

*Last updated: 2026-04-03 | Managed Solution — Will Ford*
*API reference: [Microsoft Power BI REST API docs](https://learn.microsoft.com/en-us/rest/api/power-bi/)*
