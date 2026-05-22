# Client Computer Scripts

PowerShell scripts for configuring and managing Windows client machines, including VPN setup, software configuration, and endpoint management tasks.

---

## Scripts

| Script | Description |
|--------|-------------|
| [Set-FortinetVPNRegistry.ps1](Set-FortinetVPNRegistry.ps1) | Pre-configures FortiClient SSL VPN tunnel registry entries on a Windows client. |
| [Set-WHBRegistry.ps1](Set-WHBRegistry.ps1) | Enables Windows Hello for Business and Biometrics registry keys. |
| [Remove-BioDB.ps1](Remove-BioDB.ps1) | Resets the Windows Biometric Database by removing all .dat files and restarting the service. |

---

## Prerequisites

- PowerShell 5.1 or later
- **Administrator privileges** — all scripts in this folder write to `HKLM` or perform system-level changes
- Target software (e.g., FortiClient) installed on the endpoint before running configuration scripts

---

## Quick Start

### Configure FortiClient SSL VPN

```powershell
# Run as Administrator
.\Set-FortinetVPNRegistry.ps1

# With username pre-populated
.\Set-FortinetVPNRegistry.ps1 -Username "jdoe@contoso.com"
```

---

## Deployment Notes

These scripts are designed to be run locally on each client machine or deployed via:
- **Intune / MEM** — as a PowerShell script deployment targeting a device group
- **Group Policy** — via a startup/logon script
- **RMM tools** — as a remote script execution task

For Intune deployment, ensure the script is configured to run in **system context** so it has the required HKLM write permissions.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Access is denied` writing to HKLM | Run PowerShell as Administrator or deploy via Intune system context |
| VPN tunnel not appearing in FortiClient | Restart FortiClient after the registry entries are created |
| Script reports entries already exist | The tunnel was previously configured — no action needed |

---

## Related Documentation

- [Wiki: Set-FortinetVPNRegistry](../../docs/wiki/Client%20Computer/Set-FortinetVPNRegistry.md)
- [Wiki: Set-WHBRegistry](../../docs/wiki/Client%20Computer/Set-WHBRegistry.md)
- [Wiki: Remove-BioDB](../../docs/wiki/Client%20Computer/Remove-BioDB.md)
- [FortiClient Administration Guide](https://docs.fortinet.com/document/forticlient/latest/administration-guide)
