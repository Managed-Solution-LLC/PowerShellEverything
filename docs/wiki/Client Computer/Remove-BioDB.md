# Remove-BioDB

## Overview

Resets the Windows Biometric Database by stopping the Windows Biometric Service, deleting all `.dat` files from `C:\Windows\System32\WinBioDatabase`, and restarting the service. This resolves fingerprint and facial recognition enrollment issues where biometric data has become corrupted or needs to be re-enrolled.

---

## Features

- Stops the Windows Biometric Service (`WbioSrvc`) safely
- Confirms the service is fully stopped before proceeding
- Removes all `.dat` biometric database files
- Restarts the service and verifies it's running
- Color-coded status output with error handling at each step

---

## Prerequisites

- PowerShell 5.1 or later
- **Must be run as Administrator** (stops system services and deletes system files)
- Windows 10/11

---

## Parameters

This script has no parameters.

---

## Usage Examples

### Example 1: Reset the biometric database

```powershell
.\Remove-BioDB.ps1
```

Stops the biometric service, clears all `.dat` files, and restarts the service.

---

## What It Does

1. **Stops** the Windows Biometric Service (`WbioSrvc`)
2. **Verifies** the service has stopped (exits with error if not)
3. **Deletes** all `.dat` files in `C:\Windows\System32\WinBioDatabase`
4. **Restarts** the Windows Biometric Service
5. **Confirms** the service is running again

---

## Output

Console output with color-coded status messages:
- Green checkmarks for successful operations
- Yellow warnings if no `.dat` files are found
- Red errors if the service fails to stop or start

---

## Common Issues & Troubleshooting

| Issue | Solution |
|-------|----------|
| `Access is denied` | Run PowerShell as Administrator |
| Service won't stop | Check for dependent services; try `Stop-Service WbioSrvc -Force` manually |
| No `.dat` files found | Database was already empty — no action needed |
| Service won't restart | Check Event Viewer for errors; verify biometric hardware is connected |
| Fingerprint still not working after reset | Re-enroll fingerprint in Settings > Accounts > Sign-in options |

---

## Related Scripts

- [Set-WHBRegistry.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Client%20Computer/Set-WHBRegistry.ps1) — Enables Windows Hello for Business registry keys

---

## Version History

- **v1.0** (2025-05-21): Initial release — Biometric database reset

---

## See Also

- [Windows Hello for Business Troubleshooting](https://docs.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/hello-errors-during-pin-creation)
- [Windows Biometric Service](https://docs.microsoft.com/en-us/windows/win32/secbiomet/biometric-service-api-portal)
