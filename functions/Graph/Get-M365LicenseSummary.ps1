<#
.SYNOPSIS
    Returns a clean summary of Microsoft 365 license SKUs assigned vs.
    available across the connected tenant.

.DESCRIPTION
    Dot-source this file to load the Get-M365LicenseSummary function into
    your session (or add it to a module). Calls Get-MgSubscribedSku and
    reshapes the result into a friendly per-SKU summary (assigned, available
    consumed units, total, and percent used), with an option to translate
    cryptic SKU part numbers (e.g. "SPE_E3") to friendly display names using
    a small built-in lookup table. Useful for the license-utilization check
    you end up doing at the start of almost every tenant review.

.PARAMETER FriendlyNames
    Translate known SkuPartNumber values to a friendly product name in a
    FriendlyName column (falls back to the raw SkuPartNumber for anything
    not in the built-in lookup table).

.PARAMETER IncludeZeroAssigned
    Include SKUs with zero assigned licenses (excluded by default to keep
    the summary focused on what's actually in use).

.EXAMPLE
    . .\Get-M365LicenseSummary.ps1
    Get-M365LicenseSummary -FriendlyNames | Format-Table -AutoSize

.EXAMPLE
    Get-M365LicenseSummary | Where-Object { $_.PercentUsed -ge 90 }

.EXAMPLE
    Get-M365LicenseSummary -IncludeZeroAssigned | Export-Csv .\Licenses.csv -NoTypeInformation

.NOTES
    Requires an active Microsoft Graph connection with at least the
    Organization.Read.All (or equivalent) scope, and the
    Microsoft.Graph.Identity.DirectoryManagement module for
    Get-MgSubscribedSku. See Connect-GraphWithScopes in this repo.
#>

function Get-M365LicenseSummary {
    [CmdletBinding()]
    param(
        [switch] $FriendlyNames,

        [switch] $IncludeZeroAssigned
    )

    if (-not (Get-Command -Name Get-MgSubscribedSku -ErrorAction SilentlyContinue)) {
        throw "Get-M365LicenseSummary: Get-MgSubscribedSku is not available. Install/import Microsoft.Graph.Identity.DirectoryManagement and run Connect-MgGraph (scope: Organization.Read.All) first."
    }

    # Small, non-exhaustive lookup of common SKU part numbers -> friendly names.
    # Extend this table as needed; unmapped SKUs just show their raw part number.
    $skuFriendlyMap = @{
        "SPE_E3"                 = "Microsoft 365 E3"
        "SPE_E5"                 = "Microsoft 365 E5"
        "ENTERPRISEPACK"         = "Office 365 E3"
        "ENTERPRISEPREMIUM"      = "Office 365 E5"
        "STANDARDPACK"           = "Office 365 E1"
        "O365_BUSINESS_PREMIUM"  = "Microsoft 365 Business Standard"
        "SPB"                    = "Microsoft 365 Business Premium"
        "O365_BUSINESS_ESSENTIALS" = "Microsoft 365 Business Basic"
        "EMS"                    = "Enterprise Mobility + Security E3"
        "EMSPREMIUM"             = "Enterprise Mobility + Security E5"
        "FLOW_FREE"              = "Power Automate Free"
        "POWER_BI_STANDARD"      = "Power BI (free)"
        "POWER_BI_PRO"           = "Power BI Pro"
        "TEAMS_EXPLORATORY"      = "Teams Exploratory"
        "AAD_PREMIUM"            = "Azure AD Premium P1"
        "AAD_PREMIUM_P2"         = "Azure AD Premium P2"
    }

    try {
        $skus = Get-MgSubscribedSku -All -ErrorAction Stop
    }
    catch {
        throw "Get-M365LicenseSummary: Get-MgSubscribedSku failed - $($_.Exception.Message)"
    }

    $summary = foreach ($sku in $skus) {
        $assigned = $sku.ConsumedUnits
        $total = $sku.PrepaidUnits.Enabled
        $available = $total - $assigned

        if (-not $IncludeZeroAssigned -and $assigned -eq 0) {
            continue
        }

        $percentUsed = if ($total -gt 0) { [math]::Round(($assigned / $total) * 100, 1) } else { 0 }

        $entry = [ordered]@{
            SkuPartNumber = $sku.SkuPartNumber
            SkuId         = $sku.SkuId
            Assigned      = $assigned
            Available     = $available
            Total         = $total
            PercentUsed   = $percentUsed
        }

        if ($FriendlyNames) {
            $friendly = $skuFriendlyMap[$sku.SkuPartNumber]
            $entry["FriendlyName"] = if ($friendly) { $friendly } else { $sku.SkuPartNumber }
        }

        [PSCustomObject]$entry
    }

    return $summary | Sort-Object -Property Assigned -Descending
}
