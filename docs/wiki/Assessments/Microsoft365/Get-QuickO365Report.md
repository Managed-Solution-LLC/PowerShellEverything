# Office 365 Assessment Scripts

Comprehensive Office 365 tenant assessment and reporting tools for mailboxes, OneDrive, SharePoint, Groups, Teams, and permissions.

## 🚀 Quick Start Scripts

### Get-QuickO365Report.ps1
**Recommended** - Complete Office 365 assessment with Excel output.

```powershell
.\Get-QuickO365Report.ps1 -TenantDomain "contoso"
```

**Collects:**
- ✅ Mailboxes with storage, quotas, archives, and **licenses**
- ✅ OneDrive sites with usage
- ✅ SharePoint sites with storage and **permissions**
- ✅ Microsoft 365 Groups with members
- ✅ Teams-connected sites
- ✅ License inventory and assignments

**Output:**
- **Excel workbook** with formatted tables (one tab per dataset)
- Individual CSV files for each data type
- License summary report
- ZIP archive of all files
- Executive summary

**Requirements:**
- ExchangeOnlineManagement module
- Microsoft.Online.SharePoint.PowerShell module
- MSOnline module (for licensing)
- ImportExcel module (auto-installed)

**Execution Time:** 5-20 minutes depending on tenant size

---


## 🎯 Common Use Cases

### Complete Tenant Assessment
```powershell
.\Get-QuickO365Report.ps1 -TenantDomain "contoso"
```
Generates comprehensive Excel workbook with all tenant data.

### Security Audit
```powershell

# Review SharePoint_Permissions.csv from quick report
.\Get-QuickO365Report.ps1
```

### Capacity Planning
```powershell
.\Get-QuickO365Report.ps1
# Review Mailboxes.csv for quota usage
# Review OneDrive.csv for storage trends
```

### License Optimization
```powershell
.\Get-QuickO365Report.ps1
# Review License_Summary.csv for available licenses
# Review Mailboxes.csv for user license assignments
```

---

## 📊 Output Files

### Get-QuickO365Report.ps1 Generates:
- **`O365_Assessment_[timestamp].xlsx`** - Complete Excel workbook
- `Mailboxes.csv` - All mailboxes with licenses, storage, quotas
- `License_Summary.csv` - Organization license inventory
- `OneDrive.csv` - OneDrive sites and usage
- `SharePoint.csv` - SharePoint sites and storage
- `SharePoint_Permissions.csv` - Site-level permissions
- `M365_Groups.csv` - Microsoft 365 Groups
- `Group_Memberships.csv` - Group member listings
- `Teams_Sites.csv` - Teams-connected sites
- `Summary.txt` - Executive summary with statistics
- `O365Report_[timestamp].zip` - Complete archive

---

## 🔧 Requirements

### PowerShell Modules
All scripts automatically check and install required modules:
- **ExchangeOnlineManagement** - Mailbox data
- **Microsoft.Online.SharePoint.PowerShell** - SharePoint/OneDrive/Groups
- **MSOnline** - License information
- **ImportExcel** - Excel workbook generation (optional)

### Permissions
- **Exchange Administrator** or **Global Reader** - For mailbox data
- **SharePoint Administrator** - For SharePoint/OneDrive/Groups data
- **Global Reader** - Recommended for read-only assessments

### PowerShell Version
- PowerShell 5.1 or later
- PowerShell 7+ recommended for best compatibility

---

## ⚡ Performance Tips

1. **Run during off-peak hours** for large tenants (500+ users)
2. **Fresh PowerShell session** recommended to avoid module conflicts
3. **Adequate permissions** - use Global Reader for complete data
4. **Stable connection** - Keep session active, avoid network interruptions

### Execution Times (Approximate)
- Small tenant (< 100 users): 5-10 minutes
- Medium tenant (100-500 users): 10-20 minutes
- Large tenant (500-1000 users): 20-40 minutes
- Enterprise (1000+ users): 40+ minutes

---

## 🔍 Troubleshooting

### Module Installation Fails
```powershell
# Run PowerShell as Administrator
Install-Module ExchangeOnlineManagement -Scope AllUsers -Force
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope AllUsers -Force
Install-Module MSOnline -Scope AllUsers -Force
```

### SharePoint Connection Fails (Assembly Conflict)
```powershell
# Exit and start fresh PowerShell session
exit
pwsh
cd "path\to\scripts"
.\Get-QuickO365Report.ps1 -TenantDomain "contoso"
```

### No Groups/Teams Found
- Verify SharePoint Administrator role
- Check if tenant has Microsoft 365 Groups enabled
- Review `GROUP#0` template availability in tenant

### Excel File Corruption Warning
- File opens successfully after "repair"
- Caused by complex data formatting
- All data is intact and readable
- Use CSV files if Excel issues persist

---

## 📚 Additional Documentation

- [Office 365 Assessment Scripts Wiki](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Office365-Assessment-Scripts)
- [Code Standards](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Code-Standards)
- [Contributing Guidelines](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/CONTRIBUTING)

---

## 🔐 Security & Compliance

- Scripts collect **read-only** data
- No modifications made to tenant
- Reports may contain **PII** - store securely
- Review data before sharing
- Delete reports after analysis if containing sensitive data

---

## 📝 Version History

- **v2.0** (2025-12-23) - Added licensing, Groups, Teams, permissions, Excel export
- **v1.1** (2025-12-17) - SharePoint Online Management Shell integration
- **v1.0** (2025-12-17) - Initial release

---

## 👥 Support

For issues, questions, or contributions:
- GitHub Issues: [PowerShellEveryting Issues](https://github.com/Managed-Solution-LLC/PowerShellEveryting/issues)
- Documentation: [Project Wiki](https://github.com/Managed-Solution-LLC/PowerShellEveryting/wiki)

---

**Author:** W. Ford (Managed Solution LLC)  
**License:** See [LICENSE](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/docs/docs/LICENSE.md) file
