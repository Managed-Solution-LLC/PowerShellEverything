<#
.SYNOPSIS
    Hides or shows mailboxes in the Global Address List (GAL) for multiple users.

.DESCRIPTION
    This script allows bulk management of mailbox visibility in the Exchange Global Address List (GAL).
    It accepts user identities from multiple sources (CSV file, array, or hashtable) and can either
    hide mailboxes from the GAL or make them visible.
    
    Works with Exchange Online, On-Premise Exchange, and Active Directory (ADSI) environments.
    
    Key features:
    - Accepts identities from CSV file with flexible column naming
    - Accepts direct array or hashtable input
    - Toggle visibility with -ShowInGAL switch
    - Supports Exchange Online, On-Premise Exchange, and Active Directory ADSI
    - Direct AD attribute modification (msExchHideFromAddressLists)
    - Comprehensive error handling and progress tracking
    - Detailed reporting with success/failure counts
    - Export results to CSV with timestamp

.PARAMETER CsvPath
    Path to a CSV file containing user identities. The CSV should have a column containing
    email addresses, user principal names, or display names. Supports columns named:
    - Identity, Email, EmailAddress, UserPrincipalName, UPN, DisplayName, User, SamAccountName
    
.PARAMETER Identities
    Array of user identities (email addresses, UPNs, or display names) to process.
    Can be passed directly as an array of strings or extracted from hashtables.
    
.PARAMETER IdentityColumn
    Specifies which column to use from the CSV file if the standard column names are not found.
    Only used when -CsvPath is specified.
    
.PARAMETER ShowInGAL
    Switch parameter. When specified, makes the mailboxes VISIBLE in the GAL instead of hiding them.
    Default behavior (without this switch) is to HIDE mailboxes from the GAL.
    
.PARAMETER OnPremise
    Switch parameter. Use this when working with on-premise Exchange Server instead of Exchange Online.
    When specified, the script will use local Exchange Management Shell cmdlets instead of connecting
    to Exchange Online. Requires running from Exchange Management Shell or having Exchange cmdlets available.
    
.PARAMETER UseADSI
    Switch parameter. Use this to modify Active Directory objects directly using ADSI.
    This modifies the msExchHideFromAddressLists attribute on AD user/contact/group objects.
    Requires appropriate AD permissions and cannot be combined with -OnPremise.
    Works with SamAccountName, Distinguished Name, or UserPrincipalName.
    
.PARAMETER SearchBase
    LDAP search base (Distinguished Name) for AD queries when using -UseADSI.
    If not specified, searches the entire domain. Example: "OU=Users,DC=contoso,DC=com"
    
.PARAMETER OutputDirectory
    Directory where the results CSV will be saved. Defaults to C:\Reports\GAL_Changes.
    
.PARAMETER WhatIf
    Shows what would happen if the script runs without actually making changes.

.EXAMPLE
    .\Set-HideFromGal.ps1 -CsvPath "C:\Users\users.csv"
    
    Hides all users listed in the CSV file from the Global Address List.

.EXAMPLE
    .\Set-HideFromGal.ps1 -Identities @("user1@contoso.com", "user2@contoso.com")
    
    Hides the specified users from the Global Address List.

.EXAMPLE
    .\Set-HideFromGal.ps1 -CsvPath "C:\Users\users.csv" -ShowInGAL
    
    Makes all users listed in the CSV file VISIBLE in the Global Address List.

.EXAMPLE
    .\Set-HideFromGal.ps1 -Identities @("user1@contoso.com", "user2@contoso.com") -ShowInGAL
    
    Makes the specified users VISIBLE in the Global Address List.

.EXAMPLE
    .\Set-HideFromGal.ps1 -CsvPath "C:\Data\employees.csv" -IdentityColumn "EmployeeEmail"
    
    Hides users from GAL using the "EmployeeEmail" column from the CSV.

.EXAMPLE
    $users = @{Identity = "user1@contoso.com"}, @{Identity = "user2@contoso.com"}
    .\Set-HideFromGal.ps1 -Identities $users
    
    Processes hashtable array and hides users from GAL.

.EXAMPLE
    .\Set-HideFromGal.ps1 -CsvPath "C:\Users\users.csv" -OnPremise
    
    Hides users from GAL in on-premise Exchange environment.

.EXAMPLE
    .\Set-HideFromGal.ps1 -Identities @("user1@contoso.com", "user2@contoso.com") -OnPremise -ShowInGAL
    
    Makes users visible in GAL in on-premise Exchange environment.

.EXAMPLE
    .\Set-HideFromGal.ps1 -CsvPath "C:\Users\users.csv" -UseADSI
    
    Hides users from GAL by modifying AD objects directly using ADSI.

.EXAMPLE
    .\Set-HideFromGal.ps1 -Identities @("user1", "user2") -UseADSI -ShowInGAL -SearchBase "OU=Users,DC=contoso,DC=com"
    
    Makes users visible in GAL by modifying AD objects in specific OU.

.NOTES
    Author: W. Ford
    Date: 2026-02-04
    Version: 1.0
    
    Requirements:
    For Exchange Online:
    - Exchange Online PowerShell module (ExchangeOnlineManagement)
    - Exchange Online administrator permissions
    - PowerShell 5.1 or later
    
    For On-Premise Exchange:
    - Exchange Management Shell or Exchange cmdlets available
    - Exchange administrator permissions
    - Must run from Exchange Management Shell or have Exchange snap-in loaded
    - PowerShell 5.1 or later
    
    For Active Directory (ADSI):
    - Active Directory PowerShell module (optional but recommended)
    - Domain connectivity and appropriate AD permissions
    - Modify permissions on user/contact/group objects
    - PowerShell 5.1 or later
    
    The script will:
    1. Verify required modules/cmdlets are available
    2. Connect to Exchange Online (if not using -OnPremise)
    3. Process each identity and update HiddenFromAddressListsEnabled property
    4. Generate detailed progress output
    5. Export results to timestamped CSV file
    6. Display summary statistics

.LINK
    https://docs.microsoft.com/en-us/powershell/module/exchange/set-mailbox
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false, ParameterSetName="CSV", HelpMessage="Path to CSV file containing user identities")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CsvPath,
    
    [Parameter(Mandatory=$false, ParameterSetName="Array", HelpMessage="Array of user identities to process")]
    [ValidateNotNullOrEmpty()]
    [object[]]$Identities,
    
    [Parameter(Mandatory=$false, HelpMessage="Column name to use from CSV for identity")]
    [string]$IdentityColumn,
    
    [Parameter(Mandatory=$false, HelpMessage="Show users in GAL instead of hiding them")]
    [switch]$ShowInGAL,
    
    [Parameter(Mandatory=$false, HelpMessage="Use on-premise Exchange instead of Exchange Online")]
    [switch]$OnPremise,
    
    [Parameter(Mandatory=$false, HelpMessage="Modify AD objects directly using ADSI")]
    [switch]$UseADSI,
    
    [Parameter(Mandatory=$false, HelpMessage="LDAP search base for AD queries when using UseADSI")]
    [string]$SearchBase,
    
    [Parameter(Mandatory=$false, HelpMessage="Directory for output files")]
    [string]$OutputDirectory = "C:\Reports\GAL_Changes"
)

#Requires -Version 5.1

# Validate parameter combinations
if ($OnPremise -and $UseADSI) {
    Write-Host "❌ Cannot use both -OnPremise and -UseADSI switches together" -ForegroundColor Red
    Write-Host "   Choose one method: Exchange Online (default), -OnPremise, or -UseADSI" -ForegroundColor Yellow
    exit 1
}

# Script initialization
$ErrorActionPreference = "Stop"
$StartTime = Get-Date
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$Separator = "=" * 80

# Tracking variables
$SuccessCount = 0
$FailureCount = 0
$SkippedCount = 0
$Results = @()

# Determine operation mode
$OperationMode = if ($ShowInGAL) { "Show in GAL" } else { "Hide from GAL" }
$HiddenValue = -not $ShowInGAL

$EnvironmentType = if ($UseADSI) { "Active Directory (ADSI)" } elseif ($OnPremise) { "On-Premise Exchange" } else { "Exchange Online" }

Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "GLOBAL ADDRESS LIST VISIBILITY MANAGER" -ForegroundColor Cyan
Write-Host "Environment: $EnvironmentType" -ForegroundColor Cyan
Write-Host "Operation: $OperationMode" -ForegroundColor $(if($ShowInGAL){'Green'}else{'Yellow'})
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host $Separator -ForegroundColor Cyan

#region Module Verification
Write-Host "`n[1/5] Verifying required modules..." -ForegroundColor Cyan

if ($UseADSI) {
    # Check for ActiveDirectory module (optional but helpful)
    if (Get-Module -Name ActiveDirectory -ListAvailable) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            Write-Host "✅ ActiveDirectory module loaded" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  ActiveDirectory module found but couldn't load, will use ADSI directly" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "ℹ️  ActiveDirectory module not found, using ADSI directly" -ForegroundColor Cyan
    }
    
    # Verify domain connectivity
    try {
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        Write-Host "✅ Connected to domain: $($domain.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Cannot connect to Active Directory domain" -ForegroundColor Red
        Write-Host "   Ensure you are on a domain-joined machine or have domain connectivity" -ForegroundColor Yellow
        exit 1
    }
}
elseif ($OnPremise) {
    # Verify Exchange cmdlets are available for on-premise
    $ExchangeCmdlets = @('Get-Mailbox', 'Set-Mailbox')
    $MissingCmdlets = $ExchangeCmdlets | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }
    
    if ($MissingCmdlets) {
        Write-Host "❌ Required Exchange cmdlets not available: $($MissingCmdlets -join ', ')" -ForegroundColor Red
        Write-Host "   This script must be run from Exchange Management Shell or have Exchange cmdlets loaded" -ForegroundColor Yellow
        Write-Host "   You can load the Exchange snap-in with: Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "✅ Exchange cmdlets are available" -ForegroundColor Green
    
    # Try to get Exchange server info to verify connectivity
    try {
        $exchangeServer = Get-ExchangeServer -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exchangeServer) {
            Write-Host "✅ Connected to Exchange Server: $($exchangeServer.Name)" -ForegroundColor Green
        }
        else {
            Write-Host "⚠️  Exchange cmdlets available but cannot verify server connectivity" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "⚠️  Exchange cmdlets available but cannot verify server connectivity" -ForegroundColor Yellow
    }
}
else {
    # Verify Exchange Online module
    $RequiredModule = "ExchangeOnlineManagement"
    if (-not (Get-Module -Name $RequiredModule -ListAvailable)) {
        Write-Host "❌ Required module '$RequiredModule' is not installed" -ForegroundColor Red
        Write-Host "   Install with: Install-Module $RequiredModule -Scope CurrentUser" -ForegroundColor Yellow
        exit 1
    }
    
    try {
        Import-Module $RequiredModule -ErrorAction Stop
        Write-Host "✅ Module '$RequiredModule' loaded successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to import module: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
#endregion

#region Exchange Connection
if ($UseADSI) {
    Write-Host "`n[2/5] Preparing Active Directory access..." -ForegroundColor Cyan
    
    try {
        # Get domain information
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $domainDN = "DC=" + ($domain.Name -replace '\.',',DC=')
        
        if ($SearchBase) {
            $searchBaseDN = $SearchBase
            Write-Host "✅ Using search base: $searchBaseDN" -ForegroundColor Green
        }
        else {
            $searchBaseDN = $domainDN
            Write-Host "✅ Using domain root: $searchBaseDN" -ForegroundColor Green
        }
        
        # Test LDAP connectivity
        $testSearch = New-Object System.DirectoryServices.DirectorySearcher
        $testSearch.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$searchBaseDN")
        $testSearch.Filter = "(objectClass=user)"
        $testSearch.PageSize = 1
        $null = $testSearch.FindOne()
        
        Write-Host "✅ LDAP connectivity verified" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to access Active Directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
elseif (-not $OnPremise) {
    Write-Host "`n[2/5] Connecting to Exchange Online..." -ForegroundColor Cyan
    
    try {
        # Check if already connected
        $existingConnection = Get-ConnectionInformation -ErrorAction SilentlyContinue
        
        if ($existingConnection) {
            Write-Host "✅ Already connected to Exchange Online as $($existingConnection.UserPrincipalName)" -ForegroundColor Green
        }
        else {
            Connect-ExchangeOnline -ShowProgress $false -ErrorAction Stop
            Write-Host "✅ Connected to Exchange Online" -ForegroundColor Green
        }
        
        # Verify connection with a simple command
        $null = Get-OrganizationConfig -ErrorAction Stop
    }
    catch {
        Write-Host "❌ Failed to connect to Exchange Online: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Ensure you have Exchange Online administrator permissions" -ForegroundColor Yellow
        exit 1
    }
}
else {
    Write-Host "`n[2/5] Using On-Premise Exchange..." -ForegroundColor Cyan
    
    try {
        # Verify we can run a basic command
        $null = Get-Mailbox -ResultSize 1 -ErrorAction Stop
        Write-Host "✅ On-premise Exchange cmdlets verified" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to execute Exchange cmdlets: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Ensure you have Exchange administrator permissions and are running from Exchange Management Shell" -ForegroundColor Yellow
        exit 1
    }
}
#endregion

#region Load Identities
Write-Host "`n[3/5] Loading user identities..." -ForegroundColor Cyan

$UserIdentities = @()

if ($PSCmdlet.ParameterSetName -eq "CSV") {
    # Load from CSV
    try {
        $CsvData = Import-Csv -Path $CsvPath -ErrorAction Stop
        Write-Host "✅ Loaded CSV file: $CsvPath" -ForegroundColor Green
        Write-Host "   Total rows: $($CsvData.Count)" -ForegroundColor Gray
        
        # Determine which column to use
        $StandardColumns = @('Identity', 'Email', 'EmailAddress', 'UserPrincipalName', 'UPN', 'DisplayName', 'User', 'SamAccountName')
        
        if ($IdentityColumn) {
            if ($CsvData[0].PSObject.Properties.Name -contains $IdentityColumn) {
                $ColumnToUse = $IdentityColumn
                Write-Host "✅ Using specified column: $ColumnToUse" -ForegroundColor Green
            }
            else {
                Write-Host "❌ Specified column '$IdentityColumn' not found in CSV" -ForegroundColor Red
                Write-Host "   Available columns: $($CsvData[0].PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
                exit 1
            }
        }
        else {
            # Auto-detect column
            $ColumnToUse = $StandardColumns | Where-Object { $CsvData[0].PSObject.Properties.Name -contains $_ } | Select-Object -First 1
            
            if (-not $ColumnToUse) {
                Write-Host "❌ Could not auto-detect identity column in CSV" -ForegroundColor Red
                Write-Host "   Available columns: $($CsvData[0].PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
                Write-Host "   Use -IdentityColumn to specify which column to use" -ForegroundColor Yellow
                exit 1
            }
            Write-Host "✅ Auto-detected identity column: $ColumnToUse" -ForegroundColor Green
        }
        
        # Extract identities
        $UserIdentities = $CsvData | ForEach-Object { $_.$ColumnToUse } | Where-Object { $_ -and $_.Trim() }
        
        if ($UserIdentities.Count -eq 0) {
            Write-Host "❌ No valid identities found in CSV column '$ColumnToUse'" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "✅ Extracted $($UserIdentities.Count) identities from CSV" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to load CSV: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
else {
    # Use provided array
    if ($null -eq $Identities -or $Identities.Count -eq 0) {
        Write-Host "❌ No identities provided. Use -CsvPath or -Identities parameter" -ForegroundColor Red
        exit 1
    }
    
    # Handle hashtable arrays
    $UserIdentities = $Identities | ForEach-Object {
        if ($_ -is [hashtable] -or $_.GetType().Name -eq 'PSCustomObject') {
            # Try to extract identity from common properties (PS 5.1 compatible)
            $identity = $null
            $propertiesToTry = @('Identity', 'Email', 'EmailAddress', 'UserPrincipalName', 'UPN', 'DisplayName', 'User')
            
            foreach ($prop in $propertiesToTry) {
                if ($_ -is [hashtable] -and $_.ContainsKey($prop) -and $_[$prop]) {
                    $identity = $_[$prop]
                    break
                }
                elseif ($_ -is [PSCustomObject] -and $_.PSObject.Properties[$prop] -and $_.$prop) {
                    $identity = $_.$prop
                    break
                }
            }
            
            if ($identity) { $identity } else { $_ }
        }
        else {
            $_
        }
    } | Where-Object { $_ -and $_.ToString().Trim() }
    
    Write-Host "✅ Loaded $($UserIdentities.Count) identities from array" -ForegroundColor Green
}

Write-Host "`n   Identities to process:" -ForegroundColor Gray
$UserIdentities | Select-Object -First 5 | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
if ($UserIdentities.Count -gt 5) {
    Write-Host "   ... and $($UserIdentities.Count - 5) more" -ForegroundColor Gray
}
#endregion

#region Create Output Directory
if (!(Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
        Write-Host "`n✅ Created output directory: $OutputDirectory" -ForegroundColor Green
    }
    catch {
        Write-Host "`n❌ Cannot create output directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
#endregion

#region Process Users
Write-Host "`n[4/5] Processing users..." -ForegroundColor Cyan
Write-Host "   Setting HiddenFromAddressListsEnabled = $HiddenValue" -ForegroundColor Gray

$Counter = 0
foreach ($Identity in $UserIdentities) {
    $Counter++
    $PercentComplete = [math]::Round(($Counter / $UserIdentities.Count) * 100, 0)
    Write-Progress -Activity "Processing mailboxes" -Status "$Counter of $($UserIdentities.Count)" -PercentComplete $PercentComplete
    
    $Result = [PSCustomObject]@{
        Identity = $Identity
        Operation = $OperationMode
        Status = ""
        CurrentHiddenValue = $null
        NewHiddenValue = $HiddenValue
        Message = ""
        ProcessedTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }
    
    try {
        # Get current mailbox or AD object
        Write-Host "   [$Counter/$($UserIdentities.Count)] Processing: $Identity" -ForegroundColor Cyan
        
        if ($UseADSI) {
            # Find AD object using ADSI
            $adObject = $null
            
            # Try different search filters
            $filters = @(
                "(userPrincipalName=$Identity)",
                "(mail=$Identity)",
                "(sAMAccountName=$Identity)",
                "(distinguishedName=$Identity)",
                "(cn=$Identity)"
            )
            
            $searcher = New-Object System.DirectoryServices.DirectorySearcher
            $searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$searchBaseDN")
            $searcher.PageSize = 1000
            
            foreach ($filter in $filters) {
                $searcher.Filter = "(&(|(objectClass=user)(objectClass=contact)(objectClass=group))$filter)"
                $searchResult = $searcher.FindOne()
                
                if ($searchResult) {
                    $adObject = $searchResult.GetDirectoryEntry()
                    break
                }
            }
            
            if ($null -eq $adObject) {
                Write-Host "   ⚠️  AD object not found: $Identity" -ForegroundColor Yellow
                $Result.Status = "Skipped"
                $Result.Message = "AD object not found"
                $SkippedCount++
                $Results += $Result
                continue
            }
            
            # Get current value
            $currentValue = $adObject.Properties["msExchHideFromAddressLists"].Value
            $Result.CurrentHiddenValue = [bool]$currentValue
            
            # Check if change is needed
            if ([bool]$currentValue -eq $HiddenValue) {
                Write-Host "   ℹ️  Already configured correctly (msExchHideFromAddressLists = $HiddenValue)" -ForegroundColor Gray
                $Result.Status = "Skipped"
                $Result.Message = "Already configured correctly"
                $SkippedCount++
                $Results += $Result
                continue
            }
            
            # Apply change
            if ($PSCmdlet.ShouldProcess($Identity, "Set msExchHideFromAddressLists to $HiddenValue")) {
                if ($HiddenValue) {
                    $adObject.Put("msExchHideFromAddressLists", $true)
                }
                else {
                    # Remove the attribute or set to false
                    if ($adObject.Properties.Contains("msExchHideFromAddressLists")) {
                        $adObject.PutEx(1, "msExchHideFromAddressLists", $null)  # 1 = Clear
                    }
                }
                $adObject.SetInfo()
                
                Write-Host "   ✅ Successfully updated AD object" -ForegroundColor Green
                $Result.Status = "Success"
                $Result.Message = "Successfully updated msExchHideFromAddressLists to $HiddenValue"
                $SuccessCount++
            }
            else {
                Write-Host "   ℹ️  WhatIf: Would set msExchHideFromAddressLists to $HiddenValue" -ForegroundColor Cyan
                $Result.Status = "WhatIf"
                $Result.Message = "WhatIf mode - no changes made"
                $SkippedCount++
            }
        }
        else {
            # Exchange mailbox processing
            $Mailbox = Get-Mailbox -Identity $Identity -ErrorAction Stop
        
            if ($null -eq $Mailbox) {
                Write-Host "   ⚠️  Mailbox not found: $Identity" -ForegroundColor Yellow
                $Result.Status = "Skipped"
                $Result.Message = "Mailbox not found"
                $SkippedCount++
                $Results += $Result
                continue
            }
            
            $Result.CurrentHiddenValue = $Mailbox.HiddenFromAddressListsEnabled
            
            # Check if change is needed
            if ($Mailbox.HiddenFromAddressListsEnabled -eq $HiddenValue) {
                Write-Host "   ℹ️  Already configured correctly (HiddenFromAddressListsEnabled = $HiddenValue)" -ForegroundColor Gray
                $Result.Status = "Skipped"
                $Result.Message = "Already configured correctly"
                $SkippedCount++
                $Results += $Result
                continue
            }
            
            # Apply change
            if ($PSCmdlet.ShouldProcess($Identity, "Set HiddenFromAddressListsEnabled to $HiddenValue")) {
                Set-Mailbox -Identity $Mailbox.Identity -HiddenFromAddressListsEnabled $HiddenValue -ErrorAction Stop
                Write-Host "   ✅ Successfully updated" -ForegroundColor Green
                $Result.Status = "Success"
                $Result.Message = "Successfully updated HiddenFromAddressListsEnabled to $HiddenValue"
                $SuccessCount++
            }
            else {
                Write-Host "   ℹ️  WhatIf: Would set HiddenFromAddressListsEnabled to $HiddenValue" -ForegroundColor Cyan
                $Result.Status = "WhatIf"
                $Result.Message = "WhatIf mode - no changes made"
                $SkippedCount++
            }
        }
    }
    catch {
        Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        $Result.Status = "Failed"
        $Result.Message = $_.Exception.Message
        $FailureCount++
    }
    
    $Results += $Result
}

Write-Progress -Activity "Processing mailboxes" -Completed
#endregion

#region Export Results
Write-Host "`n[5/5] Exporting results..." -ForegroundColor Cyan

$OutputFile = Join-Path $OutputDirectory "GAL_Changes_$Timestamp.csv"

try {
    $Results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    Write-Host "✅ Results exported to: $OutputFile" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to export results: $($_.Exception.Message)" -ForegroundColor Red
}
#endregion

#region Summary
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan
Write-Host "Operation:        $OperationMode" -ForegroundColor White
Write-Host "Total Processed:  $($UserIdentities.Count)" -ForegroundColor White
Write-Host "Successful:       $SuccessCount" -ForegroundColor Green
Write-Host "Failed:           $FailureCount" -ForegroundColor $(if($FailureCount -gt 0){'Red'}else{'White'})
Write-Host "Skipped:          $SkippedCount" -ForegroundColor Yellow
Write-Host "Duration:         $($Duration.ToString('mm\:ss'))" -ForegroundColor Gray
Write-Host "Results File:     $OutputFile" -ForegroundColor Gray
Write-Host $Separator -ForegroundColor Cyan

# Display failures if any
if ($FailureCount -gt 0) {
    Write-Host "`nFailed Items:" -ForegroundColor Red
    $Results | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
        Write-Host "  - $($_.Identity): $($_.Message)" -ForegroundColor Red
    }
}
#endregion

# Cleanup
Write-Host "`n✅ Script completed" -ForegroundColor Green
