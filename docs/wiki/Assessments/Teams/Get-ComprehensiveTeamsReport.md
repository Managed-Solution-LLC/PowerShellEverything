# Get-ComprehensiveTeamsReport.ps1

## Overview
Generates a comprehensive Microsoft Teams infrastructure report providing complete visibility into Teams deployment, configuration, voice infrastructure, meeting settings, compliance features, and licensing. This assessment tool helps administrators understand their Teams environment health, identify configuration issues, and plan for optimization or migration.

The script connects to Microsoft Teams PowerShell and optionally Microsoft Graph to gather detailed information across all Teams configuration areas, generating both text reports and optional CSV exports for further analysis.

## Features
- **Tenant Configuration**: Teams tenant settings, federation, external access
- **Policy Analysis**: All Teams policies (calling, meeting, messaging, app setup)
- **Voice Infrastructure**: Direct Routing, Calling Plans, SBC status, voice routing
- **User Licensing**: Teams license distribution and usage analytics
- **Meeting Configuration**: Meeting policies, settings, and room systems
- **Compliance Analysis**: DLP policies, retention policies, audit configurations
- **Teams & Channels**: Detailed Teams inventory with membership
- **Executive Summary**: Key findings and recommendations
- **CSV Export**: Optional detailed data export for offline analysis

## Prerequisites

### PowerShell Requirements
- **PowerShell 5.1 or later** (PowerShell 7+ recommended)
- **Administrator role** in Microsoft Teams

### Required Modules
- **MicrosoftTeams** - Auto-checked and prompted if missing
- **Microsoft.Graph.Authentication** (optional) - For enhanced user and licensing data
- **Microsoft.Graph.Users** (optional) - For user details if `-IncludeUserDetails` used

### Required Permissions
**Teams Admin Roles** (one of):
- Global Administrator
- Teams Administrator
- Teams Communications Administrator (for voice analysis)

**Graph Permissions** (if using `-IncludeUserDetails` or `-IncludeComplianceAnalysis`):
- `User.Read.All`
- `Directory.Read.All`
- `Policy.Read.All` (for compliance)

## Parameters

### Optional Parameters

#### -TenantId
The Azure AD tenant ID for the Teams environment to analyze.

**Type**: String  
**Default**: Current connected tenant context  
**Example**: `"contoso.onmicrosoft.com"` or `"12345678-1234-1234-1234-123456789012"`

#### -ReportPath
The file path where the comprehensive report will be saved.

**Type**: String  
**Default**: `C:\Reports\Teams_Infrastructure_Report_[timestamp].txt`  
**Example**: `"D:\Reports\Contoso_Teams_Report.txt"`

#### -OrganizationName
The name of the organization for the report header.

**Type**: String  
**Default**: "Organization"  
**Example**: `"Contoso Corporation"`, `"Fabrikam Inc"`

#### -IncludeUserDetails
Include detailed user information in the report.

**Type**: Switch  
**Default**: False  
**Includes**: User licensing, policy assignments, usage statistics  
**Note**: Significantly increases report generation time for large tenants

#### -IncludeVoiceAnalysis
Include detailed voice infrastructure analysis.

**Type**: Switch  
**Default**: False  
**Includes**: Calling plans, Direct Routing configuration, SBC status, voice routes, dial plans  
**Requirements**: Teams Communications Administrator role

#### -IncludeComplianceAnalysis
Include compliance and security analysis.

**Type**: Switch  
**Default**: False  
**Includes**: DLP policies, retention policies, audit configurations  
**Requirements**: Compliance Administrator or Security Reader role

#### -ExportToCSV
Export detailed data to CSV files for further analysis.

**Type**: Switch  
**Default**: False  
**Output**: Creates multiple CSV files in same directory as report

## Usage Examples

### Example 1: Basic Infrastructure Report
```powershell
.\Get-ComprehensiveTeamsReport.ps1
```
Generates basic comprehensive report for current tenant with default settings.

### Example 2: Organization-Branded Report
```powershell
.\Get-ComprehensiveTeamsReport.ps1 -OrganizationName "Contoso Corp" -ReportPath "D:\Reports\Contoso_Teams_Report.txt"
```
Creates report with organization branding and custom output location.

### Example 3: Detailed Report with User Information
```powershell
.\Get-ComprehensiveTeamsReport.ps1 -OrganizationName "Contoso" -IncludeUserDetails
```
Includes detailed user licensing and policy assignments. **Warning**: Slow for large tenants.

### Example 4: Voice Infrastructure Assessment
```powershell
.\Get-ComprehensiveTeamsReport.ps1 -IncludeVoiceAnalysis -ExportToCSV
```
Comprehensive voice infrastructure analysis with CSV exports for SBC configs and voice routes.

### Example 5: Complete Assessment with All Features
```powershell
.\Get-ComprehensiveTeamsReport.ps1 `
    -OrganizationName "Contoso Corporation" `
    -IncludeUserDetails `
    -IncludeVoiceAnalysis `
    -IncludeComplianceAnalysis `
    -ExportToCSV `
    -ReportPath "C:\Assessments\Contoso_Complete_Teams_Report.txt"
```
Full assessment with all optional features enabled.

### Example 6: Quick Voice-Only Assessment
```powershell
.\Get-ComprehensiveTeamsReport.ps1 -IncludeVoiceAnalysis | Select-String "Voice|Calling|SBC|Route"
```
Generates report and filters for voice-related sections only.

## Assessment Sections

### 1. Executive Summary
- Total Teams and channels
- Active users count
- Voice enablement statistics
- Key findings and recommendations
- Configuration health score

### 2. Tenant Configuration
- Teams tenant settings
- Federation configuration
- External access settings
- Guest user settings
- File sharing configuration
- Meeting settings
- Messaging settings

### 3. Teams Policies
**Calling Policies**:
- Make private calls
- Call forwarding settings
- Simultaneous ringing
- Call park configuration
- Busy on busy settings

**Meeting Policies**:
- Meeting participant settings
- Audio/video configuration
- Content sharing permissions
- Recording policies
- Transcription settings

**Messaging Policies**:
- Chat settings
- Channel messaging permissions
- Content moderation
- Priority notifications

**App Setup Policies**:
- Pinned apps configuration
- App installation permissions
- Custom app sideloading

**Live Events Policies**:
- Live event permissions
- Recording settings
- Transcription options

### 4. Voice Infrastructure (if `-IncludeVoiceAnalysis`)
- **Direct Routing Configuration**:
  - Session Border Controllers (SBCs)
  - SBC health status
  - Voice routing policies
  - PSTN usage records
  
- **Calling Plans**:
  - Assigned phone numbers
  - Calling plan subscriptions
  - Emergency addresses
  - Number assignments

- **Dial Plans**:
  - Normalization rules
  - External access prefix
  - Number patterns

### 5. User Analysis (if `-IncludeUserDetails`)
- User licensing breakdown
- Teams policy assignments per user
- Phone system enabled users
- Voice routing assignments
- Usage statistics (if available)

### 6. Teams & Channels Inventory
- All Teams with member counts
- Public vs Private Teams
- Channel lists per Team
- Team ownership
- External user participation

### 7. Compliance & Security (if `-IncludeComplianceAnalysis`)
- Data Loss Prevention (DLP) policies
- Retention policies for Teams
- Audit log configuration
- eDiscovery settings
- Sensitivity labels

### 8. Configuration Recommendations
- Identified misconfigurations
- Security best practices not implemented
- Voice routing improvements
- Policy optimization suggestions

## Output

### Text Report Format
```
================================================================================
ORGANIZATION NAME - MICROSOFT TEAMS INFRASTRUCTURE REPORT
Generated: 2026-01-05 14:30:15
================================================================================

EXECUTIVE SUMMARY
--------------------------------------------------------------------------------
Total Teams: 156
Total Channels: 842
Active Users: 1,247
Voice Enabled Users: 234

KEY FINDINGS:
✅ Federation is properly configured
⚠️  12 Teams without owners
❌ Guest access enabled without DLP policies

RECOMMENDATIONS:
1. Implement DLP policies for guest users
2. Assign owners to Teams without management
3. Review external access settings for security

[... detailed sections follow ...]
```

### CSV Export Files (if `-ExportToCSV`)
Generated in same directory as text report:
- `Teams_Inventory_[timestamp].csv` - All Teams with details
- `User_Policies_[timestamp].csv` - User policy assignments
- `Voice_Routes_[timestamp].csv` - Voice routing configuration
- `SBC_Status_[timestamp].csv` - Session Border Controller details
- `Phone_Numbers_[timestamp].csv` - Assigned phone numbers

### File Naming Convention
**Pattern**: `{Category}_{Type}_{YYYYMMDD_HHmmss}.{ext}`

**Examples**:
- `Teams_Infrastructure_Report_20260105_143015.txt`
- `Teams_Inventory_20260105_143015.csv`
- `Voice_Routes_20260105_143015.csv`

## Performance Considerations

### Small Environments (< 100 Teams)
- **Duration**: 2-5 minutes
- **Settings**: All features can be enabled
- **Memory**: < 500 MB

### Medium Environments (100-500 Teams)
- **Duration**: 5-15 minutes with full features
- **Settings**: Consider skipping `-IncludeUserDetails`
- **Memory**: 500 MB - 2 GB

### Large Environments (> 500 Teams or > 5,000 users)
- **Duration**: 15-60 minutes with all features
- **Settings**: Run during off-hours, skip `-IncludeUserDetails` initially
- **Memory**: 2-8 GB
- **Optimization**: Use `-ExportToCSV` and analyze data separately

### Throttling
- Script automatically handles Microsoft Graph and Teams PowerShell throttling
- Large tenant assessments may pause briefly during data collection
- Graph API calls use batching where possible

## Common Issues & Troubleshooting

### Issue: "Module MicrosoftTeams not found"
**Solution**:
```powershell
Install-Module MicrosoftTeams -Scope CurrentUser -Force
```

### Issue: "Access Denied" errors
**Cause**: Insufficient permissions

**Solution**: Verify you have one of:
- Global Administrator
- Teams Administrator
- Teams Communications Administrator (for voice features)

### Issue: "Unable to connect to Microsoft Teams"
**Cause**: Authentication failure or network issues

**Solution**:
```powershell
# Disconnect and reconnect
Disconnect-MicrosoftTeams
Connect-MicrosoftTeams

# For MFA accounts, ensure you can authenticate interactively
```

### Issue: Script hangs during user analysis
**Cause**: Large number of users with `-IncludeUserDetails`

**Solution**: Remove `-IncludeUserDetails` for initial assessment, or run during off-hours

### Issue: Voice analysis shows no data
**Cause**: No Direct Routing or Calling Plans configured, or insufficient permissions

**Solution**:
- Verify voice features are configured in tenant
- Ensure you have Teams Communications Administrator role
- Check that cmdlets like `Get-CsOnlineVoiceRoute` are available

### Issue: Compliance data not included
**Cause**: Missing compliance permissions or features not licensed

**Solution**:
- Verify compliance features are licensed (E5 or compliance add-ons)
- Ensure you have Compliance Administrator or Security Reader role
- Connect to Microsoft Graph with appropriate scopes

## Automation Examples

### Scheduled Monthly Assessment
```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Get-ComprehensiveTeamsReport.ps1 -OrganizationName 'Contoso' -ExportToCSV"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 2AM

Register-ScheduledTask -TaskName "Monthly Teams Assessment" -Action $action -Trigger $trigger -User "DOMAIN\ServiceAccount"
```

### Email Report After Generation
```powershell
.\Get-ComprehensiveTeamsReport.ps1 -OrganizationName "Contoso" -ReportPath "C:\Temp\Teams_Report.txt"

$reportContent = Get-Content "C:\Temp\Teams_Report.txt" -Raw
Send-MailMessage -To "teams-admins@contoso.com" -From "reports@contoso.com" `
    -Subject "Monthly Teams Infrastructure Report - $(Get-Date -Format 'yyyy-MM-dd')" `
    -Body $reportContent -SmtpServer "smtp.contoso.com"
```

### Compare Reports Over Time
```powershell
# Generate timestamped reports monthly
$month = Get-Date -Format "yyyyMM"
.\Get-ComprehensiveTeamsReport.ps1 -ReportPath "C:\Reports\$month\Teams_Report.txt" -ExportToCSV

# Compare Team counts month-over-month
$currentTeams = Import-Csv "C:\Reports\$month\Teams_Inventory_*.csv"
$previousMonth = (Get-Date).AddMonths(-1).ToString("yyyyMM")
$previousTeams = Import-Csv "C:\Reports\$previousMonth\Teams_Inventory_*.csv"

Compare-Object $previousTeams $currentTeams -Property DisplayName
```

## Related Scripts
- [Get-ComprehensiveLyncReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveLyncReport) - Lync/Skype assessment for Teams migration planning
- [Export-ADLyncTeamsMigrationData.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Export-ADLyncTeamsMigrationData) - AD export for Teams migration
- [TeamsInfrastructureAssessment.psm1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/TeamsInfrastructureAssessment) - Modular Teams assessment functions

## Version History
- **v1.0** (2025-12-15): Initial release
  - Basic tenant configuration assessment
  - Teams and channel inventory
  - Policy analysis
- **v1.1** (2026-01-05): Enhanced features
  - Voice infrastructure analysis
  - Compliance reporting
  - CSV export functionality
  - Performance optimizations for large tenants

## See Also
- [Microsoft Teams Admin Center](https://admin.teams.microsoft.com)
- [Teams PowerShell Module Documentation](https://docs.microsoft.com/en-us/microsoftteams/teams-powershell-overview)
- [Plan for Microsoft Teams](https://docs.microsoft.com/en-us/microsoftteams/upgrade-prepare-environment)
- [Teams Voice Architecture](https://docs.microsoft.com/en-us/microsoftteams/cloud-voice-landing-page)
