$vpnName = "MulFil IPsec VPN"
$basePath = "HKLM:\SOFTWARE\Fortinet\FortiClient\IPSec\Tunnels\$vpnName"

if (Test-Path -LiteralPath $basePath) {
    try {
        Remove-Item -LiteralPath $basePath -Recurse -Force
        Write-Host "FortiClient IPsec VPN '$vpnName' registry entries removed successfully." -ForegroundColor Green
        return 0
    } catch {
        Write-Host "Error removing registry entries: $_" -ForegroundColor Red
        return 1
    }
} else {
    Write-Host "FortiClient VPN '$vpnName' not found. Nothing to remove." -ForegroundColor Yellow
    return 0
}
