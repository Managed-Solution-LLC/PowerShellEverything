<#
.SYNOPSIS
    Checks HTTP status code and response time for one or more URLs.

.DESCRIPTION
    Dot-source this file to load the Test-WebsiteHealth function into your
    session (or add it to a module). A quick uptime/health spot-check for a
    list of sites or endpoints - client portals, hosted apps, status pages,
    API health-check URLs - returning a clean pass/fail object per URL rather
    than raw Invoke-WebRequest output.

.PARAMETER Url
    One or more URLs to check. Accepts pipeline input. "http(s)://" is
    prepended automatically if missing.

.PARAMETER ExpectedStatusCode
    HTTP status code considered healthy. Default is 200.

.PARAMETER TimeoutSeconds
    Request timeout in seconds. Default is 15.

.PARAMETER FollowRedirects
    Follow HTTP redirects (3xx) instead of evaluating the redirect response
    itself.

.PARAMETER Quiet
    Suppress the colored console summary and just return the result objects.

.EXAMPLE
    . .\Test-WebsiteHealth.ps1
    Test-WebsiteHealth -Url portal.contoso.com

.EXAMPLE
    "status.contoso.com","app.contoso.com/health" | Test-WebsiteHealth -FollowRedirects -Quiet |
        Where-Object { -not $_.Healthy }

.EXAMPLE
    Test-WebsiteHealth -Url https://api.contoso.com/health -ExpectedStatusCode 204
#>

function Test-WebsiteHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]] $Url,

        [int] $ExpectedStatusCode = 200,

        [int] $TimeoutSeconds = 15,

        [switch] $FollowRedirects,

        [switch] $Quiet
    )

    begin {
        $results = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($entry in $Url) {
            $target = $entry
            if ($target -notmatch '^[a-zA-Z][a-zA-Z0-9+.\-]*://') {
                $target = "https://$target"
            }

            $statusCode = $null
            $elapsedMs = $null
            $healthy = $false
            $errorMessage = $null

            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $webParams = @{
                    Uri                = $target
                    TimeoutSec         = $TimeoutSeconds
                    UseBasicParsing    = $true
                    ErrorAction        = "Stop"
                    MaximumRedirection = if ($FollowRedirects) { 5 } else { 0 }
                }

                $response = Invoke-WebRequest @webParams
                $statusCode = [int]$response.StatusCode
            }
            catch [Microsoft.PowerShell.Commands.HttpResponseException] {
                # Invoke-WebRequest throws on non-2xx by default; still capture the status code it returned with
                if ($_.Exception.Response) {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }
                else {
                    $errorMessage = $_.Exception.Message
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
            }
            finally {
                $sw.Stop()
                $elapsedMs = $sw.ElapsedMilliseconds
            }

            if ($statusCode) {
                $healthy = ($statusCode -eq $ExpectedStatusCode)
            }

            $results.Add([PSCustomObject]@{
                Url         = $entry
                StatusCode  = $statusCode
                ExpectedCode = $ExpectedStatusCode
                Healthy     = $healthy
                ResponseMs  = $elapsedMs
                Error       = $errorMessage
            })
        }
    }

    end {
        if (-not $Quiet) {
            foreach ($r in $results) {
                $color = if ($r.Healthy) { "Green" } else { "Red" }
                $codeText = if ($r.StatusCode) { $r.StatusCode } else { "N/A" }
                $line = "{0,-45} : {1,-6} (expected {2}) in {3} ms {4}" -f $r.Url, $codeText, $r.ExpectedCode, $r.ResponseMs, $(if ($r.Error) { "- $($r.Error)" } else { "" })
                Write-Host $line -ForegroundColor $color
            }
        }

        return $results
    }
}
