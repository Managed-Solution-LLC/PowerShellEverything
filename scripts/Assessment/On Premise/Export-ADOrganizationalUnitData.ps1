<#
.SYNOPSIS
    Export Active Directory users, computers, and groups to CSV files and optional Excel workbook.

.DESCRIPTION
    This script exports comprehensive Active Directory data for all users, computers, and groups
    in the domain. By default, it exports ALL AD objects. Optionally, you can filter to a specific
    Organizational Unit (OU) using the -FilterByOU switch.
    
    It creates three separate CSV files for users, computers (devices), and groups, then optionally
    combines them into a single Excel workbook with multiple sheets for easy analysis and reporting.
    
    Key features:
    - Exports all AD objects by default (entire domain)
    - Optional OU filtering with interactive OU selection
    - Comprehensive user data export (identity, contact info, account status, group memberships)
    - Computer/device export with OS details, last logon, and DNS hostname
    - Group export with membership counts and scope information
    - Automatic Excel workbook generation with formatted sheets (optional)
    - Timestamp-based file naming for historical tracking

.PARAMETER FilterByOU
    Enable OU filtering mode. When specified, allows filtering export to a specific OU.
    If SearchBase is not provided with this switch, interactive OU selection will be displayed.
    Default: $false (exports all AD objects)

.PARAMETER SearchBase
    The distinguished name (DN) of the OU to export data from.
    Only used when -FilterByOU is specified.
    If not provided with -FilterByOU, the script will prompt for interactive OU selection.
    Example: "OU=Users,OU=Corporate,DC=contoso,DC=com"

.PARAMETER OutputDirectory
    Directory where CSV and Excel files will be saved.
    Default: "C:\Reports\AD_Exports"

.PARAMETER OrganizationName
    Organization name used in report headers and filenames.
    Default: "Organization"

.PARAMETER IncludeSubOUs
    Include all sub-OUs in the export (recursive search).
    Only applies when -FilterByOU is specified.
    Default: $false (only immediate OU contents)

.PARAMETER ExcludeDisabled
    Exclude disabled user and computer accounts from the export.
    Default: $false (includes all accounts)

.PARAMETER NoExcel
    Skip Excel workbook generation and only export CSV files.
    Use this when ImportExcel module is not available or only CSV files are needed.
    Default: $false (Excel workbook will be created)

.EXAMPLE
    .\Export-ADOrganizationalUnitData.ps1
    
    Exports ALL users, computers, and groups from the entire Active Directory domain.

.EXAMPLE
    .\Export-ADOrganizationalUnitData.ps1 -FilterByOU
    
    Launches interactive OU selection and exports only data from the selected OU.

.EXAMPLE
    .\Export-ADOrganizationalUnitData.ps1 -FilterByOU -SearchBase "OU=Users,DC=contoso,DC=com" -IncludeSubOUs
    
    Exports users, computers, and groups from specified OU and all sub-OUs.

.EXAMPLE
    .\Export-ADOrganizationalUnitData.ps1 -FilterByOU -SearchBase "OU=IT,DC=contoso,DC=com" -ExcludeDisabled
    
    Exports only enabled accounts from IT OU.

.EXAMPLE
    .\Export-ADOrganizationalUnitData.ps1 -ExcludeDisabled -OutputDirectory "C:\ADReports"
    
    Exports all enabled accounts from entire domain to custom directory.

.EXAMPLE
    .\Export-ADOrganizationalUnitData.ps1 -OrganizationName "Contoso Corp"
    
    Customizes the organization name in reports and filenames.

.EXAMPLE
    .\Export-ADOrganizationalUnitData.ps1 -NoExcel
    
    Exports only CSV files without creating Excel workbook (useful when ImportExcel is not available).

.NOTES
    Author: W. Ford
    Date: 2026-01-19
    Version: 1.0
    
    Requirements:
    - Active Directory PowerShell module
    - ImportExcel PowerShell module (for Excel generation)
    - Domain membership or appropriate credentials
    - Read permissions on target OUs
    - PowerShell 5.1 or later
    
    The script generates:
    - Three CSV files (Users, Computers, Groups)
    - One Excel workbook combining all three sheets
    - Detailed console output with color-coded status messages
    
    Output files use timestamp format: {OrgName}_AD_{Type}_{YYYYMMDD_HHmmss}.csv

.LINK
    https://docs.microsoft.com/en-us/powershell/module/activedirectory/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Enable OU filtering mode")]
    [switch]$FilterByOU,
    
    [Parameter(Mandatory=$false, HelpMessage="Distinguished name of the OU to export from (requires -FilterByOU)")]
    [ValidateNotNullOrEmpty()]
    [string]$SearchBase,
    
    [Parameter(Mandatory=$false, HelpMessage="Directory for output files")]
    [string]$OutputDirectory = "C:\Reports\AD_Exports",
    
    [Parameter(Mandatory=$false, HelpMessage="Organization name for reports")]
    [string]$OrganizationName = "Organization",
    
    [Parameter(Mandatory=$false, HelpMessage="Include sub-OUs in export (requires -FilterByOU)")]
    [switch]$IncludeSubOUs,
    
    [Parameter(Mandatory=$false, HelpMessage="Exclude disabled accounts")]
    [switch]$ExcludeDisabled,
    
    [Parameter(Mandatory=$false, HelpMessage="Skip Excel workbook generation, export CSV files only")]
    [switch]$NoExcel
)

#region Pre-Execution Checks

# 1. Validate PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "❌ This script requires PowerShell 5.1 or later" -ForegroundColor Red
    Write-Host "   Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    exit 1
}

# 2. Check required modules
$RequiredModules = @('ActiveDirectory')
if (-not $NoExcel) {
    $RequiredModules += 'ImportExcel'
}
$MissingModules = @()

foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -Name $Module -ListAvailable)) {
        $MissingModules += $Module
    }
}

if ($MissingModules.Count -gt 0) {
    Write-Host "❌ Missing required modules: $($MissingModules -join ', ')" -ForegroundColor Red
    
    # Handle ActiveDirectory module
    if ($MissingModules -contains 'ActiveDirectory') {
        Write-Host "`nActiveDirectory module is required but not installed." -ForegroundColor Yellow
        Write-Host "Installation instructions:" -ForegroundColor Yellow
        Write-Host "   - Windows 10/11: Settings > Apps > Optional Features > RSAT: Active Directory" -ForegroundColor Cyan
        Write-Host "   - Or run: Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'" -ForegroundColor Cyan
        Write-Host "   - Or run this script on a domain controller" -ForegroundColor Cyan
        exit 1
    }
    
    # Handle ImportExcel module - offer to install
    if ($MissingModules -contains 'ImportExcel') {
        Write-Host "`nImportExcel module is required to combine CSV files into Excel workbook." -ForegroundColor Yellow
        $install = Read-Host "Would you like to install ImportExcel now? (Y/N)"
        
        if ($install -eq 'Y' -or $install -eq 'y') {
            try {
                Write-Host "`nInstalling ImportExcel module..." -ForegroundColor Cyan
                Install-Module -Name ImportExcel -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                Write-Host "✅ ImportExcel module installed successfully" -ForegroundColor Green
                
                # Verify installation
                if (-not (Get-Module -Name ImportExcel -ListAvailable)) {
                    throw "Module installation completed but module not found"
                }
            }
            catch {
                Write-Host "❌ Failed to install ImportExcel: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "`nYou can install it manually with: Install-Module ImportExcel -Scope CurrentUser" -ForegroundColor Yellow
                exit 1
            }
        }
        else {
            Write-Host "`n❌ ImportExcel module is required. Exiting." -ForegroundColor Red
            Write-Host "Install manually with: Install-Module ImportExcel -Scope CurrentUser" -ForegroundColor Yellow
            exit 1
        }
    }
}

# 3. Import modules
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    if (-not $NoExcel) {
        Import-Module ImportExcel -ErrorAction Stop
    }
    Write-Host "✅ Required modules loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to import modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 4. Validate output directory
if (!(Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
        Write-Host "✅ Created output directory: $OutputDirectory" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Cannot create output directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# 5. Test write permissions
$testFile = Join-Path $OutputDirectory "test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
try {
    "test" | Out-File -FilePath $testFile -ErrorAction Stop
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Write permissions verified" -ForegroundColor Green
}
catch {
    Write-Host "❌ No write permission to output directory" -ForegroundColor Red
    exit 1
}

# 6. Verify AD connectivity
try {
    $null = Get-ADDomain -ErrorAction Stop
    Write-Host "✅ Connected to Active Directory" -ForegroundColor Green
}
catch {
    Write-Host "❌ Cannot connect to Active Directory: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

#endregion

#region Helper Functions

function Write-StatusMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Type) {
        "Error" {
            Write-Host "[$timestamp] ❌ ERROR: $Message" -ForegroundColor Red
            $script:ErrorCount++
        }
        "Warning" {
            Write-Host "[$timestamp] ⚠️  WARNING: $Message" -ForegroundColor Yellow
            $script:WarningCount++
        }
        "Success" {
            Write-Host "[$timestamp] ✅ SUCCESS: $Message" -ForegroundColor Green
        }
        default {
            Write-Host "[$timestamp] ℹ️  INFO: $Message" -ForegroundColor Cyan
        }
    }
}

function Get-OUSelection {
    <#
    .SYNOPSIS
        Interactive OU selection from Active Directory
    #>
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "ORGANIZATIONAL UNIT SELECTION" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    try {
        # Get all OUs
        Write-Host "`nRetrieving Organizational Units..." -ForegroundColor Yellow
        $OUs = Get-ADOrganizationalUnit -Filter * -Properties CanonicalName, Description |
               Sort-Object CanonicalName
        
        if ($OUs.Count -eq 0) {
            Write-StatusMessage "No OUs found in Active Directory" -Type Warning
            return $null
        }
        
        Write-Host "`nAvailable Organizational Units:" -ForegroundColor White
        Write-Host "-" * 80 -ForegroundColor Gray
        
        for ($i = 0; $i -lt $OUs.Count; $i++) {
            $ou = $OUs[$i]
            $displayName = $ou.CanonicalName
            $desc = if ($ou.Description) { " - $($ou.Description)" } else { "" }
            Write-Host "  [$($i + 1)] $displayName$desc" -ForegroundColor White
        }
        
        Write-Host "-" * 80 -ForegroundColor Gray
        
        # Get user selection
        do {
            $selection = Read-Host "`nSelect OU number (1-$($OUs.Count)) or 'Q' to quit"
            
            if ($selection -eq 'Q') {
                Write-Host "Operation cancelled by user" -ForegroundColor Yellow
                return $null
            }
            
            $selectionNum = 0
            $validSelection = [int]::TryParse($selection, [ref]$selectionNum) -and 
                            ($selectionNum -ge 1) -and ($selectionNum -le $OUs.Count)
            
            if (-not $validSelection) {
                Write-Host "Invalid selection. Please enter a number between 1 and $($OUs.Count)" -ForegroundColor Red
            }
        } while (-not $validSelection)
        
        $selectedOU = $OUs[$selectionNum - 1]
        Write-Host "`n✅ Selected OU: $($selectedOU.CanonicalName)" -ForegroundColor Green
        
        return $selectedOU.DistinguishedName
    }
    catch {
        Write-StatusMessage "Failed to retrieve OUs: $($_.Exception.Message)" -Type Error
        return $null
    }
}

#endregion

#region Main Script

# Initialize tracking variables
$StartTime = Get-Date
$ErrorCount = 0
$WarningCount = 0
$Separator = "=" * 80
$SubSeparator = "-" * 60

# Display header
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "$OrganizationName - ACTIVE DIRECTORY EXPORT" -ForegroundColor Cyan
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host $Separator -ForegroundColor Cyan

# Determine SearchBase and scope
if ($FilterByOU) {
    # OU filtering mode
    if (-not $SearchBase) {
        $SearchBase = Get-OUSelection
        if (-not $SearchBase) {
            Write-Host "`n❌ No OU selected. Exiting." -ForegroundColor Red
            exit 1
        }
    }
    
    # Validate SearchBase
    try {
        $OUObject = Get-ADOrganizationalUnit -Identity $SearchBase -ErrorAction Stop
        Write-Host "`n✅ Target OU: $($OUObject.DistinguishedName)" -ForegroundColor Green
        if ($OUObject.Description) {
            Write-Host "   Description: $($OUObject.Description)" -ForegroundColor Gray
        }
    }
    catch {
        Write-StatusMessage "Invalid SearchBase: $($_.Exception.Message)" -Type Error
        exit 1
    }
    
    $SearchScope = if ($IncludeSubOUs) { "Subtree" } else { "OneLevel" }
    Write-Host "   Search scope: $SearchScope" -ForegroundColor Gray
} else {
    # Export entire domain
    Write-Host "`n✅ Export scope: Entire Active Directory domain" -ForegroundColor Green
    $SearchBase = $null
    $SearchScope = "Subtree"
    
    if ($IncludeSubOUs) {
        Write-Host "   Note: -IncludeSubOUs is ignored when not using -FilterByOU" -ForegroundColor Yellow
    }
}

# Generate timestamp and filenames
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$FilePrefix = "$($OrganizationName -replace '[^a-zA-Z0-9]', '_')_AD"
$UsersCSV = Join-Path $OutputDirectory "$($FilePrefix)_Users_$Timestamp.csv"
$ComputersCSV = Join-Path $OutputDirectory "$($FilePrefix)_Computers_$Timestamp.csv"
$GroupsCSV = Join-Path $OutputDirectory "$($FilePrefix)_Groups_$Timestamp.csv"
$ExcelFile = Join-Path $OutputDirectory "$($FilePrefix)_Combined_$Timestamp.xlsx"

#region Export Users

Write-Host "`n$SubSeparator" -ForegroundColor Cyan
Write-Host "EXPORTING USERS" -ForegroundColor Cyan
Write-Host $SubSeparator -ForegroundColor Cyan

try {
    Write-StatusMessage "Retrieving user accounts..." -Type Info
    
    $UserFilter = if ($ExcludeDisabled) {
        { (Enabled -eq $true) -and (ObjectClass -eq 'user') }
    } else {
        { ObjectClass -eq 'user' }
    }
    
    $getUserParams = @{
        Filter = $UserFilter
        Properties = @('DisplayName', 'EmailAddress', 'Title', 'Department', 'Manager', 'Enabled', 
                    'LastLogonDate', 'WhenCreated', 'WhenChanged', 'PasswordLastSet', 
                    'PasswordNeverExpires', 'LockedOut', 'MemberOf', 'Description', 
                    'Office', 'TelephoneNumber', 'Mobile', 'StreetAddress', 'City', 'State', 
                    'PostalCode', 'Country', 'Company')
    }
    
    if ($FilterByOU) {
        $getUserParams['SearchBase'] = $SearchBase
        $getUserParams['SearchScope'] = $SearchScope
    }
    
    $Users = Get-ADUser @getUserParams
    
    if ($Users.Count -eq 0) {
        Write-StatusMessage "No users found" -Type Warning
    } else {
        Write-StatusMessage "Found $($Users.Count) user(s)" -Type Success
        
        # Build user export data
        $UserData = $Users | ForEach-Object {
            $managerName = if ($_.Manager) {
                try {
                    (Get-ADUser $_.Manager -Properties DisplayName -ErrorAction Stop).DisplayName
                } catch { "N/A" }
            } else { "N/A" }
            
            $groupCount = if ($_.MemberOf) { $_.MemberOf.Count } else { 0 }
            
            [PSCustomObject]@{
                'SamAccountName' = $_.SamAccountName
                'DisplayName' = $_.DisplayName
                'UserPrincipalName' = $_.UserPrincipalName
                'EmailAddress' = $_.EmailAddress
                'Enabled' = $_.Enabled
                'LockedOut' = $_.LockedOut
                'Title' = $_.Title
                'Department' = $_.Department
                'Company' = $_.Company
                'Manager' = $managerName
                'Office' = $_.Office
                'TelephoneNumber' = $_.TelephoneNumber
                'Mobile' = $_.Mobile
                'StreetAddress' = $_.StreetAddress
                'City' = $_.City
                'State' = $_.State
                'PostalCode' = $_.PostalCode
                'Country' = $_.Country
                'LastLogonDate' = $_.LastLogonDate
                'PasswordLastSet' = $_.PasswordLastSet
                'PasswordNeverExpires' = $_.PasswordNeverExpires
                'WhenCreated' = $_.WhenCreated
                'WhenChanged' = $_.WhenChanged
                'GroupMembershipCount' = $groupCount
                'Description' = $_.Description
                'DistinguishedName' = $_.DistinguishedName
            }
        }
        
        # Export to CSV
        $UserData | Export-Csv -Path $UsersCSV -NoTypeInformation -Encoding UTF8
        Write-StatusMessage "Exported $($UserData.Count) user(s) to: $UsersCSV" -Type Success
    }
}
catch {
    Write-StatusMessage "Failed to export users: $($_.Exception.Message)" -Type Error
}

#endregion

#region Export Computers

Write-Host "`n$SubSeparator" -ForegroundColor Cyan
Write-Host "EXPORTING COMPUTERS" -ForegroundColor Cyan
Write-Host $SubSeparator -ForegroundColor Cyan

try {
    Write-StatusMessage "Retrieving computer accounts..." -Type Info
    
    $ComputerFilter = if ($ExcludeDisabled) {
        { Enabled -eq $true }
    } else {
        { ObjectClass -eq 'computer' }
    }
    
    $getComputerParams = @{
        Filter = $ComputerFilter
        Properties = @('OperatingSystem', 'OperatingSystemVersion', 'OperatingSystemServicePack',
                    'LastLogonDate', 'WhenCreated', 'WhenChanged', 'Enabled', 'Description',
                    'IPv4Address', 'DNSHostName', 'Location', 'ManagedBy')
    }
    
    if ($FilterByOU) {
        $getComputerParams['SearchBase'] = $SearchBase
        $getComputerParams['SearchScope'] = $SearchScope
    }
    
    $Computers = Get-ADComputer @getComputerParams
    
    if ($Computers.Count -eq 0) {
        Write-StatusMessage "No computers found" -Type Warning
    } else {
        Write-StatusMessage "Found $($Computers.Count) computer(s)" -Type Success
        
        # Build computer export data
        $ComputerData = $Computers | ForEach-Object {
            $managedBy = if ($_.ManagedBy) {
                try {
                    (Get-ADUser $_.ManagedBy -Properties DisplayName -ErrorAction Stop).DisplayName
                } catch { $_.ManagedBy }
            } else { "N/A" }
            
            $daysSinceLogon = if ($_.LastLogonDate) {
                [math]::Round((New-TimeSpan -Start $_.LastLogonDate -End (Get-Date)).TotalDays)
            } else { "Never" }
            
            [PSCustomObject]@{
                'Name' = $_.Name
                'DNSHostName' = $_.DNSHostName
                'Enabled' = $_.Enabled
                'OperatingSystem' = $_.OperatingSystem
                'OSVersion' = $_.OperatingSystemVersion
                'ServicePack' = $_.OperatingSystemServicePack
                'IPv4Address' = $_.IPv4Address
                'Location' = $_.Location
                'LastLogonDate' = $_.LastLogonDate
                'DaysSinceLastLogon' = $daysSinceLogon
                'WhenCreated' = $_.WhenCreated
                'WhenChanged' = $_.WhenChanged
                'ManagedBy' = $managedBy
                'Description' = $_.Description
                'DistinguishedName' = $_.DistinguishedName
            }
        }
        
        # Export to CSV
        $ComputerData | Export-Csv -Path $ComputersCSV -NoTypeInformation -Encoding UTF8
        Write-StatusMessage "Exported $($ComputerData.Count) computer(s) to: $ComputersCSV" -Type Success
    }
}
catch {
    Write-StatusMessage "Failed to export computers: $($_.Exception.Message)" -Type Error
}

#endregion

#region Export Groups

Write-Host "`n$SubSeparator" -ForegroundColor Cyan
Write-Host "EXPORTING GROUPS" -ForegroundColor Cyan
Write-Host $SubSeparator -ForegroundColor Cyan

try {
    Write-StatusMessage "Retrieving groups..." -Type Info
    
    $getGroupParams = @{
        Filter = '*'
        Properties = @('Description', 'GroupCategory', 'GroupScope', 'WhenCreated', 'WhenChanged',
                    'ManagedBy', 'Members', 'MemberOf')
    }
    
    if ($FilterByOU) {
        $getGroupParams['SearchBase'] = $SearchBase
        $getGroupParams['SearchScope'] = $SearchScope
    }
    
    $Groups = Get-ADGroup @getGroupParams
    
    if ($Groups.Count -eq 0) {
        Write-StatusMessage "No groups found" -Type Warning
    } else {
        Write-StatusMessage "Found $($Groups.Count) group(s)" -Type Success
        
        # Build group export data
        $GroupData = $Groups | ForEach-Object {
            $managedBy = if ($_.ManagedBy) {
                try {
                    (Get-ADUser $_.ManagedBy -Properties DisplayName -ErrorAction Stop).DisplayName
                } catch { $_.ManagedBy }
            } else { "N/A" }
            
            $memberCount = if ($_.Members) { $_.Members.Count } else { 0 }
            $memberOfCount = if ($_.MemberOf) { $_.MemberOf.Count } else { 0 }
            
            [PSCustomObject]@{
                'Name' = $_.Name
                'SamAccountName' = $_.SamAccountName
                'GroupCategory' = $_.GroupCategory
                'GroupScope' = $_.GroupScope
                'Description' = $_.Description
                'MemberCount' = $memberCount
                'MemberOfCount' = $memberOfCount
                'ManagedBy' = $managedBy
                'WhenCreated' = $_.WhenCreated
                'WhenChanged' = $_.WhenChanged
                'DistinguishedName' = $_.DistinguishedName
            }
        }
        
        # Export to CSV
        $GroupData | Export-Csv -Path $GroupsCSV -NoTypeInformation -Encoding UTF8
        Write-StatusMessage "Exported $($GroupData.Count) group(s) to: $GroupsCSV" -Type Success
    }
}
catch {
    Write-StatusMessage "Failed to export groups: $($_.Exception.Message)" -Type Error
}

#endregion

#region Combine into Excel

if (-not $NoExcel) {
    Write-Host "`n$SubSeparator" -ForegroundColor Cyan
    Write-Host "GENERATING EXCEL WORKBOOK" -ForegroundColor Cyan
    Write-Host $SubSeparator -ForegroundColor Cyan

    try {
        $sheetsCreated = 0
        
        # Import Users sheet
        if (Test-Path $UsersCSV) {
            Write-StatusMessage "Adding Users sheet..." -Type Info
            Import-Csv $UsersCSV | Export-Excel -Path $ExcelFile -WorksheetName "Users" `
                -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow
            $sheetsCreated++
        }
        
        # Import Computers sheet
        if (Test-Path $ComputersCSV) {
            Write-StatusMessage "Adding Computers sheet..." -Type Info
            Import-Csv $ComputersCSV | Export-Excel -Path $ExcelFile -WorksheetName "Computers" `
                -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow
            $sheetsCreated++
        }
        
        # Import Groups sheet
        if (Test-Path $GroupsCSV) {
            Write-StatusMessage "Adding Groups sheet..." -Type Info
            Import-Csv $GroupsCSV | Export-Excel -Path $ExcelFile -WorksheetName "Groups" `
                -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow
            $sheetsCreated++
        }
        
        if ($sheetsCreated -gt 0) {
            Write-StatusMessage "Created Excel workbook with $sheetsCreated sheet(s): $ExcelFile" -Type Success
        } else {
            Write-StatusMessage "No data to export to Excel" -Type Warning
        }
    }
    catch {
        Write-StatusMessage "Failed to create Excel workbook: $($_.Exception.Message)" -Type Error
    }
} else {
    Write-Host "`n$SubSeparator" -ForegroundColor Cyan
    Write-Host "Excel workbook generation skipped (-NoExcel specified)" -ForegroundColor Yellow
    Write-Host $SubSeparator -ForegroundColor Cyan
}

#endregion

#region Summary

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "EXPORT SUMMARY" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

Write-Host "`nExecution Time: $($Duration.ToString('mm\:ss'))" -ForegroundColor White

$statusColor = if ($ErrorCount -gt 0) { 'Red' } elseif ($WarningCount -gt 0) { 'Yellow' } else { 'Green' }
Write-Host "Status: Errors: $ErrorCount | Warnings: $WarningCount" -ForegroundColor $statusColor

Write-Host "`nExported Files:" -ForegroundColor White
if (Test-Path $UsersCSV) {
    $userCount = (Import-Csv $UsersCSV).Count
    Write-Host "  ✅ Users CSV: $UsersCSV ($userCount records)" -ForegroundColor Green
}
if (Test-Path $ComputersCSV) {
    $computerCount = (Import-Csv $ComputersCSV).Count
    Write-Host "  ✅ Computers CSV: $ComputersCSV ($computerCount records)" -ForegroundColor Green
}
if (Test-Path $GroupsCSV) {
    $groupCount = (Import-Csv $GroupsCSV).Count
    Write-Host "  ✅ Groups CSV: $GroupsCSV ($groupCount records)" -ForegroundColor Green
}
if (Test-Path $ExcelFile) {
    Write-Host "  ✅ Excel Workbook: $ExcelFile" -ForegroundColor Green
}

Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "Export completed successfully!" -ForegroundColor Green
Write-Host $Separator -ForegroundColor Cyan

#endregion
