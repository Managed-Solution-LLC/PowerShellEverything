<#
.SYNOPSIS
    Analyze Office 365 assessment reports and generate insights.

.DESCRIPTION
    Post-assessment analysis script that reads CSV reports from Office 365 assessments
    and generates actionable insights including:
    - Mailboxes approaching quota limits
    - Largest storage consumers
    - Inactive mailboxes (no recent activity)
    - External forwarding rules (if available)
    - Storage growth projections
    - Recommendations for optimization
    
    Run this script after downloading and extracting your O365 assessment ZIP file.

.PARAMETER ReportDirectory
    Directory containing extracted CSV reports from assessment.

.PARAMETER QuotaWarningThreshold
    Percentage of quota usage that triggers warnings. Default is 80%.

.PARAMETER InactivityDays
    Days of inactivity to flag mailboxes as potentially inactive. Default is 90 days.

.PARAMETER OutputFile
    Path to save the analysis report. Default is AnalysisReport.html in report directory.

.EXAMPLE
    .\Analyze-O365Reports.ps1 -ReportDirectory "C:\Reports\O365Report_20251217_143022"
    Analyze reports with default thresholds.

.EXAMPLE
    .\Analyze-O365Reports.ps1 -ReportDirectory "C:\Reports\O365Report_20251217_143022" -QuotaWarningThreshold 70 -InactivityDays 60
    Custom thresholds for quota warnings and inactivity detection.

.NOTES
    Author: W. Ford (Managed Solution LLC)
    Date: 2025-12-17
    Version: 1.0
    
    Requirements:
    - PowerShell 5.1+
    - CSV files from Office 365 assessment scripts
    
    This script is read-only and does not modify any Office 365 data.

.LINK
    https://docs.microsoft.com/en-us/microsoft-365/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Directory containing assessment CSV files")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$ReportDirectory,
    
    [Parameter(Mandatory=$false, HelpMessage="Quota usage warning threshold percentage")]
    [ValidateRange(50, 100)]
    [int]$QuotaWarningThreshold = 80,
    
    [Parameter(Mandatory=$false, HelpMessage="Days without activity to flag as inactive")]
    [ValidateRange(30, 365)]
    [int]$InactivityDays = 90,
    
    [Parameter(Mandatory=$false, HelpMessage="Output file for analysis report")]
    [string]$OutputFile = ""
)

$ErrorActionPreference = 'Stop'

# Set default output file if not specified
if ([string]::IsNullOrEmpty($OutputFile)) {
    $OutputFile = Join-Path $ReportDirectory "AnalysisReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  OFFICE 365 REPORT ANALYZER" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Report Directory: $ReportDirectory" -ForegroundColor White
Write-Host "Quota Threshold: $QuotaWarningThreshold%" -ForegroundColor White
Write-Host "Inactivity Threshold: $InactivityDays days" -ForegroundColor White
Write-Host "==========================================`n" -ForegroundColor Cyan

# Find CSV files
$mailboxFile = Get-ChildItem -Path $ReportDirectory -Filter "*Mailbox*.csv" | Select-Object -First 1
$oneDriveFile = Get-ChildItem -Path $ReportDirectory -Filter "*OneDrive*.csv" | Select-Object -First 1
$sharePointFile = Get-ChildItem -Path $ReportDirectory -Filter "*SharePoint*.csv" | Select-Object -First 1
$rulesFile = Get-ChildItem -Path $ReportDirectory -Filter "*Rules*.csv" | Select-Object -First 1

if (-not $mailboxFile) {
    Write-Host "❌ ERROR: No mailbox CSV file found in directory" -ForegroundColor Red
    exit 1
}

Write-Host "📊 Loading data..." -ForegroundColor Cyan

# Load data
$mailboxes = Import-Csv $mailboxFile.FullName
Write-Host "✅ Loaded $($mailboxes.Count) mailboxes" -ForegroundColor Green

$oneDrives = if ($oneDriveFile) { 
    Import-Csv $oneDriveFile.FullName 
    Write-Host "✅ Loaded $($oneDrives.Count) OneDrive sites" -ForegroundColor Green
    $oneDrives
} else { 
    Write-Host "⚠️  No OneDrive data found" -ForegroundColor Yellow
    @() 
}

$spSites = if ($sharePointFile) { 
    Import-Csv $sharePointFile.FullName
    Write-Host "✅ Loaded $($spSites.Count) SharePoint sites" -ForegroundColor Green
    $spSites
} else { 
    Write-Host "⚠️  No SharePoint data found" -ForegroundColor Yellow
    @() 
}

$rules = if ($rulesFile) { 
    Import-Csv $rulesFile.FullName
    Write-Host "✅ Loaded $($rules.Count) mailbox rules" -ForegroundColor Green
    $rules
} else { 
    Write-Host "⚠️  No rules data found" -ForegroundColor Yellow
    @() 
}

Write-Host "`n📈 Analyzing data...`n" -ForegroundColor Cyan

# Analysis functions
function Get-QuotaAnalysis {
    param($Mailboxes, $Threshold)
    
    $results = @()
    foreach ($mb in $Mailboxes) {
        if ($mb.QuotaGB -ne "Unlimited" -and [double]$mb.QuotaGB -gt 0) {
            $usagePercent = ([double]$mb.SizeGB / [double]$mb.QuotaGB) * 100
            if ($usagePercent -ge $Threshold) {
                $results += [PSCustomObject]@{
                    DisplayName = $mb.DisplayName
                    EmailAddress = $mb.EmailAddress
                    SizeGB = [double]$mb.SizeGB
                    QuotaGB = [double]$mb.QuotaGB
                    UsagePercent = [Math]::Round($usagePercent, 1)
                    Status = if ($usagePercent -ge 95) { "Critical" } elseif ($usagePercent -ge 90) { "High" } else { "Warning" }
                }
            }
        }
    }
    return $results | Sort-Object UsagePercent -Descending
}

function Get-InactiveMailboxes {
    param($Mailboxes, $Days)
    
    $cutoffDate = (Get-Date).AddDays(-$Days)
    $results = @()
    
    foreach ($mb in $Mailboxes) {
        if (-not [string]::IsNullOrEmpty($mb.LastAccess) -or -not [string]::IsNullOrEmpty($mb.LastUserActionTime)) {
            $lastAccess = if ($mb.LastAccess) { $mb.LastAccess } else { $mb.LastUserActionTime }
            try {
                $accessDate = [DateTime]::Parse($lastAccess)
                if ($accessDate -lt $cutoffDate) {
                    $daysSinceAccess = ((Get-Date) - $accessDate).Days
                    $results += [PSCustomObject]@{
                        DisplayName = $mb.DisplayName
                        EmailAddress = $mb.EmailAddress
                        LastAccess = $accessDate.ToString('yyyy-MM-dd')
                        DaysSinceAccess = $daysSinceAccess
                        SizeGB = [double]$mb.SizeGB
                    }
                }
            }
            catch {
                Write-Verbose "Could not parse date for $($mb.EmailAddress): $lastAccess"
            }
        }
    }
    return $results | Sort-Object DaysSinceAccess -Descending
}

function Get-TopConsumers {
    param($Data, $Property, $Count = 10)
    
    return $Data | 
        Where-Object { $_.$Property -ne "Unlimited" -and [double]$_.$Property -gt 0 } |
        Sort-Object @{Expression={[double]$_.$Property}; Descending=$true} |
        Select-Object -First $Count
}

function Get-ExternalForwardingRules {
    param($Rules, $DomainPattern)
    
    $external = @()
    foreach ($rule in $Rules) {
        if ($rule.ForwardTo -or $rule.RedirectTo) {
            $addresses = ($rule.ForwardTo + "; " + $rule.RedirectTo) -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            foreach ($addr in $addresses) {
                if ($addr -match '@' -and $addr -notmatch $DomainPattern) {
                    $external += [PSCustomObject]@{
                        Mailbox = $rule.MailboxOwner
                        RuleName = $rule.RuleName
                        Enabled = $rule.Enabled
                        ForwardTo = $addr
                        Type = if ($rule.RedirectTo -match $addr) { "Redirect" } else { "Forward" }
                    }
                }
            }
        }
    }
    return $external
}

# Perform analyses
$quotaWarnings = Get-QuotaAnalysis -Mailboxes $mailboxes -Threshold $QuotaWarningThreshold
$inactiveMailboxes = Get-InactiveMailboxes -Mailboxes $mailboxes -Days $InactivityDays
$topMailboxes = Get-TopConsumers -Data $mailboxes -Property "SizeGB"
$topOneDrives = if ($oneDrives) { Get-TopConsumers -Data $oneDrives -Property "UsedGB" } else { @() }
$topSharePoint = if ($spSites) { Get-TopConsumers -Data $spSites -Property "UsedGB" } else { @() }

# External forwarding analysis
$externalForwarding = if ($rules) {
    # Try to detect domain from mailbox addresses
    $sampleDomain = ($mailboxes | Select-Object -First 1).EmailAddress -replace '.*@', ''
    Get-ExternalForwardingRules -Rules $rules -DomainPattern "@$sampleDomain"
} else { @() }

# Calculate totals
$totalMailboxGB = ($mailboxes | Measure-Object -Property SizeGB -Sum).Sum
$totalOneDriveGB = if ($oneDrives) { ($oneDrives | Measure-Object -Property UsedGB -Sum).Sum } else { 0 }
$totalSharePointGB = if ($spSites) { ($spSites | Measure-Object -Property UsedGB -Sum).Sum } else { 0 }
$totalStorageGB = $totalMailboxGB + $totalOneDriveGB + $totalSharePointGB

Write-Host "✅ Analysis complete!`n" -ForegroundColor Green

# Generate HTML Report
$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Office 365 Assessment Analysis</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #106ebe; margin-top: 30px; border-left: 4px solid #0078d4; padding-left: 10px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; }
        .card h3 { margin: 0 0 10px 0; font-size: 14px; opacity: 0.9; }
        .card .value { font-size: 32px; font-weight: bold; }
        .card .unit { font-size: 16px; opacity: 0.8; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background-color: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .status-critical { color: #d13438; font-weight: bold; }
        .status-high { color: #ff8c00; font-weight: bold; }
        .status-warning { color: #faa500; font-weight: bold; }
        .recommendation { background-color: #e7f3ff; border-left: 4px solid #0078d4; padding: 15px; margin: 10px 0; }
        .alert { background-color: #fff4e5; border-left: 4px solid #ff8c00; padding: 15px; margin: 10px 0; }
        .info { color: #666; font-size: 14px; margin: 20px 0; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px; }
    </style>
</head>
<body>
<div class="container">
    <h1>📊 Office 365 Assessment Analysis Report</h1>
    <div class="info">
        <strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')<br>
        <strong>Report Directory:</strong> $ReportDirectory<br>
        <strong>Analysis Thresholds:</strong> Quota Warning: $QuotaWarningThreshold% | Inactivity: $InactivityDays days
    </div>

    <h2>Executive Summary</h2>
    <div class="summary">
        <div class="card">
            <h3>Total Storage</h3>
            <div class="value">$([Math]::Round($totalStorageGB, 1))</div>
            <div class="unit">GB</div>
        </div>
        <div class="card">
            <h3>Mailboxes</h3>
            <div class="value">$($mailboxes.Count)</div>
            <div class="unit">accounts</div>
        </div>
        <div class="card">
            <h3>Quota Warnings</h3>
            <div class="value">$($quotaWarnings.Count)</div>
            <div class="unit">mailboxes</div>
        </div>
        <div class="card">
            <h3>Inactive Mailboxes</h3>
            <div class="value">$($inactiveMailboxes.Count)</div>
            <div class="unit">detected</div>
        </div>
    </div>

    <h2>Storage Breakdown</h2>
    <table>
        <tr><th>Category</th><th>Storage (GB)</th><th>Percentage</th></tr>
        <tr><td>Mailboxes</td><td>$([Math]::Round($totalMailboxGB, 2))</td><td>$([Math]::Round(($totalMailboxGB / $totalStorageGB) * 100, 1))%</td></tr>
        <tr><td>OneDrive</td><td>$([Math]::Round($totalOneDriveGB, 2))</td><td>$([Math]::Round(($totalOneDriveGB / $totalStorageGB) * 100, 1))%</td></tr>
        <tr><td>SharePoint</td><td>$([Math]::Round($totalSharePointGB, 2))</td><td>$([Math]::Round(($totalSharePointGB / $totalStorageGB) * 100, 1))%</td></tr>
        <tr style="font-weight: bold; background-color: #f0f0f0;"><td>Total</td><td>$([Math]::Round($totalStorageGB, 2))</td><td>100%</td></tr>
    </table>
"@

# Quota warnings section
if ($quotaWarnings.Count -gt 0) {
    $html += @"
    <h2>⚠️ Mailboxes Approaching Quota ($($quotaWarnings.Count) found)</h2>
    <div class="alert">
        <strong>Action Required:</strong> The following mailboxes are at or near their storage quota and may soon be unable to receive email.
    </div>
    <table>
        <tr><th>Display Name</th><th>Email</th><th>Used (GB)</th><th>Quota (GB)</th><th>Usage %</th><th>Status</th></tr>
"@
    foreach ($item in $quotaWarnings | Select-Object -First 25) {
        $statusClass = "status-$($item.Status.ToLower())"
        $html += "<tr><td>$($item.DisplayName)</td><td>$($item.EmailAddress)</td><td>$($item.SizeGB)</td><td>$($item.QuotaGB)</td><td>$($item.UsagePercent)%</td><td class='$statusClass'>$($item.Status)</td></tr>"
    }
    $html += "</table>"
    
    if ($quotaWarnings.Count -gt 25) {
        $html += "<p><em>Showing top 25 of $($quotaWarnings.Count) mailboxes. See CSV export for full list.</em></p>"
    }
}

# Inactive mailboxes section
if ($inactiveMailboxes.Count -gt 0) {
    $html += @"
    <h2>💤 Inactive Mailboxes ($($inactiveMailboxes.Count) found)</h2>
    <div class="recommendation">
        <strong>Recommendation:</strong> Review these mailboxes for potential license reclamation or archival. No activity detected in the last $InactivityDays days.
    </div>
    <table>
        <tr><th>Display Name</th><th>Email</th><th>Last Access</th><th>Days Inactive</th><th>Size (GB)</th></tr>
"@
    foreach ($item in $inactiveMailboxes | Select-Object -First 25) {
        $html += "<tr><td>$($item.DisplayName)</td><td>$($item.EmailAddress)</td><td>$($item.LastAccess)</td><td>$($item.DaysSinceAccess)</td><td>$($item.SizeGB)</td></tr>"
    }
    $html += "</table>"
    
    if ($inactiveMailboxes.Count -gt 25) {
        $html += "<p><em>Showing top 25 of $($inactiveMailboxes.Count) inactive mailboxes. See CSV export for full list.</em></p>"
    }
}

# External forwarding section
if ($externalForwarding.Count -gt 0) {
    $html += @"
    <h2>🔒 External Forwarding Rules ($($externalForwarding.Count) found)</h2>
    <div class="alert">
        <strong>Security Review Required:</strong> The following mailboxes have rules forwarding email to external addresses.
    </div>
    <table>
        <tr><th>Mailbox</th><th>Rule Name</th><th>Enabled</th><th>Forward To</th><th>Type</th></tr>
"@
    foreach ($item in $externalForwarding) {
        $html += "<tr><td>$($item.Mailbox)</td><td>$($item.RuleName)</td><td>$($item.Enabled)</td><td>$($item.ForwardTo)</td><td>$($item.Type)</td></tr>"
    }
    $html += "</table>"
}

# Top consumers section
$html += @"
    <h2>📈 Top 10 Storage Consumers</h2>
    
    <h3>Largest Mailboxes</h3>
    <table>
        <tr><th>Display Name</th><th>Email</th><th>Size (GB)</th><th>Type</th></tr>
"@
foreach ($mb in $topMailboxes) {
    $html += "<tr><td>$($mb.DisplayName)</td><td>$($mb.EmailAddress)</td><td>$([Math]::Round([double]$mb.SizeGB, 2))</td><td>$($mb.Type)</td></tr>"
}
$html += "</table>"

if ($topOneDrives.Count -gt 0) {
    $html += @"
    <h3>Largest OneDrive Sites</h3>
    <table>
        <tr><th>Owner</th><th>URL</th><th>Size (GB)</th></tr>
"@
    foreach ($od in $topOneDrives) {
        $html += "<tr><td>$($od.Owner)</td><td>$($od.URL)</td><td>$([Math]::Round([double]$od.UsedGB, 2))</td></tr>"
    }
    $html += "</table>"
}

if ($topSharePoint.Count -gt 0) {
    $html += @"
    <h3>Largest SharePoint Sites</h3>
    <table>
        <tr><th>Title</th><th>URL</th><th>Size (GB)</th></tr>
"@
    foreach ($sp in $topSharePoint) {
        $html += "<tr><td>$($sp.Title)</td><td>$($sp.URL)</td><td>$([Math]::Round([double]$sp.UsedGB, 2))</td></tr>"
    }
    $html += "</table>"
}

# Recommendations section
$html += @"
    <h2>💡 Recommendations</h2>
    <div class="recommendation">
        <h3>Immediate Actions</h3>
        <ul>
"@

if ($quotaWarnings.Count -gt 0) {
    $critical = $quotaWarnings | Where-Object { $_.Status -eq "Critical" }
    if ($critical) {
        $html += "<li><strong>URGENT:</strong> $($critical.Count) mailbox(es) at 95%+ quota. Contact users immediately to free space.</li>"
    }
    $html += "<li>Review $($quotaWarnings.Count) mailbox(es) approaching quota limits.</li>"
}

if ($inactiveMailboxes.Count -gt 0) {
    $html += "<li>Audit $($inactiveMailboxes.Count) inactive mailbox(es) for potential license recovery (potential savings: $(($inactiveMailboxes.Count * 12)) licenses/year if monthly billing).</li>"
}

if ($externalForwarding.Count -gt 0) {
    $html += "<li><strong>SECURITY:</strong> Review $($externalForwarding.Count) external forwarding rule(s) for compliance and security risks.</li>"
}

$html += @"
        </ul>
    </div>
    
    <div class="recommendation">
        <h3>Long-term Optimization</h3>
        <ul>
            <li>Implement mailbox archiving policies for mailboxes over 50GB</li>
            <li>Enable auto-expanding archives for users with growing mailboxes</li>
            <li>Review retention policies to automatically clean old items</li>
            <li>Consider OneDrive storage policies to manage personal file growth</li>
            <li>Audit SharePoint site owners and implement cleanup schedules</li>
            <li>Monitor storage trends monthly to forecast license needs</li>
        </ul>
    </div>

    <div class="footer">
        <p><strong>Office 365 Assessment Analysis Report</strong> | Generated by PowerShellEverything | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>This report is for informational purposes only. Verify all findings before taking action.</p>
    </div>
</div>
</body>
</html>
"@

# Save HTML report
$html | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "✅ Analysis report saved to:" -ForegroundColor Green
Write-Host "   $OutputFile" -ForegroundColor Yellow

# Export findings to CSV files
if ($quotaWarnings.Count -gt 0) {
    $quotaFile = Join-Path $ReportDirectory "Analysis_QuotaWarnings_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $quotaWarnings | Export-Csv -Path $quotaFile -NoTypeInformation
    Write-Host "✅ Quota warnings exported to: $quotaFile" -ForegroundColor Green
}

if ($inactiveMailboxes.Count -gt 0) {
    $inactiveFile = Join-Path $ReportDirectory "Analysis_InactiveMailboxes_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $inactiveMailboxes | Export-Csv -Path $inactiveFile -NoTypeInformation
    Write-Host "✅ Inactive mailboxes exported to: $inactiveFile" -ForegroundColor Green
}

if ($externalForwarding.Count -gt 0) {
    $forwardingFile = Join-Path $ReportDirectory "Analysis_ExternalForwarding_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $externalForwarding | Export-Csv -Path $forwardingFile -NoTypeInformation
    Write-Host "✅ External forwarding rules exported to: $forwardingFile" -ForegroundColor Green
}

# Summary
Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "  ✅ ANALYSIS COMPLETE!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Open the HTML report in your browser:" -ForegroundColor Cyan
Write-Host "  $OutputFile" -ForegroundColor Yellow
Write-Host "`nKey Findings:" -ForegroundColor Cyan
Write-Host "  • $($quotaWarnings.Count) mailbox(es) approaching quota" -ForegroundColor White
Write-Host "  • $($inactiveMailboxes.Count) inactive mailbox(es) detected" -ForegroundColor White
Write-Host "  • $($externalForwarding.Count) external forwarding rule(s) found" -ForegroundColor White
Write-Host "  • $([Math]::Round($totalStorageGB, 1)) GB total storage used" -ForegroundColor White
Write-Host "==========================================`n" -ForegroundColor Green

# Open HTML report in default browser
$openReport = Read-Host "Open HTML report in browser now? (Y/N)"
if ($openReport -match '^[Yy]') {
    Start-Process $OutputFile
}
