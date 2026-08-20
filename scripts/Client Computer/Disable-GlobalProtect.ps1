#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables Palo Alto GlobalProtect on this machine.

.DESCRIPTION
    Stops the GlobalProtect service(s) and agent process, then sets the
    service startup type to Disabled so it does not come back on reboot
    or user logon. Must be run as Administrator.

    Includes a -Uninstall switch to fully remove the GlobalProtect app
    instead of just disabling it.

.PARAMETER Uninstall
    If specified, fully uninstalls GlobalProtect instead of just disabling it.

.EXAMPLE
    .\Disable-GlobalProtect.ps1
    Stops and disables the GlobalProtect service/agent (re-enable-able later).

.EXAMPLE
    .\Disable-GlobalProtect.ps1 -Uninstall
    Fully removes GlobalProtect from the machine.
#>

[CmdletBinding()]
param(
    [switch]$Uninstall
)

# Re-launch elevated if not already running as admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and 'Run as Administrator', then re-run this script."
    exit 1
}

# --- Known GlobalProtect service names (varies slightly by version) ---
$serviceNames = @('PanGPS', 'PanGpHip', 'PanGPService')

# --- Known GlobalProtect process names ---
$processNames = @('PanGPA', 'PanGPS')

function Stop-And-Disable-GlobalProtect {
    foreach ($svcName in $serviceNames) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Host "Stopping service: $svcName ..."
            Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue

            Write-Host "Setting startup type to Disabled: $svcName"
            Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }

    foreach ($procName in $processNames) {
        $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Host "Stopping process: $procName"
            Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "`nGlobalProtect has been stopped and disabled."
    Write-Host "To re-enable it later, run:"
    Write-Host "  Set-Service -Name PanGPS -StartupType Automatic; Start-Service -Name PanGPS"
}

function Uninstall-GlobalProtect {
    Write-Host "Looking for GlobalProtect installation..."

    # Try the standard uninstall via WMI/CIM (works for MSI-based installs)
    $app = Get-CimInstance -ClassName Win32_Product -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*GlobalProtect*' }

    if ($app) {
        foreach ($a in $app) {
            Write-Host "Uninstalling: $($a.Name) ($($a.IdentifyingNumber))"
            $a | Invoke-CimMethod -MethodName Uninstall | Out-Null
        }
        Write-Host "Uninstall complete."
        return
    }

    # Fallback: check registry uninstall keys for the quiet-uninstall string
    $uninstallKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $entry = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like '*GlobalProtect*' } |
        Select-Object -First 1

    if ($entry -and $entry.QuietUninstallString) {
        Write-Host "Running: $($entry.QuietUninstallString)"
        Start-Process cmd.exe -ArgumentList "/c `"$($entry.QuietUninstallString)`"" -Wait
        Write-Host "Uninstall complete."
    }
    elseif ($entry -and $entry.UninstallString) {
        Write-Host "Running: $($entry.UninstallString) /quiet /norestart"
        Start-Process cmd.exe -ArgumentList "/c `"$($entry.UninstallString)`" /quiet /norestart" -Wait
        Write-Host "Uninstall complete."
    }
    else {
        Write-Warning "Could not automatically locate a GlobalProtect uninstaller. Falling back to disabling the service/process instead."
        Stop-And-Disable-GlobalProtect
    }
}

if ($Uninstall) {
    Uninstall-GlobalProtect
} else {
    Stop-And-Disable-GlobalProtect
}