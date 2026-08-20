#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Checks whether FortiClient is installed, and if not, checks whether it's
    assigned to this device via Intune and triggers a sync to pull the install.

.DESCRIPTION
    1. Checks the local uninstall registry for FortiClient.
    2. If not installed, reads the local Intune Management Extension (IME)
       "Reporting" registry cache to see if a FortiClient Win32 app is
       assigned to this device and what its compliance/install state is.
    3. If it's assigned but not yet installed, triggers an Intune sync
       (restarts the IME service + kicks the MDM scheduled tasks — the same
       effect as clicking "Sync" in Settings > Accounts > Access work or school)
       so the agent re-evaluates and pulls the install on its next check-in.

    This reads only the local machine's own IME cache/logs — no Graph API
    calls or credentials are involved, so it's safe to run via RMM against
    any Intune-managed endpoint.

.PARAMETER SkipSync
    Only checks and reports status; does not restart the IME service or
    trigger the MDM sync scheduled tasks.

.EXAMPLE
    .\Check-FortiClient-IntuneInstall.ps1

.EXAMPLE
    .\Check-FortiClient-IntuneInstall.ps1 -SkipSync
#>

[CmdletBinding()]
param(
    [switch]$SkipSync
)

function Test-FortiClientInstalled {
    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $found = Get-ItemProperty -Path $uninstallPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like '*FortiClient*' }
    return [bool]$found
}

function Get-IntuneFortiClientAssignment {
    $reportingRoot = 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Reporting'
    if (-not (Test-Path $reportingRoot)) {
        Write-Warning "IntuneManagementExtension Reporting registry key not found. Either IME hasn't run a Win32 app evaluation yet, or this device isn't managed by Intune's Win32 app agent."
        return $null
    }

    $matches = @()
    Get-ChildItem $reportingRoot -ErrorAction SilentlyContinue | ForEach-Object {
        $win32AppsPath = Join-Path $_.PsPath 'Win32Apps'
        if (Test-Path $win32AppsPath) {
            Get-ChildItem $win32AppsPath -ErrorAction SilentlyContinue | ForEach-Object {
                $csm = (Get-ItemProperty -Path $_.PsPath -Name 'ComplianceStateMessage' -ErrorAction SilentlyContinue).ComplianceStateMessage
                if ($csm) {
                    try {
                        $json = $csm | ConvertFrom-Json
                        if ($json.ApplicationName -like '*FortiClient*') {
                            $matches += [PSCustomObject]@{
                                ApplicationName = $json.ApplicationName
                                DesiredState    = $json.DesiredState
                                ComplianceState = $json.ComplianceState
                                ErrorCode       = $json.ErrorCode
                                RegistryKey     = $_.PsPath
                            }
                        }
                    }
                    catch { }
                }
            }
        }
    }
    return $matches
}

function Invoke-IntuneSync {
    Write-Host "Triggering Intune policy sync..."

    $svc = Get-Service -Name 'IntuneManagementExtension' -ErrorAction SilentlyContinue
    if ($svc) {
        Restart-Service -Name 'IntuneManagementExtension' -Force -ErrorAction SilentlyContinue
        Write-Host "  Restarted IntuneManagementExtension service."
    }
    else {
        Write-Warning "  IntuneManagementExtension service not found — this device may not be enrolled/managed by Intune."
    }

    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
        Where-Object { $_.TaskPath -like '*Microsoft\Windows\EnterpriseMgmt*' -and $_.TaskName -match 'PushLaunch|Schedule' }

    if ($tasks) {
        foreach ($task in $tasks) {
            Start-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
            Write-Host "  Started scheduled task: $($task.TaskPath)$($task.TaskName)"
        }
    }
    else {
        Write-Warning "  No MDM sync scheduled tasks found under EnterpriseMgmt."
    }
}

# ---- Main ----

if (Test-FortiClientInstalled) {
    Write-Host "FortiClient is already installed on this machine. No action needed."
    return
}

Write-Host "FortiClient is NOT installed. Checking the local Intune cache for an assigned install..."

$assignment = Get-IntuneFortiClientAssignment

if ($assignment) {
    Write-Host "`nFortiClient IS targeted to this device via Intune:"
    $assignment | Format-List

    # ComplianceState: 1 = Compliant/Installed in most IME reporting payloads
    $pending = $assignment | Where-Object { $_.ComplianceState -ne 1 }

    if ($pending -and -not $SkipSync) {
        Write-Host "`nInstall appears pending / not yet compliant. Triggering a sync to pull it down now..."
        Invoke-IntuneSync
        Write-Host "`nSync triggered. The Win32 app agent checks in on its own schedule (typically within a few minutes up to ~1 hour)."
        Write-Host "Re-run this script later, or check the log directly:"
        Write-Host "  $env:ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
    }
    elseif ($pending -and $SkipSync) {
        Write-Host "`nInstall appears pending / not yet compliant. (Sync skipped due to -SkipSync.)"
    }
    else {
        Write-Host "`nIntune reports this as compliant/installed, but FortiClient wasn't found locally — worth checking the IME install log for an error:"
        Write-Host "  $env:ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
    }
}
else {
    Write-Host "`nNo FortiClient Win32 app assignment found in the local Intune Management Extension cache."
    Write-Host "This means either:"
    Write-Host "  - FortiClient isn't assigned to this device or user group in Intune, or"
    Write-Host "  - This device hasn't synced with Intune's Win32 app agent yet."

    if (-not $SkipSync) {
        Write-Host "`nTriggering a sync in case a new assignment just hasn't been picked up yet..."
        Invoke-IntuneSync
        Write-Host "`nRe-run this script in a few minutes to see if the assignment/install shows up."
    }
}