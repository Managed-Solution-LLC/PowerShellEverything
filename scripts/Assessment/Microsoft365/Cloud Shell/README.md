# Office 365 Assessment Scripts

Comprehensive tools for Office 365 tenant assessment, reporting, and capacity planning optimized for Azure Cloud Shell execution.

## Available Scripts

### 🚀 Get-QuickO365Report.ps1 (Recommended for Most Users)
**Simplified Cloud Shell assessment - just run and download**

- **Purpose**: Fast, automated Office 365 assessment
- **Collection**: Mailboxes, OneDrive, SharePoint
- **Time**: 5-20 minutes
- **Output**: Single ZIP file with CSV reports

```powershell
.\Get-QuickO365Report.ps1
```

**Best for**:
- Quick tenant assessments
- Capacity planning
- Storage analysis
- Users who want simplicity

### 📊 Get-ComprehensiveO365Report.ps1
**Full-featured assessment with advanced options**

- **Purpose**: Detailed Office 365 analysis with optional features
- **Collection**: Mailboxes, rules, OneDrive, SharePoint, archives
- **Time**: 15-120 minutes (depending on options)
- **Output**: Multiple CSVs + summary + ZIP file

```powershell
# Basic usage
.\Get-ComprehensiveO365Report.ps1

# With all features
.\Get-ComprehensiveO365Report.ps1 -IncludeArchives -IncludeMailboxRules
```

**Best for**:
- Compliance assessments
- Migration planning
- Security audits (inbox rules)
- Advanced reporting needs

## Quick Comparison

| Feature | Quick Script | Comprehensive Script |
|---------|--------------|---------------------|
| Mailbox sizes | ✅ | ✅ |
| OneDrive sites | ✅ | ✅ |
| SharePoint sites | ✅ | ✅ |
| Archive mailboxes | ❌ | ✅ (optional) |
| Inbox rules | ❌ | ✅ (optional) |
| Shared mailbox filtering | ❌ | ✅ (optional) |
| Parallel execution | ❌ | ✅ |
| Custom output location | ❌ | ✅ |
| Execution time (1000 mbx) | 10-15 min | 20-90 min |
| Lines of code | ~200 | ~900 |

## Getting Started

### Step 1: Open Azure Cloud Shell
1. Go to [https://shell.azure.com](https://shell.azure.com)
2. Select **PowerShell** mode
3. Authenticate with your Office 365 admin credentials

### Step 2: Upload Script
Click **Upload** button in Cloud Shell toolbar and select your script file.

Or use `git` if repository is available:
```powershell
git clone <repository-url>
cd PowerShellEveryting/scripts/Assessment/Office365
```

### Step 3: Run Script
```powershell
# For quick assessment
.\Get-QuickO365Report.ps1

# For comprehensive assessment
.\Get-ComprehensiveO365Report.ps1
```

### Step 4: Download Results
```powershell
# List available reports
ls cloudshell:\*.zip

# Download using Cloud Shell
download cloudshell:\O365Report_<timestamp>.zip
```

## Requirements

### Permissions
One of the following role assignments:
- **Global Administrator** (full access)
- **Exchange Administrator** + **SharePoint Administrator** (recommended)
- **Global Reader** (read-only access)

### Environment
- **Azure Cloud Shell** with PowerShell mode
- **PowerShell 5.1+** (included in Cloud Shell)
- **Internet connectivity** (Cloud Shell provides)

### Modules (Auto-Installed)
- `ExchangeOnlineManagement` (v3.0.0+)
- `Microsoft.Online.SharePoint.PowerShell` (v16.0.0+)

Scripts automatically install missing modules.

## Output Files

### All Scripts Generate:

#### Mailboxes.csv / MailboxSizes_*.csv
Mailbox statistics including:
- Display name and email address
- Mailbox type (User, Shared, Room, etc.)
- Size in GB and item count
- Quota and free space
- Last access time

#### OneDrive.csv / OneDriveSites_*.csv
OneDrive for Business sites:
- Owner and URL
- Storage used and quota
- Last modified date
- Status

#### SharePoint.csv / SharePointSites_*.csv
SharePoint site collections:
- Title, URL, and owner
- Template type
- Storage used and quota
- Sharing capability
- Status

#### Summary.txt / Summary_Report_*.txt
Executive summary including:
- Total counts and storage
- Average sizes
- Largest mailboxes/sites
- Error counts and warnings

#### *.zip
Compressed archive containing all reports for easy download.

### Comprehensive Script Additional Files:

#### MailboxRules_*.csv (if -IncludeMailboxRules)
Inbox rules for all mailboxes:
- Mailbox owner
- Rule name and description
- Forwarding/redirect addresses
- Actions (move, delete, mark read)

## Usage Examples

### Example 1: Quick Assessment
```powershell
# Simplest execution - auto-detects everything
.\Get-QuickO365Report.ps1

# Specify tenant explicitly
.\Get-QuickO365Report.ps1 -TenantDomain "contoso"
```

### Example 2: Mailbox Assessment with Archives
```powershell
.\Get-ComprehensiveO365Report.ps1 -IncludeArchives
```

### Example 3: Security Audit (Include Rules)
```powershell
# WARNING: Can take hours for large tenants
.\Get-ComprehensiveO365Report.ps1 -IncludeMailboxRules
```

### Example 4: Custom Output Location
```powershell
.\Get-ComprehensiveO365Report.ps1 -OutputDirectory "cloudshell:\CustomReports"
```

### Example 5: Storage-Only Assessment
```powershell
# Use Quick script for fastest storage analysis
.\Get-QuickO365Report.ps1
```

## Troubleshooting

### Common Issues

#### "Failed to connect to SharePoint"
**Cause**: Incorrect tenant domain or permissions

**Solution**:
```powershell
# Find your tenant domain
Get-OrganizationConfig | Select-Object Name, Identity

# Run with explicit domain
.\Get-QuickO365Report.ps1 -TenantDomain "yourtenant"
```

#### "Module installation failed"
**Cause**: Network issues or permission problems

**Solution**:
```powershell
# Manually install modules
Install-Module ExchangeOnlineManagement -Force -Scope CurrentUser
Install-Module Microsoft.Online.SharePoint.PowerShell -Force -Scope CurrentUser
```

#### Script runs slowly
**Cause**: Large tenant or including mailbox rules

**Solutions**:
- Use Quick script instead of Comprehensive
- Remove `-IncludeMailboxRules` flag
- Run during off-peak hours

#### Cloud Shell timeout
**Cause**: 20-minute idle timeout in Cloud Shell

**Solution**:
- Keep browser tab active
- For long operations, use comprehensive script with progress tracking
- Break large operations into smaller batches

## Performance Guidelines

### Expected Execution Times

| Mailboxes | Quick Script | Comprehensive | With Rules |
|-----------|-------------|---------------|------------|
| <100 | 2-5 min | 5-10 min | 15-30 min |
| 100-500 | 5-10 min | 15-30 min | 1-2 hours |
| 500-2000 | 10-20 min | 30-60 min | 2-5 hours |
| 2000+ | 20-40 min | 60-120 min | 5+ hours |

### Optimization Tips

1. **Start with Quick script** for initial assessment
2. **Skip rules** unless specifically needed for compliance
3. **Avoid archives** for capacity planning (primary mailbox data sufficient)
4. **Run during off-peak** for faster API responses
5. **Use verbose mode** only for troubleshooting

## Data Analysis

### Import into Excel
All CSV files can be opened directly in Excel:
1. Download ZIP file
2. Extract contents
3. Double-click CSV files

### Common Analysis Tasks

#### Find Mailboxes Near Quota
```powershell
# After importing CSV
Import-Csv .\Mailboxes.csv | 
    Where-Object { [double]$_.SizeGB / [double]$_.QuotaGB -gt 0.8 } |
    Sort-Object SizeGB -Descending
```

#### Calculate Total Storage Cost
```powershell
$mbData = Import-Csv .\Mailboxes.csv
$totalGB = ($mbData | Measure-Object -Property SizeGB -Sum).Sum
$costPerGB = 0.10  # Example: $0.10 per GB
Write-Host "Estimated monthly cost: $([Math]::Round($totalGB * $costPerGB, 2))"
```

#### Identify External Forwarding Rules
```powershell
Import-Csv .\MailboxRules.csv | 
    Where-Object { $_.ForwardTo -like "*@*" -and $_.ForwardTo -notlike "*@yourdomain.com" }
```

## Security Considerations

### Data Sensitivity
Reports contain:
- ✅ **Safe**: Mailbox sizes, quotas, site URLs
- ⚠️ **Moderate**: Email addresses, user names
- ❌ **Sensitive**: Forwarding rules (potential data exfiltration)

### Best Practices
1. **Delete reports** from Cloud Shell after downloading
2. **Store securely** on encrypted drives
3. **Limit access** to IT administrators only
4. **Follow retention policies** per organization guidelines
5. **Use Global Reader** role when possible (read-only)

### Safe for Production
Scripts are read-only and do not modify:
- ❌ No mailbox changes
- ❌ No rule modifications
- ❌ No site deletions
- ❌ No permission changes
- ✅ Safe to run in production

## Documentation

### Detailed Guides
- **[Office365-Assessment-Guide.md](../../docs/Office365-Assessment-Guide.md)**: Complete documentation for comprehensive script
- **[CONTRIBUTING.md](../../CONTRIBUTING.md)**: Guidelines for script modifications

### Related Scripts
- `scripts/Office365/.prep/Get-MailboxSizeReport.ps1`: Desktop version with interactive prompts
- `scripts/Office365/.prep/Get-MailboxRules.ps1`: Standalone rules collector
- `scripts/Office365/.prep/OneDriveSizeReportCSVUserList.ps1`: OneDrive with custom user lists

### Microsoft Documentation
- [Exchange Online PowerShell](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell-v2)
- [SharePoint Online PowerShell](https://learn.microsoft.com/en-us/powershell/sharepoint/sharepoint-online/connect-sharepoint-online)
- [Azure Cloud Shell](https://learn.microsoft.com/en-us/azure/cloud-shell/overview)

## Version History

### Version 1.0 (2025-12-17)
- Initial release of Quick and Comprehensive scripts
- Cloud Shell optimization
- Automatic ZIP creation
- Module auto-installation
- Comprehensive error handling

## Support

For issues, questions, or contributions:
1. Review troubleshooting section above
2. Check error messages and verbose output
3. Consult detailed documentation guides
4. Verify permissions and module versions

## License

See [LICENSE](../../LICENSE) file in repository root.

---

**Author**: W. Ford (Managed Solution LLC)  
**Last Updated**: 2025-12-17
