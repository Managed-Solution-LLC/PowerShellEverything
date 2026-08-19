# Get-MailboxRules.ps1

## Overview
Retrieves and exports mailbox rules from Exchange Online for all users or a specific user. This script is useful for auditing email forwarding rules, auto-replies, folder moves, and other automated actions configured in user mailboxes.

## Features
- Query all mailboxes or a specific user's mailbox
- Automatic output directory creation and validation
- Timestamped CSV output files
- Progress tracking with visual indicators
- Comprehensive error handling
- Exports key rule properties including forwards, redirects, and folder moves
- Creates empty CSV with headers if no rules found (for audit trail)
- Color-coded console output for easy monitoring

## Prerequisites
- **PowerShell**: 5.1 or later
- **Module**: ExchangeOnlineManagement (auto-checked, installation instructions provided if missing)
- **Permissions**: Exchange Online administrator role or equivalent
- **Connectivity**: Internet access to Exchange Online

## Parameters

### Required Parameters
None - all parameters are optional.

### Optional Parameters

#### `-OutputDirectory`
- **Type**: String
- **Default**: `C:\Temp\MailboxRules`
- **Description**: Directory where CSV files will be saved
- **Validation**: Must not be null or empty; automatically created if missing

**Example:**
```powershell
-OutputDirectory "D:\Reports\ExchangeAudits"
```

#### `-UserPrincipalName`
- **Type**: String
- **Default**: None (checks all users if not specified)
- **Description**: Specific user's email address to check
- **Validation**: Must be valid mailbox in tenant

**Example:**
```powershell
-UserPrincipalName "john.doe@contoso.com"
```

## Usage Examples

### Example 1: Check All Mailboxes
```powershell
.\Get-MailboxRules.ps1
```
Exports rules from all mailboxes in the tenant to the default directory `C:\Temp\MailboxRules\`.

**Output File**: `MailboxRules_AllUsers_20251223_143052.csv`

### Example 2: Check Specific User
```powershell
.\Get-MailboxRules.ps1 -UserPrincipalName "john.doe@contoso.com"
```
Exports rules only for the specified user.

**Output File**: `MailboxRules_john.doe_20251223_143052.csv`

### Example 3: Custom Output Directory
```powershell
.\Get-MailboxRules.ps1 -OutputDirectory "D:\Audits\MailboxRules"
```
Exports all user rules to a custom directory.

### Example 4: Specific User with Custom Directory
```powershell
.\Get-MailboxRules.ps1 `
    -UserPrincipalName "jane.smith@contoso.com" `
    -OutputDirectory "C:\Reports\Exchange"
```
Checks specific user and saves to custom location.

### Example 5: Batch Check Multiple Users
```powershell
$users = @("user1@contoso.com", "user2@contoso.com", "user3@contoso.com")
foreach ($user in $users) {
    .\Get-MailboxRules.ps1 -UserPrincipalName $user
}
```
Loops through multiple users, creating separate CSV files for each.

## Output

### Output File Naming
Files are automatically timestamped to prevent overwrites:

**Single User**: `MailboxRules_<username>_<YYYYMMDD_HHmmss>.csv`
- Example: `MailboxRules_john.doe_20251223_143052.csv`

**All Users**: `MailboxRules_AllUsers_<YYYYMMDD_HHmmss>.csv`
- Example: `MailboxRules_AllUsers_20251223_143052.csv`

### Output File Locations
**Default**: `C:\Temp\MailboxRules\`

**Custom**: Specified via `-OutputDirectory` parameter

### CSV Structure
The exported CSV contains the following columns:

| Column | Description | Example |
|--------|-------------|---------|
| `MailboxOwnerID` | Email address of mailbox owner | john.doe@contoso.com |
| `Name` | Name of the rule | Forward to Manager |
| `Description` | User-defined description | Auto-forward sales emails |
| `Enabled` | Whether rule is active | True |
| `RedirectTo` | Redirect recipient(s) | manager@contoso.com |
| `MoveToFolder` | Target folder for move action | \Inbox\Sales |
| `ForwardTo` | Forward recipient(s) | team@contoso.com |
| `ForwardAsAttachmentTo` | Forward as attachment recipient(s) | archive@contoso.com |
| `DeleteMessage` | Whether message is deleted | False |
| `MarkAsRead` | Whether message is marked read | True |
| `StopProcessingRules` | Whether to stop processing additional rules | False |

### Console Output
The script provides color-coded feedback:

**✅ Green** - Successful operations
- Connected to Exchange Online
- Directory created/exists
- Mailbox found
- Rules exported

**❌ Red** - Errors
- Module not installed
- Connection failed
- Mailbox not found
- Permission denied

**⚠️ Yellow** - Warnings
- Error checking specific mailbox
- No rules found (when creating empty CSV)

**ℹ️ Cyan** - Information
- Checking specific user
- Retrieving mailboxes

**Gray** - Neutral information
- No rules found for user

### Summary Report
At completion, displays:
```
═══════════════════════════════════════════════════════
Export Complete
═══════════════════════════════════════════════════════
  Mailboxes Checked:     250
  Users with Rules:      47
  Total Rules Found:     156
  Output File:           C:\Temp\MailboxRules\MailboxRules_AllUsers_20251223_143052.csv
═══════════════════════════════════════════════════════
```

## Common Use Cases

### 1. Security Audit - Auto-Forwarding Rules
Identify users with forwarding rules that may pose security risks:

```powershell
.\Get-MailboxRules.ps1
# Review CSV for ForwardTo, RedirectTo, or ForwardAsAttachmentTo values
```

### 2. Pre-Migration Assessment
Before migrating to another tenant, document all mailbox rules:

```powershell
.\Get-MailboxRules.ps1 -OutputDirectory "D:\Migration\PreMigrationAudit"
```

### 3. Compliance Reporting
Regular audits for compliance purposes:

```powershell
# Monthly audit
.\Get-MailboxRules.ps1 -OutputDirectory "C:\Compliance\MailboxRules\2025-12"
```

### 4. Troubleshooting Missing Emails
Check if a specific user has rules affecting email delivery:

```powershell
.\Get-MailboxRules.ps1 -UserPrincipalName "helpdesk@contoso.com"
```

### 5. Executive/VIP Account Review
Audit high-value accounts for unauthorized rules:

```powershell
$vipUsers = @("ceo@contoso.com", "cfo@contoso.com", "cto@contoso.com")
foreach ($vip in $vipUsers) {
    .\Get-MailboxRules.ps1 -UserPrincipalName $vip -OutputDirectory "C:\Security\VIP_Audit"
}
```

## Common Issues & Troubleshooting

### Issue: "ExchangeOnlineManagement module not installed"
**Solution**: Install the module:
```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

### Issue: "Failed to connect to Exchange Online"
**Solutions**:
1. Verify you have Exchange administrator permissions
2. Check internet connectivity
3. Ensure MFA is configured properly (use app password if needed)
4. Try connecting manually first:
   ```powershell
   Connect-ExchangeOnline
   ```

### Issue: "Failed to find mailbox: user@contoso.com"
**Solutions**:
1. Verify email address is spelled correctly
2. Confirm mailbox exists: `Get-Mailbox -Identity user@contoso.com`
3. Check you have permissions to view the mailbox
4. Ensure it's not a shared mailbox (use `-Identity` with shared mailbox GUID if needed)

### Issue: "No write permission to directory"
**Solutions**:
1. Ensure directory path exists or can be created
2. Run PowerShell as Administrator
3. Choose a different output directory:
   ```powershell
   -OutputDirectory "$env:USERPROFILE\Documents\MailboxRules"
   ```

### Issue: Script runs but no CSV file created
**Possible Causes**:
- No rules found in any mailbox (check console output)
- Path contains invalid characters
- Antivirus blocking file creation

**Solution**: 
Script now creates empty CSV with headers if no rules found. Check the output file path shown in summary.

### Issue: Slow performance with large tenants
**Solutions**:
1. Check specific users instead of all:
   ```powershell
   -UserPrincipalName "user@contoso.com"
   ```
2. Run during off-hours
3. Process users in batches:
   ```powershell
   $batch = Get-Mailbox -ResultSize 50
   foreach ($user in $batch) {
       .\Get-MailboxRules.ps1 -UserPrincipalName $user.UserPrincipalName
   }
   ```

### Issue: "Processing user (1 of 1)" shows for single user
This is expected behavior - indicates 1 out of 1 user is being processed.

## Security Considerations

### Data Sensitivity
- CSV output contains email routing information
- May reveal sensitive business processes
- Store output files securely
- Delete files after analysis if containing PII

### Permissions Required
- **Minimum**: Exchange Online View-Only Administrator
- **Recommended**: Exchange Administrator or Global Administrator
- Can use delegated admin permissions

### Audit Trail
- Script execution is logged in Exchange audit logs
- Each `Get-InboxRule` call is recorded
- Consider organizational compliance policies

## Performance Notes

### Execution Time Estimates
| Mailboxes | Approximate Duration |
|-----------|---------------------|
| 1 user | 5-10 seconds |
| 10 users | 30-60 seconds |
| 100 users | 5-10 minutes |
| 1,000+ users | 30-60 minutes |

### Factors Affecting Performance
- Number of mailboxes in tenant
- Number of rules per mailbox
- Network latency to Exchange Online
- Throttling policies

### Best Practices
1. Use `-UserPrincipalName` for single-user queries
2. Run large scans during off-hours
3. Monitor progress bar for estimated completion
4. Consider batching for very large tenants (5,000+ users)

## Related Scripts
- [Get-MailboxPermissionsReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-MailboxPermissionsReport) - Audit mailbox delegation
- [Get-QuickO365Report.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-QuickO365Report) - Comprehensive M365 assessment

## Version History
- **v1.0** (2022-11): Initial release
- **v1.1**: Added parameter, improved file creation logic
- **v2.0** (2025-12-23): Added single-user parameter, improved validation, timestamped files, enhanced error handling
- **v2.1** (2025-12-23): Fixed Windows path handling, corrected default directory, improved CSV export reliability

## See Also
- [Microsoft Docs: Get-InboxRule](https://docs.microsoft.com/en-us/powershell/module/exchange/get-inboxrule)
- [Exchange Online PowerShell](https://docs.microsoft.com/en-us/powershell/exchange/exchange-online-powershell)
- [Mailbox Rules Best Practices](https://docs.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/outlook-on-the-web/create-inbox-rules)
