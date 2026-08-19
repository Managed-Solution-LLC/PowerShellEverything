# Sync-ContactsFromCsv

## Overview

`Sync-ContactsFromCsv.ps1` synchronizes contact information from a CSV file to users' contact folders in Microsoft Graph. This script is ideal for organizations that need to maintain consistent contact information across multiple mailboxes, such as shared contact directories, sales teams, or department-wide contact lists.

The script retrieves target users from a security group, CSV file, or direct list, then syncs contact data including phone numbers, names, company information, and job titles from a canonical CSV source.

## Features

- **Security Group Integration** - Automatically retrieve users from Entra security groups
- **Flexible User Selection** - Pull users from security groups, CSV files, or direct parameter lists
- **Phone Number Normalization** - Automatically strips formatting while preserving digits and international prefixes
- **Selective Updates** - Update only phone numbers by default, or include names/company/job titles with `-UpdateNames`
- **Contact Cleanup** - Optionally delete contacts not present in the source CSV with `-DeleteNotInCsv`
- **Parallel Processing** - Process multiple users concurrently with configurable thread count (1-16)
- **Comprehensive Logging** - Color-coded console output with detailed status messages and execution statistics
- **WhatIf Support** - Preview changes before executing with `-WhatIf` parameter
- **Automatic Folder Creation** - Creates missing contact folders as needed

## Prerequisites

### PowerShell Version
- **PowerShell 7.2 or later** (required by #Requires directive)

### Required Modules
- `Microsoft.Graph.Authentication` - Authentication to Microsoft Graph
- `Microsoft.Graph.Users` - User and contact management
- `Microsoft.Graph.Groups` - Security group membership retrieval

Will be automatically installed if missing during script execution.

### Required Permissions
The script requires Microsoft Graph permissions:
- `Contacts.ReadWrite` - Create, update, and delete contacts
- `User.Read.All` - Retrieve user information
- `Group.Read.All` - Read security group membership (when using `-SecurityGroup`)

### Network & Connectivity
- Active internet connection
- Access to Microsoft Graph API
- Appropriate tenant permissions for contact folder operations

## Parameters

### CsvPath
**Type:** String  
**Required:** Yes  
**Description:** Path to the CSV file containing canonical contact information to sync.

**Expected CSV Columns:**
- `Email` (required) - Primary email address; used as unique identifier
- `GivenName` - First name (required for display name; updated with `-UpdateNames`)
- `Surname` - Last name (required for display name; updated with `-UpdateNames`)
- `Company` - Company name (updated with `-UpdateNames`)
- `JobTitle` - Job title or position (updated with `-UpdateNames`)
- `BusinessPhones` - Semicolon-separated list of business phone numbers
- `MobilePhone` - Mobile/cell phone number

See [ContactList_Template.csv](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Office365/templates/ContactList_Template.csv) for example format.

### FolderName
**Type:** String  
**Required:** Yes  
**Description:** Name of the contact folder to sync. The folder will be created in each user's mailbox if it doesn't already exist.

**Example:** `"Contacts"`, `"Shared Contacts"`, `"Sales Directory"`

### SecurityGroup
**Type:** String  
**Required:** Yes (Parameter Set: SecurityGroup)  
**Description:** Distinguished name (DN), display name, or object ID of the Entra security group whose members should be synced.

**Formats Accepted:**
- Display Name: `"Sales Team"`
- Distinguished Name: `"CN=Sales Team,OU=Groups,DC=contoso,DC=com"`
- Object ID: `"12345678-1234-1234-1234-123456789012"`

**Note:** Mutually exclusive with `-Users` and `-UsersCsvPath`

### Users
**Type:** String Array  
**Required:** Yes (Parameter Set: UsersList)  
**Description:** Array of user principal names (UPNs) to sync.

**Example:**
```powershell
-Users @("john.smith@contoso.com", "jane.doe@contoso.com")
```

**Note:** Mutually exclusive with `-SecurityGroup` and `-UsersCsvPath`

### UsersCsvPath
**Type:** String  
**Required:** Yes (Parameter Set: UsersCsv)  
**Description:** Path to CSV file containing target users. CSV must have a `UPN` column with user principal names.

**Example CSV format:**
```
UPN
john.smith@contoso.com
jane.doe@contoso.com
robert.johnson@contoso.com
```

**Note:** Mutually exclusive with `-SecurityGroup` and `-Users`

### DeleteNotInCsv
**Type:** Switch  
**Required:** No  
**Default:** Not specified (disabled)  
**Description:** If specified, deletes any contacts in the target contact folder that are not present in the source CSV.

**Use Case:** Ensure the contact folder matches the CSV exactly, removing outdated contacts

**Warning:** Use with caution - this will permanently remove contacts not in your CSV

### UpdateNames
**Type:** Switch  
**Required:** No  
**Default:** Not specified (disabled)  
**Description:** If specified, updates contact names, company, and job titles in addition to phone numbers. By default, only phone numbers are synced.

**Default Behavior (without flag):** Only phone numbers are updated  
**With Flag:** Updates GivenName, Surname, Company, and JobTitle

### DegreeOfParallelism
**Type:** Integer  
**Required:** No  
**Default:** 4  
**Valid Range:** 1-16  
**Description:** Number of parallel threads used to process users concurrently.

**Recommendations:**
- **1-2:** For testing or low-memory environments
- **4** (default): Balanced for most scenarios
- **8-16:** For large user counts (100+) on high-performance systems

## Usage Examples

### Example 1: Basic Sync - Phone Numbers Only
Sync phone numbers for all members of a security group to their "Contacts" folder:

```powershell
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Contacts" `
    -SecurityGroup "Sales Team"
```

### Example 2: Sync with Name Updates
Include name and company information updates:

```powershell
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Contacts" `
    -SecurityGroup "Sales Team" `
    -UpdateNames
```

### Example 3: Full Sync with Cleanup
Update everything and delete contacts not in CSV:

```powershell
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Shared Contacts" `
    -SecurityGroup "CN=Sales Team,OU=Groups,DC=contoso,DC=com" `
    -UpdateNames `
    -DeleteNotInCsv
```

### Example 4: Preview Changes (WhatIf)
Preview what changes would be made without executing:

```powershell
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Contacts" `
    -SecurityGroup "Sales Team" `
    -WhatIf
```

### Example 5: Specific Users from CSV
Load target users from a CSV file:

```powershell
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Contacts" `
    -UsersCsvPath "C:\target_users.csv"
```

### Example 6: Direct User List
Sync specific users without a security group:

```powershell
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Sales Directory" `
    -Users @("john.smith@contoso.com", "jane.doe@contoso.com", "bob.jones@contoso.com")
```

### Example 7: Faster Processing with Higher Parallelism
Process 50+ users with 8 concurrent threads:

```powershell
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Contacts" `
    -SecurityGroup "Sales Team" `
    -DegreeOfParallelism 8
```

## Output

### Console Output
The script provides real-time color-coded feedback:

```
ℹ️  [2026-03-12 14:23:45] Verifying required PowerShell modules...
✅ [2026-03-12 14:23:46] Successfully connected to Microsoft Graph
ℹ️  [2026-03-12 14:23:47] Loading canonical contacts from: C:\contacts.csv
✅ [2026-03-12 14:23:47] Loaded 50 canonical contacts
ℹ️  [2026-03-12 14:23:48] Retrieving members from security group: Sales Team
✅ [2026-03-12 14:23:49] Found 25 members in security group
ℹ️  [2026-03-12 14:23:50] Processing user: john.smith@contoso.com
✅ [2026-03-12 14:23:51] Created contact: John Smith [john.smith@contoso.com]
...
```

### Summary Report
After completion, displays execution statistics:

```
==================== SYNC COMPLETE ====================
Users Processed: 25
Total Contacts Created: 78
Total Contacts Updated: 145
Total Contacts Deleted: 12
======================================================
```

### Status Messages
- ✅ **Green (Success)** - Operation completed successfully
- ❌ **Red (Error)** - Operation failed; check details
- ⚠️ **Yellow (Warning)** - Potential issue; operation may be skipped
- ℹ️ **Cyan (Info)** - Informational message; normal operation flow

## Contact CSV Format

### Required Columns
| Column | Type | Notes |
|--------|------|-------|
| **Email** | String | Unique identifier; no duplicates |

### Optional Columns
| Column | Type | Notes |
|--------|------|-------|
| GivenName | String | First name; updated with `-UpdateNames` |
| Surname | String | Last name; updated with `-UpdateNames` |
| Company | String | Organization; updated with `-UpdateNames` |
| JobTitle | String | Position; updated with `-UpdateNames` |
| BusinessPhones | String | Semicolon-separated; formatting auto-stripped |
| MobilePhone | String | Only first number used if multiple |

### Phone Number Formatting
- **Auto-Stripped Characters:** Parentheses, hyphens, spaces, periods, commas
- **Preserved:** Digits (0-9) and plus sign (+)
- **International:** Include + prefix (e.g., `+1-555-123-4567` → `+15551234567`)
- **Multiple Business Phones:** Separate with semicolon (e.g., `(555) 123-4567; (555) 987-1234`)
- **Display in CSV:** Any formatting is acceptable; normalization is automatic

### CSV Encoding
- **Recommended:** UTF-8 without BOM
- Fields with commas should be wrapped in quotes
- Both Unix (LF) and Windows (CRLF) line endings are supported

## Common Issues & Troubleshooting

### Issue: "Security group not found"
**Symptoms:** Error message: "Security group 'Sales Team' not found"

**Causes:**
- Security group doesn't exist or has been deleted
- User doesn't have permission to read the security group
- Group display name doesn't match exact string

**Solutions:**
1. Verify security group exists in Entra:
   ```powershell
   Get-MgGroup -Filter "displayName eq 'Sales Team'"
   ```
2. Use the group's object ID instead of display name
3. Check user permissions in your tenant
4. Ensure exact spelling and case sensitivity where applicable

### Issue: "Module not found"
**Symptoms:** Errors about missing Microsoft.Graph modules

**Causes:**
- Modules haven't been installed
- User lacks permission to install modules
- PowerShell doesn't have internet access

**Solutions:**
1. Install modules manually:
   ```powershell
   Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
   Install-Module Microsoft.Graph.Users -Scope CurrentUser -Force
   Install-Module Microsoft.Graph.Groups -Scope CurrentUser -Force
   ```
2. Run PowerShell as administrator if installing system-wide
3. Check internet connectivity and proxy settings

### Issue: "Failed to connect to Microsoft Graph"
**Symptoms:** Authentication error or connection timeout

**Causes:**
- Not logged into Azure/Microsoft 365
- MFA required but not available
- Network connectivity issue

**Solutions:**
1. Verify you're connected to a network with Microsoft Graph access
2. Ensure proper MFA setup if required
3. Clear cached credentials:
   ```powershell
   Disconnect-MgGraph
   Connect-MgGraph -Scopes 'Contacts.ReadWrite', 'User.Read.All', 'Group.Read.All'
   ```
4. Test connectivity:
   ```powershell
   Test-NetConnection graph.microsoft.com -Port 443
   ```

### Issue: "No contacts created or updated"
**Symptoms:** Script completes but shows zero changes

**Causes:**
- Email addresses in CSV don't match existing contacts
- Contacts folder permissions issue
- Phone numbers are already normalized correctly

**Solutions:**
1. Verify email addresses match exactly:
   ```powershell
   Get-MgUserContactFolderContact -UserId "user@contoso.com" -All | Select DisplayName, EmailAddresses
   ```
2. Check contact folder permissions
3. Use `-WhatIf` to preview what would happen:
   ```powershell
   .\Sync-ContactsFromCsv.ps1 -CsvPath "..." -FolderName "..." -SecurityGroup "..." -WhatIf
   ```

### Issue: "Permission denied" when deleting contacts
**Symptoms:** Error when using `-DeleteNotInCsv`

**Causes:**
- Insufficient permissions to modify contacts
- Contact is protected or read-only
- Permission scope doesn't include Contacts.ReadWrite

**Solutions:**
1. Verify user has Contacts.ReadWrite permission
2. Remove `-DeleteNotInCsv` flag and manually delete outdated contacts
3. Check if contacts are protected in organization policies

### Issue: "CSV file not found" or "No contacts loaded"
**Symptoms:** Script exits with file not found error

**Causes:**
- Incorrect file path
- File path contains spaces and isn't quoted
- File doesn't have .csv extension or has wrong format

**Solutions:**
1. Use full path with quotes:
   ```powershell
   -CsvPath "C:\Reports\My Contacts.csv"
   ```
2. Verify file exists:
   ```powershell
   Test-Path "C:\Reports\contacts.csv"
   ```
3. Check CSV format includes Email column with data

## Performance Considerations

### User Count vs. Parallelism
- **1-10 users:** DegreeOfParallelism = 2-4 (default fine)
- **11-50 users:** DegreeOfParallelism = 4-6
- **50+ users:** DegreeOfParallelism = 8-16
- **100+ users:** DegreeOfParallelism = 12-16 (monitor system resources)

### Contact Count Impact
- Small contact folders (10-50 contacts): <1 second per user
- Medium contact folders (50-200 contacts): 2-5 seconds per user
- Large contact folders (200+ contacts): 5-15 seconds per user

### Network Bandwidth
Phone number updates use minimal bandwidth; name updates require slightly more.

### Tips for Best Performance
1. Test with `-WhatIf` on a small subset first
2. Run during off-peak hours for production scenarios
3. Monitor memory usage with high parallelism on large user counts
4. Consider breaking large syncs into smaller groups if needed

## Related Scripts

- [New-Office365Accounts](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/New-Office365Accounts) - Create bulk user accounts
- [Set-OfficeContacts](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Set-OfficeContacts) - Manage individual contact properties (wiki page coming soon)
- [Get-GraphToken.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Graph%20Commands/Get-GraphToken.ps1) - Generate Microsoft Graph authentication tokens

## Version History

- **v1.0** (2026-03-12) - Initial public release
  - Security group member retrieval
  - CSV-based contact syncing
  - Parallel processing support
  - Phone number normalization
  - Contact cleanup with deletion support
  - Comprehensive error handling and logging

## See Also

- [Microsoft Graph Contacts API](https://docs.microsoft.com/graph/api/resources/contact)
- [Microsoft Graph Contact Folders](https://docs.microsoft.com/graph/api/contactfolder-get)
- [CSV Template](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Office365/templates/ContactList_Template.csv)
- [Contact Format Documentation](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Office365/.prep/ContactList_Format.md)
