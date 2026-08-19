<#
.SYNOPSIS
    Generates a report of Lync user registrations and their activity status.
.DESCRIPTION
    This script generates a report of Lync user registrations and their activity status.
    It provides insights into user registration details, including their last activity date and registration status.
    The report can be customized based on various parameters.
.PARAMETER OrganizationName
    The name of the organization for which the report is being generated.
.PARAMETER ReportPath
    The file path where the report will be saved.
.PARAMETER SampleUserCount
    The number of sample users to include in the report.
.PARAMETER RecentModifiedDays
    The number of days to consider for recent modifications.
.PARAMETER SBAPattern
    The pattern used to identify Survivable Branch Appliances (SBA).
.EXAMPLE
    Get-LyncUserRegistrationReport -OrganizationName "Contoso" -ReportPath "C:\Reports\Contoso_Lync_Report.txt"
.NOTES
    Author: W. Ford
    Date: 2025-09-17       
    Purpose: Generate a report of Lync user registrations and their activity status.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$OrganizationName = "Organization",
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "C:\Reports\Lync_Users_Registration_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt",
    
    [Parameter(Mandatory=$false)]
    [int]$SampleUserCount = 10,
    
    [Parameter(Mandatory=$false)]
    [int]$RecentModifiedDays = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$SBAPattern = "*MSSBA*"
)
$Separator = "=" * 80

# Create reports directory if it doesn't exist
$ReportsDir = Split-Path $ReportPath -Parent
if (!(Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force
}

# Start report
$Report = @()
$Report += "$OrganizationName - LYNC USER AND REGISTRATION REPORT"
$Report += "Generated: $(Get-Date)"
$Report += "Server: $($env:COMPUTERNAME)"
$Report += $Separator
$Report += ""

# Section 1: Lync Enabled Users Summary
$Report += "LYNC ENABLED USERS SUMMARY"
$Report += $Separator
try {
    $LyncUsers = Get-CsUser -ErrorAction SilentlyContinue
    if ($LyncUsers) {
        $Report += "  Total Lync-enabled users: $($LyncUsers.Count)"
        $Report += ""
        
        # Group by registrar pool
        $UsersByPool = $LyncUsers | Group-Object RegistrarPool
        $Report += "  Users by Registrar Pool:"
        $UsersByPool | ForEach-Object {
            $Report += "    Pool: $($_.Name) - Users: $($_.Count)"
        }
        $Report += ""
        
        # Group by enabled status
        $EnabledUsers = $LyncUsers | Where-Object { $_.Enabled -eq $true }
        $DisabledUsers = $LyncUsers | Where-Object { $_.Enabled -eq $false }
        $Report += "  Enabled Users: $($EnabledUsers.Count)"
        $Report += "  Disabled Users: $($DisabledUsers.Count)"
        $Report += ""
        
    } else {
        $Report += "No Lync users found or Lync Management Shell not available."
        $Report += ""
    }
} catch {
    $Report += "Error retrieving Lync users: $($_.Exception.Message)"
    $Report += ""
}

# Section 2: User Services Configuration (corrected with actual properties)
$Report += "USER SERVICES CONFIGURATION"
$Report += $Separator
try {
    $UserServicesConfig = Get-CsUserServicesConfiguration -ErrorAction SilentlyContinue
    if ($UserServicesConfig) {
        $UserServicesConfig | ForEach-Object {
            $Report += "  Identity: $($_.Identity)"
            $Report += ""
            
            $Report += "  SUBSCRIPTION SETTINGS:"
            $Report += "    Min Subscription Expiration: $($_.MinSubscriptionExpiration) seconds"
            $Report += "    Default Subscription Expiration: $($_.DefaultSubscriptionExpiration) seconds"
            $Report += "    Max Subscription Expiration: $($_.MaxSubscriptionExpiration) seconds"
            $Report += "    Max Subscriptions: $($_.MaxSubscriptions)"
            $Report += ""
            
            $Report += "  USER LIMITS:"
            $Report += "    Max Contacts: $($_.MaxContacts)"
            $Report += "    Max Personal Notes: $($_.MaxPersonalNotes)"
            $Report += "    Max Scheduled Meetings Per Organizer: $($_.MaxScheduledMeetingsPerOrganizer)"
            $Report += ""
            
            $Report += "  MAINTENANCE & GRACE PERIODS:"
            $MaintenanceTime = $_.MaintenanceTimeOfDay
            $Report += "    Maintenance Time of Day: $($MaintenanceTime.ToString('HH:mm:ss'))"
            
            $AnonymousGrace = $_.AnonymousUserGracePeriod
            $Report += "    Anonymous User Grace Period: $($AnonymousGrace.Days) days, $($AnonymousGrace.Hours):$($AnonymousGrace.Minutes):$($AnonymousGrace.Seconds)"
            
            $DeactivationGrace = $_.DeactivationGracePeriod
            $Report += "    Deactivation Grace Period: $($DeactivationGrace.Days) days, $($DeactivationGrace.Hours):$($DeactivationGrace.Minutes):$($DeactivationGrace.Seconds)"
            $Report += ""
            
            $Report += "  PRESENCE SETTINGS:"
            $Report += "    Subscribe to Collapsed Distribution Groups: $($_.SubscribeToCollapsedDG)"
            $Report += "    Presence Providers Count: $($_.PresenceProviders.Count)"
            $Report += ""
        }
    } else {
        $Report += "No user services configuration found."
        $Report += ""
    }
} catch {
    $Report += "User services configuration not available: $($_.Exception.Message)"
    $Report += ""
}

# Try to get Registrar Configuration (corrected with actual properties)
try {
    $RegistrarConfig = Get-CsRegistrarConfiguration -ErrorAction SilentlyContinue
    if ($RegistrarConfig) {
        $Report += "REGISTRAR CONFIGURATION"
        $Report += $Separator
        $RegistrarConfig | ForEach-Object {
            $Report += "  Identity: $($_.Identity)"
            $Report += "  Pool State: $($_.PoolState)"
            $Report += "  Max User Count: $($_.MaxUserCount)"
            $Report += ""
            
            $Report += "  ENDPOINT SETTINGS:"
            $Report += "    Min Endpoint Expiration: $($_.MinEndpointExpiration) seconds"
            $Report += "    Default Endpoint Expiration: $($_.DefaultEndpointExpiration) seconds"
            $Report += "    Max Endpoint Expiration: $($_.MaxEndpointExpiration) seconds"
            $Report += "    Max Endpoints Per User: $($_.MaxEndpointsPerUser)"
            $Report += ""
            
            $Report += "  BACKUP SETTINGS:"
            $BackupThreshold = $_.BackupStoreUnavailableThreshold
            $Report += "    Backup Store Unavailable Threshold: $($BackupThreshold.Days) days, $($BackupThreshold.Hours):$($BackupThreshold.Minutes):$($BackupThreshold.Seconds)"
            $Report += ""
            
            $EnableDHCP = if ($_.EnableDHCPServer -eq "") { "False (Default)" } else { $_.EnableDHCPServer }
            $Report += "  DHCP SERVER ENABLED: $EnableDHCP"
            $Report += ""
        }
    }
} catch {
    $Report += "Registrar configuration not available: $($_.Exception.Message)"
    $Report += ""
}

# Section 3: Sample User Details (First $SampleUserCount users)
$Report += "SAMPLE USER DETAILS (First $SampleUserCount users)"
$Report += $Separator
try {
    $SampleUsers = Get-CsUser -ResultSize $SampleUserCount -ErrorAction SilentlyContinue
    if ($SampleUsers) {
        $SampleUsers | ForEach-Object {
            $Report += "  User: $($_.Identity)"
            $Report += "  Display Name: $($_.DisplayName)"
            $Report += "  SIP Address: $($_.SipAddress)"
            $Report += "  Enabled: $($_.Enabled)"
            $Report += "  Registrar Pool: $($_.RegistrarPool)"
            $Report += "  Voice Policy: $($_.VoicePolicy)"
            $Report += "  Conferencing Policy: $($_.ConferencingPolicy)"
            $Report += ""
        }
    } else {
        $Report += "No sample users available."
        $Report += ""
    }
} catch {
    $Report += "Error retrieving sample user details: $($_.Exception.Message)"
    $Report += ""
}

# Section 4: User Sessions and Activity
$Report += "USER SESSIONS AND ACTIVITY"
$Report += $Separator
try {
    # Try alternative methods since Get-CsUserSession doesn't exist
    $Report += "ACTIVE USER ANALYSIS"
    $Report += $Separator
    
    # Method 1: Check for presence information
    try {
        # Try Get-CsPresenceState if available
        $PresenceStates = Get-CsPresenceState -ErrorAction SilentlyContinue
        if ($PresenceStates) {
            $Report += "Presence information retrieved successfully"
            $Report += "Active presence states found: $($PresenceStates.Count)"
            $Report += ""
        }
    } catch {
        $Report += "Presence state information not available"
    }
    
    # Method 2: Use WMI to check for Lync processes on remote systems (if accessible)
    try {
        $LyncProcesses = Get-WmiObject -Class Win32_Process -Filter "Name LIKE '%communicator%' OR Name LIKE '%lync%' OR Name LIKE '%skype%'" -ErrorAction SilentlyContinue
        if ($LyncProcesses) {
            $Report += "LOCAL LYNC CLIENT PROCESSES:"
            $LyncProcesses | Group-Object Name | ForEach-Object {
                $Report += "  Process: $($_.Name) - Count: $($_.Count)"
            }
            $Report += ""
        }
    } catch {
        $Report += "Could not retrieve local process information"
    }
    
    # Method 3: Analyze user properties to infer activity
    try {
        $Users = Get-CsUser -ErrorAction SilentlyContinue
        if ($Users) {
            $Report += "USER ACTIVITY ANALYSIS (Based on Configuration):"
            $Report += $Separator
            
            # Users with recent changes (activity indicator)
            $RecentlyModified = $Users | Where-Object { 
                $_.WhenChanged -and (Get-Date) - $_.WhenChanged -lt (New-TimeSpan -Days $RecentModifiedDays) 
            }
            $Report += "Users modified in last $RecentModifiedDays days: $($RecentlyModified.Count)"
            
            # Users with line URIs (likely active voice users)
            $VoiceActiveUsers = $Users | Where-Object { $_.LineURI -and $_.EnterpriseVoiceEnabled -eq $true }
            $Report += "Active voice users (with Line URI): $($VoiceActiveUsers.Count)"
            
            # Users enabled for various services
            $PresenceUsers = $Users | Where-Object { $_.EnabledForRichPresence -eq $true }
            $FederationUsers = $Users | Where-Object { $_.EnabledForFederation -eq $true }
            $InternetUsers = $Users | Where-Object { $_.EnabledForInternetAccess -eq $true }
            
            $Report += "Rich presence enabled: $($PresenceUsers.Count)"
            $Report += "Federation enabled: $($FederationUsers.Count)"
            $Report += "Internet access enabled: $($InternetUsers.Count)"
            $Report += ""
            
            # Sample of recently modified users
            if ($RecentlyModified.Count -gt 0) {
                $Report += "RECENTLY MODIFIED USERS (Sample):"
                $RecentlyModified | Sort-Object WhenChanged -Descending | Select-Object -First 5 | ForEach-Object {
                    $Report += "  User: $($_.DisplayName)"
                    $Report += "  Last Modified: $($_.WhenChanged)"
                    $Report += "  Pool: $($_.RegistrarPool)"
                    $Report += ""
                }
            }
        }
    } catch {
        $Report += "Could not analyze user activity: $($_.Exception.Message)"
    }
    
    $Report += "NOTE: Detailed session information requires specific Lync server roles"
    $Report += "or access to monitoring databases. This analysis uses available user"
    $Report += "configuration data to infer activity patterns."
    $Report += ""
    
} catch {
    $Report += "Error retrieving user session information: $($_.Exception.Message)"
    $Report += ""
}

# Section 5: User Pool Information
$Report += "USER POOL DISTRIBUTION"
$Report += $Separator
try {
    $Users = Get-CsUser -ErrorAction SilentlyContinue
    if ($Users) {
        $PoolDistribution = $Users | Where-Object { $_.RegistrarPool } | Group-Object RegistrarPool | Sort-Object Count -Descending
        $PoolDistribution | ForEach-Object {
            $Report += "  Pool: $($_.Name)"
            $Report += "  User Count: $($_.Count)"
            $Report += ""
        }
    }
} catch {
    $Report += "Error calculating pool distribution: $($_.Exception.Message)"
    $Report += ""
}

# Export report
$Report | Out-File -FilePath $ReportPath -Encoding UTF8
Write-Host "User and Registration Report exported to: $ReportPath" -ForegroundColor Green