# Functions

Reusable PowerShell functions for day-to-day MSP work — dot-source any file to
load its function into your session, or fold them into a module. Unlike
`scripts/` (standalone, single-purpose tools), everything here is a building
block meant to be composed into other scripts.

Each file follows the same pattern: full comment-based help (`Get-Help
.\Name.ps1 -Full`), a `[CmdletBinding()]` function, pipeline support where it
makes sense, and PSCustomObject results so output can be filtered, formatted,
or exported.

## General/

| Function | Purpose |
|---|---|
| `Write-Log` | Timestamped, color-coded, leveled logging to console and/or a log file, with size-based rollover. |
| `Invoke-WithRetry` | Runs a scriptblock with automatic retry + exponential backoff (honors `Retry-After` on throttled calls). |
| `New-RandomPassword` | Generates cryptographically random passwords meeting configurable complexity rules. |

## Network/

| Function | Purpose |
|---|---|
| `Test-PortConnection` | Batch TCP port checks across hosts, with latency and timeout. |
| `Resolve-DnsRecord` | Batch DNS lookups (A/AAAA/MX/TXT/CNAME/etc.) with clean error handling. |
| `Get-PublicIPInfo` | Current public IP plus optional geolocation/ISP info. |
| `Test-WebsiteHealth` | HTTP status + response-time health check across one or more URLs. |
| `Get-SslCertificateInfo` | Checks the SSL/TLS certificate presented by one or more URLs and flags expiring/expired certs. |

## Graph/

| Function | Purpose |
|---|---|
| `Get-MgGraphAllPages` | Auto-pages through any Microsoft Graph API response so you stop writing `@odata.nextLink` loops. |
| `Connect-GraphWithScopes` | Connects to Microsoft Graph only when needed, checking the existing context/scopes/tenant first. |
| `Test-MgGraphConnection` | Read-only check of whether Graph is already connected, and with what scopes/tenant. |
| `Get-M365LicenseSummary` | Tenant-wide license SKU summary (assigned/available/percent used), with optional friendly names. |

## data operations/

| Function | Purpose |
|---|---|
| `Export-ResultToFile` | Exports any pipeline objects to a timestamped CSV/JSON/Excel file, creating the output folder if needed. |

## Requirements

Most functions here have no dependencies beyond PowerShell itself. A few call
into external modules and check for them at runtime, failing with a clear
message (not a stack trace) if missing:

- **Graph/** functions require `Microsoft.Graph.Authentication` (and
  `Microsoft.Graph.Identity.DirectoryManagement` for `Get-M365LicenseSummary`),
  plus an active `Connect-MgGraph` session.
- `Resolve-DnsRecord` requires the `Resolve-DnsName` cmdlet (Windows
  PowerShell / Windows 10+ / Windows Server — not available on non-Windows
  PowerShell 7 by default).
- `Export-ResultToFile -Format Excel` requires the community `ImportExcel`
  module; it falls back to CSV with a warning if that module isn't installed.
