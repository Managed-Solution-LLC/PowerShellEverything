# Lync Assessment Scripts

This directory contains comprehensive assessment and reporting tools for Lync/Skype for Business environments.

## Available Scripts

### Data Export Tools
- **[Start-LyncCsvExporter.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Start-LyncCsvExporter)** - Interactive menu-driven CSV export tool
  - User data exports (Summary, Voice, SBA, Complete)
  - Phone/device inventory (Common area phones, Analog devices, USB devices)
  - Infrastructure exports (Pools, Policies)
  - Bulk export operations

- **[Export-ADLyncTeamsMigrationData.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Export-ADLyncTeamsMigrationData)** - Active Directory export for Teams migration
  - AD user attributes for migration analysis
  - Lync-specific attribute capture
  - Voice routing and SIP address export
  - Teams migration readiness assessment

### Comprehensive Reports
- **[Get-ComprehensiveLyncReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveLyncReport)** - Complete environment assessment
  - Executive summary with key metrics
  - Pool architecture analysis
  - Certificate health monitoring
  - User distribution analytics
  - Database mirror state assessment
  - Infrastructure recommendations

### Health & Diagnostics
- **[Get-LyncHealthReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncHealthReport)** - Health monitoring and diagnostics
  - Certificate expiration tracking
  - Database mirror state analysis
  - Event log error analysis
  - System performance metrics
  - Lync-specific performance counters

### Infrastructure Analysis
- **[Get-LyncInfrastructureReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncInfrastructureReport)** - Infrastructure configuration report
  - Pool categorization (Standard, SBA, IVR, Edge)
  - Computer deployment analysis
  - Service configuration review
  - Topology documentation
  - Conference directory inventory

- **[Get-LyncServiceStatus.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncServiceStatus)** - Service status monitoring
  - Windows service analysis
  - Process performance metrics
  - Service dependency mapping
  - Resource usage reporting

### User Analysis
- **[Get-LyncUserRegistrationReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncUserRegistrationReport)** - User registration and activity
  - Registration status analysis
  - User activity tracking
  - Voice enablement statistics
  - SBA user identification
  - Inactive user detection

## Common Prerequisites

All scripts require:
- **PowerShell**: 3.0 or higher
- **Lync Management Shell**: For Lync-specific cmdlets
- **Permissions**: CsAdministrator or CsUserAdministrator role
- **Network Access**: Connectivity to Lync Front End servers

## Quick Start Guide

### For Daily Operations
```powershell
# Quick health check
.\Get-LyncHealthReport.ps1 -PoolFQDN "lyncpool.contoso.com"

# Service status
.\Get-LyncServiceStatus.ps1 -OrganizationName "Contoso"

# User registration check
.\Get-LyncUserRegistrationReport.ps1 -OrganizationName "Contoso"
```

### For Migration Planning
```powershell
# Export AD data for migration analysis
.\Export-ADLyncTeamsMigrationData.ps1 -OrganizationName "Contoso" -ExportToCsv

# Export all user and device data
.\Start-LyncCsvExporter.ps1 -OrganizationName "Contoso"
# Select option 12 (Export Everything)

# Generate comprehensive assessment
.\Get-ComprehensiveLyncReport.ps1 -PoolFQDN "lyncpool.contoso.com" -OrganizationName "Contoso"
```

### For Infrastructure Documentation
```powershell
# Complete infrastructure report
.\Get-LyncInfrastructureReport.ps1 -OrganizationName "Contoso"

# Comprehensive environment assessment
.\Get-ComprehensiveLyncReport.ps1 -PoolFQDN "lyncpool.contoso.com" -OrganizationName "Contoso"
```

## Report Output Locations

Default output directories:
- **Text Reports**: `C:\Reports\`
- **CSV Exports**: `C:\Reports\CSV_Exports\`

All scripts support custom output paths via parameters.

## Common Parameters Across Scripts

Most scripts support these common parameters:
- `-OrganizationName` - Organization name for report headers (default: "Organization")
- `-ReportPath` or `-OutputDirectory` - Custom output location
- `-SBAPattern` - Pattern to identify branch office SBA pools (default: "*MSSBA*")

## Customization Tips

### Custom Pool Patterns
If your environment uses different naming conventions:
```powershell
# Custom SBA pattern
-SBAPattern "*Branch*"

# Custom standard pool pattern  
-LyncPattern "*sfb*"

# Custom Edge pattern
-EdgePattern "*dmz*"
```

### Performance Tuning
For large environments:
```powershell
# Reduce sample sizes
-SampleUserCount 5
-MaxComputersPerPool 5

# Limit time ranges
-EventLogHours 24
-RecentModifiedDays 30
```

## Troubleshooting

### Common Issues

**"Cmdlet not found" errors**:
- Run from Lync Management Shell (Start Menu → Lync Server Management Shell)
- Or import module: `Import-Module SkypeForBusiness`

**"Access Denied" errors**:
- Verify CsAdministrator role assignment
- Run PowerShell as Administrator for local operations
- Check network connectivity to Front End servers

**Slow report generation**:
- Run during off-peak hours
- Reduce sample sizes and time ranges
- Consider per-pool analysis for very large environments

**Empty or incomplete data**:
- Verify Lync services are running
- Check permissions to query specific data
- Review script output for specific error messages

## Related Documentation

- [Office 365 Migration Guide](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Office365-Quick-Start)
- [Lync CSV Exporter Changes](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Lync-CSV-Exporter-Changes)
- [Microsoft Lync Server Documentation](https://docs.microsoft.com/en-us/skypeforbusiness/)

## Support and Contributing

For issues or enhancements:
1. Review script-specific documentation (linked above)
2. Check troubleshooting sections
3. Review error messages and script output
4. Refer to Microsoft Lync/Skype documentation

## Version Information

All scripts follow the project's version numbering:
- **v2.0** (2025-09-17): Current release with enhanced features
- **v1.0** (2024): Initial releases

See individual script documentation for specific version histories and changes.
