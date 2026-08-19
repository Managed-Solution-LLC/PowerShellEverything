# PKI Assessment Scripts

Quick start guide for PowerShell scripts that assess, monitor, and consolidate Public Key Infrastructure (PKI) data across enterprise Certificate Authority environments.

## Script Suite Overview

| Script | Purpose | Best For |
|--------|---------|----------|
| [Get-ComprehensivePKIReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensivePKIReport) | Deep infrastructure assessment | Quarterly audits, migration planning, compliance |
| [Get-PKIHealthReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-PKIHealthReport) | Operational health monitoring | Weekly checks, troubleshooting, SLA monitoring |
| [Merge-PKIAssessmentReports.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Merge-PKIAssessmentReports) | Multi-CA consolidation | Executive reporting, cross-CA analysis |

## Quick Start

### Single CA Assessment
```powershell
# Step 1: Deep assessment (run ON CA server)
.\Get-ComprehensivePKIReport.ps1 -OrganizationName "Contoso"

# Step 2: Health check (run ON CA server)
.\Get-PKIHealthReport.ps1 -OrganizationName "Contoso"

# Review outputs in C:\Reports\PKI_Assessment and C:\Reports\PKI_Health
```

### Multi-CA Enterprise Assessment
```powershell
# Step 1: Run on each CA (save to network share)
.\Get-ComprehensivePKIReport.ps1 -OutputDirectory "\\FileServer\PKI\Assessment"
.\Get-PKIHealthReport.ps1 -OutputDirectory "\\FileServer\PKI\Health"

# Step 2: Consolidate from management workstation
.\Merge-PKIAssessmentReports.ps1 `
    -AssessmentPath "\\FileServer\PKI\Assessment" `
    -HealthPath "\\FileServer\PKI\Health" `
    -OutputDirectory "\\FileServer\PKI\Reports" `
    -OrganizationName "Contoso"

# Open Excel: \\FileServer\PKI\Reports\PKI_Consolidated_*.xlsx
```

## Available Scripts

### [Get-ComprehensivePKIReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensivePKIReport)
Deep PKI infrastructure assessment with certificate inventory, template analysis, and permissions export.

**Key Features**:
- Export all issued certificates with expiration analysis
- Retrieve certificate templates from AD configuration
- Analyze template permissions and enrollment rights
- Flag certificates expiring within threshold
- Generate CSV exports and comprehensive text reports
- Supports inclusion of revoked certificates

**Quick Example**:
```powershell
.\Get-ComprehensivePKIReport.ps1 -DaysToExpiration 30
```

### [Get-PKIHealthReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-PKIHealthReport)
Operational health monitoring with automated scoring (0-100) and actionable recommendations.

**Key Features**:
- Certificate Services status validation
- CA certificate expiration tracking
- Database health metrics and statistics
- CRL/AIA distribution point testing
- Template availability verification
- Event log analysis (errors and warnings)
- Automated health scoring with issue weighting

**Quick Example**:
```powershell
.\Get-PKIHealthReport.ps1 -DaysToExpiration 15 -EventLogHours 48
```

### [Merge-PKIAssessmentReports.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Merge-PKIAssessmentReports)
Consolidates PKI data from multiple CAs into single Excel workbook with 10 worksheets.

**Key Features**:
- Auto-discovers latest assessments from each CA
- Combines certificates, templates, permissions, health data
- Adds CAServer column for filtering/pivoting
- Generates professional Excel workbook
- Supports UNC paths for centralized reporting
- Includes overview and summary worksheets

**Quick Example**:
```powershell
.\Merge-PKIAssessmentReports.ps1 -OrganizationName "Contoso"
```

## Common Prerequisites

### Assessment & Health Scripts (Run ON CA Servers)
- Windows Server with Certificate Authority role
- RSAT-ADCS PowerShell module
- Administrator privileges on CA server
- PowerShell 5.1 or later
- Certificate Services running

### Merge Script (Run From Anywhere)
- PowerShell 5.1 or later
- ImportExcel module (auto-installs if missing)
- Read access to assessment/health folders

### Installation
```powershell
# On CA servers - Install RSAT-ADCS
Install-WindowsFeature RSAT-ADCS
Import-Module ADCS-Administration

# For merge script - Install ImportExcel (optional, auto-installs)
Install-Module ImportExcel -Scope CurrentUser -Force

# Verify CA connectivity
certutil -ping
```

## Common Use Cases

### Use Case 1: Certificate Lifecycle Management
**Goal**: Identify certificates expiring soon, track renewals

```powershell
# Run assessment with 30-day threshold
.\Get-ComprehensivePKIReport.ps1 -DaysToExpiration 30

# Review: HOSTNAME_PKI_IssuedCertificates_*.csv
# Filter: ExpirationStatus = "Expiring Soon"
```

### Use Case 2: Security Audit
**Goal**: Audit template permissions, identify over-privileged enrollment

```powershell
# Export templates with permissions
.\Get-ComprehensivePKIReport.ps1

# Review: HOSTNAME_PKI_TemplatePermissions_*.csv
# Look for: Unexpected Enroll/AutoEnroll rights
```

### Use Case 3: Weekly Health Monitoring
**Goal**: Catch operational issues early, track health scores

```powershell
# Schedule weekly health checks
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
    -Argument '-File "C:\Scripts\Get-PKIHealthReport.ps1"'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 6am
Register-ScheduledTask -TaskName "PKI Health Check" -Action $action -Trigger $trigger -RunLevel Highest

# Review health scores - investigate any drop below 90
```

### Use Case 4: Executive PKI Report
**Goal**: Consolidated view across all CAs for stakeholders

```powershell
# Consolidate multi-CA data
.\Merge-PKIAssessmentReports.ps1 `
    -AssessmentPath "\\FileServer\PKI\Assessment" `
    -HealthPath "\\FileServer\PKI\Health" `
    -OutputDirectory "\\FileServer\PKI\Reports" `
    -OrganizationName "Contoso"

# Delivers: Single Excel with 193K certs, 192 templates, 4 CA health scores
```

### Use Case 5: Migration Planning
**Goal**: Baseline current state before CA migration

```powershell
# Before migration: Full assessment
.\Get-ComprehensivePKIReport.ps1 -IncludeRevokedCertificates -OutputDirectory "C:\Migration\Baseline"

# After migration: Validation
.\Get-ComprehensivePKIReport.ps1 -OutputDirectory "C:\Migration\Validation"

# Compare certificate counts, templates, permissions
```

### Use Case 6: Troubleshooting Certificate Issuance
**Goal**: Diagnose why certificates aren't being issued

```powershell
# Extended event log review
.\Get-PKIHealthReport.ps1 -EventLogHours 48

# Check: Event Log Issues CSV for errors
# Verify: CRL/AIA distribution point accessibility
# Confirm: Template availability in AD
```

## Output Structure

### Assessment Script Outputs
**Folder Pattern**: `HOSTNAME_PKI_Assessment_YYYYMMDD_HHMMSS\`
- `HOSTNAME_PKI_IssuedCertificates_YYYYMMDD_HHMMSS.csv` - All certificates
- `HOSTNAME_PKI_CertificateTemplates_YYYYMMDD_HHMMSS.csv` - Template properties
- `HOSTNAME_PKI_TemplatePermissions_YYYYMMDD_HHMMSS.csv` - ACLs
- `HOSTNAME_PKI_Assessment_Report_YYYYMMDD_HHMMSS.txt` - Summary report

### Health Script Outputs
**Folder Pattern**: `HOSTNAME_PKI_Health_YYYYMMDD_HHMMSS\`
- `HOSTNAME_PKI_CRLHealth_YYYYMMDD_HHMMSS.csv` - CRL distribution status
- `HOSTNAME_PKI_AIAHealth_YYYYMMDD_HHMMSS.csv` - AIA distribution status
- `HOSTNAME_PKI_TemplateHealth_YYYYMMDD_HHMMSS.csv` - Template availability
- `HOSTNAME_PKI_EventLogIssues_YYYYMMDD_HHMMSS.csv` - Errors/warnings
- `HOSTNAME_PKI_Health_Report_YYYYMMDD_HHMMSS.txt` - Health report (score 0-100)

### Merge Script Output
**File Pattern**: `PKI_Consolidated_Assessment_YYYYMMDD_HHMMSS.xlsx`
- 10 Excel worksheets: Overview, CA Summary, Certificates, Templates, Permissions, Health Summary, CRL Health, AIA Health, Template Health, Event Log Issues

### Default Locations
- Assessment: `C:\Reports\PKI_Assessment\`
- Health: `C:\Reports\PKI_Health\`
- Consolidated: `C:\Reports\PKI_Consolidated\`

## Health Scoring Guide

### Score Ranges
- **90-100**: EXCELLENT - No significant issues
- **70-89**: GOOD - Minor warnings, no critical issues
- **50-69**: FAIR - Multiple issues requiring attention
- **0-49**: POOR - Critical issues requiring immediate action

### Major Score Deductions
- **-50**: Certificate Services not running (CRITICAL)
- **-10**: CA certificate expired or CRL overdue (CRITICAL)
- **-5**: Error event, failed CRL/AIA distribution point
- **-2**: Warning event, CA cert expiring soon, high pending requests

## Troubleshooting

### Module Not Found
```powershell
# ADCS-Administration (CA servers)
Install-WindowsFeature RSAT-ADCS
Import-Module ADCS-Administration

# ImportExcel (merge script)
Install-Module ImportExcel -Scope CurrentUser -Force
```

### Cannot Connect to CA
1. Verify CA server online: `Test-Connection CAServerName`
2. Check CA service running: `Get-Service CertSvc`
3. Test CA responsiveness: `certutil -ping`
4. Verify firewall allows RPC traffic
5. Ensure admin rights on CA server

### Access Denied on Templates
1. Run PowerShell as Administrator
2. Verify domain connectivity: `nltest /dclist:domain.com`
3. Check AD Configuration partition permissions
4. Ensure Read access to Certificate Templates container

### CRL Distribution Points Not Accessible
**Health Impact**: -5 per failed URL  
**Solution**:
- Verify web server hosting CRL is running
- Check firewall allows HTTP/HTTPS
- Test URL from client network: `Invoke-WebRequest http://...`
- Confirm IIS/Apache virtual directory configuration

### Health Score Dropped Below 70
**Solution**:
1. Review health report "Recommendations" section
2. Check Event Log Issues CSV - address errors first
3. Verify Certificate Services running
4. Test CRL/AIA distribution points
5. Confirm CA certificate not expiring soon
6. Check database size (<10 GB recommended)

## Related Documentation

- [Microsoft PKI Documentation](https://docs.microsoft.com/en-us/windows-server/networking/core-network-guide/cng/server-certs/install-the-certification-authority)
- [Certificate Templates Guide](https://docs.microsoft.com/en-us/windows-server/networking/core-network-guide/cng/server-certs/configure-server-certificate-autoenrollment)
- [ADCS PowerShell Cmdlets](https://docs.microsoft.com/en-us/powershell/module/adcsadministration/)
- [Certificate Revocation](https://docs.microsoft.com/en-us/windows-server/identity/ad-cs/certificate-revocation)
