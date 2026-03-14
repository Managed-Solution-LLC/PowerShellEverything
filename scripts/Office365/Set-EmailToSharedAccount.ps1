<#
.SYNOPSIS
    Converts Exchange Online mailboxes to Shared Mailboxes and removes all assigned licenses.

.DESCRIPTION
    Automates the process of converting regular (user) mailboxes to shared mailboxes and
    stripping all Microsoft 365 licenses from the accounts in bulk.

    Key capabilities:
    - Bulk conversion from CSV file, in-memory array, or single-identity parameter
    - Converts mailbox type to Shared via Exchange Online (Set-Mailbox -Type Shared)
    - Removes all assigned SKU licenses via Microsoft Graph
    - Skips license removal if the account has no licenses (non-fatal)
    - WhatIf mode to validate input without making changes
    - Generates a timestamped CSV results report of all actions taken
    - Comprehensive error handling and colored status output

    Required CSV column:
        Identity  - UPN or primary SMTP of the mailbox to convert

.PARAMETER CsvPath
    Path to a CSV file containing accounts to convert.
    Required column: Identity
    Use -GenerateTemplate to create a pre-formatted template.

.PARAMETER UserArray
    Array of PSCustomObjects or hashtables with an Identity property.
    Useful for pipeline or in-memory data scenarios.

.PARAMETER Identity
    Single UPN or primary SMTP address for a one-off conversion.

.PARAMETER SkipLicenseRemoval
    When specified, converts the mailbox type but does NOT remove licenses.
    Useful when license management is handled separately.

.PARAMETER OutputDirectory
    Directory where the results CSV report will be saved.
    Default: C:\Reports\CSV_Exports

.PARAMETER GenerateTemplate
    Creates a blank CSV template in -OutputDirectory and exits.

.EXAMPLE
    .\Set-EmailToSharedAccount.ps1 -CsvPath "C:\Data\accounts.csv"

    Converts all mailboxes in the CSV to shared and removes their licenses.

.EXAMPLE
    .\Set-EmailToSharedAccount.ps1 -CsvPath "C:\Data\accounts.csv" -WhatIf

    Simulates all changes without applying them.

.EXAMPLE
    .\Set-EmailToSharedAccount.ps1 -Identity "jsmith@contoso.com"

    Converts a single mailbox and removes its licenses.

.EXAMPLE
    .\Set-EmailToSharedAccount.ps1 -Identity "jsmith@contoso.com" -SkipLicenseRemoval

    Converts mailbox type only; does not touch license assignments.

.EXAMPLE
    $users = @(
        [PSCustomObject]@{ Identity = "alice@contoso.com" }
        [PSCustomObject]@{ Identity = "bob@contoso.com" }
    )
    .\Set-EmailToSharedAccount.ps1 -UserArray $users

    Passes an in-memory array directly to the script.

.EXAMPLE
    .\Set-EmailToSharedAccount.ps1 -GenerateTemplate -OutputDirectory "C:\Data"

    Writes a blank CSV template to C:\Data\SharedMailbox_Template.csv and exits.

.NOTES
    Author: W. Ford
    Date: 2026-03-13
    Version: 1.0

    Requirements:
    - PowerShell 5.1 or later (PowerShell 7 recommended)
    - ExchangeOnlineManagement module  (Install-Module ExchangeOnlineManagement -Scope CurrentUser)
    - Microsoft.Graph.Users module     (Install-Module Microsoft.Graph.Users -Scope CurrentUser)
    - Exchange Online Administrator or Exchange Recipient Administrator role
    - User Administrator or License Administrator role (for license removal)

    Output:
    - Console status messages with color-coded results
    - Timestamped CSV results report in -OutputDirectory

.LINK
    https://learn.microsoft.com/powershell/module/exchange/set-mailbox
    https://learn.microsoft.com/graph/api/user-assignlicense
#>

[CmdletBinding(DefaultParameterSetName = 'CSV', SupportsShouldProcess = $true)]
param (
    # ---- Input methods ----
    [Parameter(Mandatory = $true, ParameterSetName = 'CSV', HelpMessage = "Path to input CSV file")]
    [ValidateNotNullOrEmpty()]
    [string]$CsvPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'Array', HelpMessage = "Array of identity objects")]
    [ValidateNotNullOrEmpty()]
    [object[]]$UserArray,

    [Parameter(Mandatory = $true, ParameterSetName = 'Single', HelpMessage = "UPN or primary SMTP of the mailbox to convert")]
    [ValidateNotNullOrEmpty()]
    [string]$Identity,

    [Parameter(Mandatory = $true, ParameterSetName = 'Template', HelpMessage = "Generate a blank CSV template and exit")]
    [switch]$GenerateTemplate,

    # ---- Behaviour options ----
    [Parameter(Mandatory = $false, HelpMessage = "Convert mailbox type only; do not remove licenses")]
    [switch]$SkipLicenseRemoval,

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
        'Success' { Write-Host "[$ts] ✅ $Message" -ForegroundColor Green  }
        'Warning' { Write-Host "[$ts] ⚠️  $Message" -ForegroundColor Yellow; $script:WarningCount++ }
        'Error'   { Write-Host "[$ts] ❌ $Message" -ForegroundColor Red;    $script:ErrorCount++   }
        default   { Write-Host "[$ts] ℹ️  $Message" -ForegroundColor Cyan  }
    }
}

function Add-Result {
    param(
        [string]$Identity,
        [string]$MailboxConverted,
        [string]$LicensesRemoved,
        [string]$LicensesSkipped,
        [string]$Status,
        [string]$Details = ""
    )
    $script:Results.Add([PSCustomObject]@{
        Identity         = $Identity
        MailboxConverted = $MailboxConverted
        LicensesRemoved  = $LicensesRemoved
        LicensesSkipped  = $LicensesSkipped
        Status           = $Status
        Details          = $Details
        Timestamp        = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    })
}

#endregion

#region ── Template generation ──────────────────────────────────────────────────

if ($PSCmdlet.ParameterSetName -eq 'Template') {
    if (!(Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    $TemplatePath = Join-Path $OutputDirectory "SharedMailbox_Template.csv"
    @"
Identity
jsmith@contoso.com
agarcia@contoso.com
"@ | Out-File -FilePath $TemplatePath -Encoding UTF8 -Force
    Write-Host "✅ Template created: $TemplatePath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Column reference:" -ForegroundColor Cyan
    Write-Host "  Identity  - UPN or primary SMTP of the mailbox to convert to Shared"
    exit 0
}

#endregion

#region ── Pre-flight checks ────────────────────────────────────────────────────

Write-Host ""
Write-Host $Separator -ForegroundColor Cyan
Write-Host "  Set-EmailToSharedAccount  |  Shared Mailbox Conversion & License Removal" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

# PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Status "PowerShell 5.1 or later is required." -Type Error
    exit 1
}

# Required modules
$RequiredModules = @('ExchangeOnlineManagement')
if (-not $SkipLicenseRemoval) { $RequiredModules += 'Microsoft.Graph.Users' }

$MissingModules = $RequiredModules | Where-Object { -not (Get-Module -Name $_ -ListAvailable) }
if ($MissingModules) {
    Write-Status "Missing required module(s): $($MissingModules -join ', ')" -Type Error
    Write-Host "   Install with: Install-Module $($MissingModules -join ', ') -Scope CurrentUser" -ForegroundColor Yellow
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

$WorkList = [System.Collections.Generic.List[string]]::new()

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

        $CsvHeaders = $RawCsv[0].PSObject.Properties.Name
        if ('Identity' -notin $CsvHeaders) {
            Write-Status "CSV is missing the required 'Identity' column." -Type Error
            Write-Host "   Use -GenerateTemplate to create a correctly formatted template." -ForegroundColor Yellow
            exit 1
        }

        foreach ($Row in $RawCsv) {
            $Val = $Row.Identity.Trim()
            if (![string]::IsNullOrWhiteSpace($Val)) { $WorkList.Add($Val) }
        }
        Write-Status "Loaded $($WorkList.Count) record(s) from CSV." -Type Info
    }

    'Array' {
        foreach ($Item in $UserArray) {
            $Val = if ($Item -is [hashtable]) { $Item['Identity'] } else { $Item.Identity }
            if ([string]::IsNullOrWhiteSpace($Val)) {
                Write-Status "Skipping array entry with missing Identity." -Type Warning
                continue
            }
            $WorkList.Add($Val.ToString().Trim())
        }
        Write-Status "Loaded $($WorkList.Count) record(s) from array." -Type Info
    }

    'Single' {
        $WorkList.Add($Identity.Trim())
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

    $ExistingEXO = Get-ConnectionInformation -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Connected' -and $_.Name -like '*ExchangeOnline*' }

    if ($ExistingEXO) {
        Write-Status "Re-using existing Exchange Online session ($($ExistingEXO.UserPrincipalName))." -Type Success
    }
    else {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        $null = Get-OrganizationConfig -ErrorAction Stop
        Write-Status "Connected to Exchange Online." -Type Success
    }
}
catch {
    Write-Status "Failed to connect to Exchange Online: $($_.Exception.Message)" -Type Error
    exit 1
}

#endregion

#region ── Connect to Microsoft Graph (license removal) ─────────────────────────

if (-not $SkipLicenseRemoval) {
    Write-Host ""
    Write-Host $SubSeparator -ForegroundColor Cyan
    Write-Host "  Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Write-Host $SubSeparator -ForegroundColor Cyan

    try {
        Import-Module Microsoft.Graph.Users -ErrorAction Stop

        $GraphContext = Get-MgContext -ErrorAction SilentlyContinue
        if ($GraphContext) {
            Write-Status "Re-using existing Graph session ($($GraphContext.Account))." -Type Success
        }
        else {
            Connect-MgGraph -Scopes "User.ReadWrite.All" -NoWelcome -ErrorAction Stop
            $GraphContext = Get-MgContext -ErrorAction Stop
            Write-Status "Connected to Microsoft Graph as $($GraphContext.Account)." -Type Success
        }
    }
    catch {
        Write-Status "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -Type Error
        Write-Host "   Tip: You can re-run with -SkipLicenseRemoval to convert mailboxes only." -ForegroundColor Yellow
        exit 1
    }
}

#endregion

#region ── Process each account ─────────────────────────────────────────────────

Write-Host ""
Write-Host $SubSeparator -ForegroundColor Cyan
Write-Host "  Converting Mailboxes ($($WorkList.Count) account(s))..." -ForegroundColor Cyan
Write-Host $SubSeparator -ForegroundColor Cyan

$Counter = 0
foreach ($Ident in $WorkList) {
    $Counter++
    $Pct = [math]::Round(($Counter / $WorkList.Count) * 100)
    Write-Progress -Activity "Converting to Shared Mailbox" `
                   -Status "[$Counter/$($WorkList.Count)] $Ident" `
                   -PercentComplete $Pct

    $MailboxConverted = "No"
    $LicensesRemoved  = "N/A"
    $LicensesSkipped  = "N/A"
    $OverallStatus    = "Success"
    $Details          = [System.Collections.Generic.List[string]]::new()

    # ── Step 1: Verify mailbox exists ──────────────────────────────────────────
    try {
        $Mailbox = Get-Mailbox -Identity $Ident -ErrorAction Stop
    }
    catch {
        Write-Status "[$Counter/$($WorkList.Count)] Mailbox not found: $Ident" -Type Error
        Add-Result -Identity $Ident -MailboxConverted "No" -LicensesRemoved "N/A" `
                   -LicensesSkipped "N/A" -Status "Failed" `
                   -Details "Mailbox not found: $($_.Exception.Message)"
        continue
    }

    # ── Step 2: Convert to Shared ──────────────────────────────────────────────
    if ($Mailbox.RecipientTypeDetails -eq 'SharedMailbox') {
        Write-Status "[$Counter/$($WorkList.Count)] Already a Shared Mailbox - skipping conversion: $Ident" -Type Warning
        $MailboxConverted = "AlreadyShared"
        $Details.Add("Mailbox already Shared")
    }
    else {
        if ($PSCmdlet.ShouldProcess($Ident, "Convert mailbox to Shared")) {
            try {
                Set-Mailbox -Identity $Ident -Type Shared -ErrorAction Stop
                Write-Status "[$Counter/$($WorkList.Count)] Converted to Shared Mailbox: $Ident" -Type Success
                $MailboxConverted = "Yes"
                $Details.Add("Converted to Shared")
            }
            catch {
                Write-Status "[$Counter/$($WorkList.Count)] Failed to convert mailbox: $Ident - $($_.Exception.Message)" -Type Error
                $MailboxConverted = "Failed"
                $OverallStatus    = "Failed"
                $Details.Add("Mailbox conversion failed: $($_.Exception.Message)")
            }
        }
        else {
            Write-Status "[$Counter/$($WorkList.Count)] [WhatIf] Would convert to Shared: $Ident" -Type Info
            $MailboxConverted = "WhatIf"
            $Details.Add("WhatIf - would convert to Shared")
        }
    }

    # ── Step 3: Remove licenses ────────────────────────────────────────────────
    if ($SkipLicenseRemoval) {
        $LicensesRemoved = "Skipped"
        $LicensesSkipped = "SkipLicenseRemoval flag set"
        $Details.Add("License removal skipped by parameter")
    }
    else {
        try {
            $AssignedLicenses = Get-MgUserLicenseDetail -UserId $Ident -ErrorAction Stop

            if ($AssignedLicenses.Count -eq 0) {
                Write-Status "[$Counter/$($WorkList.Count)] No licenses assigned: $Ident" -Type Warning
                $LicensesRemoved = "None"
                $LicensesSkipped = "No licenses found"
                $Details.Add("No licenses were assigned")
            }
            else {
                $SkuList = $AssignedLicenses.SkuPartNumber -join "; "

                if ($PSCmdlet.ShouldProcess($Ident, "Remove licenses: $SkuList")) {
                    try {
                        Set-MgUserLicense -UserId $Ident `
                                          -AddLicenses @() `
                                          -RemoveLicenses $AssignedLicenses.SkuId `
                                          -ErrorAction Stop | Out-Null
                        Write-Status "[$Counter/$($WorkList.Count)] Removed $($AssignedLicenses.Count) license(s) from $Ident ($SkuList)" -Type Success
                        $LicensesRemoved = $SkuList
                        $LicensesSkipped = "None"
                        $Details.Add("Licenses removed: $SkuList")
                    }
                    catch {
                        Write-Status "[$Counter/$($WorkList.Count)] Failed to remove licenses from $Ident - $($_.Exception.Message)" -Type Error
                        $LicensesRemoved = "Failed"
                        $LicensesSkipped = $SkuList
                        $OverallStatus   = if ($OverallStatus -ne 'Failed') { 'PartialSuccess' } else { 'Failed' }
                        $Details.Add("License removal failed: $($_.Exception.Message)")
                    }
                }
                else {
                    Write-Status "[$Counter/$($WorkList.Count)] [WhatIf] Would remove $($AssignedLicenses.Count) license(s) from $Ident ($SkuList)" -Type Info
                    $LicensesRemoved = "WhatIf"
                    $LicensesSkipped = $SkuList
                    $Details.Add("WhatIf - would remove: $SkuList")
                }
            }
        }
        catch {
            Write-Status "[$Counter/$($WorkList.Count)] Could not retrieve licenses for $Ident - $($_.Exception.Message)" -Type Error
            $LicensesRemoved = "LookupFailed"
            $OverallStatus   = if ($OverallStatus -ne 'Failed') { 'PartialSuccess' } else { 'Failed' }
            $Details.Add("License lookup failed: $($_.Exception.Message)")
        }
    }

    Add-Result -Identity $Ident `
               -MailboxConverted $MailboxConverted `
               -LicensesRemoved $LicensesRemoved `
               -LicensesSkipped $LicensesSkipped `
               -Status $OverallStatus `
               -Details ($Details -join " | ")
}

Write-Progress -Activity "Converting to Shared Mailbox" -Completed

#endregion

#region ── Export results & summary ─────────────────────────────────────────────

$ResultsFile = Join-Path $OutputDirectory "SharedMailbox_Results_$Timestamp.csv"
try {
    $Results | Export-Csv -Path $ResultsFile -NoTypeInformation -Encoding UTF8
    Write-Status "Results exported to: $ResultsFile" -Type Success
}
catch {
    Write-Status "Failed to export results CSV: $($_.Exception.Message)" -Type Warning
}

$Successful     = ($Results | Where-Object { $_.Status -eq 'Success' }).Count
$AlreadyShared  = ($Results | Where-Object { $_.MailboxConverted -eq 'AlreadyShared' }).Count
$Partial        = ($Results | Where-Object { $_.Status -eq 'PartialSuccess' }).Count
$WhatIfRows     = ($Results | Where-Object { $_.MailboxConverted -eq 'WhatIf' }).Count
$Failed         = ($Results | Where-Object { $_.Status -eq 'Failed' }).Count

Write-Host ""
Write-Host $Separator -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host "  Total processed   : $($WorkList.Count)"  -ForegroundColor White
Write-Host "  Fully successful  : $Successful"          -ForegroundColor $(if ($Successful -gt 0)   { 'Green'  } else { 'Gray' })
if ($AlreadyShared -gt 0) {
Write-Host "  Already Shared    : $AlreadyShared"       -ForegroundColor Yellow
}
if ($Partial -gt 0) {
Write-Host "  Partial success   : $Partial"             -ForegroundColor Yellow
}
if ($WhatIfRows -gt 0) {
Write-Host "  WhatIf (not applied): $WhatIfRows"        -ForegroundColor Cyan
}
Write-Host "  Failed            : $Failed"              -ForegroundColor $(if ($Failed -gt 0)        { 'Red'    } else { 'Gray' })
Write-Host "  Warnings          : $WarningCount"        -ForegroundColor $(if ($WarningCount -gt 0)  { 'Yellow' } else { 'Gray' })
Write-Host "  Results file      : $ResultsFile"         -ForegroundColor White
Write-Host $Separator -ForegroundColor Cyan

#endregion

#region ── Disconnect ───────────────────────────────────────────────────────────

try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch {}
try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}
Write-Status "Disconnected from all services." -Type Info

#endregion
