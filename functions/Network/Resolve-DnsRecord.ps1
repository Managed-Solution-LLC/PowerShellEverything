<#
.SYNOPSIS
    Resolves one or more DNS record types for one or more hostnames, in batch,
    with consistent error handling.

.DESCRIPTION
    Dot-source this file to load the Resolve-DnsRecord function into your
    session (or add it to a module). Wraps Resolve-DnsName so you can check
    many hostnames and record types (e.g. validating MX/SPF/DKIM/DMARC records
    during a mail migration, or confirming A/CNAME records point where expected)
    in one call and get back a flat, filterable/exportable result set instead of
    per-call console output and terminating errors.

.PARAMETER Name
    One or more hostnames or domains to query. Accepts pipeline input.

.PARAMETER Type
    One or more DNS record types to query for each -Name.
    Default is @("A", "AAAA", "MX", "TXT", "CNAME").

.PARAMETER Server
    Optional DNS server to query against instead of the system default
    (e.g. "8.8.8.8" to bypass local/split-horizon DNS and check public records).

.PARAMETER Quiet
    Suppress the colored console summary and just return the result objects.

.EXAMPLE
    . .\Resolve-DnsRecord.ps1
    Resolve-DnsRecord -Name contoso.com -Type MX,TXT

.EXAMPLE
    "contoso.com","fabrikam.com" | Resolve-DnsRecord -Type A -Server 8.8.8.8 -Quiet

.EXAMPLE
    Resolve-DnsRecord -Name "_dmarc.contoso.com" -Type TXT | Select-Object -ExpandProperty Data

.NOTES
    Requires the Resolve-DnsName cmdlet (DnsClient module), which ships with
    Windows PowerShell/Windows 10+ and Windows Server. Not available on
    non-Windows PowerShell 7 by default.
#>

function Resolve-DnsRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]] $Name,

        [ValidateSet("A", "AAAA", "MX", "TXT", "CNAME", "NS", "SOA", "SRV", "PTR")]
        [string[]] $Type = @("A", "AAAA", "MX", "TXT", "CNAME"),

        [string] $Server,

        [switch] $Quiet
    )

    begin {
        if (-not (Get-Command -Name Resolve-DnsName -ErrorAction SilentlyContinue)) {
            throw "Resolve-DnsRecord: the Resolve-DnsName cmdlet is not available on this system (requires Windows PowerShell/Windows 10+ or Windows Server)."
        }

        $results = [System.Collections.Generic.List[object]]::new()
        $dnsParams = @{ ErrorAction = "Stop" }
        if ($Server) { $dnsParams["Server"] = $Server }
    }

    process {
        foreach ($hostName in $Name) {
            foreach ($recordType in $Type) {
                try {
                    $records = Resolve-DnsName -Name $hostName -Type $recordType @dnsParams

                    foreach ($record in $records) {
                        $data = switch ($recordType) {
                            "A"     { $record.IPAddress }
                            "AAAA"  { $record.IPAddress }
                            "MX"    { "$($record.NameExchange) (pref $($record.Preference))" }
                            "TXT"   { ($record.Strings -join "") }
                            "CNAME" { $record.NameHost }
                            "NS"    { $record.NameHost }
                            "SOA"   { $record.PrimaryServer }
                            "SRV"   { "$($record.NameTarget):$($record.Port) (priority $($record.Priority))" }
                            "PTR"   { $record.NameHost }
                            default { $record.ToString() }
                        }

                        $results.Add([PSCustomObject]@{
                            Name   = $hostName
                            Type   = $recordType
                            Data   = $data
                            TTL    = $record.TTL
                            Error  = $null
                        })
                    }
                }
                catch {
                    $results.Add([PSCustomObject]@{
                        Name  = $hostName
                        Type  = $recordType
                        Data  = $null
                        TTL   = $null
                        Error = $_.Exception.Message
                    })
                }
            }
        }
    }

    end {
        if (-not $Quiet) {
            foreach ($r in $results) {
                if ($r.Error) {
                    Write-Host "$($r.Name) [$($r.Type)] -> ERROR: $($r.Error)" -ForegroundColor Red
                }
                else {
                    Write-Host "$($r.Name) [$($r.Type)] -> $($r.Data) (TTL $($r.TTL))" -ForegroundColor Green
                }
            }
        }

        return $results
    }
}
