# Office 365 Management Scripts

PowerShell scripts for Office 365 user management, automation, and administrative tasks.

## 📁 Scripts in this Directory

### New-Office365Accounts.ps1
Creates new user accounts in Microsoft 365 (or Active Directory) from CSV file, array, or individual parameters with automatic password generation and optional OneDrive initialization.

**Quick Start:**
```powershell
# From CSV file
.\New-Office365Accounts.ps1 -CsvPath "C:\Users\NewHires.csv"

# From array
$users = @(
    @{FirstName='John'; LastName='Doe'; EmailAddress='john.doe@contoso.com'; UsageLocation='US'},
    @{FirstName='Jane'; LastName='Smith'; EmailAddress='jane.smith@contoso.com'; UsageLocation='US'}
)
.\New-Office365Accounts.ps1 -UserArray $users

# Single user with OneDrive initialization
.\New-Office365Accounts.ps1 `
    -FirstName "John" `
    -LastName "Doe" `
    -EmailAddress "john.doe@contoso.com" `
    -UsageLocation "US" `
    -InitializeOneDrive
```

**Use Cases:**
- Bulk user account creation for new hires
- Automated onboarding workflows
- Testing environments with multiple accounts
- Migration preparation with pre-created accounts

**Features:**
- CSV batch import or array input
- Secure password generation (12-128 characters)
- Password export to timestamped CSV
- Automatic OneDrive provisioning
- Microsoft 365 or Active Directory support
- Comprehensive validation and error tracking

**Parameters:**
- `CsvPath` - Path to CSV file with user data
- `UserArray` - Array of user objects (hashtables or PSCustomObjects)
- `FirstName`, `LastName`, `EmailAddress` - Individual user parameters (required)
- `DisplayName`, `Password`, `UsageLocation`, `Department`, `JobTitle` - Optional fields
- `AccountType` - "Microsoft365" (default) or "ActiveDirectory"
- `GeneratePasswords` - Force password generation even if provided
- `PasswordLength` - Length of generated passwords (12-128, default: 16)
- `InitializeOneDrive` - Automatically provision OneDrive for new accounts
- `BlockSignIn` - Create accounts but block sign-in initially
- `ForceChangePassword` - Require password change on first sign-in (default: true)

**Output:**
- CSV file: `C:\Reports\AccountCreation\AccountCreation_Results_YYYYMMDD_HHmmss.csv`
- Contains all account details including generated passwords
- OneDrive provisioning status if enabled

---

### Invoke-UserSignOutAndBlock.ps1
Blocks sign-in, revokes all active sessions and refresh tokens, and optionally disables Entra ID-registered devices for one or more Microsoft 365 / Entra ID accounts. Designed for offboarding, incident response, and account compromise scenarios.

**Quick Start:**
```powershell
# Single account - block sign-in and revoke sessions
.\Invoke-UserSignOutAndBlock.ps1 -Identity "jdoe@contoso.com"

# Single account - also disable all Entra ID-joined devices
.\Invoke-UserSignOutAndBlock.ps1 -Identity "jdoe@contoso.com" -DisableDevices

# Bulk from CSV
.\Invoke-UserSignOutAndBlock.ps1 -CsvPath "C:\Data\offboard.csv" -DisableDevices

# From array
$accounts = @(
    [PSCustomObject]@{ Identity = "jdoe@contoso.com";   Reason = "Offboarding" }
    [PSCustomObject]@{ Identity = "jsmith@contoso.com"; Reason = "Account compromise" }
)
.\Invoke-UserSignOutAndBlock.ps1 -UserArray $accounts -DisableDevices

# Preview without making changes
.\Invoke-UserSignOutAndBlock.ps1 -CsvPath "C:\Data\offboard.csv" -WhatIf
```

**Use Cases:**
- Employee offboarding — immediately cut access across all sessions and devices
- Account compromise response — revoke attacker sessions while investigation proceeds
- Bulk tenant decommissioning — lock all accounts before domain removal

**Features:**
- Blocks sign-in (AccountEnabled = $false)
- Revokes all refresh tokens and active sessions via Microsoft Graph
- Reports all Entra ID-registered/joined devices per account
- Optional device disablement (`-DisableDevices`)
- CSV file, array, or single-identity input
- WhatIf support for pre-run validation
- Timestamped CSV results report

**Parameters:**
- `CsvPath` - Path to CSV file (required column: `Identity`; optional: `Reason`)
- `UserArray` - Array of PSCustomObjects with `Identity` (and optionally `Reason`) properties
- `Identity` - Single UPN or Entra Object ID
- `DisableDevices` - Also disable all Entra ID-registered devices owned by the account
- `SkipBlockSignIn` - Revoke sessions only; do not set AccountEnabled = $false
- `SkipRevokeSession` - Block sign-in only; do not revoke existing sessions
- `OutputDirectory` - Results CSV location (default: `C:\Reports\CSV_Exports`)
- `GenerateTemplate` - Create a blank CSV template and exit

**Required Permissions (Microsoft Graph):**
- `User.ReadWrite.All`
- `Directory.ReadWrite.All`
- `Device.ReadWrite.All`

**Output:**
- CSV file: `C:\Reports\CSV_Exports\UserSignOutAndBlock_Results_YYYYMMDD_HHmmss.csv`
- Per-account status: SignInBlocked, SessionsRevoked, DevicesFound, DevicesDisabled

**Note:** This script does **not** wipe or retire managed devices from Intune. Use the Intune portal or dedicated scripts for remote wipe.

---

### Remove-OrganizedMeetings.ps1
Cancels all organized meetings for offboarded users to clean up calendars and send cancellation notices.

**Quick Start:**
```powershell
# Connect to Exchange Online first
Connect-ExchangeOnline

# Array of offboarded users
$offboardedUsers = @(
    "user1@contoso.com",
    "user2@contoso.com"
)

# Cancel their meetings
foreach ($user in $offboardedUsers) {
    Remove-CalendarEvents -Identity $user -CancelOrganizedMeetings -Confirm:$false
}
```

**Use Cases:**
- Offboarding cleanup
- Canceling recurring meetings for departed employees
- Calendar hygiene during transitions

---

### Sync-ContactsFromCsv.ps1
Synchronizes contact information from a CSV file to users' contact folders in Microsoft Graph. Retrieve users from security groups, populate contact folders with phone numbers, names, and company information, with optional deletion of contacts not in the source CSV.

**Quick Start:**
```powershell
# Sync all Sales team members' contacts from CSV
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Contacts" `
    -SecurityGroup "Sales Team"

# Include name updates and delete outdated contacts
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Shared Contacts" `
    -SecurityGroup "Sales Team" `
    -UpdateNames `
    -DeleteNotInCsv

# Preview changes without executing
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Contacts" `
    -SecurityGroup "Sales Team" `
    -WhatIf
```

**Use Cases:**
- Maintain consistent contact directories for departments or teams
- Sync sales contact lists to team mailboxes
- Automated contact folder management during reorganizations
- Central contact repository distribution to multiple users
- Bulk phone number updates across contact folders

**Features:**
- Retrieve target users from Entra security groups, CSV, or direct list
- Phone number normalization (auto-strips formatting)
- Selective updates (phone numbers only, or including names/company/titles)
- Contact cleanup with optional deletion of outdated contacts
- Parallel processing for fast bulk operations
- Comprehensive logging and execution statistics
- WhatIf support for previewing changes

**Parameters:**
- `CsvPath` - Source CSV with canonical contact data
- `FolderName` - Target contact folder name
- `-SecurityGroup` - Entra security group (retrieves members)
- `-Users` - Direct list of user UPNs
- `-UsersCsvPath` - CSV file with UPN column
- `-UpdateNames` - Include name/company/job title updates
- `-DeleteNotInCsv` - Remove contacts not in source CSV
- `-DegreeOfParallelism` - Concurrent user processing threads (1-16, default: 4)

**Output:**
- Real-time console feedback with color-coded status messages
- Per-user creation/update/delete counts
- Summary statistics on completion

**See Also:**
- [[Sync-ContactsFromCsv|Detailed Documentation]] (wiki)
- [CSV Template](templates/ContactList_Template.csv)
- [CSV Format Guide](.prep/ContactList_Format.md)

---

## 🚀 Prerequisites

### PowerShell Requirements
- **PowerShell 5.1 or later** (Windows PowerShell or PowerShell 7+)
- **Execution Policy**: RemoteSigned or Unrestricted
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Required Modules

**For New-Office365Accounts.ps1:**
- **Microsoft.Graph.Users** (required)
- **Microsoft.Graph.Files** (for OneDrive initialization)
- **Microsoft.Graph.Sites** (for OneDrive initialization)
- **ActiveDirectory** (optional, for AD account creation)

```powershell
# Install Microsoft Graph modules
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Files -Scope CurrentUser
Install-Module Microsoft.Graph.Sites -Scope CurrentUser
```

**For Sync-ContactsFromCsv.ps1:**
- **Microsoft.Graph.Authentication** (required)
- **Microsoft.Graph.Users** (required)
- **Microsoft.Graph.Groups** (required for security group member retrieval)

```powershell
# Install Microsoft Graph modules
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Groups -Scope CurrentUser
```

**For Remove-OrganizedMeetings.ps1:**
- **ExchangeOnlineManagement**

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

### Permissions Required

**New-Office365Accounts.ps1:**
- Microsoft Graph: `User.ReadWrite.All`
- For OneDrive: `Files.ReadWrite.All`, `Sites.ReadWrite.All`
- For AD: Account creation rights in target OU

**Sync-ContactsFromCsv.ps1:**
- Microsoft Graph: `Contacts.ReadWrite`, `User.Read.All`, `Group.Read.All`
- (Contact folder must be accessible to the authenticated user)

**Remove-OrganizedMeetings.ps1:**
- Exchange Online: Exchange Administrator or Global Administrator

---

## 📊 Related Resources

### Template Generator
Use the **New-AccountCreationTemplate.ps1** script in `scripts/Assessment/Microsoft365/` to generate a properly formatted CSV template for bulk account creation:

```powershell
..\Assessment\Microsoft365\New-AccountCreationTemplate.ps1
```

This generates `AccountCreation_Template.csv` with all available fields and sample data.

### Sample CSV Format
```csv
FirstName,LastName,EmailAddress,DisplayName,Password,UsageLocation,Department,JobTitle
John,Doe,john.doe@contoso.com,John Doe,,US,IT,Systems Administrator
Jane,Smith,jane.smith@contoso.com,Jane Smith,,US,Sales,Account Manager
```

**Note:** Leave `Password` column empty to auto-generate secure passwords.

---

## 🔧 Common Workflows

### Bulk User Creation with OneDrive
```powershell
# 1. Generate template
..\Assessment\Microsoft365\New-AccountCreationTemplate.ps1 -OutputPath "C:\NewHires.csv"

# 2. Fill in user data (edit CSV in Excel)

# 3. Create accounts with OneDrive
.\New-Office365Accounts.ps1 -CsvPath "C:\NewHires.csv" -InitializeOneDrive

# 4. Secure the password file immediately!
# Output: C:\Reports\AccountCreation\AccountCreation_Results_YYYYMMDD_HHmmss.csv
```

### Array-Based Account Creation
```powershell
# Create from array (useful for automation/API integration)
$newHires = @(
    @{
        FirstName = 'John'
        LastName = 'Doe'
        EmailAddress = 'john.doe@contoso.com'
        UsageLocation = 'US'
        Department = 'IT'
        JobTitle = 'Systems Administrator'
    },
    @{
        FirstName = 'Jane'
        LastName = 'Smith'
        EmailAddress = 'jane.smith@contoso.com'
        UsageLocation = 'US'
        Department = 'Sales'
    }
)

.\New-Office365Accounts.ps1 -UserArray $newHires -GeneratePasswords -PasswordLength 20
```

### Offboarding Cleanup
```powershell
# Cancel meetings for departed employees
Connect-ExchangeOnline

$offboarded = @("departed1@contoso.com", "departed2@contoso.com")

foreach ($user in $offboarded) {
    Remove-CalendarEvents -Identity $user -CancelOrganizedMeetings -Confirm:$false
}
```

---

## 🔒 Security Notes

### Password Security
- Generated passwords meet complexity requirements (uppercase, lowercase, numbers, special characters)
- **CRITICAL**: Secure the output CSV file immediately after creation - it contains plaintext passwords
- Consider encrypting the password file or using secure delivery methods (e.g., secure email, password manager)
- Delete or securely archive password files after distribution

### Best Practices
- Use `-BlockSignIn` to create accounts in disabled state until ready
- Always set `UsageLocation` for accounts that will receive licenses
- Review the output CSV for any creation errors before distributing credentials
- Test in a development tenant first when using array input from automation

---

## 📝 Additional Documentation

For detailed assessment and reporting scripts, see:
- [Assessment Scripts](../Assessment/Microsoft365/README.md)
- [Microsoft 365 Assessment Documentation](../../docs/Office365-Assessment-Guide.md)
