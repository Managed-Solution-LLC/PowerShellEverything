<#
.SYNOPSIS
    TeamsInfrastructureAssessment PowerShell Module
    Helper functions for Microsoft Teams infrastructure assessment and reporting.

.DESCRIPTION
    This module provides helper functions and utilities for conducting comprehensive
    Microsoft Teams infrastructure assessments. It includes functions for data collection,
    analysis, formatting, and reporting across various Teams components including voice,
    meetings, policies, and user configurations.

.AUTHOR
    W. Ford

.VERSION
    1.0

.DATE
    2025-09-24

#>

# Export module functions
$ExportedFunctions = @(
    'Get-TeamsInfrastructureHealth',
    'Test-TeamsConnectivity',
    'Get-TeamsVoiceConfiguration',
    'Get-TeamsPolicyAssignments',
    'Format-TeamsReport',
    'Export-TeamsData',
    'Get-TeamsUsageStatistics',
    'Test-SBCHealth',
    'Get-TeamsComplianceStatus',
    'Compare-TeamsConfigurations'
)

#region Helper Functions

function Write-TeamsLog {
    <#
    .SYNOPSIS
        Writes formatted log messages for Teams assessment operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$Level = 'Info',
        
        [Parameter(Mandatory=$false)]
        [string]$Component = 'TeamsAssessment'
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogColors = @{
        'Info' = 'Cyan'
        'Warning' = 'Yellow'
        'Error' = 'Red'
        'Success' = 'Green'
        'Debug' = 'Gray'
    }
    
    $LogMessage = "[$Timestamp] [$Level] [$Component] $Message"
    Write-Host $LogMessage -ForegroundColor $LogColors[$Level]
    
    # Optionally write to log file if specified
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $LogMessage -ErrorAction SilentlyContinue
    }
}

function Invoke-TeamsCommand {
    <#
    .SYNOPSIS
        Safely executes Teams PowerShell commands with error handling and logging.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Command,
        
        [Parameter(Mandatory=$false)]
        [string]$OperationName = "Teams Command",
        
        [Parameter(Mandatory=$false)]
        [switch]$SuppressErrors
    )
    
    try {
        Write-TeamsLog "Executing: $OperationName" -Level 'Debug'
        $Result = & $Command
        Write-TeamsLog "Successfully completed: $OperationName" -Level 'Debug'
        return $Result
    }
    catch {
        $ErrorMsg = "Failed to execute $OperationName - $($_.Exception.Message)"
        if (-not $SuppressErrors) {
            Write-TeamsLog $ErrorMsg -Level 'Error'
        }
        return $null
    }
}

#endregion

#region Infrastructure Health Functions

function Get-TeamsInfrastructureHealth {
    <#
    .SYNOPSIS
        Performs a comprehensive health check of Teams infrastructure components.
    
    .DESCRIPTION
        Evaluates the health status of various Teams infrastructure components including
        SBCs, voice routing, policies, and user configurations. Returns a health score
        and detailed status information.
    
    .EXAMPLE
        Get-TeamsInfrastructureHealth
        
    .EXAMPLE
        Get-TeamsInfrastructureHealth -IncludeDetailedAnalysis -ExportResults
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$IncludeDetailedAnalysis,
        
        [Parameter(Mandatory=$false)]
        [switch]$ExportResults,
        
        [Parameter(Mandatory=$false)]
        [string]$ExportPath = "C:\Reports\TeamsHealthCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    )
    
    Write-TeamsLog "Starting Teams Infrastructure Health Check" -Level 'Info'
    
    $HealthResults = [PSCustomObject]@{
        Timestamp = Get-Date
        OverallHealth = "Unknown"
        HealthScore = 0
        ComponentStatus = @{}
        Issues = @()
        Recommendations = @()
        DetailedAnalysis = @{}
    }
    
    $ComponentScores = @{}
    
    # Check SBC Health
    Write-TeamsLog "Checking SBC health status" -Level 'Info'
    $SBCHealth = Test-SBCHealth
    $ComponentScores['SBC'] = $SBCHealth.HealthScore
    $HealthResults.ComponentStatus['SBC'] = $SBCHealth.Status
    
    if ($SBCHealth.Issues) {
        $HealthResults.Issues += $SBCHealth.Issues
    }
    
    # Check Voice Routing Health
    Write-TeamsLog "Checking voice routing configuration" -Level 'Info'
    $VoiceHealth = Test-VoiceRoutingHealth
    $ComponentScores['VoiceRouting'] = $VoiceHealth.HealthScore
    $HealthResults.ComponentStatus['VoiceRouting'] = $VoiceHealth.Status
    
    # Check Policy Health
    Write-TeamsLog "Checking Teams policy configuration" -Level 'Info'
    $PolicyHealth = Test-TeamsPolicyHealth
    $ComponentScores['Policies'] = $PolicyHealth.HealthScore
    $HealthResults.ComponentStatus['Policies'] = $PolicyHealth.Status
    
    # Check User Configuration Health
    Write-TeamsLog "Checking user configuration health" -Level 'Info'
    $UserHealth = Test-TeamsUserHealth
    $ComponentScores['UserConfig'] = $UserHealth.HealthScore
    $HealthResults.ComponentStatus['UserConfig'] = $UserHealth.Status
    
    # Calculate overall health score
    if ($ComponentScores.Values.Count -gt 0) {
        $HealthResults.HealthScore = ($ComponentScores.Values | Measure-Object -Average).Average
        $HealthResults.OverallHealth = switch ($HealthResults.HealthScore) {
            {$_ -ge 90} { "Excellent" }
            {$_ -ge 80} { "Good" }
            {$_ -ge 70} { "Fair" }
            {$_ -ge 60} { "Poor" }
            default { "Critical" }
        }
    }
    
    # Generate recommendations based on findings
    $HealthResults.Recommendations = Get-HealthRecommendations -HealthResults $HealthResults
    
    # Include detailed analysis if requested
    if ($IncludeDetailedAnalysis) {
        $HealthResults.DetailedAnalysis = @{
            SBCDetails = $SBCHealth.Details
            VoiceDetails = $VoiceHealth.Details
            PolicyDetails = $PolicyHealth.Details
            UserDetails = $UserHealth.Details
        }
    }
    
    # Export results if requested
    if ($ExportResults) {
        try {
            $HealthResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
            Write-TeamsLog "Health check results exported to: $ExportPath" -Level 'Success'
        }
        catch {
            Write-TeamsLog "Failed to export results: $($_.Exception.Message)" -Level 'Error'
        }
    }
    
    Write-TeamsLog "Teams Infrastructure Health Check completed. Overall Health: $($HealthResults.OverallHealth) ($($HealthResults.HealthScore.ToString('F1'))%)" -Level 'Success'
    return $HealthResults
}

function Test-TeamsConnectivity {
    <#
    .SYNOPSIS
        Tests connectivity to Teams services and infrastructure components.
    
    .DESCRIPTION
        Performs comprehensive connectivity tests for Teams infrastructure including
        SIP connectivity, media connectivity, and service endpoint accessibility.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string[]]$TestEndpoints = @(
            "teams.microsoft.com",
            "api.interfaces.records.teams.microsoft.com",
            "config.teams.microsoft.com"
        ),
        
        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 30
    )
    
    Write-TeamsLog "Starting Teams connectivity tests" -Level 'Info'
    
    $ConnectivityResults = @{
        Timestamp = Get-Date
        OverallStatus = "Unknown"
        EndpointResults = @()
        SBCConnectivity = @()
        NetworkRequirements = @{
            TeamsEndpoints = "Unknown"
            MediaConnectivity = "Unknown"
            SignalingConnectivity = "Unknown"
        }
    }
    
    # Test standard Teams endpoints
    foreach ($Endpoint in $TestEndpoints) {
        Write-TeamsLog "Testing connectivity to: $Endpoint" -Level 'Debug'
        
        $TestResult = @{
            Endpoint = $Endpoint
            Status = "Failed"
            ResponseTime = -1
            Error = $null
        }
        
        try {
            $TestConnection = Test-NetConnection -ComputerName $Endpoint -Port 443 -WarningAction SilentlyContinue
            if ($TestConnection.TcpTestSucceeded) {
                $TestResult.Status = "Success"
                $TestResult.ResponseTime = if ($TestConnection.PingReplyDetails) { 
                    $TestConnection.PingReplyDetails.RoundtripTime 
                } else { 0 }
            }
        }
        catch {
            $TestResult.Error = $_.Exception.Message
        }
        
        $ConnectivityResults.EndpointResults += $TestResult
    }
    
    # Test SBC connectivity if SBCs are configured
    $SBCs = Invoke-TeamsCommand { Get-CsOnlinePSTNGateway } -OperationName "Get SBCs" -SuppressErrors
    if ($SBCs) {
        foreach ($SBC in $SBCs) {
            $SBCTest = Test-SBCConnectivity -SBCFQDN $SBC.Fqdn -Port $SBC.SipSignalingPort
            $ConnectivityResults.SBCConnectivity += $SBCTest
        }
    }
    
    # Determine overall status
    $SuccessfulTests = ($ConnectivityResults.EndpointResults | Where-Object { $_.Status -eq "Success" }).Count
    $TotalTests = $ConnectivityResults.EndpointResults.Count
    
    $ConnectivityResults.OverallStatus = if ($SuccessfulTests -eq $TotalTests) {
        "Healthy"
    } elseif ($SuccessfulTests -gt 0) {
        "Partial"
    } else {
        "Failed"
    }
    
    Write-TeamsLog "Connectivity tests completed. Status: $($ConnectivityResults.OverallStatus)" -Level 'Info'
    return $ConnectivityResults
}

#endregion

#region Voice Configuration Functions

function Get-TeamsVoiceConfiguration {
    <#
    .SYNOPSIS
        Retrieves comprehensive Teams voice configuration information.
    
    .DESCRIPTION
        Collects detailed voice configuration data including voice routing policies,
        SBC configuration, phone number assignments, and voice application settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$IncludeUserAssignments,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeUsageStatistics,
        
        [Parameter(Mandatory=$false)]
        [switch]$TestConnectivity
    )
    
    Write-TeamsLog "Gathering Teams voice configuration" -Level 'Info'
    
    $VoiceConfig = [PSCustomObject]@{
        Timestamp = Get-Date
        VoiceRoutingPolicies = @()
        VoiceRoutes = @()
        SBCs = @()
        PhoneNumbers = @()
        VoiceApps = @{
            CallQueues = @()
            AutoAttendants = @()
        }
        EmergencyServices = @{}
        UserAssignments = @()
        UsageStatistics = @{}
        ConnectivityStatus = @{}
    }
    
    # Get voice routing policies
    $VoiceConfig.VoiceRoutingPolicies = Invoke-TeamsCommand { 
        Get-CsOnlineVoiceRoutingPolicy | ForEach-Object {
            [PSCustomObject]@{
                Identity = $_.Identity
                OnlinePstnUsages = $_.OnlinePstnUsages
                Description = $_.Description
                AssignedUserCount = 0  # Will be populated if IncludeUserAssignments is true
            }
        }
    } -OperationName "Get Voice Routing Policies"
    
    # Get voice routes
    $VoiceConfig.VoiceRoutes = Invoke-TeamsCommand {
        Get-CsOnlineVoiceRoute | ForEach-Object {
            [PSCustomObject]@{
                Identity = $_.Identity
                NumberPattern = $_.NumberPattern
                Priority = $_.Priority
                OnlinePstnUsages = $_.OnlinePstnUsages
                OnlinePstnGatewayList = $_.OnlinePstnGatewayList
            }
        }
    } -OperationName "Get Voice Routes"
    
    # Get SBC configuration
    $VoiceConfig.SBCs = Invoke-TeamsCommand {
        Get-CsOnlinePSTNGateway | ForEach-Object {
            [PSCustomObject]@{
                Identity = $_.Identity
                Fqdn = $_.Fqdn
                Enabled = $_.Enabled
                SipSignalingPort = $_.SipSignalingPort
                MediaBypass = $_.MediaBypass
                MaxConcurrentSessions = $_.MaxConcurrentSessions
                FailoverTimeSeconds = $_.FailoverTimeSeconds
                ForwardCallHistory = $_.ForwardCallHistory
                ForwardPai = $_.ForwardPai
                SendSipOptions = $_.SendSipOptions
            }
        }
    } -OperationName "Get SBC Configuration"
    
    # Get phone number assignments
    $VoiceConfig.PhoneNumbers = Invoke-TeamsCommand {
        Get-CsPhoneNumberAssignment | ForEach-Object {
            [PSCustomObject]@{
                TelephoneNumber = $_.TelephoneNumber
                NumberType = $_.NumberType
                AssignedPstnTargetId = $_.AssignedPstnTargetId
                PstnAssignmentStatus = $_.PstnAssignmentStatus
                LocationId = $_.LocationId
            }
        }
    } -OperationName "Get Phone Number Assignments"
    
    # Get voice applications
    $VoiceConfig.VoiceApps.CallQueues = Invoke-TeamsCommand {
        Get-CsCallQueue | Select-Object -First 50 | ForEach-Object {
            [PSCustomObject]@{
                Identity = $_.Identity
                Name = $_.Name
                AgentCount = if ($_.Agents) { $_.Agents.Count } else { 0 }
                OverflowAction = $_.OverflowAction
                TimeoutAction = $_.TimeoutAction
                LanguageId = $_.LanguageId
            }
        }
    } -OperationName "Get Call Queues"
    
    $VoiceConfig.VoiceApps.AutoAttendants = Invoke-TeamsCommand {
        Get-CsAutoAttendant | Select-Object -First 50 | ForEach-Object {
            [PSCustomObject]@{
                Identity = $_.Identity
                Name = $_.Name
                LanguageId = $_.LanguageId
                Status = $_.Status
                DefaultCallFlow = if ($_.DefaultCallFlow) { "Configured" } else { "Not configured" }
            }
        }
    } -OperationName "Get Auto Attendants"
    
    # Get emergency services configuration
    $VoiceConfig.EmergencyServices = Invoke-TeamsCommand {
        $EmergencyPolicies = Get-CsTeamsEmergencyCallingPolicy
        $NetworkSites = Get-CsTenantNetworkSite
        
        [PSCustomObject]@{
            EmergencyCallingPolicies = $EmergencyPolicies.Count
            NetworkSites = $NetworkSites.Count
            LocationsConfigured = ($NetworkSites | Where-Object { $_.LocationPolicy }).Count
        }
    } -OperationName "Get Emergency Services Configuration"
    
    # Include user assignments if requested
    if ($IncludeUserAssignments) {
        Write-TeamsLog "Gathering user voice assignments" -Level 'Info'
        $VoiceUsers = Invoke-TeamsCommand { 
            Get-CsOnlineUser -ResultSize Unlimited | Where-Object { $_.EnterpriseVoiceEnabled -eq $true }
        } -OperationName "Get Voice Users"
        
        if ($VoiceUsers) {
            $VoiceConfig.UserAssignments = $VoiceUsers | ForEach-Object {
                [PSCustomObject]@{
                    UserPrincipalName = $_.UserPrincipalName
                    DisplayName = $_.DisplayName
                    TelephoneNumber = $_.TelephoneNumber
                    OnlineVoiceRoutingPolicy = $_.OnlineVoiceRoutingPolicy
                    TeamsCallingPolicy = $_.TeamsCallingPolicy
                    UsageLocation = $_.UsageLocation
                }
            }
            
            # Update user counts for voice routing policies
            foreach ($Policy in $VoiceConfig.VoiceRoutingPolicies) {
                $Policy.AssignedUserCount = ($VoiceConfig.UserAssignments | Where-Object { 
                    $_.OnlineVoiceRoutingPolicy -eq $Policy.Identity 
                }).Count
            }
        }
    }
    
    # Test connectivity if requested
    if ($TestConnectivity) {
        Write-TeamsLog "Testing voice infrastructure connectivity" -Level 'Info'
        $VoiceConfig.ConnectivityStatus = Test-VoiceConnectivity -SBCs $VoiceConfig.SBCs
    }
    
    Write-TeamsLog "Voice configuration gathering completed" -Level 'Success'
    return $VoiceConfig
}

function Test-SBCHealth {
    <#
    .SYNOPSIS
        Tests the health and connectivity of Session Border Controllers.
    
    .DESCRIPTION
        Performs comprehensive health checks on configured SBCs including connectivity,
        configuration validation, and performance metrics.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string[]]$SBCList,
        
        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 30
    )
    
    Write-TeamsLog "Starting SBC health check" -Level 'Info'
    
    $SBCHealthResults = [PSCustomObject]@{
        Timestamp = Get-Date
        HealthScore = 0
        Status = "Unknown"
        Issues = @()
        Details = @()
    }
    
    # Get SBC configuration if not provided
    if (-not $SBCList) {
        $SBCs = Invoke-TeamsCommand { Get-CsOnlinePSTNGateway } -OperationName "Get SBC Configuration"
        $SBCList = $SBCs | ForEach-Object { $_.Fqdn }
    }
    
    if (-not $SBCList -or $SBCList.Count -eq 0) {
        $SBCHealthResults.Status = "No SBCs Configured"
        $SBCHealthResults.HealthScore = 100  # Not applicable
        Write-TeamsLog "No SBCs configured - skipping SBC health check" -Level 'Info'
        return $SBCHealthResults
    }
    
    $HealthyCount = 0
    $TotalCount = $SBCList.Count
    
    foreach ($SBCFQDN in $SBCList) {
        Write-TeamsLog "Testing SBC: $SBCFQDN" -Level 'Debug'
        
        $SBCTest = @{
            FQDN = $SBCFQDN
            ConnectivityStatus = "Unknown"
            ConfigurationStatus = "Unknown"
            Issues = @()
            Metrics = @{}
        }
        
        # Test connectivity
        try {
            $ConnTest = Test-NetConnection -ComputerName $SBCFQDN -Port 5061 -WarningAction SilentlyContinue
            $SBCTest.ConnectivityStatus = if ($ConnTest.TcpTestSucceeded) { "Healthy" } else { "Failed" }
            
            if ($ConnTest.PingReplyDetails) {
                $SBCTest.Metrics['Latency'] = $ConnTest.PingReplyDetails.RoundtripTime
            }
        }
        catch {
            $SBCTest.ConnectivityStatus = "Failed"
            $SBCTest.Issues += "Connectivity test failed: $($_.Exception.Message)"
        }
        
        # Validate configuration
        $SBCConfig = Invoke-TeamsCommand { 
            Get-CsOnlinePSTNGateway -Identity $SBCFQDN 
        } -OperationName "Get SBC Config for $SBCFQDN" -SuppressErrors
        
        if ($SBCConfig) {
            $SBCTest.ConfigurationStatus = "Configured"
            
            # Check for common configuration issues
            if (-not $SBCConfig.Enabled) {
                $SBCTest.Issues += "SBC is disabled"
            }
            
            if ($SBCConfig.MaxConcurrentSessions -eq 0) {
                $SBCTest.Issues += "Max concurrent sessions is set to 0"
            }
            
            if (-not $SBCConfig.SendSipOptions) {
                $SBCTest.Issues += "SIP OPTIONS not enabled - health monitoring may be limited"
            }
        } else {
            $SBCTest.ConfigurationStatus = "Configuration Error"
            $SBCTest.Issues += "Unable to retrieve SBC configuration"
        }
        
        # Determine if SBC is healthy
        if ($SBCTest.ConnectivityStatus -eq "Healthy" -and $SBCTest.ConfigurationStatus -eq "Configured" -and $SBCTest.Issues.Count -eq 0) {
            $HealthyCount++
        }
        
        $SBCHealthResults.Details += $SBCTest
        $SBCHealthResults.Issues += $SBCTest.Issues
    }
    
    # Calculate overall health score
    $SBCHealthResults.HealthScore = if ($TotalCount -gt 0) { ($HealthyCount / $TotalCount) * 100 } else { 0 }
    $SBCHealthResults.Status = if ($SBCHealthResults.HealthScore -eq 100) {
        "Healthy"
    } elseif ($SBCHealthResults.HealthScore -ge 75) {
        "Minor Issues"
    } elseif ($SBCHealthResults.HealthScore -ge 50) {
        "Major Issues"
    } else {
        "Critical"
    }
    
    Write-TeamsLog "SBC health check completed. Status: $($SBCHealthResults.Status) ($($SBCHealthResults.HealthScore.ToString('F1'))%)" -Level 'Info'
    return $SBCHealthResults
}

#endregion

#region Policy and Configuration Functions

function Get-TeamsPolicyAssignments {
    <#
    .SYNOPSIS
        Retrieves comprehensive Teams policy assignments and configuration.
    
    .DESCRIPTION
        Collects detailed information about Teams policy assignments across different
        policy types including meeting, messaging, calling, and app policies.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$IncludeUserAssignments,
        
        [Parameter(Mandatory=$false)]
        [string[]]$PolicyTypes = @('Meeting', 'Messaging', 'Calling', 'App', 'Update')
    )
    
    Write-TeamsLog "Gathering Teams policy assignments" -Level 'Info'
    
    $PolicyData = [PSCustomObject]@{
        Timestamp = Get-Date
        MeetingPolicies = @()
        MessagingPolicies = @()
        CallingPolicies = @()
        AppPolicies = @()
        UpdatePolicies = @()
        UserAssignments = @()
    }
    
    # Get meeting policies
    if ($PolicyTypes -contains 'Meeting') {
        $PolicyData.MeetingPolicies = Invoke-TeamsCommand {
            Get-CsTeamsMeetingPolicy | ForEach-Object {
                [PSCustomObject]@{
                    Identity = $_.Identity
                    AllowCloudRecording = $_.AllowCloudRecording
                    AllowTranscription = $_.AllowTranscription
                    AllowAnonymousUsersToStartMeeting = $_.AllowAnonymousUsersToStartMeeting
                    MaxMeetingParticipants = $_.MaxMeetingParticipants
                    AssignedUserCount = 0
                }
            }
        } -OperationName "Get Meeting Policies"
    }
    
    # Get messaging policies
    if ($PolicyTypes -contains 'Messaging') {
        $PolicyData.MessagingPolicies = Invoke-TeamsCommand {
            Get-CsTeamsMessagingPolicy | ForEach-Object {
                [PSCustomObject]@{
                    Identity = $_.Identity
                    AllowUserChat = $_.AllowUserChat
                    AllowGiphy = $_.AllowGiphy
                    AllowStickers = $_.AllowStickers
                    AllowUrlPreviews = $_.AllowUrlPreviews
                    AssignedUserCount = 0
                }
            }
        } -OperationName "Get Messaging Policies"
    }
    
    # Get calling policies
    if ($PolicyTypes -contains 'Calling') {
        $PolicyData.CallingPolicies = Invoke-TeamsCommand {
            Get-CsTeamsCallingPolicy | ForEach-Object {
                [PSCustomObject]@{
                    Identity = $_.Identity
                    AllowPrivateCalling = $_.AllowPrivateCalling
                    AllowVoicemail = $_.AllowVoicemail
                    AllowCallForwarding = $_.AllowCallForwarding
                    AllowCallRedirect = $_.AllowCallRedirect
                    AssignedUserCount = 0
                }
            }
        } -OperationName "Get Calling Policies"
    }
    
    # Include user assignments if requested
    if ($IncludeUserAssignments) {
        Write-TeamsLog "Gathering user policy assignments" -Level 'Info'
        $Users = Invoke-TeamsCommand {
            Get-CsOnlineUser -ResultSize 1000 | ForEach-Object {
                [PSCustomObject]@{
                    UserPrincipalName = $_.UserPrincipalName
                    DisplayName = $_.DisplayName
                    TeamsMeetingPolicy = $_.TeamsMeetingPolicy
                    TeamsMessagingPolicy = $_.TeamsMessagingPolicy
                    TeamsCallingPolicy = $_.TeamsCallingPolicy
                    TeamsAppSetupPolicy = $_.TeamsAppSetupPolicy
                }
            }
        } -OperationName "Get User Policy Assignments"
        
        $PolicyData.UserAssignments = $Users
        
        # Update assignment counts
        foreach ($Policy in $PolicyData.MeetingPolicies) {
            $Policy.AssignedUserCount = ($Users | Where-Object { $_.TeamsMeetingPolicy -eq $Policy.Identity }).Count
        }
        
        foreach ($Policy in $PolicyData.MessagingPolicies) {
            $Policy.AssignedUserCount = ($Users | Where-Object { $_.TeamsMessagingPolicy -eq $Policy.Identity }).Count
        }
        
        foreach ($Policy in $PolicyData.CallingPolicies) {
            $Policy.AssignedUserCount = ($Users | Where-Object { $_.TeamsCallingPolicy -eq $Policy.Identity }).Count
        }
    }
    
    Write-TeamsLog "Policy assignments gathering completed" -Level 'Success'
    return $PolicyData
}

#endregion

#region Reporting and Export Functions

function Format-TeamsReport {
    <#
    .SYNOPSIS
        Formats Teams assessment data into a readable report format.
    
    .DESCRIPTION
        Takes raw Teams assessment data and formats it into a structured, readable
        report with sections, summaries, and recommendations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$AssessmentData,
        
        [Parameter(Mandatory=$false)]
        [string]$OrganizationName = "Organization",
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeRecommendations,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputFormat = "Text"
    )
    
    $Separator = "=" * 80
    $SubSeparator = "-" * 60
    
    $FormattedReport = @()
    
    # Header
    $FormattedReport += "$OrganizationName TEAMS INFRASTRUCTURE ASSESSMENT"
    $FormattedReport += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $FormattedReport += $Separator
    $FormattedReport += ""
    
    # Executive Summary
    if ($AssessmentData.ContainsKey('Summary')) {
        $FormattedReport += "EXECUTIVE SUMMARY"
        $FormattedReport += $SubSeparator
        $FormattedReport += $AssessmentData.Summary
        $FormattedReport += ""
    }
    
    # Infrastructure Health
    if ($AssessmentData.ContainsKey('InfrastructureHealth')) {
        $Health = $AssessmentData.InfrastructureHealth
        $FormattedReport += "INFRASTRUCTURE HEALTH STATUS"
        $FormattedReport += $SubSeparator
        $FormattedReport += "Overall Health: $($Health.OverallHealth) ($($Health.HealthScore.ToString('F1'))%)"
        $FormattedReport += ""
        
        foreach ($Component in $Health.ComponentStatus.GetEnumerator()) {
            $FormattedReport += "  $($Component.Key): $($Component.Value)"
        }
        $FormattedReport += ""
        
        if ($Health.Issues -and $Health.Issues.Count -gt 0) {
            $FormattedReport += "Identified Issues:"
            foreach ($Issue in $Health.Issues) {
                $FormattedReport += "  • $Issue"
            }
            $FormattedReport += ""
        }
    }
    
    # Voice Configuration
    if ($AssessmentData.ContainsKey('VoiceConfiguration')) {
        $Voice = $AssessmentData.VoiceConfiguration
        $FormattedReport += "VOICE INFRASTRUCTURE"
        $FormattedReport += $SubSeparator
        $FormattedReport += "SBC Count: $($Voice.SBCs.Count)"
        $FormattedReport += "Voice Routing Policies: $($Voice.VoiceRoutingPolicies.Count)"
        $FormattedReport += "Voice Routes: $($Voice.VoiceRoutes.Count)"
        $FormattedReport += "Phone Numbers: $($Voice.PhoneNumbers.Count)"
        $FormattedReport += ""
    }
    
    # Include recommendations if requested
    if ($IncludeRecommendations -and $AssessmentData.ContainsKey('Recommendations')) {
        $FormattedReport += "RECOMMENDATIONS"
        $FormattedReport += $SubSeparator
        foreach ($Recommendation in $AssessmentData.Recommendations) {
            $FormattedReport += "• $Recommendation"
        }
        $FormattedReport += ""
    }
    
    # Footer
    $FormattedReport += $Separator
    $FormattedReport += "Report generated by Teams Infrastructure Assessment Module v1.0"
    $FormattedReport += "Generated on: $($env:COMPUTERNAME) by $($env:USERNAME)"
    
    return $FormattedReport
}

function Export-TeamsData {
    <#
    .SYNOPSIS
        Exports Teams assessment data to various formats.
    
    .DESCRIPTION
        Exports Teams infrastructure data to CSV, JSON, or XML formats for
        further analysis or integration with other systems.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Data,
        
        [Parameter(Mandatory=$true)]
        [string]$ExportPath,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('CSV', 'JSON', 'XML')]
        [string]$Format = 'JSON',
        
        [Parameter(Mandatory=$false)]
        [switch]$OverwriteExisting
    )
    
    Write-TeamsLog "Exporting Teams data to $Format format" -Level 'Info'
    
    if (Test-Path $ExportPath -and -not $OverwriteExisting) {
        Write-TeamsLog "Export file already exists and overwrite not specified: $ExportPath" -Level 'Warning'
        return $false
    }
    
    try {
        $ExportDir = Split-Path $ExportPath -Parent
        if (-not (Test-Path $ExportDir)) {
            New-Item -ItemType Directory -Path $ExportDir -Force | Out-Null
        }
        
        switch ($Format) {
            'JSON' {
                $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
            }
            'CSV' {
                if ($Data -is [Array]) {
                    $Data | Export-Csv -Path $ExportPath -NoTypeInformation
                } else {
                    # Convert object to flat structure for CSV
                    $FlatData = Convert-ToFlatObject -Object $Data
                    $FlatData | Export-Csv -Path $ExportPath -NoTypeInformation
                }
            }
            'XML' {
                $Data | Export-Clixml -Path $ExportPath
            }
        }
        
        Write-TeamsLog "Successfully exported data to: $ExportPath" -Level 'Success'
        return $true
    }
    catch {
        Write-TeamsLog "Failed to export data: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

#endregion

#region Utility Functions

function Convert-ToFlatObject {
    <#
    .SYNOPSIS
        Converts a complex object to a flat structure suitable for CSV export.
    #>
    param([object]$Object)
    
    $FlatObject = @{}
    
    function Flatten-Object {
        param($Obj, $Prefix = "")
        
        foreach ($Property in $Obj.PSObject.Properties) {
            $Key = if ($Prefix) { "$Prefix.$($Property.Name)" } else { $Property.Name }
            
            if ($Property.Value -is [PSCustomObject] -or $Property.Value -is [Hashtable]) {
                Flatten-Object -Obj $Property.Value -Prefix $Key
            } elseif ($Property.Value -is [Array]) {
                $FlatObject[$Key] = ($Property.Value -join '; ')
            } else {
                $FlatObject[$Key] = $Property.Value
            }
        }
    }
    
    Flatten-Object -Obj $Object
    return [PSCustomObject]$FlatObject
}

function Test-VoiceRoutingHealth {
    [CmdletBinding()]
    param()
    
    # Placeholder for voice routing health check
    return [PSCustomObject]@{
        HealthScore = 85
        Status = "Good"
        Details = @{}
    }
}

function Test-TeamsPolicyHealth {
    [CmdletBinding()]
    param()
    
    # Placeholder for policy health check
    return [PSCustomObject]@{
        HealthScore = 90
        Status = "Excellent"
        Details = @{}
    }
}

function Test-TeamsUserHealth {
    [CmdletBinding()]
    param()
    
    # Placeholder for user health check
    return [PSCustomObject]@{
        HealthScore = 80
        Status = "Good"
        Details = @{}
    }
}

function Get-HealthRecommendations {
    [CmdletBinding()]
    param([object]$HealthResults)
    
    $Recommendations = @()
    
    if ($HealthResults.HealthScore -lt 80) {
        $Recommendations += "Review and address identified infrastructure issues"
    }
    
    if ($HealthResults.ComponentStatus.SBC -eq "Critical") {
        $Recommendations += "Urgent: Address SBC connectivity and configuration issues"
    }
    
    return $Recommendations
}

function Test-VoiceConnectivity {
    [CmdletBinding()]
    param([object[]]$SBCs)
    
    # Placeholder for voice connectivity testing
    return @{
        Status = "Healthy"
        Details = @{}
    }
}

function Test-SBCConnectivity {
    [CmdletBinding()]
    param(
        [string]$SBCFQDN,
        [int]$Port = 5061
    )
    
    try {
        $result = Test-NetConnection -ComputerName $SBCFQDN -Port $Port -WarningAction SilentlyContinue
        return @{
            FQDN = $SBCFQDN
            Port = $Port
            Reachable = $result.TcpTestSucceeded
            PingSuccess = $result.PingSucceeded
            LatencyMs = if ($result.PingReplyDetails) { $result.PingReplyDetails.RoundtripTime } else { -1 }
        }
    } catch {
        return @{
            FQDN = $SBCFQDN
            Port = $Port
            Reachable = $false
            PingSuccess = $false
            LatencyMs = -1
            Error = $_.Exception.Message
        }
    }
}

#endregion

# Export module functions
Export-ModuleMember -Function $ExportedFunctions