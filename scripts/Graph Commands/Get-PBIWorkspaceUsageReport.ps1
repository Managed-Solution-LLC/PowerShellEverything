<#
.SYNOPSIS
    Power BI Workspace Usage Report — Phase 1: Usage & Inventory
    Pulls all reports across ALL workspaces (including personal), correlates with
    Activity Log data for the last 90 days, and exports in CSV or JSON format.

.DESCRIPTION
    This script addresses the reporting gap identified in the PBI Workspace Strategy:
      1. All reports across all workspaces (including personal)
      2. The workspace each report is aligned to
      3. Report views over the last 90 days
      4. # of unique report users for the last 90 days
      5. A list of users who viewed each report

    APIs Used:
      - Admin - Groups GetGroupsAsAdmin   -> workspace + report inventory
      - Admin - ActivityEvents             -> ViewReport events (covers personal workspaces)

    Authentication:
      - Service Principal (App Registration) with Power BI Admin APIs enabled
      - Requires: Tenant.Read.All, Tenant.ReadWrite.All (Power BI Service)
        OR the SP must be added to the "Power BI Service Admins" security group
        and the tenant setting "Allow service principals to use Power BI admin APIs" enabled.

.PARAMETER TenantId
    Azure AD / Entra ID Tenant ID.

.PARAMETER ClientId
    App Registration (Service Principal) Client ID.

.PARAMETER ClientSecret
    App Registration Client Secret. For production use, pull from Key Vault.

.PARAMETER OutputPath
    Directory to write the output files. Defaults to the current directory.

.PARAMETER OutputFormat
    Export format: "csv" or "json". Defaults to "csv".
    JSON output uses proper arrays for user lists and pretty-printed formatting.

.PARAMETER ActivityDays
    Number of days of activity history to pull (max 90). Defaults to 90.

.EXAMPLE
    .\Get-PBIWorkspaceUsageReport.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
        -ClientId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" `
        -ClientSecret "your-secret-here"

.EXAMPLE
    .\Get-PBIWorkspaceUsageReport.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
        -ClientId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" `
        -ClientSecret "your-secret-here" `
        -OutputPath "C:\Reports\PBI" -OutputFormat "json" -ActivityDays 60

.NOTES
    Author  : Managed Solution - Will Ford
    Version : 1.1.0
    Date    : 2026-03-12

    Requirements:
    - PowerShell 5.1 or later
    - Service Principal with Power BI Admin API access
    - Write access to the OutputPath directory

    Updates in v1.1.0:
    - Added pre-flight validation (PowerShell version, directory permissions, parameter values)
    - Improved Get-PBIAccessToken with response validation and actionable error hints
    - Improved Export-Data with try/catch and verbose logging
    - Wrapped main authentication in try/catch with clean exit
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure AD / Entra ID Tenant ID")]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory = $true, HelpMessage = "App Registration (Service Principal) Client ID")]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter(Mandatory = $true, HelpMessage = "App Registration Client Secret")]
    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret,

    [Parameter(Mandatory = $false, HelpMessage = "Directory to write output files")]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false, HelpMessage = "Export format: csv or json")]
    [ValidateSet("csv", "json")]
    [string]$OutputFormat = "csv",

    [Parameter(Mandatory = $false, HelpMessage = "Number of days of activity history to pull (max 90)")]
    [ValidateRange(1, 90)]
    [int]$ActivityDays = 90
)

# ------------------------------------------------------------------------------
# PRE-FLIGHT VALIDATION
# ------------------------------------------------------------------------------

# Require PowerShell 5.1+
if ($PSVersionTable.PSVersion.Major -lt 5 -or
    ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1)) {
    Write-Host "❌ PowerShell 5.1 or later is required. Current: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    exit 1
}

# Create output directory if missing
if (-not (Test-Path -Path $OutputPath -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $OutputPath -Force -ErrorAction Stop | Out-Null
        Write-Host "✅ Created output directory: $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to create output directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Verify write permissions to output directory
$_pbiTestFile = Join-Path $OutputPath ".pbi_write_test_$([guid]::NewGuid().ToString().Substring(0,8)).tmp"
try {
    "test" | Out-File -FilePath $_pbiTestFile -ErrorAction Stop -Encoding UTF8
    Remove-Item -Path $_pbiTestFile -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Output directory write permissions verified." -ForegroundColor Green
}
catch {
    Write-Host "❌ Cannot write to '$OutputPath': $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Verify you have write permissions to this location." -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------------------------
# CONFIG & CONSTANTS
# ------------------------------------------------------------------------------

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"   # speeds up Invoke-RestMethod

$PBI_BASE_URL = "https://api.powerbi.com/v1.0/myorg"
$AUTH_URL     = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$SCOPE        = "https://analysis.windows.net/powerbi/api/.default"

$timestamp         = Get-Date -Format "yyyyMMdd_HHmmss"
$ext               = $OutputFormat.ToLower()
$reportOutPath     = Join-Path $OutputPath "PBI_Report_Inventory_$timestamp.$ext"
$usageOutPath      = Join-Path $OutputPath "PBI_Report_Usage_$timestamp.$ext"
$userDetailOutPath = Join-Path $OutputPath "PBI_Report_UserDetails_$timestamp.$ext"
$summaryPath       = Join-Path $OutputPath "PBI_Usage_Summary_$timestamp.txt"

# ------------------------------------------------------------------------------
# FUNCTIONS
# ------------------------------------------------------------------------------

function Get-PBIAccessToken {
    <#
    .SYNOPSIS
        Authenticate via OAuth2 client_credentials flow and return a bearer token.
    .NOTES
        Validates token response structure before returning.
        Provides actionable hints for common 400/401 failures.
    #>
    Write-Host "[AUTH] Acquiring access token..." -ForegroundColor Cyan

    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = $SCOPE
    }

    try {
        $response = Invoke-RestMethod -Uri $AUTH_URL -Method POST -Body $body `
            -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop

        if (-not $response.access_token) {
            throw "Response missing access_token. Response: $($response | ConvertTo-Json)"
        }

        Write-Host "[AUTH] Token acquired. Expires in $($response.expires_in) seconds." -ForegroundColor Green
        return $response.access_token
    }
    catch {
        Write-Host "❌ [AUTH] Failed to acquire token" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
        if ($_.Exception.Message -match "400|invalid") {
            Write-Host "   Hint: Verify that ClientId, ClientSecret, and TenantId are correct." -ForegroundColor Yellow
        }
        elseif ($_.Exception.Message -match "401|unauthorized") {
            Write-Host "   Hint: SP may lack required PBI Admin API permissions, or the tenant restricts SP admin API access." -ForegroundColor Yellow
        }
        throw
    }
}

function Invoke-PBIRestMethod {
    <#
    .SYNOPSIS
        Wrapper around Invoke-RestMethod that handles pagination via continuationUri
        and odata.nextLink, with 429 rate-limit retry.
    #>
    param(
        [string]$Uri,
        [string]$Token,
        [string]$Method = "GET"
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type"  = "application/json"
    }

    $allResults = @()
    $currentUri = $Uri

    do {
        try {
            $response = Invoke-RestMethod -Uri $currentUri -Headers $headers -Method $Method
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__

            # Handle 429 (Too Many Requests) with retry
            if ($statusCode -eq 429) {
                $retryAfter = 60
                $retryHeader = $_.Exception.Response.Headers["Retry-After"]
                if ($retryHeader) { $retryAfter = [int]$retryHeader }

                Write-Warning "[API] Rate-limited (429). Waiting $retryAfter seconds..."
                Start-Sleep -Seconds $retryAfter
                continue
            }

            Write-Error "[API] Request failed ($statusCode): $_"
            throw
        }

        # Collect results - response shape varies by endpoint
        if ($response.value) {
            $allResults += $response.value
        }
        elseif ($response.activityEventEntities) {
            $allResults += $response.activityEventEntities
        }

        # Advance pagination
        $currentUri = $null
        if ($response.'odata.nextLink')  { $currentUri = $response.'odata.nextLink' }
        if ($response.continuationUri)   { $currentUri = $response.continuationUri }
        if ($response.continuationToken) {
            $sep = if ($Uri -match "\?") { "&" } else { "?" }
            $currentUri = "$Uri${sep}continuationToken=$($response.continuationToken)"
        }

    } while ($currentUri)

    return $allResults
}

function Get-AllWorkspacesAndReports {
    <#
    .SYNOPSIS
        Uses Admin - GetGroupsAsAdmin with expand=reports to pull every workspace
        and every report in the tenant, including personal workspaces.
    #>
    param([string]$Token)

    Write-Host "[INVENTORY] Fetching all workspaces with reports (Admin API)..." -ForegroundColor Cyan

    # expand=reports includes report metadata in the workspace response
    # top=5000 is the max page size for this endpoint
    $uri = "$PBI_BASE_URL/admin/groups?`$expand=reports&`$top=5000"

    $workspaces = Invoke-PBIRestMethod -Uri $uri -Token $Token

    Write-Host "[INVENTORY] Retrieved $($workspaces.Count) workspaces." -ForegroundColor Green
    return $workspaces
}

function Get-ActivityEvents {
    <#
    .SYNOPSIS
        Pulls Power BI Activity Log events for a single day.
        The Activity Events API requires date-range queries scoped to a single UTC day.
    #>
    param(
        [string]$Token,
        [datetime]$Date,
        [string]$ActivityFilter = "ViewReport"
    )

    $startDT = $Date.ToString("yyyy-MM-dd'T'00:00:00.000'Z'")
    $endDT   = $Date.ToString("yyyy-MM-dd'T'23:59:59.999'Z'")

    $uri = "$PBI_BASE_URL/admin/activityevents?startDateTime='$startDT'&endDateTime='$endDT'&`$filter=Activity eq '$ActivityFilter'"

    return Invoke-PBIRestMethod -Uri $uri -Token $Token
}

function Get-AllActivityEvents {
    <#
    .SYNOPSIS
        Iterates day-by-day over the requested window and collects all ViewReport events.
        The Activity Events API is scoped to single-day queries, so we loop.
    #>
    param(
        [string]$Token,
        [int]$Days = 90
    )

    Write-Host "[ACTIVITY] Pulling ViewReport activity for the last $Days days..." -ForegroundColor Cyan

    $allEvents = @()
    $today     = (Get-Date).Date
    $startDate = $today.AddDays(-$Days)

    for ($d = $startDate; $d -lt $today; $d = $d.AddDays(1)) {
        $dayStr = $d.ToString("yyyy-MM-dd")
        Write-Host "  Fetching $dayStr ..." -NoNewline

        $events = Get-ActivityEvents -Token $Token -Date $d
        $count  = ($events | Measure-Object).Count

        Write-Host " $count events" -ForegroundColor $(if ($count -gt 0) { "Green" } else { "DarkGray" })
        $allEvents += $events

        # Small delay to be kind to the API rate limits
        Start-Sleep -Milliseconds 200
    }

    Write-Host "[ACTIVITY] Total ViewReport events collected: $($allEvents.Count)" -ForegroundColor Green
    return $allEvents
}

function Export-Data {
    <#
    .SYNOPSIS
        Exports a collection of objects to CSV or JSON based on OutputFormat.
        JSON is pretty-printed at Depth 10 for nested objects.
    .NOTES
        PS 5.1 compatibility: ConvertTo-Json lacks -AsArray. Single-item collections
        are wrapped in @() and handled manually for consistent JSON array output.
        Both formats use UTF8 encoding without BOM.
    #>
    param(
        [object[]]$Data,
        [string]$FilePath,
        [string]$Format
    )

    try {
        if ($Format -eq "json") {
            # Wrap in @() to guarantee array even for single-item collections
            $jsonArray = @($Data)
            if ($jsonArray.Count -eq 1) {
                # PS 5.1: ConvertTo-Json outputs bare object for single items - wrap manually
                $json = ConvertTo-Json -InputObject $jsonArray -Depth 10
            }
            else {
                $json = $jsonArray | ConvertTo-Json -Depth 10
            }
            [System.IO.File]::WriteAllText($FilePath, $json, [System.Text.Encoding]::UTF8)
        }
        else {
            $Data | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        }
        Write-Verbose "Exported $($Data.Count) records to: $FilePath"
    }
    catch {
        Write-Host "❌ Failed to export data to '$FilePath': $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ------------------------------------------------------------------------------
# MAIN EXECUTION
# ------------------------------------------------------------------------------

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  Power BI Workspace Usage Report - Phase 1                   " -ForegroundColor Yellow
Write-Host "  Managed Solution                                             " -ForegroundColor Yellow
Write-Host "  Output Format: $($OutputFormat.ToUpper())                   " -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""

# Step 1: Authenticate
try {
    $token = Get-PBIAccessToken
}
catch {
    Write-Host "❌ Script terminated: authentication failed. Verify your credentials and try again." -ForegroundColor Red
    exit 1
}

# Step 2: Pull workspace & report inventory
$workspaces = Get-AllWorkspacesAndReports -Token $token

# Flatten into a report-level table
$reportInventory = @()
foreach ($ws in $workspaces) {
    $wsType = if ($ws.type -eq "PersonalGroup") { "Personal" } else { "Shared" }
    $wsName = if ($ws.name) { $ws.name } else { "[Personal - $($ws.id)]" }

    if ($ws.reports) {
        foreach ($report in $ws.reports) {
            $reportInventory += [PSCustomObject]@{
                WorkspaceId      = $ws.id
                WorkspaceName    = $wsName
                WorkspaceType    = $wsType
                WorkspaceState   = $ws.state
                ReportId         = $report.id
                ReportName       = $report.name
                ReportWebUrl     = $report.webUrl
                DatasetId        = $report.datasetId
                CreatedDateTime  = $report.createdDateTime
                ModifiedDateTime = $report.modifiedDateTime
            }
        }
    }
}

$totalReports    = $reportInventory.Count
$sharedReports   = ($reportInventory | Where-Object { $_.WorkspaceType -eq "Shared" }).Count
$personalReports = ($reportInventory | Where-Object { $_.WorkspaceType -eq "Personal" }).Count

Write-Host ""
Write-Host "[INVENTORY] Report Inventory Summary:" -ForegroundColor Cyan
Write-Host "  Total Reports       : $totalReports"
Write-Host "  Shared Workspace    : $sharedReports"
Write-Host "  Personal Workspace  : $personalReports"
Write-Host ""

Export-Data -Data $reportInventory -FilePath $reportOutPath -Format $OutputFormat
Write-Host "✅ [EXPORT] Report inventory  -> $reportOutPath" -ForegroundColor Green

# Step 3: Pull Activity Log events (ViewReport)
$activityEvents = Get-AllActivityEvents -Token $token -Days $ActivityDays

# Step 4: Correlate activity with inventory
Write-Host ""
Write-Host "[CORRELATE] Joining activity data with report inventory..." -ForegroundColor Cyan

# Build a lookup of ReportId -> activity events
$activityByReport = @{}
foreach ($event in $activityEvents) {
    $rid = $event.ReportId
    if (-not $rid) { continue }
    if (-not $activityByReport.ContainsKey($rid)) { $activityByReport[$rid] = @() }
    $activityByReport[$rid] += $event
}

# Build the usage summary per report
$usageSummary = @()
$userDetails  = @()

foreach ($report in $reportInventory) {
    $rid    = $report.ReportId
    $events = if ($activityByReport.ContainsKey($rid)) { $activityByReport[$rid] } else { @() }

    $users     = $events | Where-Object { $_.UserId } | Select-Object -ExpandProperty UserId -Unique
    $viewCount = ($events | Measure-Object).Count

    $usageSummary += [PSCustomObject]@{
        ReportId        = $rid
        ReportName      = $report.ReportName
        WorkspaceId     = $report.WorkspaceId
        WorkspaceName   = $report.WorkspaceName
        WorkspaceType   = $report.WorkspaceType
        TotalViews_90d  = $viewCount
        UniqueUsers_90d = $users.Count
        UserList_90d    = if ($OutputFormat -eq "json") { @($users) } else { ($users -join "; ") }
        DatasetId       = $report.DatasetId
        ReportWebUrl    = $report.ReportWebUrl
    }

    foreach ($user in $users) {
        $userEvents  = $events | Where-Object { $_.UserId -eq $user }
        $userDetails += [PSCustomObject]@{
            ReportId      = $rid
            ReportName    = $report.ReportName
            WorkspaceName = $report.WorkspaceName
            WorkspaceType = $report.WorkspaceType
            UserId        = $user
            ViewCount_90d = ($userEvents | Measure-Object).Count
            LastViewed    = ($userEvents | Sort-Object CreationTime -Descending | Select-Object -First 1).CreationTime
        }
    }
}

# Sort: most-viewed reports first
$usageSummary = $usageSummary | Sort-Object TotalViews_90d -Descending
$userDetails  = $userDetails  | Sort-Object ReportName, ViewCount_90d -Descending

# Step 5: Export results
Export-Data -Data $usageSummary -FilePath $usageOutPath -Format $OutputFormat
Write-Host "✅ [EXPORT] Usage summary     -> $usageOutPath" -ForegroundColor Green

Export-Data -Data $userDetails -FilePath $userDetailOutPath -Format $OutputFormat
Write-Host "✅ [EXPORT] User details      -> $userDetailOutPath" -ForegroundColor Green

# Step 6: Console summary & text report
$reportsWithUsage    = ($usageSummary | Where-Object { $_.TotalViews_90d -gt 0 }).Count
$reportsWithoutUsage = $totalReports - $reportsWithUsage
$totalViews          = ($usageSummary | Measure-Object -Property TotalViews_90d -Sum).Sum
$totalUniqueUsers    = ($userDetails | Select-Object -ExpandProperty UserId -Unique).Count
$topReports          = $usageSummary | Select-Object -First 10

$summaryText = @"
═══════════════════════════════════════════════════════════════
  POWER BI WORKSPACE USAGE REPORT - PHASE 1
  Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  Activity Window: Last $ActivityDays days
  Output Format: $($OutputFormat.ToUpper())
═══════════════════════════════════════════════════════════════

INVENTORY
  Total Workspaces       : $($workspaces.Count)
  Total Reports          : $totalReports
    Shared Workspace     : $sharedReports
    Personal Workspace   : $personalReports

USAGE (Last $ActivityDays Days)
  Reports WITH views     : $reportsWithUsage
  Reports WITHOUT views  : $reportsWithoutUsage
  Total Report Views     : $totalViews
  Total Unique Users     : $totalUniqueUsers

TOP 10 MOST-VIEWED REPORTS
$( ($topReports | ForEach-Object {
    "  {0,-50} {1,6} views | {2,3} users | [{3}] {4}" -f `
        $_.ReportName.Substring(0, [Math]::Min($_.ReportName.Length, 50)),
        $_.TotalViews_90d,
        $_.UniqueUsers_90d,
        $_.WorkspaceType,
        $_.WorkspaceName
}) -join "`n" )

OUTPUT FILES
  Report Inventory : $reportOutPath
  Usage Summary    : $usageOutPath
  User Details     : $userDetailOutPath
  This Summary     : $summaryPath
═══════════════════════════════════════════════════════════════
"@

$summaryText | Out-File -FilePath $summaryPath -Encoding UTF8
Write-Host ""
Write-Host $summaryText
Write-Host ""
Write-Host "✅ [DONE] All reports generated successfully." -ForegroundColor Green