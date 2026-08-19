# New-Office365Accounts.ps1

## Overview
Automates the creation of new user accounts in Microsoft 365 or Active Directory with support for bulk CSV import, array input, or individual parameters. Features automatic password generation, secure credential storage, and optional OneDrive provisioning.

## Features
- **Multiple Input Methods**: CSV file, array of objects, or individual parameters
- **Secure Password Generation**: Automatically generates complex passwords (12-128 characters) meeting security requirements
- **Password Export**: Saves all credentials to timestamped CSV for secure distribution
- **OneDrive Provisioning**: Automatically initialize OneDrive for new accounts
- **Dual Platform Support**: Microsoft 365 (cloud) or Active Directory (on-premises)
- **Comprehensive Validation**: Email format validation, required field checking, module verification
- **Error Tracking**: Detailed success/failure/warning statistics
- **Batch Processing**: Create multiple accounts efficiently with progress tracking

## Prerequisites

### PowerShell Version
- PowerShell 5.1 or later (Windows PowerShell or PowerShell 7+)

### Required Modules

**For Microsoft 365 Accounts:**
```powershell
Install-Module Microsoft.Graph.Users -Scope CurrentUser
```

**For OneDrive Initialization (Optional):**
```powershell
Install-Module Microsoft.Graph.Files -Scope CurrentUser
Install-Module Microsoft.Graph.Sites -Scope CurrentUser
```

**For Active Directory Accounts (Optional):**
```powershell
# ActiveDirectory module (typically pre-installed on domain-joined systems)
Import-Module ActiveDirectory
```

### Required Permissions

**Microsoft 365:**
- `User.ReadWrite.All` (required for account creation)
- `Files.ReadWrite.All` (required for OneDrive initialization)
- `Sites.ReadWrite.All` (required for OneDrive initialization)

**Active Directory:**
- Account creation rights in target Organizational Unit
- Typically requires Domain Admins or delegated user creation permissions

### Network Requirements
- Internet connectivity for Microsoft Graph API
- Access to Microsoft 365 tenant
- For AD: Connection to domain controller

## Parameters

### Input Parameters (Mutually Exclusive)

#### CSV Input
**-CsvPath** `[string]` (Mandatory for CSV parameter set)
- Path to CSV file containing user account information
- CSV must contain: `FirstName`, `LastName`, `EmailAddress`
- Optional CSV columns: `DisplayName`, `Password`, `UsageLocation`, `Department`, `JobTitle`, `MobilePhone`, `OfficeLocation`, `StreetAddress`, `City`, `State`, `PostalCode`, `Country`

#### Array Input
**-UserArray** `[array]` (Mandatory for Array parameter set)
- Array of user objects (hashtables or PSCustomObjects)
- Each object must contain: `FirstName`, `LastName`, `EmailAddress`
- Optional properties: Same as CSV optional columns

#### Single User Input
**-FirstName** `[string]` (Mandatory for Single parameter set)
- First name of the user

**-LastName** `[string]` (Mandatory for Single parameter set)
- Last name of the user

**-EmailAddress** `[string]` (Mandatory for Single parameter set)
- Email address/User Principal Name
- Must be valid email format
- Must be unique in the directory

### Optional User Properties

**-DisplayName** `[string]`
- Display name for the user
- Default: `"FirstName LastName"`

**-Password** `[string]`
- Password for the account (8-256 characters)
- If not provided, a secure password is auto-generated

**-UsageLocation** `[string]` (2 characters)
- Two-letter country code (ISO 3166-1 alpha-2)
- Examples: `US`, `GB`, `CA`, `AU`, `DE`
- **Required for Microsoft 365 accounts that will receive licenses**

**-Department** `[string]`
- Department name

**-JobTitle** `[string]`
- Job title

### Configuration Parameters

**-AccountType** `[string]` (Default: `"Microsoft365"`)
- Type of account to create
- Valid values: `"Microsoft365"`, `"ActiveDirectory"`
- Default behavior is cloud-first

**-OutputDirectory** `[string]` (Default: `"C:\Reports\AccountCreation"`)
- Directory where output CSV files will be saved
- Created automatically if it doesn't exist

**-GeneratePasswords** `[switch]`
- Force password generation even if passwords are provided in CSV
- Useful for ensuring consistent password strength

**-PasswordLength** `[int]` (Default: `16`, Range: `12-128`)
- Length of auto-generated passwords
- Passwords include uppercase, lowercase, numbers, and special characters

**-ForceChangePassword** `[bool]` (Default: `$true`)
- Require users to change password on first sign-in
- Best practice for security

**-BlockSignIn** `[switch]`
- Create accounts but block sign-in initially
- Useful for pre-creating accounts before activation

**-InitializeOneDrive** `[switch]`
- Automatically provision OneDrive for each created account
- Only applicable for Microsoft 365 accounts
- Requires additional Graph permissions

## Running from GitHub

You can invoke this script directly from GitHub without downloading it first. This is particularly useful in Azure Cloud Shell or for quick testing.

### Method 1: Direct Invocation (Recommended for Cloud Shell)
```powershell
# Download and run from GitHub
$scriptUrl = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Office365/New-Office365Accounts.ps1"
Invoke-WebRequest -Uri $scriptUrl -OutFile "./New-Office365Accounts.ps1"
chmod +x ./New-Office365Accounts.ps1  # Linux/Cloud Shell only

# Now run with your parameters
./New-Office365Accounts.ps1 -UserArray $users
```

### Method 2: One-Line Execution (Advanced)
```powershell
# Execute directly without saving
$scriptUrl = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Office365/New-Office365Accounts.ps1"
Invoke-Expression (Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content
```

**Note:** After running with Method 2, you'll need to call the script's functions directly. Method 1 is recommended for most use cases.

### Cloud Shell Quick Start
```powershell
# 1. Open Azure Cloud Shell (https://shell.azure.com)
# 2. Download the script
$scriptUrl = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Office365/New-Office365Accounts.ps1"
Invoke-WebRequest -Uri $scriptUrl -OutFile "./New-Office365Accounts.ps1"

# 3. Prepare your user data
$users = @(
    @{FirstName='John'; LastName='Doe'; EmailAddress='john.doe@contoso.com'; UsageLocation='US'}
)

# 4. Run the script
./New-Office365Accounts.ps1 -UserArray $users

# 5. Download the results
# The script will provide the exact download command, e.g.:
# download "/home/user/clouddrive/AccountCreation/AccountCreation_Results_20260122_143052.csv"
```

### Alternative: Clone Repository
```powershell
# Clone entire repository for offline use
git clone https://github.com/Managed-Solution-LLC/PowerShellEveryting.git
cd PowerShellEveryting/scripts/Office365
./New-Office365Accounts.ps1 -CsvPath "path/to/users.csv"
```

## Usage Examples

### Example 1: Basic CSV Import
```powershell
.\New-Office365Accounts.ps1 -CsvPath "C:\Users\NewHires.csv"
```
Creates Microsoft 365 accounts from CSV file. Generates passwords for any accounts without passwords specified.

### Example 2: Array Input with Multiple Users
```powershell
$users = @(
    @{FirstName='John'; LastName='Doe'; EmailAddress='john.doe@contoso.com'; UsageLocation='US'; Department='IT'},
    @{FirstName='Jane'; LastName='Smith'; EmailAddress='jane.smith@contoso.com'; UsageLocation='US'; Department='Sales'}
)
.\New-Office365Accounts.ps1 -UserArray $users
```
Creates accounts from an array of hashtables with department information.

### Example 3: Single User with All Options
```powershell
.\New-Office365Accounts.ps1 `
    -FirstName "John" `
    -LastName "Doe" `
    -EmailAddress "john.doe@contoso.com" `
    -UsageLocation "US" `
    -Department "IT" `
    -JobTitle "Systems Administrator" `
    -InitializeOneDrive
```
Creates a single account with detailed information and provisions OneDrive.

### Example 4: Active Directory Account Creation
```powershell
.\New-Office365Accounts.ps1 `
    -CsvPath "C:\Users\NewHires.csv" `
    -AccountType "ActiveDirectory"
```
Creates on-premises Active Directory accounts from CSV file.

### Example 5: Force Strong Passwords
```powershell
.\New-Office365Accounts.ps1 `
    -CsvPath "C:\Users\NewHires.csv" `
    -GeneratePasswords `
    -PasswordLength 20
```
Creates accounts and generates 20-character passwords for all users, ignoring any passwords in the CSV.

### Example 6: Pre-Create Disabled Accounts
```powershell
.\New-Office365Accounts.ps1 `
    -CsvPath "C:\Users\FutureHires.csv" `
    -BlockSignIn
```
Creates accounts but blocks sign-in until you're ready to activate them.

### Example 7: Array with PSCustomObjects
```powershell
$newHires = @(
    [PSCustomObject]@{
        FirstName = 'John'
        LastName = 'Doe'
        EmailAddress = 'john.doe@contoso.com'
        UsageLocation = 'US'
        Department = 'Engineering'
        JobTitle = 'Software Engineer'
        MobilePhone = '+1-555-0100'
    }
)
.\New-Office365Accounts.ps1 -UserArray $newHires -InitializeOneDrive
```
Creates accounts from PSCustomObjects with full contact details and OneDrive provisioning.

## Output

### Output File Location
Default: `C:\Reports\AccountCreation\AccountCreation_Results_YYYYMMDD_HHmmss.csv`

### Output File Naming
Pattern: `AccountCreation_Results_YYYYMMDD_HHmmss.csv`

Example: `AccountCreation_Results_20260122_143052.csv`

### Output File Contents
The CSV file contains all account details including:
- **DisplayName**: Full display name
- **FirstName**: User's first name
- **LastName**: User's last name
- **EmailAddress**: Email/UPN
- **Password**: Account password (plaintext - **secure this file!**)
- **PasswordGenerated**: Boolean indicating if password was auto-generated
- **AccountType**: "Microsoft365" or "ActiveDirectory"
- **Created**: Boolean indicating successful creation
- **UserId**: Unique identifier (GUID for AD, Object ID for M365)
- **OneDriveInitialized**: Boolean (if OneDrive initialization was requested)
- **OneDrivePending**: Boolean (if OneDrive provisioning is pending)
- **OneDriveUrl**: URL to user's OneDrive (if available)
- **Error**: Error message if creation failed
- **Timestamp**: Creation timestamp
- **Optional Fields**: Department, JobTitle, MobilePhone, etc. (if provided)

### Console Output
The script provides color-coded console feedback:
- ✅ **Green**: Successful operations
- ❌ **Red**: Errors
- ⚠️ **Yellow**: Warnings
- **Cyan**: Informational messages

### Summary Statistics
At completion, displays:
- Total accounts processed
- Successfully created
- Failed creations
- Warning count
- Execution duration

## CSV Template Format

### Generate Template
Use the companion script to generate a properly formatted template:
```powershell
..\Assessment\Microsoft365\New-AccountCreationTemplate.ps1
```

### Required Columns
```csv
FirstName,LastName,EmailAddress
```

### Complete Template
```csv
FirstName,LastName,EmailAddress,DisplayName,Password,UsageLocation,Department,JobTitle,MobilePhone,OfficeLocation,StreetAddress,City,State,PostalCode,Country
John,Doe,john.doe@contoso.com,John Doe,,US,IT,Systems Administrator,+1-555-0100,Building A,123 Main St,Seattle,WA,98101,United States
Jane,Smith,jane.smith@contoso.com,Jane Smith,,US,Sales,Account Manager,+1-555-0101,Building B,456 Oak Ave,Portland,OR,97201,United States
```

**Note:** Leave `Password` column empty to auto-generate secure passwords.

## Common Issues & Troubleshooting

### Issue: Module Not Found
**Error:** `Required module 'Microsoft.Graph.Users' is not installed`

**Solution:** Install the required module:
```powershell
Install-Module Microsoft.Graph.Users -Scope CurrentUser
```

For OneDrive functionality:
```powershell
Install-Module Microsoft.Graph.Files -Scope CurrentUser
Install-Module Microsoft.Graph.Sites -Scope CurrentUser
```

### Issue: Connection Failed
**Error:** `Failed to connect to Microsoft Graph`

**Solutions:**
1. Ensure you have internet connectivity
2. Check MFA is properly configured for your account
3. Verify you have appropriate admin permissions
4. Try interactive authentication:
   ```powershell
   Connect-MgGraph -Scopes "User.ReadWrite.All"
   ```

### Issue: Permission Denied
**Error:** `Insufficient privileges to complete the operation`

**Solutions:**
- Verify you have `User.ReadWrite.All` permission in Microsoft Graph
- For OneDrive: Ensure `Files.ReadWrite.All` and `Sites.ReadWrite.All` permissions
- Check you have appropriate admin role (User Administrator or Global Administrator)
- Re-consent to permissions:
  ```powershell
  Disconnect-MgGraph
  Connect-MgGraph -Scopes "User.ReadWrite.All", "Files.ReadWrite.All", "Sites.ReadWrite.All"
  ```

### Issue: User Already Exists
**Error:** `Another object with the same value for property userPrincipalName already exists`

**Solutions:**
- Verify email addresses are unique in your CSV
- Check if user already exists in directory
- Review soft-deleted users (may need to restore or permanently delete)
- Change the email address to a unique value

### Issue: OneDrive Not Initialized
**Warning:** `OneDrive not yet available - provisioning initiated`

**Explanation:** OneDrive provisioning can take several minutes after account creation. This is expected behavior.

**Solutions:**
- Wait 5-10 minutes and check again
- User can trigger provisioning by signing in and accessing OneDrive
- Provisioning happens automatically during first sign-in

### Issue: Invalid Usage Location
**Error:** `UsageLocation is required for license assignment`

**Solution:** Ensure you provide a valid 2-letter country code:
```powershell
-UsageLocation "US"  # Correct
-UsageLocation "USA" # Incorrect
```

### Issue: CSV Validation Failed
**Error:** `CSV missing required columns: FirstName, LastName`

**Solution:** Ensure your CSV has all required column headers:
```csv
FirstName,LastName,EmailAddress
```
Use `New-AccountCreationTemplate.ps1` to generate a proper template.

### Issue: No Write Permission
**Error:** `Cannot create output directory`

**Solutions:**
- Verify you have write permissions to `C:\Reports\AccountCreation`
- Specify a different output directory:
  ```powershell
  -OutputDirectory "C:\Temp\AccountCreation"
  ```

### Issue: Array Validation Failed
**Error:** `User object missing required properties: EmailAddress`

**Solution:** Ensure each object in array has required properties:
```powershell
# Correct
$users = @(
    @{FirstName='John'; LastName='Doe'; EmailAddress='john.doe@contoso.com'}
)

# Incorrect (missing EmailAddress)
$users = @(
    @{FirstName='John'; LastName='Doe'}
)
```

## Security Best Practices

### Password File Security
⚠️ **CRITICAL:** The output CSV contains plaintext passwords!

**Recommended Actions:**
1. **Secure immediately** after generation
2. **Encrypt the file** using BitLocker, 7-Zip with password, or similar
3. **Distribute securely** via encrypted email or password manager
4. **Delete** after passwords are distributed to users
5. **Archive securely** if retention is required (encrypted backup)

### Account Creation Best Practices
1. **UsageLocation**: Always set for accounts receiving licenses
2. **ForceChangePassword**: Keep enabled (default: true) for security
3. **BlockSignIn**: Use when pre-creating accounts before user start date
4. **Strong Passwords**: Use minimum 16 characters (default)
5. **Review Output**: Check for errors before distributing credentials
6. **Test First**: Create test accounts in development tenant

### Permission Management
- Use least-privilege service accounts for automation
- Consider using app-only authentication with certificate for unattended scripts
- Regularly audit admin role assignments
- Enable conditional access policies for admin accounts

## Advanced Scenarios

### Automated Onboarding Pipeline
```powershell
# 1. Import user data from HR system
$hrData = Import-Csv "C:\HR\NewHires_$(Get-Date -Format 'yyyyMMdd').csv"

# 2. Transform to required format
$users = $hrData | ForEach-Object {
    @{
        FirstName = $_.GivenName
        LastName = $_.Surname
        EmailAddress = "$($_.GivenName).$($_.Surname)@contoso.com".ToLower()
        UsageLocation = 'US'
        Department = $_.Department
        JobTitle = $_.Title
    }
}

# 3. Create accounts with OneDrive
.\New-Office365Accounts.ps1 -UserArray $users -InitializeOneDrive

# 4. Send welcome emails (separate process)
```

### Integration with Ticketing System
```powershell
# Create account from ticket data
$ticketData = Get-ServiceNowTicket -Number "RITM0012345"

.\New-Office365Accounts.ps1 `
    -FirstName $ticketData.FirstName `
    -LastName $ticketData.LastName `
    -EmailAddress $ticketData.Email `
    -UsageLocation $ticketData.Country `
    -Department $ticketData.Department `
    -JobTitle $ticketData.JobTitle

# Update ticket with account details
```

### Bulk Creation with Progress Tracking
```powershell
# For very large batches, create in chunks
$allUsers = Import-Csv "C:\Users\LargeImport.csv"
$batchSize = 50

for ($i = 0; $i -lt $allUsers.Count; $i += $batchSize) {
    $batch = $allUsers[$i..([Math]::Min($i + $batchSize - 1, $allUsers.Count - 1))]
    
    Write-Host "Processing batch $([Math]::Floor($i/$batchSize) + 1)..." -ForegroundColor Cyan
    
    .\New-Office365Accounts.ps1 -UserArray $batch
    
    Start-Sleep -Seconds 5 # Brief pause between batches
}
```

## GitHub Repository Access

### Script Location
**GitHub Repository:** [Managed-Solution-LLC/PowerShellEveryting](https://github.com/Managed-Solution-LLC/PowerShellEveryting)

**Direct Script URL:**
```
https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Office365/New-Office365Accounts.ps1
```

### Quick Access in Cloud Shell
Azure Cloud Shell has git pre-installed and is ideal for running this script:

```powershell
# Option 1: Download single script
curl -O https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Office365/New-Office365Accounts.ps1

# Option 2: Clone full repository
git clone https://github.com/Managed-Solution-LLC/PowerShellEveryting.git
cd PowerShellEveryting/scripts/Office365
```

### Benefits of Running from GitHub
- ✅ **Always Latest Version** - Get the most recent updates
- ✅ **No Local Storage Required** - Perfect for Cloud Shell
- ✅ **Quick Testing** - Try before committing to local installation
- ✅ **Consistent Environment** - Same script across all machines
- ✅ **Easy Updates** - Just re-download to get latest version

### Security Considerations
When running scripts from the internet:
1. **Review the code first** - Check the GitHub repository
2. **Use HTTPS URLs** - Ensures encrypted transfer
3. **Verify the source** - Confirm it's from the official repository
4. **Check commit history** - Review recent changes on GitHub
5. **Use raw.githubusercontent.com** - For direct script downloads

## Related Scripts
- [New-AccountCreationTemplate.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/docs/scripts/Assessment/Microsoft365/New-AccountCreationTemplate) - Generate CSV template
- [Get-QuickO365Report.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-QuickO365Report) - Tenant assessment
- [Get-MailboxPermissionsReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-MailboxPermissionsReport) - Audit permissions
- [Running Scripts from GitHub Guide](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Running-Scripts-from-GitHub) - General guide for all scripts

## Workflow Integration

### Complete Onboarding Process
1. **Generate Template**: Use `New-AccountCreationTemplate.ps1`
2. **Fill Data**: Enter user information in Excel
3. **Create Accounts**: Run `New-Office365Accounts.ps1` with CSV
4. **Secure Passwords**: Encrypt/store password file securely
5. **Verify**: Check output for errors
6. **Assign Licenses**: Use separate licensing script
7. **Distribute**: Send credentials via secure method
8. **Clean Up**: Delete/archive password file

## Version History
- **v1.0** (2026-01-22): Initial release
  - CSV, array, and single user input support
  - Secure password generation
  - OneDrive initialization
  - Microsoft 365 and Active Directory support
  - Comprehensive error handling and validation

## See Also
- [Microsoft Graph User API Documentation](https://learn.microsoft.com/en-us/graph/api/user-post-users)
- [New-ADUser Cmdlet Documentation](https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-aduser)
- [Microsoft 365 Licensing Best Practices](https://learn.microsoft.com/en-us/microsoft-365/enterprise/assign-licenses-to-user-accounts)
- [OneDrive Provisioning Guide](https://learn.microsoft.com/en-us/sharepoint/provision-onedrive)
