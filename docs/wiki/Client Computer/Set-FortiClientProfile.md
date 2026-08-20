# Set-FortiClientProfile

## Overview

Imports an encrypted FortiClient VPN configuration profile onto a target machine using FCConfig.exe. Designed for deployment via Intune, SCCM, or manual execution.

## Prerequisites

- FortiClient installed with `FCConfig.exe` present
- Administrator privileges (required to stop/start FortiClient services)
- Network access to the hosted configuration file URL

## Parameters

### Required

| Parameter | Description |
|-----------|-------------|
| **ConfigUrl** | URL where the encrypted `.conf` file is hosted (Azure Blob, file share, web server) |
| **ConfigPassword** | Password that was set when exporting the configuration |

### Optional

| Parameter | Default | Description |
|-----------|---------|-------------|
| **FCConfigPath** | `C:\Program Files\Fortinet\FortiClient\FCConfig.exe` | Path to FCConfig.exe |
| **LogFile** | `$env:TEMP\FCConfig-Import.log` | Path for the import log |

## Usage Examples

### Basic Import

```powershell
.\Set-FortiClientProfile.ps1 -ConfigUrl "https://storage.blob.core.windows.net/configs/vpnconfig.conf" -ConfigPassword "ExportPass123"
```

### Custom Log Location

```powershell
.\Set-FortiClientProfile.ps1 -ConfigUrl "\\fileserver\share\vpnconfig.conf" -ConfigPassword "ExportPass123" -LogFile "C:\Logs\fc-import.log"
```

## Exporting a FortiClient Configuration

Before using this script you must export the VPN configuration from a reference machine.

### Option 1: GUI Export

1. Open FortiClient and go to **Settings**.
2. Under **System**, click **Backup**.
3. Select the file destination.
4. Enter a password to save the file in an encrypted format.
5. Click **OK**.

### Option 2: CLI Export (run as Administrator)

```powershell
& "C:\Program Files\Fortinet\FortiClient\FCConfig.exe" -m all -f "C:\Temp\vpnconfig.conf" -o export -i 1 -p "YourPassword"
```

### Hosting the Configuration

After export, host the `.conf` file somewhere accessible to target endpoints:

- **Azure Blob Storage** with a SAS token URL
- **SMB file share** accessible from the endpoint network
- **Web server** with HTTPS

## What the Script Does

1. Validates that FCConfig.exe exists at the specified path.
2. Downloads the configuration file from the URL to a temp location.
3. Grants read permissions to Authenticated Users on the temp file.
4. Stops all FortiClient processes and services.
5. Waits 3 seconds, then restarts FortiClient services.
6. Runs `FCConfig.exe` to import the configuration.
7. Logs the result and cleans up the temp file.

## FCConfig Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 5 | Invalid configuration file (wrong password or corrupt) |

## Troubleshooting

### FCConfig.exe not found

Verify FortiClient is installed and check the install path. Non-standard installs may require the `-FCConfigPath` parameter.

### Download failed

- Confirm the URL is accessible from the endpoint
- Check proxy/firewall rules
- For blob storage, verify the SAS token hasn't expired

### Exit code 5

The password provided doesn't match the one used during export, or the file is corrupt. Re-export the configuration and try again.

## Version History

- **v2.0** (2026-08-20): Parameterized script, added comment-based help and documentation
- **v1.0**: Initial hardcoded implementation

## See Also

- [Set-FortinetVPNRegistry](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Set-FortinetVPNRegistry)
- [Fortinet FortiClient Documentation](https://docs.fortinet.com/document/forticlient/)
