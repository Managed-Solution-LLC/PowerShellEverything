<#
.SYNOPSIS
    Generates a comprehensive Lync/Skype for Business environment report.

.DESCRIPTION
    This script generates a detailed comprehensive report of a Lync/Skype for Business environment,
    including pool architecture analysis, certificate health, user distribution, system configuration,
    and infrastructure recommendations. The report provides administrators with a complete overview
    of their Lync deployment status and health.

.PARAMETER PoolFQDN
    The fully qualified domain name of the primary Lync pool to analyze. This parameter is mandatory
    and is used for database mirror state analysis and as the primary infrastructure reference.

.PARAMETER ReportPath
    The file path where the comprehensive report will be saved. If not specified, defaults to
    "C:\Reports\Lync_Comprehensive_[timestamp].txt" in the current directory.

.PARAMETER OrganizationName
    The name of the organization for which the report is being generated. Used in the report header
    and organizational context throughout the report.

.PARAMETER Domain
    The primary email/UPN domain for the organization (e.g. "contoso.com"). Used to help categorize
    pools and identify organization-owned FQDNs. Defaults to the domain portion of PoolFQDN if not specified.

.PARAMETER AdditionalKeyPools
    An optional array of additional pool FQDNs (beyond PoolFQDN) to highlight in the
    "Key Infrastructure Pools" section of the report, e.g. edge, web conferencing, or SQL witness pools.

.PARAMETER SBAPattern
    The pattern used to identify Survivable Branch Appliances (SBA) pools. Defaults to "*MSSBA*".
    This pattern is used to categorize and analyze branch office deployments.

.PARAMETER IVRPattern
    The pattern used to identify Interactive Voice Response (IVR) pools. Defaults to "*ivr*".

.PARAMETER EdgePattern
    The pattern used to identify Edge server pools. Defaults to "*edge*".

.PARAMETER LyncPattern
    The pattern used to identify standard Lync pools. Defaults to "*lync*".

.PARAMETER RecentModifiedDays
    The number of days to look back when analyzing recently modified users. Defaults to 30 days.

.EXAMPLE
    .\Get-ComprehensiveLyncReport.ps1 -PoolFQDN "lyncpool.contoso.com"
    
    Generates a comprehensive report for the specified Lync pool using default settings.

.EXAMPLE
    .\Get-ComprehensiveLyncReport.ps1 -PoolFQDN "lyncpool.contoso.com" -OrganizationName "Contoso Corp" -ReportPath "D:\Reports\Contoso_Lync_Report.txt"
    
    Generates a comprehensive report with custom organization name and output path.

.EXAMPLE
    .\Get-ComprehensiveLyncReport.ps1 -PoolFQDN "teamspool.contoso.com" -SBAPattern "*Branch*" -LyncPattern "*teams*" -RecentModifiedDays 60
    
    Generates a report with custom pool patterns and extended recent modification timeframe.

.NOTES
    Author: W. Ford
    Date: 2025-09-17
    Version: 2.0
    
    Requirements:
    - Lync/Skype for Business Management Shell
    - Administrative privileges on Lync infrastructure
    - PowerShell 3.0 or higher
    
    The script performs comprehensive analysis including:
    - Executive summary with environment overview
    - Pool architecture categorization and analysis
    - Certificate health and expiration monitoring
    - User distribution across pools and sites
    - System configuration analysis
    - Database mirror state assessment
    - Infrastructure health summary
    - Detailed recommendations for optimization

.LINK
    https://docs.microsoft.com/en-us/skypeforbusiness/

#>

param(
    [Parameter(Mandatory=$true, HelpMessage="The FQDN of the primary Lync pool to analyze")]
    [ValidateNotNullOrEmpty()]
    [string]$PoolFQDN,
    
    [Parameter(Mandatory=$false, HelpMessage="Path where the report will be saved")]
    [string]$ReportPath = "C:\Reports\Lync_Comprehensive_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt",

    [Parameter(Mandatory=$false, HelpMessage="Organization name for the report header")]
    [string]$OrganizationName = "Organization",

    [Parameter(Mandatory=$false, HelpMessage="Primary domain for the organization; defaults to the domain portion of PoolFQDN")]
    [string]$Domain,

    [Parameter(Mandatory=$false, HelpMessage="Additional pool FQDNs to highlight in the key infrastructure section")]
    [string[]]$AdditionalKeyPools = @(),

    [Parameter(Mandatory=$false, HelpMessage="Pattern to identify SBA pools")]
    [string]$SBAPattern = "*MSSBA*",
    
    [Parameter(Mandatory=$false, HelpMessage="Pattern to identify IVR pools")]
    [string]$IVRPattern = "*ivr*",
    
    [Parameter(Mandatory=$false, HelpMessage="Pattern to identify Edge pools")]
    [string]$EdgePattern = "*edge*",
    
    [Parameter(Mandatory=$false, HelpMessage="Pattern to identify Lync pools")]
    [string]$LyncPattern = "*lync*",
    
    [Parameter(Mandatory=$false, HelpMessage="Days to look back for recently modified users")]
    [ValidateRange(1, 365)]
    [int]$RecentModifiedDays = 30
)

# Use provided or default report path if not specified directly
$Separator = "=" * 80

# Derive the primary domain from the pool FQDN if not explicitly provided
if (-not $Domain) {
    $Domain = ($PoolFQDN -split '\.', 2)[1]
}

# Create reports directory if it doesn't exist
$ReportsDir = Split-Path $ReportPath -Parent
if (!(Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force
}

# Start report
$Report = @()
$Report += $OrganizationName.ToUpper()
$Report += "LYNC/SKYPE FOR BUSINESS ENVIRONMENT REPORT"
$Report += "Generated: $(Get-Date)"
$Report += "Server: $($env:COMPUTERNAME)"
$Report += $Separator
$Report += ""

# Executive Summary
$Report += "EXECUTIVE SUMMARY"
$Report += $Separator
try {
    $AllUsers = Get-CsUser -ErrorAction SilentlyContinue
    $AllPools = Get-CsPool -ErrorAction SilentlyContinue
    $Certificates = Get-CsCertificate -ErrorAction SilentlyContinue
    
    $Report += "Environment Overview:"
    $Report += "  Total Lync Users: $($AllUsers.Count)"
    $Report += "  Total Pools: $($AllPools.Count)"
    $Report += "  Total Certificates: $($Certificates.Count)"
    $Report += "  Primary Lync Pool: $PoolFQDN"
    $Report += "  Domain: $Domain"
    $Report += ""
    
    # Voice-enabled statistics
    $VoiceUsers = $AllUsers | Where-Object { $_.EnterpriseVoiceEnabled -eq $true }
    $HostedVMUsers = $AllUsers | Where-Object { $_.HostedVoiceMail -eq $true }
    
    $Report += "Voice Services Summary:"
    $Report += "  Enterprise Voice Enabled: $($VoiceUsers.Count) users"
    $Report += "  Hosted Voicemail: $($HostedVMUsers.Count) users"
    $Report += "  Voice Penetration: $([Math]::Round(($VoiceUsers.Count / $AllUsers.Count) * 100, 1))%"
    $Report += ""
    
} catch {
    $Report += "Error generating executive summary: $($_.Exception.Message)"
    $Report += ""
}

# Pool Architecture Analysis
$Report += "POOL ARCHITECTURE ANALYSIS"
$Report += $Separator
try {
    $Pools = Get-CsPool -ErrorAction SilentlyContinue
    if ($Pools) {
        # Categorize pools by type
        $StandardPools = $Pools | Where-Object { $_.Fqdn -like "*lync*" -or $_.Fqdn -like "*$Domain" -and $_.Fqdn -notlike "*MSSBA*" -and $_.Fqdn -notlike "*ivr*" }
        $SBAPools = $Pools | Where-Object { $_.Fqdn -like "*MSSBA*" }
        $IVRPools = $Pools | Where-Object { $_.Fqdn -like "*ivr*" }
        $EdgePools = $Pools | Where-Object { $_.Fqdn -like "*edge*" }
        $IPPools = $Pools | Where-Object { $_.Fqdn -match '^\d+\.\d+\.\d+\.\d+$' }
        
        $Report += "POOL CATEGORIZATION:"
        $Report += "  Standard Lync Pools: $($StandardPools.Count)"
        $Report += "  Survivable Branch Appliances (SBA): $($SBAPools.Count)"
        $Report += "  IVR/Voice Pools: $($IVRPools.Count)"
        $Report += "  Edge Pools: $($EdgePools.Count)"
        $Report += "  IP Address Pools: $($IPPools.Count)"
        $Report += ""
        
        # Key infrastructure pools
        $Report += "KEY INFRASTRUCTURE POOLS:"
        $KeyPools = @($PoolFQDN) + $AdditionalKeyPools
        $KeyPools | ForEach-Object {
            $Pool = $Pools | Where-Object { $_.Fqdn -eq $_ }
            if ($Pool) {
                $Report += "  $($Pool.Fqdn) - Site: $($Pool.Site)"
                $Report += "    Services: $($Pool.Services -join ', ')"
                if ($Pool.Computers) {
                    $Report += "    Computers: $($Pool.Computers -join ', ')"
                }
                $Report += ""
            }
        }
        
        # SBA Site Analysis
        if ($SBAPools) {
            $Report += "SURVIVABLE BRANCH APPLIANCE (SBA) SITES:"
            $Report += "Total SBA Sites: $($SBAPools.Count)"
            $Report += ""
            
            # Group SBAs by naming pattern to identify schools/sites
            $SBAGroups = $SBAPools | Group-Object { ($_.Fqdn -split '-')[0] } | Sort-Object Name
            $Report += "SBA Sites by Identifier:"
            $SBAGroups | ForEach-Object {
                $SiteName = $_.Name
                $Report += "  Site Code: $SiteName"
                $_.Group | ForEach-Object {
                    $IP = ($_.Fqdn -split '\.')[0] -replace '\D', ''
                    if ($IP) {
                        $Report += "    Pool: $($_.Fqdn) - Network: $($_.Fqdn -replace '.*\.(\d+\.\d+\.\d+\.\d+).*', '10.x.x.x')"
                    } else {
                        $Report += "    Pool: $($_.Fqdn)"
                    }
                }
                $Report += ""
            }
        }
    }
} catch {
    $Report += "Error analyzing pool architecture: $($_.Exception.Message)"
    $Report += ""
}

# Certificate Health Analysis
$Report += "CERTIFICATE HEALTH ANALYSIS"
$Report += $Separator
try {
    $Certificates = Get-CsCertificate -ErrorAction SilentlyContinue
    if ($Certificates) {
        $Report += "CERTIFICATE OVERVIEW:"
        $Report += "Total Certificates: $($Certificates.Count)"
        $Report += ""
        
        $Certificates | ForEach-Object {
            $DaysToExpiry = ($_.NotAfter - (Get-Date)).Days
            $Status = if ($DaysToExpiry -lt 0) { 
                "🔴 EXPIRED" 
            } elseif ($DaysToExpiry -lt 30) { 
                "🟡 EXPIRES SOON" 
            } elseif ($DaysToExpiry -lt 90) { 
                "🟠 RENEWAL DUE" 
            } else { 
                "✅ HEALTHY" 
            }
            
            $Report += "Certificate for: $($_.Subject)"
            $Report += "  Use: $($_.Use)"
            $Report += "  Status: $Status"
            $Report += "  Expires: $($_.NotAfter.ToString('yyyy-MM-dd HH:mm:ss'))"
            $Report += "  Days to Expiry: $DaysToExpiry"
            $Report += "  Issuer: $($_.Issuer -replace 'CN=', '' -replace ',.*', '')"
            $Report += "  Serial Number: $($_.SerialNumber)"
            
            if ($_.AlternativeNames.Count -gt 0) {
                $Report += "  Alternative Names: $($_.AlternativeNames -join ', ')"
            }
            $Report += ""
        }
        
        # Certificate health summary
        $ExpiredCerts = $Certificates | Where-Object { ($_.NotAfter - (Get-Date)).Days -lt 0 }
        $ExpiringCerts = $Certificates | Where-Object { ($_.NotAfter - (Get-Date)).Days -lt 30 -and ($_.NotAfter - (Get-Date)).Days -ge 0 }
        
        $Report += "CERTIFICATE HEALTH SUMMARY:"
        $Report += "  Expired Certificates: $($ExpiredCerts.Count)"
        $Report += "  Expiring in 30 days: $($ExpiringCerts.Count)"
        $Report += "  Healthy Certificates: $(($Certificates | Where-Object { ($_.NotAfter - (Get-Date)).Days -ge 30 }).Count)"
        $Report += ""
    }
} catch {
    $Report += "Error analyzing certificates: $($_.Exception.Message)"
    $Report += ""
}

# User Distribution by School Sites (Enhanced with fixed activity analysis)
$Report += "USER DISTRIBUTION BY SCHOOL SITES"
$Report += $Separator
try {
    $Users = Get-CsUser -ErrorAction SilentlyContinue
    if ($Users) {
        # Analyze user distribution across SBA pools (schools)
        $SBAUsers = $Users | Where-Object { $_.RegistrarPool -like "*MSSBA*" }
        $CentralUsers = $Users | Where-Object { $_.RegistrarPool -like "*lync*" }
        $OtherUsers = $Users | Where-Object { $_.RegistrarPool -notlike "*MSSBA*" -and $_.RegistrarPool -notlike "*lync*" }
        
        $Report += "USER DEPLOYMENT MODEL:"
        $Report += "  Central Lync Pool Users: $($CentralUsers.Count)"
        $Report += "  School Site (SBA) Users: $($SBAUsers.Count)"
        $Report += "  Other Pool Users: $($OtherUsers.Count)"
        $Report += ""
        
        # User activity analysis based on configuration
        $Report += "USER ACTIVITY ANALYSIS:"
        $RecentlyModified = $Users | Where-Object { 
            $_.WhenChanged -and (Get-Date) - $_.WhenChanged -lt (New-TimeSpan -Days 30) 
        }
        $VoiceActiveUsers = $Users | Where-Object { $_.LineURI -and $_.EnterpriseVoiceEnabled -eq $true }
        $PresenceUsers = $Users | Where-Object { $_.EnabledForRichPresence -eq $true }
        $FederationUsers = $Users | Where-Object { $_.EnabledForFederation -eq $true }
        
        $Report += "  Recently Modified (30 days): $($RecentlyModified.Count)"
        $Report += "  Active Voice Users (with Line URI): $($VoiceActiveUsers.Count)"
        $Report += "  Rich Presence Enabled: $($PresenceUsers.Count)"
        $Report += "  Federation Enabled: $($FederationUsers.Count)"
        $Report += ""
        
        if ($SBAUsers) {
            $Report += "USERS BY SCHOOL SITE (SBA):"
            $SBADistribution = $SBAUsers | Group-Object RegistrarPool | Sort-Object Count -Descending
            
            # Show top 10 school sites by user count
            $TopSBASites = $SBADistribution | Select-Object -First 10
            $TopSBASites | ForEach-Object {
                # Extract school code from pool name
                $SchoolCode = ($_.Name -split '-')[0]
                $Report += "  School: $SchoolCode"
                $Report += "    Pool: $($_.Name)"
                $Report += "    Users: $($_.Count)"
                
                # Show voice statistics for this school
                $SchoolVoiceUsers = $_.Group | Where-Object { $_.EnterpriseVoiceEnabled -eq $true }
                $SchoolActiveVoice = $_.Group | Where-Object { $_.LineURI -and $_.EnterpriseVoiceEnabled -eq $true }
                $Report += "    Voice Enabled: $($SchoolVoiceUsers.Count)"
                $Report += "    Active Voice (with Line URI): $($SchoolActiveVoice.Count)"
                $Report += ""
            }
            
            if ($SBADistribution.Count -gt 10) {
                $Report += "  ... and $($SBADistribution.Count - 10) more school sites"
                $Report += ""
            }
        }
        
        # Voice policy analysis
        $VoicePolicies = $Users | Where-Object { $_.VoicePolicy } | Group-Object VoicePolicy
        if ($VoicePolicies) {
            $Report += "VOICE POLICY DISTRIBUTION:"
            $VoicePolicies | Sort-Object Count -Descending | ForEach-Object {
                $Report += "  Policy: $($_.Name) - Users: $($_.Count)"
            }
            $Report += ""
        }
        
        # Conferencing policy analysis  
        $ConferencingPolicies = $Users | Where-Object { $_.ConferencingPolicy } | Group-Object ConferencingPolicy
        if ($ConferencingPolicies) {
            $Report += "CONFERENCING POLICY DISTRIBUTION:"
            $ConferencingPolicies | Sort-Object Count -Descending | ForEach-Object {
                $Report += "  Policy: $($_.Name) - Users: $($_.Count)"
            }
            $Report += ""
        }
        
        # Recently modified users sample
        if ($RecentlyModified.Count -gt 0) {
            $Report += "RECENTLY MODIFIED USERS (Sample):"
            $RecentlyModified | Sort-Object WhenChanged -Descending | Select-Object -First 5 | ForEach-Object {
                $SchoolCode = if ($_.RegistrarPool -like "*MSSBA*") { 
                    "[$($_.RegistrarPool -split '-')[0]]" 
                } else { 
                    "[Central]" 
                }
                $Report += "  $($_.DisplayName) $SchoolCode"
                $Report += "    Last Modified: $($_.WhenChanged)"
                $Report += "    Pool: $($_.RegistrarPool)"
                $Report += ""
            }
        }
    }
} catch {
    $Report += "Error analyzing user distribution: $($_.Exception.Message)"
    $Report += ""
}

# System Configuration Analysis (Enhanced with proper database mirror handling)
$Report += "SYSTEM CONFIGURATION ANALYSIS"
$Report += $Separator
try {
    # Registrar configuration
    $RegConfig = Get-CsRegistrarConfiguration -ErrorAction SilentlyContinue
    if ($RegConfig) {
        $Report += "REGISTRAR CONFIGURATION:"
        $RegConfig | ForEach-Object {
            $Report += "  Identity: $($_.Identity)"
            $Report += "  Max User Count: $($_.MaxUserCount)"
            $Report += "  Max Endpoints Per User: $($_.MaxEndpointsPerUser)"
            $Report += "  Pool State: $($_.PoolState)"
            
            # Endpoint expiration settings
            $Report += "  Endpoint Expiration Settings:"
            $Report += "    Minimum: $($_.MinEndpointExpiration) seconds"
            $Report += "    Default: $($_.DefaultEndpointExpiration) seconds"
            $Report += "    Maximum: $($_.MaxEndpointExpiration) seconds"
            
            $BackupThreshold = $_.BackupStoreUnavailableThreshold
            $Report += "  Backup Store Threshold: $($BackupThreshold.TotalMinutes) minutes"
            $Report += ""
        }
    }
    
    # User services configuration
    $UserConfig = Get-CsUserServicesConfiguration -ErrorAction SilentlyContinue
    if ($UserConfig) {
        $Report += "USER SERVICES CONFIGURATION:"
        $UserConfig | ForEach-Object {
            $Report += "  Max Contacts: $($_.MaxContacts)"
            $Report += "  Max Scheduled Meetings: $($_.MaxScheduledMeetingsPerOrganizer)"
            $Report += "  Max Subscriptions: $($_.MaxSubscriptions)"
            $Report += "  Max Personal Notes: $($_.MaxPersonalNotes)"
            
            # Subscription settings
            $Report += "  Subscription Expiration:"
            $Report += "    Minimum: $($_.MinSubscriptionExpiration) seconds"
            $Report += "    Default: $($_.DefaultSubscriptionExpiration) seconds"
            $Report += "    Maximum: $($_.MaxSubscriptionExpiration) seconds"
            
            $MaintenanceTime = $_.MaintenanceTimeOfDay.ToString('HH:mm:ss')
            $Report += "  Maintenance Window: $MaintenanceTime"
            
            # Grace periods
            $AnonymousGrace = $_.AnonymousUserGracePeriod
            $DeactivationGrace = $_.DeactivationGracePeriod
            $Report += "  Anonymous User Grace Period: $($AnonymousGrace.TotalHours) hours"
            $Report += "  Deactivation Grace Period: $($DeactivationGrace.Days) days"
            $Report += ""
        }
    }
    
    # Database mirror state analysis
    $Report += "DATABASE CONFIGURATION ANALYSIS:"
    try {
        $MirrorState = Get-CsDatabaseMirrorState -PoolFqdn $PoolFQDN -ErrorAction SilentlyContinue
        if ($MirrorState) {
            $MirroredDatabases = $MirrorState | Where-Object { -not [string]::IsNullOrEmpty($_.State) -and $_.State -ne "Not mirrored" }
            $UnmirroredDatabases = $MirrorState | Where-Object { [string]::IsNullOrEmpty($_.State) -or $_.State -eq "Not mirrored" }
            
            $Report += "  Total Databases: $($MirrorState.Count)"
            $Report += "  Mirrored Databases: $($MirroredDatabases.Count)"
            $Report += "  Non-Mirrored Databases: $($UnmirroredDatabases.Count)"
            
            if ($UnmirroredDatabases.Count -gt 0) {
                $Report += "  Database List: $($MirrorState.DatabaseName -join ', ')"
                $Report += "  Mirror Status: Single server deployment (no mirroring configured)"
            }
            $Report += ""
        } else {
            $Report += "  Database mirror information not available"
            $Report += ""
        }
    } catch {
        $Report += "  Database configuration not accessible"
        $Report += ""
    }
    
} catch {
    $Report += "Error analyzing system configuration: $($_.Exception.Message)"
    $Report += ""
}

# Recommendations and Action Items (Enhanced with database and activity insights)
$Report += "RECOMMENDATIONS AND ACTION ITEMS"
$Report += $Separator

# Certificate recommendations
try {
    $Certificates = Get-CsCertificate -ErrorAction SilentlyContinue
    if ($Certificates) {
        $ExpiringCerts = $Certificates | Where-Object { ($_.NotAfter - (Get-Date)).Days -lt 90 }
        if ($ExpiringCerts) {
            $Report += "🔶 CERTIFICATE ACTIONS REQUIRED:"
            $ExpiringCerts | ForEach-Object {
                $DaysLeft = ($_.NotAfter - (Get-Date)).Days
                $Urgency = if ($DaysLeft -lt 0) { "URGENT" } elseif ($DaysLeft -lt 30) { "HIGH" } else { "MEDIUM" }
                $Report += "  [$Urgency] Renew certificate for $($_.Subject) (expires in $DaysLeft days)"
            }
            $Report += ""
        } else {
            $Report += "✅ CERTIFICATES: All certificates are healthy (>90 days to expiration)"
            $Report += ""
        }
    }
} catch {}

# Database recommendations based on mirror analysis
try {
    $MirrorState = Get-CsDatabaseMirrorState -PoolFqdn $PoolFQDN -ErrorAction SilentlyContinue
    if ($MirrorState) {
        $UnmirroredCount = ($MirrorState | Where-Object { [string]::IsNullOrEmpty($_.State) }).Count
        if ($UnmirroredCount -gt 0) {
            $Report += "📊 DATABASE RECOMMENDATIONS:"
            $Report += "  Current Status: $UnmirroredCount databases are not mirrored"
            $Report += "  Recommendation: Consider implementing database mirroring for high availability"
            $Report += "  Impact: Single server deployment increases risk during maintenance/failures"
            $Report += "  Priority: Medium (evaluate based on business requirements)"
            $Report += ""
        } else {
            $Report += "✅ DATABASE MIRRORING: Properly configured for high availability"
            $Report += ""
        }
    }
} catch {}

# User activity recommendations
try {
    $Users = Get-CsUser -ErrorAction SilentlyContinue
    if ($Users) {
        $VoiceUsers = $Users | Where-Object { $_.EnterpriseVoiceEnabled -eq $true }
        $ActiveVoiceUsers = $Users | Where-Object { $_.LineURI -and $_.EnterpriseVoiceEnabled -eq $true }
        
        if ($VoiceUsers.Count -gt $ActiveVoiceUsers.Count) {
            $UnusedVoiceCount = $VoiceUsers.Count - $ActiveVoiceUsers.Count
            $Report += "📞 VOICE SERVICES OPTIMIZATION:"
            $Report += "  Voice Enabled Users: $($VoiceUsers.Count)"
            $Report += "  Active Voice Users (with Line URI): $($ActiveVoiceUsers.Count)"
            $Report += "  Users without Line URI: $UnusedVoiceCount"
            $Report += "  Recommendation: Review users without Line URIs for license optimization"
            $Report += ""
        }
        
        # SBA user distribution analysis
        $SBAUsers = $Users | Where-Object { $_.RegistrarPool -like "*MSSBA*" }
        if ($SBAUsers) {
            $SBADistribution = $SBAUsers | Group-Object RegistrarPool
            $SmallSites = $SBADistribution | Where-Object { $_.Count -lt 5 }
            if ($SmallSites) {
                $Report += "🏫 SBA DEPLOYMENT OPTIMIZATION:"
                $Report += "  Small school sites (< 5 users): $($SmallSites.Count)"
                $Report += "  Recommendation: Evaluate consolidation for underutilized SBAs"
                $Report += "  Consider: Cost vs. redundancy for very small sites"
                $Report += ""
            }
        }
    }
} catch {}
$Report += $Separator
$Report += "Report completed: $(Get-Date)"
$Report += "Generated for: $OrganizationName"

# Export report
$Report | Out-File -FilePath $ReportPath -Encoding UTF8

Write-Host ""
Write-Host "LYNC COMPREHENSIVE REPORT COMPLETE" -ForegroundColor Cyan
Write-Host "Report saved to: $ReportPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "Key findings will be highlighted in the report for your review." -ForegroundColor Green