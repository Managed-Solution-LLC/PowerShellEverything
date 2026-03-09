<#
.SYNOPSIS
    Configures FortiClient SSL VPN tunnel registry entries on a Windows client machine.

.DESCRIPTION
    Creates the required registry entries under HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels
    to pre-configure a FortiClient SSL VPN tunnel. If the tunnel entry already exists, the script
    exits without making changes.

    Configured settings include:
    - VPN tunnel name and description
    - Server address and SSL port
    - SSO (SAML) authentication enabled
    - Server certificate validation
    - Username pre-population (optional)
    - Password remember prompt visibility

    Must be run with administrative privileges to write to HKLM.

.PARAMETER Username
    Optional. Pre-populates the username field in the FortiClient SSL VPN tunnel.
    Defaults to an empty string if not specified.

.EXAMPLE
    .\Set-FortinetVPNRegistry.ps1
    Creates the SSL VPN tunnel registry entries with no pre-populated username.

.EXAMPLE
    .\Set-FortinetVPNRegistry.ps1 -Username "jdoe@contoso.com"
    Creates the SSL VPN tunnel registry entries with the username pre-populated.

.NOTES
    Author: Managed Solution LLC
    Date: 2026-03-09
    Version: 1.0

    Requirements:
    - PowerShell 5.1 or later
    - Must be run as Administrator (requires HKLM write access)
    - FortiClient must be installed on the target machine

    Returns exit code 0 on success, 1 on error.

.LINK
    https://docs.fortinet.com/document/forticlient/latest/administration-guide
#>
param(
    [Parameter(Mandatory = $false, HelpMessage = "Pre-populate the VPN username field (e.g., user@contoso.com)")]
    [string]$Username = ""
)

$vpnName = "VPN Name"
$vpnDescription = "SSL VPN"
$vpnServer = "vpn.server.com"
$sslPort = 10443
# Check if the FortiClient SSL VPN tunnel already exists
if ((Test-Path -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$($vpnName)") -ne $true) {
    try {
        # PowerShell script to create FortiClient SSL VPN registry entries for "$vpnName"
        # Run this script with administrative privileges

        # Base registry path for SSL VPN
        $basePath = "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn\Tunnels\$vpnName"

        # Create main registry key
        New-Item -Path $basePath -Force | Out-Null

        # Set SSL VPN tunnel values
        New-ItemProperty -Path $basePath -Name "Description"            -Value $vpnDescription             -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $basePath -Name "Server"                 -Value "$($vpnServer):$($sslPort)" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $basePath -Name "Username"               -Value $Username                   -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $basePath -Name "promptcertificate"      -Value 0                           -PropertyType DWord  -Force | Out-Null
        New-ItemProperty -Path $basePath -Name "ServerCert"             -Value "check"                     -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $basePath -Name "sso_enabled"            -Value 1                           -PropertyType DWord  -Force | Out-Null
        New-ItemProperty -Path $basePath -Name "use_external_browser"   -Value 0                           -PropertyType DWord  -Force | Out-Null
        New-ItemProperty -Path $basePath -Name "single_user"            -Value 0                           -PropertyType DWord  -Force | Out-Null
        New-ItemProperty -Path $basePath -Name "show_remember_password" -Value 1                           -PropertyType DWord  -Force | Out-Null
        New-ItemProperty -Path $basePath -Name "Flags"                  -Value 4                           -PropertyType DWord  -Force | Out-Null

        Write-Host "FortiClient SSL VPN '$vpnName' registry entries created successfully."
        return 0
    } catch {
        Write-Host "Error creating registry entries: $_"
        return 1
    }

} else {
    Write-Host "FortiClient SSL VPN '$vpnName' registry entries already exist."
    return 0
}