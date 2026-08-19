# Merge-PKIAssessmentReports.ps1

Consolidates PKI assessment and health data from multiple CA servers into a single comprehensive Excel workbook for enterprise-wide analysis and reporting.

## Overview

This script automatically discovers and processes PKI assessment data from multiple Certificate Authority servers, combining certificates, templates, permissions, and health metrics into a single Excel file with multiple worksheets. Perfect for enterprise PKI environments with multiple CAs.

## Features

- **Auto-Discovery** - Automatically finds latest assessment from each CA server
- **Multi-CA Consolidation** - Combines data from unlimited CA servers
- **Excel Workbook Generation** - Professional multi-worksheet Excel output
- **CA Server Tagging** - Adds CAServer column for filtering and analysis
- **Health Metrics Parsing** - Extracts health scores from text reports
- **Flexible Input** - Processes data from any folder structure
- **Module Auto-Install** - Installs ImportExcel module if missing
- **Progress Tracking** - Shows processing status for each CA

## Prerequisites

### Required
- PowerShell 5.1 or later
- Read access to PKI assessment and health folders
- ImportExcel module (auto-installs if missing)

### Optional
- Network access to UNC paths (for centralized storage)

## Parameters

### Optional Parameters

#### `-AssessmentPath`
Path to directory containing PKI_Assessment folders from multiple CAs.
- **Type**: String
- **Default**: `C:\Reports\PKI_Assessment`
- **Example**: `-AssessmentPath "\\FileServer\PKI\Assessment"`

#### `-HealthPath`
Path to directory containing PKI_Health folders from multiple CAs.
- **Type**: String
- **Default**: `C:\Reports\PKI_Health`
- **Example**: `-HealthPath "\\FileServer\PKI\Health"`

#### `-OutputDirectory`
Directory where consolidated Excel file will be saved.
- **Type**: String
- **Default**: `C:\Reports\PKI_Consolidated`
- **Example**: `-OutputDirectory "D:\Reports"`

#### `-OutputFileName`
Name for output Excel file (without .xlsx extension).
- **Type**: String
- **Default**: `PKI_Consolidated_Assessment_{timestamp}`
- **Example**: `-OutputFileName "Contoso_PKI_Report"`

#### `-OrganizationName`
Organization name for the report.
- **Type**: String
- **Default**: "Organization"
- **Example**: `-OrganizationName "Contoso"`

## Usage Examples

### Example 1: Default Paths
```powershell
.\Merge-PKIAssessmentReports.ps1
```
Processes assessment and health data from default locations, outputs to `C:\Reports\PKI_Consolidated\`.

### Example 2: Custom Paths
```powershell
.\Merge-PKIAssessmentReports.ps1 `
    -AssessmentPath "D:\PKI\Assessment" `
    -HealthPath "D:\PKI\Health"
```
Processes data from custom local directories.

### Example 3: UNC Network Paths
```powershell
.\Merge-PKIAssessmentReports.ps1 `
    -AssessmentPath "\\FileServer\PKI\Assessment" `
    -HealthPath "\\FileServer\PKI\Health" `
    -OutputDirectory "\\FileServer\PKI\Reports" `
    -OrganizationName "Dendreon"
```
Consolidates data from network share, outputs to network location with organization branding.

### Example 4: Custom Output Filename
```powershell
.\Merge-PKIAssessmentReports.ps1 `
    -OutputDirectory "C:\Reports" `
    -OutputFileName "Contoso_PKI_$(Get-Date -Format 'yyyy-MM')" `
    -OrganizationName "Contoso"
```
Creates monthly PKI report with custom naming: `Contoso_PKI_2025-12.xlsx`.

## Output

### Excel Workbook Structure
```
PKI_Consolidated_Assessment_20251224_170613.xlsx
├── Overview (metadata and summary)
├── CA Summary (certificate counts per CA)
├── Issued Certificates (all certificates from all CAs)
├── Certificate Templates (all templates from all CAs)
├── Template Permissions (all permission entries)
├── Health Summary (health scores per CA)
├── CRL Health (CRL distribution point status)
├── AIA Health (AIA distribution point status)
├── Template Health (template availability)
└── Event Log Issues (Certificate Services errors/warnings)
```

### Worksheet Details

#### 1. Overview
Report metadata and summary statistics.

**Fields:**
- `OrganizationName` - Organization name from parameter
- `ReportGeneratedDate` - Timestamp of consolidation
- `TotalCAServers` - Number of CAs processed
- `TotalCertificates` - Total certificates across all CAs
- `TotalTemplates` - Total template entries
- `AssessmentDataSource` - Path to assessment data
- `HealthDataSource` - Path to health data

#### 2. CA Summary
High-level statistics for each CA server.

**Columns:**
- `CAServer` - CA server hostname
- `TotalCertificates` - Total certificates from this CA
- `ValidCertificates` - Certificates with Valid status
- `ExpiringSoon` - Certificates expiring within threshold
- `Expired` - Expired certificates
- `AssessmentDate` - Timestamp of assessment

#### 3. Issued Certificates
All certificates from all CAs combined.

**Columns:**
- `CAServer` - **Added by script** - CA that issued certificate
- `CommonName` - Certificate subject
- `RequesterName` - Requester identity
- `Template` - Certificate template used
- `SerialNumber` - Certificate serial number
- `NotBefore` - Valid from date
- `NotAfter` - Expiration date
- `DaysRemaining` - Days until expiration
- `ExpirationStatus` - Valid | Expiring Soon | Expired
- `CertificateHash` - Certificate thumbprint
- `Disposition` - Certificate status code

#### 4. Certificate Templates
All templates from all CAs.

**Columns:**
- `CAServer` - **Added by script** - CA where template published
- `DisplayName` - Template friendly name
- `Name` - Template common name
- `Published` - True/False
- `PublishedOn` - CA servers
- `ValidityPeriod` - Certificate lifetime
- `MinimalKeyLength` - Minimum key size
- `Flags` - Template flags
- `EnrollmentFlags` - Enrollment behavior
- `Distinguished_Name` - AD path

#### 5. Template Permissions
All permission entries from all CAs.

**Columns:**
- `CAServer` - **Added by script**
- `TemplateName` - Template display name
- `TemplateCommonName` - Template CN
- `IdentityReference` - Security principal
- `AccessControlType` - Allow | Deny
- `ActiveDirectoryRights` - Specific rights
- `InheritanceType` - Inheritance model
- `IsInherited` - True/False

#### 6. Health Summary
Operational health metrics per CA.

**Columns:**
- `CAServer` - CA server hostname
- `HealthScore` - 0-100 health rating
- `Status` - EXCELLENT | GOOD | FAIR | POOR
- `Errors` - Error count
- `Warnings` - Warning count
- `ServiceStatus` - Certificate Services state
- `CACertDaysUntilExpiration` - CA cert expiration countdown
- `DatabaseSizeMB` - Database size
- `TotalDatabaseRecords` - Total DB records
- `AssessmentDate` - Timestamp of health check

#### 7-10. Distribution and Event Data
CRL Health, AIA Health, Template Health, and Event Log Issues worksheets contain data as exported from health assessments, with CAServer column added.

## How It Works

### 1. Module Verification
- Checks for ImportExcel module
- Auto-installs if missing (`Install-Module ImportExcel -Scope CurrentUser`)
- Imports module for use

### 2. Path Validation
- Validates assessment path exists
- Checks for health path (optional)
- Creates output directory if needed

### 3. Assessment Discovery
- Scans for folders matching pattern: `*_PKI_Assessment_*`
- Extracts CA name and timestamp from folder name
- Groups by CA server
- Selects most recent assessment per CA

### 4. Health Discovery
- Scans for folders matching pattern: `*_PKI_Health_*`
- Extracts CA name and timestamp
- Groups by CA server
- Selects most recent health report per CA

### 5. Data Loading - Assessment
For each CA:
- **Certificates**: Loads CSV, adds CAServer column, calculates summary stats
- **Templates**: Loads CSV, adds CAServer column
- **Permissions**: Loads CSV, adds CAServer column

### 6. Data Loading - Health
For each CA:
- **Health Report**: Parses text file with regex to extract metrics
- **CRL Health**: Loads CSV if exists, adds CAServer column
- **AIA Health**: Loads CSV if exists, adds CAServer column
- **Template Health**: Loads CSV if exists, adds CAServer column
- **Event Log Issues**: Loads CSV if exists, adds CAServer column

### 7. Excel Generation
- Creates Excel package with professional formatting
- Exports each dataset to separate worksheet
- Applies:
  - Auto-sized columns
  - Frozen top row
  - Bold headers
- Saves to output path

## Common Issues & Troubleshooting

### Issue: "No PKI assessment folders found"
**Cause**: Assessment path doesn't contain properly named folders  
**Solution**: 
- Verify folder naming: `HOSTNAME_PKI_Assessment_YYYYMMDD_HHMMSS`
- Ensure assessments have been run: `Get-ComprehensivePKIReport.ps1`
- Check path spelling and network access

### Issue: "ImportExcel module not found"
**Cause**: Module missing and auto-install failed  
**Solution**:
```powershell
# Manual installation
Install-Module ImportExcel -Scope CurrentUser -Force

# If offline, download and install manually from PowerShell Gallery
```

### Issue: "Failed to load certificates: [error]"
**Cause**: CSV file corrupt or missing columns  
**Solution**: Re-run assessment on affected CA server

### Issue: "Health report parsing returned N/A"
**Cause**: Text report format doesn't match expected patterns  
**Solution**: Ensure using matching versions of Get-PKIHealthReport.ps1 and Merge script

### Issue: "Access denied to output path"
**Cause**: Insufficient permissions to create/write Excel file  
**Solution**: 
```powershell
# Check permissions
Test-Path -Path "C:\Reports\PKI_Consolidated" -PathType Container

# Create directory with proper permissions
New-Item -ItemType Directory -Path "C:\Reports\PKI_Consolidated" -Force
```

## Data Analysis Examples

### Filter Certificates by CA Server
```powershell
# Open Excel file
$excel = Open-ExcelPackage -Path "C:\Reports\PKI_Consolidated\PKI_Consolidated_Assessment_*.xlsx"

# Get Issued Certificates worksheet
$certs = Import-Excel -ExcelPackage $excel -WorksheetName "Issued Certificates"

# Filter for specific CA
$certs | Where-Object { $_.CAServer -eq 'LAX11CA01' } |
    Format-Table CommonName, NotAfter, ExpirationStatus
```

### Compare Health Scores
```powershell
# Import health summary
$health = Import-Excel -Path "C:\Reports\PKI_Consolidated\*.xlsx" -WorksheetName "Health Summary"

# Compare scores
$health | Sort-Object HealthScore |
    Format-Table CAServer, HealthScore, Status, Errors, Warnings
```

### Cross-CA Certificate Analysis
```powershell
# Load consolidated certificates
$certs = Import-Excel -Path "C:\Reports\PKI_Consolidated\*.xlsx" -WorksheetName "Issued Certificates"

# Group by template and CA
$certs | Group-Object Template, CAServer |
    Sort-Object Count -Descending |
    Select-Object Count, @{N='Template';E={$_.Name.Split(',')[0]}}, @{N='CA';E={$_.Name.Split(',')[1]}}
```

### Event Log Correlation
```powershell
# Load event log issues
$events = Import-Excel -Path "C:\Reports\PKI_Consolidated\*.xlsx" -WorksheetName "Event Log Issues"

# Find common issues across CAs
$events | Group-Object EventID, Level |
    Sort-Object Count -Descending |
    Select-Object Count, @{N='EventID';E={$_.Name.Split(',')[0]}}, @{N='Level';E={$_.Name.Split(',')[1]}}
```

## Integration Workflow

### Complete Enterprise PKI Assessment

#### Step 1: Run Assessments on All CAs
```powershell
# List of CA servers
$caServers = @('LAX11CA01', 'SEA11CA01', 'ATL11CA01', 'DAL11CA01')

# Run on each CA (requires PSRemoting or manual execution)
foreach ($ca in $caServers) {
    Invoke-Command -ComputerName $ca -ScriptBlock {
        & "C:\Scripts\Get-ComprehensivePKIReport.ps1" -OutputDirectory "\\FileServer\PKI\Assessment"
        & "C:\Scripts\Get-PKIHealthReport.ps1" -OutputDirectory "\\FileServer\PKI\Health"
    }
}
```

#### Step 2: Consolidate Reports
```powershell
.\Merge-PKIAssessmentReports.ps1 `
    -AssessmentPath "\\FileServer\PKI\Assessment" `
    -HealthPath "\\FileServer\PKI\Health" `
    -OutputDirectory "\\FileServer\PKI\Reports" `
    -OrganizationName "Contoso"
```

#### Step 3: Distribute Report
```powershell
# Email consolidated report
$reportFile = Get-ChildItem "\\FileServer\PKI\Reports" -Filter "PKI_Consolidated_*.xlsx" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

Send-MailMessage `
    -To "pki-team@contoso.com" `
    -From "pki-automation@contoso.com" `
    -Subject "Monthly PKI Assessment - $(Get-Date -Format 'MMMM yyyy')" `
    -Body "Attached is the consolidated PKI assessment covering all 4 CA servers." `
    -Attachments $reportFile.FullName `
    -SmtpServer "smtp.contoso.com"
```

## Best Practices

1. **Centralize Data Collection** - Use UNC paths to consolidate all CA data
2. **Run Regularly** - Monthly consolidated reports track PKI health trends
3. **Version Control** - Include timestamps in output filenames for historical comparison
4. **Archive Reports** - Keep consolidated reports for compliance auditing
5. **Filter in Excel** - Use Excel's filter/pivot features on CAServer column
6. **Validate Before Merge** - Ensure all CA assessments completed successfully
7. **Check File Sizes** - Large environments (100k+ certs) create large Excel files
8. **Use Consistent Timing** - Run all CA assessments within same time window

## Performance Considerations

### Large Datasets
- **193,000 certificates**: ~90 seconds to process
- **Excel file size**: ~50 MB for 200k certificates
- **Memory usage**: ~500 MB during Excel generation

### Optimization Tips
- Run on machine with adequate RAM (8 GB+)
- Use local paths when possible (faster than UNC)
- Close other applications during large consolidations
- Consider splitting very large environments (500k+ certs) into regional reports

## Security Considerations

- **Data Access**: Requires read access to assessment folders
- **Network Paths**: UNC paths traverse network - use secure shares
- **Output Protection**: Excel files contain comprehensive PKI data
- **Module Installation**: ImportExcel module downloaded from PowerShell Gallery

## Related Scripts

- [Get-ComprehensivePKIReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensivePKIReport) - Generate assessment data
- [Get-PKIHealthReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-PKIHealthReport) - Generate health data

## Version History

- **v1.0** (2025-12-24): Initial release with multi-CA consolidation

## See Also

- [ImportExcel Module](https://github.com/dfinke/ImportExcel)
- [Excel Workbook Automation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/export-excel)
