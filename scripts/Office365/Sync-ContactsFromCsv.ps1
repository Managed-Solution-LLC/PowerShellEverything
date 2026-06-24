<#
.SYNOPSIS
    Synchronizes contact information from a CSV file to users' contact folders in Microsoft Graph.

.DESCRIPTION
    This script syncs contact information from a source CSV file to contact folders within specified users'
    Microsoft Graph mailboxes. It can retrieve target users from a security group, CSV file, or direct list.
    The script updates phone numbers, names, company, and job title information, and optionally deletes 
    contacts not present in the source CSV.

.PARAMETER CsvPath
    Path to the CSV file containing canonical contact information. Required columns: GivenName, Surname.
    Optional columns: Email, BusinessPhones (semicolon-separated), MobilePhone, Company, JobTitle.
    Note: Email is recommended to ensure unique contact identification. If Email is empty, contacts are matched by full name (GivenName Surname).

.PARAMETER FolderName
    Name of the contact folder to sync. The folder will be created if it doesn't exist.

.PARAMETER SecurityGroup
    Distinguished name (DN) or object ID of the security group whose members should be synced.
    Example: "CN=Sales Team,OU=Groups,DC=contoso,DC=com" or the Azure AD object ID

.PARAMETER Users
    Array of specific user UPNs to sync (alternative to SecurityGroup or UsersCsvPath).

.PARAMETER UsersCsvPath
    Path to CSV file containing target users (must have UPN column). Alternative to SecurityGroup or Users.

.PARAMETER DeleteNotInCsv
    If specified, deletes any contacts in the target folder that are not in the source CSV.

.PARAMETER UpdateNames
    If specified, updates contact names, company, and job title. By default, only phone numbers are updated.

.PARAMETER DegreeOfParallelism
    Number of parallel threads for user processing (1-16). Default: 4.

.EXAMPLE
    .\Sync-ContactsFromCsv.ps1 -CsvPath "C:\contacts.csv" -FolderName "Contacts" -SecurityGroup "Sales Team"

.EXAMPLE
    .\Sync-ContactsFromCsv.ps1 -CsvPath "C:\contacts.csv" -FolderName "Shared Contacts" -UsersCsvPath "C:\users.csv" -UpdateNames -DeleteNotInCsv

.NOTES
    Author: Managed Solution LLC
    Date: 2026-03-12
    Version: 1.0
    
    Requirements:
    - PowerShell 7.2+
    - Microsoft.Graph.Authentication module
    - Microsoft.Graph.Users module
    - Microsoft.Graph.Groups module
    - Appropriate Microsoft Graph permissions (Contacts.ReadWrite, User.Read.All, Directory.Read.All)
    
    The script uses parallel processing to speed up contact syncing across multiple users.
    Phone numbers are normalized by removing formatting characters, keeping only digits and + signs.
    Contacts are matched in target folders by email address (if present) or by full name (GivenName Surname).
    Warning: Using name-only matching can lead to duplicate contacts if multiple records have identical names.

.LINK
    https://docs.microsoft.com/graph/api/contactfolder-post-childfolders
#>

#Requires -Version 7.2
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.PersonalContacts

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ParameterSetName = 'SecurityGroup')]
    [Parameter(Mandatory, ParameterSetName = 'UsersList')]
    [Parameter(Mandatory, ParameterSetName = 'UsersCsv')]
    [ValidateNotNullOrEmpty()]
    [string]$CsvPath,

    [Parameter(Mandatory, ParameterSetName = 'SecurityGroup')]
    [Parameter(Mandatory, ParameterSetName = 'UsersList')]
    [Parameter(Mandatory, ParameterSetName = 'UsersCsv')]
    [ValidateNotNullOrEmpty()]
    [string]$FolderName,

    [Parameter(Mandatory, ParameterSetName = 'SecurityGroup')]
    [ValidateNotNullOrEmpty()]
    [string]$SecurityGroup,

    [Parameter(Mandatory, ParameterSetName = 'UsersList')]
    [ValidateNotNullOrEmpty()]
    [string[]]$Users,

    [Parameter(Mandatory, ParameterSetName = 'UsersCsv')]
    [ValidateNotNullOrEmpty()]
    [string]$UsersCsvPath,

    [Parameter()]
    [switch]$DeleteNotInCsv,

    [Parameter()]
    [switch]$UpdateNames,

    [Parameter()]
    [ValidateRange(1, 16)]
    [int]$DegreeOfParallelism = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-StatusMessage {
    <#
    .SYNOPSIS
        Writes formatted status messages to the console with timestamps
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Type = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    switch ($Type) {
        'Success' { Write-Host "✅ [$timestamp] $Message" -ForegroundColor Green }
        'Error'   { Write-Host "❌ [$timestamp] $Message" -ForegroundColor Red }
        'Warning' { Write-Host "⚠️  [$timestamp] $Message" -ForegroundColor Yellow }
        'Debug'   { Write-Verbose "[$timestamp] $Message" }
        default   { Write-Host "ℹ️  [$timestamp] $Message" -ForegroundColor Cyan }
    }
}

function Get-TargetUsers {
    <#
    .SYNOPSIS
        Retrieves target users based on security group, direct list, or CSV file
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$SecurityGroup,

        [Parameter()]
        [string[]]$UsersList,

        [Parameter()]
        [string]$UsersCsvFile
    )

    $targetUsers = @()

    # Method 1: Retrieve from security group
    if ($PSBoundParameters.ContainsKey('SecurityGroup')) {
        Write-StatusMessage "Retrieving members from security group: $SecurityGroup"
        try {
            # Try to get by display name first
            $group = Get-MgGroup -Filter "displayName eq '$SecurityGroup'" -ErrorAction SilentlyContinue | Select-Object -First 1
            
            # If not found by display name, assume it's an object ID
            if (-not $group) {
                $group = Get-MgGroup -GroupId $SecurityGroup -ErrorAction Stop
            }

            if (-not $group) {
                throw "Security group '$SecurityGroup' not found"
            }

            $members = Get-MgGroupMember -GroupId $group.Id -All -Property 'id,userPrincipalName' -ErrorAction Stop
            $upns = @($members.AdditionalProperties.userPrincipalName | Where-Object { $_ } | Sort-Object -Unique)
            $targetUsers = $upns
            Write-StatusMessage "Found $($targetUsers.Count) members in security group" -Type 'Success'
        }
        catch {
            Write-StatusMessage "Failed to retrieve security group members: $($_.Exception.Message)" -Type 'Error'
            throw
        }
    }

    # Method 2: Direct user list
    if ($PSBoundParameters.ContainsKey('UsersList')) {
        Write-StatusMessage "Using provided user list: $($UsersList.Count) users"
        $targetUsers += $UsersList
    }

    # Method 3: CSV file
    if ($PSBoundParameters.ContainsKey('UsersCsvFile')) {
        Write-StatusMessage "Loading users from CSV: $UsersCsvFile"
        if (-not (Test-Path $UsersCsvFile)) {
            throw "Users CSV file not found: $UsersCsvFile"
        }
        try {
            $csvUsers = @(Import-Csv -Path $UsersCsvFile -ErrorAction Stop)
            $csvUpns = @($csvUsers | Where-Object { $_.UPN } | ForEach-Object { $_.UPN } | Sort-Object -Unique)
            $targetUsers += $csvUpns
            Write-StatusMessage "Loaded $($csvUsers.Count) users from CSV" -Type 'Success'
        }
        catch {
            throw "Failed to load users from CSV: $($_.Exception.Message)"
        }
    }

    $result = @($targetUsers | Sort-Object -Unique)
    return $result
}

function Get-OrCreateContactFolder {
    <#
    .SYNOPSIS
        Gets or creates a contact folder for a user
    #>
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$FolderName
    )

    try {
        $folder = Get-MgUserContactFolder -UserId $UserId -All -ErrorAction Stop |
            Where-Object { $_.DisplayName -eq $FolderName } |
            Select-Object -First 1

        if (-not $folder) {
            $bodyParameter = @{ displayName = $FolderName }

            if (-not $WhatIfPreference) {
                $folder = New-MgUserContactFolder -UserId $UserId -BodyParameter $bodyParameter -ErrorAction Stop
                Write-StatusMessage "Created contact folder: $FolderName for user: $UserId" -Type 'Success'
            }
        }

        return $folder
    }
    catch {
        Write-StatusMessage "Failed to get/create contact folder for $UserId : $($_.Exception.Message)" -Type 'Error'
        return $null
    }
}

function Normalize-PhoneNumbers {
    <#
    .SYNOPSIS
        Normalizes phone numbers by removing formatting, keeping only digits and + signs
    #>
    param(
        [Parameter()]
        [string[]]$PhoneNumbers
    )

    if (-not $PhoneNumbers) { return @() }

    $normalized = $PhoneNumbers | ForEach-Object {
        if ($_) {
            $_.Trim() -replace '[^\d+]', ''  # Keep only digits and + sign
        }
    } | Where-Object { $_ } | Sort-Object -Unique

    return $normalized
}

function Compare-ContactProperties {
    <#
    .SYNOPSIS
        Compares CSV contact data with existing contact and returns update body if changes needed
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$ExistingContact,

        [Parameter(Mandatory)]
        [hashtable]$CanonicalContact,

        [Parameter()]
        [switch]$UpdateNames
    )

    $updateBody = @{}
    $needsUpdate = $false

    # Phone comparisons
    $existingBusinessPhones = Normalize-PhoneNumbers -PhoneNumbers $ExistingContact.businessPhones
    $targetBusinessPhones = Normalize-PhoneNumbers -PhoneNumbers ($CanonicalContact.BusinessPhones -split ';')
    
    if (($existingBusinessPhones | Sort-Object) -ne ($targetBusinessPhones | Sort-Object)) {
        $updateBody['businessPhones'] = @($targetBusinessPhones)
        $needsUpdate = $true
    }

    $existingMobilePhone = $ExistingContact.mobilePhone
    $targetMobilePhone = if ($CanonicalContact.MobilePhone) {
        (Normalize-PhoneNumbers -PhoneNumbers @($CanonicalContact.MobilePhone)) | Select-Object -First 1
    }
    else {
        $null
    }

    if ($existingMobilePhone -ne $targetMobilePhone) {
        $updateBody['mobilePhone'] = $targetMobilePhone
        $needsUpdate = $true
    }

    # Name and company updates (if enabled)
    if ($UpdateNames) {
        if ($ExistingContact.givenName -ne $CanonicalContact.GivenName) {
            $updateBody['givenName'] = $CanonicalContact.GivenName
            $needsUpdate = $true
        }
        if ($ExistingContact.surname -ne $CanonicalContact.Surname) {
            $updateBody['surname'] = $CanonicalContact.Surname
            $needsUpdate = $true
        }
        if ($ExistingContact.companyName -ne $CanonicalContact.Company) {
            $updateBody['companyName'] = $CanonicalContact.Company
            $needsUpdate = $true
        }
        if ($ExistingContact.jobTitle -ne $CanonicalContact.JobTitle) {
            $updateBody['jobTitle'] = $CanonicalContact.JobTitle
            $needsUpdate = $true
        }
    }

    return @{
        needsUpdate = $needsUpdate
        updateBody  = $updateBody
    }
}

# ============================================================================
# VALIDATION AND INITIALIZATION
# ============================================================================

# Verify required modules
Write-StatusMessage "Verifying required PowerShell modules..."
$RequiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Users',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.PersonalContacts'
)

foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -Name $Module -ListAvailable -ErrorAction SilentlyContinue)) {
        Write-StatusMessage "Installing required module: $Module" -Type 'Warning'
        try {
            Install-Module -Name $Module -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
            Write-StatusMessage "Successfully installed $Module" -Type 'Success'
        }
        catch {
            Write-StatusMessage "Failed to install $Module : $($_.Exception.Message)" -Type 'Error'
            throw "Required module $Module could not be installed"
        }
    }
}

# Validate input files
Write-StatusMessage "Validating input files..."
if (-not (Test-Path $CsvPath)) {
    throw "Contact CSV file not found: $CsvPath"
}

if ($PSBoundParameters.ContainsKey('UsersCsvPath') -and -not (Test-Path $UsersCsvPath)) {
    throw "Users CSV file not found: $UsersCsvPath"
}

# Load canonical contacts
Write-StatusMessage "Loading canonical contacts from: $CsvPath"
try {
    $canonicalContacts = @(Import-Csv -Path $CsvPath -ErrorAction Stop)
    Write-StatusMessage "Loaded $($canonicalContacts.Count) canonical contacts" -Type 'Success'
}
catch {
    throw "Failed to load canonical contacts: $($_.Exception.Message)"
}

if ($canonicalContacts.Count -eq 0) {
    throw "No contacts found in CSV file: $CsvPath"
}

# Validate required columns and warn about missing emails
$contactsWithoutEmail = 0
$duplicateNames = @{}

foreach ($contact in $canonicalContacts) {
    if ([string]::IsNullOrWhiteSpace($contact.GivenName) -or [string]::IsNullOrWhiteSpace($contact.Surname)) {
        Write-StatusMessage "Skipping contact with missing GivenName or Surname" -Type 'Warning'
        continue
    }
    
    if ([string]::IsNullOrWhiteSpace($contact.Email)) {
        $contactsWithoutEmail++
        $fullName = "$($contact.GivenName) $($contact.Surname)".Trim()
        if ($duplicateNames.ContainsKey($fullName)) {
            $duplicateNames[$fullName]++
        } else {
            $duplicateNames[$fullName] = 1
        }
    }
}

if ($contactsWithoutEmail -gt 0) {
    Write-StatusMessage "$contactsWithoutEmail contacts without email address (will be matched by full name)" -Type 'Warning'
    
    $duplicatesDetected = @($duplicateNames.Values | Where-Object { $_ -gt 1 })
    if ($duplicatesDetected.Count -gt 0) {
        Write-StatusMessage "WARNING: Duplicate names detected - contacts without unique emails may cause sync issues" -Type 'Warning'
        foreach ($name in $duplicateNames.Keys | Where-Object { $duplicateNames[$_] -gt 1 }) {
            Write-StatusMessage "  Duplicate: '$name' ($($duplicateNames[$name]) records)" -Type 'Warning'
        }
    }
}

# Verify Graph connection
Write-StatusMessage "Establishing Microsoft Graph connection..."
try {
    $context = Get-MgContext -ErrorAction Stop
    if (-not $context) {
        throw "Not connected to Microsoft Graph"
    }
    Write-StatusMessage "Connected to Microsoft Graph as: $($context.Account)" -Type 'Success'
}
catch {
    Write-StatusMessage "Not connected to Microsoft Graph. Attempting interactive connection..." -Type 'Warning'
    try {
        Connect-MgGraph -Scopes 'Contacts.ReadWrite', 'User.Read.All', 'Group.Read.All' -NoWelcome -ErrorAction Stop
        Write-StatusMessage "Successfully connected to Microsoft Graph" -Type 'Success'
    }
    catch {
        throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    }
}

# ============================================================================
# MAIN PROCESSING
# ============================================================================
# ============================================================================
# MAIN PROCESSING
# ============================================================================

# Get target users based on parameter set
$getTargetUsersParams = @{}
if ($PSBoundParameters.ContainsKey('SecurityGroup')) { $getTargetUsersParams['SecurityGroup'] = $SecurityGroup }
if ($PSBoundParameters.ContainsKey('Users'))         { $getTargetUsersParams['UsersList']     = $Users }
if ($PSBoundParameters.ContainsKey('UsersCsvPath'))  { $getTargetUsersParams['UsersCsvFile']  = $UsersCsvPath }
$targetUsers = @(Get-TargetUsers @getTargetUsersParams)

if ($targetUsers.Count -eq 0) {
    Write-StatusMessage "No target users found. Exiting." -Type 'Warning'
    exit 0
}

Write-StatusMessage "Starting contact synchronization for $($targetUsers.Count) users with DegreeOfParallelism=$DegreeOfParallelism"

# Create index of canonical contacts by email (primary) and by name (fallback)
$canonicalByEmail = @{}
$canonicalByName = @{}
foreach ($contact in $canonicalContacts) {
    # Skip if missing required name fields
    if ([string]::IsNullOrWhiteSpace($contact.GivenName) -or [string]::IsNullOrWhiteSpace($contact.Surname)) {
        continue
    }
    
    if ($contact.Email) {
        $canonicalByEmail[$contact.Email.ToLower()] = $contact
    } else {
        $fullName = "$($contact.GivenName) $($contact.Surname)".Trim()
        $canonicalByName[$fullName.ToLower()] = $contact
    }
}

# Serialize function definitions as strings so they survive the parallel runspace boundary
# ($using: does not support scriptblock variables in ForEach-Object -Parallel)
$fnWriteStatusStr       = ${function:Write-StatusMessage}.ToString()
$fnGetOrCreateFolderStr = ${function:Get-OrCreateContactFolder}.ToString()
$fnCompareContactStr    = ${function:Compare-ContactProperties}.ToString()
$fnNormalizePhonesStr   = ${function:Normalize-PhoneNumbers}.ToString()

Write-StatusMessage "Waiting for all users to be processed..."
$syncStatistics = @($targetUsers | ForEach-Object -Parallel {
    # Reconstruct user-defined functions in this runspace
    ${function:Write-StatusMessage}       = [scriptblock]::Create($using:fnWriteStatusStr)
    ${function:Get-OrCreateContactFolder} = [scriptblock]::Create($using:fnGetOrCreateFolderStr)
    ${function:Compare-ContactProperties} = [scriptblock]::Create($using:fnCompareContactStr)
    ${function:Normalize-PhoneNumbers}    = [scriptblock]::Create($using:fnNormalizePhonesStr)

    # Import Graph modules (reuses already-loaded assemblies; Graph session state is shared via static GraphSession.Instance)
    Import-Module Microsoft.Graph.Authentication  -ErrorAction Stop
    Import-Module Microsoft.Graph.Users           -ErrorAction Stop
    Import-Module Microsoft.Graph.PersonalContacts -ErrorAction Stop

    $UserId                = $_
    $TargetFolderName      = $using:FolderName
    $CanonicalIndexByEmail = $using:canonicalByEmail
    $CanonicalIndexByName  = $using:canonicalByName
    $doUpdateNames         = [bool]($using:UpdateNames)
    $doDeleteNotInCsv      = [bool]($using:DeleteNotInCsv)
    $isWhatIf              = $using:WhatIfPreference

    $userStats = @{
        User    = $UserId
        Created = 0
        Updated = 0
        Deleted = 0
        Errors  = 0
    }

    try {
        Write-StatusMessage "Processing user: $UserId"

        # Get or create target folder
        $folder = Get-OrCreateContactFolder -UserId $UserId -FolderName $TargetFolderName
        if (-not $folder) {
            $userStats.Errors++
            Write-StatusMessage "Skipping user $UserId - could not access contact folder" -Type 'Warning'
            return $userStats
        }

        # Get existing contacts from the folder
        $existingContacts = Get-MgUserContactFolderContact -UserId $UserId `
                                                          -ContactFolderId $folder.Id `
                                                          -All `
                                                          -Property 'id,displayName,emailAddresses,businessPhones,mobilePhone,companyName,jobTitle' `
                                                          -ErrorAction Stop

        # Index existing contacts by email (primary) and by name (fallback)
        $existingByEmail = @{}
        $existingByName  = @{}
        foreach ($contact in $existingContacts) {
            if ($contact.emailAddresses -and $contact.emailAddresses.Count -gt 0) {
                $primaryEmail = $contact.emailAddresses | Select-Object -First 1
                if ($primaryEmail.address) {
                    $existingByEmail[$primaryEmail.address.ToLower()] = $contact
                }
            }
            if ($contact.givenName -or $contact.surname) {
                $fullName = "$($contact.givenName) $($contact.surname)".Trim()
                if (-not [string]::IsNullOrWhiteSpace($fullName)) {
                    $existingByName[$fullName.ToLower()] = $contact
                }
            }
        }

        # Process each canonical contact (email-based)
        foreach ($canonicalEmail in $CanonicalIndexByEmail.Keys) {
            $canonicalContact = $CanonicalIndexByEmail[$canonicalEmail]
            $displayName = if ($canonicalContact.GivenName -or $canonicalContact.Surname) {
                "$($canonicalContact.GivenName) $($canonicalContact.Surname)".Trim()
            } else {
                $canonicalContact.Email
            }

            if ($existingByEmail.ContainsKey($canonicalEmail.ToLower())) {
                # Contact exists - check if update needed
                $existingContact = $existingByEmail[$canonicalEmail.ToLower()]
                $comparison = Compare-ContactProperties -ExistingContact $existingContact `
                                                       -CanonicalContact $canonicalContact `
                                                       -UpdateNames:$doUpdateNames

                if ($comparison.needsUpdate -and -not $isWhatIf) {
                    try {
                        Update-MgUserContact -UserId $UserId `
                                            -ContactId $existingContact.Id `
                                            -BodyParameter $comparison.updateBody `
                                            -ErrorAction Stop | Out-Null
                        $userStats.Updated++
                        Write-StatusMessage "Updated: $displayName [$canonicalEmail]" -Type 'Success'
                    }
                    catch {
                        $userStats.Errors++
                        Write-StatusMessage "Failed to update $displayName : $($_.Exception.Message)" -Type 'Error'
                    }
                }
            }
            else {
                # Contact doesn't exist by email - create it
                if (-not $isWhatIf) {
                    $bodyParameter = @{
                        displayName    = $displayName
                        givenName      = $canonicalContact.GivenName
                        surname        = $canonicalContact.Surname
                        companyName    = $canonicalContact.Company
                        jobTitle       = $canonicalContact.JobTitle
                        emailAddresses = @(@{
                            address = $canonicalContact.Email
                            name    = $displayName
                        })
                        businessPhones = @(Normalize-PhoneNumbers -PhoneNumbers ($canonicalContact.BusinessPhones -split ';'))
                        mobilePhone    = (Normalize-PhoneNumbers -PhoneNumbers @($canonicalContact.MobilePhone) | Select-Object -First 1)
                    }
                    try {
                        New-MgUserContactFolderContact -UserId $UserId `
                                                      -ContactFolderId $folder.Id `
                                                      -BodyParameter $bodyParameter `
                                                      -ErrorAction Stop | Out-Null
                        $userStats.Created++
                        Write-StatusMessage "Created: $displayName [$canonicalEmail]" -Type 'Success'
                    }
                    catch {
                        $userStats.Errors++
                        Write-StatusMessage "Failed to create $displayName : $($_.Exception.Message)" -Type 'Error'
                    }
                }
            }
        }

        # Process canonical contacts without email (name-based)
        foreach ($contactName in $CanonicalIndexByName.Keys) {
            $canonicalContact = $CanonicalIndexByName[$contactName]
            $displayName = $contactName

            if ($existingByName.ContainsKey($contactName.ToLower())) {
                # Contact exists by name - check if update needed
                $existingContact = $existingByName[$contactName.ToLower()]
                $comparison = Compare-ContactProperties -ExistingContact $existingContact `
                                                       -CanonicalContact $canonicalContact `
                                                       -UpdateNames:$doUpdateNames

                if ($comparison.needsUpdate -and -not $isWhatIf) {
                    try {
                        Update-MgUserContact -UserId $UserId `
                                            -ContactId $existingContact.Id `
                                            -BodyParameter $comparison.updateBody `
                                            -ErrorAction Stop | Out-Null
                        $userStats.Updated++
                        Write-StatusMessage "Updated: $displayName (by name)" -Type 'Success'
                    }
                    catch {
                        $userStats.Errors++
                        Write-StatusMessage "Failed to update $displayName : $($_.Exception.Message)" -Type 'Error'
                    }
                }
            }
            else {
                # Contact doesn't exist by name - create it
                if (-not $isWhatIf) {
                    $bodyParameter = @{
                        displayName    = $displayName
                        givenName      = $canonicalContact.GivenName
                        surname        = $canonicalContact.Surname
                        companyName    = $canonicalContact.Company
                        jobTitle       = $canonicalContact.JobTitle
                        businessPhones = @(Normalize-PhoneNumbers -PhoneNumbers ($canonicalContact.BusinessPhones -split ';'))
                        mobilePhone    = (Normalize-PhoneNumbers -PhoneNumbers @($canonicalContact.MobilePhone) | Select-Object -First 1)
                    }
                    if ($canonicalContact.Email) {
                        $bodyParameter['emailAddresses'] = @(@{
                            address = $canonicalContact.Email
                            name    = $displayName
                        })
                    }
                    try {
                        New-MgUserContactFolderContact -UserId $UserId `
                                                      -ContactFolderId $folder.Id `
                                                      -BodyParameter $bodyParameter `
                                                      -ErrorAction Stop | Out-Null
                        $userStats.Created++
                        Write-StatusMessage "Created: $displayName (no email)" -Type 'Success'
                    }
                    catch {
                        $userStats.Errors++
                        Write-StatusMessage "Failed to create $displayName : $($_.Exception.Message)" -Type 'Error'
                    }
                }
            }
        }

        # Delete contacts not in canonical list (if requested)
        if ($doDeleteNotInCsv -and -not $isWhatIf) {
            foreach ($email in $existingByEmail.Keys) {
                if (-not $CanonicalIndexByEmail.ContainsKey($email)) {
                    $existingContact = $existingByEmail[$email]
                    $contactName = if ($existingContact.displayName) {
                        $existingContact.displayName
                    } else {
                        ($existingContact.emailAddresses | Select-Object -First 1).name
                    }
                    try {
                        Remove-MgUserContact -UserId $UserId -ContactId $existingContact.Id -Confirm:$false -ErrorAction Stop
                        $userStats.Deleted++
                        Write-StatusMessage "Deleted: $contactName [$email]" -Type 'Success'
                    }
                    catch {
                        $userStats.Errors++
                        Write-StatusMessage "Failed to delete contact [$email] : $($_.Exception.Message)" -Type 'Error'
                    }
                }
            }

            foreach ($name in $existingByName.Keys) {
                if (-not $CanonicalIndexByName.ContainsKey($name)) {
                    $existingContact = $existingByName[$name]
                    $contactName = if ($existingContact.displayName) {
                        $existingContact.displayName
                    } else {
                        "$($existingContact.givenName) $($existingContact.surname)".Trim()
                    }
                    try {
                        Remove-MgUserContact -UserId $UserId -ContactId $existingContact.Id -Confirm:$false -ErrorAction Stop
                        $userStats.Deleted++
                        Write-StatusMessage "Deleted: $contactName (by name)" -Type 'Success'
                    }
                    catch {
                        $userStats.Errors++
                        Write-StatusMessage "Failed to delete contact [$name] : $($_.Exception.Message)" -Type 'Error'
                    }
                }
            }
        }

        Write-StatusMessage "Completed user: $UserId (Created: $($userStats.Created), Updated: $($userStats.Updated), Deleted: $($userStats.Deleted), Errors: $($userStats.Errors))" -Type 'Info'
        return $userStats
    }
    catch {
        Write-StatusMessage "Fatal error processing $UserId : $($_.Exception.Message)" -Type 'Error'
        return @{
            User    = $UserId
            Created = 0
            Updated = 0
            Deleted = 0
            Errors  = 1
        }
    }
} -ThrottleLimit $DegreeOfParallelism)

# ============================================================================
# SUMMARY AND CLEANUP
# ============================================================================

$totalStats = @{
    Created = ($syncStatistics | Measure-Object -Property Created -Sum).Sum
    Updated = ($syncStatistics | Measure-Object -Property Updated -Sum).Sum
    Deleted = ($syncStatistics | Measure-Object -Property Deleted -Sum).Sum
    Errors  = ($syncStatistics | Measure-Object -Property Errors -Sum).Sum
}

Write-StatusMessage "==================== SYNC COMPLETE ====================" -Type 'Info'
Write-StatusMessage "Users Processed: $($syncStatistics.Count)" -Type 'Info'
Write-StatusMessage "Total Contacts Created: $($totalStats.Created)" -Type 'Success'
Write-StatusMessage "Total Contacts Updated: $($totalStats.Updated)" -Type 'Success'
Write-StatusMessage "Total Contacts Deleted: $($totalStats.Deleted)" -Type 'Success'

if ($totalStats.Errors -gt 0) {
    Write-StatusMessage "Total Errors: $($totalStats.Errors)" -Type 'Error'
}
else {
    Write-StatusMessage "No errors encountered" -Type 'Success'
}

Write-StatusMessage "======================================================" -Type 'Info'