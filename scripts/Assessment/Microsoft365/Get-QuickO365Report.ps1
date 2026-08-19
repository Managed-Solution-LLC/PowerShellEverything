<#
.SYNOPSIS
    Quick Office 365 assessment for local PowerShell - simplified execution.
.DESCRIPTION
    Comprehensive Office 365 assessment optimized for local PowerShell.
    
    Collects:
    - Mailbox statistics with archive information
    - OneDrive sites and storage
    - SharePoint sites with storage and permissions
    - Microsoft 365 Groups with memberships
    - Teams sites with owners and members
    
    Uses Exchange Online Management Shell and SharePoint Online Management Shell.
.PARAMETER TenantDomain
    SharePoint admin domain (e.g., 'contoso' for contoso-admin.sharepoint.com).
    Auto-detected if not specified.
.PARAMETER OutputDirectory
    Custom output directory. Default is Documents\O365Reports_<timestamp>.
    
.PARAMETER SkipSharePoint
    Skip SharePoint Online and OneDrive collection. Use this if you encounter
    authentication issues with SharePoint or don't have SharePoint admin permissions.
    
.PARAMETER SkipLicensing
    Skip MSOnline licensing data collection. Use this if MSOnline authentication fails
    due to MFA or conditional access policies.
    
.EXAMPLE
    .\Get-QuickO365Report.ps1 -TenantDomain "contoso"
    
.EXAMPLE
    .\Get-QuickO365Report.ps1 -SkipSharePoint -SkipLicensing
    
    Collects only Exchange/mailbox data, skipping SharePoint and licensing modules
    that may have authentication issues.
    
.NOTES
    Author: W. Ford (Managed Solution LLC)
    Date: 2025-12-23
    Version: 2.0 - Added Teams, Groups, Memberships, and SharePoint permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="SharePoint admin domain (e.g., 'contoso' for contoso-admin.sharepoint.com)")]
    [string]$TenantDomain,
    
    [Parameter(Mandatory=$false, HelpMessage="Custom output directory")]
    [string]$OutputDirectory = "$env:USERPROFILE\Documents\O365Report_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
    
    [Parameter(Mandatory=$false, HelpMessage="Skip SharePoint/OneDrive collection")]
    [switch]$SkipSharePoint,
    
    [Parameter(Mandatory=$false, HelpMessage="Skip MSOnline licensing data collection")]
    [switch]$SkipLicensing
)

$ErrorActionPreference = 'Stop'
$StartTime = Get-Date

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  OFFICE 365 QUICK ASSESSMENT" -ForegroundColor Cyan
Write-Host "  Local PowerShell Edition" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Write-Host "[OK] Output directory: $OutputDirectory" -ForegroundColor Green

# Install modules
Write-Host ""
Write-Host "[INFO] Checking required modules..." -ForegroundColor Cyan
$modules = @(
    'ExchangeOnlineManagement',
    'Microsoft.Online.SharePoint.PowerShell',
    'MSOnline'
)

foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "   Installing $module..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop | Out-Null
            Write-Host "   [OK] $module installed" -ForegroundColor Green
        }
        catch {
            Write-Host "   [ERROR] Failed to install $module" -ForegroundColor Red
            Write-Host "   You may need to run as Administrator" -ForegroundColor Yellow
            exit 1
        }
    }
    else {
        Write-Host "   [OK] $module ready" -ForegroundColor Green
    }
}

# Connect to Exchange
Write-Host ""
Write-Host "[INFO] Connecting to Exchange Online..." -ForegroundColor Cyan
Write-Host "   (Sign-in prompt will appear)" -ForegroundColor Yellow
try {
    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    $null = Get-OrganizationConfig -ErrorAction Stop
    Write-Host "[OK] Connected to Exchange Online" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to connect to Exchange Online" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

# Auto-detect tenant if not provided
if ([string]::IsNullOrEmpty($TenantDomain)) {
    Write-Host ""
    Write-Host "[INFO] Detecting tenant domain..." -ForegroundColor Cyan
    $orgConfig = Get-OrganizationConfig
    $TenantDomain = ($orgConfig.Identity -split '\.')[0]
    Write-Host "[OK] Detected tenant: $TenantDomain" -ForegroundColor Green
}

# Connect to MSOnline (for licensing data)
$msolConnected = $false

if ($SkipLicensing) {
    Write-Host ""
    Write-Host "[SKIP] Skipping MSOnline licensing collection (per -SkipLicensing parameter)" -ForegroundColor Yellow
}
else {
    Write-Host ""
    Write-Host "[INFO] Connecting to MSOnline..." -ForegroundColor Cyan
    Write-Host "   (Use same credentials as Exchange)" -ForegroundColor Yellow
    Write-Host "   Note: MSOnline module has authentication limitations with MFA/modern auth" -ForegroundColor Gray

    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Import-Module MSOnline -UseWindowsPowerShell -ErrorAction Stop -WarningAction SilentlyContinue
        } else {
            Import-Module MSOnline -ErrorAction Stop
        }
        Connect-MsolService -ErrorAction Stop
        Write-Host "[OK] Connected to MSOnline" -ForegroundColor Green
        $msolConnected = $true
    }
    catch {
        Write-Host "[WARNING] Failed to connect to MSOnline" -ForegroundColor Yellow
        Write-Host "   License data will not be collected" -ForegroundColor Yellow
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
        
        if ($_.Exception.Message -like "*Negotiate*" -or $_.Exception.Message -like "*forbidden*") {
            Write-Host "" -ForegroundColor Yellow
            Write-Host "   Troubleshooting: This error often occurs with MFA/Conditional Access" -ForegroundColor Yellow
            Write-Host "   - MSOnline module doesn't fully support modern authentication" -ForegroundColor Yellow
            Write-Host "   - Try running from a non-MFA admin account if available" -ForegroundColor Yellow
            Write-Host "   - Or use app password if your org allows" -ForegroundColor Yellow
            Write-Host "   - Or rerun with: -SkipLicensing to skip this module" -ForegroundColor Yellow
            Write-Host "   - Assessment will continue without license details" -ForegroundColor Yellow
        }
    }
}

# Collect license information if connected
$userLicenses = @{}
if ($msolConnected) {
    Write-Host ""
    Write-Host "[INFO] Collecting license information..." -ForegroundColor Cyan
    try {
        $msolUsers = Get-MsolUser -All -ErrorAction Stop
        Write-Host "   Found $($msolUsers.Count) users" -ForegroundColor Yellow
        
        foreach ($user in $msolUsers) {
            $licenseNames = @()
            foreach ($license in $user.Licenses) {
                if ($license.AccountSkuId) {
                    $licenseNames += ($license.AccountSkuId -replace '^.*:', '')
                }
            }
            if ($licenseNames.Count -gt 0) {
                $userLicenses[$user.UserPrincipalName] = $licenseNames -join '; '
            } else {
                $userLicenses[$user.UserPrincipalName] = "No License"
            }
        }
        Write-Host "[OK] Collected license data for $($userLicenses.Count) users" -ForegroundColor Green
    }
    catch {
        Write-Host "[WARNING] Error collecting licenses: $($_.Exception.Message)" -ForegroundColor Yellow
        $msolConnected = $false
    }
}

# Connect to SharePoint Online
$spoConnected = $false

if ($SkipSharePoint) {
    Write-Host ""
    Write-Host "[SKIP] Skipping SharePoint Online collection (per -SkipSharePoint parameter)" -ForegroundColor Yellow
}
else {
    Write-Host ""
    Write-Host "[INFO] Connecting to SharePoint Online..." -ForegroundColor Cyan
    Write-Host "   (Sign-in prompt will appear)" -ForegroundColor Yellow

    $adminUrl = "https://$TenantDomain-admin.sharepoint.com"
    Write-Host "   Admin URL: $adminUrl" -ForegroundColor Gray

    try {
        Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -ErrorAction Stop
        
        # Try connecting with retry logic
        $maxRetries = 2
        $retryCount = 0
        $connected = $false
        
        while (-not $connected -and $retryCount -lt $maxRetries) {
            try {
                if ($retryCount -gt 0) {
                    Write-Host "   Retry attempt $retryCount of $($maxRetries - 1)..." -ForegroundColor Yellow
                }
                Connect-SPOService -Url $adminUrl -ErrorAction Stop
                $connected = $true
                $spoConnected = $true
                Write-Host "[OK] Connected to SharePoint Online" -ForegroundColor Green
            }
            catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "   Connection failed, retrying..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
                else {
                    throw
                }
            }
        }
    }
    catch {
        Write-Host "[WARNING] Failed to connect to SharePoint Online" -ForegroundColor Yellow
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
        
        if ($_.Exception.Message -like "*401*" -or $_.Exception.Message -like "*Unauthorized*") {
            Write-Host "" -ForegroundColor Yellow
            Write-Host "   Troubleshooting - 401 Unauthorized:" -ForegroundColor Yellow
            Write-Host "   1. Verify tenant domain name is correct: '$TenantDomain'" -ForegroundColor Yellow
            Write-Host "      (Should match your SharePoint URL, e.g., 'contoso' for contoso.sharepoint.com)" -ForegroundColor Yellow
            Write-Host "   2. Ensure your account has SharePoint Administrator role" -ForegroundColor Yellow
            Write-Host "   3. Check if conditional access policies are blocking connection" -ForegroundColor Yellow
            Write-Host "   4. Try running: Connect-SPOService -Url $adminUrl" -ForegroundColor Yellow
            Write-Host "      manually to test authentication" -ForegroundColor Yellow
            Write-Host "   5. Or rerun with: -SkipSharePoint to skip SharePoint collection" -ForegroundColor Yellow
        }
        elseif ($_.Exception.Message -like "*not found*" -or $_.Exception.Message -like "*404*") {
            Write-Host "" -ForegroundColor Yellow
            Write-Host "   Troubleshooting - URL Not Found:" -ForegroundColor Yellow
            Write-Host "   The tenant domain '$TenantDomain' may be incorrect" -ForegroundColor Yellow
            Write-Host "   To find your SharePoint admin URL:" -ForegroundColor Yellow
            Write-Host "   1. Go to admin.microsoft.com" -ForegroundColor Yellow
            Write-Host "   2. Navigate to SharePoint admin center" -ForegroundColor Yellow
            Write-Host "   3. Note the URL format: https://YOURTENANT-admin.sharepoint.com" -ForegroundColor Yellow
            Write-Host "   4. Rerun script with: -TenantDomain 'YOURTENANT'" -ForegroundColor Yellow
        }
        
        Write-Host "" -ForegroundColor Yellow
        Write-Host "   Continuing with Exchange data only..." -ForegroundColor Yellow
    }
}

# Helper function for size conversion
function ConvertTo-GB {
    param([string]$Size)
    try {
        if ([string]::IsNullOrEmpty($Size) -or $Size -eq "Unlimited") { return 0 }
        $value = $Size.Split(" ")
        if ($value.Count -lt 2) { return 0 }
        switch($value[1]) {
            "GB" { return [Math]::Round([double]$value[0], 2) }
            "MB" { return [Math]::Round([double]$value[0] / 1024, 2) }
            "KB" { return [Math]::Round([double]$value[0] / 1024 / 1024, 2) }
            default { return 0 }
        }
    }
    catch { return 0 }
}

# Collect mailbox statistics
Write-Host ""
Write-Host "[INFO] Collecting mailbox statistics..." -ForegroundColor Cyan
$mailboxFile = Join-Path $OutputDirectory "Mailboxes.csv"

try {
    $mailboxes = Get-EXOMailbox -ResultSize Unlimited -ErrorAction Stop
    Write-Host "   Found $($mailboxes.Count) mailboxes" -ForegroundColor Yellow

    $mbResults = @()
    $mbErrors = 0
    $i = 0
    
    foreach ($mb in $mailboxes) {
        $i++
        Write-Progress -Activity "Collecting Mailboxes" -Status "$($mb.DisplayName)" -PercentComplete (($i/$mailboxes.Count)*100)
        
        try {
            $stats = Get-EXOMailboxStatistics -Identity $mb.UserPrincipalName -Properties LastUserActionTime,LastLogonTime -ErrorAction Stop -WarningAction SilentlyContinue
            
            # Parse sizes
            $totalGB = 0
            if ($null -ne $stats.TotalItemSize) {
                $sizeString = $stats.TotalItemSize.ToString()
                if (-not [string]::IsNullOrWhiteSpace($sizeString) -and $sizeString -ne '0') {
                    $parsedSize = $sizeString.Split("(")[0].Trim()
                    $totalGB = ConvertTo-GB -Size $parsedSize
                }
            }
            
            $deletedSizeGB = 0
            if ($null -ne $stats.TotalDeletedItemSize) {
                try {
                    $deletedSizeGB = ConvertTo-GB -Size $stats.TotalDeletedItemSize.ToString().Split('(')[0].Trim()
                } catch { $deletedSizeGB = 0 }
            }
            
            # Parse quotas
            $warningQuotaGB = "Unlimited"
            if ($null -ne $mb.IssueWarningQuota -and $mb.IssueWarningQuota.ToString() -ne "Unlimited") {
                try {
                    $warningQuotaGB = [Math]::Round((ConvertTo-GB -Size $mb.IssueWarningQuota.ToString().Split('(')[0].Trim()), 2)
                } catch { $warningQuotaGB = "Error" }
            }
            
            $maxMailboxSizeGB = "Unlimited"
            if ($null -ne $mb.ProhibitSendReceiveQuota -and $mb.ProhibitSendReceiveQuota.ToString() -ne "Unlimited") {
                try {
                    $maxMailboxSizeGB = [Math]::Round((ConvertTo-GB -Size $mb.ProhibitSendReceiveQuota.ToString().Split('(')[0].Trim()), 2)
                } catch { $maxMailboxSizeGB = "Error" }
            }
            
            $freeSpaceGB = "Unlimited"
            if ($maxMailboxSizeGB -ne "Unlimited" -and $maxMailboxSizeGB -ne "Error") {
                try { $freeSpaceGB = [Math]::Round($maxMailboxSizeGB - $totalGB, 2) }
                catch { $freeSpaceGB = "Error" }
            }
            
            # Archive stats
            $archiveSize = 0
            $archiveItemCount = 0
            
            if ($null -ne $mb.ArchiveDatabase) {
                try {
                    $archiveStats = Get-EXOMailboxStatistics -Identity $mb.UserPrincipalName -Archive -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                    if ($null -ne $archiveStats -and $null -ne $archiveStats.TotalItemSize) {
                        $archiveSize = ConvertTo-GB -Size $archiveStats.TotalItemSize.ToString().Split('(')[0].Trim()
                        $archiveItemCount = $archiveStats.ItemCount
                    }
                } catch { }
            }
            
            # Aliases
            $aliases = ""
            if ($mb.EmailAddresses) {
                $aliasList = $mb.EmailAddresses | Where-Object { $_ -like "smtp:*" -and $_ -notlike "smtp:$($mb.PrimarySmtpAddress)" } | ForEach-Object { $_.Replace("smtp:", "") }
                if ($aliasList) { $aliases = $aliasList -join "; " }
            }
            
            # Get license info
            $licenses = "Not Available"
            if ($msolConnected -and $userLicenses.ContainsKey($mb.UserPrincipalName)) {
                $licenses = $userLicenses[$mb.UserPrincipalName]
            }
            
            $mbResults += [PSCustomObject]@{
                DisplayName = $mb.DisplayName
                EmailAddress = $mb.PrimarySmtpAddress
                MailboxType = $mb.RecipientTypeDetails
                Licenses = $licenses
                LastUserActionTime = if ($stats.LastUserActionTime) { $stats.LastUserActionTime } elseif ($stats.LastLogonTime) { $stats.LastLogonTime } else { "Never" }
                TotalSizeGB = $totalGB
                DeletedItemsSizeGB = $deletedSizeGB
                ItemCount = $stats.ItemCount
                DeletedItemCount = $stats.DeletedItemCount
                WarningQuotaGB = $warningQuotaGB
                MaxMailboxSizeGB = $maxMailboxSizeGB
                FreeSpaceGB = $freeSpaceGB
                ArchiveSizeGB = $archiveSize
                ArchiveItemCount = $archiveItemCount
                Aliases = $aliases
            }
        }
        catch {
            $mbErrors++
            if ($mbErrors -le 5) {
                Write-Host "   [ERROR] Error processing $($mb.DisplayName)" -ForegroundColor Red
            }
        }
    }
    Write-Progress -Activity "Collecting Mailboxes" -Completed
    
    if ($mbErrors -gt 5) {
        Write-Host "   [WARNING] ... and $($mbErrors - 5) more errors" -ForegroundColor Yellow
    }
    
    if ($mbResults.Count -gt 0) {
        $mbResults | Export-Csv -Path $mailboxFile -NoTypeInformation -Encoding UTF8
        Write-Host "[OK] Exported $($mbResults.Count) mailboxes" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] No mailbox data collected" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[ERROR] Failed to collect mailbox data: $($_.Exception.Message)" -ForegroundColor Red
    $mbResults = @()
}

# Generate License Summary
if ($msolConnected) {
    Write-Host ""
    Write-Host "[INFO] Generating license summary..." -ForegroundColor Cyan
    $licenseFile = Join-Path $OutputDirectory "License_Summary.csv"
    
    try {
        $accountSkus = Get-MsolAccountSku -ErrorAction Stop
        $licenseReport = @()
        
        foreach ($sku in $accountSkus) {
            $skuName = $sku.AccountSkuId -replace '^.*:', ''
            $licenseReport += [PSCustomObject]@{
                LicenseName = $skuName
                TotalLicenses = $sku.ActiveUnits
                ConsumedLicenses = $sku.ConsumedUnits
                AvailableLicenses = $sku.ActiveUnits - $sku.ConsumedUnits
                WarningUnits = $sku.WarningUnits
                SuspendedUnits = $sku.SuspendedUnits
            }
        }
        
        if ($licenseReport.Count -gt 0) {
            $licenseReport | Export-Csv -Path $licenseFile -NoTypeInformation -Encoding UTF8
            Write-Host "[OK] Exported license summary for $($licenseReport.Count) license types" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[WARNING] Error generating license summary: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Collect OneDrive and SharePoint using SPO module
$odResults = @()
$spResults = @()

if ($spoConnected) {
    Write-Host ""
    Write-Host "[INFO] Collecting SharePoint and OneDrive sites..." -ForegroundColor Cyan
    
    try {
        # Get ALL sites including personal (OneDrive)
        $allSites = Get-SPOSite -IncludePersonalSite $true -Limit All -ErrorAction Stop
        Write-Host "   Found $($allSites.Count) total sites" -ForegroundColor Yellow
        
        # Split into OneDrive and SharePoint
        $odSites = @($allSites | Where-Object { $_.Url -like "*/personal/*" })
        $spSites = @($allSites | Where-Object { $_.Url -notlike "*/personal/*" })
        
        Write-Host "   OneDrive sites: $($odSites.Count)" -ForegroundColor Yellow
        Write-Host "   SharePoint sites: $($spSites.Count)" -ForegroundColor Yellow
        
        # Process OneDrive
        $oneDriveFile = Join-Path $OutputDirectory "OneDrive.csv"
        foreach ($site in $odSites) {
            $usedGB = [Math]::Round($site.StorageUsageCurrent / 1024, 2)
            $quotaGB = [Math]::Round($site.StorageQuota / 1024, 2)
            $percentUsed = if ($site.StorageQuota -gt 0) { [Math]::Round(($site.StorageUsageCurrent / $site.StorageQuota) * 100, 1) } else { 0 }
            
            $odResults += [PSCustomObject]@{
                Owner = $site.Owner
                Title = $site.Title
                URL = $site.Url
                UsedGB = $usedGB
                QuotaGB = $quotaGB
                PercentUsed = $percentUsed
                LastModified = $site.LastContentModifiedDate
                Status = $site.Status
            }
        }
        
        if ($odResults.Count -gt 0) {
            $odResults | Export-Csv -Path $oneDriveFile -NoTypeInformation -Encoding UTF8
            Write-Host "[OK] Exported $($odResults.Count) OneDrive sites" -ForegroundColor Green
        }
        
        # Process SharePoint
        $spFile = Join-Path $OutputDirectory "SharePoint.csv"
        foreach ($site in $spSites) {
            $usedGB = [Math]::Round($site.StorageUsageCurrent / 1024, 2)
            $quotaGB = [Math]::Round($site.StorageQuota / 1024, 2)
            $percentUsed = if ($site.StorageQuota -gt 0) { [Math]::Round(($site.StorageUsageCurrent / $site.StorageQuota) * 100, 1) } else { 0 }
            
            $spResults += [PSCustomObject]@{
                Title = $site.Title
                URL = $site.Url
                Owner = $site.Owner
                Template = $site.Template
                UsedGB = $usedGB
                QuotaGB = $quotaGB
                PercentUsed = $percentUsed
                LastModified = $site.LastContentModifiedDate
                Status = $site.Status
                SharingCapability = $site.SharingCapability
            }
        }
        
        if ($spResults.Count -gt 0) {
            $spResults | Export-Csv -Path $spFile -NoTypeInformation -Encoding UTF8
            Write-Host "[OK] Exported $($spResults.Count) SharePoint sites" -ForegroundColor Green
        }
        
        # Collect SharePoint Site Permissions
        Write-Host ""
        Write-Host "[INFO] Collecting SharePoint site permissions..." -ForegroundColor Cyan
        $permFile = Join-Path $OutputDirectory "SharePoint_Permissions.csv"
        $permResults = @()
        
        $i = 0
        foreach ($site in $spSites | Where-Object { $_.Template -notlike '*SPSPERS*' }) {
            $i++
            $statusMsg = if ($site.Title) { $site.Title } else { $site.Url }
            Write-Progress -Activity "Collecting Permissions" -Status $statusMsg -PercentComplete (($i/$spSites.Count)*100)
            
            try {
                $siteUsers = Get-SPOUser -Site $site.Url -ErrorAction SilentlyContinue
                foreach ($user in $siteUsers | Where-Object { $_.LoginName -notlike '*spo-grid-all-users*' }) {
                    $permResults += [PSCustomObject]@{
                        SiteTitle = $site.Title
                        SiteURL = $site.Url
                        UserName = $user.DisplayName
                        LoginName = $user.LoginName
                        IsSiteAdmin = $user.IsSiteAdmin
                        Groups = ($user.Groups -join '; ')
                    }
                }
            }
            catch {
                Write-Verbose "Error getting permissions for $($site.Url): $($_.Exception.Message)"
            }
        }
        Write-Progress -Activity "Collecting Permissions" -Completed
        
        if ($permResults.Count -gt 0) {
            $permResults | Export-Csv -Path $permFile -NoTypeInformation -Encoding UTF8
            Write-Host "[OK] Exported $($permResults.Count) permission entries" -ForegroundColor Green
        }
        
        # Collect Microsoft 365 Groups
        Write-Host ""
        Write-Host "[INFO] Collecting Microsoft 365 Groups..." -ForegroundColor Cyan
        $groupsFile = Join-Path $OutputDirectory "M365_Groups.csv"
        $groupResults = @()
        
        # Try multiple methods to get group sites
        Write-Host "   Checking for group sites..." -ForegroundColor Yellow
        
        # Method 1: Try GROUP#0 template
        $groups = @(Get-SPOSite -Template 'GROUP#0' -Limit All -ErrorAction SilentlyContinue)
        Write-Host "   Found $($groups.Count) sites with GROUP#0 template" -ForegroundColor Gray
        
        # Method 2: If no results, try filtering by URL pattern (groups typically contain /sites/)
        if ($groups.Count -eq 0) {
            Write-Host "   Trying alternative group detection..." -ForegroundColor Yellow
            $allSites = Get-SPOSite -Limit All -ErrorAction SilentlyContinue
            $groups = @($allSites | Where-Object { 
                $_.Url -match '/sites/' -and 
                $_.Template -like 'GROUP*' 
            })
            Write-Host "   Found $($groups.Count) potential group sites by URL pattern" -ForegroundColor Gray
        }
        
        # Method 3: Check for IsTeamsConnected property
        if ($groups.Count -eq 0) {
            Write-Host "   Checking all sites for Teams/Group connections..." -ForegroundColor Yellow
            $allSites = Get-SPOSite -Limit All -ErrorAction SilentlyContinue
            foreach ($site in $allSites) {
                try {
                    $siteDetail = Get-SPOSite -Identity $site.Url -Detailed -ErrorAction SilentlyContinue
                    if ($siteDetail.IsTeamsConnected -or $siteDetail.IsTeamsChannelConnected) {
                        $groups += $site
                    }
                }
                catch {
                    # Silent fail - just checking
                }
            }
            Write-Host "   Found $($groups.Count) Teams/Group-connected sites" -ForegroundColor Gray
        }
        
        foreach ($group in $groups) {
            $groupResults += [PSCustomObject]@{
                DisplayName = $group.Title
                URL = $group.Url
                Owner = $group.Owner
                Template = $group.Template
                Created = $group.TimeCreated
                LastModified = $group.LastContentModifiedDate
                StorageUsedGB = [Math]::Round($group.StorageUsageCurrent / 1024, 2)
                Status = $group.Status
                SharingCapability = $group.SharingCapability
            }
        }
        
        if ($groupResults.Count -gt 0) {
            $groupResults | Export-Csv -Path $groupsFile -NoTypeInformation -Encoding UTF8
            Write-Host "[OK] Exported $($groupResults.Count) Microsoft 365 Groups" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] No Microsoft 365 Groups found" -ForegroundColor Yellow
        }
        
        # Collect Group Memberships
        Write-Host ""
        Write-Host "[INFO] Collecting group memberships..." -ForegroundColor Cyan
        $membershipFile = Join-Path $OutputDirectory "Group_Memberships.csv"
        $membershipResults = @()
        
        $i = 0
        foreach ($group in $groups) {
            $i++
            $statusMsg = if ($group.Title) { $group.Title } else { $group.Url }
            Write-Progress -Activity "Collecting Memberships" -Status $statusMsg -PercentComplete (($i/$groups.Count)*100)
            
            try {
                $members = Get-SPOUser -Site $group.Url -ErrorAction SilentlyContinue
                foreach ($member in $members | Where-Object { $_.LoginName -notlike '*spo-grid-all-users*' }) {
                    $membershipResults += [PSCustomObject]@{
                        GroupName = $group.Title
                        GroupURL = $group.Url
                        MemberName = $member.DisplayName
                        MemberLogin = $member.LoginName
                        IsOwner = $member.IsSiteAdmin
                    }
                }
            }
            catch {
                Write-Verbose "Error getting members for $($group.Title): $($_.Exception.Message)"
            }
        }
        Write-Progress -Activity "Collecting Memberships" -Completed
        
        if ($membershipResults.Count -gt 0) {
            $membershipResults | Export-Csv -Path $membershipFile -NoTypeInformation -Encoding UTF8
            Write-Host "[OK] Exported $($membershipResults.Count) group membership entries" -ForegroundColor Green
        }
        
        # Collect Teams Sites (subset of Groups with Teams)
        Write-Host ""
        Write-Host "[INFO] Identifying Teams-connected sites..." -ForegroundColor Cyan
        $teamsFile = Join-Path $OutputDirectory "Teams_Sites.csv"
        $teamsResults = @()
        
        $teamsCount = 0
        foreach ($group in $groups) {
            # Check if Teams-enabled by getting detailed site info
            $isTeamsConnected = $false
            try {
                $siteFeatures = Get-SPOSite -Identity $group.Url -Detailed -ErrorAction SilentlyContinue
                $isTeamsConnected = $siteFeatures.IsTeamsConnected -or $siteFeatures.IsTeamsChannelConnected
                if ($isTeamsConnected) { $teamsCount++ }
            }
            catch {
                Write-Verbose "Error checking Teams integration for $($group.Url): $($_.Exception.Message)"
                # Fallback: check if template or URL indicates Teams
                if ($group.Template -like '*GROUP*' -or $group.Url -match '/teams-') {
                    $isTeamsConnected = $true
                    $teamsCount++
                }
            }
            
            $teamsResults += [PSCustomObject]@{
                TeamName = $group.Title
                URL = $group.Url
                Owner = $group.Owner
                Template = $group.Template
                Created = $group.TimeCreated
                LastActivity = $group.LastContentModifiedDate
                StorageUsedGB = [Math]::Round($group.StorageUsageCurrent / 1024, 2)
                HasTeamsIntegration = $isTeamsConnected
                Status = $group.Status
            }
        }
        
        if ($teamsResults.Count -gt 0) {
            $teamsResults | Export-Csv -Path $teamsFile -NoTypeInformation -Encoding UTF8
            Write-Host "[OK] Exported $($teamsResults.Count) group sites ($teamsCount Teams-connected)" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] No Teams sites found" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[ERROR] Error collecting SharePoint/OneDrive data: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host ""
    Write-Host "[SKIP] Skipping SharePoint/OneDrive collection (not connected)" -ForegroundColor Yellow
}

# Generate summary
Write-Host ""
Write-Host "[INFO] Generating summary report..." -ForegroundColor Cyan
$summaryFile = Join-Path $OutputDirectory "Summary.txt"

$mbTotalGB = [Math]::Round(($mbResults | Measure-Object -Property TotalSizeGB -Sum).Sum, 2)
$mbAvgGB = if ($mbResults.Count -gt 0) { [Math]::Round(($mbResults | Measure-Object -Property TotalSizeGB -Average).Average, 2) } else { 0 }
$mbLargest = $mbResults | Sort-Object TotalSizeGB -Descending | Select-Object -First 1

$odTotalGB = [Math]::Round(($odResults | Measure-Object -Property UsedGB -Sum).Sum, 2)
$odAvgGB = if ($odResults.Count -gt 0) { [Math]::Round(($odResults | Measure-Object -Property UsedGB -Average).Average, 2) } else { 0 }

$spTotalGB = [Math]::Round(($spResults | Measure-Object -Property UsedGB -Sum).Sum, 2)

$groupTotalGB = [Math]::Round(($groupResults | Measure-Object -Property StorageUsedGB -Sum).Sum, 2)
$teamsConnected = ($teamsResults | Where-Object { $_.HasTeamsIntegration -eq $true }).Count

# License stats
$licensedUsers = ($mbResults | Where-Object { $_.Licenses -ne "Not Available" -and $_.Licenses -ne "No License" }).Count
$unlicensedUsers = ($mbResults | Where-Object { $_.Licenses -eq "No License" }).Count

$summary = @"
============================================
OFFICE 365 QUICK ASSESSMENT SUMMARY
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Tenant: $TenantDomain
============================================

LICENSING
----------------------------------------
Licensed Users: $licensedUsers
Unlicensed Users: $unlicensedUsers
License Data Available: $(if ($msolConnected) { "Yes" } else { "No" })

MAILBOXES
----------------------------------------
Total Mailboxes: $($mbResults.Count)
Total Storage: $mbTotalGB GB
Average Size: $mbAvgGB GB
Largest: $($mbLargest.DisplayName) - $($mbLargest.TotalSizeGB) GB

ONEDRIVE
----------------------------------------
Total Sites: $($odResults.Count)
Total Storage: $odTotalGB GB
Average Size: $odAvgGB GB

SHAREPOINT
----------------------------------------
Total Sites: $($spResults.Count)
Total Storage: $spTotalGB GB
Permission Entries: $($permResults.Count)

MICROSOFT 365 GROUPS
----------------------------------------
Total Groups: $($groupResults.Count)
Total Storage: $groupTotalGB GB
Group Members: $($membershipResults.Count)

TEAMS
----------------------------------------
Teams-Connected Sites: $teamsConnected
Total Group Sites: $($teamsResults.Count)

COMBINED TOTALS
----------------------------------------
Total Storage: $([Math]::Round($mbTotalGB + $odTotalGB + $spTotalGB + $groupTotalGB, 2)) GB

EXECUTION
----------------------------------------
Duration: $(((Get-Date) - $StartTime).ToString('mm\:ss'))
============================================
"@

$summary | Out-File -FilePath $summaryFile -Encoding UTF8
Write-Host "[OK] Summary saved" -ForegroundColor Green

# Create Excel workbook from CSV files
Write-Host ""
Write-Host "[INFO] Creating Excel workbook..." -ForegroundColor Cyan
$excelFile = Join-Path (Split-Path $OutputDirectory -Parent) "O365_Assessment_$(Get-Date -Format 'yyyyMMdd_HHmmss').xlsx"

try {
    # Check if ImportExcel module is available
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Host "   Installing ImportExcel module..." -ForegroundColor Yellow
        Install-Module -Name ImportExcel -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop | Out-Null
        Write-Host "   [OK] ImportExcel module installed" -ForegroundColor Green
    }
    
    Import-Module ImportExcel -ErrorAction Stop
    
    # Get all CSV files
    $csvFiles = Get-ChildItem -Path $OutputDirectory -Filter "*.csv" -ErrorAction Stop
    
    if ($csvFiles.Count -gt 0) {
        Write-Host "   Processing $($csvFiles.Count) CSV files..." -ForegroundColor Yellow
        
        foreach ($csv in $csvFiles) {
            $worksheetName = $csv.BaseName -replace '_', ' '
            # Truncate worksheet name to 31 characters (Excel limit)
            if ($worksheetName.Length -gt 31) {
                $worksheetName = $worksheetName.Substring(0, 31)
            }
            
            # Create safe table name (letters and numbers only, must start with letter)
            $tableName = $csv.BaseName -replace '[^a-zA-Z0-9]', ''
            # Ensure it starts with a letter
            if ($tableName -match '^\d') {
                $tableName = "Table$tableName"
            }
            # Truncate to reasonable length
            if ($tableName.Length -gt 50) {
                $tableName = $tableName.Substring(0, 50)
            }
            
            Write-Host "      Adding worksheet: $worksheetName" -ForegroundColor Gray
            
            # Import CSV and export to Excel with table formatting
            $data = Import-Csv -Path $csv.FullName
            
            if ($data.Count -gt 0) {
                $data | Export-Excel -Path $excelFile `
                    -WorksheetName $worksheetName `
                    -AutoSize `
                    -TableName $tableName `
                    -TableStyle Medium2 `
                    -FreezeTopRow `
                    -BoldTopRow
            }
        }
        
        Write-Host "[OK] Excel workbook created: $excelFile" -ForegroundColor Green
        
        # Add summary as text (not table) to avoid formula issues
        Write-Host "   Adding summary worksheet..." -ForegroundColor Yellow
        
        # Split summary into lines for better Excel display
        $summaryLines = $summary -split "`r`n|`n"
        $summaryData = @()
        foreach ($line in $summaryLines) {
            $summaryData += [PSCustomObject]@{
                'Assessment Summary' = $line
            }
        }
        
        # Export without table formatting to avoid any formula interpretation
        $summaryData | Export-Excel -Path $excelFile `
            -WorksheetName "Summary" `
            -AutoSize `
            -BoldTopRow `
            -MoveToStart `
            -NoNumberConversion *
        
        Write-Host "[OK] Summary worksheet added" -ForegroundColor Green
    }
    else {
        Write-Host "[WARNING] No CSV files found to convert" -ForegroundColor Yellow
        $excelFile = $null
    }
}
catch {
    Write-Host "[WARNING] Could not create Excel workbook: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   CSV files are still available in output directory" -ForegroundColor Yellow
    $excelFile = $null
}

# Create ZIP archive
Write-Host ""
Write-Host "[INFO] Creating ZIP archive..." -ForegroundColor Cyan
$zipFile = "$($OutputDirectory).zip"
$filesToZip = Get-ChildItem -Path $OutputDirectory -File

if ($filesToZip.Count -gt 0) {
    Compress-Archive -Path "$OutputDirectory\*" -DestinationPath $zipFile -Force
    Write-Host "[OK] Archive created: $zipFile" -ForegroundColor Green
} else {
    Write-Host "[WARNING] No files to archive" -ForegroundColor Yellow
    $zipFile = $null
}

# Cleanup connections
Write-Host ""
Write-Host "[INFO] Disconnecting..." -ForegroundColor Cyan
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
if ($spoConnected) {
    Disconnect-SPOService -ErrorAction SilentlyContinue | Out-Null
}

# Final output
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  ASSESSMENT COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# Prioritize Excel file if available
if ($excelFile -and (Test-Path $excelFile)) {
    Write-Host ""
    Write-Host "Excel Report:" -ForegroundColor Cyan
    Write-Host "  $excelFile" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "ZIP Archive:" -ForegroundColor Cyan
    Write-Host "  $zipFile" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Opening Excel report..." -ForegroundColor Cyan
    Start-Process "explorer.exe" -ArgumentList "/select,`"$excelFile`""
}
elseif ($zipFile -and (Test-Path $zipFile)) {
    Write-Host ""
    Write-Host "Your report is ready:" -ForegroundColor Cyan
    Write-Host "  $zipFile" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Opening report location..." -ForegroundColor Cyan
    Start-Process "explorer.exe" -ArgumentList "/select,`"$zipFile`""
} elseif (Test-Path $OutputDirectory) {
    Write-Host ""
    Write-Host "Report directory:" -ForegroundColor Cyan
    Write-Host "  $OutputDirectory" -ForegroundColor Yellow
    Start-Process "explorer.exe" -ArgumentList "`"$OutputDirectory`""
}

Write-Host ""
Write-Host "Execution time: $(((Get-Date) - $StartTime).ToString('mm\:ss'))" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Green
