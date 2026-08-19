<#
.SYNOPSIS
	Export all users with aliases and x500 addresses to CSV
.DESCRIPTION
	Connects to Microsoft Graph or Exchange Online, retrieves all user objects, and exports their primary SMTP, proxy addresses (aliases), and x500 addresses to a CSV file. Designed for client-agnostic, production-ready use.
.PARAMETER OutputDirectory
	Directory to save the CSV export. Defaults to C:\Reports\CSV_Exports
.PARAMETER OrganizationName
	Organization name for report headers. Defaults to "Organization"
.EXAMPLE
	.\Get-UserInfoExport.ps1 -OutputDirectory "C:\Exports" -OrganizationName "Contoso"
	Exports all users with aliases and x500 addresses for Contoso to C:\Exports
.NOTES
	Author: W. Ford, Managed Solution LLC
	Date: 2026-02-25
	Version: 1.0
	Requirements:
	  - Microsoft Graph or ExchangeOnlineManagement module
	  - User.Read.All, Directory.Read.All, or equivalent permissions
	  - PowerShell 5.1+
.LINK
	https://learn.microsoft.com/en-us/powershell/module/exchange/get-mailbox
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$false, HelpMessage="Directory to save the CSV export")]
	[string]$OutputDirectory = "C:\Reports\CSV_Exports",

	[Parameter(Mandatory=$false, HelpMessage="Organization name for report headers")]
	[string]$OrganizationName = "Organization"
)

# Pre-execution checks
if ($PSVersionTable.PSVersion.Major -lt 5) {
	Write-Host "❌ This script requires PowerShell 5.1 or later" -ForegroundColor Red
	exit 1
}
if (!(Test-Path $OutputDirectory)) {
	try {
		New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
		Write-Host "✅ Created output directory: $OutputDirectory" -ForegroundColor Green
	} catch {
		Write-Host "❌ Cannot create output directory: $($_.Exception.Message)" -ForegroundColor Red
		exit 1
	}
}

# Module check
$RequiredModules = @('ExchangeOnlineManagement')
$MissingModules = $RequiredModules | Where-Object { -not (Get-Module -Name $_ -ListAvailable) }
if ($MissingModules) {
	Write-Host "❌ Missing required modules: $($MissingModules -join ', ')" -ForegroundColor Red
	Write-Host "   Install with: Install-Module $($MissingModules -join ', ') -Scope CurrentUser" -ForegroundColor Yellow
	exit 1
}

# Connect to Exchange Online
try {
	Connect-ExchangeOnline -ShowProgress:$false -ErrorAction Stop
	$null = Get-OrganizationConfig -ErrorAction Stop
	Write-Host "✅ Connected to Exchange Online" -ForegroundColor Green
} catch {
	Write-Host "❌ Failed to connect to Exchange Online: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}

# Get all mailboxes
Write-Host "Retrieving all user mailboxes..." -ForegroundColor Cyan
$mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox -ErrorAction Stop

# Prepare data
$userExport = foreach ($mbx in $mailboxes) {
	$aliases = @()
	$x500s = @()
	foreach ($addr in $mbx.EmailAddresses) {
		if ($addr.PrefixString -eq 'smtp' -or $addr.PrefixString -eq 'SMTP') {
			if ($addr.AddressString -ne $mbx.PrimarySmtpAddress) { $aliases += $addr.AddressString }
		} elseif ($addr.PrefixString -eq 'x500') {
			$x500s += $addr.AddressString
		}
	}
	[PSCustomObject]@{
		DisplayName         = $mbx.DisplayName
		UserPrincipalName   = $mbx.UserPrincipalName
		PrimarySmtpAddress  = $mbx.PrimarySmtpAddress
		Aliases             = ($aliases -join '; ')
		X500Addresses       = ($x500s -join '; ')
	}
}

# Export to CSV
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$OutputFile = Join-Path $OutputDirectory "User_Alias_X500_Export_${Timestamp}.csv"
$userExport | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
Write-Host "✅ Exported $($userExport.Count) users to: $OutputFile" -ForegroundColor Green

# Disconnect
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Disconnected from Exchange Online" -ForegroundColor Gray
