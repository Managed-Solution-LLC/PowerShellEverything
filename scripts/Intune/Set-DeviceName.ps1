<#
.SYNOPSIS
    Renames a computer according to company naming standards after migration.

.DESCRIPTION
    This script renames a Windows computer following a standardized naming convention:
    [DeviceType]-[Location]-[Serial]
    
    Format: XX-XXXX-XXXX
    - 2 character device type (DT, LT, TB, etc.)
    - 4 character location code (ACCT, EXEC, SALE, etc.)
    - Last 4 characters of device serial number
    
    Example: DT-ACCT-K94S (Desktop in Accounting with serial ending in K94S)
    
    The script validates the naming format, retrieves the device serial number,
    constructs the new name, and performs the rename operation with optional reboot.

.PARAMETER DeviceType
    2-character device type code. Common values:
    - DT: Desktop
    - LT: Laptop
    - TB: Tablet
    - VM: Virtual Machine
    - WS: Workstation

.PARAMETER LocationCode
    4-character location or department code. Examples:
    - ACCT: Accounting
    - EXEC: Executive
    - SALE: Sales
    - MRKT: Marketing
    - ENGG: Engineering
    - CORP: Corporate
    - HR00: Human Resources
    - IT00: IT Department

.PARAMETER AutoReboot
    Automatically reboots the computer after renaming without prompting.
    If not specified, the user will be prompted before reboot.

.PARAMETER NoReboot
    Skips the reboot entirely. Computer rename will take effect on next manual reboot.

.PARAMETER LogPath
    Path to write detailed log file. Defaults to C:\Windows\Temp\ComputerRename_[timestamp].log

.PARAMETER WhatIf
    Shows what would happen without actually renaming the computer.

.EXAMPLE
    .\Set-DeviceName.ps1 -DeviceType "DT" -LocationCode "ACCT"
    
    Prompts for confirmation, renames the desktop computer with Accounting location code,
    and prompts before reboot.

.EXAMPLE
    .\Set-DeviceName.ps1 -DeviceType "LT" -LocationCode "EXEC" -AutoReboot
    
    Renames the laptop with Executive location code and automatically reboots.

.EXAMPLE
    .\Set-DeviceName.ps1 -DeviceType "VM" -LocationCode "IT00" -NoReboot
    
    Renames the virtual machine with IT location code without rebooting.

.EXAMPLE
    .\Set-DeviceName.ps1 -DeviceType "DT" -LocationCode "ACCT" -WhatIf
    
    Shows what the new computer name would be without actually performing the rename.

.NOTES
    Author: W. Ford
    Company: Managed Solution LLC
    Date: 2026-01-02
    Version: 1.0
    
    Requirements:
    - PowerShell 5.1 or later
    - Local Administrator privileges
    - Windows OS (Windows 10/11, Server 2016+)
    
    The script automatically retrieves the device serial number from WMI/CIM.
    A reboot is required for the rename to take effect.
    
    Serial Number Sources (in order of preference):
    1. BIOS Serial Number (most reliable)
    2. System Serial Number
    3. Chassis Serial Number
    
    Exit Codes:
    0  - Success
    1  - Insufficient privileges
    2  - Failed to retrieve serial number
    3  - Invalid naming format
    4  - Rename operation failed

.LINK
    https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/rename-computer
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true, HelpMessage="2-character device type (DT, LT, TB, VM, WS)")]
    [ValidatePattern('^[A-Z]{2}$')]
    [ValidateLength(2,2)]
    [string]$DeviceType,
    
    [Parameter(Mandatory=$true, HelpMessage="4-character location code (ACCT, EXEC, SALE, etc.)")]
    [ValidatePattern('^[A-Z0-9]{4}$')]
    [ValidateLength(4,4)]
    [string]$LocationCode,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoReboot,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoReboot,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Windows\Temp\ComputerRename_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

#Requires -RunAsAdministrator

# ============================================================================
# INITIALIZE
# ============================================================================

$ErrorActionPreference = 'Stop'
$StartTime = Get-Date
$Script:LogPath = $LogPath

# Ensure log directory exists
$LogDirectory = Split-Path -Path $LogPath -Parent
if (!(Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info','Success','Warning','Error')]
        [string]$Level = 'Info'
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $Script:LogPath -Value $LogMessage
    
    # Write to console with color
    switch ($Level) {
        'Success' { Write-Host $Message -ForegroundColor Green }
        'Warning' { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        'Error'   { Write-Host "❌ $Message" -ForegroundColor Red }
        default   { Write-Host $Message -ForegroundColor Cyan }
    }
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DeviceSerialNumber {
    <#
    .SYNOPSIS
        Retrieves the device serial number from WMI/CIM.
    #>
    
    Write-Log "Retrieving device serial number..." -Level Info
    
    try {
        # Try BIOS Serial Number first (most reliable)
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
        $serialNumber = $bios.SerialNumber
        
        if ([string]::IsNullOrWhiteSpace($serialNumber) -or $serialNumber -match 'default|to be filled|not applicable|none|n/a|000000|123456|system serial number') {
            Write-Log "BIOS serial number not valid, trying system serial..." -Level Warning
            
            # Try System Serial Number
            $system = Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction Stop
            $serialNumber = $system.IdentifyingNumber
        }
        
        if ([string]::IsNullOrWhiteSpace($serialNumber) -or $serialNumber -match 'default|to be filled|not applicable|none|n/a|000000|123456') {
            Write-Log "System serial not valid, trying chassis serial..." -Level Warning
            
            # Try Chassis Serial Number as last resort
            $chassis = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction Stop
            $serialNumber = $chassis.SerialNumber
        }
        
        # Clean up serial number
        $serialNumber = $serialNumber.Trim() -replace '\s+', ''
        
        if ([string]::IsNullOrWhiteSpace($serialNumber)) {
            throw "Unable to retrieve a valid serial number from device"
        }
        
        Write-Log "✅ Retrieved serial number: $serialNumber" -Level Success
        return $serialNumber
    }
    catch {
        Write-Log "Failed to retrieve serial number: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Get-Last4Characters {
    param([string]$InputString)
    
    # Remove any non-alphanumeric characters
    $cleaned = $InputString -replace '[^A-Z0-9]', ''
    
    if ($cleaned.Length -ge 4) {
        return $cleaned.Substring($cleaned.Length - 4, 4).ToUpper()
    }
    else {
        # Pad with zeros if less than 4 characters
        return $cleaned.PadLeft(4, '0').ToUpper()
    }
}

function Test-ComputerNameLength {
    param([string]$ComputerName)
    
    # Windows NetBIOS name limit is 15 characters
    if ($ComputerName.Length -gt 15) {
        Write-Log "Computer name '$ComputerName' exceeds 15 character limit (length: $($ComputerName.Length))" -Level Warning
        return $false
    }
    return $true
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

Write-Log "===============================================" -Level Info
Write-Log "Computer Rename Script Started" -Level Info
Write-Log "===============================================" -Level Info
Write-Log "Script Version: 1.0" -Level Info
Write-Log "Executed by: $env:USERNAME" -Level Info
Write-Log "Current Computer Name: $env:COMPUTERNAME" -Level Info
Write-Log "" -Level Info

# Validate admin privileges
if (-not (Test-AdminPrivileges)) {
    Write-Log "This script requires Administrator privileges" -Level Error
    Write-Log "Please run PowerShell as Administrator and try again" -Level Error
    exit 1
}

Write-Log "✅ Running with Administrator privileges" -Level Success

# Validate conflicting parameters
if ($AutoReboot -and $NoReboot) {
    Write-Log "Cannot specify both -AutoReboot and -NoReboot" -Level Error
    exit 3
}

try {
    # Get device serial number
    $serialNumber = Get-DeviceSerialNumber
    $serialLast4 = Get-Last4Characters -InputString $serialNumber
    
    # Construct new computer name
    $newComputerName = "$DeviceType-$LocationCode-$serialLast4"
    
    Write-Log "" -Level Info
    Write-Log "Naming Convention Details:" -Level Info
    Write-Log "  Device Type:    $DeviceType" -Level Info
    Write-Log "  Location Code:  $LocationCode" -Level Info
    Write-Log "  Serial Number:  $serialNumber" -Level Info
    Write-Log "  Serial Last 4:  $serialLast4" -Level Info
    Write-Log "" -Level Info
    Write-Log "  New Name:       $newComputerName" -Level Success
    Write-Log "" -Level Info
    
    # Validate name length
    if (-not (Test-ComputerNameLength -ComputerName $newComputerName)) {
        Write-Log "Computer name validation failed" -Level Error
        exit 3
    }
    
    # Check if already named correctly
    if ($env:COMPUTERNAME -eq $newComputerName) {
        Write-Log "Computer is already named correctly: $newComputerName" -Level Success
        Write-Log "No rename operation needed" -Level Info
        exit 0
    }
    
    # WhatIf mode
    if ($WhatIf) {
        Write-Log "WhatIf: Would rename computer from '$env:COMPUTERNAME' to '$newComputerName'" -Level Info
        Write-Log "WhatIf: No changes made" -Level Info
        exit 0
    }
    
    # Confirm before proceeding
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  COMPUTER RENAME CONFIRMATION" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  Current Name:  " -NoNewline -ForegroundColor Cyan
    Write-Host "$env:COMPUTERNAME" -ForegroundColor White
    Write-Host "  New Name:      " -NoNewline -ForegroundColor Cyan
    Write-Host "$newComputerName" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    
    $confirmation = Read-Host "Proceed with rename? (Y/N)"
    if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
        Write-Log "Rename operation cancelled by user" -Level Warning
        exit 0
    }
    
    # Perform the rename
    Write-Log "Initiating computer rename..." -Level Info
    
    try {
        Rename-Computer -NewName $newComputerName -Force -ErrorAction Stop
        Write-Log "✅ Computer successfully renamed to: $newComputerName" -Level Success
        
        # Handle reboot
        Write-Log "" -Level Info
        Write-Log "A reboot is required for the name change to take effect" -Level Warning
        
        if ($NoReboot) {
            Write-Log "Reboot skipped as requested (-NoReboot)" -Level Info
            Write-Log "Please reboot the computer manually when ready" -Level Warning
        }
        elseif ($AutoReboot) {
            Write-Log "Auto-reboot enabled. Computer will restart in 30 seconds..." -Level Warning
            Write-Log "Press Ctrl+C to cancel reboot" -Level Info
            Start-Sleep -Seconds 5
            
            shutdown /r /t 30 /c "Computer renamed to $newComputerName. Restarting to apply changes." /d p:4:1
            Write-Log "Reboot scheduled" -Level Success
        }
        else {
            Write-Host "`n" -NoNewline
            $rebootChoice = Read-Host "Reboot now? (Y/N)"
            if ($rebootChoice -eq 'Y' -or $rebootChoice -eq 'y') {
                Write-Log "Initiating reboot..." -Level Info
                Restart-Computer -Force
            }
            else {
                Write-Log "Reboot postponed. Please reboot manually when ready." -Level Warning
            }
        }
    }
    catch {
        Write-Log "Failed to rename computer: $($_.Exception.Message)" -Level Error
        throw
    }
}
catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" -Level Error
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    
    # Determine appropriate exit code
    if ($_.Exception.Message -match 'serial') {
        exit 2
    }
    else {
        exit 4
    }
}
finally {
    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime
    Write-Log "" -Level Info
    Write-Log "===============================================" -Level Info
    Write-Log "Script completed in $($Duration.ToString('mm\:ss'))" -Level Info
    Write-Log "Log file: $LogPath" -Level Info
    Write-Log "===============================================" -Level Info
}
