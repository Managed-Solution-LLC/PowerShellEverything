<#
.SYNOPSIS
    Revokes all active sessions, disconnects registered devices, and blocks sign-in for one or
    more Entra ID / Microsoft 365 accounts.

.DESCRIPTION
    Designed for offboarding, incident response, or account compromise scenarios. For each
    targeted account this script will:

    1. Block sign-in  - Sets AccountEnabled = $false so no new authentications succeed.
    2. Revoke sessions - Calls Revoke-MgUserSignInSession to invalidate all existing refresh
       tokens and active sessions immediately.
    3. Report devices  - Lists all Entra ID-registered and Entra ID-joined devices owned by
       the account.
    4. Disable devices - When -DisableDevices is specified, sets each owned device to
       AccountEnabled = $false in Entra ID so it can no longer authenticate.

    Supports bulk operation via CSV file, an in-memory array, or a single UPN/Object ID.
    All results are written to a timestamped CSV report.

    Required Microsoft Graph permissions (delegated or app):
        User.ReadWrite.All
        Directory.ReadWrite.All
        Device.ReadWrite.All

.PARAMETER CsvPath
    Path to a CSV file containing accounts to process.
    Required column: Identity (UPN or Entra Object ID)
    Optional column: Reason (logged to the results report)
    Use -GenerateTemplate to create a pre-formatted template file.

.PARAMETER UserArray
    Array of PSCustomObjects or hashtables with at minimum an Identity property.
    Useful for pipeline or in-memory scenarios.

.PARAMETER Identity
    Single UPN or Entra Object ID for a one-off operation.

.PARAMETER DisableDevices
    When specified, disables all Entra ID-registered devices owned by each target account.
    Without this switch the script reports devices but does not modify them.

.PARAMETER SkipBlockSignIn
    When specified, skips setting AccountEnabled = $false.
    Useful when you only want to revoke sessions without fully locking the account.

.PARAMETER SkipRevokeSession
    When specified, skips the Revoke-MgUserSignInSession call.
    Useful when you only want to block sign-in or disable devices.

.PARAMETER OutputDirectory
    Directory where the results CSV report will be saved.
    Default: C:\Reports\CSV_Exports

.PARAMETER GenerateTemplate
    Creates a blank CSV template in -OutputDirectory and exits without processing accounts.

.PARAMETER WhatIf
    Shows what changes would be made without actually making them.

.EXAMPLE
    .\Invoke-UserSignOutAndBlock.ps1 -Identity "jdoe@contoso.com"

    Blocks sign-in and revokes all sessions for a single account.

.EXAMPLE
    .\Invoke-UserSignOutAndBlock.ps1 -Identity "jdoe@contoso.com" -DisableDevices

    Blocks sign-in, revokes sessions, and disables all Entra ID-joined/registered devices
    owned by the account.

.EXAMPLE
    .\Invoke-UserSignOutAndBlock.ps1 -CsvPath "C:\Data\offboard.csv" -DisableDevices

    Processes a list of accounts from CSV, blocking sign-in, revoking sessions, and
    disabling all associated devices.

.EXAMPLE
    .\Invoke-UserSignOutAndBlock.ps1 -CsvPath "C:\Data\offboard.csv" -WhatIf

    Validates all accounts in the CSV and shows what would happen without making any changes.

.EXAMPLE
    .\Invoke-UserSignOutAndBlock.ps1 -GenerateTemplate -OutputDirectory "C:\Reports"

    Creates a blank CSV template at C:\Reports\UserSignOutAndBlock_Template.csv.

.NOTES
    Author: William Ford
    Date: 2026-03-13
    Version: 1.0

    Requirements:
    - PowerShell 5.1 or PowerShell 7+
    - Microsoft.Graph.Authentication module
    - Microsoft.Graph.Users module
    - Microsoft.Graph.Identity.DirectoryManagement module (for device management)
    - Permissions: User.ReadWrite.All, Directory.ReadWrite.All, Device.ReadWrite.All

    Behavior notes:
    - Revoking sessions is near-immediate for new resource access attempts, but existing
      short-lived access tokens (typically 1-hour lifetime) remain valid until expiry.
      Blocking sign-in prevents renewal of those tokens.
    - Device disablement prevents the device from authenticating to Entra ID. The user's
      local session on the device may remain active until idle timeout or manual sign-out.
    - This script does NOT wipe or retire managed devices from Intune. Use the Intune
      portal or dedicated scripts for remote wipe operations.

.LINK
    https://learn.microsoft.com/en-us/graph/api/user-revokesigninsessions
    https://learn.microsoft.com/en-us/graph/api/user-update
    https://learn.microsoft.com/en-us/graph/api/device-update
#>

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Identity')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Csv', HelpMessage = 'Path to CSV file with Identity column')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'Array', HelpMessage = 'Array of objects with Identity property')]
    [object[]]$UserArray,

    [Parameter(Mandatory = $true, ParameterSetName = 'Identity', HelpMessage = 'UPN or Entra Object ID of the account')]
    [ValidateNotNullOrEmpty()]
    [string]$Identity,

    [Parameter(Mandatory = $false, HelpMessage = 'Disable all Entra ID-registered devices owned by the account')]
    [switch]$DisableDevices,

    [Parameter(Mandatory = $false, HelpMessage = 'Skip blocking sign-in (AccountEnabled = $false)')]
    [switch]$SkipBlockSignIn,

    [Parameter(Mandatory = $false, HelpMessage = 'Skip revoking active sessions and refresh tokens')]
    [switch]$SkipRevokeSession,

    [Parameter(Mandatory = $false, HelpMessage = 'Directory for the results CSV report')]
    [string]$OutputDirectory = 'C:\Reports\CSV_Exports',

    [Parameter(Mandatory = $false, ParameterSetName = 'Template', HelpMessage = 'Generate a blank CSV template and exit')]
    [switch]$GenerateTemplate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region ── Helpers ─────────────────────────────────────────────────────────────

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Section')]
        [string]$Type = 'Info'
    )
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    switch ($Type) {
        'Section'  { Write-Host "`n$('─' * 70)`n  $Message`n$('─' * 70)" -ForegroundColor Cyan }
        'Success'  { Write-Host "[$ts] ✅ $Message" -ForegroundColor Green }
        'Warning'  { Write-Host "[$ts] ⚠️  $Message" -ForegroundColor Yellow; $script:WarningCount++ }
        'Error'    { Write-Host "[$ts] ❌ $Message" -ForegroundColor Red;    $script:ErrorCount++ }
        default    { Write-Host "[$ts]    $Message" -ForegroundColor Cyan }
    }
}

#endregion

#region ── Template generation ─────────────────────────────────────────────────

if ($GenerateTemplate) {
    if (!(Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    $TemplatePath = Join-Path $OutputDirectory 'UserSignOutAndBlock_Template.csv'
    @'
Identity,Reason
jdoe@contoso.com,Account compromise - ticket INC0012345
jane.smith@contoso.com,Offboarding
'@ | Out-File -FilePath $TemplatePath -Encoding UTF8 -Force
    Write-Status "Template created: $TemplatePath" -Type Success
    exit 0
}

#endregion

#region ── Tracking variables ──────────────────────────────────────────────────

$StartTime    = Get-Date
$ErrorCount   = 0
$WarningCount = 0
$Results      = [System.Collections.Generic.List[PSCustomObject]]::new()

#endregion

#region ── Output directory ────────────────────────────────────────────────────

if (!(Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
        Write-Status "Created output directory: $OutputDirectory" -Type Success
    }
    catch {
        Write-Status "Cannot create output directory: $($_.Exception.Message)" -Type Error
        exit 1
    }
}

# Verify write access
$TestFile = Join-Path $OutputDirectory "write_test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
try {
    'test' | Out-File -FilePath $TestFile -ErrorAction Stop
    Remove-Item $TestFile -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Status "No write permission to output directory: $OutputDirectory" -Type Error
    exit 1
}

#endregion

#region ── Module checks ───────────────────────────────────────────────────────

Write-Status 'Checking required modules...' -Type Section

$RequiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Users',
    'Microsoft.Graph.Identity.DirectoryManagement'
)

$MissingModules = $RequiredModules | Where-Object { -not (Get-Module -Name $_ -ListAvailable) }
if ($MissingModules) {
    Write-Status "Missing required modules: $($MissingModules -join ', ')" -Type Error
    Write-Host "  Install with: Install-Module $($MissingModules -join ', ') -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

foreach ($Mod in $RequiredModules) {
    try {
        Import-Module $Mod -ErrorAction Stop
        Write-Status "Module loaded: $Mod" -Type Success
    }
    catch {
        Write-Status "Failed to import module '$Mod': $($_.Exception.Message)" -Type Error
        exit 1
    }
}

#endregion

#region ── Graph connection ────────────────────────────────────────────────────

Write-Status 'Connecting to Microsoft Graph...' -Type Section

try {
    $RequiredScopes = @(
        'User.ReadWrite.All',
        'Directory.ReadWrite.All',
        'Device.ReadWrite.All'
    )
    Connect-MgGraph -Scopes $RequiredScopes -NoWelcome -ErrorAction Stop
    $GraphContext = Get-MgContext
    if (-not $GraphContext) { throw 'Get-MgContext returned null after connection.' }
    Write-Status "Connected to Microsoft Graph as: $($GraphContext.Account)" -Type Success
}
catch {
    Write-Status "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -Type Error
    exit 1
}

#endregion

#region ── Build target list ───────────────────────────────────────────────────

$TargetList = switch ($PSCmdlet.ParameterSetName) {
    'Csv'      { Import-Csv -Path $CsvPath }
    'Array'    { $UserArray }
    'Identity' { @([PSCustomObject]@{ Identity = $Identity; Reason = 'Manual run' }) }
}

if (-not $TargetList -or ($TargetList | Measure-Object).Count -eq 0) {
    Write-Status 'No accounts found in the provided input.' -Type Warning
    exit 0
}

Write-Status "Accounts to process: $(($TargetList | Measure-Object).Count)" -Type Section

#endregion

#region ── Process each account ────────────────────────────────────────────────

foreach ($Entry in $TargetList) {

    $UserIdentity = $Entry.Identity
    $Reason       = if ($Entry.PSObject.Properties['Reason']) { $Entry.Reason } else { 'Not specified' }

    $ResultRow = [PSCustomObject]@{
        Identity          = $UserIdentity
        DisplayName       = ''
        Reason            = $Reason
        SignInBlocked     = 'Skipped'
        SessionsRevoked   = 'Skipped'
        DevicesFound      = 0
        DevicesDisabled   = 0
        DeviceNames       = ''
        Status            = ''
        ErrorDetails      = ''
        Timestamp         = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }

    Write-Host ''
    Write-Status "Processing: $UserIdentity" -Type Info

    # ── Resolve user ──────────────────────────────────────────────────────────
    try {
        $MgUser = Get-MgUser -UserId $UserIdentity `
                             -Property 'Id,DisplayName,UserPrincipalName,AccountEnabled' `
                             -ErrorAction Stop
        $ResultRow.DisplayName = $MgUser.DisplayName
        Write-Status "Resolved: $($MgUser.DisplayName) ($($MgUser.UserPrincipalName))" -Type Info
        Write-Status "  Current AccountEnabled: $($MgUser.AccountEnabled)" -Type Info
    }
    catch {
        $ResultRow.Status      = 'Failed'
        $ResultRow.ErrorDetails = "User not found or access denied: $($_.Exception.Message)"
        Write-Status "$($ResultRow.ErrorDetails)" -Type Error
        $Results.Add($ResultRow)
        continue
    }

    $UserEncounteredError = $false

    # ── Block sign-in ─────────────────────────────────────────────────────────
    if (-not $SkipBlockSignIn) {
        if ($PSCmdlet.ShouldProcess($UserIdentity, 'Block sign-in (AccountEnabled = $false)')) {
            try {
                Update-MgUser -UserId $MgUser.Id -AccountEnabled:$false -ErrorAction Stop
                $ResultRow.SignInBlocked = 'Success'
                Write-Status "Sign-in blocked for $($MgUser.DisplayName)" -Type Success
            }
            catch {
                $ResultRow.SignInBlocked = 'Failed'
                $ResultRow.ErrorDetails += "BlockSignIn: $($_.Exception.Message); "
                Write-Status "Failed to block sign-in: $($_.Exception.Message)" -Type Error
                $UserEncounteredError = $true
            }
        }
        else {
            $ResultRow.SignInBlocked = 'WhatIf'
            Write-Status "[WhatIf] Would block sign-in for $($MgUser.DisplayName)" -Type Warning
        }
    }

    # ── Revoke sessions ───────────────────────────────────────────────────────
    if (-not $SkipRevokeSession) {
        if ($PSCmdlet.ShouldProcess($UserIdentity, 'Revoke all sign-in sessions and refresh tokens')) {
            try {
                $null = Invoke-MgInvalidateAllUserRefreshToken -UserId $MgUser.Id -ErrorAction Stop
                $ResultRow.SessionsRevoked = 'Success'
                Write-Status "All sessions and refresh tokens revoked for $($MgUser.DisplayName)" -Type Success
            }
            catch {
                # Fall back to the beta/v1 alias if needed
                try {
                    $null = Revoke-MgUserSignInSession -UserId $MgUser.Id -ErrorAction Stop
                    $ResultRow.SessionsRevoked = 'Success'
                    Write-Status "All sessions revoked for $($MgUser.DisplayName)" -Type Success
                }
                catch {
                    $ResultRow.SessionsRevoked = 'Failed'
                    $ResultRow.ErrorDetails   += "RevokeSession: $($_.Exception.Message); "
                    Write-Status "Failed to revoke sessions: $($_.Exception.Message)" -Type Error
                    $UserEncounteredError = $true
                }
            }
        }
        else {
            $ResultRow.SessionsRevoked = 'WhatIf'
            Write-Status "[WhatIf] Would revoke all sessions for $($MgUser.DisplayName)" -Type Warning
        }
    }

    # ── Devices ───────────────────────────────────────────────────────────────
    try {
        $OwnedDevices = @(Get-MgUserOwnedDevice -UserId $MgUser.Id -ErrorAction Stop)
        $ResultRow.DevicesFound = $OwnedDevices.Count

        if ($OwnedDevices.Count -gt 0) {
            $DeviceNameList = [System.Collections.Generic.List[string]]::new()
            $DisabledCount  = 0

            foreach ($DeviceRef in $OwnedDevices) {
                # OwnedDevice returns a DirectoryObject; re-query for device details
                try {
                    $Device = Get-MgDevice -DeviceId $DeviceRef.Id -Property 'Id,DisplayName,AccountEnabled,OperatingSystem,OperatingSystemVersion' -ErrorAction Stop
                    $DeviceNameList.Add("$($Device.DisplayName) [$($Device.OperatingSystem)]")

                    Write-Status "  Device: $($Device.DisplayName) | OS: $($Device.OperatingSystem) $($Device.OperatingSystemVersion) | Enabled: $($Device.AccountEnabled)" -Type Info

                    if ($DisableDevices) {
                        if ($PSCmdlet.ShouldProcess($Device.DisplayName, "Disable Entra ID device")) {
                            try {
                                Update-MgDevice -DeviceId $Device.Id -AccountEnabled:$false -ErrorAction Stop
                                $DisabledCount++
                                Write-Status "  Device disabled: $($Device.DisplayName)" -Type Success
                            }
                            catch {
                                Write-Status "  Failed to disable device '$($Device.DisplayName)': $($_.Exception.Message)" -Type Error
                                $ResultRow.ErrorDetails += "Device[$($Device.DisplayName)]: $($_.Exception.Message); "
                                $UserEncounteredError    = $true
                            }
                        }
                        else {
                            Write-Status "  [WhatIf] Would disable device: $($Device.DisplayName)" -Type Warning
                        }
                    }
                }
                catch {
                    Write-Status "  Could not retrieve device details for ID $($DeviceRef.Id): $($_.Exception.Message)" -Type Warning
                }
            }

            $ResultRow.DevicesDisabled = $DisabledCount
            $ResultRow.DeviceNames     = $DeviceNameList -join ' | '
        }
        else {
            Write-Status "  No Entra ID-registered devices found for $($MgUser.DisplayName)" -Type Info
        }
    }
    catch {
        Write-Status "Failed to retrieve devices for '$UserIdentity': $($_.Exception.Message)" -Type Warning
        $ResultRow.ErrorDetails += "GetDevices: $($_.Exception.Message); "
    }

    # ── Row status ────────────────────────────────────────────────────────────
    $ResultRow.Status = if ($UserEncounteredError) { 'CompletedWithErrors' } else { 'Success' }
    $Results.Add($ResultRow)

    Write-Status "Finished: $($MgUser.DisplayName) — $($ResultRow.Status)" -Type $(if ($UserEncounteredError) { 'Warning' } else { 'Success' })
}

#endregion

#region ── Export results ──────────────────────────────────────────────────────

$Timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$OutputFile = Join-Path $OutputDirectory "UserSignOutAndBlock_Results_$Timestamp.csv"

try {
    $Results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    Write-Status "Results exported to: $OutputFile" -Type Success
}
catch {
    Write-Status "Failed to export results CSV: $($_.Exception.Message)" -Type Error
}

#endregion

#region ── Summary ─────────────────────────────────────────────────────────────

$Duration    = (Get-Date) - $StartTime
$SuccessRows = ($Results | Where-Object { $_.Status -eq 'Success' }).Count
$FailedRows  = ($Results | Where-Object { $_.Status -eq 'Failed' }).Count
$PartialRows = ($Results | Where-Object { $_.Status -eq 'CompletedWithErrors' }).Count
$TotalDevicesDisabled = ($Results | Measure-Object -Property DevicesDisabled -Sum).Sum

Write-Host "`n$('═' * 70)" -ForegroundColor Cyan
Write-Host '  SIGN-OUT & BLOCK SUMMARY' -ForegroundColor Cyan
Write-Host "$('═' * 70)" -ForegroundColor Cyan
Write-Host "  Total accounts processed : $($Results.Count)"
Write-Host "  Fully successful         : $SuccessRows"    -ForegroundColor Green
Write-Host "  Completed with errors    : $PartialRows"    -ForegroundColor $(if ($PartialRows -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  Failed (skipped)         : $FailedRows"     -ForegroundColor $(if ($FailedRows   -gt 0) { 'Red'    } else { 'Green' })
Write-Host "  Devices disabled         : $TotalDevicesDisabled"
Write-Host "  Warnings                 : $WarningCount"
Write-Host "  Errors                   : $ErrorCount"     -ForegroundColor $(if ($ErrorCount   -gt 0) { 'Red'    } else { 'Green' })
Write-Host "  Elapsed time             : $($Duration.ToString('mm\:ss'))"
Write-Host "  Results file             : $OutputFile"
Write-Host "$('═' * 70)" -ForegroundColor Cyan

#endregion

#region ── Disconnect ──────────────────────────────────────────────────────────

try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Write-Status 'Disconnected from Microsoft Graph.' -Type Info
}
catch {
    # Non-fatal; ignore disconnect errors
}

#endregion
