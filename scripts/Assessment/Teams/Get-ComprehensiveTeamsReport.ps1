<#
.SYNOPSIS
    Generates a comprehensive Microsoft Teams infrastructure report.

.DESCRIPTION
    This script generates a detailed comprehensive report of a Microsoft Teams environment,
    including tenant configuration, Teams policies, voice infrastructure, meeting settings,
    compliance features, licensing analysis, and infrastructure recommendations. The report 
    provides administrators with a complete overview of their Teams deployment status and health.

.PARAMETER TenantId
    The Azure AD tenant ID for the Teams environment to analyze. If not specified, uses the 
    current connected tenant context.

.PARAMETER ReportPath
    The file path where the comprehensive report will be saved. If not specified, defaults to
    "C:\Reports\Teams_Infrastructure_Report_[timestamp].txt".

.PARAMETER OrganizationName
    The name of the organization for which the report is being generated. Used in the report header
    and organizational context throughout the report.

.PARAMETER IncludeUserDetails
    Switch parameter to include detailed user information in the report. This will add user
    licensing, policy assignments, and usage statistics.

.PARAMETER IncludeVoiceAnalysis
    Switch parameter to include detailed voice infrastructure analysis including calling plans,
    direct routing configuration, and SBC status.

.PARAMETER IncludeComplianceAnalysis
    Switch parameter to include compliance and security analysis including DLP policies,
    retention policies, and audit configurations.

.PARAMETER ExportToCSV
    Switch parameter to also export detailed data to CSV files for further analysis.

.EXAMPLE
    .\Get-ComprehensiveTeamsReport.ps1
    
    Generates a basic comprehensive report for the current tenant using default settings.

.EXAMPLE
    .\Get-ComprehensiveTeamsReport.ps1 -OrganizationName "Contoso Corp" -ReportPath "D:\Reports\Contoso_Teams_Report.txt" -IncludeUserDetails
    
    Generates a comprehensive report with user details for Contoso Corp.

.EXAMPLE
    .\Get-ComprehensiveTeamsReport.ps1 -IncludeVoiceAnalysis -IncludeComplianceAnalysis -ExportToCSV
    
    Generates a full comprehensive report including voice and compliance analysis with CSV exports.

.NOTES
    Author: W. Ford
    Date: 2025-09-24
    Version: 1.0
    
    Requirements:
    - Microsoft Teams PowerShell Module (MicrosoftTeams)
    - Microsoft Graph PowerShell SDK (Microsoft.Graph)
    - Exchange Online PowerShell Module (ExchangeOnlineManagement) - for compliance features
    - Global Administrator or Teams Administrator privileges
    - PowerShell 5.1 or PowerShell 7.0+
    
    The script performs comprehensive analysis including:
    - Executive summary with environment overview
    - Tenant configuration and settings
    - Teams policies analysis (meeting, messaging, app policies)
    - Voice infrastructure assessment
    - Meeting and calling configuration
    - Compliance and security features
    - User licensing and distribution
    - Teams and channels statistics
    - Device and app usage analysis
    - Infrastructure health summary
    - Detailed recommendations for optimization

.LINK
    https://docs.microsoft.com/en-us/microsoftteams/

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Azure AD tenant ID")]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false, HelpMessage="Path where the report will be saved")]
    [string]$ReportPath = "C:\Reports\Teams_Infrastructure_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt",
    
    [Parameter(Mandatory=$false, HelpMessage="Organization name for the report header")]
    [string]$OrganizationName = "Organization",
    
    [Parameter(Mandatory=$false, HelpMessage="Include detailed user information")]
    [switch]$IncludeUserDetails,
    
    [Parameter(Mandatory=$false, HelpMessage="Include voice infrastructure analysis")]
    [switch]$IncludeVoiceAnalysis,
    
    [Parameter(Mandatory=$false, HelpMessage="Include compliance and security analysis")]
    [switch]$IncludeComplianceAnalysis,
    
    [Parameter(Mandatory=$false, HelpMessage="Export detailed data to CSV files")]
    [switch]$ExportToCSV
)

# Initialize script variables
$Separator = "=" * 80
$SubSeparator = "-" * 60
$StartTime = Get-Date
$ErrorCount = 0
$WarningCount = 0

# Create reports directory if it doesn't exist
$ReportsDir = Split-Path $ReportPath -Parent
if (!(Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
}

# Function to write status messages
function Write-StatusMessage {
    param([string]$Message, [string]$Type = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Type) {
        "Error" { Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor Red; $script:ErrorCount++ }
        "Warning" { Write-Host "[$timestamp] WARNING: $Message" -ForegroundColor Yellow; $script:WarningCount++ }
        "Success" { Write-Host "[$timestamp] SUCCESS: $Message" -ForegroundColor Green }
        default { Write-Host "[$timestamp] INFO: $Message" -ForegroundColor Cyan }
    }
}

# Function to safely execute commands and handle errors
function Invoke-SafeCommand {
    param(
        [scriptblock]$Command,
        [string]$ErrorMessage = "Command execution failed"
    )
    try {
        return & $Command
    }
    catch {
        Write-StatusMessage "$ErrorMessage - $($_.Exception.Message)" -Type "Error"
        return $null
    }
}

Write-StatusMessage "Starting Teams Infrastructure Assessment for $OrganizationName"

# Check required modules
$RequiredModules = @('MicrosoftTeams', 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Users', 'Microsoft.Graph.Reports')
if ($IncludeComplianceAnalysis) {
    $RequiredModules += 'ExchangeOnlineManagement'
}

Write-StatusMessage "Checking required PowerShell modules..."
foreach ($Module in $RequiredModules) {
    if (!(Get-Module -ListAvailable -Name $Module -ErrorAction SilentlyContinue)) {
        Write-StatusMessage "Required module '$Module' is not installed. Please install it using: Install-Module $Module" -Type "Error"
        return
    }
}

# Connect to services
Write-StatusMessage "Connecting to Microsoft Teams and Graph services..."
try {
    # Connect to Teams
    if ($TenantId) {
        Connect-MicrosoftTeams -TenantId $TenantId -ErrorAction Stop
    } else {
        Connect-MicrosoftTeams -ErrorAction Stop
    }
    
    # Connect to Microsoft Graph
    $GraphScopes = @(
        'User.Read.All',
        'Group.Read.All',
        'Reports.Read.All',
        'Organization.Read.All',
        'Policy.Read.All',
        'Directory.Read.All',
        'GroupMember.Read.All'
    )
    Connect-MgGraph -Scopes $GraphScopes -NoWelcome -ErrorAction Stop
    
    # Connect to Exchange Online if compliance analysis is requested
    if ($IncludeComplianceAnalysis) {
        Connect-ExchangeOnline -ShowProgress $false -ErrorAction Stop
    }
    
    Write-StatusMessage "Successfully connected to all required services" -Type "Success"
} catch {
    Write-StatusMessage "Failed to connect to required services: $($_.Exception.Message)" -Type "Error"
    return
}

# Initialize report
$Report = @()
$Report += "$OrganizationName"
$Report += "MICROSOFT TEAMS INFRASTRUCTURE REPORT"
$Report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$Report += "Generated By: $($env:USERNAME) on $($env:COMPUTERNAME)"
$Report += $Separator
$Report += ""

# Get tenant information
Write-StatusMessage "Gathering tenant information..."
$TenantInfo = Invoke-SafeCommand { Get-CsTenant } "Failed to get tenant information"
$OrgInfo = Invoke-SafeCommand { Get-MgOrganization } "Failed to get organization information"

# EXECUTIVE SUMMARY
Write-StatusMessage "Generating executive summary..."
$Report += "EXECUTIVE SUMMARY"
$Report += $Separator

try {
    # Get basic statistics
    $AllUsers = Invoke-SafeCommand { Get-CsOnlineUser -ResultSize Unlimited } "Failed to get Teams users"
    $TeamsCount = Invoke-SafeCommand { (Get-Team).Count } "Failed to get Teams count"
    $VoiceUsers = if ($AllUsers) { ($AllUsers | Where-Object { $_.EnterpriseVoiceEnabled -eq $true }).Count } else { 0 }
    $ConferencingUsers = if ($AllUsers) { ($AllUsers | Where-Object { $_.AudioConferencingProvider -ne $null }).Count } else { 0 }
    
    $Report += "Environment Overview:"
    if ($TenantInfo) {
        $Report += "  Tenant ID: $($TenantInfo.TenantId)"
        $Report += "  Teams Tenant: $($TenantInfo.DisplayName)"
        $Report += "  Default Domain: $($TenantInfo.Domains[0])"
    }
    $Report += "  Total Licensed Users: $(if ($AllUsers) { $AllUsers.Count } else { 'Unable to retrieve' })"
    $Report += "  Total Teams: $(if ($TeamsCount -ne $null) { $TeamsCount } else { 'Unable to retrieve' })"
    $Report += "  Voice-Enabled Users: $VoiceUsers"
    $Report += "  Audio Conferencing Users: $ConferencingUsers"
    $Report += ""
    
    # Calculate percentages
    if ($AllUsers -and $AllUsers.Count -gt 0) {
        $VoicePercentage = [Math]::Round(($VoiceUsers / $AllUsers.Count) * 100, 1)
        $ConferencingPercentage = [Math]::Round(($ConferencingUsers / $AllUsers.Count) * 100, 1)
        $Report += "Adoption Metrics:"
        $Report += "  Voice Adoption: $VoicePercentage%"
        $Report += "  Conferencing Adoption: $ConferencingPercentage%"
    }
    $Report += ""
    
} catch {
    Write-StatusMessage "Error in executive summary: $($_.Exception.Message)" -Type "Error"
    $Report += "Error generating executive summary statistics"
    $Report += ""
}

# TENANT CONFIGURATION
Write-StatusMessage "Analyzing tenant configuration..."
$Report += "TENANT CONFIGURATION ANALYSIS"
$Report += $Separator

try {
    if ($TenantInfo) {
        $Report += "TENANT SETTINGS:"
        $Report += "  Organization Name: $($TenantInfo.DisplayName)"
        $Report += "  Country/Region: $($TenantInfo.CountryOrRegionDisplayName)"
        $Report += "  Data Location: $($TenantInfo.ServiceInstance)"
        $Report += "  Teams Upgrade Policy: $($TenantInfo.TeamsUpgradeEffectiveMode)"
        $Report += "  External Access: $(if ($TenantInfo.AllowFederatedUsers) { 'Enabled' } else { 'Disabled' })"
        $Report += "  Guest Access: $(if ($TenantInfo.AllowGuestUser) { 'Enabled' } else { 'Disabled' })"
        $Report += ""
        
        # Meeting settings
        $MeetingConfig = Invoke-SafeCommand { Get-CsTeamsMeetingConfiguration } "Failed to get meeting configuration"
        if ($MeetingConfig) {
            $Report += "MEETING CONFIGURATION:"
            $Report += "  Logo URL: $(if ($MeetingConfig.LogoURL) { $MeetingConfig.LogoURL } else { 'Not configured' })"
            $Report += "  Custom Footer Text: $(if ($MeetingConfig.CustomFooterText) { 'Configured' } else { 'Not configured' })"
            $Report += "  Help URL: $(if ($MeetingConfig.HelpURL) { $MeetingConfig.HelpURL } else { 'Not configured' })"
            $Report += ""
        }
    }
} catch {
    Write-StatusMessage "Error analyzing tenant configuration: $($_.Exception.Message)" -Type "Error"
    $Report += "Error retrieving tenant configuration details"
    $Report += ""
}

# TEAMS POLICIES ANALYSIS
Write-StatusMessage "Analyzing Teams policies..."
$Report += "TEAMS POLICIES ANALYSIS"
$Report += $Separator

try {
    # Meeting Policies
    $MeetingPolicies = Invoke-SafeCommand { Get-CsTeamsMeetingPolicy } "Failed to get meeting policies"
    if ($MeetingPolicies) {
        $Report += "MEETING POLICIES:"
        $Report += "Total Meeting Policies: $($MeetingPolicies.Count)"
        $Report += ""
        
        # Global policy analysis
        $GlobalMeeting = $MeetingPolicies | Where-Object { $_.Identity -eq "Global" }
        if ($GlobalMeeting) {
            $Report += "Global Meeting Policy Settings:"
            $Report += "  Allow Cloud Recording: $($GlobalMeeting.AllowCloudRecording)"
            $Report += "  Allow Transcription: $($GlobalMeeting.AllowTranscription)"
            $Report += "  Allow Anonymous Users to Start: $($GlobalMeeting.AllowAnonymousUsersToStartMeeting)"
            $Report += "  Allow Anonymous Users to Join: $($GlobalMeeting.AllowAnonymousUsersToJoinMeeting)"
            $Report += "  Auto Admit Users: $($GlobalMeeting.AutoAdmittedUsers)"
            $Report += "  Allow Private Meeting Scheduling: $($GlobalMeeting.AllowPrivateMeetingScheduling)"
            $Report += "  Allow Channel Meeting Scheduling: $($GlobalMeeting.AllowChannelMeetingScheduling)"
            $Report += "  Allow Meet Now: $($GlobalMeeting.AllowMeetNow)"
            $Report += "  Allow IP Video: $($GlobalMeeting.AllowIPVideo)"
            $Report += "  Allow IP Audio: $($GlobalMeeting.AllowIPAudio)"
            $Report += "  Media Bit Rate (Kbps): $($GlobalMeeting.MediaBitRateKb)"
            $Report += "  Screen Sharing Mode: $($GlobalMeeting.ScreenSharingMode)"
            $Report += ""
        }
        
        # Show top 5 custom meeting policies
        $CustomMeetingPolicies = $MeetingPolicies | Where-Object { $_.Identity -ne "Global" } | Select-Object -First 5
        if ($CustomMeetingPolicies) {
            $Report += "Custom Meeting Policies (Sample):"
            foreach ($Policy in $CustomMeetingPolicies) {
                $Report += "  Policy: $($Policy.Identity)"
                $Report += "    Cloud Recording: $($Policy.AllowCloudRecording)"
                $Report += "    Transcription: $($Policy.AllowTranscription)"
                $Report += "    Anonymous Start: $($Policy.AllowAnonymousUsersToStartMeeting)"
                $Report += "    Max Participants: $(if ($Policy.MaxMeetingParticipants) { $Policy.MaxMeetingParticipants } else { 'Default' })"
                $Report += ""
            }
        }
    }
    
    # Messaging Policies
    $MessagingPolicies = Invoke-SafeCommand { Get-CsTeamsMessagingPolicy } "Failed to get messaging policies"
    if ($MessagingPolicies) {
        $Report += "MESSAGING POLICIES:"
        $Report += "Total Messaging Policies: $($MessagingPolicies.Count)"
        $Report += ""
        
        $GlobalMessaging = $MessagingPolicies | Where-Object { $_.Identity -eq "Global" }
        if ($GlobalMessaging) {
            $Report += "Global Messaging Policy Settings:"
            $Report += "  Allow User Chat: $($GlobalMessaging.AllowUserChat)"
            $Report += "  Allow User Edit Message: $($GlobalMessaging.AllowUserEditMessage)"
            $Report += "  Allow User Delete Message: $($GlobalMessaging.AllowUserDeleteMessage)"
            $Report += "  Allow Owner Delete Message: $($GlobalMessaging.AllowOwnerDeleteMessage)"
            $Report += "  Allow Remove User: $($GlobalMessaging.AllowRemoveUser)"
            $Report += "  Allow Giphy: $($GlobalMessaging.AllowGiphy)"
            $Report += "  Giphy Rating Type: $($GlobalMessaging.GiphyRatingType)"
            $Report += "  Allow Memes: $($GlobalMessaging.AllowMemes)"
            $Report += "  Allow Stickers: $($GlobalMessaging.AllowStickers)"
            $Report += "  Allow URL Previews: $($GlobalMessaging.AllowUrlPreviews)"
            $Report += "  Allow User Translation: $($GlobalMessaging.AllowUserTranslation)"
            $Report += "  Allow Immersive Reader: $($GlobalMessaging.AllowImmersiveReader)"
            $Report += ""
        }
    }
    
    # Calling Policies
    $CallingPolicies = Invoke-SafeCommand { Get-CsTeamsCallingPolicy } "Failed to get calling policies"
    if ($CallingPolicies) {
        $Report += "CALLING POLICIES:"
        $Report += "Total Calling Policies: $($CallingPolicies.Count)"
        $Report += ""
        
        $GlobalCalling = $CallingPolicies | Where-Object { $_.Identity -eq "Global" }
        if ($GlobalCalling) {
            $Report += "Global Calling Policy Settings:"
            $Report += "  Allow Private Calling: $($GlobalCalling.AllowPrivateCalling)"
            $Report += "  Allow Voicemail: $($GlobalCalling.AllowVoicemail)"
            $Report += "  Allow Call Forwarding: $($GlobalCalling.AllowCallForwarding)"
            $Report += "  Allow Call Redirect: $($GlobalCalling.AllowCallRedirect)"
            $Report += "  Allow Call Groups: $($GlobalCalling.AllowCallGroups)"
            $Report += "  Allow Delegation: $($GlobalCalling.AllowDelegation)"
            $Report += "  Allow Cloud Recording for Calls: $($GlobalCalling.AllowCloudRecordingForCalls)"
            $Report += "  Allow Transcription for Calls: $($GlobalCalling.AllowTranscriptionForCalling)"
            $Report += "  Live Captions Calling Mode: $($GlobalCalling.LiveCaptionsEnabledTypeForCalling)"
            $Report += ""
        }
    }
    
    # App Setup Policies
    $AppPolicies = Invoke-SafeCommand { Get-CsTeamsAppSetupPolicy } "Failed to get app setup policies"
    if ($AppPolicies) {
        $Report += "APP SETUP POLICIES:"
        $Report += "Total App Setup Policies: $($AppPolicies.Count)"
        $Report += ""
        
        $GlobalApp = $AppPolicies | Where-Object { $_.Identity -eq "Global" }
        if ($GlobalApp) {
            $Report += "Global App Setup Policy Settings:"
            $Report += "  Allow User Pinning: $($GlobalApp.AllowUserPinning)"
            $Report += "  Allow Side Loading: $($GlobalApp.AllowSideLoading)"
            $Report += "  Pinned Apps Count: $(if ($GlobalApp.PinnedApps) { $GlobalApp.PinnedApps.Count } else { 0 })"
            if ($GlobalApp.PinnedApps) {
                $PinnedAppNames = $GlobalApp.PinnedApps | ForEach-Object { 
                    if ($_.Id) { $_.Id } elseif ($_.AppId) { $_.AppId } else { "Unknown" }
                } | Select-Object -First 10
                $Report += "  Sample Pinned Apps: $($PinnedAppNames -join ', ')"
            }
            $Report += ""
        }
    }
    
    # Teams Update Policies
    $UpdatePolicies = Invoke-SafeCommand { Get-CsTeamsUpdateManagementPolicy } "Failed to get Teams update policies"
    if ($UpdatePolicies) {
        $Report += "TEAMS UPDATE POLICIES:"
        $Report += "Total Update Policies: $($UpdatePolicies.Count)"
        $Report += ""
        
        foreach ($Policy in $UpdatePolicies | Select-Object -First 5) {
            $Report += "Policy: $($Policy.Identity)"
            $Report += "  Allow M365 Apps: $($Policy.AllowManagedUpdates)"
            $Report += "  Allow Preview Features: $($Policy.AllowPreview)"
            $Report += "  Update Day of Week: $($Policy.UpdateDayOfWeek)"
            $Report += "  Update Time of Day: $($Policy.UpdateTimeOfDay)"
            $Report += ""
        }
    }
    
    # Teams Channels Policies
    $ChannelsPolicies = Invoke-SafeCommand { Get-CsTeamsChannelsPolicy } "Failed to get Teams channels policies"
    if ($ChannelsPolicies) {
        $Report += "TEAMS CHANNELS POLICIES:"
        $Report += "Total Channels Policies: $($ChannelsPolicies.Count)"
        $Report += ""
        
        $GlobalChannels = $ChannelsPolicies | Where-Object { $_.Identity -eq "Global" }
        if ($GlobalChannels) {
            $Report += "Global Channels Policy Settings:"
            $Report += "  Allow Org Wide Team Creation: $($GlobalChannels.AllowOrgWideTeamCreation)"
            $Report += "  Allow Private Team Discovery: $($GlobalChannels.AllowPrivateTeamDiscovery)"
            $Report += "  Allow Channel Sharing: $($GlobalChannels.AllowChannelSharingToExternalUser)"
            $Report += "  Allow Private Channel Creation: $($GlobalChannels.AllowPrivateChannelCreation)"
            $Report += "  Allow Shared Channel Creation: $($GlobalChannels.AllowSharedChannelCreation)"
            $Report += ""
        }
    }
    
    # Teams Education Policies (if applicable)
    $EducationPolicies = Invoke-SafeCommand { Get-CsTeamsEducationAssignmentsAppPolicy } "Failed to get education policies" -SuppressErrors
    if ($EducationPolicies) {
        $Report += "TEAMS EDUCATION POLICIES:"
        $Report += "Total Education Policies: $($EducationPolicies.Count)"
        $Report += ""
    }
    
    # Teams Compliance Recording Policies
    $ComplianceRecordingPolicies = Invoke-SafeCommand { Get-CsTeamsComplianceRecordingPolicy } "Failed to get compliance recording policies" -SuppressErrors
    if ($ComplianceRecordingPolicies) {
        $Report += "COMPLIANCE RECORDING POLICIES:"
        $Report += "Total Compliance Recording Policies: $($ComplianceRecordingPolicies.Count)"
        $Report += ""
        
        foreach ($Policy in $ComplianceRecordingPolicies | Select-Object -First 3) {
            $Report += "Policy: $($Policy.Identity)"
            $Report += "  Enabled: $($Policy.Enabled)"
            $Report += "  Recording Applications: $(if ($Policy.ComplianceRecordingApplications) { $Policy.ComplianceRecordingApplications.Count } else { 0 })"
            $Report += ""
        }
    }
    
    # Policy Assignment Summary
    if ($AllUsers) {
        $Report += "POLICY ASSIGNMENT SUMMARY:"
        $PolicyAssignmentCount = ($AllUsers | Where-Object { 
            $_.TeamsMeetingPolicy -or $_.TeamsMessagingPolicy -or $_.TeamsCallingPolicy -or $_.TeamsAppSetupPolicy 
        }).Count
        $Report += "Users with Policy Assignments: $PolicyAssignmentCount"
        if ($AllUsers.Count -gt 0) {
            $Report += "Policy Assignment Rate: $([Math]::Round(($PolicyAssignmentCount / $AllUsers.Count) * 100, 1))%"
        }
        $Report += ""
    }
    
} catch {
    Write-StatusMessage "Error analyzing Teams policies: $($_.Exception.Message)" -Type "Error"
    $Report += "Error retrieving Teams policies information"
    $Report += ""
}

# PHONE NUMBER INVENTORY
Write-StatusMessage "Analyzing phone number inventory..."
$Report += "PHONE NUMBER INVENTORY"
$Report += $Separator

try {
    # Get phone number assignments
    $PhoneNumbers = Invoke-SafeCommand { Get-CsPhoneNumberAssignment } "Failed to get phone number assignments"
    if ($PhoneNumbers) {
        $Report += "PHONE NUMBER ASSIGNMENTS:"
        $Report += "Total Assigned Numbers: $($PhoneNumbers.Count)"
        $Report += ""
        
        # Group by number type
        $NumbersByType = $PhoneNumbers | Group-Object -Property NumberType | Sort-Object Count -Descending
        $Report += "Numbers by Type:"
        foreach ($Type in $NumbersByType) {
            $Report += "  $($Type.Name): $($Type.Count) numbers"
        }
        $Report += ""
        
        # Group by assignment status
        $NumbersByStatus = $PhoneNumbers | Group-Object -Property PstnAssignmentStatus | Sort-Object Count -Descending
        $Report += "Numbers by Assignment Status:"
        foreach ($Status in $NumbersByStatus) {
            $Report += "  $($Status.Name): $($Status.Count) numbers"
        }
        $Report += ""
        
        # Assigned vs Unassigned breakdown
        $AssignedNumbers = $PhoneNumbers | Where-Object { $_.AssignedPstnTargetId -ne $null }
        $UnassignedNumbers = $PhoneNumbers | Where-Object { $_.AssignedPstnTargetId -eq $null }
        
        $Report += "ASSIGNMENT BREAKDOWN:"
        $Report += "  Assigned to Users/Resources: $($AssignedNumbers.Count)"
        $Report += "  Unassigned/Available: $($UnassignedNumbers.Count)"
        $Report += ""
        
        # Show sample assigned numbers
        if ($AssignedNumbers.Count -gt 0) {
            $Report += "SAMPLE ASSIGNED NUMBERS:"
            $SampleAssigned = $AssignedNumbers | Select-Object -First 10
            foreach ($Number in $SampleAssigned) {
                $AssigneeInfo = if ($Number.AssignedPstnTargetId) {
                    # Try to get user info for the assigned target
                    $AssignedUser = Invoke-SafeCommand { 
                        Get-CsOnlineUser -Identity $Number.AssignedPstnTargetId -ErrorAction SilentlyContinue
                    } "Failed to get user info"
                    if ($AssignedUser) { $AssignedUser.DisplayName } else { $Number.AssignedPstnTargetId }
                } else { "Unknown" }
                
                $Report += "  $($Number.TelephoneNumber) - $($Number.NumberType) -> $AssigneeInfo"
            }
            $Report += ""
        }
        
        # Show unassigned numbers for inventory management
        if ($UnassignedNumbers.Count -gt 0) {
            $Report += "UNASSIGNED NUMBERS INVENTORY:"
            $Report += "Available for assignment: $($UnassignedNumbers.Count) numbers"
            $Report += "Sample unassigned numbers:"
            $UnassignedNumbers | Select-Object -First 10 | ForEach-Object {
                $Report += "  $($_.TelephoneNumber) - $($_.NumberType)"
            }
            $Report += ""
        }
    }
    
    # Get available phone numbers from inventory
    $AvailableNumbers = Invoke-SafeCommand { Get-CsOnlineTelephoneNumber } "Failed to get available phone numbers"
    if ($AvailableNumbers) {
        $Report += "AVAILABLE PHONE NUMBERS (Inventory):"
        $Report += "Total Available in Inventory: $($AvailableNumbers.Count)"
        
        $AvailableByType = $AvailableNumbers | Group-Object -Property NumberType | Sort-Object Count -Descending
        foreach ($Type in $AvailableByType) {
            $Report += "  $($Type.Name): $($Type.Count) numbers"
        }
        $Report += ""
        
        # Show sample available numbers
        if ($AvailableNumbers.Count -gt 0) {
            $Report += "Sample Available Numbers:"
            $AvailableNumbers | Select-Object -First 10 | ForEach-Object {
                $Report += "  $($_.TelephoneNumber) - $($_.NumberType) - $($_.ActivationState)"
            }
            $Report += ""
        }
    }
    
} catch {
    Write-StatusMessage "Error analyzing phone numbers: $($_.Exception.Message)" -Type "Error"
    $Report += "Error retrieving phone number inventory"
    $Report += ""
}

# ENTRA ID USER ANALYSIS
Write-StatusMessage "Analyzing Entra ID user information..."
$Report += "ENTRA ID USER ANALYSIS"
$Report += $Separator

try {
    # Get Entra ID users with Teams-relevant properties
    $EntraUsers = Invoke-SafeCommand { 
        Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName,Mail,JobTitle,Department,OfficeLocation,UsageLocation,AccountEnabled,CreatedDateTime,SignInActivity,AssignedLicenses,LicenseDetails" | Select-Object -First 5000
    } "Failed to get Entra ID users"
    
    if ($EntraUsers) {
        $Report += "ENTRA ID USER OVERVIEW:"
        $Report += "Total Entra ID Users Retrieved: $($EntraUsers.Count)"
        $Report += ""
        
        # User status analysis
        $EnabledUsers = ($EntraUsers | Where-Object { $_.AccountEnabled -eq $true }).Count
        $DisabledUsers = ($EntraUsers | Where-Object { $_.AccountEnabled -eq $false }).Count
        
        $Report += "USER STATUS DISTRIBUTION:"
        $Report += "  Enabled Users: $EnabledUsers"
        $Report += "  Disabled Users: $DisabledUsers"
        $Report += "  Account Enabled Rate: $([Math]::Round(($EnabledUsers / $EntraUsers.Count) * 100, 1))%"
        $Report += ""
        
        # License analysis
        $LicensedUsers = ($EntraUsers | Where-Object { $_.AssignedLicenses -and $_.AssignedLicenses.Count -gt 0 }).Count
        $UnlicensedUsers = $EntraUsers.Count - $LicensedUsers
        
        $Report += "LICENSING OVERVIEW:"
        $Report += "  Licensed Users: $LicensedUsers"
        $Report += "  Unlicensed Users: $UnlicensedUsers"
        $Report += "  License Coverage: $([Math]::Round(($LicensedUsers / $EntraUsers.Count) * 100, 1))%"
        $Report += ""
        
        # Department distribution
        $UsersByDepartment = $EntraUsers | Where-Object { $_.Department } | Group-Object -Property Department | Sort-Object Count -Descending
        if ($UsersByDepartment.Count -gt 0) {
            $Report += "USERS BY DEPARTMENT (Top 10):"
            foreach ($Dept in $UsersByDepartment | Select-Object -First 10) {
                $Report += "  $($Dept.Name): $($Dept.Count) users"
            }
            $Report += ""
        }
        
        # Usage location distribution
        $UsersByLocation = $EntraUsers | Where-Object { $_.UsageLocation } | Group-Object -Property UsageLocation | Sort-Object Count -Descending
        if ($UsersByLocation.Count -gt 0) {
            $Report += "USERS BY USAGE LOCATION:"
            foreach ($Location in $UsersByLocation | Select-Object -First 10) {
                $Report += "  $($Location.Name): $($Location.Count) users"
            }
            $Report += ""
        }
        
        # Sign-in activity analysis (if available)
        $ActiveUsers = $EntraUsers | Where-Object { 
            $_.SignInActivity -and $_.SignInActivity.LastSignInDateTime -and 
            $_.SignInActivity.LastSignInDateTime -gt (Get-Date).AddDays(-30)
        }
        
        if ($ActiveUsers) {
            $Report += "USER ACTIVITY (Last 30 days):"
            $Report += "  Users with Recent Sign-in: $($ActiveUsers.Count)"
            $Report += "  Activity Rate: $([Math]::Round(($ActiveUsers.Count / $EntraUsers.Count) * 100, 1))%"
            $Report += ""
        }
        
        # Correlate with Teams users
        if ($AllUsers) {
            $TeamsEnabledEntraUsers = @()
            foreach ($EntraUser in $EntraUsers) {
                $TeamsUser = $AllUsers | Where-Object { $_.UserPrincipalName -eq $EntraUser.UserPrincipalName }
                if ($TeamsUser) {
                    $TeamsEnabledEntraUsers += [PSCustomObject]@{
                        EntraUser = $EntraUser
                        TeamsUser = $TeamsUser
                        HasTeams = $true
                        EnterpriseVoiceEnabled = $TeamsUser.EnterpriseVoiceEnabled
                        PhoneNumber = $TeamsUser.TelephoneNumber
                    }
                }
            }
            
            $Report += "ENTRA ID TO TEAMS CORRELATION:"
            $Report += "  Entra Users with Teams: $($TeamsEnabledEntraUsers.Count)"
            $Report += "  Teams Adoption Rate: $([Math]::Round(($TeamsEnabledEntraUsers.Count / $EntraUsers.Count) * 100, 1))%"
            
            $VoiceEnabledEntraUsers = ($TeamsEnabledEntraUsers | Where-Object { $_.EnterpriseVoiceEnabled -eq $true }).Count
            $Report += "  Voice-Enabled Users: $VoiceEnabledEntraUsers"
            if ($TeamsEnabledEntraUsers.Count -gt 0) {
                $Report += "  Voice Adoption Rate: $([Math]::Round(($VoiceEnabledEntraUsers / $TeamsEnabledEntraUsers.Count) * 100, 1))%"
            }
            $Report += ""
        }
    }
    
} catch {
    Write-StatusMessage "Error analyzing Entra ID users: $($_.Exception.Message)" -Type "Error"
    $Report += "Error retrieving Entra ID user information"
    $Report += ""
}

# ENTRA ID GROUPS ANALYSIS
Write-StatusMessage "Analyzing Entra ID groups and membership..."
$Report += "ENTRA ID GROUPS ANALYSIS"
$Report += $Separator

try {
    # Get Entra ID groups
    $EntraGroups = Invoke-SafeCommand {
        Get-MgGroup -All -Property "Id,DisplayName,Description,GroupTypes,SecurityEnabled,MailEnabled,CreatedDateTime,MembershipRule,MembershipRuleProcessingState" | Select-Object -First 1000
    } "Failed to get Entra ID groups"
    
    if ($EntraGroups) {
        $Report += "ENTRA ID GROUPS OVERVIEW:"
        $Report += "Total Groups Retrieved: $($EntraGroups.Count)"
        $Report += ""
        
        # Group type analysis
        $SecurityGroups = ($EntraGroups | Where-Object { $_.SecurityEnabled -eq $true -and $_.MailEnabled -eq $false }).Count
        $M365Groups = ($EntraGroups | Where-Object { $_.GroupTypes -contains "Unified" }).Count
        $MailEnabledGroups = ($EntraGroups | Where-Object { $_.MailEnabled -eq $true -and -not ($_.GroupTypes -contains "Unified") }).Count
        $DynamicGroups = ($EntraGroups | Where-Object { $_.GroupTypes -contains "DynamicMembership" }).Count
        
        $Report += "GROUPS BY TYPE:"
        $Report += "  Security Groups: $SecurityGroups"
        $Report += "  Microsoft 365 Groups: $M365Groups"
        $Report += "  Mail-Enabled Security Groups: $MailEnabledGroups"
        $Report += "  Dynamic Groups: $DynamicGroups"
        $Report += ""
        
        # Teams-connected groups analysis
        $TeamsConnectedGroups = @()
        if ($AllTeams) {
            foreach ($Team in $AllTeams) {
                $MatchingGroup = $EntraGroups | Where-Object { $_.Id -eq $Team.GroupId }
                if ($MatchingGroup) {
                    $TeamsConnectedGroups += [PSCustomObject]@{
                        GroupId = $MatchingGroup.Id
                        GroupName = $MatchingGroup.DisplayName
                        TeamName = $Team.DisplayName
                        GroupType = if ($MatchingGroup.GroupTypes -contains "Unified") { "Microsoft 365" } else { "Other" }
                        TeamVisibility = $Team.Visibility
                        TeamArchived = $Team.Archived
                    }
                }
            }
            
            $Report += "TEAMS-CONNECTED GROUPS:"
            $Report += "  Groups with Teams: $($TeamsConnectedGroups.Count)"
            $Report += "  Teams Coverage: $([Math]::Round(($TeamsConnectedGroups.Count / $AllTeams.Count) * 100, 1))%"
            $Report += ""
        }
        
        # Sample group membership analysis
        $Report += "SAMPLE GROUP MEMBERSHIP ANALYSIS (Top 20 groups):"
        $SampleGroups = $EntraGroups | Select-Object -First 20
        
        foreach ($Group in $SampleGroups) {
            try {
                $Members = Invoke-SafeCommand {
                    Get-MgGroupMember -GroupId $Group.Id -All | Select-Object -First 100
                } "Failed to get members for group $($Group.DisplayName)" -SuppressErrors
                
                $MemberCount = if ($Members) { $Members.Count } else { 0 }
                $GroupTypeDesc = if ($Group.GroupTypes -contains "Unified") { 
                    "M365 Group" 
                } elseif ($Group.SecurityEnabled -and $Group.MailEnabled) { 
                    "Mail-Enabled Security" 
                } elseif ($Group.SecurityEnabled) { 
                    "Security Group" 
                } else { 
                    "Distribution List" 
                }
                
                $Report += "  $($Group.DisplayName)"
                $Report += "    Type: $GroupTypeDesc"
                $Report += "    Members: $MemberCount"
                if ($Group.Description) {
                    $ShortDescription = if ($Group.Description.Length -gt 80) { 
                        $Group.Description.Substring(0, 77) + "..." 
                    } else { 
                        $Group.Description 
                    }
                    $Report += "    Description: $ShortDescription"
                }
                
                # Check if it's a Teams-connected group
                $IsTeamsGroup = $TeamsConnectedGroups | Where-Object { $_.GroupId -eq $Group.Id }
                if ($IsTeamsGroup) {
                    $Report += "    Teams: ✅ Connected (Team: $($IsTeamsGroup.TeamName))"
                }
                $Report += ""
            }
            catch {
                $Report += "  $($Group.DisplayName) - Error retrieving membership"
                $Report += ""
            }
        }
        
        # Dynamic groups analysis
        $DynamicGroupsList = $EntraGroups | Where-Object { $_.GroupTypes -contains "DynamicMembership" }
        if ($DynamicGroupsList.Count -gt 0) {
            $Report += "DYNAMIC GROUPS CONFIGURATION:"
            foreach ($DynGroup in $DynamicGroupsList | Select-Object -First 10) {
                $Report += "  $($DynGroup.DisplayName)"
                $Report += "    Processing State: $($DynGroup.MembershipRuleProcessingState)"
                if ($DynGroup.MembershipRule) {
                    $ShortRule = if ($DynGroup.MembershipRule.Length -gt 100) { 
                        $DynGroup.MembershipRule.Substring(0, 97) + "..." 
                    } else { 
                        $DynGroup.MembershipRule 
                    }
                    $Report += "    Rule: $ShortRule"
                }
                $Report += ""
            }
        }
        
    }
    
} catch {
    Write-StatusMessage "Error analyzing Entra ID groups: $($_.Exception.Message)" -Type "Error"
    $Report += "Error retrieving Entra ID groups information"
    $Report += ""
}

# VOICE INFRASTRUCTURE ANALYSIS (if requested)
if ($IncludeVoiceAnalysis) {
    Write-StatusMessage "Performing voice infrastructure analysis..."
    $Report += "VOICE INFRASTRUCTURE ANALYSIS"
    $Report += $Separator
    
    try {
        # Voice routing policies
        $VoiceRoutingPolicies = Invoke-SafeCommand { Get-CsOnlineVoiceRoutingPolicy } "Failed to get voice routing policies"
        if ($VoiceRoutingPolicies) {
            $Report += "VOICE ROUTING POLICIES:"
            $Report += "Total Voice Routing Policies: $($VoiceRoutingPolicies.Count)"
            $Report += ""
            
            foreach ($Policy in $VoiceRoutingPolicies | Select-Object -First 5) {
                $Report += "Policy: $($Policy.Identity)"
                $Report += "  Online PSTN Usages: $(if ($Policy.OnlinePstnUsages) { $Policy.OnlinePstnUsages -join ', ' } else { 'None' })"
                $Report += ""
            }
        }
        
        # Voice routes
        $VoiceRoutes = Invoke-SafeCommand { Get-CsOnlineVoiceRoute } "Failed to get voice routes"
        if ($VoiceRoutes) {
            $Report += "VOICE ROUTES:"
            $Report += "Total Voice Routes: $($VoiceRoutes.Count)"
            $Report += ""
            
            foreach ($Route in $VoiceRoutes | Select-Object -First 5) {
                $Report += "Route: $($Route.Identity)"
                $Report += "  Number Pattern: $($Route.NumberPattern)"
                $Report += "  Online PSTN Usages: $(if ($Route.OnlinePstnUsages) { $Route.OnlinePstnUsages -join ', ' } else { 'None' })"
                $Report += "  Online PSTN Gateway List: $(if ($Route.OnlinePstnGatewayList) { $Route.OnlinePstnGatewayList -join ', ' } else { 'None' })"
                $Report += ""
            }
        }
        
        # SBC Configuration
        $SBCs = Invoke-SafeCommand { Get-CsOnlinePSTNGateway } "Failed to get SBC configuration"
        if ($SBCs) {
            $Report += "SESSION BORDER CONTROLLERS (SBCs):"
            $Report += "Total SBCs: $($SBCs.Count)"
            $Report += ""
            
            foreach ($SBC in $SBCs) {
                $Report += "SBC: $($SBC.Identity)"
                $Report += "  FQDN: $($SBC.Fqdn)"
                $Report += "  SIP Signaling Port: $($SBC.SipSignalingPort)"
                $Report += "  Media Bypass: $($SBC.MediaBypass)"
                $Report += "  Enabled: $($SBC.Enabled)"
                $Report += "  Max Concurrent Sessions: $(if ($SBC.MaxConcurrentSessions) { $SBC.MaxConcurrentSessions } else { 'Unlimited' })"
                $Report += ""
            }
        }
        
        # Calling plans
        $CallingPlans = Invoke-SafeCommand { Get-CsOnlineLicensedUser | Where-Object { $_.SkuPartNumber -like "*CALLING*" } } "Failed to get calling plan information"
        if ($CallingPlans) {
            $Report += "CALLING PLANS:"
            $Report += "Users with Calling Plans: $($CallingPlans.Count)"
            $Report += ""
        }
        
        # Emergency Services Configuration
        $Report += "EMERGENCY SERVICES CONFIGURATION:"
        $Report += $SubSeparator
        
        # Emergency calling policies
        $EmergencyPolicies = Invoke-SafeCommand { Get-CsTeamsEmergencyCallingPolicy } "Failed to get emergency calling policies"
        if ($EmergencyPolicies) {
            $Report += "Emergency Calling Policies: $($EmergencyPolicies.Count)"
            $Report += ""
            foreach ($Policy in $EmergencyPolicies) {
                $Report += "Policy: $($Policy.Identity)"
                $Report += "  Enhanced Emergency Services: $(if ($Policy.EnhancedEmergencyServiceDisclaimer) { '✅ Configured' } else { '❌ Not configured' })"
                $Report += "  External Location Lookup: $(if ($Policy.ExternalLocationLookupMode -and $Policy.ExternalLocationLookupMode -ne 'Disabled') { '✅ Enabled' } else { '❌ Disabled' })"
                $Report += "  Notification Group: $(if ($Policy.NotificationGroup) { $Policy.NotificationGroup } else { 'Not configured' })"
                $Report += "  Notification Mode: $(if ($Policy.NotificationMode) { $Policy.NotificationMode } else { 'Not configured' })"
                $Report += ""
            }
        } else {
            $Report += "❌ No emergency calling policies configured"
            $Report += ""
        }
        
        # Emergency call routing policies
        $EmergencyCallRoutingPolicies = Invoke-SafeCommand { Get-CsTeamsEmergencyCallRoutingPolicy } "Failed to get emergency call routing policies"
        if ($EmergencyCallRoutingPolicies) {
            $Report += "Emergency Call Routing Policies: $($EmergencyCallRoutingPolicies.Count)"
            $Report += ""
            foreach ($Policy in $EmergencyCallRoutingPolicies | Select-Object -First 5) {
                $Report += "Policy: $($Policy.Identity)"
                $Report += "  Emergency Numbers: $(if ($Policy.EmergencyNumbers) { ($Policy.EmergencyNumbers | ForEach-Object { $_.EmergencyDialString }) -join ', ' } else { 'Not configured' })"
                $Report += "  Description: $(if ($Policy.Description) { $Policy.Description } else { 'No description' })"
                $Report += ""
            }
        }
        
        # Network sites for location-based routing
        $NetworkSites = Invoke-SafeCommand { Get-CsTenantNetworkSite } "Failed to get network sites"
        if ($NetworkSites) {
            $Report += "NETWORK SITES (Location-Based Routing):"
            $Report += "Total Network Sites: $($NetworkSites.Count)"
            $Report += ""
            
            $SitesWithEmergencyServices = ($NetworkSites | Where-Object { $_.EmergencyCallingPolicy -or $_.EmergencyCallRoutingPolicy }).Count
            $Report += "Sites with Emergency Services: $SitesWithEmergencyServices"
            $Report += "Emergency Services Coverage: $([Math]::Round(($SitesWithEmergencyServices / $NetworkSites.Count) * 100, 1))%"
            $Report += ""
            
            # Show sample sites
            $Report += "Sample Network Sites:"
            foreach ($Site in $NetworkSites | Select-Object -First 10) {
                $Report += "  Site: $($Site.Identity)"
                $Report += "    Location Policy: $(if ($Site.LocationPolicy) { $Site.LocationPolicy } else { 'Not assigned' })"
                $Report += "    Emergency Calling Policy: $(if ($Site.EmergencyCallingPolicy) { $Site.EmergencyCallingPolicy } else { 'Not assigned' })"
                $Report += "    Emergency Routing Policy: $(if ($Site.EmergencyCallRoutingPolicy) { $Site.EmergencyCallRoutingPolicy } else { 'Not assigned' })"
                $Report += ""
            }
        }
        
        # Location Information Services (LIS)
        $LISLocations = Invoke-SafeCommand { Get-CsLisLocation } "Failed to get LIS locations" -SuppressErrors
        if ($LISLocations) {
            $Report += "LOCATION INFORMATION SERVICE (LIS):"
            $Report += "Total LIS Locations: $($LISLocations.Count)"
            $Report += ""
            
            # Group by location type if available
            if ($LISLocations[0].PSObject.Properties.Name -contains 'LocationType') {
                $LocationsByType = $LISLocations | Group-Object -Property LocationType | Sort-Object Count -Descending
                foreach ($Type in $LocationsByType) {
                    $Report += "  $($Type.Name): $($Type.Count) locations"
                }
            }
            $Report += ""
        }
        
        # Civic addresses
        $CivicAddresses = Invoke-SafeCommand { Get-CsOnlineLisCivicAddress } "Failed to get civic addresses" -SuppressErrors
        if ($CivicAddresses) {
            $Report += "CIVIC ADDRESSES:"
            $Report += "Total Civic Addresses: $($CivicAddresses.Count)"
            $Report += ""
            
            # Show sample addresses
            $Report += "Sample Civic Addresses:"
            foreach ($Address in $CivicAddresses | Select-Object -First 5) {
                $Report += "  Address ID: $($Address.CivicAddressId)"
                $Report += "    Street: $($Address.HouseNumber) $($Address.StreetName)"
                $Report += "    City: $($Address.City), $($Address.StateOrProvince) $($Address.PostalCode)"
                $Report += "    Country: $($Address.CountryOrRegion)"
                $Report += "    Validated: $(if ($Address.ValidationStatus -eq 'Validated') { '✅ Yes' } else { '❌ No' })"
                $Report += ""
            }
        }
        
        # Emergency services summary
        $EmergencyServicesHealth = "Unknown"
        $EmergencyIssues = @()
        
        if (-not $EmergencyPolicies -or $EmergencyPolicies.Count -eq 0) {
            $EmergencyIssues += "No emergency calling policies configured"
        }
        
        if (-not $NetworkSites -or $SitesWithEmergencyServices -eq 0) {
            $EmergencyIssues += "No network sites configured with emergency services"
        }
        
        if (-not $CivicAddresses -or $CivicAddresses.Count -eq 0) {
            $EmergencyIssues += "No civic addresses configured"
        }
        
        $EmergencyServicesHealth = if ($EmergencyIssues.Count -eq 0) {
            "✅ Good"
        } elseif ($EmergencyIssues.Count -le 2) {
            "🟡 Needs Attention"
        } else {
            "🔴 Critical"
        }
        
        $Report += "EMERGENCY SERVICES HEALTH: $EmergencyServicesHealth"
        if ($EmergencyIssues.Count -gt 0) {
            $Report += "Issues identified:"
            foreach ($Issue in $EmergencyIssues) {
                $Report += "  • $Issue"
            }
        }
        $Report += ""
        
    } catch {
        Write-StatusMessage "Error in voice infrastructure analysis: $($_.Exception.Message)" -Type "Error"
        $Report += "Error retrieving voice infrastructure details"
        $Report += ""
    }
}

# USER DISTRIBUTION AND LICENSING (if requested)
if ($IncludeUserDetails) {
    Write-StatusMessage "Analyzing user distribution and licensing..."
    $Report += "USER DISTRIBUTION AND LICENSING ANALYSIS"
    $Report += $Separator
    
    try {
        if ($AllUsers) {
            # User distribution by license
            $UsersByLicense = $AllUsers | Group-Object -Property AssignedPlan | Sort-Object Count -Descending
            
            $Report += "USER LICENSING DISTRIBUTION:"
            foreach ($License in $UsersByLicense | Select-Object -First 10) {
                $LicenseName = if ($License.Name) { $License.Name } else { "Unknown License" }
                $Report += "  $LicenseName : $($License.Count) users"
            }
            $Report += ""
            
            # User distribution by usage location
            $UsersByLocation = $AllUsers | Where-Object { $_.UsageLocation } | Group-Object -Property UsageLocation | Sort-Object Count -Descending
            if ($UsersByLocation) {
                $Report += "USERS BY LOCATION:"
                foreach ($Location in $UsersByLocation | Select-Object -First 10) {
                    $Report += "  $($Location.Name): $($Location.Count) users"
                }
                $Report += ""
            }
            
            # Teams usage statistics
            $TeamsUsers = $AllUsers | Where-Object { $_.TeamsUpgradeEffectiveMode -ne $null }
            $Report += "TEAMS USAGE STATISTICS:"
            $Report += "  Total Teams-Enabled Users: $($TeamsUsers.Count)"
            
            $UpgradeModes = $TeamsUsers | Group-Object -Property TeamsUpgradeEffectiveMode | Sort-Object Count -Descending
            foreach ($Mode in $UpgradeModes) {
                $Report += "  $($Mode.Name) Mode: $($Mode.Count) users"
            }
            $Report += ""
        }
        
    } catch {
        Write-StatusMessage "Error analyzing user distribution: $($_.Exception.Message)" -Type "Error"
        $Report += "Error retrieving user distribution details"
        $Report += ""
    }
}

# COMPLIANCE AND SECURITY ANALYSIS (if requested)
if ($IncludeComplianceAnalysis) {
    Write-StatusMessage "Analyzing compliance and security settings..."
    $Report += "COMPLIANCE AND SECURITY ANALYSIS"
    $Report += $Separator
    
    try {
        # Retention policies
        $RetentionPolicies = Invoke-SafeCommand { Get-RetentionCompliancePolicy } "Failed to get retention policies"
        if ($RetentionPolicies) {
            $Report += "RETENTION POLICIES:"
            $Report += "Total Retention Policies: $($RetentionPolicies.Count)"
            $Report += ""
            
            foreach ($Policy in $RetentionPolicies | Select-Object -First 5) {
                $Report += "Policy: $($Policy.Name)"
                $Report += "  Enabled: $($Policy.Enabled)"
                $Report += "  Workloads: $(if ($Policy.Workload) { $Policy.Workload -join ', ' } else { 'All' })"
                $Report += ""
            }
        }
        
        # DLP policies
        $DLPPolicies = Invoke-SafeCommand { Get-DlpCompliancePolicy } "Failed to get DLP policies"
        if ($DLPPolicies) {
            $Report += "DATA LOSS PREVENTION (DLP) POLICIES:"
            $Report += "Total DLP Policies: $($DLPPolicies.Count)"
            $Report += ""
            
            $TeamsEnforced = $DLPPolicies | Where-Object { $_.Workload -contains "SharePoint" -or $_.Workload -contains "OneDriveForBusiness" -or $_.Workload -contains "TeamsChat" }
            $Report += "DLP Policies Affecting Teams: $($TeamsEnforced.Count)"
            $Report += ""
        }
        
        # Sensitivity labels
        $SensitivityLabels = Invoke-SafeCommand { Get-Label } "Failed to get sensitivity labels"
        if ($SensitivityLabels) {
            $Report += "SENSITIVITY LABELS:"
            $Report += "Total Sensitivity Labels: $($SensitivityLabels.Count)"
            $TeamsLabels = $SensitivityLabels | Where-Object { $_.SiteAndGroupProtectionEnabled -eq $true }
            $Report += "Labels for Teams Protection: $($TeamsLabels.Count)"
            $Report += ""
        }
        
    } catch {
        Write-StatusMessage "Error analyzing compliance settings: $($_.Exception.Message)" -Type "Error"
        $Report += "Error retrieving compliance and security details"
        $Report += ""
    }
}

# TEAMS AND CHANNELS STATISTICS
Write-StatusMessage "Analyzing Teams and channels statistics..."
$Report += "TEAMS AND CHANNELS STATISTICS"
$Report += $Separator

try {
    $AllTeams = Invoke-SafeCommand { Get-Team } "Failed to get Teams information"
    if ($AllTeams) {
        $Report += "TEAMS OVERVIEW:"
        $Report += "Total Teams: $($AllTeams.Count)"
        
        # Teams by visibility
        $PublicTeams = ($AllTeams | Where-Object { $_.Visibility -eq "Public" }).Count
        $PrivateTeams = ($AllTeams | Where-Object { $_.Visibility -eq "Private" }).Count
        
        $Report += "  Public Teams: $PublicTeams"
        $Report += "  Private Teams: $PrivateTeams"
        $Report += ""
        
        # Teams by archive status
        $ArchivedTeams = ($AllTeams | Where-Object { $_.Archived -eq $true }).Count
        $Report += "TEAMS STATUS:"
        $Report += "  Active Teams: $($AllTeams.Count - $ArchivedTeams)"
        $Report += "  Archived Teams: $ArchivedTeams"
        $Report += ""
        
        # Sample of largest teams (by description length as proxy for activity)
        $Report += "SAMPLE TEAMS (Top 5):"
        $SampleTeams = $AllTeams | Select-Object -First 5
        foreach ($Team in $SampleTeams) {
            $Report += "  Team: $($Team.DisplayName)"
            $Report += "    Group ID: $($Team.GroupId)"
            $Report += "    Visibility: $($Team.Visibility)"
            $Report += "    Archived: $($Team.Archived)"
            $Report += ""
        }
    }
    
} catch {
    Write-StatusMessage "Error analyzing Teams statistics: $($_.Exception.Message)" -Type "Error"
    $Report += "Error retrieving Teams and channels statistics"
    $Report += ""
}

# RECOMMENDATIONS
Write-StatusMessage "Generating recommendations..."
$Report += "INFRASTRUCTURE RECOMMENDATIONS"
$Report += $Separator

$Recommendations = @()

# Security recommendations
$Recommendations += "SECURITY AND COMPLIANCE:"
$Recommendations += "  • Review and implement guest access policies for external collaboration"
$Recommendations += "  • Enable data loss prevention (DLP) policies for Teams conversations"
$Recommendations += "  • Configure retention policies for Teams chat and file data"
$Recommendations += "  • Implement sensitivity labels for team classification"
$Recommendations += "  • Regular audit of Teams creation and membership"
$Recommendations += ""

# Voice recommendations
if ($IncludeVoiceAnalysis) {
    $Recommendations += "VOICE AND TELEPHONY:"
    $Recommendations += "  • Monitor SBC performance and concurrent session usage"
    $Recommendations += "  • Review voice routing policies for optimization"
    $Recommendations += "  • Implement emergency services location configuration"
    $Recommendations += "  • Regular testing of call quality and routing paths"
    $Recommendations += ""
}

# General recommendations
$Recommendations += "GENERAL INFRASTRUCTURE:"
$Recommendations += "  • Implement Teams usage reporting and analytics"
$Recommendations += "  • Configure appropriate meeting policies for different user groups"
$Recommendations += "  • Review and optimize app policies for organizational needs"
$Recommendations += "  • Plan for Teams governance and lifecycle management"
$Recommendations += "  • Regular review of licensing and feature utilization"
$Recommendations += "  • Implement backup and disaster recovery procedures"
$Recommendations += ""

$Report += $Recommendations

# REPORT SUMMARY
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

$Report += "ASSESSMENT SUMMARY"
$Report += $Separator
$Report += "Assessment completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$Report += "Total duration: $($Duration.Hours) hours, $($Duration.Minutes) minutes, $($Duration.Seconds) seconds"
$Report += "Errors encountered: $ErrorCount"
$Report += "Warnings: $WarningCount"
$Report += ""
$Report += "Report generated by: $($env:USERNAME)"
$Report += "Computer: $($env:COMPUTERNAME)"
$Report += "PowerShell Version: $($PSVersionTable.PSVersion)"
$Report += $Separator

# Save the report
Write-StatusMessage "Saving comprehensive report to: $ReportPath"
$Report | Out-File -FilePath $ReportPath -Encoding UTF8
Write-StatusMessage "Report saved successfully" -Type "Success"

# Export CSV data if requested
if ($ExportToCSV) {
    Write-StatusMessage "Exporting data to CSV files..."
    
    try {
        # Export user data if available
        if ($AllUsers -and $IncludeUserDetails) {
            $UserExportPath = $ReportPath.Replace('.txt', '_Users.csv')
            $AllUsers | Select-Object DisplayName, UserPrincipalName, AssignedLicenses, UsageLocation, TeamsUpgradeEffectiveMode, EnterpriseVoiceEnabled, TelephoneNumber, OnlineVoiceRoutingPolicy, TeamsMeetingPolicy, TeamsMessagingPolicy, TeamsCallingPolicy | 
                Export-Csv -Path $UserExportPath -NoTypeInformation
            Write-StatusMessage "User data exported to: $UserExportPath" -Type "Success"
        }
        
        # Export Teams data if available
        if ($AllTeams) {
            $TeamsExportPath = $ReportPath.Replace('.txt', '_Teams.csv')
            $AllTeams | Select-Object DisplayName, GroupId, Visibility, Archived, Description | 
                Export-Csv -Path $TeamsExportPath -NoTypeInformation
            Write-StatusMessage "Teams data exported to: $TeamsExportPath" -Type "Success"
        }
        
        # Export phone numbers data
        if ($PhoneNumbers) {
            $PhoneNumbersExportPath = $ReportPath.Replace('.txt', '_PhoneNumbers.csv')
            $PhoneNumbers | Select-Object TelephoneNumber, NumberType, AssignedPstnTargetId, PstnAssignmentStatus, LocationId | 
                Export-Csv -Path $PhoneNumbersExportPath -NoTypeInformation
            Write-StatusMessage "Phone numbers data exported to: $PhoneNumbersExportPath" -Type "Success"
        }
        
        # Export available phone numbers
        if ($AvailableNumbers) {
            $AvailableNumbersExportPath = $ReportPath.Replace('.txt', '_AvailablePhoneNumbers.csv')
            $AvailableNumbers | Select-Object TelephoneNumber, NumberType, ActivationState, AssignmentStatus | 
                Export-Csv -Path $AvailableNumbersExportPath -NoTypeInformation
            Write-StatusMessage "Available phone numbers data exported to: $AvailableNumbersExportPath" -Type "Success"
        }
        
        # Export Entra ID users data
        if ($EntraUsers) {
            $EntraUsersExportPath = $ReportPath.Replace('.txt', '_EntraUsers.csv')
            $EntraUsers | Select-Object Id, DisplayName, UserPrincipalName, Mail, JobTitle, Department, OfficeLocation, UsageLocation, AccountEnabled, CreatedDateTime | 
                Export-Csv -Path $EntraUsersExportPath -NoTypeInformation
            Write-StatusMessage "Entra ID users data exported to: $EntraUsersExportPath" -Type "Success"
        }
        
        # Export Entra ID groups data
        if ($EntraGroups) {
            $EntraGroupsExportPath = $ReportPath.Replace('.txt', '_EntraGroups.csv')
            $EntraGroups | Select-Object Id, DisplayName, Description, GroupTypes, SecurityEnabled, MailEnabled, CreatedDateTime | 
                Export-Csv -Path $EntraGroupsExportPath -NoTypeInformation
            Write-StatusMessage "Entra ID groups data exported to: $EntraGroupsExportPath" -Type "Success"
        }
        
        # Export Teams-connected groups data
        if ($TeamsConnectedGroups -and $TeamsConnectedGroups.Count -gt 0) {
            $TeamsGroupsExportPath = $ReportPath.Replace('.txt', '_TeamsConnectedGroups.csv')
            $TeamsConnectedGroups | Select-Object GroupId, GroupName, TeamName, GroupType, TeamVisibility, TeamArchived | 
                Export-Csv -Path $TeamsGroupsExportPath -NoTypeInformation
            Write-StatusMessage "Teams-connected groups data exported to: $TeamsGroupsExportPath" -Type "Success"
        }
        
        # Export policies summary if voice analysis was included
        if ($IncludeVoiceAnalysis) {
            # Export emergency services data
            if ($EmergencyPolicies) {
                $EmergencyPoliciesExportPath = $ReportPath.Replace('.txt', '_EmergencyPolicies.csv')
                $EmergencyPolicies | Select-Object Identity, EnhancedEmergencyServiceDisclaimer, ExternalLocationLookupMode, NotificationGroup, NotificationMode | 
                    Export-Csv -Path $EmergencyPoliciesExportPath -NoTypeInformation
                Write-StatusMessage "Emergency policies data exported to: $EmergencyPoliciesExportPath" -Type "Success"
            }
            
            # Export network sites
            if ($NetworkSites) {
                $NetworkSitesExportPath = $ReportPath.Replace('.txt', '_NetworkSites.csv')
                $NetworkSites | Select-Object Identity, LocationPolicy, EmergencyCallingPolicy, EmergencyCallRoutingPolicy | 
                    Export-Csv -Path $NetworkSitesExportPath -NoTypeInformation
                Write-StatusMessage "Network sites data exported to: $NetworkSitesExportPath" -Type "Success"
            }
            
            # Export civic addresses
            if ($CivicAddresses) {
                $CivicAddressesExportPath = $ReportPath.Replace('.txt', '_CivicAddresses.csv')
                $CivicAddresses | Select-Object CivicAddressId, HouseNumber, StreetName, City, StateOrProvince, PostalCode, CountryOrRegion, ValidationStatus | 
                    Export-Csv -Path $CivicAddressesExportPath -NoTypeInformation
                Write-StatusMessage "Civic addresses data exported to: $CivicAddressesExportPath" -Type "Success"
            }
        }
        
        # Export comprehensive policies data
        if ($MeetingPolicies) {
            $MeetingPoliciesExportPath = $ReportPath.Replace('.txt', '_MeetingPolicies.csv')
            $MeetingPolicies | Select-Object Identity, AllowCloudRecording, AllowTranscription, AllowAnonymousUsersToStartMeeting, AllowAnonymousUsersToJoinMeeting, AutoAdmittedUsers, AllowPrivateMeetingScheduling, ScreenSharingMode | 
                Export-Csv -Path $MeetingPoliciesExportPath -NoTypeInformation
            Write-StatusMessage "Meeting policies data exported to: $MeetingPoliciesExportPath" -Type "Success"
        }
        
        if ($MessagingPolicies) {
            $MessagingPoliciesExportPath = $ReportPath.Replace('.txt', '_MessagingPolicies.csv')
            $MessagingPolicies | Select-Object Identity, AllowUserChat, AllowUserEditMessage, AllowUserDeleteMessage, AllowGiphy, GiphyRatingType, AllowStickers, AllowUrlPreviews | 
                Export-Csv -Path $MessagingPoliciesExportPath -NoTypeInformation
            Write-StatusMessage "Messaging policies data exported to: $MessagingPoliciesExportPath" -Type "Success"
        }
        
        if ($CallingPolicies) {
            $CallingPoliciesExportPath = $ReportPath.Replace('.txt', '_CallingPolicies.csv')
            $CallingPolicies | Select-Object Identity, AllowPrivateCalling, AllowVoicemail, AllowCallForwarding, AllowCallRedirect, AllowCallGroups, AllowDelegation | 
                Export-Csv -Path $CallingPoliciesExportPath -NoTypeInformation
            Write-StatusMessage "Calling policies data exported to: $CallingPoliciesExportPath" -Type "Success"
        }
        
    } catch {
        Write-StatusMessage "Error exporting CSV data: $($_.Exception.Message)" -Type "Error"
    }
}

# Disconnect from services
Write-StatusMessage "Disconnecting from services..."
try {
    Disconnect-MicrosoftTeams -Confirm:$false -ErrorAction SilentlyContinue
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    if ($IncludeComplianceAnalysis) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-StatusMessage "Disconnected from all services" -Type "Success"
} catch {
    Write-StatusMessage "Note: Some service connections may still be active" -Type "Warning"
}

Write-StatusMessage "Teams Infrastructure Assessment completed successfully!" -Type "Success"
Write-StatusMessage "Report location: $ReportPath" -Type "Success"

# Display report path for easy access
if (Test-Path $ReportPath) {
    Write-Host "`nReport Summary:" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "📊 Report File: " -ForegroundColor Yellow -NoNewline
    Write-Host $ReportPath -ForegroundColor White
    Write-Host "📈 Assessment Duration: " -ForegroundColor Yellow -NoNewline
    Write-Host "$($Duration.TotalMinutes.ToString('F1')) minutes" -ForegroundColor White
    Write-Host "⚠️  Errors: " -ForegroundColor Yellow -NoNewline
    Write-Host $ErrorCount -ForegroundColor $(if ($ErrorCount -eq 0) { 'Green' } else { 'Red' })
    Write-Host "🔔 Warnings: " -ForegroundColor Yellow -NoNewline
    Write-Host $WarningCount -ForegroundColor $(if ($WarningCount -eq 0) { 'Green' } else { 'Orange' })
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
}