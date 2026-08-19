# Start-IntuneEnrollment.ps1

## Overview
Forces enrollment of Entra Joined (Azure AD Joined) Windows devices into Microsoft Intune using the current user's authentication context. This script is designed for scenarios where devices are Azure AD Joined but not automatically enrolled in Intune, or when re-enrollment is required.

The script uses Windows MDM enrollment protocols and the DeviceEnroller CSP to perform enrollment without requiring user interaction, leveraging existing Entra Join authentication for seamless device management enrollment.

## Features
- **Intelligent Enrollment Detection**: 3-tiered detection using Registry, OMADM, and dsregcmd
- **Automatic Re-enrollment**: Force re-enrollment even if device appears enrolled
- **Enrollment Validation**: Verifies successful enrollment before completing
- **Policy Synchronization**: Optional immediate sync after enrollment
- **Detailed Logging**: Comprehensive logging to file and console
- **GitHub Execution Support**: Can be run directly from GitHub repository
- **Progress Tracking**: Real-time status updates during enrollment process

## Prerequisites

### System Requirements
- **Windows 10 1809 or later** or **Windows 11**
- **Entra Joined** (Azure AD Joined) device
- **Administrator privileges** required
- **Internet connectivity** to Intune service endpoints

### Required Endpoints
The device must be able to reach:
- `enrollment.manage.microsoft.com`
- `portal.manage.microsoft.com`
- `login.microsoftonline.com`

### Enrollment Prerequisites
- Device must already be Entra Joined (check with `dsregcmd /status`)
- Intune MDM auto-enrollment must be configured in Azure AD
- User must have appropriate Intune licenses

## Parameters

### Optional Parameters

#### -ForceReenroll
Forces re-enrollment even if the device is already enrolled in Intune.

**Type**: Switch  
**Default**: False  
**Use Case**: Troubleshooting enrollment issues, resetting policy application

#### -SyncAfterEnroll
Automatically triggers an Intune device sync after successful enrollment.

**Type**: Switch  
**Default**: False  
**Benefits**: Speeds up initial policy application, immediately downloads configurations

#### -LogPath
Path to write detailed log file.

**Type**: String  
**Default**: `C:\ProgramData\Intune\Logs\Enrollment_[timestamp].log`  
**Example**: `"C:\Logs\IntuneEnroll.log"`

#### -WaitForSync
Waits for the initial sync to complete before exiting.

**Type**: Switch  
**Default**: False  
**Timeout**: 5 minutes  
**Use Case**: Automation scenarios where you need to ensure policies are applied

#### -NoRestart
Prevents automatic restart prompt after enrollment.

**Type**: Switch  
**Default**: False (will prompt if restart needed)  
**Use Case**: During business hours or when restart must be scheduled separately

## Usage Examples

### Example 1: Basic Enrollment Check
```powershell
.\Start-IntuneEnrollment.ps1
```
Checks current enrollment status and enrolls the device if not already enrolled.

### Example 2: Force Re-enrollment with Sync
```powershell
.\Start-IntuneEnrollment.ps1 -ForceReenroll -SyncAfterEnroll
```
Forces re-enrollment even if already enrolled, then triggers immediate policy sync.

### Example 3: Enrollment with Sync Wait
```powershell
.\Start-IntuneEnrollment.ps1 -SyncAfterEnroll -WaitForSync
```
Enrolls device, triggers sync, and waits up to 5 minutes for sync to complete.

### Example 4: Custom Log Location
```powershell
.\Start-IntuneEnrollment.ps1 -LogPath "C:\Logs\IntuneEnroll.log" -NoRestart
```
Enrolls device with custom log location and prevents automatic restart prompt.

### Example 5: Run Directly from GitHub (Basic)
```powershell
iex "& {$(irm https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1)}"
```
Downloads and executes the script directly from GitHub repository.

### Example 6: Run from GitHub with Parameters
```powershell
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1"
Invoke-Expression "& {$(Invoke-RestMethod $url)} -ForceReenroll -SyncAfterEnroll"
```
Runs script from GitHub with force re-enrollment and sync.

### Example 7: Remote Execution via Intune
```powershell
# Create Intune Remediation Script or Win32 app
$script = @"
Set-ExecutionPolicy Bypass -Scope Process -Force
`$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1"
Invoke-Expression "& {`$(Invoke-RestMethod `$url)} -SyncAfterEnroll -NoRestart"
"@
$script | Out-File -FilePath "C:\ProgramData\Intune\Scripts\EnrollDevice.ps1" -Encoding UTF8
```
Package for Intune deployment to multiple devices.

## Execution Workflow

### Phase 1: Prerequisites Check
1. Verifies administrator privileges
2. Checks Windows version compatibility
3. Validates Entra Join status using `dsregcmd`
4. Creates log directory if needed

### Phase 2: Enrollment Status Detection
Uses 3-tiered detection approach:

**Method 1: Registry Enrollment Keys**
- Checks `HKLM:\SOFTWARE\Microsoft\Enrollments\*`
- Looks for `EnrollmentState = 1` (active enrollment)
- Validates `ProviderID` matches Intune patterns

**Method 2: OMADM Accounts**
- Checks `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\*`
- Verifies active MDM accounts

**Method 3: dsregcmd Parsing**
- Runs `dsregcmd /status`
- Parses `MdmUrl` and enrollment state
- Cross-references with registry data

### Phase 3: Enrollment/Re-enrollment
If not enrolled or `-ForceReenroll` specified:
1. **Remove Existing Enrollment** (if present)
   - Deletes registry keys from Enrollments
   - Removes OMADM account entries
   - Cleans up leftover enrollment artifacts
   - Stops related services if needed

2. **Trigger New Enrollment**
   - Uses `DeviceEnroller.exe` with MDM enrollment type
   - Leverages existing Azure AD authentication
   - Monitors enrollment process
   - Validates successful completion

### Phase 4: Validation & Sync
1. Re-checks enrollment status using detection methods
2. Optionally triggers device sync (if `-SyncAfterEnroll`)
3. Waits for sync completion (if `-WaitForSync`)
4. Reports final enrollment state

### Phase 5: Completion
1. Displays enrollment summary
2. Shows error and warning counts
3. Prompts for restart if needed (unless `-NoRestart`)
4. Writes completion status to log

## Detection Logic Details

### EnrollmentState Values
- **0**: Not enrolled
- **1**: Enrolled and active
- **2**: Enrollment pending
- **3**: Enrollment failed

### Provider ID Patterns
Script recognizes these Intune provider IDs:
- `MS DM Server`
- `MS DM Server 2`
- `Microsoft Intune`

### dsregcmd Validation
Checks for:
```
DomainJoined : No
AzureAdJoined : Yes
EnterpriseJoined : No
MdmUrl : https://enrollment.manage.microsoft.com/...
```

## Output

### Console Output
Color-coded status messages:
- ✅ **Green**: Success messages
- ❌ **Red**: Error messages
- ⚠️ **Yellow**: Warning messages
- **Cyan**: Informational messages

### Log File Format
```
[2026-01-05 14:30:15] INFO: Starting Intune enrollment check...
[2026-01-05 14:30:16] INFO: Device is Azure AD Joined
[2026-01-05 14:30:17] SUCCESS: Device is enrolled in Intune
[2026-01-05 14:30:17] COMPLETE: Enrollment verification complete
```

### Exit Codes
- **0**: Success (enrolled or already enrolled)
- **1**: Error (enrollment failed or prerequisites not met)
- **2**: Warning (enrolled but with issues)

## Common Issues & Troubleshooting

### Issue: "Not running as Administrator"
**Cause**: Script requires elevated privileges

**Solution**:
```powershell
# Right-click PowerShell and select "Run as Administrator"
# Or from elevated prompt:
Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File .\Start-IntuneEnrollment.ps1" -Verb RunAs
```

### Issue: "Device is not Azure AD Joined"
**Cause**: Device must be Entra Joined before Intune enrollment

**Solution**:
```powershell
# Check join status
dsregcmd /status

# Join device to Azure AD first
Settings > Accounts > Access work or school > Connect > Join this device to Azure Active Directory
```

### Issue: "Enrollment failed - 0x80180002b"
**Cause**: MDM auto-enrollment not configured in Azure AD or user lacks license

**Solution**:
1. Verify Azure AD > Mobility (MDM and MAM) > Microsoft Intune is configured
2. Ensure "MDM user scope" is set to "All" or includes this user
3. Verify user has appropriate Intune license

### Issue: "The operation was blocked"
**Cause**: Existing enrollment artifacts preventing new enrollment

**Solution**:
```powershell
# Use force re-enrollment
.\Start-IntuneEnrollment.ps1 -ForceReenroll
```

### Issue: "Cannot reach Intune enrollment endpoints"
**Cause**: Firewall or proxy blocking required endpoints

**Solution**:
```powershell
# Test connectivity
Test-NetConnection enrollment.manage.microsoft.com -Port 443
Test-NetConnection portal.manage.microsoft.com -Port 443

# Configure proxy if needed
netsh winhttp set proxy proxy-server="proxy.contoso.com:8080"
```

### Issue: Script shows "enrolled" but portal shows "not compliant"
**Cause**: Enrollment succeeded but policies haven't applied yet

**Solution**:
```powershell
# Trigger immediate sync
.\Start-IntuneEnrollment.ps1 -SyncAfterEnroll -WaitForSync

# Or manually sync from Settings
Settings > Accounts > Access work or school > [Your org] > Info > Sync
```

### Issue: Enrollment succeeds but policies not applying
**Cause**: Sync required after enrollment

**Solution**: Always use `-SyncAfterEnroll` parameter for immediate policy application

## Automation Scenarios

### Intune Remediation Script
**Detection Script**:
```powershell
$enrolled = Test-Path "HKLM:\SOFTWARE\Microsoft\Enrollments\*\MS DM Server"
if ($enrolled) {
    Write-Output "Compliant"
    exit 0
} else {
    Write-Output "Not Compliant"
    exit 1
}
```

**Remediation Script**:
```powershell
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1"
Invoke-Expression "& {$(Invoke-RestMethod $url)} -SyncAfterEnroll -NoRestart"
```

### Scheduled Task (For Devices Not Yet Enrolled)
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"iex '& {`$(irm https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1)} -SyncAfterEnroll'`""

$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "Intune Auto-Enrollment" -Action $action -Trigger $trigger -Principal $principal
```

### GPO Startup Script
```powershell
# Save to startup scripts location
$scriptPath = "C:\Windows\SYSVOL\domain\scripts\IntuneEnroll.ps1"
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1"
Invoke-WebRequest -Uri $url -OutFile $scriptPath

# Configure in GPO:
# Computer Configuration > Windows Settings > Scripts > Startup > PowerShell Scripts
# Add: C:\Windows\SYSVOL\domain\scripts\IntuneEnroll.ps1 -SyncAfterEnroll -NoRestart
```

## Security Considerations

### Execution Policy
Script requires bypass or unrestricted execution policy for remote execution:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### Permissions Required
- **Local Administrator**: Required for registry modifications and service operations
- **Intune License**: User must have appropriate license assigned
- **Azure AD Join**: Device must be joined to Azure AD/Entra

### Network Security
- Script communicates with Microsoft Intune cloud services
- All communication uses HTTPS (port 443)
- No credentials are stored or transmitted by the script
- Leverages existing Azure AD device authentication

## Related Scripts
- [Start-ReEnrollWithPackage.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/docs/scripts/Intune/.prep/Start-ReEnrollWithPackage.ps1) - Re-enrollment using provisioning package (customer-specific)
- [Set-DeviceName.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Set-DeviceName) - Intune device naming script
- [Get-IntuneAppPolicies.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-IntuneAppPolicies) - Intune app policy assessment

## Version History
- **v1.0** (2026-01-02): Initial release
  - 3-tiered enrollment detection (Registry, OMADM, dsregcmd)
  - Force re-enrollment capability
  - GitHub direct execution support
  - Comprehensive logging and validation
  - Policy sync and wait functionality

## See Also
- [Microsoft Docs: Windows Enrollment Methods](https://docs.microsoft.com/en-us/mem/intune/enrollment/windows-enrollment-methods)
- [DeviceEnroller CSP](https://docs.microsoft.com/en-us/windows/client-management/mdm/deviceenroller-csp)
- [Azure AD Join Documentation](https://docs.microsoft.com/en-us/azure/active-directory/devices/azureadjoin-plan)
- [Intune Troubleshooting](https://docs.microsoft.com/en-us/mem/intune/fundamentals/help-desk-operators)
