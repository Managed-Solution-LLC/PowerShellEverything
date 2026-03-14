<#
.SYNOPSIS
    Removes all Exchange Online mail contacts whose primary email address matches one or more specified domains.

.DESCRIPTION
    Connects to Exchange Online and retrieves all mail contacts (tenant-level GAL contacts) whose primary
    email address belongs to the specified domain(s). Contacts are removed in bulk with progress tracking,
    error handling, and an optional pre-removal CSV export for auditing.

    Supports -WhatIf for a dry-run preview of which contacts would be removed without making changes.

    Use cases:
    - Cleaning up contacts from a legacy domain after migration
    - Removing a vendor/partner domain's contact list from the GAL
    - Decommissioning shared contact directories

.PARAMETER Domain
    One or more email domains to target (e.g., "contoso.com" or @("contoso.com","fabrikam.com")).
    All mail contacts whose primary SMTP address ends with @<domain> will be removed.

.PARAMETER OutputDirectory
    Directory for the pre-removal audit CSV export. Defaults to C:\Reports\CSV_Exports.
    Set to $null or empty string to skip the export.

.PARAMETER SkipExport
    If specified, skips the pre-removal CSV export of contacts that will be deleted.

.PARAMETER DisconnectWhenDone
    If specified, disconnects from Exchange Online after the script completes.

.EXAMPLE
    .\Remove-AllContactsOnDomain.ps1 -Domain "contoso.com"
    Removes all mail contacts in Exchange Online whose email is @contoso.com.

.EXAMPLE
    .\Remove-AllContactsOnDomain.ps1 -Domain "contoso.com" -WhatIf
    Previews which contacts would be removed without making any changes.

.EXAMPLE
    .\Remove-AllContactsOnDomain.ps1 -Domain @("contoso.com", "fabrikam.com") -OutputDirectory "C:\Temp\Exports"
    Removes contacts from both domains and saves the audit CSV to C:\Temp\Exports.

.EXAMPLE
    .\Remove-AllContactsOnDomain.ps1 -Domain "legacydomain.com" -SkipExport -DisconnectWhenDone
    Removes contacts without exporting a report and disconnects when complete.

.NOTES
    Author: Managed Solution LLC
    Date: 2026-03-13
    Version: 1.0

    Requirements:
    - PowerShell 5.1 or later
    - ExchangeOnlineManagement module (Install-Module ExchangeOnlineManagement)
    - Exchange Online Administrator or Recipient Management role

    The script will prompt to connect to Exchange Online if not already connected.
    A pre-removal CSV audit report is exported by default before any deletions occur.

.LINK
    https://docs.microsoft.com/powershell/module/exchange/remove-mailcontact
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "One or more email domains to target (e.g. 'contoso.com')")]
    [ValidateNotNullOrEmpty()]
    [string[]]$Domain,

    [Parameter(Mandatory = $false, HelpMessage = "Directory for the pre-removal audit CSV export")]
    [string]$OutputDirectory = "C:\Reports\CSV_Exports",

    [Parameter(Mandatory = $false, HelpMessage = "Skip the pre-removal CSV export")]
    [switch]$SkipExport,

    [Parameter(Mandatory = $false, HelpMessage = "Disconnect from Exchange Online when done")]
    [switch]$DisconnectWhenDone
)

#region Initialization
$Separator    = "=" * 80
$SubSeparator = "-" * 60
$StartTime    = Get-Date
$ErrorCount   = 0
$WarningCount = 0
$RemovedCount = 0
$SkippedCount = 0

Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  Remove-AllContactsOnDomain" -ForegroundColor Cyan
Write-Host "  Domains: $($Domain -join ', ')" -ForegroundColor Cyan
Write-Host "  Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
#endregion

#region Module Check
if (-not (Get-Module -Name ExchangeOnlineManagement -ListAvailable)) {
    Write-Host "❌ ExchangeOnlineManagement module not installed." -ForegroundColor Red
    Write-Host "   Install with: Install-Module ExchangeOnlineManagement -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}
#endregion

#region Exchange Online Connection
Write-Host "`nChecking Exchange Online connection..." -ForegroundColor Yellow
try {
    $null = Get-OrganizationConfig -ErrorAction Stop
    Write-Host "✅ Already connected to Exchange Online" -ForegroundColor Green
}
catch {
    Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
    try {
        Connect-ExchangeOnline -ShowProgress $false -ErrorAction Stop
        $null = Get-OrganizationConfig -ErrorAction Stop
        Write-Host "✅ Connected to Exchange Online" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to connect to Exchange Online: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
#endregion

#region Output Directory
if (-not $SkipExport) {
    if (-not (Test-Path $OutputDirectory)) {
        try {
            New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
            Write-Host "✅ Created output directory: $OutputDirectory" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  Cannot create output directory '$OutputDirectory' - $($_.Exception.Message). Skipping export." -ForegroundColor Yellow
            $SkipExport = $true
            $WarningCount++
        }
    }
}
#endregion

#region Retrieve Contacts
Write-Host "`n$SubSeparator" -ForegroundColor Gray
Write-Host "Retrieving all mail contacts from Exchange Online..." -ForegroundColor Yellow

try {
    $AllContacts = Get-MailContact -ResultSize Unlimited -ErrorAction Stop
    Write-Host "  Total mail contacts in tenant: $($AllContacts.Count)" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ Failed to retrieve mail contacts: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Normalize domains to lowercase for comparison
$NormalizedDomains = $Domain | ForEach-Object { $_.ToLower().TrimStart('@') }

# Filter contacts matching any target domain
$TargetContacts = $AllContacts | Where-Object {
    $emailDomain = ($_.PrimarySmtpAddress -split '@')[-1].ToLower()
    $NormalizedDomains -contains $emailDomain
}

if ($TargetContacts.Count -eq 0) {
    Write-Host "`n⚠️  No mail contacts found matching domain(s): $($Domain -join ', ')" -ForegroundColor Yellow
    Write-Host "  Nothing to remove. Exiting." -ForegroundColor Yellow
    if ($DisconnectWhenDone) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
    exit 0
}

Write-Host "  Contacts matching target domain(s): $($TargetContacts.Count)" -ForegroundColor White
#endregion

#region Pre-Removal Export
if (-not $SkipExport) {
    $Timestamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $DomainLabel = ($NormalizedDomains -join '_') -replace '[^a-zA-Z0-9_-]', ''
    $AuditFile   = Join-Path $OutputDirectory "Contacts_Removed_${DomainLabel}_${Timestamp}.csv"

    Write-Host "`nExporting pre-removal audit to CSV..." -ForegroundColor Yellow
    try {
        $TargetContacts | Select-Object `
            DisplayName,
            PrimarySmtpAddress,
            Alias,
            ExternalEmailAddress,
            @{ Name = 'HiddenFromAddressListsEnabled'; Expression = { $_.HiddenFromAddressListsEnabled } },
            Identity,
            OrganizationalUnit,
            WhenCreated,
            WhenChanged |
            Export-Csv -Path $AuditFile -NoTypeInformation -Encoding UTF8

        Write-Host "✅ Audit CSV exported: $AuditFile" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Failed to export audit CSV: $($_.Exception.Message)" -ForegroundColor Yellow
        $WarningCount++
    }
}
#endregion

#region Removal
Write-Host "`n$SubSeparator" -ForegroundColor Gray

if ($WhatIfPreference) {
    Write-Host "WHAT-IF MODE - No contacts will be removed" -ForegroundColor Magenta
}
else {
    Write-Host "Removing $($TargetContacts.Count) contact(s)..." -ForegroundColor Yellow
}

Write-Host $SubSeparator -ForegroundColor Gray

$Counter = 0
foreach ($Contact in $TargetContacts) {
    $Counter++
    $ProgressPct = [Math]::Round(($Counter / $TargetContacts.Count) * 100)

    Write-Progress -Activity "Removing Contacts" `
        -Status "[$Counter/$($TargetContacts.Count)] $($Contact.DisplayName)" `
        -PercentComplete $ProgressPct

    if ($PSCmdlet.ShouldProcess($Contact.PrimarySmtpAddress, "Remove-MailContact")) {
        try {
            Remove-MailContact -Identity $Contact.Identity -Confirm:$false -ErrorAction Stop
            Write-Host "  ✅ Removed: $($Contact.DisplayName) <$($Contact.PrimarySmtpAddress)>" -ForegroundColor Green
            $RemovedCount++
        }
        catch {
            Write-Host "  ❌ Failed to remove $($Contact.DisplayName) <$($Contact.PrimarySmtpAddress)>: $($_.Exception.Message)" -ForegroundColor Red
            $ErrorCount++
        }
    }
    else {
        # WhatIf branch - ShouldProcess already printed the WhatIf message
        $SkippedCount++
    }
}

Write-Progress -Activity "Removing Contacts" -Completed
#endregion

#region Summary
$EndTime  = Get-Date
$Duration = $EndTime - $StartTime

Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host $SubSeparator -ForegroundColor Cyan
Write-Host "  Target domain(s)  : $($Domain -join ', ')"
Write-Host "  Contacts found    : $($TargetContacts.Count)"

if ($WhatIfPreference) {
    Write-Host "  Mode              : WhatIf (no changes made)" -ForegroundColor Magenta
    Write-Host "  Would remove      : $SkippedCount" -ForegroundColor Magenta
}
else {
    Write-Host "  Removed           : $RemovedCount" -ForegroundColor $(if ($RemovedCount -gt 0) { 'Green' } else { 'White' })
    Write-Host "  Errors            : $ErrorCount"   -ForegroundColor $(if ($ErrorCount -gt 0) { 'Red' } else { 'White' })
    Write-Host "  Warnings          : $WarningCount" -ForegroundColor $(if ($WarningCount -gt 0) { 'Yellow' } else { 'White' })
}

Write-Host "  Duration          : $($Duration.ToString('mm\:ss'))"
Write-Host "  Completed         : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host $Separator -ForegroundColor Cyan
#endregion

#region Cleanup
if ($DisconnectWhenDone) {
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "`n✅ Disconnected from Exchange Online" -ForegroundColor Green
    }
    catch {
        # Non-fatal
    }
}
#endregion
