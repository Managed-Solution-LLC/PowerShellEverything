<#
.SYNOPSIS
    Searches all SharePoint Online sites for group membership and exports results to JSON.
.DESCRIPTION
    Takes one or more group display names and checks every SharePoint Online site collection
    for membership (owners, members, visitors, and any SharePoint group that contains the
    target groups). Results are exported to a timestamped JSON file.

    The script uses the Microsoft.Online.SharePoint.PowerShell module (SPO Management Shell)
    to enumerate site collections and check SharePoint group membership. No app registration
    or Graph consent is required - just SharePoint admin credentials.

    Key features:
    - Accepts multiple group names to search for
    - Scans all SharePoint site collections (including Teams-connected and OneDrive optional)
    - Identifies group membership in SharePoint site groups with permission levels
    - Exports structured JSON with per-site membership details
    - Colored console progress output
.PARAMETER GroupNames
    One or more group display names to search for across SharePoint sites.
.PARAMETER AdminUrl
    SharePoint Online admin center URL (e.g. https://contoso-admin.sharepoint.com).
.PARAMETER OutputDirectory
    Directory for the JSON export. Defaults to C:\Reports\SharePoint_Exports.
.PARAMETER IncludeOneDriveSites
    Include OneDrive for Business personal sites in the scan. Off by default as these
    are typically numerous and slow to enumerate.
.EXAMPLE
    .\Get-GroupMembershipInSharePoint.ps1 -GroupNames "SG-Finance-Team" -AdminUrl "https://contoso-admin.sharepoint.com"
    Searches all SharePoint sites for the group "SG-Finance-Team" and exports results.
.EXAMPLE
    .\Get-GroupMembershipInSharePoint.ps1 -GroupNames "SG-Finance-Team","SG-IT-Admins" -AdminUrl "https://contoso-admin.sharepoint.com" -IncludeOneDriveSites
    Searches all sites including OneDrive personal sites for multiple groups.
.NOTES
    Author: W. Ford
    Date: 2026-04-09
    Version: 2.0

    Requirements:
    - Microsoft.Online.SharePoint.PowerShell module
    - SharePoint Online administrator role
    - PowerShell 5.1 (Windows PowerShell recommended; PS7 requires -UseWindowsPowerShell import)

    Module Installation:
    Run the following commands to install the required module:

        Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser -Force

    If you already have an older version installed, update with:

        Update-Module -Name Microsoft.Online.SharePoint.PowerShell

    For PowerShell 7, you may need to import with compatibility mode:

        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell

    The script requires SharePoint admin permissions to enumerate all site collections.
    For sites where the connected account lacks access, a warning is logged and the site is skipped.
.LINK
    https://learn.microsoft.com/en-us/powershell/sharepoint/sharepoint-online/connect-sharepoint-online
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "One or more group display names to search for.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$GroupNames,

    [Parameter(Mandatory = $true, HelpMessage = "SharePoint Online admin center URL (e.g. https://contoso-admin.sharepoint.com).")]
    [ValidatePattern('^https://.+-admin\.sharepoint\.com$')]
    [string]$AdminUrl,

    [Parameter(Mandatory = $false, HelpMessage = "Output directory for JSON export.")]
    [string]$OutputDirectory = "C:\Reports\SharePoint_Exports",

    [Parameter(Mandatory = $false, HelpMessage = "Include OneDrive for Business personal sites in the scan.")]
    [switch]$IncludeOneDriveSites
)

#region Prerequisites
# ---------------------------------------------------------------------------
# Module checks
# ---------------------------------------------------------------------------
$ModuleName = 'Microsoft.Online.SharePoint.PowerShell'
if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
    Write-Host "ERROR: Missing required module: $ModuleName" -ForegroundColor Red
    Write-Host "   Install with: Install-Module $ModuleName -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Import module - use compatibility mode for PS7
if ($PSVersionTable.PSVersion.Major -ge 7) {
    try {
        Import-Module $ModuleName -UseWindowsPowerShell -ErrorAction Stop
    }
    catch {
        Write-Host "ERROR: Failed to import $ModuleName in compatibility mode: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
else {
    Import-Module $ModuleName -ErrorAction Stop
}

# Output directory
if (!(Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
        Write-Host "OK: Created output directory: $OutputDirectory" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Cannot create output directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
#endregion

#region Connection
# ---------------------------------------------------------------------------
# Connect to SharePoint Online Admin
# ---------------------------------------------------------------------------
try {
    Write-Host "Connecting to SharePoint Online Admin ($AdminUrl)..." -ForegroundColor Yellow
    Connect-SPOService -Url $AdminUrl -ErrorAction Stop
    Write-Host "OK: Connected to SharePoint Online Admin" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to connect to SharePoint Online: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
#endregion

#region Enumerate Sites
# ---------------------------------------------------------------------------
# Get all site collections
# ---------------------------------------------------------------------------
try {
    Write-Host "Enumerating site collections..." -ForegroundColor Yellow
    $allSites = Get-SPOSite -Limit All -ErrorAction Stop
    if (-not $IncludeOneDriveSites) {
        $allSites = $allSites | Where-Object { $_.Url -notlike "*-my.sharepoint.com/personal/*" }
    }
    Write-Host "OK: Found $($allSites.Count) site collection(s) to scan." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: Failed to enumerate site collections: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
#endregion

#region Scan Sites
# ---------------------------------------------------------------------------
# Check each site for target group membership
# Uses Get-SPOUser to resolve GUIDs in site group Users lists to display names
# ---------------------------------------------------------------------------
$Results = @()
$SiteIndex = 0
$ErrorCount = 0

Write-Host "`nSearching for group(s): $($GroupNames -join ', ')`n" -ForegroundColor Cyan

foreach ($site in $allSites) {
    $SiteIndex++
    $pctComplete = [math]::Round(($SiteIndex / $allSites.Count) * 100)
    Write-Progress -Activity "Scanning SharePoint sites" -Status "$SiteIndex of $($allSites.Count): $($site.Url)" -PercentComplete $pctComplete

    # Get all SharePoint groups for this site
    try {
        $siteGroups = Get-SPOSiteGroup -Site $site.Url -ErrorAction Stop
    }
    catch {
        Write-Host "WARNING: Skipping $($site.Url) - $($_.Exception.Message)" -ForegroundColor Yellow
        $ErrorCount++
        continue
    }

    # Build a GUID-to-DisplayName lookup using Get-SPOUser for this site
    $UserLookup = @{}
    try {
        $siteUsers = Get-SPOUser -Site $site.Url -Limit All -ErrorAction Stop
        foreach ($u in $siteUsers) {
            # LoginName may be a GUID, a claim string containing a GUID, or an email
            $UserLookup[$u.LoginName] = $u.DisplayName
        }
    }
    catch {
        Write-Verbose "Could not enumerate users for $($site.Url): $($_.Exception.Message)"
    }

    $SiteMemberships = @()

    foreach ($spGroup in $siteGroups) {
        $permLevel = ($spGroup.Roles -join ', ')
        if ([string]::IsNullOrWhiteSpace($permLevel)) {
            $permLevel = 'None'
        }

        foreach ($userEntry in $spGroup.Users) {
            # Resolve the GUID/login to a display name via our lookup
            $displayName = $UserLookup[$userEntry]
            if (-not $displayName) {
                # Try matching as a substring (GUIDs may appear inside claim strings)
                $matchedKey = $UserLookup.Keys | Where-Object { $_ -like "*$userEntry*" } | Select-Object -First 1
                if ($matchedKey) {
                    $displayName = $UserLookup[$matchedKey]
                }
            }

            foreach ($targetGroup in $GroupNames) {
                # Match resolved display name or raw login against target group name
                if (($displayName -and $displayName -like "*$targetGroup*") -or
                    ($userEntry -like "*$targetGroup*")) {
                    $SiteMemberships += [PSCustomObject]@{
                        SharePointGroup = $spGroup.Title
                        PermissionLevel = $permLevel
                        MatchedUser     = $userEntry
                        DisplayName     = if ($displayName) { $displayName } else { $userEntry }
                        SearchedFor     = $targetGroup
                        MatchType       = "SharePointGroupMember"
                    }
                }
            }
        }
    }

    if ($SiteMemberships.Count -gt 0) {
        $matchedGroupNames = ($SiteMemberships | Select-Object -ExpandProperty SearchedFor -Unique)

        $Results += [PSCustomObject]@{
            SiteUrl     = $site.Url
            SiteTitle   = $site.Title
            Template    = $site.Template
            GroupsFound = $matchedGroupNames
            Memberships = $SiteMemberships
        }

        Write-Host "  OK: $($site.Title) - Found $($SiteMemberships.Count) membership(s)" -ForegroundColor Green
    }
}

Write-Progress -Activity "Scanning SharePoint sites" -Completed
#endregion

#region Export
# ---------------------------------------------------------------------------
# Build output and export to JSON
# ---------------------------------------------------------------------------
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$OutputFile = Join-Path $OutputDirectory "SharePoint_GroupMembership_$Timestamp.json"

$ExportObject = [PSCustomObject]@{
    GeneratedDate     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    SearchedGroups    = $GroupNames
    TotalSitesScanned = $allSites.Count
    SitesWithMatches  = $Results.Count
    SitesSkipped      = $ErrorCount
    Results           = $Results
}

try {
    $ExportObject | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8 -ErrorAction Stop
    Write-Host "`nOK: Results exported to: $OutputFile" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to export JSON: $($_.Exception.Message)" -ForegroundColor Red
}
#endregion

#region Summary
# ---------------------------------------------------------------------------
$Separator = "=" * 70
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "SHAREPOINT GROUP MEMBERSHIP SCAN SUMMARY" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host "Groups searched:       $($GroupNames.Count) ($($GroupNames -join ', '))" -ForegroundColor White
Write-Host "Total sites scanned:   $($allSites.Count)" -ForegroundColor White
Write-Host "Sites with matches:    $($Results.Count)" -ForegroundColor $(if ($Results.Count -gt 0) { 'Green' } else { 'Yellow' })
Write-Host "Sites skipped/errors:  $ErrorCount" -ForegroundColor $(if ($ErrorCount -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "Output file:           $OutputFile" -ForegroundColor White
Write-Host $Separator -ForegroundColor Cyan

if ($Results.Count -gt 0) {
    Write-Host "`nSites where groups were found:" -ForegroundColor White
    foreach ($r in $Results) {
        Write-Host "  - $($r.SiteTitle) ($($r.SiteUrl))" -ForegroundColor White
        foreach ($m in $r.Memberships) {
            Write-Host "      > $($m.SharePointGroup) ($($m.PermissionLevel)) [$($m.MatchedUser)]" -ForegroundColor Gray
        }
    }
}
else {
    Write-Host "`nWARNING: No group memberships found across scanned sites." -ForegroundColor Yellow
}
#endregion

# Disconnect
try {
    Disconnect-SPOService -ErrorAction SilentlyContinue
}
catch {
    # Non-critical
}
