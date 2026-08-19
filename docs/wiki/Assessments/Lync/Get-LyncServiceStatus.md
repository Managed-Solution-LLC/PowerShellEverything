# Get-LyncServiceStatus.ps1

## Overview
Generates a comprehensive service status report for Lync/Skype for Business environments. This monitoring tool analyzes Windows services, Lync Management Shell services, and related processes to provide administrators with complete visibility into service health and operational status.

## Features
- **Windows Services Analysis**: Status of all Lync-related Windows services
- **Lync Management Shell Services**: Lync-specific service information
- **Process Information**: Related process metrics including resource usage
- **Service Dependencies**: Service dependency and startup configuration
- **Performance Metrics**: CPU and memory usage by process
- **Customizable Service Patterns**: Flexible service identification
- **Specific Service Checks**: Critical service validation
- **Real-Time Status**: Current operational state

## Prerequisites
- **PowerShell Version**: 3.0 or higher
- **Required Permissions**: 
  - Local Administrator (for service query)
  - Read access to process information
- **Optional**: Lync/Skype for Business Management Shell (for enhanced reporting)
- **Network Requirements**: Local or remote server access

## Parameters

### Optional Parameters
- **OrganizationName**: Organization name
  - Type: String
  - Default: `"Organization"`
  - Description: Organization name for report headers

- **ReportPath**: Output file path
  - Type: String
  - Default: `"C:\Reports\Lync_Service_Status_{timestamp}.txt"`
  - Description: Full path where service status report will be saved

- **ServicePatterns**: Service identification patterns
  - Type: String Array
  - Default: `@("*RTC*", "*Lync*", "*Skype*")`
  - Description: Wildcard patterns to identify Lync/SfB related services

- **SpecificServices**: Critical services to check
  - Type: String Array
  - Default: `@("RTCSRV", "RTCCLSAGT", "RTCATS", "RTCDSS", "RTCMCU", "RTCASMCU")`
  - Description: Specific service names checked individually regardless of patterns

## Usage Examples

### Example 1: Standard Service Status Report
```powershell
.\Get-LyncServiceStatus.ps1
```
Generates service status report with default patterns and organization name.

### Example 2: Custom Organization and Path
```powershell
.\Get-LyncServiceStatus.ps1 -OrganizationName "Contoso Corp" -ReportPath "D:\Reports\Contoso_Services.txt"
```
Creates report with custom organization name and output location.

### Example 3: Teams/Skype Hybrid Environment
```powershell
.\Get-LyncServiceStatus.ps1 -ServicePatterns @("*Teams*", "*SfB*", "*RTC*") -SpecificServices @("TeamsService", "SfBService")
```
Monitors services in Teams/Skype hybrid environment with custom patterns.

### Example 4: Focused RTC Service Monitoring
```powershell
.\Get-LyncServiceStatus.ps1 -ServicePatterns @("*RTC*") -SpecificServices @("RTCSRV", "RTCMCU")
```
Focuses on core RTC services only.

### Example 5: Extended Service Coverage
```powershell
.\Get-LyncServiceStatus.ps1 -ServicePatterns @("*RTC*", "*Lync*", "*Skype*", "*MSSQL*", "*FabricHost*")
```
Includes SQL Server and Fabric services for complete infrastructure monitoring.

## Output

### Report Structure

#### 1. Windows Services Status Summary
For each service matching patterns:
- **Service Name**: System service name
- **Display Name**: Friendly service name
- **Status**: Running, Stopped, Paused, etc.
- **Startup Type**: Automatic, Manual, Disabled
- **Account**: Service logon account
- **Dependencies**: Services this service depends on
- **Dependent Services**: Services that depend on this service

**Service Status Indicators**:
- ✅ **Running** (Automatic): Healthy
- ⚠️ **Stopped** (Automatic): Issue - service should be running
- ℹ️ **Stopped** (Manual/Disabled): Expected state
- 🔴 **Failed**: Critical - service in error state

#### 2. Lync Management Shell Service Information
(If Lync Management Shell available):
- **Service Identity**: Lync service pool and role
- **Computer**: Server hosting service
- **Status**: Active, Inactive, Quiesced
- **Service Type**: Registrar, WebServices, etc.
- **Dependent Features**: Features depending on service

#### 3. Related Process Information
For each Lync-related process:
- **Process Name**: Executable name
- **Process ID**: PID
- **CPU Usage**: Current CPU percentage
- **Memory Usage**: Private memory in MB
- **Handle Count**: System handles in use
- **Thread Count**: Active threads
- **Start Time**: When process started
- **Responding**: Process responsiveness status

**Process Health Indicators**:
- ✅ **Normal**: CPU < 50%, Memory stable, Responding
- ⚠️ **Warning**: CPU 50-80%, High memory, Responsive
- 🔴 **Critical**: CPU > 80%, Memory leak, Not responding

#### 4. Service Dependency Map
Visual representation of service dependencies:
```
RTCSRV (Front-End Service)
├── Depends on: RPC, EventLog, MSSQLSERVER
└── Required by: RTCMCU, RTCATS

RTCMCU (MCU Service)
├── Depends on: RTCSRV
└── Required by: None
```

#### 5. Service Performance Summary
- **Total Services Monitored**: Count of services checked
- **Services Running**: Count of active services
- **Services Stopped**: Count of stopped services (with startup type analysis)
- **Critical Issues**: Services that should be running but are stopped
- **Process Count**: Total Lync-related processes
- **Total CPU Usage**: Combined CPU across all Lync processes
- **Total Memory Usage**: Combined memory across all Lync processes

### Output File Locations
Default: `C:\Reports\`

### Output File Naming
Pattern: `Lync_Service_Status_{YYYYMMDD_HHmmss}.txt`

Example: `Lync_Service_Status_20251223_143052.txt`

### Console Output
Real-time status messages:
- Service discovery progress
- Process enumeration status
- Critical service alerts
- Report generation confirmation

## Common Issues & Troubleshooting

### Issue: "Access is denied" Error
**Solution**: Run PowerShell as Administrator:
```powershell
# Right-click PowerShell or Lync Management Shell
# Select "Run as Administrator"
.\Get-LyncServiceStatus.ps1
```

### Issue: No Services Found
**Possible Causes**:
1. Lync not installed on this server
2. Service patterns don't match your services
3. Services renamed or customized

**Solution**: Verify services and adjust patterns:
```powershell
# List all services with "RTC" in name
Get-Service -DisplayName "*RTC*"

# List all services with "Lync" in name
Get-Service -DisplayName "*Lync*"

# Adjust pattern accordingly
.\Get-LyncServiceStatus.ps1 -ServicePatterns @("*YourPattern*")
```

### Issue: Specific Service Not in Report
**Solution**: Add to SpecificServices parameter:
```powershell
.\Get-LyncServiceStatus.ps1 -SpecificServices @("RTCSRV", "RTCMCU", "YourServiceName")
```

### Issue: Process Information Empty
**Solution**: Ensure Lync processes are running:
```powershell
# Check for Lync processes
Get-Process | Where-Object {$_.ProcessName -like "*rtc*" -or $_.ProcessName -like "*lync*"}

# If none running, services may be stopped
Get-Service -DisplayName "*RTC*" | Where-Object {$_.Status -eq "Stopped"}
```

### Issue: Lync Management Shell Section Missing
**Solution**: This is expected if:
- Script run outside Lync Management Shell
- Lync cmdlets not available
- Remote server querying

The script continues with Windows Services information only. For full reporting:
```powershell
# Launch Lync Management Shell
# Start Menu → Lync Server Management Shell
.\Get-LyncServiceStatus.ps1
```

### Issue: "Service not found" for Specific Service
**Solution**: Verify service name:
```powershell
# Get exact service name
Get-Service | Select-Object Name, DisplayName | Where-Object {$_.DisplayName -like "*lync*"}

# Use exact Name (not DisplayName)
.\Get-LyncServiceStatus.ps1 -SpecificServices @("ExactServiceName")
```

### Issue: High CPU/Memory Reported
**Interpretation**:
- **Normal during calls**: High activity expected during peak usage
- **Idle system**: May indicate issue - investigate process

**Troubleshooting**:
```powershell
# Identify specific high-usage process
Get-Process | Where-Object {$_.CPU -gt 50} | Select-Object ProcessName, CPU, WorkingSet

# Check event logs for errors
Get-EventLog -LogName Application -Source "Lync*" -Newest 20
```

## Use Case Scenarios

### Service Health Monitoring
Daily service status checks:
```powershell
# Create scheduled task
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"C:\Scripts\Get-LyncServiceStatus.ps1`""
$Trigger = New-ScheduledTaskTrigger -Daily -At 8:00AM
Register-ScheduledTask -TaskName "Lync Daily Service Check" -Action $Action -Trigger $Trigger
```

### After-Hours Maintenance Verification
Post-maintenance health check:
```powershell
# Before maintenance
.\Get-LyncServiceStatus.ps1 -ReportPath "C:\Reports\Pre-Maintenance-Status.txt"

# Perform maintenance

# After maintenance
.\Get-LyncServiceStatus.ps1 -ReportPath "C:\Reports\Post-Maintenance-Status.txt"

# Compare
Compare-Object (Get-Content "C:\Reports\Pre-Maintenance-Status.txt") (Get-Content "C:\Reports\Post-Maintenance-Status.txt")
```

### Incident Response
During service outages:
1. Run service status report immediately
2. Identify stopped services
3. Check process status and resource usage
4. Review service dependencies
5. Restart services as needed

### Capacity Planning
Monitor resource trends:
```powershell
# Run regularly and track metrics over time
.\Get-LyncServiceStatus.ps1

# Extract metrics
$report = Get-Content "C:\Reports\Lync_Service_Status_*.txt" | Select-String "CPU Usage|Memory Usage"
```

### Disaster Recovery Testing
Validate service recovery:
1. Generate baseline service status
2. Simulate failure (stop services)
3. Execute recovery procedures
4. Generate post-recovery status
5. Verify all services restored

### Multi-Server Monitoring
Monitor multiple Front End servers:
```powershell
# Create function to run on remote servers
$Servers = @("lyncfe01", "lyncfe02", "lyncfe03")

foreach ($Server in $Servers) {
    Invoke-Command -ComputerName $Server -FilePath "C:\Scripts\Get-LyncServiceStatus.ps1" -ArgumentList @{
        ReportPath = "C:\Reports\${Server}_Service_Status.txt"
    }
}
```

### Automated Alerting
Alert on service failures:
```powershell
# Generate report
.\Get-LyncServiceStatus.ps1 -ReportPath "C:\Reports\Status.txt"

# Parse for stopped services
$report = Get-Content "C:\Reports\Status.txt"
$stoppedServices = $report | Select-String "Stopped.*Automatic"

# Send alert if issues found
if ($stoppedServices) {
    Send-MailMessage -To "admin@contoso.com" -Subject "Lync Service Alert" -Body "Services stopped: $stoppedServices"
}
```

## Service Reference Guide

### Core Lync Services

| Service Name | Display Name | Purpose | Critical |
|-------------|--------------|---------|----------|
| RTCSRV | Lync Server Front-End | Core communication service | Yes |
| RTCCLSAGT | Lync Server Centralized Logging Service Agent | Diagnostic logging | No |
| RTCATS | Lync Server Audio/Video Conferencing | A/V conferencing | Yes (if A/V used) |
| RTCDSS | Lync Server Storage Service | Data storage | Yes |
| RTCMCU | Lync Server Conferencing MCU | Multipoint conferencing | Yes (if conferencing used) |
| RTCASMCU | Lync Server Application Sharing MCU | Application sharing | Yes (if app sharing used) |
| RTCMEDSRV | Lync Server Mediation | PSTN gateway mediation | Yes (if voice enabled) |
| RTCSRVACC | Lync Server Audio Conferencing Server | Audio conferencing | Yes (if audio conf used) |

### Expected Service States

**Automatic + Running**: Normal operational state
**Automatic + Stopped**: Problem - service should be running
**Manual + Stopped**: Normal - service starts on demand
**Disabled + Stopped**: Normal - service intentionally disabled

## Related Scripts
- [Get-LyncHealthReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncHealthReport) - Comprehensive health diagnostics
- [Get-LyncInfrastructureReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncInfrastructureReport) - Infrastructure configuration
- [Get-ComprehensiveLyncReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveLyncReport) - Complete environment assessment

## Version History
- **v2.0** (2025-09-17): Enhanced service monitoring
  - Added process performance metrics
  - Enhanced service dependency mapping
  - Added customizable service patterns
  - Improved service status indicators
  - Added resource usage reporting
- **v1.0** (2024): Initial release
  - Basic service status reporting
  - Windows service enumeration

## See Also
- [Manage Services in Lync Server](https://docs.microsoft.com/en-us/skypeforbusiness/manage/services/)
- [Start and Stop Services](https://docs.microsoft.com/en-us/skypeforbusiness/manage/services/start-and-stop)
- [Configure Windows Services](https://docs.microsoft.com/en-us/windows/win32/services/)
