# Microsoft Teams Assessment Scripts

Comprehensive assessment and reporting tools for Microsoft Teams environments. These scripts help IT professionals with infrastructure documentation, policy analysis, voice configuration review, and migration planning.

## Available Scripts

### [Get-ComprehensiveTeamsReport.ps1](Get-ComprehensiveTeamsReport.ps1)
**Purpose**: Complete Microsoft Teams infrastructure assessment

**Features**:
- Tenant configuration analysis
- Teams and channel inventory
- Policy assessment (calling, meeting, messaging, apps)
- Voice infrastructure analysis (Direct Routing, Calling Plans)
- User licensing and policy assignments
- Compliance and security analysis
- Executive summary with recommendations

**Quick Start**:
```powershell
.\Get-ComprehensiveTeamsReport.ps1 -OrganizationName "Contoso"
```

**Documentation**: [Full Documentation](../../docs/wiki/Assessments/Teams/Get-ComprehensiveTeamsReport.md)

**Typical Use Cases**:
- Pre-migration assessment (from Lync/Skype for Business)
- Security and compliance audits
- Voice infrastructure documentation
- Policy optimization reviews
- Quarterly health checks

---

### [TeamsInfrastructureAssessment.psm1](TeamsInfrastructureAssessment.psm1)
**Purpose**: Modular PowerShell module with reusable Teams assessment functions

**Features**:
- Reusable assessment functions
- Standardized logging and error handling
- Safe command execution wrappers
- Progress tracking helpers

**Usage**:
```powershell
Import-Module .\TeamsInfrastructureAssessment.psm1
$teams = Get-TeamsInventory -Verbose
$policies = Get-TeamsPolicyAssignments
```

**Typical Use Cases**:
- Building custom assessment scripts
- Automating Teams configuration reviews
- Integration with other management tools

---

## Prerequisites

### PowerShell Requirements
- **PowerShell 5.1 or later** (PowerShell 7+ recommended)
- **Microsoft Teams Administrator role** or higher

### Required Modules
- **MicrosoftTeams** - Auto-checked by scripts
- **Microsoft.Graph.Authentication** (optional) - For enhanced user data
- **Microsoft.Graph.Users** (optional) - For user details

**Module Installation**:
```powershell
Install-Module MicrosoftTeams -Scope CurrentUser -Force
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
```

### Required Permissions

**Teams Admin Roles** (one of):
- Global Administrator
- Teams Administrator
- Teams Communications Administrator (for voice features)

**Graph API Scopes** (if using user/compliance features):
- `User.Read.All`
- `Directory.Read.All`
- `Policy.Read.All`

## Common Parameters

### -OrganizationName
Organization name for report branding and identification.

**Default**: "Organization"  
**Example**: `"Contoso Corporation"`, `"Fabrikam Inc"`

### -ReportPath
Custom output location for text reports.

**Default**: `C:\Reports\Teams_Infrastructure_Report_[timestamp].txt`  
**Example**: `"D:\Assessments\Teams_Report.txt"`

### -IncludeUserDetails
Switch to include detailed user information (licensing, policy assignments, usage).

**Impact**: Significantly increases execution time for large tenants  
**Recommendation**: Skip for initial assessment, enable for detailed analysis

### -IncludeVoiceAnalysis
Switch to include voice infrastructure analysis (Direct Routing, Calling Plans, SBCs).

**Requirements**: Teams Communications Administrator role  
**Use Case**: Voice migration planning, SBC health monitoring

### -IncludeComplianceAnalysis
Switch to include compliance and security features (DLP, retention, audit).

**Requirements**: Compliance Administrator or Security Reader role  
**Use Case**: Security audits, compliance reviews

### -ExportToCSV
Switch to export detailed data to CSV files alongside text report.

**Output**: Multiple CSV files for Teams, users, policies, voice routes  
**Use Case**: Offline analysis, data manipulation, trending

## Quick Start Guide

### 1. Basic Infrastructure Assessment
```powershell
# Connect to Teams
Connect-MicrosoftTeams

# Run basic assessment
.\Get-ComprehensiveTeamsReport.ps1 -OrganizationName "Contoso"
```

### 2. Voice Infrastructure Review
```powershell
.\Get-ComprehensiveTeamsReport.ps1 `
    -OrganizationName "Contoso" `
    -IncludeVoiceAnalysis `
    -ExportToCSV
```

### 3. Complete Assessment
```powershell
.\Get-ComprehensiveTeamsReport.ps1 `
    -OrganizationName "Contoso Corporation" `
    -IncludeUserDetails `
    -IncludeVoiceAnalysis `
    -IncludeComplianceAnalysis `
    -ExportToCSV `
    -ReportPath "C:\Assessments\Contoso_Complete_Teams.txt"
```

## Output Structure

### Text Report Sections
```
================================================================================
ORGANIZATION - MICROSOFT TEAMS INFRASTRUCTURE REPORT
================================================================================

EXECUTIVE SUMMARY
- Total Teams, channels, users
- Voice enablement statistics
- Key findings and recommendations

TENANT CONFIGURATION
- Federation and external access
- Guest user settings
- Meeting and messaging settings

TEAMS POLICIES
- Calling policies
- Meeting policies
- Messaging policies
- App setup policies

VOICE INFRASTRUCTURE (optional)
- Direct Routing SBC status
- Calling Plans assignment
- Voice routes and dial plans

USER ANALYSIS (optional)
- Licensing breakdown
- Policy assignments per user

COMPLIANCE & SECURITY (optional)
- DLP policies
- Retention policies
- Audit configuration
```

### CSV Export Files (if `-ExportToCSV`)
```
OutputDirectory/
├── Teams_Infrastructure_Report_YYYYMMDD_HHmmss.txt
├── Teams_Inventory_YYYYMMDD_HHmmss.csv
├── User_Policies_YYYYMMDD_HHmmss.csv
├── Voice_Routes_YYYYMMDD_HHmmss.csv
├── SBC_Status_YYYYMMDD_HHmmss.csv
└── Phone_Numbers_YYYYMMDD_HHmmss.csv
```

## Common Troubleshooting

### "Module MicrosoftTeams not found"
**Solution**:
```powershell
Install-Module MicrosoftTeams -Scope CurrentUser -Force
```

### "Access Denied" Errors
**Cause**: Insufficient Teams admin permissions

**Solution**: Verify admin role in Microsoft 365 admin center. Requires one of:
- Global Administrator
- Teams Administrator
- Teams Communications Administrator (for voice features)

### "Unable to connect to Microsoft Teams"
**Solution**:
```powershell
# Disconnect and reconnect
Disconnect-MicrosoftTeams
Connect-MicrosoftTeams

# For MFA, ensure interactive authentication works
```

### Script Hangs During User Analysis
**Cause**: Large tenant with `-IncludeUserDetails`

**Solution**: 
- Remove `-IncludeUserDetails` for initial run
- Schedule during off-hours
- Use `-ExportToCSV` and analyze CSV separately

### Voice Analysis Shows No Data
**Cause**: Missing voice configuration or insufficient permissions

**Solution**:
- Verify Teams voice features are configured
- Ensure you have Teams Communications Administrator role
- Check cmdlet availability: `Get-Command *CsOnlineVoice*`

## Performance Guidelines

### Small Environments (< 100 Teams, < 1,000 users)
- **Duration**: 2-5 minutes
- **Settings**: All features can be enabled
- **Memory**: < 500 MB

### Medium Environments (100-500 Teams, 1,000-5,000 users)
- **Duration**: 5-15 minutes
- **Settings**: Consider skipping `-IncludeUserDetails`
- **Memory**: 500 MB - 2 GB

### Large Environments (> 500 Teams, > 5,000 users)
- **Duration**: 15-60 minutes with all features
- **Settings**: 
  - Skip `-IncludeUserDetails` initially
  - Run during off-hours
  - Use `-ExportToCSV` for offline analysis
- **Memory**: 2-8 GB

## Best Practices

### Before Running Assessments
1. ✅ Connect to Microsoft Teams PowerShell
2. ✅ Verify admin permissions
3. ✅ Check available disk space for reports
4. ✅ Close any open report files
5. ✅ Test with basic report first, then add features

### During Execution
1. ✅ Monitor console output for errors
2. ✅ Don't interrupt long-running assessments
3. ✅ Watch for throttling messages
4. ✅ Note any access denied warnings for follow-up

### After Completion
1. ✅ Review executive summary first
2. ✅ Check error and warning counts
3. ✅ Verify CSV exports if enabled
4. ✅ Secure reports (contain sensitive configuration data)
5. ✅ Follow up on recommendations

## Security Considerations

⚠️ **Assessment reports contain sensitive information**:
- Voice routing configurations
- Phone numbers and SBC details
- Policy assignments and user data
- Security and compliance settings

**Recommendations**:
- Store reports in secure locations
- Restrict access to assessment files
- Delete temporary files after analysis
- Encrypt reports if transmitting over email

## Related Scripts

- [Get-ComprehensiveLyncReport.ps1](../Lync/Get-ComprehensiveLyncReport.md) - Lync/Skype assessment for Teams migration planning
- [Export-ADLyncTeamsMigrationData.ps1](../Lync/Export-ADLyncTeamsMigrationData.md) - AD export for migration
- [Get-QuickO365Report.ps1](../Microsoft365/Get-QuickO365Report.md) - Quick Microsoft 365 tenant assessment

## Related Documentation

- [Get-ComprehensiveTeamsReport.ps1 Full Documentation](../../docs/wiki/Assessments/Teams/Get-ComprehensiveTeamsReport.md)
- [Microsoft Teams Admin Center](https://admin.teams.microsoft.com)
- [Teams PowerShell Documentation](https://docs.microsoft.com/en-us/microsoftteams/teams-powershell-overview)
- [Plan for Microsoft Teams](https://docs.microsoft.com/en-us/microsoftteams/upgrade-prepare-environment)

## Support

For issues, questions, or contributions:
- GitHub Issues: [PowerShellEveryting Issues](https://github.com/Managed-Solution-LLC/PowerShellEveryting/issues)
- Wiki: [Project Wiki](https://github.com/Managed-Solution-LLC/PowerShellEveryting/wiki)

## Version History

- **2026-01-05**: Enhanced Get-ComprehensiveTeamsReport.ps1 with voice and compliance features
- **2025-12-15**: Added Get-ComprehensiveTeamsReport.ps1 - Complete Teams infrastructure assessment
- **2025**: Initial Teams assessment scripts and module
