# Set-FortinetVPNRegistry

## Overview

Pre-configures a FortiClient SSL VPN tunnel by writing the required registry entries to `HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\`. This allows IT administrators to deploy a standardized VPN configuration to Windows endpoints before users launch FortiClient, ensuring the correct tunnel is available without manual setup.

If the tunnel entry already exists in the registry, the script exits gracefully without overwriting the existing configuration.

---

## Features

- Creates all required FortiClient SSL VPN tunnel registry values in a single operation
- Idempotent — safe to run multiple times; skips if tunnel already exists
- Supports optional username pre-population for a smoother user experience
- SSO/SAML authentication enabled by default
- Server certificate validation enforced (`check` mode)
- Suitable for Intune, Group Policy, or RMM deployment

---

## Prerequisites

- PowerShell 5.1 or later
- **Must be run as Administrator** (writes to `HKLM`)
- FortiClient installed on the target machine

---

## Parameters

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Username` | String | `""` | Pre-populates the username field in the FortiClient VPN tunnel UI. Leave blank to require the user to enter it. |

---

## Usage Examples

### Example 1: Basic — No username pre-population

```powershell
.\Set-FortinetVPNRegistry.ps1
```

Creates the SSL VPN tunnel registry entries. The user will need to enter their username in FortiClient.

### Example 2: Pre-populate username

```powershell
.\Set-FortinetVPNRegistry.ps1 -Username "jdoe@contoso.com"
```

Creates the tunnel entries and pre-fills the username field in FortiClient.

### Example 3: Deploy via Intune (PowerShell script)

Upload `Set-FortinetVPNRegistry.ps1` to **Intune > Devices > Scripts** with:
- **Run this script using the logged-on credentials**: No (run as System)
- **Enforce script signature check**: No (or Yes if script is signed)
- **Run script in 64-bit PowerShell**: Yes

---

## Registry Values Created

All values are written to:
`HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\<VPN Name>`

| Registry Value | Type | Description |
|----------------|------|-------------|
| `Description` | String | Human-readable tunnel description |
| `Server` | String | VPN server address and SSL port (`server:port`) |
| `Username` | String | Pre-populated username (blank by default) |
| `promptcertificate` | DWORD | `0` — Do not prompt for client certificate |
| `ServerCert` | String | `check` — Enforce server certificate validation |
| `sso_enabled` | DWORD | `1` — Enable SSO/SAML authentication |
| `use_external_browser` | DWORD | `0` — Use FortiClient internal browser for SAML |
| `single_user` | DWORD | `0` — Allow multiple users |
| `show_remember_password` | DWORD | `1` — Show the "Remember Password" option |
| `Flags` | DWORD | `4` — Internal FortiClient tunnel flags |

---

## Output

Console messages only. No files are generated.

| Message | Meaning |
|---------|---------|
| `FortiClient SSL VPN '<name>' registry entries created successfully.` | Entries written successfully (exit code 0) |
| `FortiClient SSL VPN '<name>' registry entries already exist.` | Tunnel already configured — no changes made (exit code 0) |
| `Error creating registry entries: <error>` | Write failed — check admin rights (exit code 1) |

---

## Customization

Before deploying, update the following variables at the top of the script to match your environment:

```powershell
$vpnName        = "VPN Name"        # Display name shown in FortiClient
$vpnDescription = "SSL VPN"         # Tunnel description
$vpnServer      = "vpn.server.com"  # Your VPN gateway hostname or IP
$sslPort        = 10443             # SSL VPN port (default FortiGate: 10443 or 443)
```

---

## Common Issues & Troubleshooting

### Access is denied

**Cause**: Script not running with Administrator privileges.
**Solution**: Right-click PowerShell → Run as Administrator, or deploy via Intune using System context.

### VPN tunnel not appearing in FortiClient

**Cause**: FortiClient reads registry at startup; changes made while it is running may not appear immediately.
**Solution**: Restart FortiClient after the script completes.

### Entries already exist but configuration is wrong

**Cause**: Script is idempotent and won't overwrite existing values.
**Solution**: Manually delete the registry key and re-run the script:

```powershell
Remove-Item -Path "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\<VPN Name>" -Recurse -Force
.\Set-FortinetVPNRegistry.ps1
```

---

## Version History

- **v1.0** (2026-03-09): Initial release — core registry configuration for FortiClient SSL VPN tunnel

---

## See Also

- [Client Computer Scripts README](../../scripts/Client%20Computer/README.md)
- [FortiClient Administration Guide](https://docs.fortinet.com/document/forticlient/latest/administration-guide)
- [Intune PowerShell Script Deployment](https://learn.microsoft.com/en-us/mem/intune/apps/intune-management-extension)
