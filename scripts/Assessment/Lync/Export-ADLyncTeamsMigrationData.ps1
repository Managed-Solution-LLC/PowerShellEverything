<#
.SYNOPSIS
    Exports Active Directory user information for Lync to Teams migration analysis
.DESCRIPTION
    This script exports comprehensive Active Directory user data focusing on attributes that
    are relevant for Lync/Skype for Business to Microsoft Teams migration. It captures:
    
    - Standard user information (Name, UPN, Email, etc.)
    - Lync/SfB specific attributes (msRTCSIP-*, proxyAddresses)
    - Corporate telephone numbers and extension information
    - SIP addresses and voice routing attributes
    - Account status and organizational information
    - Teams migration readiness indicators
    
    The output helps identify users that need attribute cleanup before Teams migration
    and ensures proper extension dialing configuration for cloud voice services.
    
.PARAMETER OutputDirectory
    The directory where the exported CSV files will be saved
.PARAMETER OrganizationName
    The name of the organization for report headers
.PARAMETER IncludeDisabledUsers
    Include disabled user accounts in the export
.PARAMETER IncludeServiceAccounts
    Include service accounts (typically Lync device accounts)
.PARAMETER ExportToCsv
    Export results to CSV files
.PARAMETER SearchBase
    Specific OU to search (default: entire domain)
.PARAMETER MaxUsers
    Maximum number of users to process (default: unlimited)
.PARAMETER SipUsersOnly
    Export only users that have SIP addresses (Lync/SfB enabled users)
    
.EXAMPLE
    .\Export-ADLyncTeamsMigrationData.ps1 -OrganizationName "Contoso" -ExportToCsv
    
.EXAMPLE
    .\Export-ADLyncTeamsMigrationData.ps1 -OrganizationName "Contoso" -SipUsersOnly -ExportToCsv
    
.EXAMPLE
    .\Export-ADLyncTeamsMigrationData.ps1 -OrganizationName "Contoso" -IncludeDisabledUsers -IncludeServiceAccounts -SearchBase "OU=Users,DC=contoso,DC=com"
    
.NOTES
    Author: W. Ford
    Date: 2025-09-24
    Version: 1.0
    
    Requirements:
    - Active Directory PowerShell module
    - Appropriate permissions to read AD user attributes
    - Access to Lync/SfB specific attributes
    
    This script is specifically designed for organizations migrating from Lync/Skype for Business
    on-premises to Microsoft Teams in the cloud.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputDirectory = "C:\Reports\Teams_Migration_AD_Export",
    
    [Parameter(Mandatory=$false)]
    [string]$OrganizationName = "Organization",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeDisabledUsers,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeServiceAccounts,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportToCsv,
    
    [Parameter(Mandatory=$false)]
    [string]$SearchBase,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxUsers = 0,
    
    [Parameter(Mandatory=$false)]
    [switch]$SipUsersOnly
)

# Import required modules
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "✅ Active Directory module loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load Active Directory module: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Please install RSAT or run on a domain controller" -ForegroundColor Yellow
    exit 1
}

$Separator = "=" * 80

# Create output directory
if ($ExportToCsv -and !(Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force
    Write-Host "Created directory: $OutputDirectory" -ForegroundColor Green
}

Write-Host $Separator -ForegroundColor Cyan
Write-Host "$OrganizationName - ACTIVE DIRECTORY LYNC TO TEAMS MIGRATION EXPORT" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host ""

# Define Lync/SfB specific attributes to retrieve
$StandardAttributes = @(
    # Standard AD attributes
    'DisplayName', 'GivenName', 'Surname', 'SamAccountName', 'UserPrincipalName', 
    'EmailAddress', 'Enabled', 'DistinguishedName', 'Department', 'Title', 'Office',
    'Company', 'Manager', 'WhenCreated', 'WhenChanged', 'LastLogonDate',
    
    # Telephone attributes
    'TelephoneNumber', 'HomePhone', 'MobilePhone', 'Fax', 'IPPhone', 'OtherTelephone',
    
    # Exchange/Email attributes
    'ProxyAddresses', 'Mail', 'MailNickname', 'LegacyExchangeDN',
    
    # Object class and category
    'ObjectClass', 'ObjectCategory'
)

# Lync/SfB specific attributes (these may not all exist in every environment)
$LyncAttributes = @(
    'msRTCSIP-UserEnabled', 'msRTCSIP-PrimaryUserAddress', 'msRTCSIP-PrimaryHomeServer',
    'msRTCSIP-UserPolicies', 'msRTCSIP-OptionFlags', 'msRTCSIP-FederationEnabled',
    'msRTCSIP-InternetAccessEnabled', 'msRTCSIP-EnabledForRichPresence',
    'msRTCSIP-PublicNetworkEnabled', 'msRTCSIP-EnterpriseVoiceEnabled',
    'msRTCSIP-LineURI', 'msRTCSIP-Line', 'msRTCSIP-OwnerUrn', 'msRTCSIP-DeploymentLocator',
    'msRTCSIP-ArchivingEnabled', 'msRTCSIP-TenantId',
    'msRTCSIP-ApplicationOptions', 'msRTCSIP-ApplicationDestination'
)

# Test which Lync attributes exist in the schema
Write-Host "🔍 Testing Lync/SfB attribute availability..." -ForegroundColor Yellow
$AvailableAttributes = $StandardAttributes + @()

foreach ($Attribute in $LyncAttributes) {
    try {
        # Test the attribute by trying to query with it
        Get-ADUser -Filter "SamAccountName -eq 'NonExistentUser'" -Properties $Attribute -ErrorAction Stop | Out-Null
        $AvailableAttributes += $Attribute
        Write-Host "   ✅ $Attribute" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️  $Attribute - Not available or accessible" -ForegroundColor Yellow
    }
}

Write-Host "✅ Found $($AvailableAttributes.Count) available attributes" -ForegroundColor Green

# Build search parameters
$SearchParams = @{
    Filter = '*'
    Properties = $AvailableAttributes
}

if ($SearchBase) {
    $SearchParams.SearchBase = $SearchBase
    Write-Host "🔍 Searching in: $SearchBase" -ForegroundColor Yellow
} else {
    Write-Host "🔍 Searching entire domain" -ForegroundColor Yellow
}

# Determine user filter
if (-not $IncludeDisabledUsers) {
    $SearchParams.Filter = 'Enabled -eq $true'
}

Write-Host "📊 Retrieving user accounts from Active Directory..." -ForegroundColor Yellow

try {
    $AllUsers = Get-ADUser @SearchParams
    Write-Host "✅ Retrieved $($AllUsers.Count) user accounts" -ForegroundColor Green
} catch {
    Write-Host "❌ Error retrieving users: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Filter users based on parameters
$FilteredUsers = $AllUsers

# Exclude service accounts if requested
if (-not $IncludeServiceAccounts) {
    $FilteredUsers = $FilteredUsers | Where-Object {
        $_.SamAccountName -notmatch '^(svc|service|admin|test|lync|skype|sfb|teams|room|device|common|phone)' -and
        $_.DisplayName -notmatch '^(Service|Admin|Test|Lync|Skype|SfB|Teams|Room|Device|Common|Phone)'
    }
}

# Limit users if specified
if ($MaxUsers -gt 0 -and $FilteredUsers.Count -gt $MaxUsers) {
    $FilteredUsers = $FilteredUsers | Select-Object -First $MaxUsers
    Write-Host "⚠️  Limited to first $MaxUsers users as requested" -ForegroundColor Yellow
}

Write-Host "📋 Processing $($FilteredUsers.Count) users for migration analysis..." -ForegroundColor Yellow

# Process users and build export data
$ExportData = @()
$LyncEnabledUsers = 0
$VoiceEnabledUsers = 0
$UsersWithTelephoneNumbers = 0
$UsersWithSipAddresses = 0
$UsersWithIssues = @()

foreach ($User in $FilteredUsers) {
    # Extract corporate telephone info
    $CorporateTelephone = $null
    $Extension = $null
    
    if ($User.TelephoneNumber) {
        $CorporateTelephone = $User.TelephoneNumber
        # Try to extract extension (common formats: +1234567890x123, (123)456-7890 x123, etc.)
        if ($CorporateTelephone -match 'x(\d+)$|ext\.?\s*(\d+)$|extension\s*(\d+)$') {
            $Extension = $matches[1] + $matches[2] + $matches[3]  # One will be populated
        }
    }
    
    # Analyze Lync/SfB attributes (safely handle missing attributes)
    $IsLyncEnabled = $false
    $IsVoiceEnabled = $false
    $SipAddress = $null
    $LineURI = $null
    $LyncHomeServer = $null
    
    # Safely get Lync attributes
    try {
        if ($User.PSObject.Properties['msRTCSIP-UserEnabled'] -and $User.'msRTCSIP-UserEnabled') {
            $IsLyncEnabled = $true
            $LyncEnabledUsers++
        }
    } catch { }
    
    try {
        if ($User.PSObject.Properties['msRTCSIP-EnterpriseVoiceEnabled'] -and $User.'msRTCSIP-EnterpriseVoiceEnabled') {
            $IsVoiceEnabled = $true
            $VoiceEnabledUsers++
        }
    } catch { }
    
    try {
        if ($User.PSObject.Properties['msRTCSIP-PrimaryUserAddress'] -and $User.'msRTCSIP-PrimaryUserAddress') {
            $SipAddress = $User.'msRTCSIP-PrimaryUserAddress'
            $UsersWithSipAddresses++
        }
    } catch { }
    
    try {
        if ($User.PSObject.Properties['msRTCSIP-LineURI'] -and $User.'msRTCSIP-LineURI') {
            $LineURI = $User.'msRTCSIP-LineURI'
        }
    } catch { }
    
    try {
        if ($User.PSObject.Properties['msRTCSIP-PrimaryHomeServer'] -and $User.'msRTCSIP-PrimaryHomeServer') {
            $LyncHomeServer = $User.'msRTCSIP-PrimaryHomeServer'
        }
    } catch { }
    
    # Count users with telephone numbers
    if ($CorporateTelephone) {
        $UsersWithTelephoneNumbers++
    }
    
    # Analyze proxy addresses for SIP
    $ProxyAddresses = @()
    $SipProxyAddresses = @()
    if ($User.ProxyAddresses) {
        $ProxyAddresses = $User.ProxyAddresses
        $SipProxyAddresses = $ProxyAddresses | Where-Object { $_ -match '^sip:' }
    }
    
    # Identify potential issues
    $Issues = @()
    if ($IsLyncEnabled -and -not $SipAddress) {
        $Issues += "Lync enabled but no SIP address"
    }
    if ($IsVoiceEnabled -and -not $LineURI -and -not $CorporateTelephone) {
        $Issues += "Voice enabled but no phone number"
    }
    if ($SipAddress -and $User.EmailAddress -and ($SipAddress -replace '^sip:', '') -ne $User.EmailAddress) {
        $Issues += "SIP address doesn't match email"
    }
    if (-not $User.EmailAddress) {
        $Issues += "No email address"
    }
    if ($CorporateTelephone -and $LineURI -and $CorporateTelephone -ne ($LineURI -replace '^tel:', '')) {
        $Issues += "Telephone number mismatch with LineURI"
    }
    
    if ($Issues.Count -gt 0) {
        $UsersWithIssues += $User
    }
    
    # Determine migration readiness
    $MigrationReadiness = "Ready"
    if ($Issues.Count -gt 0) {
        $MigrationReadiness = "Needs Attention"
    } elseif (-not $IsLyncEnabled -and $User.Enabled) {
        $MigrationReadiness = "New User"
    } elseif (-not $User.Enabled) {
        $MigrationReadiness = "Disabled"
    }
    
    # Build export record
    $ExportRecord = [PSCustomObject]@{
        # Basic User Info
        DisplayName = $User.DisplayName
        FirstName = $User.GivenName
        LastName = $User.Surname
        SamAccountName = $User.SamAccountName
        UserPrincipalName = $User.UserPrincipalName
        EmailAddress = $User.EmailAddress
        Enabled = $User.Enabled
        
        # Organizational Info
        Department = $User.Department
        Title = $User.Title
        Office = $User.Office
        Company = $User.Company
        Manager = $User.Manager
        
        # Telephone Information
        CorporateTelephone = $CorporateTelephone
        Extension = $Extension
        MobilePhone = $User.MobilePhone
        HomePhone = $User.HomePhone
        IPPhone = $User.IPPhone
        Fax = $User.Fax
        
        # Lync/SfB Status
        LyncEnabled = $IsLyncEnabled
        VoiceEnabled = $IsVoiceEnabled
        SipAddress = $SipAddress
        LineURI = $LineURI
        LyncHomeServer = $LyncHomeServer
        
        # Lync Policies and Settings (safely handle missing attributes)
        UserPolicies = if ($User.PSObject.Properties['msRTCSIP-UserPolicies']) { $User.'msRTCSIP-UserPolicies' } else { $null }
        FederationEnabled = if ($User.PSObject.Properties['msRTCSIP-FederationEnabled']) { $User.'msRTCSIP-FederationEnabled' } else { $null }
        InternetAccessEnabled = if ($User.PSObject.Properties['msRTCSIP-InternetAccessEnabled']) { $User.'msRTCSIP-InternetAccessEnabled' } else { $null }
        RichPresenceEnabled = if ($User.PSObject.Properties['msRTCSIP-EnabledForRichPresence']) { $User.'msRTCSIP-EnabledForRichPresence' } else { $null }
        PublicNetworkEnabled = if ($User.PSObject.Properties['msRTCSIP-PublicNetworkEnabled']) { $User.'msRTCSIP-PublicNetworkEnabled' } else { $null }
        ArchivingEnabled = if ($User.PSObject.Properties['msRTCSIP-ArchivingEnabled']) { $User.'msRTCSIP-ArchivingEnabled' } else { $null }
        
        # Proxy Addresses
        ProxyAddressesCount = $ProxyAddresses.Count
        SipProxyAddressesCount = $SipProxyAddresses.Count
        PrimaryProxyAddress = ($ProxyAddresses | Where-Object { $_ -match '^SMTP:' }) -join '; '
        
        # Migration Analysis
        MigrationReadiness = $MigrationReadiness
        Issues = $Issues -join '; '
        IssueCount = $Issues.Count
        
        # Technical Details
        DistinguishedName = $User.DistinguishedName
        WhenCreated = $User.WhenCreated
        WhenChanged = $User.WhenChanged
        LastLogon = $User.LastLogonDate
        
        # Teams Preparation
        TeamsPhoneSystemRequired = $IsVoiceEnabled
        ExtensionDialingReady = ($null -ne $Extension)
        CloudVoiceReady = ($IsVoiceEnabled -and ($null -ne $CorporateTelephone -or $null -ne $LineURI))
    }
    
    $ExportData += $ExportRecord
}

# Filter to SIP users only if requested
if ($SipUsersOnly) {
    $OriginalCount = $ExportData.Count
    $ExportData = $ExportData | Where-Object { $null -ne $_.SipAddress -or $_.LyncEnabled -eq $true }
    Write-Host "🔍 Filtered to SIP users only: $($ExportData.Count) of $OriginalCount users" -ForegroundColor Yellow
}

# Generate summary statistics
Write-Host ""
Write-Host $Separator -ForegroundColor Green
Write-Host "MIGRATION ANALYSIS SUMMARY" -ForegroundColor Green
Write-Host $Separator -ForegroundColor Green

Write-Host "👥 User Statistics:" -ForegroundColor Cyan
Write-Host "   Total Users Processed: $($FilteredUsers.Count)" -ForegroundColor White
Write-Host "   Lync Enabled Users: $LyncEnabledUsers" -ForegroundColor White
Write-Host "   Voice Enabled Users: $VoiceEnabledUsers" -ForegroundColor White
Write-Host "   Users with Telephone Numbers: $UsersWithTelephoneNumbers" -ForegroundColor White
Write-Host "   Users with SIP Addresses: $UsersWithSipAddresses" -ForegroundColor White

$ReadinessStats = $ExportData | Group-Object MigrationReadiness
Write-Host ""
Write-Host "🚀 Migration Readiness:" -ForegroundColor Cyan
foreach ($Status in $ReadinessStats) {
    $Color = switch ($Status.Name) {
        "Ready" { "Green" }
        "New User" { "Yellow" }
        "Needs Attention" { "Red" }
        "Disabled" { "Gray" }
        default { "White" }
    }
    Write-Host "   $($Status.Name): $($Status.Count)" -ForegroundColor $Color
}

# Extension dialing analysis
$UsersWithExtensions = $ExportData | Where-Object { $null -ne $_.Extension }
$VoiceUsersWithoutExtensions = $ExportData | Where-Object { $_.VoiceEnabled -and $null -eq $_.Extension }

Write-Host ""
Write-Host "☎️ Extension Dialing Analysis:" -ForegroundColor Cyan
Write-Host "   Users with Extensions: $($UsersWithExtensions.Count)" -ForegroundColor White
Write-Host "   Voice Users without Extensions: $($VoiceUsersWithoutExtensions.Count)" -ForegroundColor $(if ($VoiceUsersWithoutExtensions.Count -gt 0) { "Red" } else { "Green" })
Write-Host "   Extension Dialing Readiness: $(if ($VoiceUsersWithoutExtensions.Count -eq 0) { "100%" } else { [math]::Round((($UsersWithExtensions.Count / ($UsersWithExtensions.Count + $VoiceUsersWithoutExtensions.Count)) * 100), 1).ToString() + "%" })" -ForegroundColor White

# Common issues
$CommonIssues = $ExportData | Where-Object { $_.IssueCount -gt 0 } | 
    ForEach-Object { $_.Issues -split '; ' } | 
    Group-Object | Sort-Object Count -Descending

if ($CommonIssues) {
    Write-Host ""
    Write-Host "⚠️ Common Migration Issues:" -ForegroundColor Red
    foreach ($Issue in ($CommonIssues | Select-Object -First 5)) {
        Write-Host "   $($Issue.Name): $($Issue.Count) users" -ForegroundColor Yellow
    }
}

# Export to CSV if requested
if ($ExportToCsv) {
    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    
    # Main export file
    $MainExportFile = "$OutputDirectory\AD_LyncTeams_Migration_Export_$Timestamp.csv"
    $ExportData | Export-Csv -Path $MainExportFile -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host "✅ Main export saved: $MainExportFile" -ForegroundColor Green
    
    # Users needing attention
    $IssuesFile = "$OutputDirectory\AD_Users_Needing_Attention_$Timestamp.csv"
    $ExportData | Where-Object { $_.MigrationReadiness -eq "Needs Attention" } | 
        Export-Csv -Path $IssuesFile -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Users with issues saved: $IssuesFile" -ForegroundColor Green
    
    # Voice users without extensions
    if ($VoiceUsersWithoutExtensions.Count -gt 0) {
        $ExtensionIssuesFile = "$OutputDirectory\AD_VoiceUsers_Without_Extensions_$Timestamp.csv"
        $VoiceUsersWithoutExtensions | Export-Csv -Path $ExtensionIssuesFile -NoTypeInformation -Encoding UTF8
        Write-Host "✅ Voice users without extensions saved: $ExtensionIssuesFile" -ForegroundColor Green
    }
    
    # Summary report
    $SummaryFile = "$OutputDirectory\AD_Migration_Summary_$Timestamp.txt"
    $SummaryReport = @()
    $SummaryReport += "$OrganizationName - Active Directory Migration Analysis Summary"
    $SummaryReport += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $SummaryReport += $Separator
    $SummaryReport += ""
    $SummaryReport += "USER STATISTICS:"
    $SummaryReport += "Total Users Processed: $($FilteredUsers.Count)"
    $SummaryReport += "Lync Enabled Users: $LyncEnabledUsers"
    $SummaryReport += "Voice Enabled Users: $VoiceEnabledUsers"
    $SummaryReport += "Users with Telephone Numbers: $UsersWithTelephoneNumbers"
    $SummaryReport += "Users with SIP Addresses: $UsersWithSipAddresses"
    $SummaryReport += ""
    $SummaryReport += "MIGRATION READINESS:"
    foreach ($Status in $ReadinessStats) {
        $SummaryReport += "$($Status.Name): $($Status.Count)"
    }
    $SummaryReport += ""
    $SummaryReport += "EXTENSION DIALING:"
    $SummaryReport += "Users with Extensions: $($UsersWithExtensions.Count)"
    $SummaryReport += "Voice Users without Extensions: $($VoiceUsersWithoutExtensions.Count)"
    
    if ($CommonIssues) {
        $SummaryReport += ""
        $SummaryReport += "COMMON ISSUES:"
        foreach ($Issue in ($CommonIssues | Select-Object -First 10)) {
            $SummaryReport += "$($Issue.Name): $($Issue.Count) users"
        }
    }
    
    $SummaryReport | Out-File -FilePath $SummaryFile -Encoding UTF8
    Write-Host "✅ Summary report saved: $SummaryFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎯 Next Steps for Teams Migration:" -ForegroundColor Cyan
Write-Host "   1. Review users needing attention and resolve issues" -ForegroundColor White
Write-Host "   2. Ensure all voice users have proper extension configuration" -ForegroundColor White
Write-Host "   3. Validate SIP addresses match email addresses" -ForegroundColor White
Write-Host "   4. Plan Phone System licensing for voice-enabled users" -ForegroundColor White
Write-Host "   5. Configure calling plans or direct routing for PSTN connectivity" -ForegroundColor White

Write-Host ""
Write-Host "✨ Analysis Complete! Use the exported data to plan your Teams migration." -ForegroundColor Green