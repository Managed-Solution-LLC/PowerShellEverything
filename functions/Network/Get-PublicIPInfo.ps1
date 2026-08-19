<#
.SYNOPSIS
    Retrieves the current public (egress) IP address and, optionally,
    geolocation/ISP details.

.DESCRIPTION
    Dot-source this file to load the Get-PublicIPInfo function into your
    session (or add it to a module). Useful for confirming what IP a machine
    or site is egressing on before adding it to an allowlist/firewall rule,
    verifying a VPN or proxy is actually routing traffic as expected, or
    quickly documenting a site's public IP during an assessment.

    Queries https://ipinfo.io by default. Falls back to
    https://api.ipify.org for a plain IP address if -Simple is used or if the
    primary service is unreachable.

.PARAMETER Simple
    Only return the plain IP address (fast, minimal-dependency check) instead
    of full geolocation/ISP details.

.PARAMETER TimeoutSeconds
    Request timeout in seconds. Default is 10.

.EXAMPLE
    . .\Get-PublicIPInfo.ps1
    Get-PublicIPInfo

.EXAMPLE
    Get-PublicIPInfo -Simple

.EXAMPLE
    (Get-PublicIPInfo).Country

.NOTES
    Requires outbound internet access to the lookup service. If both the
    primary and fallback service are unreachable, an error object is returned
    with the Error property populated rather than throwing, so this is safe
    to use in scripts that check connectivity as a first step.
#>

function Get-PublicIPInfo {
    [CmdletBinding()]
    param(
        [switch] $Simple,

        [int] $TimeoutSeconds = 10
    )

    if ($Simple) {
        try {
            $ip = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec $TimeoutSeconds -ErrorAction Stop
            return [PSCustomObject]@{
                IPAddress = $ip.ip
                Error     = $null
            }
        }
        catch {
            return [PSCustomObject]@{
                IPAddress = $null
                Error     = $_.Exception.Message
            }
        }
    }

    try {
        $info = Invoke-RestMethod -Uri "https://ipinfo.io/json" -TimeoutSec $TimeoutSeconds -ErrorAction Stop

        return [PSCustomObject]@{
            IPAddress = $info.ip
            City      = $info.city
            Region    = $info.region
            Country   = $info.country
            Location  = $info.loc
            ISP       = $info.org
            Timezone  = $info.timezone
            Error     = $null
        }
    }
    catch {
        Write-Warning "Get-PublicIPInfo: primary lookup (ipinfo.io) failed - $($_.Exception.Message). Falling back to plain IP lookup."

        try {
            $ip = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec $TimeoutSeconds -ErrorAction Stop
            return [PSCustomObject]@{
                IPAddress = $ip.ip
                City      = $null
                Region    = $null
                Country   = $null
                Location  = $null
                ISP       = $null
                Timezone  = $null
                Error     = "Geolocation lookup failed; returning IP only."
            }
        }
        catch {
            return [PSCustomObject]@{
                IPAddress = $null
                City      = $null
                Region    = $null
                Country   = $null
                Location  = $null
                ISP       = $null
                Timezone  = $null
                Error     = $_.Exception.Message
            }
        }
    }
}
