# Get-PKIHealthReport.ps1

Operational health monitoring script that validates CA infrastructure, distribution points, and service status with automated scoring.

## Overview

This script provides comprehensive health monitoring of Certificate Authority infrastructure by validating operational status, testing distribution points, analyzing event logs, and generating an overall health score (0-100) with actionable recommendations.

## Features

- **Service Monitoring** - CA service status and responsiveness validation
- **Certificate Expiration** - CA certificate expiration tracking and alerting
- **Database Health** - Size metrics, record counts, and statistics
- **CRL Validation** - Publication status and distribution point accessibility
- **AIA Validation** - Authority Information Access distribution point testing
- **Template Health** - Certificate template availability in Active Directory
- **Event Log Analysis** - Recent Certificate Services errors and warnings
- **Health Scoring** - Automated 0-100 health rating with issue weighting
- **Recommendations** - Actionable items based on detected issues

## Prerequisites

### Required
- PowerShell 5.1 or later
- Administrator privileges
- Must be run **ON the Certificate Authority server** (local execution only)
- Certificate Services running
- Network access to test distribution points (HTTP/HTTPS)

### Optional
- Firewall exceptions for distribution point URLs
- Event log read permissions

## Parameters

### Optional Parameters

#### `-OutputDirectory`
Directory path where reports and CSV exports will be saved.
- **Type**: String
- **Default**: `C:\Reports\PKI_Health`
- **Example**: `-OutputDirectory "D:\PKI_Health"`

#### `-CheckCRLDistribution`
Verify CRL distribution points are accessible and current.
- **Type**: Boolean
- **Default**: `$true`
- **Example**: `-CheckCRLDistribution $false`

#### `-CheckAIADistribution`
Verify AIA (Authority Information Access) distribution points are accessible.
- **Type**: Boolean
- **Default**: `$true`
- **Example**: `-CheckAIADistribution $false`

#### `-DaysToExpiration`
Flag certificates and CRLs expiring within this number of days.
- **Type**: Integer
- **Range**: 1-365
- **Default**: 30 days
- **Example**: `-DaysToExpiration 15`

#### `-EventLogHours`
Number of hours to review in Application event logs.
- **Type**: Integer
- **Range**: 1-168 (1 week)
- **Default**: 24 hours
- **Example**: `-EventLogHours 48`

#### `-OrganizationName`
Organization name for report headers.
- **Type**: String
- **Default**: "Organization"
- **Example**: `-OrganizationName "Contoso"`

## Usage Examples

### Example 1: Full Health Assessment
```powershell
.\Get-PKIHealthReport.ps1
```
Runs complete health check with default settings - 24 hours of event logs, 30-day expiration threshold.

### Example 2: Extended Monitoring Period
```powershell
.\Get-PKIHealthReport.ps1 -DaysToExpiration 15 -EventLogHours 48
```
Flags items expiring within 15 days and reviews 48 hours of event logs.

### Example 3: Selective Distribution Point Checks
```powershell
.\Get-PKIHealthReport.ps1 -OutputDirectory "D:\PKI_Health" -CheckCRLDistribution:$false
```
Runs assessment with custom output directory, skipping CRL distribution point checks.

### Example 4: Enterprise Monitoring
```powershell
.\Get-PKIHealthReport.ps1 `
    -OutputDirectory "\\FileServer\PKI\Health" `
    -EventLogHours 72 `
    -DaysToExpiration 7 `
    -OrganizationName "Dendreon"
```
Complete health assessment with UNC output, 72-hour event review, 7-day expiration alerting, and organization branding.

## Output

### Folder Structure
```
C:\Reports\PKI_Health\
└── HOSTNAME_PKI_Health_YYYYMMDD_HHMMSS\
    ├── HOSTNAME_PKI_CRLHealth_YYYYMMDD_HHMMSS.csv
    ├── HOSTNAME_PKI_AIAHealth_YYYYMMDD_HHMMSS.csv
    ├── HOSTNAME_PKI_TemplateHealth_YYYYMMDD_HHMMSS.csv
    ├── HOSTNAME_PKI_EventLogIssues_YYYYMMDD_HHMMSS.csv
    └── HOSTNAME_PKI_Health_Report_YYYYMMDD_HHMMSS.txt
```

### Output Files

#### 1. CRL Health CSV
Distribution point accessibility status.

**Columns:**
- `URL` - CRL distribution point URL
- `Accessible` - True/False accessibility status
- `StatusCode` - HTTP status code (200 = success)
- `Message` - Error message if failed
- `TestedAt` - Timestamp of test

#### 2. AIA Health CSV
Authority Information Access point validation.

**Columns:**
- `URL` - AIA distribution point URL  
- `Accessible` - True/False accessibility status
- `StatusCode` - HTTP status code
- `Message` - Error message if failed
- `TestedAt` - Timestamp of test

#### 3. Template Health CSV
Certificate template availability in AD.

**Columns:**
- `TemplateName` - Template name
- `Status` - Available | Not Found | Error
- `Published` - True if published to CA
- `Issue` - Description of any problems

#### 4. Event Log Issues CSV
Recent Certificate Services errors/warnings.

**Columns:**
- `TimeCreated` - Event timestamp
- `Level` - Error | Warning
- `EventID` - Windows event ID
- `Message` - Event description (truncated to 200 chars)
- `Source` - CertificationAuthority

#### 5. Health Report (Text)
Comprehensive health assessment with recommendations.

**Sections:**
1. Overall Health Status (score, status, error/warning counts)
2. Certificate Authority Information
3. CA Certificate Status (expiration tracking)
4. Database Health (size, records, statistics)
5. CRL Health (publication status, distribution points)
6. AIA Health (distribution point accessibility)
7. Certificate Templates (availability status)
8. Event Log Analysis (recent errors/warnings)
9. Recommendations (actionable items based on findings)
10. Exported Files List

## Health Scoring System

### Score Ranges
- **90-100**: EXCELLENT - No significant issues detected
- **70-89**: GOOD - Minor warnings present, no critical issues
- **50-69**: FAIR - Multiple issues requiring attention
- **0-49**: POOR - Critical issues requiring immediate action

### Score Deductions
- **-50**: Certificate Services not running (CRITICAL)
- **-10**: CA certificate expired (CRITICAL)
- **-10**: CRL overdue for publishing (CRITICAL)
- **-5**: Error event detected
- **-5**: Failed CRL distribution point
- **-5**: Failed AIA distribution point
- **-2**: Warning event detected
- **-2**: CA certificate expiring soon
- **-2**: High pending request count (>100)
- **-2**: Template availability issue
- **-2**: Large database size (>10 GB)

## How It Works

### 1. Initialization
- Validates PowerShell version and admin rights
- Checks for Certificate Services (CertSvc)
- Creates output directory with timestamp
- Initializes health score at 100

### 2. CA Configuration Check
- Queries local CA configuration
- Retrieves CA certificate expiration
- Tests CA responsiveness with ping
- Calculates days until CA cert expires

### 3. Database Health Check
- Locates CA database directory
- Calculates database size in MB
- Queries certificate statistics (issued, revoked, pending, failed)
- Warns if database exceeds 10 GB

### 4. CRL Health Validation
- Retrieves last CRL publication date
- Calculates time until next CRL publication
- Alerts if CRL is overdue
- Tests HTTP accessibility of CRL URLs (if enabled)
- Times out after 10 seconds per URL

### 5. AIA Health Validation
- Extracts AIA URLs from CA certificate
- Tests HTTP accessibility of .crt/.cer URLs (if enabled)
- Records status codes and error messages

### 6. Template Health Check
- Queries published templates from CA
- Verifies each template exists in Active Directory
- Reports templates published but missing in AD

### 7. Event Log Analysis
- Queries Application log for Certificate Services events
- Filters by time range (default 24 hours)
- Captures Error (Level 2) and Warning (Level 3) events
- Truncates messages to 200 characters

### 8. Health Score Calculation
- Applies weighted deductions for each issue
- Ensures score doesn't go below 0
- Determines status: EXCELLENT | GOOD | FAIR | POOR

### 9. Report Generation
- Generates actionable recommendations
- Creates CSV exports for each health area
- Produces comprehensive text report
- Displays color-coded console summary

## Common Issues & Troubleshooting

### Issue: "Certificate Services is not running"
**Impact**: -50 health score (CRITICAL)  
**Solution**:
```powershell
Start-Service CertSvc
```

### Issue: "CA certificate has EXPIRED"
**Impact**: -10 health score (CRITICAL)  
**Solution**: Renew CA certificate immediately - this is a critical outage

### Issue: "CRL is OVERDUE for publishing"
**Impact**: -10 health score (CRITICAL)  
**Solution**: 
```powershell
# Force CRL publication
certutil -CRL
```

### Issue: "CRL not accessible at http://..."
**Impact**: -5 health score per failed URL  
**Solution**: 
- Verify web server hosting CRL is running
- Check firewall rules allow HTTP/HTTPS access
- Confirm IIS/Apache configuration
- Test URL from client machine

### Issue: "Template not found in AD"
**Impact**: -2 health score per template  
**Solution**: 
- Verify template exists in AD: `CN=Certificate Templates,CN=Public Key Services...`
- Unpublish missing templates from CA
- Or restore template to Active Directory

### Issue: "Database size exceeds 10 GB"
**Impact**: -2 health score  
**Solution**:
```powershell
# Archive old certificate records
certutil -databaseclean +3months
```

## Data Analysis Examples

### Review Failed Distribution Points
```powershell
# Import CRL health data
$crlHealth = Import-Csv "C:\Reports\PKI_Health\*\*_CRLHealth_*.csv"

# Show inaccessible CRLs
$crlHealth | Where-Object { $_.Accessible -eq 'False' } |
    Format-Table URL, Message
```

### Trend Analysis Across Assessments
```powershell
# Get last 5 health reports
$reports = Get-ChildItem "C:\Reports\PKI_Health" -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 5

foreach ($report in $reports) {
    $file = Get-ChildItem $report.FullName -Filter "*_Health_Report_*.txt"
    $content = Get-Content $file.FullName -Raw
    
    if ($content -match 'Health Score:\s*(\d+)') {
        Write-Host "$($report.Name): Score $($Matches[1])"
    }
}
```

### Event Log Issue Correlation
```powershell
# Load event log issues
$events = Import-Csv "C:\Reports\PKI_Health\*\*_EventLogIssues_*.csv"

# Group by Event ID
$events | Group-Object EventID |
    Sort-Object Count -Descending |
    Format-Table Count, Name
```

## Integration with Other Scripts

### Assessment + Health Workflow
```powershell
# Step 1: Comprehensive assessment
.\Get-ComprehensivePKIReport.ps1 -OrganizationName "Contoso"

# Step 2: Health validation
.\Get-PKIHealthReport.ps1 -OrganizationName "Contoso"

# Step 3: Consolidate if multi-CA
.\Merge-PKIAssessmentReports.ps1
```

### Scheduled Health Monitoring
```powershell
# Create scheduled task for weekly health checks
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
    -Argument '-File "C:\Scripts\Get-PKIHealthReport.ps1"'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 6am

Register-ScheduledTask -TaskName "PKI Health Check" `
    -Action $action `
    -Trigger $trigger `
    -RunLevel Highest
```

## Best Practices

1. **Schedule Regular Checks** - Weekly health reports catch issues early
2. **Monitor Health Scores** - Investigate any drop below 90
3. **Test Distribution Points** - Ensure CRL/AIA URLs accessible from client networks
4. **Review Event Logs** - Certificate Services errors indicate underlying issues
5. **Track CA Cert Expiration** - Plan CA certificate renewals 90+ days in advance
6. **Validate Templates** - Remove published templates that don't exist in AD
7. **Archive Database** - Keep database size manageable (<10 GB)
8. **Alert on Critical Issues** - Automate notifications for health scores <70

## Security Considerations

- **Administrator Access**: Reads CA configuration and event logs
- **Network Testing**: Performs HTTP requests to distribution points
- **Output Protection**: Health reports contain infrastructure details
- **Event Log Data**: May contain sensitive error messages

## Related Scripts

- [Get-ComprehensivePKIReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensivePKIReport) - Deep PKI infrastructure assessment
- [Merge-PKIAssessmentReports.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Merge-PKIAssessmentReports) - Multi-CA consolidation

## Version History

- **v1.0** (2025-12-24): Initial release with health monitoring and scoring

## See Also

- [Microsoft PKI Documentation](https://docs.microsoft.com/en-us/windows-server/networking/core-network-guide/cng/server-certs/install-the-certification-authority)
- [CRL Publication](https://docs.microsoft.com/en-us/windows-server/identity/ad-cs/certificate-revocation)
- [Event Log Monitoring](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/wevtutil)
