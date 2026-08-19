param(
    [string]$PSK
)

$PSK="EncLM bf03eb8d1922d6ea2e329ab21097f5391764f3387698cfbce9861cc2fd1f183fa479b07f038d142be7d629e8adfca19ac404e3f1cf6ea995cabb3ff3916787d721a46848dc4e8d68d025da1922569eb65d831fb6dd65bdc8642ad4ba2c702b5a62150503f58a6d31925dd1a28d5f41b90ba4de159d746d90f80874aa64200d7b3ee999d0a3304ab89ec1fc0e0aee2363f21d956786e49a4dabbcd8406fd0bce0fc438b7dbddaa1e0dbda3e79e8d854e2462dc8a0b01d0d66a1316bf2cdc0dc2ed602d66bcda00337ce3113edca8fde76124164760d52da5700b3732875d35c96b55a7cd5131908cd585fb05fb24153498186d86140012f4ab706238188c3db2cce3b4f118b7d70ac6e66182b65a0418b50acfda9dc31791b2e723f17729d6eb2a50effd982bf6ae66752750d943dee253dca815a1b5aa63857733cbef3b9346c90964ef77095f5455b3fd8edeefc3e12d10e8823ac77"

$vpnName = "MulFil IPsec VPN 2"
$vpnDescription = "IPSEC Client VPN 2"
$vpnServer = "20.237.154.136"
$scriptPath = $MyInvocation.MyCommand.Path


function Delete-Me {
    if (Test-Path -LiteralPath $script:scriptPath) {
        Remove-Item -LiteralPath $script:scriptPath -Force
        Write-Host "Script '$script:scriptPath' has been deleted." -ForegroundColor Green
    } else {
        Write-Host "Script '$script:scriptPath' not found." -ForegroundColor Yellow
    }
}

<#
User Authentication Type Options (UserAuth):
    "saml"     = SAML/SSO (default, uses ike_saml_port)
    "xauth"    = XAuth username/password only
    "cert"     = Certificate-based user auth
#>
$userAuth = "saml"  # SAML/SSO
$samlPort = 9443    # SAML listening port (only used when userAuth = "saml")

# =============================================================================
# Phase 1 (IKE) Settings
# =============================================================================

<#
Encryption Algorithm Options (Enc):
    1   = DES (insecure, not recommended)
    5   = 3DES (legacy)
    128 = AES-128
    192 = AES-192
    256 = AES-256
    13  = AES-128-GCM
    14  = AES-256-GCM
    30  = CHACHA20POLY1305
#>
$p1EncAlgorithm = 256 # AES-256

<#
Authentication/Hash Algorithm Options (Auth):
    1   = MD5 (insecure, not recommended)
    2   = SHA-1 (legacy)
    128 = SHA-256
    384 = SHA-384
    512 = SHA-512
#>
$p1AuthAlgorithm = 128  # SHA-256

<#
Diffie-Hellman Group Options (DHGroup) - BITMASK, combine values with addition:
    1    = Group 1  (768-bit MODP, insecure)
    2    = Group 2  (1024-bit MODP, legacy)
    4    = Group 5  (1536-bit MODP, legacy)
    8    = Group 14 (2048-bit MODP)
    16   = Group 15 (3072-bit MODP)
    32   = Group 16 (4096-bit MODP)
    64   = Group 17 (6144-bit MODP)
    128  = Group 18 (8192-bit MODP)
    256  = Group 19 (256-bit ECP)
    512  = Group 20 (384-bit ECP)
    1024 = Group 21 (521-bit ECP)
#>
$p1DHGroup = 8  # Group 14 only

<#
Key Lifetime (seconds):
    28800  = 8 hours
    43200  = 12 hours
    86400  = 24 hours (default)
    172800 = 48 hours
#>
$p1KeyLifetime = 86400  # 24 hours in seconds

<#
IKE Version Options (ikeversion):
    1 = IKEv1
    2 = IKEv2 (recommended)
#>
$p1IKEVersion = 2  # IKEv2

<#
Authentication Method Options (AuthMethod):
    1 = Pre-Shared Key (PSK)
    2 = Certificate (X.509)
    3 = EAP
#>
$p1AuthMethod = 1  # Pre-Shared Key

<#
Mode Options (Aggressive) - IKEv1 only, ignored when ikeversion = 2:
    0 = Main Mode (more secure, recommended for IKEv2)
    1 = Aggressive Mode (faster negotiation, exposes identity)
#>
$p1Aggressive = 1  # Aggressive Mode

<#
Transport Mode Options (transport_mode):
    0 = Tunnel Mode (standard site-to-site/remote access)
    1 = Transport Mode (host-to-host only)
    2 = Auto/Dialup
#>
$p1TransportMode = 2  # Auto/Dialup

# IKEv1/IKEv2 Proposal Settings (same option values as above Enc/Auth)
$p1EncAlgorithmV1 = 256  # AES-256 for IKEv1
$p1AuthAlgorithmV1 = 128  # SHA-256 for IKEv1
$p1EncAlgorithmV2 = 256  # AES-256 for IKEv2
$p1AuthAlgorithmV2 = 128  # SHA-256 for IKEv2

# Timeout Settings
$p1TimeoutInitial = 10  # Initial timeout in seconds
$p1TimeoutRetry = 5  # Retry timeout in seconds

# =============================================================================
# Phase 2 (IPsec SA) Settings
# =============================================================================

# P2 Encryption/Auth use the same option values as P1 (see above)
$p2EncAlgorithm = 256  # AES-256
$p2AuthAlgorithm = 128  # SHA-256
$p2DHGroup = 8          # Group 14 only (bitmask)

<#
Key Lifetime Type Options (KeyLifeType):
    0 = Seconds (time-based rekey)
    1 = Kilobytes (data-based rekey)
    2 = Both (rekey on whichever comes first)
#>
$p2KeyLifeType = 0  # Seconds

<#
Key Lifetime (seconds) for P2:
    1800   = 30 minutes
    3600   = 1 hour
    14400  = 4 hours
    28800  = 8 hours
    43200  = 12 hours (default)
    86400  = 24 hours
#>
$p2KeyLifeSec = 43200  # 12 hours

$p2KeyLifeKB = 5120  # Kilobytes (used when KeyLifeType = 1 or 2)

<#
VIP Type Options (VIPType):
    0 = No VIP (manual addressing)
    1 = DHCP
    2 = Mode Config / IKE Config (recommended for dialup)
#>
$p2VIPType = 2  # Mode Config

# =============================================================================
# Check if the FortiClient VPN is installed
if ((Test-Path -LiteralPath "HKLM:\SOFTWARE\Fortinet\FortiClient\IPSec\Tunnels\$($vpnName)") -ne $true) {
    try {
        # PowerShell script to create FortiClient VPN registry entries for "IPsec VPN"
        # Run this script with administrative privileges

        # Base registry path
        $basePath = "HKLM:\SOFTWARE\Fortinet\FortiClient\IPSec\Tunnels\$vpnName"

        # Create main registry key
        New-Item -Path $basePath -Force | Out-Null

        # Create P1 key and set values
        $p1Path = "$basePath\P1"
        New-Item -Path $p1Path -Force | Out-Null

        # Encrypt the PSK
        $encryptedPSK = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($PSK))

        # Set P1 values
        New-ItemProperty -Path $p1Path -Name "NatAliveFreq" -Value 5 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "PeerID" -Value "" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "Description" -Value $vpnDescription -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "RemoteGW" -Value $vpnServer -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "AuthKey" -Value $PSK -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "promptcertificate" -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "AuthMethod" -Value $p1AuthMethod -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "promptusername" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "XAuth" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "User" -Value "" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "failover_sslvpn_connection" -Value "" -PropertyType String -Force | Out-Null
        if ($userAuth -eq "saml") {
            New-ItemProperty -Path $p1Path -Name "sso_enabled" -Value 1 -PropertyType DWord -Force | Out-Null
            New-ItemProperty -Path $p1Path -Name "use_external_browser" -Value 1 -PropertyType DWord -Force | Out-Null
            New-ItemProperty -Path $p1Path -Name "ike_saml_port" -Value $samlPort -PropertyType DWord -Force | Out-Null
        } else {
            New-ItemProperty -Path $p1Path -Name "sso_enabled" -Value 0 -PropertyType DWord -Force | Out-Null
        }
        New-ItemProperty -Path $p1Path -Name "ikeversion" -Value $p1IKEVersion -PropertyType DWord -Force | Out-Null
        if ($p1IKEVersion -ne 2) {
            New-ItemProperty -Path $p1Path -Name "Aggressive" -Value $p1Aggressive -PropertyType DWord -Force | Out-Null
        }
        New-ItemProperty -Path $p1Path -Name "Modecfg" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "transport_mode" -Value $p1TransportMode -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "udp_port" -Value 500 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "tcp_port" -Value 500 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "KeyLife" -Value $p1KeyLifetime -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "LocalID" -Value "" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "DPD" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "Flag" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "EnableLocalLAN" -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "DHGroup" -Value $p1DHGroup -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p1Path -Name "RemoteGWSorted" -Value $vpnServer -PropertyType String -Force | Out-Null

        # Create P1\Proposals key
        $p1ProposalsPath = "$p1Path\Proposals"
        New-Item -Path $p1ProposalsPath -Force | Out-Null

        # Create P1\Proposals\p0 and p1
        $p0Path = "$p1ProposalsPath\p0"
        New-Item -Path $p0Path -Force | Out-Null
        New-ItemProperty -Path $p0Path -Name "Auth" -Value 256 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p0Path -Name "Enc" -Value 128 -PropertyType DWord -Force | Out-Null

        #$p1PropPath = "$p1ProposalsPath\p1"
        #New-Item -Path $p1PropPath -Force | Out-Null
        #New-ItemProperty -Path $p1PropPath -Name "Auth" -Value 256 -PropertyType DWord -Force | Out-Null
        #New-ItemProperty -Path $p1PropPath -Name "Enc" -Value 256 -PropertyType DWord -Force | Out-Null

        # Create P2 key and set values
        $p2Path = "$basePath\P2"
        New-Item -Path $p2Path -Force | Out-Null

        # Set P2 values
        New-ItemProperty -Path $p2Path -Name "VIPWinsServer" -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "DIP" -Value "0.0.0.0" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "DMASK" -Value "0.0.0.0" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "Options" -Value 69 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "VIPType" -Value $p2VIPType -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "VIPDnsServer" -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "VIPIP" -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "VIPMask" -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "DIP1" -Value "::/0" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "DMASK1" -Value "::/0" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "KeyLifeType" -Value $p2KeyLifeType -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "KeyLifeSec" -Value $p2KeyLifeSec -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "KeyLifeKB" -Value $p2KeyLifeKB -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p2Path -Name "DHGroup" -Value $p2DHGroup -PropertyType DWord -Force | Out-Null

        # Create P2\Proposals key
        $p2ProposalsPath = "$p2Path\Proposals"
        New-Item -Path $p2ProposalsPath -Force | Out-Null

        # Create P2\Proposals\p0 and p1
        $p0Path = "$p2ProposalsPath\p0"
        New-Item -Path $p0Path -Force | Out-Null
        New-ItemProperty -Path $p0Path -Name "Auth" -Value 256 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $p0Path -Name "Enc" -Value 128 -PropertyType DWord -Force | Out-Null

        #$p1PropPath = "$p2ProposalsPath\p1"
        #New-Item -Path $p1PropPath -Force | Out-Null
        #New-ItemProperty -Path $p1PropPath -Name "Auth" -Value 256 -PropertyType DWord -Force | Out-Null
        #New-ItemProperty -Path $p1PropPath -Name "Enc" -Value 128 -PropertyType DWord -Force | Out-Null

        Write-Host "✅ FortiClient IPsec VPN '$vpnName' registry entries created successfully." -ForegroundColor Green
        #Delete-Me
        return 0
    } catch {
        Write-Host "❌ Error creating registry entries: $_" -ForegroundColor Red
        return 1
    }

} else {
    Write-Host "FortiClient VPN '$vpnName' registry entries already exist." -ForegroundColor Yellow
    #Delete-Me
    return 0
}


