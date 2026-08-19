<#
.SYNOPSIS
    Comprehensive Active Directory assessment for AD to AD migration planning and user matching.

.DESCRIPTION
    This script performs a comprehensive assessment of an Active Directory environment, exporting
    detailed information needed for AD to AD migration planning. It captures user accounts, groups,
    organizational units, computer objects, and key attributes required for matching users across
    source and target AD environments.
    
    Key features:
    - Exports all user accounts with attributes needed for matching (samAccountName, UPN, mail, employeeID, etc.)
    - Captures group memberships and nested groups
    - Documents OU structure and user distribution
    - Exports computer objects and their properties
    - Identifies privileged accounts and service accounts
    - Analyzes account states (enabled/disabled, password status)
    - Generates executive summary with migration considerations
    - All exports timestamped for tracking and comparison
    
    Data exported for user matching:
    - Core identifiers: samAccountName, UserPrincipalName, mail, employeeID, objectGUID
    - Personal info: givenName, surname, displayName, description
    - Organizational: department, title, company, office, manager
    - Contact: telephoneNumber, mobile, streetAddress, city, state, postalCode
    - Account status: enabled, locked, password expiry, last logon
    - Group memberships: all groups user is member of
    
.PARAMETER OutputDirectory
    Directory where assessment reports will be saved. Defaults to C:\Reports\AD_Assessment.
    Directory will be created if it doesn't exist.

.PARAMETER DomainController
    Specific domain controller to query. If not specified, will use the default DC.

.PARAMETER IncludeDisabledUsers
    Include disabled user accounts in the assessment. Default is enabled users only.

.PARAMETER IncludeComputers
    Include computer objects in the assessment.

.PARAMETER IncludeGroupDetails
    Include detailed group analysis with nested group memberships.

.PARAMETER SearchBase
    Specific OU distinguished name to limit the assessment scope.
    Example: "OU=Users,OU=Company,DC=contoso,DC=com"

.PARAMETER OrganizationName
    Organization name for report headers. Defaults to "Organization".

.EXAMPLE
    .\Get-ComprehensiveADReport.ps1
    
    Runs assessment with default settings, exports enabled users and groups to default directory.

.EXAMPLE
    .\Get-ComprehensiveADReport.ps1 -OutputDirectory "C:\Migration\SourceAD" -IncludeDisabledUsers -IncludeComputers
    
    Full assessment including disabled users and computers, saves to custom directory.

.EXAMPLE
    .\Get-ComprehensiveADReport.ps1 -SearchBase "OU=Corporate,DC=contoso,DC=com" -OrganizationName "Contoso"
    
    Limits assessment to specific OU and sets organization name for reports.

.EXAMPLE
    .\Get-ComprehensiveADReport.ps1 -DomainController "DC01.contoso.com" -IncludeGroupDetails
    
    Queries specific domain controller with detailed group analysis.

.NOTES
    Author: W. Ford
    Date: 2026-01-07
    Version: 1.0
    
    Requirements:
    - ActiveDirectory PowerShell module
    - Domain user permissions (read access to AD)
    - PowerShell 5.1 or later
    
    For AD to AD migrations:
    1. Run this script in SOURCE AD environment first
    2. Run again in TARGET AD environment
    3. Compare exported CSVs to identify matching criteria
    4. Use employeeID or mail as primary matching attributes
    5. Review privileged accounts list for special handling
    
    Output Files:
    - AD_Users_Full_{timestamp}.csv          - Complete user export with all attributes
    - AD_Groups_Summary_{timestamp}.csv      - All groups with member counts
    - AD_GroupMemberships_{timestamp}.csv    - User to group mappings
    - AD_OUs_Structure_{timestamp}.csv       - OU hierarchy and user distribution
    - AD_Computers_{timestamp}.csv           - Computer objects (if included)
    - AD_Assessment_Report_{timestamp}.txt   - Executive summary and statistics
    
.LINK
    https://docs.microsoft.com/en-us/powershell/module/activedirectory/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Output directory for assessment reports")]
    [string]$OutputDirectory = "C:\Reports\AD_Assessment",
    
    [Parameter(Mandatory=$false, HelpMessage="Target domain FQDN (e.g., contoso.com)")]
    [string]$Domain,
    
    [Parameter(Mandatory=$false, HelpMessage="Specific domain controller to query")]
    [string]$DomainController,
    
    [Parameter(Mandatory=$false, HelpMessage="Credentials for accessing different forest/domain")]
    [System.Management.Automation.PSCredential]$Credential,
    
    [Parameter(Mandatory=$false, HelpMessage="Include disabled user accounts")]
    [switch]$IncludeDisabledUsers,
    
    [Parameter(Mandatory=$false, HelpMessage="Include computer objects in assessment")]
    [switch]$IncludeComputers,
    
    [Parameter(Mandatory=$false, HelpMessage="Include detailed group analysis")]
    [switch]$IncludeGroupDetails,
    
    [Parameter(Mandatory=$false, HelpMessage="Specific OU to limit assessment scope")]
    [string]$SearchBase,
    
    [Parameter(Mandatory=$false, HelpMessage="Organization name for reports")]
    [string]$OrganizationName = "Organization"
)


# Initialize tracking variables
$StartTime = Get-Date
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$ErrorCount = 0
$WarningCount = 0
$Separator = "=" * 80
$SubSeparator = "-" * 60

# Status message function
function Write-StatusMessage {
    param(
        [string]$Message, 
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Type) {
        "Error"   { Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor Red; $script:ErrorCount++ }
        "Warning" { Write-Host "[$timestamp] WARNING: $Message" -ForegroundColor Yellow; $script:WarningCount++ }
        "Success" { Write-Host "[$timestamp] SUCCESS: $Message" -ForegroundColor Green }
        default   { Write-Host "[$timestamp] INFO: $Message" -ForegroundColor Cyan }
    }
}

# Safe command execution wrapper
function Invoke-SafeCommand {
    param(
        [scriptblock]$Command,
        [string]$ErrorMessage = "Command execution failed",
        [switch]$ContinueOnError
    )
    try {
        Write-Verbose "Executing command: $($Command.ToString().Substring(0, [Math]::Min(50, $Command.ToString().Length)))..."
        $result = & $Command
        
        if ($null -eq $result) {
            Write-StatusMessage "Command returned null result" -Type Warning
        }
        
        return $result
    }
    catch {
        $errorDetails = "$ErrorMessage - $($_.Exception.Message)"
        Write-StatusMessage $errorDetails -Type Error
        Write-Verbose "Stack Trace: $($_.ScriptStackTrace)"
        
        if (-not $ContinueOnError) {
            throw
        }
        return $null
    }
}

# Pre-execution checks
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "ACTIVE DIRECTORY MIGRATION ASSESSMENT" -ForegroundColor Cyan
Write-Host "$OrganizationName - AD Environment Analysis" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-StatusMessage "This script requires PowerShell 5.1 or later" -Type Error
    exit 1
}

# Verify ActiveDirectory module
if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
    Write-StatusMessage "ActiveDirectory module not found" -Type Error
    Write-Host "`nThe ActiveDirectory PowerShell module (RSAT) is required for this script." -ForegroundColor Yellow
    Write-Host "Would you like to install it now? (Y/N)" -ForegroundColor Cyan
    
    $response = Read-Host
    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host "`nInstalling RSAT Active Directory module..." -ForegroundColor Yellow
        
        # Detect OS type
        $isServer = (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -ne 1
        
        try {
            if ($isServer) {
                # Windows Server
                Write-Host "Detected Windows Server - using Install-WindowsFeature..." -ForegroundColor Cyan
                Install-WindowsFeature RSAT-AD-PowerShell -ErrorAction Stop | Out-Null
                Write-StatusMessage "RSAT Active Directory module installed successfully" -Type Success
            }
            else {
                # Windows 10/11
                Write-Host "Detected Windows Client - using Add-WindowsCapability..." -ForegroundColor Cyan
                Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 -ErrorAction Stop | Out-Null
                Write-StatusMessage "RSAT Active Directory module installed successfully" -Type Success
            }
            
            Write-Host "Importing ActiveDirectory module..." -ForegroundColor Yellow
            Import-Module ActiveDirectory -ErrorAction Stop
            Write-StatusMessage "ActiveDirectory module loaded successfully" -Type Success
        }
        catch {
            Write-StatusMessage "Failed to install RSAT: $($_.Exception.Message)" -Type Error
            Write-Host "`nManual installation instructions:" -ForegroundColor Yellow
            if ($isServer) {
                Write-Host "  Install-WindowsFeature RSAT-AD-PowerShell" -ForegroundColor White
            }
            else {
                Write-Host "  Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ForegroundColor White
            }
            exit 1
        }
    }
    else {
        Write-Host "`nInstallation cancelled. Cannot proceed without ActiveDirectory module." -ForegroundColor Yellow
        Write-Host "`nManual installation instructions:" -ForegroundColor Yellow
        Write-Host "  Windows 10/11: Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ForegroundColor White
        Write-Host "  Windows Server: Install-WindowsFeature RSAT-AD-PowerShell" -ForegroundColor White
        Write-Host "  Or run this script on a Domain Controller" -ForegroundColor White
        exit 1
    }
}
else {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-StatusMessage "ActiveDirectory module loaded successfully" -Type Success
    }
    catch {
        Write-StatusMessage "Failed to import ActiveDirectory module: $($_.Exception.Message)" -Type Error
        exit 1
    }
}

# Create output directory
if (!(Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
        Write-StatusMessage "Created output directory: $OutputDirectory" -Type Success
    }
    catch {
        Write-StatusMessage "Cannot create output directory: $($_.Exception.Message)" -Type Error
        exit 1
    }
}
else {
    Write-StatusMessage "Using output directory: $OutputDirectory" -Type Info
}

# Test write permissions
$testFile = Join-Path $OutputDirectory "test_$Timestamp.tmp"
try {
    "test" | Out-File -FilePath $testFile -ErrorAction Stop
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    Write-StatusMessage "Write permissions verified" -Type Success
}
catch {
    Write-StatusMessage "No write permission to output directory" -Type Error
    exit 1
}

# Build AD query parameters
$ADParams = @{
    Properties = '*'
    ErrorAction = 'Stop'
}

if ($Domain) {
    $ADParams['Server'] = $Domain
    Write-StatusMessage "Targeting domain: $Domain" -Type Info
}
elseif ($DomainController) {
    $ADParams['Server'] = $DomainController
    Write-StatusMessage "Using domain controller: $DomainController" -Type Info
}

if ($Credential) {
    $ADParams['Credential'] = $Credential
    Write-StatusMessage "Using provided credentials for authentication" -Type Info
}

if ($SearchBase) {
    $ADParams['SearchBase'] = $SearchBase
    Write-StatusMessage "Limiting scope to: $SearchBase" -Type Info
}

# Get domain information
Write-Host "`nGathering domain information..." -ForegroundColor Yellow
try {
    $DomainParams = @{ ErrorAction = 'Stop' }
    if ($Domain) { 
        $DomainParams['Server'] = $Domain 
        $DomainParams['Identity'] = $Domain
    }
    elseif ($DomainController) { 
        $DomainParams['Server'] = $DomainController 
    }
    if ($Credential) { $DomainParams['Credential'] = $Credential }
    
    $DomainInfo = Get-ADDomain @DomainParams
    $ForestParams = @{ ErrorAction = 'Stop' }
    if ($Domain) { $ForestParams['Server'] = $Domain }
    elseif ($DomainController) { $ForestParams['Server'] = $DomainController }
    if ($Credential) { $ForestParams['Credential'] = $Credential }
    $ForestInfo = Get-ADForest @ForestParams
    
    Write-StatusMessage "Connected to domain: $($DomainInfo.DNSRoot)" -Type Success
    Write-StatusMessage "Forest: $($ForestInfo.Name)" -Type Info
    Write-StatusMessage "Domain Functional Level: $($DomainInfo.DomainMode)" -Type Info
}
catch {
    Write-StatusMessage "Failed to retrieve domain information: $($_.Exception.Message)" -Type Error
    exit 1
}

# Initialize report
$Report = @()
$Report += $Separator
$Report += "$OrganizationName - ACTIVE DIRECTORY ASSESSMENT REPORT"
$Report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$Report += $Separator
$Report += ""
$Report += "DOMAIN INFORMATION"
$Report += $SubSeparator
$Report += "Domain: $($DomainInfo.DNSRoot)"
$Report += "NetBIOS Name: $($DomainInfo.NetBIOSName)"
$Report += "Forest: $($ForestInfo.Name)"
$Report += "Domain Functional Level: $($DomainInfo.DomainMode)"
$Report += "Forest Functional Level: $($ForestInfo.ForestMode)"
$Report += "Domain Controllers: $($DomainInfo.ReplicaDirectoryServers -join ', ')"
if ($SearchBase) {
    $Report += "Assessment Scope: $SearchBase"
}
$Report += ""

# ================================================================================
# EXPORT USERS
# ================================================================================
Write-Host "`nExporting user accounts..." -ForegroundColor Yellow

$UserFilter = if ($IncludeDisabledUsers) {
    "ObjectClass -eq 'user' -and ObjectCategory -eq 'person'"
} else {
    "ObjectClass -eq 'user' -and ObjectCategory -eq 'person' -and Enabled -eq `$true"
}

$Users = Invoke-SafeCommand -Command {
    Get-ADUser -Filter $UserFilter @ADParams
} -ErrorMessage "Failed to retrieve users" -ContinueOnError

if ($null -eq $Users -or $Users.Count -eq 0) {
    Write-StatusMessage "No users found matching criteria" -Type Warning
    $Users = @()
}
else {
    Write-StatusMessage "Retrieved $($Users.Count) user accounts" -Type Success
}

# Build comprehensive user export
$UserExport = foreach ($User in $Users) {
    try {
        # Get group memberships
        $GroupMembershipParams = @{ Identity = $User.SamAccountName; ErrorAction = 'SilentlyContinue' }
        if ($Domain) { $GroupMembershipParams['Server'] = $Domain }
        elseif ($DomainController) { $GroupMembershipParams['Server'] = $DomainController }
        if ($Credential) { $GroupMembershipParams['Credential'] = $Credential }
        
        $Groups = (Get-ADPrincipalGroupMembership @GroupMembershipParams | 
                   Select-Object -ExpandProperty Name) -join ';'
        
        # Calculate password age
        $PasswordAge = if ($User.PasswordLastSet) {
            (New-TimeSpan -Start $User.PasswordLastSet -End (Get-Date)).Days
        } else {
            "Never"
        }
        
        # Last logon date
        $LastLogonDate = if ($User.LastLogonDate) {
            $User.LastLogonDate.ToString('yyyy-MM-dd HH:mm:ss')
        } else {
            "Never"
        }
        
        [PSCustomObject]@{
            # Primary Identifiers - KEY for matching
            SamAccountName = $User.SamAccountName
            UserPrincipalName = $User.UserPrincipalName
            EmailAddress = $User.EmailAddress
            EmployeeID = $User.EmployeeID
            EmployeeNumber = $User.EmployeeNumber
            ObjectGUID = $User.ObjectGUID
            SID = $User.SID
            
            # Personal Information
            GivenName = $User.GivenName
            Surname = $User.Surname
            DisplayName = $User.DisplayName
            Initials = $User.Initials
            Description = $User.Description
            
            # Organizational Information
            Department = $User.Department
            Title = $User.Title
            Company = $User.Company
            Office = $User.Office
            Manager = $User.Manager
            ManagerSamAccountName = if ($User.Manager) {
                $MgrParams = @{ Identity = $User.Manager; ErrorAction = 'SilentlyContinue' }
                if ($Domain) { $MgrParams['Server'] = $Domain }
                elseif ($DomainController) { $MgrParams['Server'] = $DomainController }
                if ($Credential) { $MgrParams['Credential'] = $Credential }
                (Get-ADUser @MgrParams).SamAccountName 
            } else { "" }
            
            # Contact Information
            TelephoneNumber = $User.TelephoneNumber
            Mobile = $User.Mobile
            IPPhone = $User.IPPhone
            Fax = $User.Fax
            HomePhone = $User.HomePhone
            Pager = $User.Pager
            
            # Address Information
            StreetAddress = $User.StreetAddress
            POBox = $User.POBox
            City = $User.City
            State = $User.State
            PostalCode = $User.PostalCode
            Country = $User.Country
            CountryCode = $User.CountryCode
            
            # Account Status
            Enabled = $User.Enabled
            LockedOut = $User.LockedOut
            PasswordExpired = $User.PasswordExpired
            PasswordNeverExpires = $User.PasswordNeverExpires
            PasswordNotRequired = $User.PasswordNotRequired
            CannotChangePassword = $User.CannotChangePassword
            PasswordLastSet = if ($User.PasswordLastSet) { 
                $User.PasswordLastSet.ToString('yyyy-MM-dd HH:mm:ss') 
            } else { "" }
            PasswordAge = $PasswordAge
            
            # Account Dates
            Created = $User.Created.ToString('yyyy-MM-dd HH:mm:ss')
            Modified = $User.Modified.ToString('yyyy-MM-dd HH:mm:ss')
            LastLogonDate = $LastLogonDate
            AccountExpirationDate = if ($User.AccountExpirationDate) { 
                $User.AccountExpirationDate.ToString('yyyy-MM-dd HH:mm:ss') 
            } else { "" }
            
            # Location in AD
            DistinguishedName = $User.DistinguishedName
            CanonicalName = $User.CanonicalName
            
            # Group Memberships
            MemberOf = $Groups
            PrimaryGroup = $User.PrimaryGroup
            
            # Additional Attributes
            HomeDirectory = $User.HomeDirectory
            HomeDrive = $User.HomeDrive
            ScriptPath = $User.ScriptPath
            ProfilePath = $User.ProfilePath
            LogonWorkstations = $User.LogonWorkstations
            
            # Flags
            SmartcardLogonRequired = $User.SmartcardLogonRequired
            TrustedForDelegation = $User.TrustedForDelegation
            AccountNotDelegated = $User.AccountNotDelegated
            UseDESKeyOnly = $User.UseDESKeyOnly
            DoesNotRequirePreAuth = $User.DoesNotRequirePreAuth
        }
    }
    catch {
        Write-StatusMessage "Error processing user $($User.SamAccountName): $($_.Exception.Message)" -Type Warning
    }
}

# Export users
$UserFile = "$OutputDirectory\AD_Users_Full_$Timestamp.csv"
if ($UserExport) {
    $UserExport | Export-Csv -Path $UserFile -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Exported $($UserExport.Count) users to: $UserFile" -ForegroundColor Green
}

# User statistics
$EnabledUsers = ($UserExport | Where-Object { $_.Enabled -eq $true }).Count
$DisabledUsers = ($UserExport | Where-Object { $_.Enabled -eq $false }).Count
$LockedUsers = ($UserExport | Where-Object { $_.LockedOut -eq $true }).Count
$PasswordNeverExpires = ($UserExport | Where-Object { $_.PasswordNeverExpires -eq $true }).Count
$NeverLoggedOn = ($UserExport | Where-Object { $_.LastLogonDate -eq "Never" }).Count

$Report += "USER ACCOUNT STATISTICS"
$Report += $SubSeparator
$Report += "Total Users Exported: $($UserExport.Count)"
$Report += "  Enabled: $EnabledUsers"
$Report += "  Disabled: $DisabledUsers"
$Report += "  Locked Out: $LockedUsers"
$Report += "  Password Never Expires: $PasswordNeverExpires"
$Report += "  Never Logged On: $NeverLoggedOn"
$Report += ""

# ================================================================================
# EXPORT GROUPS
# ================================================================================
Write-Host "`nExporting groups..." -ForegroundColor Yellow

$Groups = Invoke-SafeCommand -Command {
    Get-ADGroup -Filter * @ADParams
} -ErrorMessage "Failed to retrieve groups" -ContinueOnError

if ($null -eq $Groups -or $Groups.Count -eq 0) {
    Write-StatusMessage "No groups found" -Type Warning
    $Groups = @()
}
else {
    Write-StatusMessage "Retrieved $($Groups.Count) groups" -Type Success
}

# Build group export
$GroupExport = foreach ($Group in $Groups) {
    try {
        $MemberParams = @{ Identity = $Group.SamAccountName; ErrorAction = 'SilentlyContinue' }
        if ($Domain) { $MemberParams['Server'] = $Domain }
        elseif ($DomainController) { $MemberParams['Server'] = $DomainController }
        if ($Credential) { $MemberParams['Credential'] = $Credential }
        
        $Members = Get-ADGroupMember @MemberParams
        $MemberCount = if ($Members) { $Members.Count } else { 0 }
        
        $UserMembers = ($Members | Where-Object { $_.objectClass -eq 'user' }).Count
        $GroupMembers = ($Members | Where-Object { $_.objectClass -eq 'group' }).Count
        $ComputerMembers = ($Members | Where-Object { $_.objectClass -eq 'computer' }).Count
        
        [PSCustomObject]@{
            SamAccountName = $Group.SamAccountName
            Name = $Group.Name
            DisplayName = $Group.DisplayName
            Description = $Group.Description
            GroupCategory = $Group.GroupCategory
            GroupScope = $Group.GroupScope
            DistinguishedName = $Group.DistinguishedName
            CanonicalName = $Group.CanonicalName
            ObjectGUID = $Group.ObjectGUID
            SID = $Group.SID
            MemberCount = $MemberCount
            UserMembers = $UserMembers
            GroupMembers = $GroupMembers
            ComputerMembers = $ComputerMembers
            ManagedBy = $Group.ManagedBy
            Created = $Group.Created.ToString('yyyy-MM-dd HH:mm:ss')
            Modified = $Group.Modified.ToString('yyyy-MM-dd HH:mm:ss')
        }
    }
    catch {
        Write-StatusMessage "Error processing group $($Group.SamAccountName): $($_.Exception.Message)" -Type Warning
    }
}

# Export groups
$GroupFile = "$OutputDirectory\AD_Groups_Summary_$Timestamp.csv"
if ($GroupExport) {
    $GroupExport | Export-Csv -Path $GroupFile -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Exported $($GroupExport.Count) groups to: $GroupFile" -ForegroundColor Green
}

# Group statistics
$SecurityGroups = ($GroupExport | Where-Object { $_.GroupCategory -eq 'Security' }).Count
$DistributionGroups = ($GroupExport | Where-Object { $_.GroupCategory -eq 'Distribution' }).Count

$Report += "GROUP STATISTICS"
$Report += $SubSeparator
$Report += "Total Groups: $($GroupExport.Count)"
$Report += "  Security Groups: $SecurityGroups"
$Report += "  Distribution Groups: $DistributionGroups"
$Report += "  Universal Scope: $(($GroupExport | Where-Object { $_.GroupScope -eq 'Universal' }).Count)"
$Report += "  Global Scope: $(($GroupExport | Where-Object { $_.GroupScope -eq 'Global' }).Count)"
$Report += "  DomainLocal Scope: $(($GroupExport | Where-Object { $_.GroupScope -eq 'DomainLocal' }).Count)"
$Report += ""

# ================================================================================
# EXPORT GROUP MEMBERSHIPS
# ================================================================================
Write-Host "`nExporting group memberships..." -ForegroundColor Yellow

$GroupMemberships = @()
foreach ($User in $Users) {
    try {
        $UserGroupParams = @{ Identity = $User.SamAccountName; ErrorAction = 'SilentlyContinue' }
        if ($Domain) { $UserGroupParams['Server'] = $Domain }
        elseif ($DomainController) { $UserGroupParams['Server'] = $DomainController }
        if ($Credential) { $UserGroupParams['Credential'] = $Credential }
        
        $UserGroups = Get-ADPrincipalGroupMembership @UserGroupParams
        foreach ($UserGroup in $UserGroups) {
            $GroupMemberships += [PSCustomObject]@{
                UserSamAccountName = $User.SamAccountName
                UserUPN = $User.UserPrincipalName
                UserDisplayName = $User.DisplayName
                GroupSamAccountName = $UserGroup.SamAccountName
                GroupName = $UserGroup.Name
                GroupDistinguishedName = $UserGroup.DistinguishedName
            }
        }
    }
    catch {
        Write-StatusMessage "Error getting group memberships for $($User.SamAccountName): $($_.Exception.Message)" -Type Warning
    }
}

$MembershipFile = "$OutputDirectory\AD_GroupMemberships_$Timestamp.csv"
if ($GroupMemberships.Count -gt 0) {
    $GroupMemberships | Export-Csv -Path $MembershipFile -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Exported $($GroupMemberships.Count) group membership records to: $MembershipFile" -ForegroundColor Green
}

# ================================================================================
# EXPORT ORGANIZATIONAL UNITS
# ================================================================================
Write-Host "`nExporting organizational units..." -ForegroundColor Yellow

$OUs = Invoke-SafeCommand -Command {
    Get-ADOrganizationalUnit -Filter * @ADParams
} -ErrorMessage "Failed to retrieve OUs" -ContinueOnError

if ($null -eq $OUs -or $OUs.Count -eq 0) {
    Write-StatusMessage "No OUs found" -Type Warning
    $OUs = @()
}
else {
    Write-StatusMessage "Retrieved $($OUs.Count) organizational units" -Type Success
}

# Build OU export with user/computer counts
$OUExport = foreach ($OU in $OUs) {
    try {
        $OUCountParams = @{ Filter = '*'; SearchBase = $OU.DistinguishedName; SearchScope = 'OneLevel'; ErrorAction = 'SilentlyContinue' }
        if ($Domain) { $OUCountParams['Server'] = $Domain }
        elseif ($DomainController) { $OUCountParams['Server'] = $DomainController }
        if ($Credential) { $OUCountParams['Credential'] = $Credential }
        
        $OUUsers = (Get-ADUser @OUCountParams).Count
        $OUComputers = (Get-ADComputer @OUCountParams).Count
        $OUGroups = (Get-ADGroup @OUCountParams).Count
        
        [PSCustomObject]@{
            Name = $OU.Name
            DistinguishedName = $OU.DistinguishedName
            CanonicalName = $OU.CanonicalName
            Description = $OU.Description
            UserCount = $OUUsers
            ComputerCount = $OUComputers
            GroupCount = $OUGroups
            ObjectGUID = $OU.ObjectGUID
            Created = $OU.Created.ToString('yyyy-MM-dd HH:mm:ss')
            Modified = $OU.Modified.ToString('yyyy-MM-dd HH:mm:ss')
            ManagedBy = $OU.ManagedBy
            ProtectedFromAccidentalDeletion = $OU.ProtectedFromAccidentalDeletion
        }
    }
    catch {
        Write-StatusMessage "Error processing OU $($OU.Name): $($_.Exception.Message)" -Type Warning
    }
}

# Export OUs
$OUFile = "$OutputDirectory\AD_OUs_Structure_$Timestamp.csv"
if ($OUExport) {
    $OUExport | Export-Csv -Path $OUFile -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Exported $($OUExport.Count) organizational units to: $OUFile" -ForegroundColor Green
}

$Report += "ORGANIZATIONAL UNIT STATISTICS"
$Report += $SubSeparator
$Report += "Total OUs: $($OUExport.Count)"
$Report += "Top 10 OUs by User Count:"
$TopOUs = $OUExport | Sort-Object UserCount -Descending | Select-Object -First 10
foreach ($TopOU in $TopOUs) {
    $Report += "  $($TopOU.Name): $($TopOU.UserCount) users"
}
$Report += ""

# ================================================================================
# EXPORT COMPUTERS (if requested)
# ================================================================================
if ($IncludeComputers) {
    Write-Host "`nExporting computer objects..." -ForegroundColor Yellow
    
    $Computers = Invoke-SafeCommand -Command {
        Get-ADComputer -Filter * @ADParams
    } -ErrorMessage "Failed to retrieve computers" -ContinueOnError
    
    if ($null -eq $Computers -or $Computers.Count -eq 0) {
        Write-StatusMessage "No computers found" -Type Warning
        $Computers = @()
    }
    else {
        Write-StatusMessage "Retrieved $($Computers.Count) computer objects" -Type Success
    }
    
    # Build computer export
    $ComputerExport = foreach ($Computer in $Computers) {
        try {
            $LastLogonDate = if ($Computer.LastLogonDate) {
                $Computer.LastLogonDate.ToString('yyyy-MM-dd HH:mm:ss')
            } else {
                "Never"
            }
            
            [PSCustomObject]@{
                Name = $Computer.Name
                DNSHostName = $Computer.DNSHostName
                SamAccountName = $Computer.SamAccountName
                OperatingSystem = $Computer.OperatingSystem
                OperatingSystemVersion = $Computer.OperatingSystemVersion
                OperatingSystemServicePack = $Computer.OperatingSystemServicePack
                IPv4Address = $Computer.IPv4Address
                IPv6Address = $Computer.IPv6Address
                Enabled = $Computer.Enabled
                DistinguishedName = $Computer.DistinguishedName
                CanonicalName = $Computer.CanonicalName
                Description = $Computer.Description
                ManagedBy = $Computer.ManagedBy
                Created = $Computer.Created.ToString('yyyy-MM-dd HH:mm:ss')
                Modified = $Computer.Modified.ToString('yyyy-MM-dd HH:mm:ss')
                LastLogonDate = $LastLogonDate
                PasswordLastSet = if ($Computer.PasswordLastSet) { 
                    $Computer.PasswordLastSet.ToString('yyyy-MM-dd HH:mm:ss') 
                } else { "" }
                ObjectGUID = $Computer.ObjectGUID
                SID = $Computer.SID
            }
        }
        catch {
            Write-StatusMessage "Error processing computer $($Computer.Name): $($_.Exception.Message)" -Type Warning
        }
    }
    
    # Export computers
    $ComputerFile = "$OutputDirectory\AD_Computers_$Timestamp.csv"
    if ($ComputerExport) {
        $ComputerExport | Export-Csv -Path $ComputerFile -NoTypeInformation -Encoding UTF8
        Write-Host "✅ Exported $($ComputerExport.Count) computers to: $ComputerFile" -ForegroundColor Green
    }
    
    $EnabledComputers = ($ComputerExport | Where-Object { $_.Enabled -eq $true }).Count
    $DisabledComputers = ($ComputerExport | Where-Object { $_.Enabled -eq $false }).Count
    
    $Report += "COMPUTER OBJECT STATISTICS"
    $Report += $SubSeparator
    $Report += "Total Computers: $($ComputerExport.Count)"
    $Report += "  Enabled: $EnabledComputers"
    $Report += "  Disabled: $DisabledComputers"
    $Report += ""
    $Report += "Operating Systems:"
    $OSCounts = $ComputerExport | Group-Object OperatingSystem | Sort-Object Count -Descending
    foreach ($OS in $OSCounts) {
        $Report += "  $($OS.Name): $($OS.Count)"
    }
    $Report += ""
}

# ================================================================================
# PRIVILEGED ACCOUNTS ANALYSIS
# ================================================================================
Write-Host "`nAnalyzing privileged accounts..." -ForegroundColor Yellow

$PrivilegedGroups = @(
    'Domain Admins',
    'Enterprise Admins',
    'Schema Admins',
    'Administrators',
    'Account Operators',
    'Backup Operators',
    'Server Operators',
    'Print Operators'
)

$PrivilegedAccounts = @()
foreach ($PrivGroup in $PrivilegedGroups) {
    try {
        $PrivGroupParams = @{ Filter = "Name -eq '$PrivGroup'"; ErrorAction = 'SilentlyContinue' }
        if ($Domain) { $PrivGroupParams['Server'] = $Domain }
        elseif ($DomainController) { $PrivGroupParams['Server'] = $DomainController }
        if ($Credential) { $PrivGroupParams['Credential'] = $Credential }
        
        $Group = Get-ADGroup @PrivGroupParams
        if ($Group) {
            $PrivMemberParams = @{ Identity = $Group.SamAccountName; Recursive = $true; ErrorAction = 'SilentlyContinue' }
            if ($Domain) { $PrivMemberParams['Server'] = $Domain }
            elseif ($DomainController) { $PrivMemberParams['Server'] = $DomainController }
            if ($Credential) { $PrivMemberParams['Credential'] = $Credential }
            
            $Members = Get-ADGroupMember @PrivMemberParams
            foreach ($Member in $Members) {
                if ($Member.objectClass -eq 'user') {
                    $PrivilegedAccounts += [PSCustomObject]@{
                        UserSamAccountName = $Member.SamAccountName
                        UserName = $Member.Name
                        PrivilegedGroup = $PrivGroup
                        GroupDistinguishedName = $Group.DistinguishedName
                    }
                }
            }
        }
    }
    catch {
        Write-StatusMessage "Error analyzing privileged group ${PrivGroup}: $($_.Exception.Message)" -Type Warning
    }
}

$PrivilegedFile = "$OutputDirectory\AD_PrivilegedAccounts_$Timestamp.csv"
if ($PrivilegedAccounts.Count -gt 0) {
    $PrivilegedAccounts | Export-Csv -Path $PrivilegedFile -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Exported $($PrivilegedAccounts.Count) privileged account memberships to: $PrivilegedFile" -ForegroundColor Green
}

$UniquePrivilegedUsers = ($PrivilegedAccounts | Select-Object -Unique UserSamAccountName).Count

$Report += "PRIVILEGED ACCOUNTS"
$Report += $SubSeparator
$Report += "Unique Privileged Accounts: $UniquePrivilegedUsers"
$Report += "Total Privileged Group Memberships: $($PrivilegedAccounts.Count)"
$Report += ""
$Report += "Breakdown by Group:"
$PrivGroupCounts = $PrivilegedAccounts | Group-Object PrivilegedGroup | Sort-Object Count -Descending
foreach ($PrivGroupCount in $PrivGroupCounts) {
    $Report += "  $($PrivGroupCount.Name): $($PrivGroupCount.Count) members"
}
$Report += ""
$Report += "⚠️  MIGRATION NOTE: Review privileged accounts for special handling"
$Report += ""

# ================================================================================
# MIGRATION RECOMMENDATIONS
# ================================================================================
$Report += "MIGRATION RECOMMENDATIONS"
$Report += $SubSeparator
$Report += ""
$Report += "User Matching Strategy:"
$Report += "  Primary:   EmployeeID (if populated)"
$Report += "  Secondary: Email Address"
$Report += "  Fallback:  SamAccountName or DisplayName match"
$Report += ""

# Analyze matching attributes availability
$UsersWithEmployeeID = ($UserExport | Where-Object { ![string]::IsNullOrWhiteSpace($_.EmployeeID) }).Count
$UsersWithEmail = ($UserExport | Where-Object { ![string]::IsNullOrWhiteSpace($_.EmailAddress) }).Count

$Report += "Matching Attribute Coverage:"
$Report += "  Users with EmployeeID: $UsersWithEmployeeID ($([math]::Round($UsersWithEmployeeID / $UserExport.Count * 100, 1))%)"
$Report += "  Users with Email: $UsersWithEmail ($([math]::Round($UsersWithEmail / $UserExport.Count * 100, 1))%)"
$Report += ""

if ($UsersWithEmployeeID -lt ($UserExport.Count * 0.8)) {
    $Report += "⚠️  WARNING: Less than 80% of users have EmployeeID populated"
    $Report += "   Consider using Email Address as primary matching attribute"
    $Report += ""
}

$Report += "Next Steps:"
$Report += "  1. Run this script in TARGET AD environment"
$Report += "  2. Compare source and target CSV exports"
$Report += "  3. Identify matching users based on chosen attribute"
$Report += "  4. Review privileged accounts list for manual handling"
$Report += "  5. Plan OU structure mapping between environments"
$Report += "  6. Document group membership migration strategy"
$Report += "  7. Test user matching with pilot group"
$Report += ""

# ================================================================================
# FINALIZE REPORT
# ================================================================================
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

$Report += $Separator
$Report += "ASSESSMENT SUMMARY"
$Report += $SubSeparator
$Report += "Execution Time: $($Duration.ToString('mm\:ss'))"
$Report += "Errors: $ErrorCount"
$Report += "Warnings: $WarningCount"
$Report += ""
$Report += "Output Files Generated:"
$Report += "  $UserFile"
$Report += "  $GroupFile"
$Report += "  $MembershipFile"
$Report += "  $OUFile"
if ($IncludeComputers) {
    $Report += "  $ComputerFile"
}
$Report += "  $PrivilegedFile"
$Report += ""
$Report += "Assessment completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$Report += $Separator

# Save text report
$ReportFile = "$OutputDirectory\AD_Assessment_Report_$Timestamp.txt"
$Report | Out-File -FilePath $ReportFile -Encoding UTF8
Write-Host "`n✅ Assessment report saved to: $ReportFile" -ForegroundColor Green

# Display summary
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "ASSESSMENT COMPLETED" -ForegroundColor Green
Write-Host $Separator -ForegroundColor Cyan
Write-Host "Execution Time: $($Duration.ToString('mm\:ss'))" -ForegroundColor Cyan
Write-Host "Total Users Exported: $($UserExport.Count)" -ForegroundColor White
Write-Host "Total Groups Exported: $($GroupExport.Count)" -ForegroundColor White
Write-Host "Total Group Memberships: $($GroupMemberships.Count)" -ForegroundColor White
Write-Host "Privileged Accounts: $UniquePrivilegedUsers" -ForegroundColor Yellow
Write-Host "`nErrors: $ErrorCount | Warnings: $WarningCount" -ForegroundColor $(if($ErrorCount -gt 0){'Red'}else{'Green'})
Write-Host "`nAll reports saved to: $OutputDirectory" -ForegroundColor Green
Write-Host $Separator -ForegroundColor Cyan

# Open output directory
if ($ErrorCount -eq 0) {
    $OpenFolder = Read-Host "`nOpen output folder? (Y/N)"
    if ($OpenFolder -eq 'Y' -or $OpenFolder -eq 'y') {
        Start-Process explorer.exe -ArgumentList $OutputDirectory
    }
}
