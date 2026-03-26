# PBI Workspace Usage → Dataverse Automation Architecture

## Overview

This document describes the automated pipeline that runs `Get-PBIWorkspaceUsageReport.ps1` on a schedule via an Azure Function, stages the output in Blob Storage, and uses a Power Automate flow to validate and load the data into Dataverse.

---

## High-Level Architecture

```mermaid
flowchart TD
    KV[(Azure Key Vault\nROPC Password\nTenant ID / Client ID)]
    AF[Azure Function\nTimer Trigger\nPowerShell]
    BLOB[(Blob Storage\nreports/pending/\nreports/failed/)]
    PA[Power Automate\nBlob Created Trigger]
    DV[(Dataverse\nPBI Usage Table)]
    ALERT[Email / Teams Alert\nMax retries exceeded]

    KV -->|secrets at runtime| AF
    AF -->|writes report JSON| BLOB
    BLOB -->|new file event| PA
    PA -->|valid data| DV
    PA -->|invalid / parse error| BLOB
    BLOB -->|retry count exceeded| ALERT
    PA -->|retry — HTTP POST| AF
```

---

## Azure Function — Internal Flow

```mermaid
flowchart TD
    START([Timer Trigger\nor HTTP POST])
    PARAMS{Retry count\nin request body?}
    RETRY_CHK{RetryCount\n≥ 3?}
    FAIL_OUT[Write report to\nreports/failed/\nwith error metadata]
    DEAD([Exit — Dead Letter\nAlert upstream])
    KV_FETCH[Fetch secrets\nfrom Key Vault\nvia Managed Identity]
    ROPC[ROPC Token Request\nPBI Admin API]
    TOKEN_OK{Token\nacquired?}
    TOKEN_ERR[Write error blob\nto reports/failed/]
    PBI_GROUPS[GET /admin/groups\nall workspaces + reports]
    PBI_ACTIVITY[GET /admin/activityEvents\nViewReport events\nfor ActivityDays]
    CORRELATE[Correlate reports\nwith activity data\nbuild usage objects]
    SERIALIZE[Serialize to JSON\nwith metadata block:\n- generatedAt\n- retryCount\n- tenantId]
    WRITE_BLOB[Write to\nreports/pending/\nyyyyMMdd_HHmmss.json]
    DONE([Exit — Success])

    START --> PARAMS
    PARAMS -->|yes| RETRY_CHK
    PARAMS -->|no, retryCount = 0| KV_FETCH
    RETRY_CHK -->|yes| FAIL_OUT
    RETRY_CHK -->|no| KV_FETCH
    FAIL_OUT --> DEAD
    KV_FETCH --> ROPC
    ROPC --> TOKEN_OK
    TOKEN_OK -->|no| TOKEN_ERR
    TOKEN_ERR --> DEAD
    TOKEN_OK -->|yes| PBI_GROUPS
    PBI_GROUPS --> PBI_ACTIVITY
    PBI_ACTIVITY --> CORRELATE
    CORRELATE --> SERIALIZE
    SERIALIZE --> WRITE_BLOB
    WRITE_BLOB --> DONE
```

---

## Power Automate Flow — Internal Logic

```mermaid
flowchart TD
    TRIGGER([When a blob is created\nreports/pending/ container])
    GET_BLOB[Get blob content]
    PARSE[Parse JSON\ncheck schema:\n- generatedAt present\n- workspaces array not empty\n- retryCount field]
    VALID{Schema\nvalid?}
    RETRY_CHK{retryCount\n≥ 3?}
    ALERT[Send Teams / Email alert\nBlob name + error reason\nManual review required]
    MOVE_FAILED[Move blob to\nreports/failed/]
    LOOP[For each workspace row\nUpsert into Dataverse\nPBI Usage table\nmatch on ReportId + Date]
    DV_ERR{Dataverse\nerror?}
    MOVE_DONE[Move blob to\nreports/processed/]
    INCREMENT[RetryCount + 1\nRebuild request body]
    HTTP[HTTP POST\nAzure Function URL\nbody: retryCount]
    DONE([End])

    TRIGGER --> GET_BLOB
    GET_BLOB --> PARSE
    PARSE --> VALID
    VALID -->|yes| LOOP
    VALID -->|no| RETRY_CHK
    RETRY_CHK -->|yes| ALERT
    RETRY_CHK -->|no| INCREMENT
    ALERT --> MOVE_FAILED
    MOVE_FAILED --> DONE
    INCREMENT --> HTTP
    HTTP --> DONE
    LOOP --> DV_ERR
    DV_ERR -->|yes| RETRY_CHK
    DV_ERR -->|no| MOVE_DONE
    MOVE_DONE --> DONE
```

---

## Deployment Guide

### 1. Prerequisites

| Resource | Notes |
|---|---|
| Azure Subscription | Contributor access required |
| Azure Function App | PowerShell 7.4 runtime, Windows or Linux |
| Azure Key Vault | For ROPC credentials |
| Azure Storage Account | Blob Storage (LRS sufficient) |
| Power Automate | Premium license (Azure Blob connector is premium) |
| Dataverse environment | Table pre-created — see schema below |
| Entra App Registration | Existing SP from `Get-PBIWorkspaceUsageReport.ps1` |

---

### 2. Blob Storage Setup

Create three containers in the storage account:

| Container | Purpose |
|---|---|
| `reports/pending` | Function writes here; PA trigger watches here |
| `reports/processed` | PA moves valid blobs here after Dataverse load |
| `reports/failed` | Dead-letter — blobs that exceeded retry limit |

Set a **Lifecycle Management policy** on `reports/processed` to delete blobs older than 90 days.

---

### 3. Azure Key Vault — Secrets

Store the following secrets:

| Secret Name | Value |
|---|---|
| `pbi-tenant-id` | Entra Tenant ID |
| `pbi-client-id` | App Registration Client ID |
| `pbi-svc-username` | Service account UPN |
| `pbi-svc-password` | Service account password |

---

### 4. Azure Function App Setup

#### 4a. Enable System-Assigned Managed Identity

**Function App → Identity → System assigned → Status: On → Save**

#### 4b. Grant Managed Identity access to Key Vault

In Key Vault → **Access policies** (or RBAC if using Azure RBAC model):

- Grant the Function App's identity the **Key Vault Secrets User** role

#### 4c. Grant Managed Identity access to Blob Storage

In the Storage Account → **Access Control (IAM)**:

- Assign **Storage Blob Data Contributor** to the Function App's identity

#### 4d. Function App Settings

Add the following Application Settings (not secrets — these are non-sensitive references):

| Setting | Value |
|---|---|
| `KEY_VAULT_NAME` | Your Key Vault name |
| `BLOB_ACCOUNT_NAME` | Your Storage Account name |
| `BLOB_CONTAINER_PENDING` | `reports/pending` |
| `ACTIVITY_DAYS` | `30` (or `90` for Fabric/Premium) |

#### 4e. Deploy the Function

The Function wraps `Get-PBIWorkspaceUsageReport.ps1` with the following entry point pattern:

```powershell
# run.ps1 (timer trigger)
using namespace System.Net

param($Timer, $TriggerMetadata)

# Read retry count from binding metadata (HTTP trigger passes this)
$retryCount = $TriggerMetadata.RetryCount ?? 0

# Fetch secrets from Key Vault via Managed Identity
$kvUri     = "https://$env:KEY_VAULT_NAME.vault.azure.net"
$tenantId  = (Invoke-RestMethod "$kvUri/secrets/pbi-tenant-id?api-version=7.4" -Headers (Get-MIAuthHeader)).value
$clientId  = (Invoke-RestMethod "$kvUri/secrets/pbi-client-id?api-version=7.4" -Headers (Get-MIAuthHeader)).value
$username  = (Invoke-RestMethod "$kvUri/secrets/pbi-svc-username?api-version=7.4" -Headers (Get-MIAuthHeader)).value
$password  = (Invoke-RestMethod "$kvUri/secrets/pbi-svc-password?api-version=7.4" -Headers (Get-MIAuthHeader)).value | ConvertTo-SecureString -AsPlainText -Force

# Run the report script — output to temp path
$outPath = [System.IO.Path]::GetTempPath()
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId $tenantId `
    -ClientId $clientId `
    -Username $username `
    -Password $password `
    -OutputPath $outPath `
    -OutputFormat json `
    -ActivityDays $env:ACTIVITY_DAYS

# Upload result blob with retry metadata injected
# ... (upload logic using Az.Storage or REST with MI token)
```

> The full Function implementation is out of scope for this doc. The pattern above shows the secret retrieval and script invocation approach.

#### 4f. Timer Schedule

Set the CRON expression in `function.json`:

```json
{
  "schedule": "0 0 6 * * 1"
}
```

This runs **every Monday at 06:00 UTC**. Adjust to suit your reporting cadence.

---

### 5. Dataverse Table Schema

Create a custom table `pbi_workspaceusage` with the following columns:

| Display Name | Schema Name | Type | Notes |
|---|---|---|---|
| Report ID | `pbi_reportid` | Text | Unique identifier from PBI |
| Report Name | `pbi_reportname` | Text | |
| Workspace ID | `pbi_workspaceid` | Text | |
| Workspace Name | `pbi_workspacename` | Text | |
| View Count | `pbi_viewcount` | Whole Number | |
| Unique Users | `pbi_uniqueusers` | Whole Number | |
| Report Date | `pbi_reportdate` | Date Only | Date of the report run |
| Generated At | `pbi_generatedat` | Date and Time | Timestamp from JSON metadata |
| Is Personal Workspace | `pbi_ispersonal` | Yes/No | |

Use **Report ID + Report Date** as the alternate key for upsert deduplication.

---

### 6. Power Automate Flow Setup

1. **Create a new Automated Cloud Flow**
2. **Trigger:** `Azure Blob Storage — When a blob is added or modified`
   - Storage account: your account
   - Container: `reports/pending`

3. **Actions (in order):**
   - `Get blob content` — get the new file
   - `Parse JSON` — use the report schema
   - `Condition` — check schema validity (`generatedAt` exists, `workspaces` length > 0)
     - **Yes branch:** `Apply to each` over workspace rows → `Add a new row` (Dataverse, upsert on alternate key) → Move blob to `reports/processed`
     - **No branch:** Check `retryCount` field
       - **retryCount < 3:** Increment, `HTTP POST` to Function HTTP trigger URL with `{ "RetryCount": N }`
       - **retryCount ≥ 3:** Move blob to `reports/failed`, send Teams/Email alert

4. **Store the Function HTTP trigger URL** in a PA environment variable — do not hardcode it in the flow.

---

### 7. Security Notes

- The Power Automate HTTP action to re-trigger the Function must use the **Function Key** (not the master key). Store it in a PA environment variable.
- The service account used for ROPC must be excluded from any Conditional Access policies that enforce MFA or device compliance.
- Enable **Soft Delete** on the Storage Account to recover accidentally deleted blobs.
- Enable **Diagnostic Logging** on the Function App → Log Analytics workspace for alerting on failures.

---

### 8. Retry Flow Summary

```mermaid
sequenceDiagram
    participant F as Azure Function
    participant B as Blob Storage
    participant PA as Power Automate
    participant DV as Dataverse

    F->>B: Write report (retryCount=0)
    B-->>PA: Blob created trigger
    PA->>PA: Validate schema — FAIL
    PA->>F: HTTP POST retryCount=1
    F->>B: Write report (retryCount=1)
    B-->>PA: Blob created trigger
    PA->>PA: Validate schema — PASS
    PA->>DV: Upsert rows
    DV-->>PA: Success
    PA->>B: Move to reports/processed
```

---

*Author: Managed Solution — Will Ford*
*Last Updated: 2026-03-26*
