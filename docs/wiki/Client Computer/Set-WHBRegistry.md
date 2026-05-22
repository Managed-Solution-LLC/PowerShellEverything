# Set-WHBRegistry

## Overview

Enables Windows Hello for Business and Biometrics by setting the required registry keys under `HKLM:\SOFTWARE\Policies\Microsoft\`. This prepares Windows 10/11 endpoints for biometric authentication including fingerprint and facial recognition, and allows domain users to log on using biometrics.

---

## Features

- Enables Windows Hello for Business (`PassportForWork`)
- Enables Biometrics and domain logon via biometrics
- Enables Facial & Fingerprint features
- Creates registry paths if they don't already exist
- Suitable for Intune, Group Policy, or RMM deployment

---

## Prerequisites

- PowerShell 5.1 or later
- **Must be run as Administrator** (writes to `HKLM`)
- Windows 10/11

---

## Parameters

This script has no parameters.

---

## Usage Examples

### Example 1: Run locally as Administrator

```powershell
.\Set-WHBRegistry.ps1
```

Sets all Windows Hello for Business and Biometrics registry keys.

---

## Registry Keys Set

| Path | Name | Value |
|------|------|-------|
| `HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork` | `Enabled` | `1` (DWORD) |
| `HKLM:\SOFTWARE\Policies\Microsoft\Biometrics` | `Enabled` | `1` (DWORD) |
| `HKLM:\SOFTWARE\Policies\Microsoft\Biometrics` | `AllowDomainLogon` | `1` (DWORD) |
| `HKLM:\SOFTWARE\Policies\Microsoft\Biometrics\FacialFeatures` | `Enabled` | `1` (DWORD) |

---

## Output

Console output with color-coded status messages confirming each registry key was set.

---

## Common Issues & Troubleshooting

| Issue | Solution |
|-------|----------|
| `Access is denied` | Run PowerShell as Administrator or deploy via Intune system context |
| Settings overridden by Group Policy | Check for conflicting GPOs in `rsop.msc` |
| Biometrics still not available | Ensure biometric hardware is present and drivers are installed |

---

## Related Scripts

- [Remove-BioDB.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Client%20Computer/Remove-BioDB.ps1) — Resets the Windows Biometric Database

---

## Version History

- **v1.0** (2025-05-21): Initial release — Sets WHB and Biometrics registry keys

---

## See Also

- [Windows Hello for Business Documentation](https://docs.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/)
- [Biometrics Group Policy Settings](https://docs.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/hello-manage-in-organization)
