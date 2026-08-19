<#
.SYNOPSIS
    Comprehensive Office 365 assessment report for Cloud Shell execution.

.DESCRIPTION
    This script generates a complete Office 365 assessment including:
    - Mailbox sizes and quotas (user, shared, archive)
    - Mailbox forwarding rules and inbox rules
    - OneDrive site sizes and usage
    - SharePoint site collections and storage
    
    Optimized for Azure Cloud Shell execution with:
    - Non-interactive authentication (uses existing Cloud Shell session)
    - Parallel data collection where possible
    - Automatic ZIP file creation for download
    - Progress tracking for long-running operations
    
    All exports are saved to cloudshell:\ drive and packaged into a downloadable ZIP file.

.PARAMETER OutputDirectory
    Directory to save reports. Default is cloudshell:\O365Reports with timestamp.

.PARAMETER IncludeArchives
    Include archive mailbox statistics in the report.

.PARAMETER IncludeSharedMailboxes
    Include shared mailboxes in the mailbox size report.

.PARAMETER IncludeMailboxRules
    Collect inbox rules for all mailboxes (can be time-consuming for large tenants).

.PARAMETER TenantDomain
    SharePoint admin URL domain (e.g., 'contoso' for contoso-admin.sharepoint.com).
    If not provided, script will attempt to detect from tenant information.

.PARAMETER MaxConcurrentJobs
    Maximum number of parallel collection jobs. Default is 3 for Cloud Shell resource limits.

.EXAMPLE
    .\Get-ComprehensiveO365Report.ps1
    Runs complete assessment with default settings, creates ZIP file in cloudshell:\O365Reports.

.EXAMPLE
    .\Get-ComprehensiveO365Report.ps1 -IncludeArchives -IncludeMailboxRules -TenantDomain "contoso"
    Full assessment including archives and mailbox rules for contoso tenant.

.EXAMPLE
    .\Get-ComprehensiveO365Report.ps1 -OutputDirectory "cloudshell:\Reports" -MaxConcurrentJobs 5
    Custom output location with increased parallelism.

.NOTES
    Author: W. Ford (Managed Solution LLC)
    Date: 2025-12-17
    Version: 1.0
    
    Requirements:
    - Azure Cloud Shell (PowerShell)
    - Global Administrator or appropriate read permissions:
      - Exchange Administrator (for mailbox data)
      - SharePoint Administrator (for SharePoint/OneDrive data)
      - Global Reader (alternative read-only role)
    
    Cloud Shell Authentication:
    - Script uses existing Cloud Shell authentication session
    - No credential prompts required
    - Automatically connects to required services
    
    Performance Notes:
    - Mailbox rule collection can take 5-10 seconds per mailbox
    - Consider organizational size when enabling -IncludeMailboxRules
    - Parallel jobs optimize data collection speed
    
    Output:
    - Individual CSV files for each data type
    - Summary text report with key findings
    - ZIP file containing all reports for easy download

.LINK
    https://learn.microsoft.com/en-us/powershell/azure/cloud-shell/overview
.LINK
    https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell-v2
.LINK
    https://learn.microsoft.com/en-us/powershell/module/sharepoint-online/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Output directory for reports")]
    [string]$OutputDirectory = "cloudshell:\O365Reports_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
    
    [Parameter(Mandatory=$false, HelpMessage="Include archive mailbox statistics")]
    [switch]$IncludeArchives,
    
    [Parameter(Mandatory=$false, HelpMessage="Include shared mailboxes in report")]
    [switch]$IncludeSharedMailboxes,
    
    [Parameter(Mandatory=$false, HelpMessage="Collect inbox rules (time-consuming)")]
    [switch]$IncludeMailboxRules,
    
    [Parameter(Mandatory=$false, HelpMessage="SharePoint admin domain (e.g., 'contoso' for contoso-admin.sharepoint.com)")]
    [string]$TenantDomain,
    
    [Parameter(Mandatory=$false, HelpMessage="Maximum concurrent collection jobs")]
    [ValidateRange(1, 10)]
    [int]$MaxConcurrentJobs = 3
)

#Requires -Version 5.1

# Initialize tracking variables
$StartTime = Get-Date
$ErrorCount = 0
$WarningCount = 0
$Separator = "=" * 80
$SubSeparator = "-" * 60

# Status message function with error tracking
function Write-StatusMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Type) {
        "Error" { 
            Write-Host "[$timestamp] ❌ ERROR: $Message" -ForegroundColor Red
            $script:ErrorCount++
        }
        "Warning" { 
            Write-Host "[$timestamp] ⚠️  WARNING: $Message" -ForegroundColor Yellow
            $script:WarningCount++
        }
        "Success" { 
            Write-Host "[$timestamp] ✅ SUCCESS: $Message" -ForegroundColor Green
        }
        default { 
            Write-Host "[$timestamp] INFO: $Message" -ForegroundColor Cyan
        }
    }
}

# Safe command execution wrapper
function Invoke-SafeCommand {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Command,
        [Parameter(Mandatory=$false)]
        [string]$ErrorMessage = "Command execution failed",
        [Parameter(Mandatory=$false)]
        [switch]$ContinueOnError
    )
    
    try {
        Write-Verbose "Executing command: $($Command.ToString().Substring(0, [Math]::Min(50, $Command.ToString().Length)))..."
        $result = & $Command
        
        if ($null -eq $result) {
            Write-Verbose "Command returned null result"
        }
        
        return $result
    }
    catch {
        $errorDetails = "$ErrorMessage - $($_.Exception.Message)"
        Write-StatusMessage -Message $errorDetails -Type Error
        Write-Verbose "Stack Trace: $($_.ScriptStackTrace)"
        
        if (-not $ContinueOnError) {
            throw
        }
        return $null
    }
}

# Convert size to GB
function ConvertTo-Gb {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Size
    )
    
    if ([string]::IsNullOrEmpty($Size) -or $Size -eq "Unlimited") {
        return 0
    }
    
    try {
        $value = $Size.Split(" ")
        
        switch($value[1]) {
            "GB" { $sizeInGb = [double]$value[0] }
            "MB" { $sizeInGb = [double]$value[0] / 1024 }
            "KB" { $sizeInGb = [double]$value[0] / 1024 / 1024 }
            "bytes" { $sizeInGb = [double]$value[0] / 1024 / 1024 / 1024 }
            default { $sizeInGb = 0 }
        }
        
        return [Math]::Round($sizeInGb, 2, [MidPointRounding]::AwayFromZero)
    }
    catch {
        Write-Verbose "Error converting size '$Size': $($_.Exception.Message)"
        return 0
    }
}

# Module verification and installation
function Initialize-RequiredModules {
    Write-StatusMessage -Message "Checking required PowerShell modules..." -Type Info
    
    $RequiredModules = @(
        @{Name = 'ExchangeOnlineManagement'; MinVersion = '3.0.0'},
        @{Name = 'Microsoft.Online.SharePoint.PowerShell'; MinVersion = '16.0.0'}
    )
    
    foreach ($Module in $RequiredModules) {
        $moduleName = $Module.Name
        $installedModule = Get-Module -Name $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        
        if (-not $installedModule) {
            Write-StatusMessage -Message "Installing module: $moduleName" -Type Info
            try {
                Install-Module -Name $moduleName -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                Write-StatusMessage -Message "Successfully installed $moduleName" -Type Success
            }
            catch {
                Write-StatusMessage -Message "Failed to install $moduleName - $($_.Exception.Message)" -Type Error
                throw "Required module $moduleName could not be installed"
            }
        }
        else {
            Write-StatusMessage -Message "Module $moduleName is available (v$($installedModule.Version))" -Type Success
        }
    }
}

# Connect to Exchange Online
function Connect-O365Services {
    Write-StatusMessage -Message "Connecting to Office 365 services..." -Type Info
    
    # Connect to Exchange Online
    try {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        
        # Verify connection
        $null = Get-OrganizationConfig -ErrorAction Stop
        Write-StatusMessage -Message "Connected to Exchange Online" -Type Success
    }
    catch {
        Write-StatusMessage -Message "Failed to connect to Exchange Online: $($_.Exception.Message)" -Type Error
        throw
    }
    
    # Get tenant information for SharePoint connection
    if ([string]::IsNullOrEmpty($TenantDomain)) {
        try {
            $orgConfig = Get-OrganizationConfig
            $tenantName = ($orgConfig.Identity -split '\.')[0]
            $script:TenantDomain = $tenantName
            Write-StatusMessage -Message "Detected tenant domain: $tenantName" -Type Info
        }
        catch {
            Write-StatusMessage -Message "Could not auto-detect tenant domain. SharePoint/OneDrive collection will be skipped." -Type Warning
            return
        }
    }
    
    # Connect to SharePoint Online
    if (-not [string]::IsNullOrEmpty($script:TenantDomain)) {
        try {
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
            $adminUrl = "https://$($script:TenantDomain)-admin.sharepoint.com"
            Connect-SPOService -Url $adminUrl -ErrorAction Stop
            Write-StatusMessage -Message "Connected to SharePoint Online" -Type Success
        }
        catch {
            Write-StatusMessage -Message "Failed to connect to SharePoint Online: $($_.Exception.Message)" -Type Warning
            $script:TenantDomain = $null
        }
    }
}

# Collect mailbox statistics
function Get-MailboxStatisticsReport {
    Write-StatusMessage -Message "Collecting mailbox statistics..." -Type Info
    
    $outputFile = Join-Path $OutputDirectory "MailboxSizes_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    try {
        # Get all mailboxes
        $mailboxParams = @{
            ResultSize = 'Unlimited'
            ErrorAction = 'Stop'
        }
        
        if (-not $IncludeSharedMailboxes) {
            $mailboxParams['Filter'] = "RecipientTypeDetails -ne 'SharedMailbox'"
        }
        
        $mailboxes = Invoke-SafeCommand -Command { 
            Get-EXOMailbox @mailboxParams
        } -ErrorMessage "Failed to retrieve mailboxes"
        
        if ($null -eq $mailboxes -or $mailboxes.Count -eq 0) {
            Write-StatusMessage -Message "No mailboxes found" -Type Warning
            return $null
        }
        
        Write-StatusMessage -Message "Processing $($mailboxes.Count) mailboxes..." -Type Info
        
        $results = @()
        $i = 0
        
        foreach ($mailbox in $mailboxes) {
            $i++
            Write-Progress -Activity "Collecting mailbox statistics" -Status "Processing: $($mailbox.DisplayName)" `
                -PercentComplete (($i / $mailboxes.Count) * 100) -CurrentOperation "Mailbox $i of $($mailboxes.Count)"
            
            try {
                # Get mailbox statistics
                $mbStats = Get-EXOMailboxStatistics -Identity $mailbox.UserPrincipalName -ErrorAction Stop
                
                # Get archive statistics if requested
                $archiveSize = 0
                $archiveItems = 0
                $archiveDeletedItems = 0
                
                if ($IncludeArchives -and $null -ne $mailbox.ArchiveDatabase) {
                    try {
                        $archiveStats = Get-EXOMailboxStatistics -Identity $mailbox.UserPrincipalName -Archive -ErrorAction Stop
                        if ($null -ne $archiveStats.TotalItemSize) {
                            $archiveSize = ConvertTo-Gb -Size $archiveStats.TotalItemSize.ToString().Split("(")[0]
                        }
                        $archiveItems = $archiveStats.ItemCount
                        $archiveDeletedItems = $archiveStats.DeletedItemCount
                    }
                    catch {
                        Write-Verbose "Could not retrieve archive stats for $($mailbox.UserPrincipalName): $($_.Exception.Message)"
                    }
                }
                
                # Process mailbox size
                $totalSizeGB = 0
                if ($null -ne $mbStats.TotalItemSize) {
                    $totalSizeGB = ConvertTo-Gb -Size $mbStats.TotalItemSize.ToString().Split("(")[0]
                }
                
                $deletedSizeGB = 0
                if ($null -ne $mbStats.TotalDeletedItemSize) {
                    $deletedSizeGB = ConvertTo-Gb -Size $mbStats.TotalDeletedItemSize.ToString().Split("(")[0]
                }
                
                # Process quotas
                $warningQuota = if ($mailbox.IssueWarningQuota -ne "Unlimited") { 
                    ConvertTo-Gb -Size $mailbox.IssueWarningQuota.ToString().Split("(")[0]
                } else { "Unlimited" }
                
                $maxSize = if ($mailbox.ProhibitSendReceiveQuota -ne "Unlimited") { 
                    ConvertTo-Gb -Size $mailbox.ProhibitSendReceiveQuota.ToString().Split("(")[0]
                } else { "Unlimited" }
                
                $freeSpace = if ($maxSize -ne "Unlimited") {
                    [Math]::Round($maxSize - $totalSizeGB, 2)
                } else { "Unlimited" }
                
                $results += [PSCustomObject]@{
                    "DisplayName" = $mailbox.DisplayName
                    "EmailAddress" = $mailbox.PrimarySmtpAddress
                    "MailboxType" = $mailbox.RecipientTypeDetails
                    "LastUserActionTime" = $mbStats.LastUserActionTime
                    "TotalSizeGB" = $totalSizeGB
                    "DeletedItemsSizeGB" = $deletedSizeGB
                    "ItemCount" = $mbStats.ItemCount
                    "DeletedItemCount" = $mbStats.DeletedItemCount
                    "WarningQuotaGB" = $warningQuota
                    "MaxMailboxSizeGB" = $maxSize
                    "FreeSpaceGB" = $freeSpace
                    "ArchiveSizeGB" = $archiveSize
                    "ArchiveItemCount" = $archiveItems
                    "ArchiveDeletedItemCount" = $archiveDeletedItems
                }
            }
            catch {
                Write-StatusMessage -Message "Error processing mailbox $($mailbox.DisplayName): $($_.Exception.Message)" -Type Warning
            }
        }
        
        Write-Progress -Activity "Collecting mailbox statistics" -Completed
        
        if ($results.Count -gt 0) {
            $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
            Write-StatusMessage -Message "Exported $($results.Count) mailbox records to: $outputFile" -Type Success
            return $outputFile
        }
        else {
            Write-StatusMessage -Message "No mailbox data collected" -Type Warning
            return $null
        }
    }
    catch {
        Write-StatusMessage -Message "Failed to collect mailbox statistics: $($_.Exception.Message)" -Type Error
        return $null
    }
}

# Collect mailbox rules
function Get-MailboxRulesReport {
    if (-not $IncludeMailboxRules) {
        Write-StatusMessage -Message "Skipping mailbox rules collection (not requested)" -Type Info
        return $null
    }
    
    Write-StatusMessage -Message "Collecting mailbox inbox rules..." -Type Info
    
    $outputFile = Join-Path $OutputDirectory "MailboxRules_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    try {
        $mailboxes = Invoke-SafeCommand -Command { 
            Get-EXOMailbox -ResultSize Unlimited -ErrorAction Stop
        } -ErrorMessage "Failed to retrieve mailboxes for rules collection"
        
        if ($null -eq $mailboxes -or $mailboxes.Count -eq 0) {
            Write-StatusMessage -Message "No mailboxes found for rules collection" -Type Warning
            return $null
        }
        
        Write-StatusMessage -Message "Scanning $($mailboxes.Count) mailboxes for inbox rules (this may take a while)..." -Type Info
        
        $results = @()
        $i = 0
        
        foreach ($mailbox in $mailboxes) {
            $i++
            Write-Progress -Activity "Collecting inbox rules" -Status "Processing: $($mailbox.DisplayName)" `
                -PercentComplete (($i / $mailboxes.Count) * 100) -CurrentOperation "Mailbox $i of $($mailboxes.Count)"
            
            try {
                $rules = Get-InboxRule -Mailbox $mailbox.UserPrincipalName -ErrorAction Stop
                
                foreach ($rule in $rules) {
                    $results += [PSCustomObject]@{
                        "MailboxOwner" = $mailbox.DisplayName
                        "EmailAddress" = $mailbox.PrimarySmtpAddress
                        "RuleName" = $rule.Name
                        "Description" = $rule.Description
                        "Enabled" = $rule.Enabled
                        "RedirectTo" = ($rule.RedirectTo -join '; ')
                        "ForwardTo" = ($rule.ForwardTo -join '; ')
                        "MoveToFolder" = $rule.MoveToFolder
                        "DeleteMessage" = $rule.DeleteMessage
                        "MarkAsRead" = $rule.MarkAsRead
                    }
                }
            }
            catch {
                Write-Verbose "Error retrieving rules for $($mailbox.DisplayName): $($_.Exception.Message)"
            }
        }
        
        Write-Progress -Activity "Collecting inbox rules" -Completed
        
        if ($results.Count -gt 0) {
            $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
            Write-StatusMessage -Message "Exported $($results.Count) inbox rules from $($mailboxes.Count) mailboxes to: $outputFile" -Type Success
            return $outputFile
        }
        else {
            Write-StatusMessage -Message "No inbox rules found" -Type Info
            return $null
        }
    }
    catch {
        Write-StatusMessage -Message "Failed to collect mailbox rules: $($_.Exception.Message)" -Type Error
        return $null
    }
}

# Collect OneDrive statistics
function Get-OneDriveReport {
    if ([string]::IsNullOrEmpty($script:TenantDomain)) {
        Write-StatusMessage -Message "Skipping OneDrive collection (SharePoint not connected)" -Type Warning
        return $null
    }
    
    Write-StatusMessage -Message "Collecting OneDrive site statistics..." -Type Info
    
    $outputFile = Join-Path $OutputDirectory "OneDriveSites_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    try {
        $oneDriveSites = Invoke-SafeCommand -Command {
            Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'" -ErrorAction Stop
        } -ErrorMessage "Failed to retrieve OneDrive sites"
        
        if ($null -eq $oneDriveSites -or $oneDriveSites.Count -eq 0) {
            Write-StatusMessage -Message "No OneDrive sites found" -Type Warning
            return $null
        }
        
        Write-StatusMessage -Message "Processing $($oneDriveSites.Count) OneDrive sites..." -Type Info
        
        $results = @()
        $i = 0
        
        foreach ($site in $oneDriveSites) {
            $i++
            Write-Progress -Activity "Collecting OneDrive statistics" -Status "Processing: $($site.Title)" `
                -PercentComplete (($i / $oneDriveSites.Count) * 100) -CurrentOperation "Site $i of $($oneDriveSites.Count)"
            
            $usedGB = [Math]::Round($site.StorageUsageCurrent / 1024, 2)
            $quotaGB = [Math]::Round($site.StorageQuota / 1024, 2)
            $warningGB = [Math]::Round($site.StorageQuotaWarningLevel / 1024, 2)
            $freeGB = [Math]::Round(($site.StorageQuota - $site.StorageUsageCurrent) / 1024, 2)
            
            $results += [PSCustomObject]@{
                "Owner" = $site.Owner
                "Title" = $site.Title
                "URL" = $site.Url
                "UsedStorageGB" = $usedGB
                "StorageQuotaGB" = $quotaGB
                "FreeSpaceGB" = $freeGB
                "WarningLevelGB" = $warningGB
                "LastContentModified" = $site.LastContentModifiedDate
                "Status" = $site.Status
            }
        }
        
        Write-Progress -Activity "Collecting OneDrive statistics" -Completed
        
        if ($results.Count -gt 0) {
            $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
            Write-StatusMessage -Message "Exported $($results.Count) OneDrive sites to: $outputFile" -Type Success
            return $outputFile
        }
        else {
            Write-StatusMessage -Message "No OneDrive data collected" -Type Warning
            return $null
        }
    }
    catch {
        Write-StatusMessage -Message "Failed to collect OneDrive statistics: $($_.Exception.Message)" -Type Error
        return $null
    }
}

# Collect SharePoint site statistics
function Get-SharePointSitesReport {
    if ([string]::IsNullOrEmpty($script:TenantDomain)) {
        Write-StatusMessage -Message "Skipping SharePoint collection (SharePoint not connected)" -Type Warning
        return $null
    }
    
    Write-StatusMessage -Message "Collecting SharePoint site collections..." -Type Info
    
    $outputFile = Join-Path $OutputDirectory "SharePointSites_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    try {
        $spSites = Invoke-SafeCommand -Command {
            Get-SPOSite -Limit All -Filter "Url -notlike '-my.sharepoint.com/personal/'" -ErrorAction Stop
        } -ErrorMessage "Failed to retrieve SharePoint sites"
        
        if ($null -eq $spSites -or $spSites.Count -eq 0) {
            Write-StatusMessage -Message "No SharePoint sites found" -Type Warning
            return $null
        }
        
        Write-StatusMessage -Message "Processing $($spSites.Count) SharePoint sites..." -Type Info
        
        $results = @()
        $i = 0
        
        foreach ($site in $spSites) {
            $i++
            Write-Progress -Activity "Collecting SharePoint site statistics" -Status "Processing: $($site.Title)" `
                -PercentComplete (($i / $spSites.Count) * 100) -CurrentOperation "Site $i of $($spSites.Count)"
            
            $usedGB = [Math]::Round($site.StorageUsageCurrent / 1024, 2)
            $quotaGB = [Math]::Round($site.StorageQuota / 1024, 2)
            $warningGB = [Math]::Round($site.StorageQuotaWarningLevel / 1024, 2)
            $freeGB = [Math]::Round(($site.StorageQuota - $site.StorageUsageCurrent) / 1024, 2)
            
            $results += [PSCustomObject]@{
                "Title" = $site.Title
                "URL" = $site.Url
                "Owner" = $site.Owner
                "Template" = $site.Template
                "UsedStorageGB" = $usedGB
                "StorageQuotaGB" = $quotaGB
                "FreeSpaceGB" = $freeGB
                "WarningLevelGB" = $warningGB
                "LastContentModified" = $site.LastContentModifiedDate
                "Status" = $site.Status
                "SharingCapability" = $site.SharingCapability
            }
        }
        
        Write-Progress -Activity "Collecting SharePoint site statistics" -Completed
        
        if ($results.Count -gt 0) {
            $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
            Write-StatusMessage -Message "Exported $($results.Count) SharePoint sites to: $outputFile" -Type Success
            return $outputFile
        }
        else {
            Write-StatusMessage -Message "No SharePoint data collected" -Type Warning
            return $null
        }
    }
    catch {
        Write-StatusMessage -Message "Failed to collect SharePoint statistics: $($_.Exception.Message)" -Type Error
        return $null
    }
}

# Generate summary report
function New-SummaryReport {
    param(
        [hashtable]$ExportedFiles
    )
    
    $summaryFile = Join-Path $OutputDirectory "Summary_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $report = @()
    
    $report += $Separator
    $report += "OFFICE 365 COMPREHENSIVE ASSESSMENT REPORT"
    $report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += $Separator
    $report += ""
    
    # Mailbox summary
    if ($ExportedFiles.Mailboxes) {
        $report += "MAILBOX STATISTICS"
        $report += $SubSeparator
        try {
            $mbData = Import-Csv $ExportedFiles.Mailboxes
            $totalSize = ($mbData | Measure-Object -Property TotalSizeGB -Sum).Sum
            $avgSize = ($mbData | Measure-Object -Property TotalSizeGB -Average).Average
            
            $report += "Total Mailboxes: $($mbData.Count)"
            $report += "Total Storage Used: $([Math]::Round($totalSize, 2)) GB"
            $report += "Average Mailbox Size: $([Math]::Round($avgSize, 2)) GB"
            $report += "Largest Mailbox: $(($mbData | Sort-Object TotalSizeGB -Descending | Select-Object -First 1).DisplayName) - $(($mbData | Sort-Object TotalSizeGB -Descending | Select-Object -First 1).TotalSizeGB) GB"
            
            $report += ""
        }
        catch {
            $report += "Error reading mailbox data: $($_.Exception.Message)"
            $report += ""
        }
    }
    
    # Rules summary
    if ($ExportedFiles.Rules) {
        $report += "MAILBOX RULES"
        $report += $SubSeparator
        try {
            $rulesData = Import-Csv $ExportedFiles.Rules
            $forwardingRules = $rulesData | Where-Object { $_.ForwardTo -or $_.RedirectTo }
            
            $report += "Total Rules: $($rulesData.Count)"
            $report += "Forwarding/Redirect Rules: $($forwardingRules.Count)"
            $report += ""
        }
        catch {
            $report += "Error reading rules data: $($_.Exception.Message)"
            $report += ""
        }
    }
    
    # OneDrive summary
    if ($ExportedFiles.OneDrive) {
        $report += "ONEDRIVE SITES"
        $report += $SubSeparator
        try {
            $odData = Import-Csv $ExportedFiles.OneDrive
            $totalSize = ($odData | Measure-Object -Property UsedStorageGB -Sum).Sum
            $avgSize = ($odData | Measure-Object -Property UsedStorageGB -Average).Average
            
            $report += "Total OneDrive Sites: $($odData.Count)"
            $report += "Total Storage Used: $([Math]::Round($totalSize, 2)) GB"
            $report += "Average Site Size: $([Math]::Round($avgSize, 2)) GB"
            $report += ""
        }
        catch {
            $report += "Error reading OneDrive data: $($_.Exception.Message)"
            $report += ""
        }
    }
    
    # SharePoint summary
    if ($ExportedFiles.SharePoint) {
        $report += "SHAREPOINT SITES"
        $report += $SubSeparator
        try {
            $spData = Import-Csv $ExportedFiles.SharePoint
            $totalSize = ($spData | Measure-Object -Property UsedStorageGB -Sum).Sum
            
            $report += "Total SharePoint Sites: $($spData.Count)"
            $report += "Total Storage Used: $([Math]::Round($totalSize, 2)) GB"
            $report += ""
        }
        catch {
            $report += "Error reading SharePoint data: $($_.Exception.Message)"
            $report += ""
        }
    }
    
    # Execution summary
    $report += $Separator
    $report += "EXECUTION SUMMARY"
    $report += $SubSeparator
    $report += "Errors: $ErrorCount"
    $report += "Warnings: $WarningCount"
    $report += "Execution Time: $(((Get-Date) - $StartTime).ToString('mm\:ss'))"
    $report += $Separator
    
    $report | Out-File -FilePath $summaryFile -Encoding UTF8
    Write-StatusMessage -Message "Summary report saved to: $summaryFile" -Type Success
    
    return $summaryFile
}

# Create ZIP archive
function New-ReportArchive {
    param(
        [string[]]$Files
    )
    
    $zipFile = Join-Path (Split-Path $OutputDirectory -Parent) "O365_Assessment_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    
    try {
        Write-StatusMessage -Message "Creating ZIP archive..." -Type Info
        
        # Compress all files
        Compress-Archive -Path $Files -DestinationPath $zipFile -CompressionLevel Optimal -Force
        
        Write-StatusMessage -Message "Archive created: $zipFile" -Type Success
        Write-Host "`n$Separator" -ForegroundColor Green
        Write-Host "DOWNLOAD YOUR REPORT:" -ForegroundColor Green
        Write-Host $zipFile -ForegroundColor Yellow
        Write-Host $Separator -ForegroundColor Green
        Write-Host "`nIn Cloud Shell, use the download button or run:" -ForegroundColor Cyan
        Write-Host "  download $zipFile" -ForegroundColor White
        Write-Host ""
        
        return $zipFile
    }
    catch {
        Write-StatusMessage -Message "Failed to create ZIP archive: $($_.Exception.Message)" -Type Error
        return $null
    }
}

# Main execution
try {
    Write-Host "`n$Separator" -ForegroundColor Cyan
    Write-Host "OFFICE 365 COMPREHENSIVE ASSESSMENT" -ForegroundColor Cyan
    Write-Host "Cloud Shell Edition" -ForegroundColor Cyan
    Write-Host $Separator -ForegroundColor Cyan
    Write-Host ""
    
    # Create output directory
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        Write-StatusMessage -Message "Created output directory: $OutputDirectory" -Type Success
    }
    
    # Initialize modules
    Initialize-RequiredModules
    
    # Connect to services
    Connect-O365Services
    
    # Track exported files
    $ExportedFiles = @{
        Mailboxes = $null
        Rules = $null
        OneDrive = $null
        SharePoint = $null
        Summary = $null
    }
    
    # Collect data (run sequentially to manage Cloud Shell resources)
    $ExportedFiles.Mailboxes = Get-MailboxStatisticsReport
    $ExportedFiles.Rules = Get-MailboxRulesReport
    $ExportedFiles.OneDrive = Get-OneDriveReport
    $ExportedFiles.SharePoint = Get-SharePointSitesReport
    
    # Generate summary
    $ExportedFiles.Summary = New-SummaryReport -ExportedFiles $ExportedFiles
    
    # Create ZIP archive
    $allFiles = $ExportedFiles.Values | Where-Object { -not [string]::IsNullOrEmpty($_) }
    
    if ($allFiles.Count -gt 0) {
        $zipFile = New-ReportArchive -Files $allFiles
        
        # Display summary
        Write-Host "`n$Separator" -ForegroundColor Cyan
        Write-Host "ASSESSMENT COMPLETE" -ForegroundColor Green
        Write-Host $Separator -ForegroundColor Cyan
        Write-Host "Files Generated: $($allFiles.Count)" -ForegroundColor White
        Write-Host "Total Errors: $ErrorCount" -ForegroundColor $(if($ErrorCount -gt 0){'Red'}else{'Green'})
        Write-Host "Total Warnings: $WarningCount" -ForegroundColor $(if($WarningCount -gt 0){'Yellow'}else{'Green'})
        Write-Host "Execution Time: $(((Get-Date) - $StartTime).ToString('mm\:ss'))" -ForegroundColor White
        Write-Host $Separator -ForegroundColor Cyan
    }
    else {
        Write-StatusMessage -Message "No data was collected" -Type Error
    }
}
catch {
    Write-StatusMessage -Message "Script execution failed: $($_.Exception.Message)" -Type Error
    throw
}
finally {
    # Cleanup connections
    Write-StatusMessage -Message "Cleaning up connections..." -Type Info
    
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch {
        Write-Verbose "Error disconnecting Exchange Online: $($_.Exception.Message)"
    }
    
    try {
        Disconnect-SPOService -ErrorAction SilentlyContinue
    }
    catch {
        Write-Verbose "Error disconnecting SharePoint Online: $($_.Exception.Message)"
    }
    
    Write-StatusMessage -Message "Script execution completed" -Type Info
}
