# On-Premise Assessment Scripts

This folder contains scripts for assessing on-premise Windows Server infrastructure, focusing on file share analysis, Active Directory, and server configurations.

## Available Scripts

### Active Directory Assessment

#### [Get-ComprehensiveADReport.ps1](Get-ComprehensiveADReport.ps1)
**Purpose**: Complete Active Directory assessment for AD to AD migration and user matching

**Features**:
- Comprehensive user export with all matching attributes (EmployeeID, email, UPN, samAccountName)
- Group analysis with membership mappings
- OU structure and distribution analysis
- Privileged account identification
- Computer inventory (optional)
- Cross-domain and cross-forest query support with -Domain and -Credential parameters
- RSAT auto-install capability
- Migration recommendations and data quality analysis
- Executive summary with statistics

**Quick Start**:
```powershell
# Basic assessment (enabled users only)
.\Get-ComprehensiveADReport.ps1

# Complete assessment for migration planning
.\Get-ComprehensiveADReport.ps1 -OutputDirectory "C:\Migration\SourceAD" -IncludeDisabledUsers -IncludeComputers

# Query specific domain
.\Get-ComprehensiveADReport.ps1 -Domain "contoso.com" -OrganizationName "Contoso"

# Cross-forest with credentials
.\Get-ComprehensiveADReport.ps1 -Domain "partner.com" -Credential (Get-Credential)
```

**Documentation**: [Full Documentation](../../../docs/wiki/Assessments/OnPremise/Get-ComprehensiveADReport.md)

**Typical Use Cases**:
- AD to AD migration planning
- Multi-domain and cross-forest assessments
- User matching across source and target environments
- Group membership documentation
- Privileged account inventory
- OU structure mapping

---

#### [Check-ADMTPrerequisites.ps1](Check-ADMTPrerequisites.ps1)
**Purpose**: Validate environment readiness for Active Directory Migration Tool (ADMT) migrations

**Features**:
- DNS resolution validation for source and target domains
- Domain functional level checks
- Trust relationship analysis (type, direction, configuration)
- Permission verification (Domain Admin, read access)
- Network connectivity testing (LDAP, Kerberos, SMB, RPC, etc.)
- Optional SID History prerequisite checks
- Optional Password Export Server (PES) validation
- SQL Server detection for ADMT database
- Color-coded console output with remediation guidance
- Automated CSV export with pass/fail/warning status

**Quick Start**:
```powershell
# Basic ADMT prerequisites check
.\Check-ADMTPrerequisites.ps1 -SourceDomain "old.contoso.com" -TargetDomain "new.contoso.com"

# Include SID History checks
.\Check-ADMTPrerequisites.ps1 -SourceDomain "old.contoso.com" -TargetDomain "new.contoso.com" -CheckSIDHistory -SourcePDC "dc01.old.contoso.com"

# Full check with password migration
.\Check-ADMTPrerequisites.ps1 -SourceDomain "legacy.fabrikam.com" -CheckPES -CheckSIDHistory -SourcePDC "pdc.legacy.fabrikam.com"
```

**Documentation**: [Full Documentation](../../../docs/wiki/Assessments/OnPremise/Check-ADMTPrerequisites.md)

**Typical Use Cases**:
- Pre-migration validation for ADMT projects
- Troubleshooting ADMT connectivity issues
- Documenting migration prerequisites for compliance
- Validating trust relationships and permissions
- Network connectivity verification between domains
- SID History migration preparation

### File Share Assessment

#### [Start-FileShareAssessment.ps1](Start-FileShareAssessment.ps1)
**Purpose**: Comprehensive file share assessment with Excel reporting

**Features**:
- Automatic SMB share discovery
- Storage analysis (sizes, file counts)
- NTFS permission mapping
- SharePoint/OneDrive compatibility checking
- Excel report generation

**Quick Start**:
```powershell
.\Start-FileShareAssessment.ps1 -Domain "YourDomain"
```

**Documentation**: [Full Documentation](../../../docs/wiki/Assessments/OnPremise/Start-FileShareAssessment.md)

**Typical Use Cases**:
- File server migration planning
- Storage capacity management
- Security audit of file permissions
- SharePoint migration preparation

---

## Prerequisites

### All Scripts
- **PowerShell 5.1 or later**
- **Execution Policy**: RemoteSigned or Unrestricted

### Active Directory Scripts
- **ActiveDirectory PowerShell module** (RSAT Tools or Domain Controller)
- **Domain user permissions** (read access minimum)
- **For comprehensive assessments**: Domain Admin or equivalent recommended

### File Share Scripts
- **Administrator privileges**
- **ImportExcel module** (auto-installed)
- **Local access** to file server
- **Long paths enabled** (auto-configured by script)

## Common Parameters

### -Domain / -OrganizationName
The domain or organization name for the assessment. Used in report naming.

**Example**: `"Contoso"`, `"Organization"`, `"Lawson"`

### -OutputDirectory
Directory where reports are saved.

**Active Directory Scripts Default**: `C:\Reports\AD_Assessment`  
**File Share Scripts Default**: Current directory  
**Example**: `"C:\Reports"`, `"C:\Migration\SourceAD"`

## Quick Start Guide

### 1. Active Directory Assessment
```powershell
# Basic assessment (enabled users only)
.\Get-ComprehensiveADReport.ps1

# Complete assessment for AD migration planning
.\Get-ComprehensiveADReport.ps1 -OutputDirectory "C:\Migration\SourceAD" -IncludeDisabledUsers -IncludeComputers

# Specific OU assessment

# Query different domain
.\Get-ComprehensiveADReport.ps1 -Domain "contoso.com" -OrganizationName "Contoso"

# Cross-forest assessment
$Cred = Get-Credential
.\Get-ComprehensiveADReport.ps1 -Domain "partner.com" -Credential $Cred -OutputDirectory "C:\Migration\PartnerAD"
.\Get-ComprehensiveADReport.ps1 -SearchBase "OU=Corporate,DC=contoso,DC=com" -OrganizationName "Contoso"
```

### 2. File Share Assessment
```powershell
# Basic assessment
.\Start-FileShareAssessment.ps1 -Domain "Contoso"

# Fast assessment (skip permissions)
.\Start-FileShareAssessment.ps1 -Domain "Contoso" -SkipPermissions

# High-performance assessment
.\Start-FileShareAssessment.ps1 -Domain "Contoso" -Workers 200 -OutputDirectory "D:\Reports"
```

## Output Structure

All scripts generate structured output for easy analysis:

### Active Directory Assessment Output
```
C:\Reports\AD_Assessment\
├── AD_Users_Full_20260107_143052.csv          # Complete user export
├── AD_Groups_Summary_20260107_143052.csv      # All groups
├── AD_GroupMemberships_20260107_143052.csv    # User-to-group mappings
├── AD_OUs_Structure_20260107_143052.csv       # OU hierarchy
├── AD_Computers_20260107_143052.csv           # Computer inventory (optional)
├── AD_PrivilegedAccounts_20260107_143052.csv  # Admin accounts
└── AD_Assessment_Report_20260107_143052.txt   # Executive summary
```

### File Share Assessment Output
```
OutputDirectory/
├── {Domain}_File_Share_Assessment.xlsx  # Main Excel report
├── fileaudit_*.csv                      # Size analysis files
├── unsupported_filenames_*.csv          # Compatibility reports
└── RawData/                             # Detailed permission data
    └── permissions_*.csv
```

## Common Troubleshooting

### Active Directory Issues

#### "ActiveDirectory module not found"
**Solution**: Install RSAT tools
```powershell
# Windows 10/11
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Windows Server
Install-WindowsFeature RSAT-AD-PowerShell

#### Querying wrong domain
**Solution**: Use `-Domain` parameter with full FQDN. For cross-forest: `-Domain "targetdomain.com" -Credential (Get-Credential)`

#### RSAT module auto-install fails
**Solution**: Script will detect and offer to install. If it fails, install manually:
```powershell
# Windows 10/11
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Windows Server
Install-WindowsFeature RSAT-AD-PowerShell
```
```

#### "Access Denied" when querying AD
**Solution**: Ensure you're logged in with domain credentials. For full assessment, use Domain Admin or equivalent.

#### Slow performance with large AD
**Solution**: Use `-SearchBase` to limit scope to specific OUs, or target specific DC with `-DomainController`

### File Share Issues

### "Access to path is denied"
**Solution**: Run as Domain Admin or with appropriate delegated permissions

### "Long paths are not enabled"
**Solution**: Script will prompt to enable. Alternatively:
```powershell
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1
```

### "Failed to install ImportExcel module"
**Solution**: Manual installation:
```powershell
Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber
```

### Slow Performance
**Solution**: 
- Increase workers: `-Workers 200`
- Skip permissions: `-SkipPermissions`
- Run during off-hours

## Best Practices

### Before Running Assessments

#### Active Directory Assessments
1. ✅ Verify domain connectivity and credentials
2. ✅ Check available disk space for CSV exports
3. ✅ For large environments (10,000+ users), consider using `-SearchBase` to limit scope
4. ✅ Test on single OU first before full domain assessment
5. ✅ Schedule during off-hours if querying production DCs

#### File Share Assessments
1. ✅ Verify administrator privileges
2. ✅ Check available disk space for reports
3. ✅ Close Excel files in output directory
4. ✅ Test on single share first (use `-ExcludeShares`)
5. ✅ Schedule during off-hours for production servers

### During Execution
1. ✅ Monitor console output for errors
2. ✅ Check progress indicators
3. ✅ Note any access denied warnings
4. ✅ For AD: Watch for null result warnings on cmdlets

### After Completion

#### Active Directory Assessments
1. ✅ Review text report for statistics and recommendations
2. ✅ Verify CSV file completeness (check row counts)
3. ✅ Analyze "Matching Attribute Coverage" percentages
4. ✅ Review privileged accounts CSV for migration planning
5. ✅ Compare source and target AD exports for user matching

#### File Share Assessments
1. ✅ Review Excel report for completeness
2. ✅ Check error and warning counts
3. ✅ Secure reports (contain sensitive data)
4. ✅ Delete temporary CSV files if needed

## Security Considerations

⚠️ **Assessment reports contain sensitive information**:
- User and group permissions
- Folder structures and file names
- Security group memberships

**Recommendations**:
- Store reports in secure locations
- Restrict access to assessment files
- Delete temporary files after review
- Encrypt reports if transmitting

## Performance Guidelines

### Small Environments (< 100 GB)
- **Duration**: 5-15 minutes
- **Settings**: Default parameters

### Medium Environments (100 GB - 1 TB)
- **Duration**: 15-60 minutes
- **Settings**: `-Workers 100`

### Large Environments (> 1 TB)
- **Duration**: 1-4 hours
- **Settings**: `-Workers 200 -SkipPermissions` (initially)

## Related Documentation
7**: Updated Get-ComprehensiveADReport.ps1
  - Added -Domain parameter for explicit domain targeting
  - Added -Credential parameter for cross-forest authentication
  - Fixed domain targeting for all sub-queries
  - Added RSAT auto-install capability
- **2026-01-0
- [Start-FileShareAssessment.ps1 Full Documentation](../../../docs/wiki/Assessments/OnPremise/Start-FileShareAssessment.md)
- [File Share Migration Planning Guide](../../../docs/guides/FileShareMigration.md)
- [Assessment Best Practices](../../../docs/guides/AssessmentBestPractices.md)

## Support

For issues, questions, or contributions:
- GitHub Issues: [PowerShellEveryting Issues](https://github.com/Managed-Solution-LLC/PowerShellEveryting/issues)
- Wiki: [Project Wiki](https://github.com/Managed-Solution-LLC/PowerShellEveryting/wiki)

## Version History

- **2026-01-05**: Added Start-FileShareAssessment.ps1 - All-in-one file share assessment with Excel reporting
