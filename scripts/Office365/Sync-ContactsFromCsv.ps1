
<#
.SYNOPSIS
    Synchronizes contact information from a CSV file to users' contact folders in Microsoft Graph.

.DESCRIPTION
    This script syncs contact information from a source CSV file to contact folders within specified users'
    Microsoft Graph mailboxes. It can retrieve target users from a security group, CSV file, or direct list.
    The script updates phone numbers, names, company, and job title information, and optionally deletes 
    contacts not present in the source CSV.

.PARAMETER CsvPath
    Path to the CSV file containing canonical contact information. Required columns: Email, GivenName, Surname.
    Optional columns: BusinessPhones (semicolon-separated), MobilePhone, Company, JobTitle.

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
    .\ChangeContacts.ps1 -CsvPath "C:\contacts.csv" -FolderName "Contacts" -SecurityGroup "Sales Team"

.EXAMPLE
    .\ChangeContacts.ps1 -CsvPath "C:\contacts.csv" -FolderName "Shared Contacts" -UsersCsvPath "C:\users.csv" -UpdateNames -DeleteNotInCsv

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

.LINK
    https://docs.microsoft.com/graph/api/contactfolder-post-childfolders
#>

#Requires -Version 7.2
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups

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
            $targetUsers = $members.AdditionalProperties.userPrincipalName | Where-Object { $_ } | Sort-Object -Unique
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
            $csvUsers = Import-Csv -Path $UsersCsvFile -ErrorAction Stop
            $targetUsers += ($csvUsers | Where-Object { $_.UPN } | ForEach-Object { $_.UPN } | Sort-Object -Unique)
            Write-StatusMessage "Loaded $($csvUsers.Count) users from CSV" -Type 'Success'
        }
        catch {
            throw "Failed to load users from CSV: $($_.Exception.Message)"
        }
    }

    return ($targetUsers | Sort-Object -Unique)
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
            
            if ($PSCmdlet.ShouldProcess("$UserId/$FolderName", "Create contact folder")) {
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
    'Microsoft.Graph.Groups'
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
    $canonicalContacts = Import-Csv -Path $CsvPath -ErrorAction Stop
    Write-StatusMessage "Loaded $($canonicalContacts.Count) canonical contacts" -Type 'Success'
}
catch {
    throw "Failed to load canonical contacts: $($_.Exception.Message)"
}

if ($canonicalContacts.Count -eq 0) {
    throw "No contacts found in CSV file: $CsvPath"
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
$targetUsers = Get-TargetUsers -SecurityGroup:$($PSBoundParameters['SecurityGroup']) `
                               -UsersList:$($PSBoundParameters['Users']) `
                               -UsersCsvFile:$($PSBoundParameters['UsersCsvPath'])

if ($targetUsers.Count -eq 0) {
    Write-StatusMessage "No target users found. Exiting." -Type 'Warning'
    exit 0
}

Write-StatusMessage "Starting contact synchronization for $($targetUsers.Count) users with DegreeOfParallelism=$DegreeOfParallelism"

# Create index of canonical contacts by email for quick lookup
$canonicalByEmail = @{}
foreach ($contact in $canonicalContacts) {
    if ($contact.Email) {
        $canonicalByEmail[$contact.Email.ToLower()] = $contact
    }
}

# Setup parallel processing
$syncStatistics = [System.Collections.Concurrent.ConcurrentBag[psobject]]::new()
$throttle = [System.Threading.SemaphoreSlim]::new($DegreeOfParallelism)
$tasks = @()

foreach ($user in $targetUsers) {
    $null = $throttle.WaitAsync()
    
    $task = [System.Threading.Tasks.Task]::Run({
        param($UserId, $TargetFolderName, $CanonicalIndex, $Throttle)
        
        try {
            $userStats = @{
                User    = $UserId
                Created = 0
                Updated = 0
                Deleted = 0
                Errors  = 0
            }

            Write-StatusMessage "Processing user: $UserId" -Type 'Info'

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

            # Index existing contacts by email
            $existingByEmail = @{}
            foreach ($contact in $existingContacts) {
                if ($contact.emailAddresses -and $contact.emailAddresses.Count -gt 0) {
                    $primaryEmail = $contact.emailAddresses | Select-Object -First 1
                    if ($primaryEmail.address) {
                        $existingByEmail[$primaryEmail.address.ToLower()] = $contact
                    }
                }
            }

            # Process each canonical contact
            foreach ($canonicalEmail in $CanonicalIndex.Keys) {
                $canonicalContact = $CanonicalIndex[$canonicalEmail]
                $displayName = if ($canonicalContact.GivenName -or $canonicalContact.Surname) {
                    "$($canonicalContact.GivenName) $($canonicalContact.Surname)".Trim()
                }
                else {
                    $canonicalContact.Email
                }

                if ($existingByEmail.ContainsKey($canonicalEmail)) {
                    # Contact exists - check if update needed
                    $existingContact = $existingByEmail[$canonicalEmail]
                    $comparison = Compare-ContactProperties -ExistingContact $existingContact `
                                                           -CanonicalContact $canonicalContact `
                                                           -UpdateNames:$UpdateNames

                    if ($comparison.needsUpdate) {
                        if ($PSCmdlet.ShouldProcess("$UserId - $displayName", "Update contact")) {
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
                }
                else {
                    # Contact doesn't exist - create it
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

                    if ($PSCmdlet.ShouldProcess("$UserId - $displayName", "Create contact")) {
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

            # Delete contacts not in canonical list (if requested)
            if ($DeleteNotInCsv -and -not $WhatIfPreference) {
                foreach ($email in $existingByEmail.Keys) {
                    if (-not $CanonicalIndex.ContainsKey($email)) {
                        $existingContact = $existingByEmail[$email]
                        $contactName = if ($existingContact.displayName) {
                            $existingContact.displayName
                        }
                        else {
                            ($existingContact.emailAddresses | Select-Object -First 1).name
                        }

                        if ($PSCmdlet.ShouldProcess("$UserId - $contactName", "Delete contact")) {
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
        finally {
            $null = $Throttle.Release()
        }

    }, @($user, $FolderName, $canonicalByEmail, $throttle))

    $tasks += $task
}

# Wait for all tasks to complete
Write-StatusMessage "Waiting for all users to be processed..."
[System.Threading.Tasks.Task]::WaitAll($tasks)

# Collect results
foreach ($task in $tasks) {
    if ($task.Result) {
        $syncStatistics.Add($task.Result)
    }
}

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