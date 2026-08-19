<#
.SYNOPSIS
    Function that checks the SSL/TLS certificate presented by one or more URLs.

.DESCRIPTION
    Dot-source this file to load the Get-SslCertificateInfo function into your session
    (or add it to a module), then call it like any other cmdlet. Connects to the given
    URL(s) on the specified port (default 443), retrieves the SSL/TLS certificate, and
    returns subject, issuer, validity dates, days remaining until expiration, thumbprint,
    and SAN entries as objects you can filter, format, or export.

.PARAMETER Url
    One or more URLs or hostnames to check. Accepts values like:
    "example.com", "https://example.com", "example.com:8443".

.PARAMETER Port
    Port to connect on if not specified in the URL. Default is 443.

.PARAMETER WarningDays
    Number of days before expiration to flag the certificate as "Expiring Soon".
    Default is 30.

.PARAMETER TimeoutSeconds
    Connection timeout in seconds. Default is 10.

.PARAMETER Quiet
    Suppress the colored console summary and just return the result objects.

.EXAMPLE
    . .\Get-SslCertificateInfo.ps1
    Get-SslCertificateInfo -Url example.com

.EXAMPLE
    Get-SslCertificateInfo -Url "https://example.com","mail.example.com:993" -WarningDays 45

.EXAMPLE
    "example.com","google.com" | Get-SslCertificateInfo -Quiet | Format-Table -AutoSize

.EXAMPLE
    $expiring = Get-SslCertificateInfo -Url example.com -WarningDays 60 -Quiet |
        Where-Object { $_.Status -in @("Expiring Soon", "Expired", "Error") }
#>

function Get-SslCertificateInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]] $Url,

        [int] $Port = 443,

        [int] $WarningDays = 30,

        [int] $TimeoutSeconds = 10,

        [switch] $Quiet
    )

    begin {
        $results = [System.Collections.Generic.List[object]]::new()

        function Get-HostAndPort {
            param([string] $InputUrl, [int] $DefaultPort)

            $cleaned = $InputUrl.Trim()

            # Strip a scheme like https:// or ldaps:// if present
            if ($cleaned -match '^[a-zA-Z][a-zA-Z0-9+.\-]*://(.+)$') {
                $cleaned = $Matches[1]
            }

            # Strip any path/query
            $cleaned = $cleaned.Split('/')[0]

            $hostName = $cleaned
            $targetPort = $DefaultPort

            # Handle host:port (but not IPv6 literals in brackets, which we don't attempt to fully support here)
            if ($cleaned -match '^(.+):(\d+)$') {
                $hostName = $Matches[1]
                $targetPort = [int]$Matches[2]
            }

            [PSCustomObject]@{
                HostName = $hostName
                Port     = $targetPort
            }
        }
    }

    process {
        foreach ($entry in $Url) {

            $parsed = Get-HostAndPort -InputUrl $entry -DefaultPort $Port
            $targetHost = $parsed.HostName
            $targetPort = $parsed.Port

            $status  = "OK"
            $errorMessage = $null
            $cert = $null

            $tcpClient = $null
            $sslStream = $null

            try {
                $tcpClient = [System.Net.Sockets.TcpClient]::new()
                $connectTask = $tcpClient.ConnectAsync($targetHost, $targetPort)

                if (-not $connectTask.Wait([TimeSpan]::FromSeconds($TimeoutSeconds))) {
                    throw "Connection to $targetHost`:$targetPort timed out after $TimeoutSeconds second(s)."
                }

                $sslStream = [System.Net.Security.SslStream]::new(
                    $tcpClient.GetStream(),
                    $false,
                    [System.Net.Security.RemoteCertificateValidationCallback] { $true } # accept any cert so we can inspect it, even if invalid
                )

                $sslStream.AuthenticateAsClient($targetHost)

                $rawCert = $sslStream.RemoteCertificate
                if ($null -eq $rawCert) {
                    throw "No certificate was returned by the server."
                }

                $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($rawCert)
            }
            catch {
                $status = "Error"
                $errorMessage = $_.Exception.Message
            }
            finally {
                if ($sslStream) { $sslStream.Dispose() }
                if ($tcpClient) { $tcpClient.Dispose() }
            }

            if ($cert) {
                $daysRemaining = [math]::Ceiling(($cert.NotAfter - (Get-Date)).TotalDays)

                if ($daysRemaining -lt 0) {
                    $status = "Expired"
                }
                elseif ($daysRemaining -le $WarningDays) {
                    $status = "Expiring Soon"
                }

                $sanEntries = $null
                try {
                    $sanExt = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Subject Alternative Name" }
                    if ($sanExt) {
                        $sanEntries = ($sanExt.Format($false) -split ',\s*') -join '; '
                    }
                }
                catch {
                    # Non-fatal; SAN parsing failed, leave blank
                }

                $results.Add([PSCustomObject]@{
                    Url             = $entry
                    HostName        = $targetHost
                    Port            = $targetPort
                    Status          = $status
                    Subject         = $cert.Subject
                    Issuer          = $cert.Issuer
                    NotBefore       = $cert.NotBefore
                    NotAfter        = $cert.NotAfter
                    DaysRemaining   = $daysRemaining
                    Thumbprint      = $cert.Thumbprint
                    SubjectAltNames = $sanEntries
                    Error           = $null
                })
            }
            else {
                $results.Add([PSCustomObject]@{
                    Url             = $entry
                    HostName        = $targetHost
                    Port            = $targetPort
                    Status          = $status
                    Subject         = $null
                    Issuer          = $null
                    NotBefore       = $null
                    NotAfter        = $null
                    DaysRemaining   = $null
                    Thumbprint      = $null
                    SubjectAltNames = $null
                    Error           = $errorMessage
                })
            }
        }
    }

    end {
        if (-not $Quiet) {
            $results | ForEach-Object {
                $color = switch ($_.Status) {
                    "OK"            { "Green" }
                    "Expiring Soon" { "Yellow" }
                    "Expired"       { "Red" }
                    "Error"         { "Red" }
                    default         { "White" }
                }

                Write-Host ""
                Write-Host "=== $($_.Url) ===" -ForegroundColor Cyan
                Write-Host "Status        : $($_.Status)" -ForegroundColor $color

                if ($_.Status -eq "Error") {
                    Write-Host "Error         : $($_.Error)" -ForegroundColor $color
                }
                else {
                    Write-Host "Subject       : $($_.Subject)"
                    Write-Host "Issuer        : $($_.Issuer)"
                    Write-Host "Valid From    : $($_.NotBefore)"
                    Write-Host "Valid Until   : $($_.NotAfter)"
                    Write-Host "Days Remaining: $($_.DaysRemaining)" -ForegroundColor $color
                    Write-Host "Thumbprint    : $($_.Thumbprint)"
                    if ($_.SubjectAltNames) {
                        Write-Host "SAN           : $($_.SubjectAltNames)"
                    }
                }
            }
            Write-Host ""
        }

        # Return the result objects so callers can pipe, filter, export, or check Status themselves
        return $results
    }
}