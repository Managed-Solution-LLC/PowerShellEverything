<#
.SYNOPSIS
    Removes a computer from an Active Directory domain and joins it to a workgroup.

.DESCRIPTION
    This script removes the local computer from its current Active Directory domain
    and joins it to a specified workgroup. The computer will require a restart to
    complete the domain removal process.
    
    The script supports both local administrator credentials and remote execution
    via the -ComputerName parameter.

.PARAMETER WorkgroupName
    The name of the workgroup to join after removing from the domain.
    Default: "WORKGROUP"

.PARAMETER LocalUsername
    Local administrator username for the target computer.
    Required when removing from domain without stored credentials.

.PARAMETER LocalPassword
    Local administrator password for the target computer.
    If not provided, you will be prompted securely.

.PARAMETER ComputerName
    Remote computer name to execute on. If not specified, runs on local computer.
    Default: Local computer

.PARAMETER Force
    Skip confirmation prompts and proceed with domain removal.

.PARAMETER Restart
    Automatically restart the computer after removing from domain.
    Warning: This will interrupt any running processes.

.EXAMPLE
    .\Set-DomainJoin.ps1 -WorkgroupName "WORKGROUP"
    Removes the local computer from domain and joins WORKGROUP (requires restart).

.EXAMPLE
    .\Set-DomainJoin.ps1 -WorkgroupName "OFFSITE" -Restart
    Removes local computer from domain, joins OFFSITE workgroup, and restarts automatically.

.EXAMPLE
    .\Set-DomainJoin.ps1 -ComputerName "REMOTE-PC" -WorkgroupName "WORKGROUP" -LocalUsername "Admin" -Force
    Removes REMOTE-PC from domain and joins WORKGROUP without confirmation prompts.

.NOTES
    Author: W. Ford
    Date: 2025-01-10
    Version: 1.0
    
    Requirements:
    - PowerShell 5.1 or later
    - Administrator privileges on target computer
    - Network connectivity to target computer (for remote execution)
    - Valid local administrator credentials
    
    The computer will require a restart to complete the domain removal.
    It is recommended to save all work before executing this script.

.LINK
    https://docs.microsoft.com/windows/win32/cimwin32prov/win32-computersystem
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory=$false, HelpMessage="Workgroup name to join after domain removal")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkgroupName = "WORKGROUP",
    
    [Parameter(Mandatory=$false, HelpMessage="Local administrator username for target computer")]
    [string]$LocalUsername,
    
    [Parameter(Mandatory=$false, HelpMessage="Local administrator password")]
    [securestring]$LocalPassword,
    
    [Parameter(Mandatory=$false, HelpMessage="Remote computer name (blank for local computer)")]
    [string]$ComputerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false, HelpMessage="Skip confirmation prompts")]
    [switch]$Force,
    
    [Parameter(Mandatory=$false, HelpMessage="Automatically restart computer after domain removal")]
    [switch]$Restart
)

# Verify PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "❌ This script requires PowerShell 5.1 or later" -ForegroundColor Red
    exit 1
}

# Verify administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "❌ Administrator privileges required to remove computer from domain" -ForegroundColor Red
    exit 1
}

$Separator = "=" * 80

try {
    Write-Host "`n$Separator" -ForegroundColor Cyan
    Write-Host "DOMAIN REMOVAL AND WORKGROUP JOIN TOOL" -ForegroundColor Cyan
    Write-Host $Separator -ForegroundColor Cyan
    
    # Build credentials for remote execution if needed
    $invokeParams = @{
        ScriptBlock = {
            param($WorkgroupName)
            
            # Get current domain status
            $computerSystem = Get-WmiObject Win32_ComputerSystem
            $currentDomain = $computerSystem.Domain
            $partOf = $computerSystem.PartOfDomain
            
            if (-not $partOf) {
                Write-Host "⚠️  Computer is already in a workgroup: $($computerSystem.Workgroup)" -ForegroundColor Yellow
                return $false
            }
            
            Write-Host "Current Configuration:" -ForegroundColor White
            Write-Host "  Domain: $currentDomain" -ForegroundColor Gray
            Write-Host "  Part of Domain: $partOf" -ForegroundColor Gray
            Write-Host "  Target Workgroup: $WorkgroupName" -ForegroundColor Yellow
            
            # Remove from domain and join workgroup
            Write-Host "`nRemoving from domain and joining workgroup..." -ForegroundColor Yellow
            $result = $computerSystem.JoinDomainOrWorkgroup($WorkgroupName)
            
            if ($result.ReturnValue -eq 0) {
                Write-Host "✅ Successfully removed from domain and joined workgroup '$WorkgroupName'" -ForegroundColor Green
                return $true
            }
            else {
                Write-Host "❌ Failed to join workgroup. Error code: $($result.ReturnValue)" -ForegroundColor Red
                return $false
            }
        }
        ArgumentList = @($WorkgroupName)
    }
    
    # Add computer name if remote
    if ($ComputerName -ne $env:COMPUTERNAME) {
        # Prepare credentials for remote execution
        if (-not $LocalUsername) {
            Write-Host "Remote execution detected. Local administrator credentials required." -ForegroundColor Yellow
            $LocalUsername = Read-Host "Enter local administrator username"
        }
        
        if (-not $LocalPassword) {
            $LocalPassword = Read-Host -AsSecureString "Enter local administrator password"
        }
        
        $credential = New-Object System.Management.Automation.PSCredential($LocalUsername, $LocalPassword)
        $invokeParams.ComputerName = $ComputerName
        $invokeParams.Credential = $credential
    }
    
    # Confirm action
    if (-not $Force) {
        Write-Host "`n⚠️  WARNING: This action will remove the computer from the domain." -ForegroundColor Yellow
        Write-Host "   The computer will require a restart to complete this process." -ForegroundColor Yellow
        Write-Host "   All unsaved work should be saved before proceeding." -ForegroundColor Yellow
        
        $confirm = Read-Host "`nDo you want to continue? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Host "❌ Operation cancelled by user" -ForegroundColor Red
            exit 0
        }
    }
    
    # Execute domain removal
    $success = Invoke-Command @invokeParams
    
    if (-not $success) {
        Write-Host "❌ Domain removal failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`n$Separator" -ForegroundColor Cyan
    Write-Host "✅ Domain removal completed successfully" -ForegroundColor Green
    Write-Host "⚠️  Computer restart is required to complete the domain removal" -ForegroundColor Yellow
    Write-Host $Separator -ForegroundColor Cyan
    
    # Handle restart
    if ($Restart) {
        Write-Host "`n⏱️  Restarting computer in 60 seconds..." -ForegroundColor Cyan
        Write-Host "   Press [CTRL+C] to cancel" -ForegroundColor Gray
        
        if ($ComputerName -ne $env:COMPUTERNAME) {
            Restart-Computer -ComputerName $ComputerName -Force -Wait:$false
        }
        else {
            Start-Sleep -Seconds 60
            Restart-Computer -Force
        }
    }
    else {
        Write-Host "`nTo complete the process, restart the computer:" -ForegroundColor Yellow
        Write-Host "   Local: Restart-Computer -Force" -ForegroundColor Gray
        if ($ComputerName -ne $env:COMPUTERNAME) {
            Write-Host "   Remote: Restart-Computer -ComputerName '$ComputerName' -Force" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Verbose "Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}