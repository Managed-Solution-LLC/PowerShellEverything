<#
.SYNOPSIS
    Runs a scriptblock and automatically retries it with exponential backoff if it throws.

.DESCRIPTION
    Dot-source this file to load the Invoke-WithRetry function into your session
    (or add it to a module). Wrap any command that occasionally fails transiently -
    Graph/API calls that get throttled (HTTP 429), flaky network operations, race
    conditions against services that are still provisioning - and it will retry up
    to -MaxAttempts times, waiting longer between each attempt, before giving up and
    re-throwing the final exception.

    If the caught exception exposes a Retry-After value (as Microsoft Graph
    throttling responses do), that delay is honored instead of the computed backoff.

.PARAMETER ScriptBlock
    The code to execute. Referenced retry-relevant values (e.g. loop variables)
    should be passed in via -ArgumentList rather than closed over, so each retry
    sees the same inputs.

.PARAMETER ArgumentList
    Arguments to pass to -ScriptBlock, available inside it as $args[0], $args[1], etc.

.PARAMETER MaxAttempts
    Maximum number of attempts (including the first). Default is 5.

.PARAMETER InitialDelaySeconds
    Delay before the first retry. Default is 2 seconds. Each subsequent retry
    doubles this value (exponential backoff), optionally capped by -MaxDelaySeconds.

.PARAMETER MaxDelaySeconds
    Upper bound on the computed backoff delay. Default is 60 seconds.

.PARAMETER Jitter
    Add up to +/-20% random jitter to each computed delay, to avoid many parallel
    callers retrying in lockstep against the same throttled service.

.PARAMETER RetryOn
    Optional scriptblock predicate that receives the caught exception ($_) and
    returns $true if it should be retried, $false if it should be re-thrown
    immediately. Default retries on every exception.

.EXAMPLE
    . .\Invoke-WithRetry.ps1
    Invoke-WithRetry -ScriptBlock { Get-MgUser -UserId "user@contoso.com" }

.EXAMPLE
    Invoke-WithRetry -MaxAttempts 8 -InitialDelaySeconds 1 -Jitter -ScriptBlock {
        Invoke-RestMethod -Uri $args[0] -Headers $args[1]
    } -ArgumentList @($uri, $headers)

.EXAMPLE
    Invoke-WithRetry -ScriptBlock { Invoke-MgGraphRequest -Uri $uri } -RetryOn {
        param($ex)
        $ex.Exception.Response.StatusCode.value__ -in 429, 503, 504
    }

.NOTES
    Re-throws the original exception (via throw $lastError) if all attempts are
    exhausted, so callers can still catch and handle it normally.
#>

function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock] $ScriptBlock,

        [object[]] $ArgumentList,

        [int] $MaxAttempts = 5,

        [double] $InitialDelaySeconds = 2,

        [double] $MaxDelaySeconds = 60,

        [switch] $Jitter,

        [scriptblock] $RetryOn = { $true }
    )

    $attempt = 0
    $delay = $InitialDelaySeconds
    $lastError = $null

    while ($attempt -lt $MaxAttempts) {
        $attempt++
        try {
            Write-Verbose "Invoke-WithRetry: attempt $attempt of $MaxAttempts"
            if ($ArgumentList) {
                return & $ScriptBlock @ArgumentList
            }
            else {
                return & $ScriptBlock
            }
        }
        catch {
            $lastError = $_

            $shouldRetry = $false
            try {
                $shouldRetry = [bool](& $RetryOn $_)
            }
            catch {
                $shouldRetry = $true
            }

            if (-not $shouldRetry -or $attempt -ge $MaxAttempts) {
                Write-Verbose "Invoke-WithRetry: not retrying (shouldRetry=$shouldRetry, attempt=$attempt)"
                throw $lastError
            }

            $waitSeconds = $delay

            # Honor a server-supplied Retry-After header if the exception exposes one
            $retryAfter = $null
            try {
                $response = $_.Exception.Response
                if ($response -and $response.Headers -and $response.Headers["Retry-After"]) {
                    $retryAfter = [double]$response.Headers["Retry-After"]
                }
            }
            catch {
                $retryAfter = $null
            }

            if ($retryAfter) {
                $waitSeconds = $retryAfter
            }
            elseif ($Jitter) {
                $jitterFactor = 1 + ((Get-Random -Minimum -20 -Maximum 21) / 100)
                $waitSeconds = $waitSeconds * $jitterFactor
            }

            $waitSeconds = [math]::Min($waitSeconds, $MaxDelaySeconds)
            $waitSeconds = [math]::Max($waitSeconds, 0.1)

            Write-Warning "Invoke-WithRetry: attempt $attempt failed - $($_.Exception.Message). Retrying in $([math]::Round($waitSeconds,1))s..."
            Start-Sleep -Seconds $waitSeconds

            $delay = [math]::Min($delay * 2, $MaxDelaySeconds)
        }
    }

    throw $lastError
}
