<#
.SYNOPSIS
    Exports root site permissions and all items with broken inheritance across SharePoint Online.
.DESCRIPTION
    Connects to every SharePoint Online site collection using PnP PowerShell with certificate-based
    (PFX) authentication. For each site, the script:

    1. Exports the root web role assignments (site-level permissions)
    2. Recursively scans all document libraries for folders and files that have had
       permission inheritance broken (unique permissions)
    3. For each item with broken inheritance, captures the role assignments

    Results are exported to timestamped CSV files:
    - Root permissions:       SharePoint_RootPermissions_{timestamp}.csv
    - Broken inheritance:     SharePoint_BrokenInheritance_{timestamp}.csv

    The script uses app-only authentication via an Azure AD app registration with a PFX certificate,
    which avoids interactive login and supports unattended execution.

    Key features:
    - Certificate-based app-only auth (no user interaction required)
    - Scans all site collections or a filtered subset
    - Identifies broken inheritance at folder and file level
    - Captures full role assignment details (principal, role)
    - Progress tracking with colored console output
    - Error resilience - skips inaccessible sites and continues
.PARAMETER CertificatePath
    Full path to the PFX certificate file used for app-only authentication.
.PARAMETER ClientId
    Azure AD App Registration Application (Client) ID.
.PARAMETER Tenant
    Tenant identifier (e.g. contoso.onmicrosoft.com or tenant GUID).
.PARAMETER AdminUrl
    SharePoint Online admin center URL (e.g. https://contoso-admin.sharepoint.com).
    Used to enumerate all site collections.
.PARAMETER OutputDirectory
    Directory for CSV exports. Defaults to C:\Reports\SharePoint_Exports.
.PARAMETER IncludeOneDriveSites
    Include OneDrive for Business personal sites in the scan. Off by default.
.PARAMETER ExcludeSystemLists
    Exclude system libraries (Style Library, Form Templates, Site Assets, etc.).
    Enabled by default.
.EXAMPLE
    .\Get-SharePointBrokenInheritance.ps1 -CertificatePath "C:\Certs\PnP.pfx" -ClientId "caddf9cb-6667-4f9d-9eca-5f29d9d5dac1" -Tenant "contoso.onmicrosoft.com" -AdminUrl "https://contoso-admin.sharepoint.com"
    Scans all SharePoint sites and exports root permissions and broken inheritance to the default output directory.
.EXAMPLE
    .\Get-SharePointBrokenInheritance.ps1 -CertificatePath "C:\Certs\PnP.pfx" -ClientId "caddf9cb-6667-4f9d-9eca-5f29d9d5dac1" -Tenant "contoso.onmicrosoft.com" -AdminUrl "https://contoso-admin.sharepoint.com" -OutputDirectory "D:\Exports" -IncludeOneDriveSites
    Includes OneDrive personal sites and exports to a custom directory.
.NOTES
    Author: W. Ford
    Date: 2026-04-13
    Version: 1.0

    Requirements:
    - PnP.PowerShell module (Install-Module PnP.PowerShell -Scope CurrentUser)
    - Azure AD App Registration with Sites.FullControl.All application permission
    - PFX certificate uploaded to the app registration
    - PowerShell 5.1 or 7+

    Performance Note:
    Scanning large tenants with many sites and deeply nested libraries can take significant time.
    The script processes libraries iteratively to manage memory usage.
.LINK
    https://pnp.github.io/powershell/cmdlets/Connect-PnPOnline.html
.LINK
    https://learn.microsoft.com/en-us/sharepoint/dev/solution-guidance/security-apponly-azuread
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Full path to the PFX certificate file.")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CertificatePath,

    [Parameter(Mandatory = $true, HelpMessage = "Azure AD App Registration Client ID.")]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter(Mandatory = $true, HelpMessage = "Tenant identifier (e.g. contoso.onmicrosoft.com).")]
    [ValidateNotNullOrEmpty()]
    [string]$Tenant,

    [Parameter(Mandatory = $true, HelpMessage = "SharePoint Online admin URL (e.g. https://contoso-admin.sharepoint.com).")]
    [ValidatePattern('^https://.+-admin\.sharepoint\.com$')]
    [string]$AdminUrl,

    [Parameter(Mandatory = $false, HelpMessage = "Output directory for CSV exports.")]
    [string]$OutputDirectory = "C:\Reports\SharePoint_Exports",

    [Parameter(Mandatory = $false, HelpMessage = "Include OneDrive for Business personal sites.")]
    [switch]$IncludeOneDriveSites,

    [Parameter(Mandatory = $false, HelpMessage = "Exclude system libraries from scanning.")]
    [bool]$ExcludeSystemLists = $true
)

#region Prerequisites
# ---------------------------------------------------------------------------
$StartTime = Get-Date
$ErrorCount = 0
$WarningCount = 0
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

# System libraries to skip
$SystemLists = @(
    "Style Library", "Form Templates", "Site Assets", "Site Pages",
    "appdata", "appfiles", "Composed Looks", "Content type publishing error log",
    "List Template Gallery", "Master Page Gallery", "Solution Gallery",
    "Theme Gallery", "TaxonomyHiddenList", "Web Part Gallery",
    "Converted Forms", "Maintenance Log Library", "_catalogs"
)

# Module check
$ModuleName = 'PnP.PowerShell'
if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
    Write-Host "❌ Required module '$ModuleName' not installed." -ForegroundColor Red
    Write-Host "   Install with: Install-Module $ModuleName -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}
else {
    Write-Host "✅ Module $ModuleName is available" -ForegroundColor Green
}

# Output directory
if (!(Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
        Write-Host "✅ Created output directory: $OutputDirectory" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Cannot create output directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

$RootPermissionsFile = Join-Path $OutputDirectory "SharePoint_RootPermissions_$Timestamp.csv"
$BrokenInheritanceFile = Join-Path $OutputDirectory "SharePoint_BrokenInheritance_$Timestamp.csv"
#endregion

#region Helper Functions
# ---------------------------------------------------------------------------
function Get-RoleAssignmentDetails {
    <#
    .SYNOPSIS
        Extracts role assignment info from a SecurableObject into a flat list.
    #>
    param(
        [Parameter(Mandatory)]$RoleAssignments,
        [string]$SiteUrl,
        [string]$ItemType,
        [string]$ItemPath
    )

    $results = @()
    foreach ($ra in $RoleAssignments) {
        $principal = $ra.Member.Title
        $principalType = $ra.Member.PrincipalType
        $roles = ($ra.RoleDefinitionBindings | Where-Object { $_.Name -ne "Limited Access" } |
            Select-Object -ExpandProperty Name) -join '; '

        if ([string]::IsNullOrWhiteSpace($roles)) { continue }

        $results += [PSCustomObject]@{
            SiteUrl       = $SiteUrl
            ItemType      = $ItemType
            ItemPath      = $ItemPath
            Principal     = $principal
            PrincipalType = $principalType
            Roles         = $roles
        }
    }
    return $results
}

function Get-ListItemsBrokenInheritance {
    <#
    .SYNOPSIS
        Scans a document library for items with broken (unique) permissions.
    #>
    param(
        [Parameter(Mandatory)][string]$SiteUrl,
        [Parameter(Mandatory)]$List
    )

    $results = @()
    $listTitle = $List.Title
    $pageSize = 2000
    $position = $null

    do {
        $camlQuery = "<View Scope='RecursiveAll'><RowLimit>$pageSize</RowLimit></View>"
        try {
            $items = Get-PnPListItem -List $listTitle -PageSize $pageSize -Query $camlQuery -ErrorAction Stop
        }
        catch {
            Write-Host "  ⚠️  Error reading items from '$listTitle': $($_.Exception.Message)" -ForegroundColor Yellow
            $script:WarningCount++
            return $results
        }

        foreach ($item in $items) {
            # Check if inheritance is broken
            $hasUniquePerms = $false
            try {
                $hasUniquePerms = Get-PnPProperty -ClientObject $item -Property "HasUniqueRoleAssignments" -ErrorAction Stop
            }
            catch {
                continue
            }

            if ($hasUniquePerms) {
                $itemType = if ($item.FileSystemObjectType -eq "Folder") { "Folder" } else { "File" }
                $itemPath = $item.FieldValues["FileRef"]

                try {
                    $roleAssignments = Get-PnPProperty -ClientObject $item -Property "RoleAssignments" -ErrorAction Stop
                    foreach ($ra in $roleAssignments) {
                        Get-PnPProperty -ClientObject $ra -Property "Member", "RoleDefinitionBindings" -ErrorAction Stop | Out-Null
                    }

                    $details = Get-RoleAssignmentDetails -RoleAssignments $roleAssignments `
                        -SiteUrl $SiteUrl -ItemType $itemType -ItemPath $itemPath

                    if ($details) {
                        $results += $details
                    }
                }
                catch {
                    $results += [PSCustomObject]@{
                        SiteUrl       = $SiteUrl
                        ItemType      = $itemType
                        ItemPath      = $itemPath
                        Principal     = "ERROR: $($_.Exception.Message)"
                        PrincipalType = ""
                        Roles         = ""
                    }
                    $script:ErrorCount++
                }
            }
        }

        $position = $null  # PnP handles paging internally with -PageSize
    } while ($false)

    return $results
}
#endregion

#region Connect & Enumerate Sites
# ---------------------------------------------------------------------------
# Connect to admin site to enumerate all site collections
# ---------------------------------------------------------------------------
try {
    Write-Host "`nConnecting to SharePoint Admin ($AdminUrl)..." -ForegroundColor Yellow
    Connect-PnPOnline -Url $AdminUrl -ClientId $ClientId -Tenant $Tenant -CertificatePath $CertificatePath -ErrorAction Stop
    Write-Host "✅ Connected to SharePoint Admin" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to connect to SharePoint Admin: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

try {
    Write-Host "Enumerating site collections..." -ForegroundColor Yellow
    $allSites = Get-PnPTenantSite -ErrorAction Stop

    if (-not $IncludeOneDriveSites) {
        $allSites = $allSites | Where-Object { $_.Url -notlike "*-my.sharepoint.com/personal/*" }
    }

    Write-Host "✅ Found $($allSites.Count) site collection(s) to scan" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ Failed to enumerate site collections: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
#endregion

#region Process Sites
# ---------------------------------------------------------------------------
$AllRootPermissions = @()
$AllBrokenInheritance = @()
$SiteIndex = 0

foreach ($site in $allSites) {
    $SiteIndex++
    $siteUrl = $site.Url
    $pctComplete = [math]::Round(($SiteIndex / $allSites.Count) * 100)
    Write-Progress -Activity "Scanning SharePoint sites" -Status "$SiteIndex of $($allSites.Count): $siteUrl" -PercentComplete $pctComplete

    Write-Host "`n[$SiteIndex/$($allSites.Count)] Processing: $siteUrl" -ForegroundColor Cyan

    # Connect to individual site
    try {
        Connect-PnPOnline -Url $siteUrl -ClientId $ClientId -Tenant $Tenant -CertificatePath $CertificatePath -ErrorAction Stop
    }
    catch {
        Write-Host "  ❌ Cannot connect: $($_.Exception.Message)" -ForegroundColor Red
        $ErrorCount++
        continue
    }

    #region Root Permissions
    try {
        $web = Get-PnPWeb -Includes RoleAssignments -ErrorAction Stop
        foreach ($ra in $web.RoleAssignments) {
            Get-PnPProperty -ClientObject $ra -Property "Member", "RoleDefinitionBindings" -ErrorAction Stop | Out-Null
        }

        $rootPerms = Get-RoleAssignmentDetails -RoleAssignments $web.RoleAssignments `
            -SiteUrl $siteUrl -ItemType "RootWeb" -ItemPath "/"

        if ($rootPerms) {
            $AllRootPermissions += $rootPerms
            Write-Host "  ✅ Root permissions: $($rootPerms.Count) assignment(s)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ❌ Error reading root permissions: $($_.Exception.Message)" -ForegroundColor Red
        $ErrorCount++
    }
    #endregion

    #region Scan Libraries for Broken Inheritance
    try {
        $lists = Get-PnPList -ErrorAction Stop | Where-Object {
            $_.BaseTemplate -eq 101 -and -not $_.Hidden
        }

        if ($ExcludeSystemLists) {
            $lists = $lists | Where-Object { $_.Title -notin $SystemLists }
        }

        foreach ($list in $lists) {
            Write-Host "  📂 Scanning library: $($list.Title)" -ForegroundColor Yellow

            # Check if the library itself has broken inheritance
            try {
                $listHasUnique = Get-PnPProperty -ClientObject $list -Property "HasUniqueRoleAssignments" -ErrorAction Stop
                if ($listHasUnique) {
                    $listRoleAssignments = Get-PnPProperty -ClientObject $list -Property "RoleAssignments" -ErrorAction Stop
                    foreach ($ra in $listRoleAssignments) {
                        Get-PnPProperty -ClientObject $ra -Property "Member", "RoleDefinitionBindings" -ErrorAction Stop | Out-Null
                    }
                    $libraryPerms = Get-RoleAssignmentDetails -RoleAssignments $listRoleAssignments `
                        -SiteUrl $siteUrl -ItemType "Library" -ItemPath $list.RootFolder.ServerRelativeUrl
                    if ($libraryPerms) {
                        $AllBrokenInheritance += $libraryPerms
                        Write-Host "    ⚠️  Library has unique permissions ($($libraryPerms.Count) assignment(s))" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                Write-Host "    ⚠️  Could not check library permissions: $($_.Exception.Message)" -ForegroundColor Yellow
                $WarningCount++
            }

            # Scan items within the library
            $brokenItems = Get-ListItemsBrokenInheritance -SiteUrl $siteUrl -List $list
            if ($brokenItems) {
                $AllBrokenInheritance += $brokenItems
                $uniquePaths = ($brokenItems | Select-Object -ExpandProperty ItemPath -Unique).Count
                Write-Host "    ⚠️  Found $uniquePaths item(s) with broken inheritance" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "  ❌ Error scanning libraries: $($_.Exception.Message)" -ForegroundColor Red
        $ErrorCount++
    }
    #endregion
}

Write-Progress -Activity "Scanning SharePoint sites" -Completed
#endregion

#region Export Results
# ---------------------------------------------------------------------------
$Separator = "=" * 80

if ($AllRootPermissions.Count -gt 0) {
    $AllRootPermissions | Export-Csv -Path $RootPermissionsFile -NoTypeInformation -Encoding UTF8
    Write-Host "`n✅ Exported $($AllRootPermissions.Count) root permission entries to:" -ForegroundColor Green
    Write-Host "   $RootPermissionsFile" -ForegroundColor White
}
else {
    Write-Host "`n⚠️  No root permissions captured." -ForegroundColor Yellow
}

if ($AllBrokenInheritance.Count -gt 0) {
    $AllBrokenInheritance | Export-Csv -Path $BrokenInheritanceFile -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Exported $($AllBrokenInheritance.Count) broken inheritance entries to:" -ForegroundColor Green
    Write-Host "   $BrokenInheritanceFile" -ForegroundColor White
}
else {
    Write-Host "✅ No broken inheritance found across scanned sites." -ForegroundColor Green
}
#endregion

#region Summary
# ---------------------------------------------------------------------------
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "SHAREPOINT BROKEN INHERITANCE SCAN COMPLETE" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host "Sites scanned:           $($allSites.Count)" -ForegroundColor White
Write-Host "Root permission entries:  $($AllRootPermissions.Count)" -ForegroundColor White
Write-Host "Broken inheritance items: $($AllBrokenInheritance.Count)" -ForegroundColor White
Write-Host "Duration:                $($Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
Write-Host "Errors: $ErrorCount | Warnings: $WarningCount" -ForegroundColor $(if ($ErrorCount -gt 0) { 'Red' } else { 'Green' })
Write-Host $Separator -ForegroundColor Cyan
#endregion

# Cleanup - disconnect
try {
    Disconnect-PnPOnline -ErrorAction SilentlyContinue
}
catch {
    # Silently ignore disconnect errors
}
