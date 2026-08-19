<#
.SYNOPSIS
    Tests whether one or more TCP ports are open on one or more hosts, in batch,
    with latency and timeout control.

.DESCRIPTION
    Dot-source this file to load the Test-PortConnection function into your
    session (or add it to a module). Like a scriptable version of
    Test-NetConnection, but built for checking many host/port combinations at
    once (e.g. validating firewall rules across a list of servers, or confirming
    a batch of required outbound ports for a SaaS migration) and returning clean
    objects instead of console-only output.

.PARAMETER ComputerName
    One or more hostnames or IP addresses to test. Accepts pipeline input.

.PARAMETER Port
    One or more TCP ports to test against each -ComputerName. Default is 443.

.PARAMETER TimeoutMilliseconds
    Connection timeout per attempt, in milliseconds. Default is 2000.

.PARAMETER Quiet
    Suppress the colored console summary and just return the result objects.

.EXAMPLE
    . .\Test-PortConnection.ps1
    Test-PortConnection -ComputerName dc01 -Port 389,636,3268,3269

.EXAMPLE
    "server1","server2" | Test-PortConnection -Port 443 -Quiet | Where-Object { -not $_.Open }

.EXAMPLE
    Test-PortConnection -ComputerName smtp.office365.com -Port 587 -TimeoutMilliseconds 5000
#>

function Test-PortConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]] $ComputerName,

        [Parameter(Position = 1)]
        [int[]] $Port = @(443),

        [int] $TimeoutMilliseconds = 2000,

        [switch] $Quiet
    )

    begin {
        $results = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($target in $ComputerName) {
            foreach ($p in $Port) {

                $tcpClient = $null
                $open = $false
                $errorMessage = $null
                $elapsedMs = $null

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                try {
                    $tcpClient = [System.Net.Sockets.TcpClient]::new()
                    $connectTask = $tcpClient.ConnectAsync($target, $p)

                    if ($connectTask.Wait($TimeoutMilliseconds)) {
                        if ($tcpClient.Connected) {
                            $open = $true
                        }
                        else {
                            $errorMessage = "Connection did not complete successfully."
                        }
                    }
                    else {
                        $errorMessage = "Timed out after $TimeoutMilliseconds ms."
                    }
                }
                catch {
                    $errorMessage = $_.Exception.InnerException.Message
                    if (-not $errorMessage) { $errorMessage = $_.Exception.Message }
                }
                finally {
                    $sw.Stop()
                    $elapsedMs = $sw.ElapsedMilliseconds
                    if ($tcpClient) { $tcpClient.Dispose() }
                }

                $results.Add([PSCustomObject]@{
                    ComputerName = $target
                    Port         = $p
                    Open         = $open
                    LatencyMs    = $elapsedMs
                    Error        = $errorMessage
                })
            }
        }
    }

    end {
        if (-not $Quiet) {
            foreach ($r in $results) {
                $color = if ($r.Open) { "Green" } else { "Red" }
                $status = if ($r.Open) { "OPEN" } else { "CLOSED/FILTERED" }
                $line = "{0,-30} : {1,-6} -> {2,-16} ({3} ms)" -f "$($r.ComputerName):$($r.Port)", $status, $(if ($r.Error) { $r.Error } else { "" }), $r.LatencyMs
                Write-Host $line -ForegroundColor $color
            }
        }

        return $results
    }
}
