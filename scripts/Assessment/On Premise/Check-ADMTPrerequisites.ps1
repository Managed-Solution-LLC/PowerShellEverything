#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Checks Active Directory Migration Tool (ADMT) prerequisites.
.DESCRIPTION
    Validates environment readiness for ADMT migrations including domain levels,
    trusts, permissions, SID History requirements, and network connectivity.
.PARAMETER SourceDomain
    FQDN of the source domain (domain you're migrating FROM)
.PARAMETER TargetDomain
    FQDN of the target domain (domain you're migrating TO). Defaults to current domain.
.PARAMETER CheckSIDHistory
    Include SID History prerequisite checks
.PARAMETER CheckPES
    Check for Password Export Server requirements
.PARAMETER SourcePDC
    FQDN of source domain PDC Emulator (required for SID History checks)
.EXAMPLE
    .\Check-ADMTPrerequisites.ps1 -SourceDomain "old.contoso.com" -TargetDomain "new.contoso.com"
.EXAMPLE
    .\Check-ADMTPrerequisites.ps1 -SourceDomain "old.contoso.com" -CheckSIDHistory -SourcePDC "dc01.old.contoso.com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDomain,
    
    [Parameter(Mandatory = $false)]
    [string]$TargetDomain = (Get-ADDomain).DNSRoot,
    
    [switch]$CheckSIDHistory,
    
    [switch]$CheckPES,
    
    [string]$SourcePDC
)

#region Helper Functions
function Write-CheckResult {
    param(
        [string]$Check,
        [string]$Status,
        [string]$Message,
        [string]$Remediation = ""
    )
    
    $color = switch ($Status) {
        "PASS"    { "Green" }
        "FAIL"    { "Red" }
        "WARNING" { "Yellow" }
        "INFO"    { "Cyan" }
        default   { "White" }
    }
    
    Write-Host "`n[$Status] " -ForegroundColor $color -NoNewline
    Write-Host $Check -ForegroundColor White
    Write-Host "  $Message" -ForegroundColor Gray
    
    if ($Remediation -and $Status -eq "FAIL") {
        Write-Host "  Remediation: $Remediation" -ForegroundColor Yellow
    }
    
    return [PSCustomObject]@{
        Check       = $Check
        Status      = $Status
        Message     = $Message
        Remediation = $Remediation
    }
}

function Test-PortConnection {
    param(
        [string]$ComputerName,
        [int]$Port,
        [int]$Timeout = 3000
    )
    
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($ComputerName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
        
        if ($wait) {
            $tcp.EndConnect($connect)
            $tcp.Close()
            return $true
        }
        $tcp.Close()
        return $false
    }
    catch {
        return $false
    }
}
#endregion

#region Main Script
$results = @()
$divider = "=" * 70

Write-Host "`n$divider" -ForegroundColor Cyan
Write-Host "  ADMT Prerequisites Checker" -ForegroundColor Cyan
Write-Host "  Source Domain: $SourceDomain" -ForegroundColor White
Write-Host "  Target Domain: $TargetDomain" -ForegroundColor White
Write-Host "  Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "$divider" -ForegroundColor Cyan

#region 1. DNS Resolution Checks
Write-Host "`n[SECTION] DNS Resolution" -ForegroundColor Magenta

try {
    $sourceDNS = Resolve-DnsName -Name $SourceDomain -Type A -ErrorAction Stop
    $results += Write-CheckResult -Check "Source Domain DNS Resolution" -Status "PASS" `
        -Message "Successfully resolved $SourceDomain to $($sourceDNS.IPAddress -join ', ')"
}
catch {
    $results += Write-CheckResult -Check "Source Domain DNS Resolution" -Status "FAIL" `
        -Message "Cannot resolve $SourceDomain" `
        -Remediation "Verify DNS configuration and conditional forwarders"
}

try {
    $targetDNS = Resolve-DnsName -Name $TargetDomain -Type A -ErrorAction Stop
    $results += Write-CheckResult -Check "Target Domain DNS Resolution" -Status "PASS" `
        -Message "Successfully resolved $TargetDomain to $($targetDNS.IPAddress -join ', ')"
}
catch {
    $results += Write-CheckResult -Check "Target Domain DNS Resolution" -Status "FAIL" `
        -Message "Cannot resolve $TargetDomain" `
        -Remediation "Verify DNS configuration"
}
#endregion

#region 2. Domain Functional Level Checks
Write-Host "`n[SECTION] Domain Functional Levels" -ForegroundColor Magenta

try {
    $targetDomainInfo = Get-ADDomain -Server $TargetDomain -ErrorAction Stop
    $targetForest = Get-ADForest -Server $TargetDomain -ErrorAction Stop
    
    $results += Write-CheckResult -Check "Target Domain Functional Level" -Status "PASS" `
        -Message "Target domain level: $($targetDomainInfo.DomainMode)"
    
    $results += Write-CheckResult -Check "Target Forest Functional Level" -Status "INFO" `
        -Message "Target forest level: $($targetForest.ForestMode)"
}
catch {
    $results += Write-CheckResult -Check "Target Domain Functional Level" -Status "FAIL" `
        -Message "Cannot query target domain: $_" `
        -Remediation "Verify connectivity and credentials for target domain"
}

try {
    $sourceDomainInfo = Get-ADDomain -Server $SourceDomain -ErrorAction Stop
    
    $minLevel = "Windows2000Domain"
    if ($sourceDomainInfo.DomainMode -ge $minLevel) {
        $results += Write-CheckResult -Check "Source Domain Functional Level" -Status "PASS" `
            -Message "Source domain level: $($sourceDomainInfo.DomainMode) (minimum: Windows 2000 Native)"
    }
    else {
        $results += Write-CheckResult -Check "Source Domain Functional Level" -Status "FAIL" `
            -Message "Source domain level $($sourceDomainInfo.DomainMode) is below minimum" `
            -Remediation "Raise source domain functional level to Windows 2000 Native or higher"
    }
}
catch {
    $results += Write-CheckResult -Check "Source Domain Functional Level" -Status "FAIL" `
        -Message "Cannot query source domain: $_" `
        -Remediation "Verify connectivity and credentials for source domain"
}
#endregion

#region 3. Trust Relationship Checks
Write-Host "`n[SECTION] Trust Relationships" -ForegroundColor Magenta

try {
    $trusts = Get-ADTrust -Filter * -Server $TargetDomain -ErrorAction Stop
    $sourceTrust = $trusts | Where-Object { $_.Target -like "*$($SourceDomain.Split('.')[0])*" -or $_.Target -eq $SourceDomain }
    
    if ($sourceTrust) {
        $trustDirection = switch ($sourceTrust.Direction) {
            "BiDirectional" { "Two-way (Optimal)" }
            "Outbound"      { "Outbound (Target trusts Source)" }
            "Inbound"       { "Inbound (Source trusts Target)" }
            default         { $sourceTrust.Direction }
        }
        
        if ($sourceTrust.Direction -eq "BiDirectional") {
            $results += Write-CheckResult -Check "Trust Relationship" -Status "PASS" `
                -Message "Trust found: $trustDirection - Type: $($sourceTrust.TrustType)"
        }
        elseif ($sourceTrust.Direction -eq "Outbound") {
            $results += Write-CheckResult -Check "Trust Relationship" -Status "PASS" `
                -Message "Trust found: $trustDirection (sufficient for basic migration)"
        }
        else {
            $results += Write-CheckResult -Check "Trust Relationship" -Status "WARNING" `
                -Message "Trust direction: $trustDirection - May limit migration capabilities" `
                -Remediation "Consider establishing two-way trust for full functionality"
        }
    }
    else {
        $results += Write-CheckResult -Check "Trust Relationship" -Status "FAIL" `
            -Message "No trust relationship found between domains" `
            -Remediation "Establish trust: Target domain must trust Source domain (minimum)"
    }
}
catch {
    $results += Write-CheckResult -Check "Trust Relationship" -Status "FAIL" `
        -Message "Cannot query trust relationships: $_" `
        -Remediation "Verify AD connectivity and permissions"
}
#endregion

#region 4. Current User Permissions
Write-Host "`n[SECTION] Permission Checks" -ForegroundColor Magenta

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# Check Target Domain Admin
try {
    $targetDomainAdmins = Get-ADGroupMember -Identity "Domain Admins" -Server $TargetDomain -ErrorAction Stop
    $isTargetAdmin = $targetDomainAdmins | Where-Object { 
        $_.SamAccountName -eq $currentUser.Split('\')[1] 
    }
    
    if ($isTargetAdmin) {
        $results += Write-CheckResult -Check "Target Domain Admin Membership" -Status "PASS" `
            -Message "Current user ($currentUser) is a Domain Admin in target domain"
    }
    else {
        $results += Write-CheckResult -Check "Target Domain Admin Membership" -Status "WARNING" `
            -Message "Current user ($currentUser) may not be Domain Admin in target" `
            -Remediation "Verify user has Domain Admin rights in target domain"
    }
}
catch {
    $results += Write-CheckResult -Check "Target Domain Admin Membership" -Status "WARNING" `
        -Message "Cannot verify Domain Admin membership: $_"
}

# Check Source Domain permissions
try {
    $testOU = Get-ADOrganizationalUnit -Filter * -Server $SourceDomain -ResultSetSize 1 -ErrorAction Stop
    $results += Write-CheckResult -Check "Source Domain Read Access" -Status "PASS" `
        -Message "Can read objects from source domain"
}
catch {
    $results += Write-CheckResult -Check "Source Domain Read Access" -Status "FAIL" `
        -Message "Cannot read from source domain: $_" `
        -Remediation "Ensure account has read permissions in source domain"
}
#endregion

#region 5. SID History Prerequisites
if ($CheckSIDHistory) {
    Write-Host "`n[SECTION] SID History Prerequisites" -ForegroundColor Magenta
    
    # Check Auditing on Source Domain
    if ($SourcePDC) {
        try {
            $auditPolicy = auditpol /get /category:"Account Management" /r 2>$null | ConvertFrom-Csv
            $results += Write-CheckResult -Check "Local Audit Policy" -Status "INFO" `
                -Message "Run 'auditpol /get /category:Account Management' on source PDC to verify"
        }
        catch {
            $results += Write-CheckResult -Check "Audit Policy Check" -Status "INFO" `
                -Message "Manually verify auditing is enabled on source domain PDC"
        }
        
        # Check TCP 138 connectivity
        if (Test-PortConnection -ComputerName $SourcePDC -Port 138) {
            $results += Write-CheckResult -Check "TCP Port 138 to Source PDC" -Status "PASS" `
                -Message "Port 138 is accessible on $SourcePDC"
        }
        else {
            $results += Write-CheckResult -Check "TCP Port 138 to Source PDC" -Status "FAIL" `
                -Message "Cannot connect to port 138 on $SourcePDC" `
                -Remediation "Open TCP port 138 between ADMT server and source PDC"
        }
    }
    else {
        $results += Write-CheckResult -Check "SID History Checks" -Status "WARNING" `
            -Message "SourcePDC parameter not provided - skipping connectivity checks" `
            -Remediation "Re-run with -SourcePDC parameter for complete SID History validation"
    }
    
    # Check for source domain local group
    $results += Write-CheckResult -Check "Source Domain Local Group" -Status "INFO" `
        -Message "Verify group '`$SourceDomain`$`$`$' exists on source PDC (created during first SID migration)"
}
#endregion

#region 6. Password Export Server Check
if ($CheckPES) {
    Write-Host "`n[SECTION] Password Export Server (PES)" -ForegroundColor Magenta
    
    $results += Write-CheckResult -Check "PES Installation" -Status "INFO" `
        -Message "PES must be installed on a DC in the SOURCE domain"
    
    $results += Write-CheckResult -Check "PES Encryption Key" -Status "INFO" `
        -Message "128-bit encryption key required - generate with 'admt key' command"
}
#endregion

#region 7. Network Connectivity - Common Ports
Write-Host "`n[SECTION] Network Connectivity" -ForegroundColor Magenta

$targetDC = (Get-ADDomainController -DomainName $TargetDomain -Discover -ErrorAction SilentlyContinue).HostName[0]

if ($targetDC) {
    $portsToCheck = @(
        @{Port = 389;  Name = "LDAP" },
        @{Port = 636;  Name = "LDAPS" },
        @{Port = 3268; Name = "Global Catalog" },
        @{Port = 88;   Name = "Kerberos" },
        @{Port = 135;  Name = "RPC Endpoint Mapper" },
        @{Port = 445;  Name = "SMB" }
    )
    
    foreach ($p in $portsToCheck) {
        if (Test-PortConnection -ComputerName $targetDC -Port $p.Port) {
            $results += Write-CheckResult -Check "Port $($p.Port) ($($p.Name))" -Status "PASS" `
                -Message "Successfully connected to $targetDC on port $($p.Port)"
        }
        else {
            $results += Write-CheckResult -Check "Port $($p.Port) ($($p.Name))" -Status "WARNING" `
                -Message "Cannot connect to $targetDC on port $($p.Port)"
        }
    }
}
#endregion

#region 8. SQL Server / Database Check
Write-Host "`n[SECTION] Database Requirements" -ForegroundColor Magenta

$sqlInstances = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" -ErrorAction SilentlyContinue

if ($sqlInstances) {
    $instances = $sqlInstances.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" }
    $results += Write-CheckResult -Check "SQL Server Installation" -Status "PASS" `
        -Message "SQL Server instances found: $($instances.Name -join ', ')"
}
else {
    $results += Write-CheckResult -Check "SQL Server Installation" -Status "INFO" `
        -Message "No local SQL Server found - ADMT can install SQL Server Express" `
        -Remediation "SQL Server Express will be installed with ADMT if needed"
}
#endregion

#region 9. ADMT Installation Check
Write-Host "`n[SECTION] ADMT Installation" -ForegroundColor Magenta

$admtPath = "C:\Windows\ADMT"
$admtReg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\ADMT" -ErrorAction SilentlyContinue

if (Test-Path $admtPath) {
    $results += Write-CheckResult -Check "ADMT Installation Directory" -Status "PASS" `
        -Message "ADMT directory exists at $admtPath"
}
else {
    $results += Write-CheckResult -Check "ADMT Installation Directory" -Status "INFO" `
        -Message "ADMT not yet installed (directory not found)"
}

if ($admtReg) {
    $results += Write-CheckResult -Check "ADMT Registry" -Status "PASS" `
        -Message "ADMT is registered in the system"
}
#endregion

#region Summary Report
Write-Host "`n$divider" -ForegroundColor Cyan
Write-Host "  SUMMARY REPORT" -ForegroundColor Cyan
Write-Host "$divider" -ForegroundColor Cyan

$passed = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnings = ($results | Where-Object { $_.Status -eq "WARNING" }).Count
$info = ($results | Where-Object { $_.Status -eq "INFO" }).Count

Write-Host "`n  Total Checks: $($results.Count)" -ForegroundColor White
Write-Host "  Passed:       $passed" -ForegroundColor Green
Write-Host "  Failed:       $failed" -ForegroundColor Red
Write-Host "  Warnings:     $warnings" -ForegroundColor Yellow
Write-Host "  Info:         $info" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Host "`n  [!] There are $failed failed checks that must be resolved before migration" -ForegroundColor Red
    
    Write-Host "`n  Failed Items:" -ForegroundColor Red
    $results | Where-Object { $_.Status -eq "FAIL" } | ForEach-Object {
        Write-Host "    - $($_.Check)" -ForegroundColor Red
    }
}

if ($warnings -gt 0) {
    Write-Host "`n  [!] There are $warnings warnings to review" -ForegroundColor Yellow
}

Write-Host "`n$divider`n" -ForegroundColor Cyan

# Export results to CSV
$exportPath = ".\ADMT_Prerequisites_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -Path $exportPath -NoTypeInformation
Write-Host "Results exported to: $exportPath`n" -ForegroundColor Green

return $results
#endregion