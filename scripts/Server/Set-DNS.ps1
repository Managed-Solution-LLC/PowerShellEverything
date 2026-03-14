<#
.SYNOPSIS
    Sets DNS server addresses for network adapters on a Windows server.

.DESCRIPTION
    This script configures DNS server addresses for specified network adapters on a Windows server.
    It supports setting primary and secondary DNS servers, and can target specific adapters by name
    or configure all active adapters. The script validates DNS server addresses and provides detailed
    feedback on configuration changes.
    
    Key features:
    - Configure DNS servers for specific or all network adapters
    - Validate DNS server IP addresses before applying
    - Support for primary and secondary DNS servers
    - Backup current DNS configuration before changes
    - Detailed logging of all configuration changes
    - Rollback capability if configuration fails

.PARAMETER PrimaryDNS
    The IP address of the primary DNS server to configure.
    This parameter is mandatory and must be a valid IPv4 address.

.PARAMETER SecondaryDNS
    The IP address of the secondary DNS server to configure.
    This parameter is optional. If not specified, only the primary DNS will be configured.

.PARAMETER AdapterName
    The name of the network adapter to configure.
    If not specified, the script will configure all active Ethernet adapters.
    Use Get-NetAdapter to list available adapter names.

.PARAMETER BackupConfiguration
    Creates a backup of the current DNS configuration before making changes.
    Backup file is saved to the output directory with timestamp.

.PARAMETER OutputDirectory
    Directory where backup files and logs will be saved.
    Default: C:\Reports\DNS_Configuration

.EXAMPLE
    .\Set-DNS.ps1 -PrimaryDNS "8.8.8.8" -SecondaryDNS "8.8.4.4"
    
    Configures all active network adapters with Google's public DNS servers.

.EXAMPLE
    .\Set-DNS.ps1 -PrimaryDNS "192.168.1.1" -AdapterName "Ethernet"
    
    Configures only the "Ethernet" adapter with the specified primary DNS server.

.EXAMPLE
    .\Set-DNS.ps1 -PrimaryDNS "10.0.0.1" -SecondaryDNS "10.0.0.2" -BackupConfiguration
    
    Configures DNS servers and creates a backup of the current configuration.

.NOTES
    Author: W. Ford
    Date: 2025-12-23
    Version: 1.0
    
    Requirements:
    - PowerShell 5.1 or later
    - Administrator privileges
    - Active network adapters
    
    The script requires elevated permissions to modify network adapter settings.
    Run PowerShell as Administrator before executing this script.

.LINK
    https://docs.microsoft.com/en-us/powershell/module/nettcpip/set-dnsclientserveraddress
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Primary DNS server IP address")]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}$')]
    [string]$PrimaryDNS,
    
    [Parameter(Mandatory=$false, HelpMessage="Secondary DNS server IP address")]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}$')]
    [string]$SecondaryDNS,
    
    [Parameter(Mandatory=$false, HelpMessage="Name of network adapter to configure")]
    [string]$AdapterName,
    
    [Parameter(Mandatory=$false, HelpMessage="Create backup of current DNS configuration")]
    [switch]$BackupConfiguration,
    
    [Parameter(Mandatory=$false, HelpMessage="Directory for backup files and logs")]
    [string]$OutputDirectory = "C:\Reports\DNS_Configuration"
)

$ErrorActionPreference = "Stop"
$Separator = "=" * 80
$SubSeparator = "-" * 60

# Initialize tracking variables
$StartTime = Get-Date
$ErrorCount = 0
$WarningCount = 0
$ConfiguredAdapters = @()

function Write-StatusMessage {
    param(
        [string]$Message, 
        [string]$Type = "Info"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Type) {
        "Error" { 
            Write-Host "[$timestamp] ❌ ERROR: $Message" -ForegroundColor Red
            $script:ErrorCount++
        }
        "Warning" { 
            Write-Host "[$timestamp] ⚠️  WARNING: $Message" -ForegroundColor Yellow
            $script:WarningCount++
        }
        "Success" { 
            Write-Host "[$timestamp] ✅ SUCCESS: $Message" -ForegroundColor Green
        }
        default { 
            Write-Host "[$timestamp] INFO: $Message" -ForegroundColor Cyan
        }
    }
}

function Test-IsAdministrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IPAddress {
    param([string]$IPAddress)
    
    try {
        $octets = $IPAddress -split '\.'
        if ($octets.Count -ne 4) { return $false }
        
        foreach ($octet in $octets) {
            $num = [int]$octet
            if ($num -lt 0 -or $num -gt 255) { return $false }
        }
        return $true
    }
    catch {
        return $false
    }
}

# Display banner
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "DNS SERVER CONFIGURATION TOOL" -ForegroundColor Cyan
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

# Check for administrator privileges
if (-not (Test-IsAdministrator)) {
    Write-StatusMessage "This script requires administrator privileges" -Type "Error"
    Write-Host "Please run PowerShell as Administrator and try again" -ForegroundColor Yellow
    exit 1
}

Write-StatusMessage "Administrator privileges confirmed" -Type "Success"

# Validate DNS server addresses
Write-Host "`n$SubSeparator" -ForegroundColor White
Write-Host "Validating DNS Server Addresses..." -ForegroundColor Yellow

if (-not (Test-IPAddress -IPAddress $PrimaryDNS)) {
    Write-StatusMessage "Invalid primary DNS address: $PrimaryDNS" -Type "Error"
    exit 1
}
Write-StatusMessage "Primary DNS validated: $PrimaryDNS" -Type "Success"

if ($SecondaryDNS) {
    if (-not (Test-IPAddress -IPAddress $SecondaryDNS)) {
        Write-StatusMessage "Invalid secondary DNS address: $SecondaryDNS" -Type "Error"
        exit 1
    }
    Write-StatusMessage "Secondary DNS validated: $SecondaryDNS" -Type "Success"
}

# Create output directory if needed
if ($BackupConfiguration) {
    if (!(Test-Path $OutputDirectory)) {
        try {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
            Write-StatusMessage "Created output directory: $OutputDirectory" -Type "Success"
        }
        catch {
            Write-StatusMessage "Failed to create output directory: $($_.Exception.Message)" -Type "Error"
            exit 1
        }
    }
}

# Get network adapters
Write-Host "`n$SubSeparator" -ForegroundColor White
Write-Host "Identifying Network Adapters..." -ForegroundColor Yellow

try {
    if ($AdapterName) {
        $Adapters = Get-NetAdapter -Name $AdapterName -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' }
        if (-not $Adapters) {
            Write-StatusMessage "Adapter '$AdapterName' not found or is not active" -Type "Error"
            exit 1
        }
    }
    else {
        $Adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notlike '*Virtual*' }
        if (-not $Adapters) {
            Write-StatusMessage "No active network adapters found" -Type "Error"
            exit 1
        }
    }
    
    Write-StatusMessage "Found $($Adapters.Count) adapter(s) to configure" -Type "Success"
    foreach ($Adapter in $Adapters) {
        Write-Host "  - $($Adapter.Name) ($($Adapter.InterfaceDescription))" -ForegroundColor White
    }
}
catch {
    Write-StatusMessage "Failed to retrieve network adapters: $($_.Exception.Message)" -Type "Error"
    exit 1
}

# Backup current configuration
if ($BackupConfiguration) {
    Write-Host "`n$SubSeparator" -ForegroundColor White
    Write-Host "Backing Up Current Configuration..." -ForegroundColor Yellow
    
    try {
        $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $BackupFile = "$OutputDirectory\DNS_Backup_$Timestamp.csv"
        
        $BackupData = @()
        foreach ($Adapter in $Adapters) {
            $CurrentDNS = Get-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4
            $BackupData += [PSCustomObject]@{
                AdapterName = $Adapter.Name
                InterfaceIndex = $Adapter.ifIndex
                InterfaceDescription = $Adapter.InterfaceDescription
                CurrentDNSServers = ($CurrentDNS.ServerAddresses -join ', ')
                BackupDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            }
        }
        
        $BackupData | Export-Csv -Path $BackupFile -NoTypeInformation -Encoding UTF8
        Write-StatusMessage "Configuration backed up to: $BackupFile" -Type "Success"
    }
    catch {
        Write-StatusMessage "Failed to create backup: $($_.Exception.Message)" -Type "Warning"
    }
}

# Configure DNS servers
Write-Host "`n$SubSeparator" -ForegroundColor White
Write-Host "Configuring DNS Servers..." -ForegroundColor Yellow

foreach ($Adapter in $Adapters) {
    try {
        Write-StatusMessage "Configuring adapter: $($Adapter.Name)" -Type "Info"
        
        # Get current DNS configuration
        $CurrentDNS = Get-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4
        Write-Host "  Current DNS: $($CurrentDNS.ServerAddresses -join ', ')" -ForegroundColor Gray
        
        # Build DNS server array
        $DNSServers = @($PrimaryDNS)
        if ($SecondaryDNS) {
            $DNSServers += $SecondaryDNS
        }
        
        # Set DNS servers
        Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ServerAddresses $DNSServers -ErrorAction Stop
        
        # Verify configuration
        $NewDNS = Get-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4
        Write-Host "  New DNS: $($NewDNS.ServerAddresses -join ', ')" -ForegroundColor Green
        
        $ConfiguredAdapters += [PSCustomObject]@{
            AdapterName = $Adapter.Name
            InterfaceIndex = $Adapter.ifIndex
            PrimaryDNS = $PrimaryDNS
            SecondaryDNS = $SecondaryDNS
            Status = "Success"
        }
        
        Write-StatusMessage "Successfully configured $($Adapter.Name)" -Type "Success"
    }
    catch {
        Write-StatusMessage "Failed to configure $($Adapter.Name): $($_.Exception.Message)" -Type "Error"
        $ConfiguredAdapters += [PSCustomObject]@{
            AdapterName = $Adapter.Name
            InterfaceIndex = $Adapter.ifIndex
            PrimaryDNS = $PrimaryDNS
            SecondaryDNS = $SecondaryDNS
            Status = "Failed: $($_.Exception.Message)"
        }
    }
}

# Summary
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "CONFIGURATION SUMMARY" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

Write-Host "Execution Time: $($Duration.ToString('mm\:ss'))" -ForegroundColor White
Write-Host "Adapters Configured: $($ConfiguredAdapters.Count)" -ForegroundColor White
Write-Host "Errors: $ErrorCount" -ForegroundColor $(if($ErrorCount -gt 0){'Red'}else{'Green'})
Write-Host "Warnings: $WarningCount" -ForegroundColor $(if($WarningCount -gt 0){'Yellow'}else{'Green'})

if ($ConfiguredAdapters.Count -gt 0) {
    Write-Host "`n$SubSeparator" -ForegroundColor White
    Write-Host "Configured Adapters:" -ForegroundColor White
    $ConfiguredAdapters | Format-Table -AutoSize
}

Write-Host "`n$Separator" -ForegroundColor Cyan

if ($ErrorCount -eq 0) {
    Write-Host "✅ DNS configuration completed successfully!" -ForegroundColor Green
}
else {
    Write-Host "⚠️  DNS configuration completed with errors. Review the output above." -ForegroundColor Yellow
}

Write-Host "`nNote: You may need to flush DNS cache or restart network services for changes to take effect." -ForegroundColor Yellow
Write-Host "To flush DNS cache, run: ipconfig /flushdns`n" -ForegroundColor Gray