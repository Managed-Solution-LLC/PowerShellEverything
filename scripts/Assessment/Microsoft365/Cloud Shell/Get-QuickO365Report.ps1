<#
.SYNOPSIS
    Quick Office 365 assessment for Azure Cloud Shell - simplified execution.

.DESCRIPTION
    Streamlined version of the comprehensive O365 assessment optimized for Cloud Shell.
    Collects essential data only (mailboxes, OneDrive, SharePoint) without optional features.
    
    Automatically:
    - Installs required modules
    - Connects to services
    - Collects core data
    - Creates downloadable ZIP file
    
    Perfect for quick tenant assessments and capacity planning.

.PARAMETER TenantDomain
    SharePoint admin domain (e.g., 'contoso' for contoso-admin.sharepoint.com).
    Auto-detected if not specified.

.EXAMPLE
    .\Get-QuickO365Report.ps1
    Run with auto-detection (easiest method).

.EXAMPLE
    .\Get-QuickO365Report.ps1 -TenantDomain "contoso"
    Specify tenant domain explicitly.

.NOTES
    Author: W. Ford (Managed Solution LLC)
    Date: 2025-12-17
    Version: 1.0
    
    Requirements:
    - Azure Cloud Shell (PowerShell mode)
    - Global Reader, Exchange Admin, or SharePoint Admin role
    
    Execution Time: 5-20 minutes depending on tenant size
    
.LINK
    https://learn.microsoft.com/en-us/azure/cloud-shell/overview
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TenantDomain
)

$ErrorActionPreference = 'Stop'
$StartTime = Get-Date
$OutputDir = "cloudshell:\O365Report_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  OFFICE 365 QUICK ASSESSMENT" -ForegroundColor Cyan
Write-Host "  Cloud Shell Edition" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

# Create output directory
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Write-Host "✅ Output directory: $OutputDir" -ForegroundColor Green

# Install modules silently
Write-Host "`n📦 Checking required modules..." -ForegroundColor Cyan
$modules = @('ExchangeOnlineManagement', 'Microsoft.Online.SharePoint.PowerShell')
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "   Installing $module..." -ForegroundColor Yellow
        Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber | Out-Null
    }
    Write-Host "   ✅ $module ready" -ForegroundColor Green
}

# Connect to Exchange
Write-Host "`n🔌 Connecting to Exchange Online..." -ForegroundColor Cyan
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false
Write-Host "✅ Connected to Exchange Online" -ForegroundColor Green

# Auto-detect tenant if not provided
if ([string]::IsNullOrEmpty($TenantDomain)) {
    Write-Host "`n🔍 Detecting tenant domain..." -ForegroundColor Cyan
    $orgConfig = Get-OrganizationConfig
    $TenantDomain = ($orgConfig.Identity -split '\.')[0]
    Write-Host "✅ Detected tenant: $TenantDomain" -ForegroundColor Green
}

# Connect to SharePoint
Write-Host "`n🔌 Connecting to SharePoint Online..." -ForegroundColor Cyan
Import-Module Microsoft.Online.SharePoint.PowerShell
$adminUrl = "https://$TenantDomain-admin.sharepoint.com"
Connect-SPOService -Url $adminUrl
Write-Host "✅ Connected to SharePoint Online" -ForegroundColor Green

# Helper function for size conversion
function ConvertTo-GB {
    param([string]$Size)
    if ([string]::IsNullOrEmpty($Size) -or $Size -eq "Unlimited") { return 0 }
    $value = $Size.Split(" ")
    switch($value[1]) {
        "GB" { return [Math]::Round([double]$value[0], 2) }
        "MB" { return [Math]::Round([double]$value[0] / 1024, 2) }
        "KB" { return [Math]::Round([double]$value[0] / 1024 / 1024, 2) }
        default { return 0 }
    }
}

# Collect mailbox statistics
Write-Host "`n📊 Collecting mailbox statistics..." -ForegroundColor Cyan
$mailboxFile = Join-Path $OutputDir "Mailboxes.csv"
$mailboxes = Get-EXOMailbox -ResultSize Unlimited
Write-Host "   Found $($mailboxes.Count) mailboxes" -ForegroundColor Yellow

$mbResults = @()
$i = 0
foreach ($mb in $mailboxes) {
    $i++
    Write-Progress -Activity "Collecting Mailboxes" -Status "$($mb.DisplayName)" -PercentComplete (($i/$mailboxes.Count)*100)
    
    try {
        $stats = Get-EXOMailboxStatistics -Identity $mb.UserPrincipalName
        $totalGB = ConvertTo-GB -Size $stats.TotalItemSize.ToString().Split("(")[0]
        $quotaGB = if ($mb.ProhibitSendReceiveQuota -ne "Unlimited") { 
            ConvertTo-GB -Size $mb.ProhibitSendReceiveQuota.ToString().Split("(")[0] 
        } else { "Unlimited" }
        
        $mbResults += [PSCustomObject]@{
            DisplayName = $mb.DisplayName
            EmailAddress = $mb.PrimarySmtpAddress
            Type = $mb.RecipientTypeDetails
            SizeGB = $totalGB
            ItemCount = $stats.ItemCount
            QuotaGB = $quotaGB
            LastAccess = $stats.LastUserActionTime
        }
    }
    catch {
        Write-Verbose "Error: $($_.Exception.Message)"
    }
}
Write-Progress -Activity "Collecting Mailboxes" -Completed
$mbResults | Export-Csv -Path $mailboxFile -NoTypeInformation
Write-Host "✅ Exported $($mbResults.Count) mailboxes" -ForegroundColor Green

# Collect OneDrive statistics
Write-Host "`n📊 Collecting OneDrive sites..." -ForegroundColor Cyan
$oneDriveFile = Join-Path $OutputDir "OneDrive.csv"
$odSites = Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'"
Write-Host "   Found $($odSites.Count) OneDrive sites" -ForegroundColor Yellow

$odResults = @()
$i = 0
foreach ($site in $odSites) {
    $i++
    Write-Progress -Activity "Collecting OneDrive" -Status "$($site.Owner)" -PercentComplete (($i/$odSites.Count)*100)
    
    $odResults += [PSCustomObject]@{
        Owner = $site.Owner
        URL = $site.Url
        UsedGB = [Math]::Round($site.StorageUsageCurrent / 1024, 2)
        QuotaGB = [Math]::Round($site.StorageQuota / 1024, 2)
        LastModified = $site.LastContentModifiedDate
    }
}
Write-Progress -Activity "Collecting OneDrive" -Completed
$odResults | Export-Csv -Path $oneDriveFile -NoTypeInformation
Write-Host "✅ Exported $($odResults.Count) OneDrive sites" -ForegroundColor Green

# Collect SharePoint sites
Write-Host "`n📊 Collecting SharePoint sites..." -ForegroundColor Cyan
$spFile = Join-Path $OutputDir "SharePoint.csv"
$spSites = Get-SPOSite -Limit All -Filter "Url -notlike '-my.sharepoint.com/personal/'"
Write-Host "   Found $($spSites.Count) SharePoint sites" -ForegroundColor Yellow

$spResults = @()
$i = 0
foreach ($site in $spSites) {
    $i++
    Write-Progress -Activity "Collecting SharePoint" -Status "$($site.Title)" -PercentComplete (($i/$spSites.Count)*100)
    
    $spResults += [PSCustomObject]@{
        Title = $site.Title
        URL = $site.Url
        Owner = $site.Owner
        UsedGB = [Math]::Round($site.StorageUsageCurrent / 1024, 2)
        QuotaGB = [Math]::Round($site.StorageQuota / 1024, 2)
        LastModified = $site.LastContentModifiedDate
        Status = $site.Status
    }
}
Write-Progress -Activity "Collecting SharePoint" -Completed
$spResults | Export-Csv -Path $spFile -NoTypeInformation
Write-Host "✅ Exported $($spResults.Count) SharePoint sites" -ForegroundColor Green

# Generate summary
Write-Host "`n📝 Generating summary report..." -ForegroundColor Cyan
$summaryFile = Join-Path $OutputDir "Summary.txt"
$summary = @"
============================================
OFFICE 365 QUICK ASSESSMENT SUMMARY
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Tenant: $TenantDomain
============================================

MAILBOXES
----------------------------------------
Total Mailboxes: $($mbResults.Count)
Total Storage: $([Math]::Round(($mbResults | Measure-Object -Property SizeGB -Sum).Sum, 2)) GB
Average Size: $([Math]::Round(($mbResults | Measure-Object -Property SizeGB -Average).Average, 2)) GB
Largest: $(($mbResults | Sort-Object SizeGB -Descending | Select-Object -First 1).DisplayName) - $(($mbResults | Sort-Object SizeGB -Descending | Select-Object -First 1).SizeGB) GB

ONEDRIVE
----------------------------------------
Total Sites: $($odResults.Count)
Total Storage: $([Math]::Round(($odResults | Measure-Object -Property UsedGB -Sum).Sum, 2)) GB
Average Size: $([Math]::Round(($odResults | Measure-Object -Property UsedGB -Average).Average, 2)) GB

SHAREPOINT
----------------------------------------
Total Sites: $($spResults.Count)
Total Storage: $([Math]::Round(($spResults | Measure-Object -Property UsedGB -Sum).Sum, 2)) GB

EXECUTION
----------------------------------------
Duration: $(((Get-Date) - $StartTime).ToString('mm\:ss'))
============================================
"@

$summary | Out-File -FilePath $summaryFile
Write-Host "✅ Summary saved" -ForegroundColor Green

# Create ZIP archive
Write-Host "`n📦 Creating ZIP archive..." -ForegroundColor Cyan
$zipFile = "cloudshell:\O365Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
Compress-Archive -Path "$OutputDir\*" -DestinationPath $zipFile -Force
Write-Host "✅ Archive created: $zipFile" -ForegroundColor Green

# Cleanup
Disconnect-ExchangeOnline -Confirm:$false | Out-Null
Disconnect-SPOService | Out-Null

# Display final instructions
Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  ✅ ASSESSMENT COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "`nYour report is ready for download:" -ForegroundColor Cyan
Write-Host "  $zipFile" -ForegroundColor Yellow
Write-Host "`nTo download in Cloud Shell:" -ForegroundColor Cyan
Write-Host "  1. Click the download button (folder icon)" -ForegroundColor White
Write-Host "  2. Browse to: cloudshell:\" -ForegroundColor White
Write-Host "  3. Select the ZIP file" -ForegroundColor White
Write-Host "`nOr use command:" -ForegroundColor Cyan
Write-Host "  download `"$zipFile`"" -ForegroundColor White
Write-Host "`nTotal execution time: $(((Get-Date) - $StartTime).ToString('mm\:ss'))" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Green

# Display summary
Write-Host $summary
