param(
    [string]$VpnName = "MulFil IPsec VPN"
)

# Expected configuration values
$expected = @{
    P1 = @{
        RemoteGW        = "20.237.154.136"
        AuthMethod      = 1        # PSK
        ikeversion      = 2        # IKEv2
        DHGroup         = 8        # Group 14
        KeyLife         = 86400    # 24 hours
        transport_mode  = 2        # Auto/Dialup
        Modecfg         = 1
        XAuth           = 1
        DPD             = 1
        sso_enabled     = 1
        use_external_browser = 1
        ike_saml_port   = 9443
        udp_port        = 500
        NatAliveFreq    = 5
        promptusername  = 1
    }
    P1Proposals = @{
        p0 = @{ Auth = 256; Enc = 128 }
    }
    P2 = @{
        DHGroup      = 8        # Group 14
        KeyLifeType  = 0        # Seconds
        KeyLifeSec   = 43200    # 12 hours
        KeyLifeKB    = 5120
        VIPType      = 2        # Mode Config
        Options      = 69
    }
    P2Proposals = @{
        p0 = @{ Auth = 256; Enc = 128 }
    }
}

$basePath = "HKLM:\SOFTWARE\Fortinet\FortiClient\IPSec\Tunnels\$VpnName"
$issues = @()

Write-Host "`n=== FortiClient IPsec VPN Config Check ===" -ForegroundColor Cyan
Write-Host "VPN Name: $VpnName`n"

# Check tunnel exists
if (-not (Test-Path $basePath)) {
    Write-Host "ERROR: VPN tunnel '$VpnName' not found in registry." -ForegroundColor Red
    Write-Host "Path checked: $basePath" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Tunnel registry key exists." -ForegroundColor Green

# Check P1 values
$p1Path = "$basePath\P1"
if (-not (Test-Path $p1Path)) {
    Write-Host "[FAIL] P1 key missing!" -ForegroundColor Red
    $issues += "P1 registry key does not exist"
} else {
    Write-Host "`n--- Phase 1 (IKE) Settings ---" -ForegroundColor Cyan
    foreach ($name in $expected.P1.Keys) {
        $actual = Get-ItemProperty -Path $p1Path -Name $name -ErrorAction SilentlyContinue
        if ($null -eq $actual) {
            Write-Host "  [MISSING] $name - expected: $($expected.P1[$name])" -ForegroundColor Red
            $issues += "P1.$name is missing (expected $($expected.P1[$name]))"
        } elseif ($actual.$name -ne $expected.P1[$name]) {
            Write-Host "  [MISMATCH] $name - expected: $($expected.P1[$name]), actual: $($actual.$name)" -ForegroundColor Yellow
            $issues += "P1.$name = $($actual.$name) (expected $($expected.P1[$name]))"
        } else {
            Write-Host "  [OK] $name = $($actual.$name)" -ForegroundColor Green
        }
    }

    # Check AuthKey is not empty
    $authKey = Get-ItemProperty -Path $p1Path -Name "AuthKey" -ErrorAction SilentlyContinue
    if ($null -eq $authKey -or [string]::IsNullOrWhiteSpace($authKey.AuthKey)) {
        Write-Host "  [FAIL] AuthKey (PSK) is empty or missing!" -ForegroundColor Red
        $issues += "P1.AuthKey (PSK) is empty or missing"
    } else {
        Write-Host "  [OK] AuthKey is set (length: $($authKey.AuthKey.Length))" -ForegroundColor Green
    }

    # Check P1 Proposals
    $p1ProposalsPath = "$p1Path\Proposals"
    if (-not (Test-Path $p1ProposalsPath)) {
        Write-Host "  [FAIL] P1\Proposals key missing!" -ForegroundColor Red
        $issues += "P1\Proposals registry key does not exist"
    } else {
        foreach ($prop in $expected.P1Proposals.Keys) {
            $propPath = "$p1ProposalsPath\$prop"
            if (-not (Test-Path $propPath)) {
                Write-Host "  [MISSING] P1 Proposal '$prop' missing" -ForegroundColor Red
                $issues += "P1\Proposals\$prop does not exist"
            } else {
                foreach ($val in $expected.P1Proposals[$prop].Keys) {
                    $actual = Get-ItemProperty -Path $propPath -Name $val -ErrorAction SilentlyContinue
                    if ($null -eq $actual) {
                        Write-Host "  [MISSING] P1\Proposals\$prop\$val" -ForegroundColor Red
                        $issues += "P1\Proposals\$prop.$val is missing"
                    } elseif ($actual.$val -ne $expected.P1Proposals[$prop][$val]) {
                        Write-Host "  [MISMATCH] P1\Proposals\$prop\$val - expected: $($expected.P1Proposals[$prop][$val]), actual: $($actual.$val)" -ForegroundColor Yellow
                        $issues += "P1\Proposals\$prop.$val = $($actual.$val) (expected $($expected.P1Proposals[$prop][$val]))"
                    } else {
                        Write-Host "  [OK] P1\Proposals\$prop\$val = $($actual.$val)" -ForegroundColor Green
                    }
                }
            }
        }
    }
}

# Check P2 values
$p2Path = "$basePath\P2"
if (-not (Test-Path $p2Path)) {
    Write-Host "`n[FAIL] P2 key missing!" -ForegroundColor Red
    $issues += "P2 registry key does not exist"
} else {
    Write-Host "`n--- Phase 2 (IPsec SA) Settings ---" -ForegroundColor Cyan
    foreach ($name in $expected.P2.Keys) {
        $actual = Get-ItemProperty -Path $p2Path -Name $name -ErrorAction SilentlyContinue
        if ($null -eq $actual) {
            Write-Host "  [MISSING] $name - expected: $($expected.P2[$name])" -ForegroundColor Red
            $issues += "P2.$name is missing (expected $($expected.P2[$name]))"
        } elseif ($actual.$name -ne $expected.P2[$name]) {
            Write-Host "  [MISMATCH] $name - expected: $($expected.P2[$name]), actual: $($actual.$name)" -ForegroundColor Yellow
            $issues += "P2.$name = $($actual.$name) (expected $($expected.P2[$name]))"
        } else {
            Write-Host "  [OK] $name = $($actual.$name)" -ForegroundColor Green
        }
    }

    # Check P2 Proposals
    $p2ProposalsPath = "$p2Path\Proposals"
    if (-not (Test-Path $p2ProposalsPath)) {
        Write-Host "  [FAIL] P2\Proposals key missing!" -ForegroundColor Red
        $issues += "P2\Proposals registry key does not exist"
    } else {
        foreach ($prop in $expected.P2Proposals.Keys) {
            $propPath = "$p2ProposalsPath\$prop"
            if (-not (Test-Path $propPath)) {
                Write-Host "  [MISSING] P2 Proposal '$prop' missing" -ForegroundColor Red
                $issues += "P2\Proposals\$prop does not exist"
            } else {
                foreach ($val in $expected.P2Proposals[$prop].Keys) {
                    $actual = Get-ItemProperty -Path $propPath -Name $val -ErrorAction SilentlyContinue
                    if ($null -eq $actual) {
                        Write-Host "  [MISSING] P2\Proposals\$prop\$val" -ForegroundColor Red
                        $issues += "P2\Proposals\$prop.$val is missing"
                    } elseif ($actual.$val -ne $expected.P2Proposals[$prop][$val]) {
                        Write-Host "  [MISMATCH] P2\Proposals\$prop\$val - expected: $($expected.P2Proposals[$prop][$val]), actual: $($actual.$val)" -ForegroundColor Yellow
                        $issues += "P2\Proposals\$prop.$val = $($actual.$val) (expected $($expected.P2Proposals[$prop][$val]))"
                    } else {
                        Write-Host "  [OK] P2\Proposals\$prop\$val = $($actual.$val)" -ForegroundColor Green
                    }
                }
            }
        }
    }
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($issues.Count -eq 0) {
    Write-Host "All settings match expected configuration." -ForegroundColor Green
} else {
    Write-Host "$($issues.Count) issue(s) found:" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

return $issues.Count
