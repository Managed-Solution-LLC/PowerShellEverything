<#
.SYNOPSIS
    Sets SMTP forwarding on Exchange Online mailboxes from a CSV file or input array.

.DESCRIPTION
    Configures SMTP forwarding for one or more Exchange Online mailboxes in bulk.
    Supports CSV input, inline array input, or single-user parameters.

    Key capabilities:
    - Set or clear ForwardingSmtpAddress on any mailbox
    - Control whether mail is also delivered to the original mailbox (DeliverToMailboxAndForward)
    - Optionally update the tenant outbound spam filter policy to permit auto-forwarding
    - Generates a timestamped CSV results report of all actions taken
    - Comprehensive error handling and colored status output

    Required CSV columns:
        Identity                - UPN or email address of the mailbox to configure
        ForwardingAddress       - SMTP address to forward to (leave blank to clear forwarding)
        DeliverToMailboxAndForward - TRUE/FALSE; keep a copy in the original mailbox

.PARAMETER CsvPath
    Path to a CSV file containing forwarding assignments.
    Required columns: Identity, ForwardingAddress, DeliverToMailboxAndForward
    Use -GenerateTemplate to create a pre-formatted template.

.PARAMETER UserArray
    Array of PSCustomObjects or hashtables with the same columns as the CSV.
    Useful for pipeline or in-memory data scenarios.

.PARAMETER Identity
    Single user UPN or email address. Used with -ForwardingAddress for one-off changes.

.PARAMETER ForwardingAddress
    SMTP address to forward to. Leave empty or omit to clear forwarding on the -Identity mailbox.

.PARAMETER DeliverToMailboxAndForward
    When $true, mail is delivered to BOTH the original mailbox and the forwarding address.
    Default: $true

.PARAMETER AllowAutoForward
    When specified, updates the Default outbound spam filter policy to permit auto-forwarding
    (sets AutoForwardingMode to "On"). This is a tenant-wide setting.

    WARNING: This changes a security policy. Only use when your organization requires
    external auto-forwarding and you have documented approval.

.PARAMETER OutputDirectory
    Directory for the results CSV report.
    Default: C:\Reports\CSV_Exports

.PARAMETER GenerateTemplate
    Creates a blank CSV template file in -OutputDirectory and exits.
    Use this to generate a correctly formatted input file.

.PARAMETER WhatIf
    Simulates all changes without applying them. Useful for validating your input data.

.EXAMPLE
    .\Set-SMTPForward.ps1 -CsvPath "C:\Data\forwards.csv"

    Applies forwarding rules from the CSV. Connects to Exchange Online interactively.

.EXAMPLE
    .\Set-SMTPForward.ps1 -CsvPath "C:\Data\forwards.csv" -AllowAutoForward

    Applies forwarding rules AND updates the outbound spam policy to allow auto-forwarding.

.EXAMPLE
    .\Set-SMTPForward.ps1 -Identity "jsmith@contoso.com" -ForwardingAddress "jsmith-alt@fabrikam.com"

    Sets forwarding on a single mailbox, keeping a copy in the original mailbox (default).

.EXAMPLE
    .\Set-SMTPForward.ps1 -Identity "jsmith@contoso.com"

    Clears (removes) forwarding from a single mailbox.

.EXAMPLE
    .\Set-SMTPForward.ps1 -GenerateTemplate -OutputDirectory "C:\Data"

    Generates a blank CSV template at C:\Data\SMTPForward_Template.csv and exits.

.EXAMPLE
    $forwards = @(
        [PSCustomObject]@{ Identity = "alice@contoso.com"; ForwardingAddress = "alice@fabrikam.com"; DeliverToMailboxAndForward = $true }
        [PSCustomObject]@{ Identity = "bob@contoso.com";   ForwardingAddress = "";                  DeliverToMailboxAndForward = $false }
    )
    .\Set-SMTPForward.ps1 -UserArray $forwards

    Passes an in-memory array directly to the script.

.NOTES
    Author: W. Ford
    Date: 2026-03-13
    Version: 1.0

    Requirements:
    - PowerShell 5.1 or later (PowerShell 7 recommended)
    - ExchangeOnlineManagement module (Install-Module ExchangeOnlineManagement -Scope CurrentUser)
    - Exchange Online Administrator or Exchange Recipient Administrator role

    Output:
    - Console status messages with color-coded results
    - Timestamped CSV results report in -OutputDirectory

    Notes on AutoForwardingMode:
    - "Automatic" (default): Respects the Remote Domain auto-forward setting
    - "On":  Permits auto-forwarding regardless of Remote Domain settings
    - "Off": Blocks all auto-forwarding tenant-wide

.LINK
    https://learn.microsoft.com/powershell/module/exchange/set-mailbox
    https://learn.microsoft.com/powershell/module/exchange/set-hostedoutboundspamfilterpolicy
#>

[CmdletBinding(DefaultParameterSetName = 'CSV', SupportsShouldProcess = $true)]
param (
    # ---- Input methods ----
    [Parameter(Mandatory = $true, ParameterSetName = 'CSV', HelpMessage = "Path to input CSV file")]
    [ValidateNotNullOrEmpty()]
    [string]$CsvPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'Array', HelpMessage = "Array of forwarding objects")]
    [ValidateNotNullOrEmpty()]
    [object[]]$UserArray,

    [Parameter(Mandatory = $true, ParameterSetName = 'Single', HelpMessage = "UPN or email of the mailbox to configure")]
    [ValidateNotNullOrEmpty()]
    [string]$Identity,

    [Parameter(Mandatory = $false, ParameterSetName = 'Single', HelpMessage = "SMTP address to forward to. Omit to clear forwarding.")]
    [string]$ForwardingAddress = "",

    [Parameter(Mandatory = $false, ParameterSetName = 'Single')]
    [bool]$DeliverToMailboxAndForward = $true,

    [Parameter(Mandatory = $true, ParameterSetName = 'Template', HelpMessage = "Generate a blank CSV template and exit")]
    [switch]$GenerateTemplate,

    # ---- Behaviour options ----
    [Parameter(Mandatory = $false, HelpMessage = "Update outbound spam filter policy to allow auto-forwarding")]
    [switch]$AllowAutoForward,

    [Parameter(Mandatory = $false, HelpMessage = "Output directory for results CSV")]
    [string]$OutputDirectory = "C:\Reports\CSV_Exports"
)

#region ── Helpers ─────────────────────────────────────────────────────────────

$Separator    = "=" * 80
$SubSeparator = "-" * 60
$Timestamp    = Get-Date -Format 'yyyyMMdd_HHmmss'
$ErrorCount   = 0
$WarningCount = 0
$Results      = [System.Collections.Generic.List[PSCustomObject]]::new()

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info','Success','Warning','Error')][string]$Type = 'Info'
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Type) {
        'Success' { Write-Host "[$ts] ✅ $Message" -ForegroundColor Green }
        'Warning' { Write-Host "[$ts] ⚠️  $Message" -ForegroundColor Yellow; $script:WarningCount++ }
        'Error'   { Write-Host "[$ts] ❌ $Message" -ForegroundColor Red;    $script:ErrorCount++   }
        default   { Write-Host "[$ts] ℹ️  $Message" -ForegroundColor Cyan  }
    }
}

function Add-Result {
    param(
        [string]$Identity,
        [string]$ForwardingAddress,
        [string]$DeliverToMailboxAndForward,
        [string]$Status,
        [string]$Details = ""
    )
    $script:Results.Add([PSCustomObject]@{
        Identity                   = $Identity
        ForwardingAddress          = $ForwardingAddress
        DeliverToMailboxAndForward = $DeliverToMailboxAndForward
        Status                     = $Status
        Details                    = $Details
        Timestamp                  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    })
}

#endregion

#region ── Template generation ──────────────────────────────────────────────────

if ($PSCmdlet.ParameterSetName -eq 'Template') {
    if (!(Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    $TemplatePath = Join-Path $OutputDirectory "SMTPForward_Template.csv"
    @"
Identity,ForwardingAddress,DeliverToMailboxAndForward
jsmith@contoso.com,jsmith-ext@fabrikam.com,TRUE
agarcia@contoso.com,,FALSE
"@ | Out-File -FilePath $TemplatePath -Encoding UTF8 -Force
    Write-Host "✅ Template created: $TemplatePath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Column reference:" -ForegroundColor Cyan
    Write-Host "  Identity                   - UPN or primary SMTP of the source mailbox"
    Write-Host "  ForwardingAddress          - Target SMTP address; leave blank to CLEAR forwarding"
    Write-Host "  DeliverToMailboxAndForward - TRUE = keep copy in source mailbox; FALSE = forward only"
    exit 0
}

#endregion

#region ── Pre-flight checks ────────────────────────────────────────────────────

Write-Host ""
Write-Host $Separator -ForegroundColor Cyan
Write-Host "  Set-SMTPForward  |  Exchange Online Bulk Forwarding Tool" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

# PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Status "PowerShell 5.1 or later is required." -Type Error
    exit 1
}

# Required module
if (-not (Get-Module -Name ExchangeOnlineManagement -ListAvailable)) {
    Write-Status "ExchangeOnlineManagement module not installed." -Type Error
    Write-Host "   Install with: Install-Module ExchangeOnlineManagement -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Output directory
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

# Write permission test
$TestFile = Join-Path $OutputDirectory "writetest_$Timestamp.tmp"
try {
    "test" | Out-File -FilePath $TestFile -ErrorAction Stop
    Remove-Item $TestFile -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Status "No write permission to output directory: $OutputDirectory" -Type Error
    exit 1
}

#endregion

#region ── Build the work list ──────────────────────────────────────────────────

$WorkList = [System.Collections.Generic.List[PSCustomObject]]::new()

switch ($PSCmdlet.ParameterSetName) {

    'CSV' {
        if (-not (Test-Path $CsvPath)) {
            Write-Status "CSV file not found: $CsvPath" -Type Error
            exit 1
        }
        try {
            $RawCsv = Import-Csv -Path $CsvPath -ErrorAction Stop
        }
        catch {
            Write-Status "Failed to import CSV: $($_.Exception.Message)" -Type Error
            exit 1
        }

        # Validate required columns
        $RequiredColumns = @('Identity', 'ForwardingAddress', 'DeliverToMailboxAndForward')
        $CsvHeaders = $RawCsv[0].PSObject.Properties.Name
        $MissingCols = $RequiredColumns | Where-Object { $_ -notin $CsvHeaders }
        if ($MissingCols) {
            Write-Status "CSV is missing required column(s): $($MissingCols -join ', ')" -Type Error
            Write-Host "   Use -GenerateTemplate to create a correctly formatted template." -ForegroundColor Yellow
            exit 1
        }

        foreach ($Row in $RawCsv) {
            $Deliver = $Row.DeliverToMailboxAndForward -match '^(true|yes|1)$'
            $WorkList.Add([PSCustomObject]@{
                Identity                   = $Row.Identity.Trim()
                ForwardingAddress          = $Row.ForwardingAddress.Trim()
                DeliverToMailboxAndForward = $Deliver
            })
        }
        Write-Status "Loaded $($WorkList.Count) record(s) from CSV." -Type Info
    }

    'Array' {
        foreach ($Item in $UserArray) {
            $Ident   = if ($Item -is [hashtable]) { $Item['Identity']   } else { $Item.Identity }
            $Fwd     = if ($Item -is [hashtable]) { $Item['ForwardingAddress'] } else { $Item.ForwardingAddress }
            $Deliver = if ($Item -is [hashtable]) { $Item['DeliverToMailboxAndForward'] } else { $Item.DeliverToMailboxAndForward }

            if ([string]::IsNullOrWhiteSpace($Ident)) {
                Write-Status "Skipping array entry with missing Identity." -Type Warning
                continue
            }
            $WorkList.Add([PSCustomObject]@{
                Identity                   = $Ident.ToString().Trim()
                ForwardingAddress          = if ($null -ne $Fwd) { $Fwd.ToString().Trim() } else { "" }
                DeliverToMailboxAndForward = [bool]$Deliver
            })
        }
        Write-Status "Loaded $($WorkList.Count) record(s) from array." -Type Info
    }

    'Single' {
        $WorkList.Add([PSCustomObject]@{
            Identity                   = $Identity.Trim()
            ForwardingAddress          = $ForwardingAddress.Trim()
            DeliverToMailboxAndForward = $DeliverToMailboxAndForward
        })
        Write-Status "Single-user mode: $($Identity.Trim())." -Type Info
    }
}

if ($WorkList.Count -eq 0) {
    Write-Status "No records to process. Exiting." -Type Warning
    exit 0
}

#endregion

#region ── Connect to Exchange Online ───────────────────────────────────────────

Write-Host ""
Write-Host $SubSeparator -ForegroundColor Cyan
Write-Host "  Connecting to Exchange Online..." -ForegroundColor Cyan
Write-Host $SubSeparator -ForegroundColor Cyan

try {
    Import-Module ExchangeOnlineManagement -ErrorAction Stop

    # Check for existing session
    $ExistingSession = Get-ConnectionInformation -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Connected' -and $_.Name -like '*ExchangeOnline*' }

    if ($ExistingSession) {
        Write-Status "Re-using existing Exchange Online session ($($ExistingSession.UserPrincipalName))." -Type Success
    }
    else {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        # Verify
        $null = Get-OrganizationConfig -ErrorAction Stop
        Write-Status "Connected to Exchange Online." -Type Success
    }
}
catch {
    Write-Status "Failed to connect to Exchange Online: $($_.Exception.Message)" -Type Error
    exit 1
}

#endregion

#region ── Optional: Allow outbound auto-forwarding ────────────────────────────

if ($AllowAutoForward) {
    Write-Host ""
    Write-Host $SubSeparator -ForegroundColor Cyan
    Write-Host "  Updating Outbound Spam Filter Policy..." -ForegroundColor Cyan
    Write-Host $SubSeparator -ForegroundColor Cyan

    try {
        $CurrentPolicy = Get-HostedOutboundSpamFilterPolicy -Identity Default -ErrorAction Stop
        $CurrentMode   = $CurrentPolicy.AutoForwardingMode

        if ($CurrentMode -eq 'On') {
            Write-Status "AutoForwardingMode is already 'On'. No change required." -Type Success
        }
        else {
            Write-Status "Current AutoForwardingMode: $CurrentMode  →  Changing to: On" -Type Warning

            if ($PSCmdlet.ShouldProcess("Default outbound spam filter policy", "Set AutoForwardingMode = On")) {
                Set-HostedOutboundSpamFilterPolicy -Identity Default -AutoForwardingMode On -ErrorAction Stop
                Write-Status "AutoForwardingMode set to 'On' on Default outbound spam filter policy." -Type Success
            }
            else {
                Write-Status "[WhatIf] Would set AutoForwardingMode = On on Default outbound spam filter policy." -Type Info
            }
        }
    }
    catch {
        Write-Status "Failed to update outbound spam filter policy: $($_.Exception.Message)" -Type Error
        Write-Host "   Forwarding assignments will still be attempted." -ForegroundColor Yellow
    }
}

#endregion

#region ── Apply forwarding rules ───────────────────────────────────────────────

Write-Host ""
Write-Host $SubSeparator -ForegroundColor Cyan
Write-Host "  Applying Forwarding Rules ($($WorkList.Count) record(s))..." -ForegroundColor Cyan
Write-Host $SubSeparator -ForegroundColor Cyan

$Counter = 0
foreach ($Entry in $WorkList) {
    $Counter++
    $Pct = [math]::Round(($Counter / $WorkList.Count) * 100)
    Write-Progress -Activity "Setting SMTP Forwarding" `
                   -Status "[$Counter/$($WorkList.Count)] $($Entry.Identity)" `
                   -PercentComplete $Pct

    $Ident   = $Entry.Identity
    $FwdAddr = $Entry.ForwardingAddress
    $Deliver = $Entry.DeliverToMailboxAndForward
    $Action  = if ([string]::IsNullOrWhiteSpace($FwdAddr)) { "Clear" } else { "Set" }

    # Verify mailbox exists
    try {
        $null = Get-Mailbox -Identity $Ident -ErrorAction Stop
    }
    catch {
        Write-Status "[$Counter/$($WorkList.Count)] Mailbox not found: $Ident" -Type Error
        Add-Result -Identity $Ident -ForwardingAddress $FwdAddr `
                   -DeliverToMailboxAndForward $Deliver.ToString() `
                   -Status "Failed" -Details "Mailbox not found: $($_.Exception.Message)"
        continue
    }

    try {
        if ($Action -eq 'Clear') {
            # Remove forwarding
            if ($PSCmdlet.ShouldProcess($Ident, "Clear SMTP forwarding")) {
                Set-Mailbox -Identity $Ident `
                            -ForwardingSmtpAddress $null `
                            -DeliverToMailboxAndForward $false `
                            -ErrorAction Stop
                Write-Status "[$Counter/$($WorkList.Count)] Cleared forwarding: $Ident" -Type Success
                Add-Result -Identity $Ident -ForwardingAddress "" `
                           -DeliverToMailboxAndForward "False" `
                           -Status "Cleared" -Details "Forwarding removed"
            }
            else {
                Write-Status "[$Counter/$($WorkList.Count)] [WhatIf] Would clear forwarding: $Ident" -Type Info
                Add-Result -Identity $Ident -ForwardingAddress "" `
                           -DeliverToMailboxAndForward "False" `
                           -Status "WhatIf-Cleared" -Details "WhatIf mode"
            }
        }
        else {
            # Set forwarding
            if ($PSCmdlet.ShouldProcess($Ident, "Set SMTP forwarding to $FwdAddr (DeliverToMailbox: $Deliver)")) {
                Set-Mailbox -Identity $Ident `
                            -ForwardingSmtpAddress "smtp:$FwdAddr" `
                            -DeliverToMailboxAndForward $Deliver `
                            -ErrorAction Stop
                $DeliverLabel = if ($Deliver) { "copy kept in mailbox" } else { "forward only" }
                Write-Status "[$Counter/$($WorkList.Count)] Set forwarding: $Ident → $FwdAddr ($DeliverLabel)" -Type Success
                Add-Result -Identity $Ident -ForwardingAddress $FwdAddr `
                           -DeliverToMailboxAndForward $Deliver.ToString() `
                           -Status "Success" -Details $DeliverLabel
            }
            else {
                Write-Status "[$Counter/$($WorkList.Count)] [WhatIf] Would set: $Ident → $FwdAddr (DeliverToMailbox: $Deliver)" -Type Info
                Add-Result -Identity $Ident -ForwardingAddress $FwdAddr `
                           -DeliverToMailboxAndForward $Deliver.ToString() `
                           -Status "WhatIf-Set" -Details "WhatIf mode"
            }
        }
    }
    catch {
        Write-Status "[$Counter/$($WorkList.Count)] Failed to configure $Ident : $($_.Exception.Message)" -Type Error
        Add-Result -Identity $Ident -ForwardingAddress $FwdAddr `
                   -DeliverToMailboxAndForward $Deliver.ToString() `
                   -Status "Failed" -Details $_.Exception.Message
    }
}

Write-Progress -Activity "Setting SMTP Forwarding" -Completed

#endregion

#region ── Export results & summary ─────────────────────────────────────────────

$ResultsFile = Join-Path $OutputDirectory "SMTPForward_Results_$Timestamp.csv"
try {
    $Results | Export-Csv -Path $ResultsFile -NoTypeInformation -Encoding UTF8
    Write-Status "Results exported to: $ResultsFile" -Type Success
}
catch {
    Write-Status "Failed to export results CSV: $($_.Exception.Message)" -Type Warning
}

$Successful = ($Results | Where-Object { $_.Status -in @('Success','Cleared') }).Count
$WhatIfRows = ($Results | Where-Object { $_.Status -like 'WhatIf*' }).Count
$Failed     = ($Results | Where-Object { $_.Status -eq 'Failed' }).Count

Write-Host ""
Write-Host $Separator -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host "  Total processed : $($WorkList.Count)" -ForegroundColor White
Write-Host "  Successful      : $Successful"       -ForegroundColor $(if ($Successful -gt 0) { 'Green' } else { 'Gray' })
if ($WhatIfRows -gt 0) {
Write-Host "  WhatIf (not applied): $WhatIfRows"  -ForegroundColor Cyan
}
Write-Host "  Failed          : $Failed"           -ForegroundColor $(if ($Failed -gt 0) { 'Red' } else { 'Gray' })
Write-Host "  Warnings        : $WarningCount"     -ForegroundColor $(if ($WarningCount -gt 0) { 'Yellow' } else { 'Gray' })
Write-Host "  Results file    : $ResultsFile"      -ForegroundColor White
Write-Host $Separator -ForegroundColor Cyan

#endregion

#region ── Disconnect ───────────────────────────────────────────────────────────

try {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Write-Status "Disconnected from Exchange Online." -Type Info
}
catch {
    # Non-fatal
}

#endregion
