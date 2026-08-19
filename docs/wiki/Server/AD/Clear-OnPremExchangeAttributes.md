# Clear-OnPremExchangeAttributes

## Overview
Removes on-premises Exchange attributes from Active Directory user accounts to enable cloud mailbox provisioning in Exchange Online. This script is essential when decommissioning on-premises Exchange or migrating to a cloud-only Exchange Online environment without hybrid configuration.

## Features
- **Pre-execution backup** of all Exchange attributes to CSV with base64 encoding for binary data
- **Comprehensive attribute removal** including msExchMailboxGuid (primary blocker) and 18+ other Exchange attributes
- **Rollback capability** using backup data with `-RestoreFromBackup` parameter
- **Flexible targeting** - single user, OU-based, or CSV bulk import
- **WhatIf support** for safe testing before execution
- **Detailed logging** with timestamped status messages and color-coded output
- **Automatic validation** checks before and after cleanup
- **Summary reports** with execution statistics and next steps

## Prerequisites
- **Active Directory PowerShell module** (RSAT tools)
- **Domain Administrator or Account Operator permissions**
- **PowerShell 5.1 or later**
- **Network connectivity** to Active Directory domain controllers

## Parameters

### Required Parameters (choose one mode)
- **Identity**: The SamAccountName, UserPrincipalName, or DistinguishedName of a single user to process
- **SearchBase**: Active Directory OU to search for users (e.g., "OU=Users,OU=ToMigrate,DC=contoso,DC=com")
- **InputFile**: Path to CSV file with users (must contain 'Identity' column)

### Optional Parameters
- **OutputDirectory**: Directory for backups and reports (Default: `C:\Reports\ExchangeCleanup`)
- **AttributesToRemove**: Specific Exchange attributes to remove (defaults to standard blocking attributes)
- **BackupOnly**: Only creates backup without removing attributes (useful for assessment)
- **RestoreFromBackup**: Path to backup CSV file for rollback operations
- **WhatIf**: Shows what would happen without making changes
- **Force**: Bypasses confirmation prompts (use with caution)
- **ListAttributes**: Lists all Exchange-related attributes and exits

## Usage Examples

### Example 1: Test Single User (Recommended First Step)
```powershell
.\Clear-OnPremExchangeAttributes.ps1 -Identity "jsmith" -WhatIf
```
Tests removal of Exchange attributes without making changes. Review the attributes that would be removed.

### Example 2: Clean Single User
```powershell
.\Clear-OnPremExchangeAttributes.ps1 -Identity "jsmith"
```
Backs up and removes Exchange attributes for user jsmith. Requires typing `PROCEED` to confirm.

### Example 3: Assessment Only (Backup Without Removal)
```powershell
.\Clear-OnPremExchangeAttributes.ps1 -Identity "jsmith" -BackupOnly
```
Creates backup of Exchange attributes without removing them. Useful for auditing what attributes exist.

### Example 4: Bulk Processing from CSV
```powershell
# Create CSV with user identities
$users = @('jsmith', 'mjones', 'bwilson')
$users | ForEach-Object { [PSCustomObject]@{Identity=$_} } | Export-Csv "C:\temp\users.csv" -NoTypeInformation

# Process all users
.\Clear-OnPremExchangeAttributes.ps1 -InputFile "C:\temp\users.csv"
```
Processes multiple users from CSV file. Type `PROCEED` when prompted to execute.

### Example 5: Process Entire OU
```powershell
.\Clear-OnPremExchangeAttributes.ps1 -SearchBase "OU=ToMigrate,OU=Users,DC=contoso,DC=com"
```
Backs up and removes Exchange attributes for all users in specified OU.

### Example 6: Force Execution (No Prompts)
```powershell
.\Clear-OnPremExchangeAttributes.ps1 -Identity "jsmith" -Force
```
Bypasses confirmation prompt. Use with caution in production.

### Example 7: Restore from Backup (Rollback)
```powershell
.\Clear-OnPremExchangeAttributes.ps1 -RestoreFromBackup "C:\Reports\ExchangeCleanup\ExchangeAttributes_Backup_20260202_143052.csv"
```
Restores Exchange attributes from previous backup. Requires typing `RESTORE` to confirm.

### Example 8: List Available Attributes
```powershell
.\Clear-OnPremExchangeAttributes.ps1 -ListAttributes
```
Displays all Exchange attributes that can be removed (default and extended lists).

## Output

### Console Output
The script provides real-time color-coded status messages:
- **Cyan** - Informational messages and headers
- **Green** - Success messages with ✅ checkmark
- **Yellow** - Warnings with ⚠️ symbol
- **Red** - Errors with ❌ symbol

### Output File Locations
Default output directory: `C:\Reports\ExchangeCleanup\`

Generated files follow timestamp pattern: `{Type}_{YYYYMMDD_HHmmss}.{ext}`

#### 1. Backup File (CSV)
**Pattern**: `ExchangeAttributes_Backup_YYYYMMDD_HHmmss.csv`

**Example**: `ExchangeAttributes_Backup_20260202_143052.csv`

Contains complete backup of all Exchange attributes for processed users including:
- Standard user properties (SamAccountName, UPN, DN, DisplayName, Enabled)
- All Exchange attributes (msExchMailboxGuid, legacyExchangeDN, mailNickname, etc.)
- Binary data encoded in base64 format
- Backup timestamp

#### 2. Results File (CSV)
**Pattern**: `ExchangeCleanup_Results_YYYYMMDD_HHmmss.csv`

**Example**: `ExchangeCleanup_Results_20260202_143052.csv`

Contains detailed results for each user:
- `User`: SamAccountName
- `RemovedCount`: Number of attributes successfully removed
- `RemovedAttributes`: List of removed attribute names
- `FailedAttributes`: List of attributes that failed to remove
- `SkippedAttributes`: Attributes with no values
- `Success`: Boolean indicating if operation succeeded

#### 3. Summary Report (TXT)
**Pattern**: `ExchangeCleanup_Summary_YYYYMMDD_HHmmss.txt`

**Example**: `ExchangeCleanup_Summary_20260202_143052.txt`

Comprehensive summary including:
- Operation statistics (total processed, successful, errors, skipped)
- File locations for backup and results
- Execution time and duration
- Error details if any occurred
- Next steps for completing migration

## Exchange Attributes Removed

### Default Attributes (Primary Blockers)
These attributes prevent cloud mailbox provisioning:

- **msExchMailboxGuid** - Primary blocker, must be removed
- **msExchArchiveGUID** - Archive mailbox identifier
- **msExchRemoteRecipientType** - Remote recipient type flags
- **msExchRecipientDisplayType** - Display type (1073741824 = user mailbox)
- **msExchRecipientTypeDetails** - Detailed recipient type
- **msExchUserCulture** - User locale settings
- **msExchVersion** - Exchange schema version
- **msExchMailboxSecurityDescriptor** - Mailbox permissions
- **msExchMasterAccountSid** - Master account SID
- **msExchPoliciesExcluded** - Policy exclusions
- **msExchRecipientSoftDeletedStatus** - Soft delete status
- **msExchUserAccountControl** - Account control flags
- **msExchWhenMailboxCreated** - Mailbox creation timestamp
- **mailNickname** - Exchange alias
- **legacyExchangeDN** - Legacy distinguished name
- **targetAddress** - Routing address
- **msExchHomeServerName** - Home server path
- **homeMDB** - Mailbox database location
- **msExchMailboxTemplateLink** - Mailbox template reference

### Extended Attributes (Comprehensive Cleanup)
Additional attributes removed with `-AttributesToRemove` parameter:

- msExchAddressBookFlags, msExchArchiveDatabaseLink, msExchArchiveName
- msExchArchiveQuota, msExchArchiveWarnQuota, msExchBypassAudit
- msExchBypassModerationLink, msExchDelegateListLink, msExchELCMailboxFlags
- msExchHideFromAddressLists, msExchMailboxAuditEnable, msExchMailboxFolderSet
- msExchMobileMailboxFlags, msExchProvisioningFlags, msExchRBACPolicyLink
- msExchRecipientLimit, msExchRetentionComment, msExchRetentionURL
- msExchSafeSendersHash, msExchTextMessagingState, msExchUMDtmfMap

## Common Issues & Troubleshooting

### Issue: "Active Directory PowerShell module is not installed"
**Solution**: Install RSAT tools:
```powershell
# Windows 10/11
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Windows Server
Install-WindowsFeature RSAT-AD-PowerShell
```

### Issue: "Cannot connect to Active Directory"
**Solution**: 
- Ensure you're running from domain-joined machine
- Verify network connectivity to domain controller
- Check if you have appropriate permissions

### Issue: "No write permission to output directory"
**Solution**: 
```powershell
# Run with different output directory
.\Clear-OnPremExchangeAttributes.ps1 -Identity "jsmith" -OutputDirectory "C:\temp\ExchangeCleanup"
```

### Issue: "Could not find user: username"
**Solution**:
- Verify user exists in Active Directory
- Check spelling of username
- Try using UserPrincipalName or DistinguishedName instead

### Issue: "Successfully Cleaned: 0" with no errors
**Cause**: Attributes may not have values or were already removed

**Solution**: Check backup CSV to see if attributes existed:
```powershell
Import-Csv "C:\Reports\ExchangeCleanup\ExchangeAttributes_Backup_*.csv" | 
    Select-Object SamAccountName, msExchMailboxGuid, mailNickname, legacyExchangeDN | 
    Format-List
```

### Issue: Mailbox still won't provision after cleanup
**Possible Causes**:
1. Azure AD Connect hasn't synced changes yet
2. User still has mailbox license assigned before attributes were cleared
3. Deleted mailbox still in soft-deleted state in Exchange Online

**Solution**:
```powershell
# 1. Force Azure AD Connect sync
Start-ADSyncSyncCycle -PolicyType Delta

# 2. Wait 15-30 minutes, then remove and reassign license

# 3. Check for soft-deleted mailboxes in Exchange Online
Connect-ExchangeOnline
Get-Mailbox -SoftDeletedMailbox -Identity "user@domain.com"
```

## Rollback Procedure

If mailbox provisioning fails or you need to restore original state:

```powershell
# Restore from backup
.\Clear-OnPremExchangeAttributes.ps1 -RestoreFromBackup "C:\Reports\ExchangeCleanup\ExchangeAttributes_Backup_20260202_143052.csv"

# Type: RESTORE
# Wait for completion

# Force Azure AD Connect sync
Start-ADSyncSyncCycle -PolicyType Delta
```

## Post-Cleanup Steps

### 1. Review Backup and Results
```powershell
# Check what was removed
Import-Csv "C:\Reports\ExchangeCleanup\ExchangeCleanup_Results_*.csv" | 
    Where-Object { $_.RemovedCount -gt 0 } | 
    Format-Table User, RemovedCount, Success -AutoSize
```

### 2. Force Azure AD Connect Sync (Hybrid Environments)
```powershell
# On Azure AD Connect server
Start-ADSyncSyncCycle -PolicyType Delta
```

### 3. Wait for Replication
Allow 15-30 minutes for changes to replicate to Azure AD.

### 4. Assign Exchange Online Licenses
```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Assign license (example)
Set-MgUserLicense -UserId "jsmith@contoso.com" -AddLicenses @{SkuId="<License-SKU-ID>"} -RemoveLicenses @()
```

### 5. Verify Mailbox Provisioning
```powershell
Connect-ExchangeOnline

# Check if mailbox exists
Get-Mailbox -Identity "jsmith@contoso.com"

# May take 30-60 minutes for mailbox to provision
```

### 6. Test Mail Flow
Send test email to verify mailbox is functioning correctly.

## When to Use This Script

### Required Scenarios
- **Decommissioning on-premises Exchange** after full migration to Exchange Online
- **Moving to Exchange Online without hybrid** configuration
- **Fixing orphaned Exchange attributes** from previous failed migrations
- **Preparing users for cloud-only mailboxes** after data migration
- **Resolving "mailbox already exists"** errors in Exchange Online

### Not Recommended For
- **Active hybrid Exchange environments** - use proper migration tools instead
- **Users with active on-premises mailboxes** - migrate data first
- **Environments with Exchange Online Hybrid** - use New-MoveRequest
- **Production without testing** - always test with -WhatIf first

## Important Warnings

⚠️ **Data Loss Prevention**:
- Always backup before running (script does this automatically)
- Test with `-WhatIf` first
- Verify backup file was created successfully
- This disconnects users from on-premises Exchange mailboxes

⚠️ **Prerequisites**:
- Ensure all mailbox data has been migrated to Exchange Online
- Verify users have appropriate Exchange Online licenses
- Confirm Azure AD Connect is functioning properly (if hybrid)

⚠️ **Cannot Be Undone Without Backup**:
- Once attributes are cleared, on-premises mailbox link is permanently broken
- Use `-RestoreFromBackup` to rollback if needed
- Keep backup files in secure location

## Related Scripts
- [Get-ComprehensiveADReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveADReport) - Assess AD environment before migration
- [Get-MailboxPermissionsReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-MailboxPermissionsReport) - Document mailbox permissions
- [New-Office365Accounts.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/New-Office365Accounts) - Create Exchange Online mailboxes

## Version History
- **v1.0** (2026-02-02): Initial release
  - Core functionality for removing Exchange attributes
  - Backup and restore capabilities
  - Support for single user, OU, and bulk CSV processing
  - WhatIf support and comprehensive error handling
  - Improved attribute detection for accurate removal

## See Also
- [Microsoft: Decommission on-premises Exchange servers](https://docs.microsoft.com/en-us/exchange/decommission-on-premises-exchange)
- [Microsoft: Exchange Online mailbox migration](https://docs.microsoft.com/en-us/exchange/mailbox-migration/mailbox-migration)
- [Azure AD Connect sync](https://docs.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-sync-whatis)
