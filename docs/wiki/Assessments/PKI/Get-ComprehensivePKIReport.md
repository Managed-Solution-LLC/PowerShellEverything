# Get-ComprehensivePKIReport.ps1

## Overview
Comprehensive PKI assessment tool for Certificate Authority infrastructure that exports all issued certificates, certificate templates, and template permissions. This script provides complete visibility into your PKI environment for security audits, compliance reviews, and migration planning.

## Features
- **Certificate Export**: Retrieve all issued certificates from the Certificate Authority
- **Expiration Analysis**: Identify certificates expiring soon or already expired
- **Template Discovery**: Export all certificate templates from Active Directory
- **Permission Analysis**: Extract and analyze template ACLs and enrollment permissions
- **Published Template Detection**: Identify which templates are published to the CA
- **Multiple Output Formats**: Generate both CSV exports and comprehensive text reports
- **Executive Summary**: High-level statistics and key findings
- **Flexible Configuration**: Customize expiration thresholds and output locations

## Prerequisites

### Required Components
- **Windows Server** with Certificate Authority role installed
- **RSAT-ADCS PowerShell Module**
  ```powershell
  Install-WindowsFeature RSAT-ADCS
  ```
- **Administrator Privileges** on the CA server
- **PowerShell 5.1 or later**
- **Network Access** to the Certificate Authority server

### Optional Components
- **ActiveDirectory PowerShell Module** (recommended for enhanced template permissions analysis)
  - Automatically detected and used if available
  - Falls back to basic permissions if not available

### Permissions Required
- Local Administrator on CA server
- Read permissions on AD Certificate Templates container
- Ability to query Certificate Authority database

## Parameters

### Required Parameters
None - the script will auto-discover the CA server if not specified.

### Optional Parameters

#### `-OutputDirectory`
Directory path where reports and CSV exports will be saved.
- **Type**: String
- **Default**: `C:\Reports\PKI_Assessment`
- **Example**: `-OutputDirectory "D:\PKI_Reports"`

#### `-CAServerName`
Name of the Certificate Authority server to assess.
- **Type**: String
- **Default**: Auto-discovered from system configuration
- **Example**: `-CAServerName "CA01.contoso.com"`
- **Note**: Use FQDN format: `SERVERNAME.domain.com`

#### `-IncludeRevokedCertificates`
Include revoked certificates in the assessment.
- **Type**: Switch
- **Default**: False (only active certificates)
- **Example**: `-IncludeRevokedCertificates`

#### `-DaysToExpiration`
Flag certificates expiring within this number of days.
- **Type**: Integer
- **Range**: 1-365
- **Default**: 90 days
- **Example**: `-DaysToExpiration 30`

#### `-OrganizationName`
Organization name for report headers.
- **Type**: String
- **Default**: `Organization`
- **Example**: `-OrganizationName "Contoso"`

## Usage Examples

### Example 1: Basic Assessment with Auto-Discovery
```powershell
.\Get-ComprehensivePKIReport.ps1
```
Runs assessment with default settings:
- Auto-discovers the CA server
- Exports only active certificates
- Flags certificates expiring within 90 days
- Saves reports to `C:\Reports\PKI_Assessment\`

### Example 2: Specify CA Server
```powershell
.\Get-ComprehensivePKIReport.ps1 -CAServerName "CA01.contoso.com"
```
Explicitly specifies the Certificate Authority server to assess.

### Example 3: Include Revoked Certificates
```powershell
.\Get-ComprehensivePKIReport.ps1 -CAServerName "CA01.contoso.com" -IncludeRevokedCertificates
```
Includes both active and revoked certificates in the assessment for complete audit trail.

### Example 4: Custom Expiration Threshold
```powershell
.\Get-ComprehensivePKIReport.ps1 -DaysToExpiration 30
```
Flags certificates expiring within 30 days instead of default 90 days.

### Example 5: Full Custom Configuration
```powershell
.\Get-ComprehensivePKIReport.ps1 `
    -CAServerName "CA01.contoso.com" `
    -OutputDirectory "D:\Reports\PKI" `
    -IncludeRevokedCertificates `
    -DaysToExpiration 60 `
    -OrganizationName "Contoso Corporation"
```
Complete custom configuration for enterprise assessment.

### Example 6: Pre-Migration Assessment
```powershell
.\Get-ComprehensivePKIReport.ps1 `
    -IncludeRevokedCertificates `
    -DaysToExpiration 180 `
    -OrganizationName "Contoso" `
    -OutputDirectory "C:\Migration\PKI_Baseline"
```
Comprehensive baseline assessment before CA migration or decommission.

## Output

### Generated Files
The script generates four output files with timestamps:

#### 1. Issued Certificates CSV
**Filename**: `PKI_IssuedCertificates_YYYYMMDD_HHmmss.csv`

**Columns**:
- `CommonName`: Certificate subject common name
- `RequesterName`: User/computer that requested the certificate
- `Template`: Certificate template used
- `SerialNumber`: Certificate serial number
- `NotBefore`: Certificate validity start date
- `NotAfter`: Certificate expiration date
- `DaysRemaining`: Days until expiration (negative if expired)
- `ExpirationStatus`: Valid | Expiring Soon | Expired
- `CertificateHash`: Certificate thumbprint/hash
- `Disposition`: Issued | Revoked (if included)

#### 2. Certificate Templates CSV
**Filename**: `PKI_CertificateTemplates_YYYYMMDD_HHmmss.csv`

**Columns**:
- `DisplayName`: Template display name
- `Name`: Template common name (CN)
- `Published`: True/False - whether published to CA
- `PublishedOn`: CA server(s) where template is published
- `ValidityPeriod`: Certificate validity period
- `MinimalKeyLength`: Minimum required key length
- `Flags`: Template flags (numeric)
- `EnrollmentFlags`: Enrollment flags (numeric)
- `Distinguished_Name`: Full AD distinguished name

#### 3. Template Permissions CSV
**Filename**: `PKI_TemplatePermissions_YYYYMMDD_HHmmss.csv`

**Columns**:
- `TemplateName`: Template display name
- `TemplateCommonName`: Template CN
- `IdentityReference`: User/group with permissions
- `AccessControlType`: Allow | Deny
- `ActiveDirectoryRights`: Specific rights (Enroll, AutoEnroll, Read, Write, etc.)
- `InheritanceType`: Inheritance settings
- `IsInherited`: True/False - inherited permission

#### 4. Assessment Report (Text)
**Filename**: `PKI_Assessment_Report_YYYYMMDD_HHmmss.txt`

**Sections**:
- **CA Information**: Server name, assessment date, generated by
- **Issued Certificates Summary**: Total, valid, expiring, expired counts
- **Top 10 Expiring Certificates**: Certificates closest to expiration
- **Certificate Templates Summary**: Total, published, unpublished counts
- **Published Templates**: Detailed list with properties
- **Template Permissions Summary**: Key enrollment permissions by template
- **Assessment Summary**: Errors, warnings, exported file paths

### Output File Locations
**Default**: `C:\Reports\PKI_Assessment\`
**Custom**: Specify with `-OutputDirectory` parameter

### Console Output
The script provides color-coded real-time feedback:
- **Green (✅)**: Successful operations
- **Yellow (⚠️)**: Warnings and informational messages
- **Red (❌)**: Errors and failures
- **Cyan**: Section headers and progress updates

## Data Analysis Use Cases

### Security Audit
Review template permissions to identify:
- Unauthorized enrollment rights
- Over-permissioned templates
- Templates with auto-enrollment enabled
- Unexpected user/group access

### Certificate Lifecycle Management
Analyze certificate expiration to:
- Plan certificate renewals
- Identify expired certificates to revoke
- Forecast certificate issuance needs
- Track certificate usage patterns

### Compliance Review
Generate reports showing:
- All issued certificates with requesters
- Template security configurations
- Permission assignments
- Certificate validity status

### Migration Planning
Export complete PKI configuration:
- Baseline before CA migration
- Template configurations to replicate
- Issued certificates inventory
- Permission mappings for new CA

### Template Governance
Monitor template usage:
- Identify unused templates
- Review published vs. unpublished templates
- Audit template permission changes
- Document template inventory

## Common Issues & Troubleshooting

### Issue: "ADCS-Administration module not found"
**Cause**: RSAT-ADCS feature not installed

**Solution**:
```powershell
# Install RSAT-ADCS
Install-WindowsFeature RSAT-ADCS

# Verify installation
Get-Module ADCS-Administration -ListAvailable

# Import module
Import-Module ADCS-Administration
```

### Issue: "Cannot connect to CA server"
**Cause**: Network connectivity, firewall, or permissions issue

**Solution**:
1. Verify CA server is online:
   ```powershell
   Test-Connection CAServerName
   ```

2. Check CA service status:
   ```powershell
   Get-Service CertSvc -ComputerName CAServerName
   ```

3. Test CA connectivity:
   ```powershell
   certutil -config "CAServerName" -ping
   ```

4. Verify firewall allows RPC traffic (ports 135, 49152-65535)

5. Ensure running as Administrator with CA access rights

### Issue: "No issued certificates found"
**Cause**: Empty CA database or permissions issue

**Solution**:
1. Verify CA has issued certificates:
   ```powershell
   certutil -view -restrict "Disposition=20" -out "CommonName"
   ```

2. Check you're querying correct CA:
   ```powershell
   certutil -dump | Select-String "Config:"
   ```

3. Verify CA database is accessible and not corrupted

### Issue: "Access Denied when retrieving templates"
**Cause**: Insufficient AD permissions

**Solution**:
1. Run PowerShell as Administrator
2. Verify domain connectivity:
   ```powershell
   Test-Connection (Get-ADDomain).PDCEmulator
   ```
3. Check permissions on Certificate Templates container in AD
4. Ensure account has Read permissions on Configuration partition

### Issue: "ActiveDirectory module not available"
**Cause**: RSAT-AD-PowerShell not installed (warning only)

**Solution** (optional - script works without it):
```powershell
# Install AD PowerShell module
Install-WindowsFeature RSAT-AD-PowerShell

# Import module
Import-Module ActiveDirectory
```

### Issue: "Script takes long time on large deployments"
**Cause**: Large number of certificates or templates

**Solution**:
- This is expected behavior - script is processing all data
- Run during off-hours for large environments
- Monitor progress in console output
- Consider filtering by date range (future enhancement)

## Performance Considerations

### Expected Runtime
- **Small PKI** (< 1,000 certs): 1-2 minutes
- **Medium PKI** (1,000-10,000 certs): 3-10 minutes  
- **Large PKI** (> 10,000 certs): 10-30 minutes
- **Enterprise PKI** (> 100,000 certs): 30+ minutes

### Resource Usage
- **Network**: Moderate - queries CA database and AD
- **CPU**: Low - parsing and processing
- **Memory**: Moderate - holds certificate data in memory
- **Disk I/O**: Low - CSV/text file writes

### Optimization Tips
1. Run on CA server or management workstation to reduce network latency
2. Use `-IncludeRevokedCertificates` only when needed
3. Schedule during off-peak hours for large environments
4. Ensure adequate disk space for output files (estimate 1 KB per certificate)

## Related Scripts
- [Export-ADLyncTeamsMigrationData.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Export-ADLyncTeamsMigrationData) - Uses certificate data for Teams migration
- [Get-ServerCertificate.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/docs/Security/Get-ServerCertificate) - Individual server certificate inspection

## Version History
- **v1.0** (2025-12-24): Initial release
  - Export issued certificates with expiration analysis
  - Export certificate templates from Active Directory
  - Extract and analyze template permissions
  - Generate comprehensive CSV and text reports
  - Auto-discovery of CA server
  - Support for revoked certificate inclusion

## See Also
- [Microsoft PKI Documentation](https://docs.microsoft.com/en-us/windows-server/networking/core-network-guide/cng/server-certs/install-the-certification-authority)
- [Certificate Templates](https://docs.microsoft.com/en-us/windows-server/networking/core-network-guide/cng/server-certs/configure-server-certificate-autoenrollment)
- [ADCS PowerShell Reference](https://docs.microsoft.com/en-us/powershell/module/adcsadministration/)
- [PKI Security Best Practices](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn786445(v=ws.11))
