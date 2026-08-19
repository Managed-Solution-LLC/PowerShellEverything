# Get-LyncHealthReport.ps1

## Overview
Generates a comprehensive health and diagnostics report for Lync/Skype for Business environments. This monitoring tool performs deep health checks including certificate validation, database mirror states, health monitoring configuration, event log analysis, and system performance metrics.

## Features
- **Certificate Status Monitoring**: Expiration tracking and validity checks
- **Database Mirror State Analysis**: SQL mirroring health and synchronization
- **Health Monitoring Config**: Validates monitoring configuration
- **Event Log Analysis**: Recent error and warning detection
- **Performance Metrics**: System resource utilization
- **Lync-Specific Counters**: Service performance indicators (when available)
- **Customizable Timeframes**: Configurable event log and analysis periods
- **Detailed Diagnostics**: Root cause analysis assistance

## Prerequisites
- **PowerShell Version**: 3.0 or higher
- **Required Environment**: Lync/Skype for Business Management Shell
- **Required Permissions**: 
  - Lync Administrator or CsAdministrator role
  - Local Administrator (for event log access)
  - SQL read permissions (for database mirror state)
- **Network Requirements**: Access to Front End servers and SQL databases

## Parameters

### Required Parameters
- **PoolFQDN**: Primary Lync pool FQDN
  - Type: String
  - Validation: Must not be null or empty
  - Description: FQDN of the Lync pool to analyze for health checks
  - Example: `"lyncpool.contoso.com"`

### Optional Parameters
- **ReportPath**: Output file path
  - Type: String
  - Default: `"C:\Reports\Lync_Health_Diagnostics_{timestamp}.txt"`
  - Description: Full path where health report will be saved

- **EventLogHours**: Event log analysis period
  - Type: Integer
  - Default: `24`
  - Range: 1 to 168 hours (1 week)
  - Description: Hours to look back when analyzing event logs

- **MaxEventLogErrors**: Maximum errors to retrieve
  - Type: Integer
  - Default: `20`
  - Description: Limits the number of event log errors analyzed

- **OrganizationName**: Organization name
  - Type: String
  - Default: `"Organization"`
  - Description: Organization name for report headers

## Usage Examples

### Example 1: Standard Health Check
```powershell
.\Get-LyncHealthReport.ps1 -PoolFQDN "lyncpool.contoso.com"
```
Generates a health report with default 24-hour event log analysis.

### Example 2: Extended Event Log Analysis
```powershell
.\Get-LyncHealthReport.ps1 -PoolFQDN "lyncpool.contoso.com" -OrganizationName "Contoso Corp" -EventLogHours 48
```
Analyzes 48 hours of event logs with custom organization name.

### Example 3: Detailed Error Analysis
```powershell
.\Get-LyncHealthReport.ps1 -PoolFQDN "lyncpool.contoso.com" -ReportPath "D:\Reports\Health_Report.txt" -MaxEventLogErrors 50
```
Increases error log capture to 50 entries for detailed troubleshooting.

### Example 4: Weekly Health Review
```powershell
.\Get-LyncHealthReport.ps1 -PoolFQDN "lyncpool.contoso.com" -EventLogHours 168 -MaxEventLogErrors 100
```
Full week analysis with extended error logging for weekly health reviews.

## Output

### Report Structure

#### 1. Certificate Expiration and Validity Analysis
For each certificate in the Lync certificate store:
- **Thumbprint**: Unique certificate identifier
- **Subject**: Certificate subject name and purpose
- **Issuer**: Certificate authority information
- **Expiration Date**: When certificate expires
- **Days Until Expiration**: Countdown with status indicators
- **Status**:
  - 🔴 **CRITICAL** (< 30 days): Immediate renewal required
  - ⚠️ **WARNING** (30-90 days): Plan renewal soon
  - ✅ **OK** (> 90 days): Certificate healthy

#### 2. Database Mirror State Assessment
For the specified pool:
- **Database Identity**: Primary database name and location
- **State Machine State**: Current mirroring state
  - Synchronized: Healthy replication
  - Principal: Active database
  - Mirror: Standby database
  - Disconnected: Mirroring failure
- **Synchronized Status**: True/False replication status
- **Failover Readiness**: Assessment of DR capability

#### 3. Health Monitoring Configuration
- **Monitoring Configuration Status**: Enabled/Disabled
- **Active Monitoring Rules**: Count and listing
- **Health Check Intervals**: Configured check frequencies
- **Alert Thresholds**: Warning and critical thresholds
- **Monitoring Gaps**: Uncovered services or components

#### 4. Recent Event Log Error Analysis
From Application, System, and Lync-specific event logs:
- **Time Written**: When error occurred
- **Source**: Application or service generating error
- **Event ID**: Numeric event identifier
- **Level**: Error, Warning, Critical
- **Message**: Full error message text
- **User Context**: Account running when error occurred (if available)

**Event Sources Analyzed**:
- Lync Server services (RTC*)
- SQL Server (for database errors)
- Windows System events
- Application events

#### 5. System Performance Metrics
- **CPU Utilization**: Current and average CPU usage
- **Memory Usage**: Total, used, and available memory
- **Disk Space**: Free space on system and data drives
- **Network Utilization**: Bandwidth usage (if available)
- **Process Count**: Active Lync-related processes
- **Handle Count**: System handle utilization

#### 6. Lync-Specific Performance Counters (if available)
- **Active Conferences**: Current conference count
- **Active Users**: Currently signed-in users
- **Failed Logins**: Authentication failures
- **Media Quality**: Audio/video quality metrics
- **SIP Messages**: Message throughput
- **Database Latency**: SQL query performance

### Output File Locations
Default: `C:\Reports\`

### Output File Naming
Pattern: `Lync_Health_Diagnostics_{YYYYMMDD_HHmmss}.txt`

Example: `Lync_Health_Diagnostics_20251223_143052.txt`

### Console Output
Real-time progress indicators during health checks:
- Certificate scanning progress
- Database connectivity status
- Event log analysis progress
- Performance counter collection status

## Common Issues & Troubleshooting

### Issue: "Access is denied" for Event Logs
**Solution**: Run as Administrator:
```powershell
# Right-click PowerShell/Lync Management Shell
# Select "Run as Administrator"
.\Get-LyncHealthReport.ps1 -PoolFQDN "lyncpool.contoso.com"
```

Or grant event log read permissions:
```powershell
# Grant specific user event log read access
wevtutil sl Application /ca:O:BAG:SYD:(A;;0x1;;;BA)(A;;0x1;;;DOMAIN\Username)
```

### Issue: Database Mirror State Returns No Data
**Possible Causes**:
1. Pool doesn't use SQL mirroring
2. Incorrect PoolFQDN specified
3. SQL permissions insufficient

**Solution**: Verify mirroring configuration:
```powershell
# Check if mirroring is configured
Get-CsDatabaseMirrorState -PoolFqdn "lyncpool.contoso.com"

# If null, mirroring may not be configured
Get-CsPool -Identity "lyncpool.contoso.com" | Select-Object MirrorServer
```

### Issue: No Lync-Specific Performance Counters
**Solution**: This is expected if:
- Performance counters not installed
- Lync services not running
- Remote server querying (counters are local only)

The script continues with system performance metrics only.

### Issue: Event Log Analysis Shows "No Events Found"
**Solution**: This could indicate:
1. **Good news**: System is healthy (no errors)
2. Event logs cleared recently
3. Insufficient permissions

Verify event logs exist:
```powershell
Get-EventLog -LogName Application -Newest 10 -EntryType Error
```

### Issue: Certificate Check Shows Errors
**Error**: "Cannot access certificate store"

**Solution**: Ensure running as Administrator and certificate store is accessible:
```powershell
# Verify certificate access
Get-ChildItem Cert:\LocalMachine\My

# If fails, repair certificate store permissions
certutil -repairstore my
```

### Issue: Report Generation Hangs
**Solution**: Large event logs can slow processing:
1. Reduce `-EventLogHours` parameter (use 24 instead of 168)
2. Reduce `-MaxEventLogErrors` parameter (use 20 instead of 100)
3. Run on the Front End server directly (faster event log access)

### Issue: "Pool FQDN not found"
**Solution**: Verify pool name:
```powershell
# List all pools
Get-CsPool | Select-Object Identity, Fqdn

# Use exact FQDN from output
.\Get-LyncHealthReport.ps1 -PoolFQDN "correct-pool-fqdn.contoso.com"
```

## Use Case Scenarios

### Daily Health Monitoring
Schedule daily health checks:
```powershell
# Create scheduled task to run daily
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"C:\Scripts\Get-LyncHealthReport.ps1`" -PoolFQDN `"lyncpool.contoso.com`""
$Trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM
Register-ScheduledTask -TaskName "Lync Daily Health Check" -Action $Action -Trigger $Trigger
```

### Incident Response
During outages or issues:
1. Generate immediate health report
2. Review event log section for recent errors
3. Check certificate status for expiration issues
4. Verify database mirror state
5. Identify resource bottlenecks in performance section

### Proactive Monitoring
Weekly health reviews:
```powershell
# Every Monday, analyze full week
.\Get-LyncHealthReport.ps1 -PoolFQDN "lyncpool.contoso.com" -EventLogHours 168 -MaxEventLogErrors 50
```
Review for:
- Trend analysis in error patterns
- Certificate approaching expiration
- Database mirror interruptions
- Performance degradation

### Certificate Renewal Planning
Monthly certificate audits:
1. Run health report
2. Extract certificate section
3. Create renewal timeline
4. Coordinate with PKI team

### Change Management
Before and after changes:
```powershell
# Before change
.\Get-LyncHealthReport.ps1 -PoolFQDN "pool.contoso.com" -ReportPath "C:\Reports\Pre-Change-Health.txt"

# Perform change

# After change
.\Get-LyncHealthReport.ps1 -PoolFQDN "pool.contoso.com" -ReportPath "C:\Reports\Post-Change-Health.txt"

# Compare reports
Compare-Object (Get-Content "C:\Reports\Pre-Change-Health.txt") (Get-Content "C:\Reports\Post-Change-Health.txt")
```

### Performance Baseline
Establish performance baselines:
1. Generate health reports during normal operations
2. Document typical CPU, memory, and counter values
3. Use baselines to identify performance degradation
4. Capacity planning and growth trending

## Health Status Interpretation

### Critical Issues (Immediate Action)
- Certificates expiring within 30 days
- Database mirror disconnected or not synchronized
- Critical event log errors from Lync services
- CPU consistently above 90%
- Memory exhaustion
- Disk space below 10%

### Warning Issues (Action Needed Soon)
- Certificates expiring 30-90 days
- Intermittent database synchronization issues
- Event log warnings from Lync services
- CPU consistently above 70%
- Memory usage above 80%
- Disk space below 20%

### Informational (Monitor)
- Certificates expiring 90+ days out
- Normal event log entries
- Resource utilization within normal ranges
- All services running properly

## Related Scripts
- [Get-ComprehensiveLyncReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveLyncReport) - Complete environment assessment
- [Get-LyncServiceStatus.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncServiceStatus) - Detailed service status
- [Get-LyncInfrastructureReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncInfrastructureReport) - Infrastructure configuration

## Version History
- **v2.0** (2025-09-17): Enhanced health diagnostics
  - Added event log analysis
  - Enhanced performance metrics
  - Improved certificate checking
  - Added health monitoring configuration
  - Better error handling
- **v1.0** (2024): Initial release
  - Basic health checking
  - Certificate monitoring

## See Also
- [Monitor Lync Server Health](https://docs.microsoft.com/en-us/skypeforbusiness/manage/health-and-monitoring/)
- [Lync Server Event Logs](https://docs.microsoft.com/en-us/skypeforbusiness/manage/health-and-monitoring/event-logs)
- [Database Mirroring Monitoring](https://docs.microsoft.com/en-us/sql/database-engine/database-mirroring/)
