# Get-MailboxPermissionsReport.ps1

Comprehensive mailbox delegation and permissions audit tool for Exchange Online. Generates detailed reports of Full Access, Send As, Send on Behalf, and folder-level permissions across all mailboxes.

## 📍 Location
`scripts/Assessment/Office365/Get-MailboxPermissionsReport.ps1`

## 🎯 Purpose

Identifies and documents all mailbox delegations and permissions within an Exchange Online environment. Essential for:
- **Security audits** - Identify excessive or unauthorized access
- **Compliance reviews** - Document access patterns for auditors
- **User offboarding** - Review and remove delegated access
- **Shared mailbox management** - Track who has access to shared resources
- **Permission cleanup** - Identify orphaned or unnecessary permissions

## ✨ Features

### Permission Types Collected
- ✅ **Full Access** - Users who can open and read another user's mailbox
- ✅ **Send As** - Users who can send emails appearing from another mailbox
- ✅ **Send on Behalf** - Users who can send emails on behalf of another user
- ✅ **Inbox Permissions** - Folder-level access to Inbox
- ✅ **Calendar Permissions** - Folder-level access to Calendar

### Advanced Capabilities
- Multiple delegation handling (stacked rows for multiple delegates)
- Display name resolution for all identities
- Forwarding configuration detection
- Mailbox type filtering (User/Shared/All)
- CSV import for targeted user audits
- ZIP archive with summary statistics
- Automatic Explorer integration

## 📋 Parameters

### `-MailboxFilter`
Filter mailboxes by type.

**Values:**
- `All` - All mailboxes (default)
- `UserMailboxes` - User mailboxes only
- `SharedMailboxes` - Shared mailboxes only

**Example:**
```powershell
.\Get-MailboxPermissionsReport.ps1 -MailboxFilter SharedMailboxes
```

### `-UserPrincipalName`
Audit specific users by UPN.

**Type:** String array  
**Example:**
```powershell
.\Get-MailboxPermissionsReport.ps1 -UserPrincipalName "user1@contoso.com","user2@contoso.com"
```

### `-CsvFilePath`
Import users from CSV file.

**CSV Format:** Single column with header `UserPrincipalName`
```csv
UserPrincipalName
user1@contoso.com
user2@contoso.com
```

**Example:**
```powershell
.\Get-MailboxPermissionsReport.ps1 -CsvFilePath "C:\users.csv"
```

### `-IncludeFolderPermissions`
Include Inbox and Calendar folder-level permissions.

**Type:** Boolean  
**Default:** `$true`  
**Note:** Disabling improves performance significantly

**Example:**
```powershell
# Skip folder permissions for faster execution
.\Get-MailboxPermissionsReport.ps1 -IncludeFolderPermissions:$false
```

### `-ResolveDisplayNames`
Resolve user identities to display names.

**Type:** Boolean  
**Default:** `$true`  

**Example:**
```powershell
.\Get-MailboxPermissionsReport.ps1 -ResolveDisplayNames:$false
```

### `-CreateZip`
Create ZIP archive of output files.

**Type:** Boolean  
**Default:** `$true`  

**Example:**
```powershell
.\Get-MailboxPermissionsReport.ps1 -CreateZip:$false
```

## 🚀 Usage Examples

### Example 1: Audit All Mailboxes
Complete permissions audit of entire organization.

```powershell
.\Get-MailboxPermissionsReport.ps1
```

**Use Case:** Annual security audit, comprehensive review

---

### Example 2: Shared Mailbox Permissions
Focus on shared mailbox delegations.

```powershell
.\Get-MailboxPermissionsReport.ps1 -MailboxFilter SharedMailboxes
```

**Use Case:** Shared mailbox cleanup, department resource review

---

### Example 3: Specific User Audit
Audit permissions for specific users.

```powershell
.\Get-MailboxPermissionsReport.ps1 -UserPrincipalName "ceo@contoso.com","cfo@contoso.com"
```

**Use Case:** Executive mailbox review, high-value target audit

---

### Example 4: Fast Audit (No Folder Permissions)
Quick audit without folder-level permissions.

```powershell
.\Get-MailboxPermissionsReport.ps1 -IncludeFolderPermissions:$false
```

**Use Case:** Large environments (1000+ mailboxes), quick overview needed

---

### Example 5: CSV Import
Audit users from CSV file.

```powershell
.\Get-MailboxPermissionsReport.ps1 -CsvFilePath "C:\Audit\executives.csv"
```

**Use Case:** Department-specific audit, pre-defined user list

---

### Example 6: User Mailboxes Only
Exclude shared mailboxes and room resources.

```powershell
.\Get-MailboxPermissionsReport.ps1 -MailboxFilter UserMailboxes
```

**Use Case:** User-to-user delegation review, cross-user access audit

---

## 📊 Output Files

### MailboxPermissions_[timestamp].csv
Primary permissions report with columns:

| Column | Description |
|--------|-------------|
| Display Name | Mailbox owner display name |
| Email | Mailbox email address |
| Mailbox Type | UserMailbox, SharedMailbox, RoomMailbox, etc. |
| Forwarding Address | Email forwarding destination (if configured) |
| Full Access | Users with full mailbox access (semicolon-separated) |
| Send As | Users with Send As permission (semicolon-separated) |
| Send on Behalf | Users with Send on Behalf permission (semicolon-separated) |
| Inbox User | User with Inbox folder access |
| Inbox Permission | Permission level (Reviewer, Editor, etc.) |
| Inbox Delegated | Whether Inbox delegation is configured |
| Calendar User | User with Calendar folder access |
| Calendar Permission | Permission level |
| Calendar Delegated | Whether Calendar delegation is configured |

**Note:** Multiple permissions create stacked rows for the same mailbox.

### Summary.txt
Statistical overview including:
- Total mailboxes audited
- Mailboxes with Full Access permissions
- Mailboxes with Send As permissions
- Mailboxes with Send on Behalf permissions
- Mailboxes with folder-level permissions
- Mailboxes with email forwarding
- Execution time

### MailboxPermissions_[timestamp].zip
Compressed archive containing all output files.

---

## 📈 Report Analysis

### Finding Excessive Permissions
```powershell
# Import and analyze
$report = Import-Csv "MailboxPermissions_20251223_140000.csv"

# Find mailboxes with many Full Access delegates
$report | Where-Object { $_.'Full Access' -match ';.*;' } | 
    Select-Object 'Display Name', 'Full Access'

# Find users with access to multiple mailboxes
$report | Group-Object 'Full Access' | 
    Where-Object { $_.Count -gt 5 } | 
    Sort-Object Count -Descending
```

### Identify Forwarding Configurations
```powershell
$report = Import-Csv "MailboxPermissions_20251223_140000.csv"

# All forwarding configurations
$report | Where-Object { $_.'Forwarding Address' } | 
    Select-Object 'Display Name', 'Forwarding Address'
```

### Shared Mailbox Access Review
```powershell
$report = Import-Csv "MailboxPermissions_20251223_140000.csv"

# Shared mailboxes with multiple delegates
$report | Where-Object { $_.'Mailbox Type' -eq 'SharedMailbox' } |
    Where-Object { $_.'Full Access' } |
    Select-Object 'Display Name', 'Email', 'Full Access'
```

---

## ⚡ Performance

### Execution Times (Approximate)

| Mailbox Count | With Folder Permissions | Without Folder Permissions |
|---------------|------------------------|---------------------------|
| 10 mailboxes | 30 seconds | 10 seconds |
| 50 mailboxes | 3-5 minutes | 1 minute |
| 100 mailboxes | 7-10 minutes | 2-3 minutes |
| 500 mailboxes | 40-60 minutes | 10-15 minutes |
| 1000+ mailboxes | 90+ minutes | 20-30 minutes |

### Performance Optimization

**For Large Environments:**
1. Disable folder permissions: `-IncludeFolderPermissions:$false`
2. Use targeted audits with `-UserPrincipalName` or `-CsvFilePath`
3. Filter by mailbox type: `-MailboxFilter SharedMailboxes`
4. Run during off-peak hours
5. Use dedicated admin workstation with stable connection

**Folder Permission Impact:**
- Processing time increases 3-5x when enabled
- Each mailbox requires 2 additional API calls (Inbox + Calendar)
- Network latency significantly impacts execution time

---

## 🔧 Requirements

### PowerShell Modules
- **ExchangeOnlineManagement** (v2.0.5 or later)

Auto-installed by script if missing.

### Permissions
Minimum required permissions:
- **View-Only Recipients** role
- **Exchange Administrator** role (recommended)
- **Global Reader** role (alternative)

### PowerShell Version
- PowerShell 5.1 or later
- PowerShell 7+ recommended

### Network Requirements
- Stable internet connection
- Access to Exchange Online endpoints
- Modern authentication enabled

---

## 🔍 Troubleshooting

### Connection Timeout
**Symptom:** Connection drops during execution  
**Solution:**
```powershell
# Use shorter timeout, run in batches
$users = Get-EXOMailbox -ResultSize 100
$users | ForEach-Object { 
    .\Get-MailboxPermissionsReport.ps1 -UserPrincipalName $_.UserPrincipalName -CreateZip:$false
}
```

### Module Not Found
**Symptom:** ExchangeOnlineManagement module not installed  
**Solution:**
```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force
```

### Permission Denied
**Symptom:** Unable to retrieve mailbox permissions  
**Solution:** Verify admin role assignment:
```powershell
# Check current role assignments
Get-ManagementRoleAssignment -RoleAssignee your@email.com
```

### Slow Execution
**Symptom:** Script takes too long  
**Solution:**
```powershell
# Disable folder permissions
.\Get-MailboxPermissionsReport.ps1 -IncludeFolderPermissions:$false

# Or target specific mailboxes
.\Get-MailboxPermissionsReport.ps1 -MailboxFilter SharedMailboxes
```

### Display Names Not Resolving
**Symptom:** Shows GUIDs instead of names  
**Solution:**
- Ensure account has directory read permissions
- Some accounts may be external/deleted (expected)
- External users show as GUIDs (by design)

---

## 🛡️ Security Considerations

### Sensitive Data
Reports contain:
- ✅ Email addresses
- ✅ User names
- ✅ Access relationships
- ✅ Forwarding destinations

**Best Practices:**
1. Store reports securely (encrypted drives)
2. Limit report access to authorized personnel
3. Delete reports after analysis
4. Do not email unencrypted reports
5. Review data classification policies before sharing

### Audit Trail
- Script execution leaves no audit trail in mailbox logs
- Uses read-only operations
- No modifications made to mailboxes
- Consider logging script execution for compliance

---

## 📋 Use Case Scenarios

### Security Audit
**Goal:** Identify potential security risks  
**Process:**
1. Run complete audit: `.\Get-MailboxPermissionsReport.ps1`
2. Review Full Access permissions for unexpected delegates
3. Identify external forwarding configurations
4. Check for orphaned permissions (deleted users)
5. Document findings for remediation

### User Offboarding
**Goal:** Remove all delegated access for departing user  
**Process:**
1. Audit user's mailbox: `.\Get-MailboxPermissionsReport.ps1 -UserPrincipalName "user@domain.com"`
2. Identify where user has delegated access to others
3. Find mailboxes where user is a delegate
4. Remove permissions as appropriate
5. Reassign shared mailbox access

### Compliance Review
**Goal:** Document access for auditors  
**Process:**
1. Run filtered audit: `.\Get-MailboxPermissionsReport.ps1 -MailboxFilter SharedMailboxes`
2. Generate timestamp-stamped report
3. Review for compliance violations
4. Document approved delegations
5. Archive report for audit trail

### Shared Mailbox Cleanup
**Goal:** Optimize shared mailbox delegations  
**Process:**
1. Audit shared mailboxes: `.\Get-MailboxPermissionsReport.ps1 -MailboxFilter SharedMailboxes`
2. Identify mailboxes with excessive delegates
3. Remove inactive user permissions
4. Document business justification for remaining access
5. Schedule periodic re-audits

---

## 🔄 Automation

### Scheduled Monthly Audit
```powershell
# Save as scheduled task script
$OutputPath = "C:\Reports\MailboxPermissions\$(Get-Date -Format 'yyyy-MM')"
New-Item -ItemType Directory -Path $OutputPath -Force

cd "C:\Scripts\Assessment\Office365"
.\Get-MailboxPermissionsReport.ps1

# Move output to monthly archive
Move-Item "MailboxPermissions_*.zip" $OutputPath
```

### PowerShell Script Integration
```powershell
# Run audit and import results
.\Get-MailboxPermissionsReport.ps1 -CreateZip:$false

# Get latest report
$latestReport = Get-ChildItem "MailboxPermissions_*.csv" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

# Import and analyze
$permissions = Import-Csv $latestReport

# Custom analysis
$sharedMailboxes = $permissions | 
    Where-Object { $_.'Mailbox Type' -eq 'SharedMailbox' } |
    Where-Object { $_.'Full Access' }

Write-Host "Found $($sharedMailboxes.Count) shared mailboxes with delegated access"
```

---

## 📚 Related Scripts

- **[Get-QuickO365Report.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-QuickO365Report)** - Complete O365 assessment including mailboxes, licenses, SharePoint
- **[Get-ComprehensiveO365Report.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveO365Report)** - Extended assessment with additional features

---

## 📝 Version History

- **v1.0** (2025-12-23) - Initial release
  - Full Access permission collection
  - Send As permission collection
  - Send on Behalf permission collection
  - Inbox folder permissions
  - Calendar folder permissions
  - Display name resolution
  - ZIP archive creation
  - Multiple mailbox type filters

---

## 🤝 Contributing

Found a bug or have a feature request? 
- GitHub Issues: [PowerShellEveryting Issues](https://github.com/Managed-Solution-LLC/PowerShellEveryting/issues)
- Pull Requests: Follow [Contributing Guidelines](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/docs/docs/CONTRIBUTING)

---

## 📖 Additional Resources

- [Exchange Online Permissions Documentation](https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-permissions-for-recipients)
- [Mailbox Folder Permissions](https://learn.microsoft.com/en-us/powershell/module/exchange/add-mailboxfolderpermission)
- [Exchange Online PowerShell](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell)

---

**Author:** W. Ford (Managed Solution LLC)  
**License:** See [LICENSE](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/docs/docs/LICENSE.md)  
**Last Updated:** December 23, 2025
