# Intune Management Scripts

PowerShell scripts for Microsoft Intune device management, enrollment, configuration, and assessment.

## Available Scripts

### Device Enrollment

#### [Start-IntuneEnrollment.ps1](Start-IntuneEnrollment.ps1)
**Purpose**: Force enrollment of Entra Joined devices into Microsoft Intune

**Features**:
- 3-tiered enrollment detection (Registry, OMADM, dsregcmd)
- Force re-enrollment capability
- Automatic policy sync
- GitHub direct execution support
- Comprehensive logging

**Quick Start**:
```powershell
.\Start-IntuneEnrollment.ps1
```

**Documentation**: [Full Documentation](../../docs/wiki/Intune/Start-IntuneEnrollment.md)

**Typical Use Cases**:
- Enrolling Azure AD Joined devices that aren't auto-enrolling
- Re-enrolling devices after policy issues
- Bulk enrollment via Intune remediation scripts
- Remote enrollment via GitHub URL execution

---

### Device Configuration

#### [Set-DeviceName.ps1](Set-DeviceName.ps1)
**Purpose**: Set or rename Intune-managed device names

**Quick Start**:
```powershell
.\Set-DeviceName.ps1 -NewName "LAPTOP-001"
```

**Typical Use Cases**:
- Standardizing device naming conventions
- Renaming devices after deployment
- Bulk renaming via Intune scripts

---

### Assessment

#### [Get-IntuneAppPolicies.ps1](Assessment/Get-IntuneAppPolicies.ps1)
**Purpose**: Export Intune application protection policies

**Quick Start**:
```powershell
.\Get-IntuneAppPolicies.ps1
```

**Typical Use Cases**:
- App policy documentation
- Compliance auditing
- Pre-migration assessment

---

## Prerequisites

### All Scripts
- **PowerShell 5.1 or later**
- **Microsoft.Graph modules** (auto-installed by scripts when needed)
- **Appropriate Intune permissions**

### Enrollment Scripts
- **Administrator privileges** on target device
- **Entra Joined device** (Azure AD Joined)
- **Internet connectivity** to Intune endpoints

### Configuration Scripts
- **Intune Administrator role** or higher
- **Device must be enrolled** in Intune

## Common Permissions Required

### For Enrollment Operations
- Local Administrator on device
- Intune license assigned to user

### For Assessment/Reporting
- **Graph API Permissions**:
  - `DeviceManagementConfiguration.Read.All`
  - `DeviceManagementApps.Read.All`
  - `Device.Read.All`

- **Admin Roles**:
  - Intune Administrator
  - Global Reader
  - Cloud Device Administrator

## Quick Start Guide

### 1. Enroll Device into Intune
```powershell
# Basic enrollment
.\Start-IntuneEnrollment.ps1

# Force re-enrollment with sync
.\Start-IntuneEnrollment.ps1 -ForceReenroll -SyncAfterEnroll

# Run from GitHub (no download needed)
iex "& {$(irm https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1)}"
```

### 2. Rename Device
```powershell
.\Set-DeviceName.ps1 -NewName "DESKTOP-HR-001"
```

### 3. Export App Policies
```powershell
cd Assessment
.\Get-IntuneAppPolicies.ps1
```

## Common Troubleshooting

### "Access Denied" or "Not Authorized"
**Solution**: Verify you have appropriate permissions:
```powershell
# Check if module installed
Get-Module Microsoft.Graph.Intune -ListAvailable

# Connect with required scopes
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All", "DeviceManagementApps.ReadWrite.All"
```

### "Device not Azure AD Joined"
**Solution**: Enroll device in Azure AD first:
```powershell
# Check current join status
dsregcmd /status

# Join to Azure AD
# Settings > Accounts > Access work or school > Connect > Join this device to Azure Active Directory
```

### Enrollment fails with 0x80180002b
**Solution**: 
1. Verify MDM auto-enrollment configured in Azure AD
2. Check user has Intune license
3. Ensure device can reach Intune endpoints

### Script execution blocked
**Solution**:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

## Output Locations

### Default Output Directories
- **Enrollment Logs**: `C:\ProgramData\Intune\Logs\`
- **Assessment Reports**: Current directory
- **CSV Exports**: Current directory

### File Naming Convention
**Pattern**: `{Category}_{Type}_{YYYYMMDD_HHmmss}.{ext}`

**Examples**:
- `Enrollment_20260105_143052.log`
- `IntuneAppPolicies_20260105_143052.csv`

## Automation Examples

### Intune Remediation Script for Auto-Enrollment
**Detection**:
```powershell
$enrolled = Test-Path "HKLM:\SOFTWARE\Microsoft\Enrollments\*\MS DM Server"
if ($enrolled) { exit 0 } else { exit 1 }
```

**Remediation**:
```powershell
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1"
Invoke-Expression "& {$(Invoke-RestMethod $url)} -SyncAfterEnroll -NoRestart"
```

### Scheduled Device Naming
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Scripts\Set-DeviceName.ps1 -NewName 'DEVICE-$env:USERNAME'"
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "SYSTEM"
Register-ScheduledTask -TaskName "Set Intune Device Name" -Action $action -Trigger $trigger
```

## Best Practices

### Enrollment
1. ✅ Always run enrollment scripts as Administrator
2. ✅ Use `-SyncAfterEnroll` for immediate policy application
3. ✅ Test enrollment on single device before bulk deployment
4. ✅ Monitor enrollment logs for troubleshooting
5. ✅ Verify device shows as compliant in Intune portal after enrollment

### Device Management
1. ✅ Use consistent naming conventions
2. ✅ Document custom configurations
3. ✅ Test scripts in pilot group first
4. ✅ Use Intune remediation scripts for ongoing compliance
5. ✅ Monitor script execution results in Intune portal

### Security
1. ✅ Store scripts in secure location
2. ✅ Use least-privilege service accounts for automation
3. ✅ Audit enrollment activities regularly
4. ✅ Implement conditional access policies
5. ✅ Review device compliance policies regularly

## Related Documentation

- [Start-IntuneEnrollment.ps1 Full Documentation](../../docs/wiki/Intune/Start-IntuneEnrollment.md)
- [Microsoft Intune Documentation](https://docs.microsoft.com/en-us/mem/intune/)
- [Azure AD Join Documentation](https://docs.microsoft.com/en-us/azure/active-directory/devices/azureadjoin-plan)
- [DeviceEnroller CSP](https://docs.microsoft.com/en-us/windows/client-management/mdm/deviceenroller-csp)

## Support

For issues, questions, or contributions:
- GitHub Issues: [PowerShellEveryting Issues](https://github.com/Managed-Solution-LLC/PowerShellEveryting/issues)
- Wiki: [Project Wiki](https://github.com/Managed-Solution-LLC/PowerShellEveryting/wiki)

## Version History

- **2026-01-02**: Added Start-IntuneEnrollment.ps1 - Force enrollment with 3-tiered detection and GitHub execution support
- **2025**: Initial Intune management scripts
