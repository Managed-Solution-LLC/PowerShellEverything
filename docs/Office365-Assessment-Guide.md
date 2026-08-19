# Office 365 Comprehensive Assessment Guide

## Overview
The Office 365 Assessment script provides a complete tenant analysis optimized for Azure Cloud Shell execution. It collects mailbox statistics, inbox rules, OneDrive usage, and SharePoint site information, then packages everything into a downloadable ZIP file.

## Script Location
**Path**: `scripts/Assessment/Office365/Get-ComprehensiveO365Report.ps1`

## Features

### Data Collection
- **Mailbox Statistics**: Size, quotas, item counts, archive data
- **Mailbox Rules**: Inbox rules including forwarding/redirect rules
- **OneDrive Sites**: Personal OneDrive storage usage and quotas
- **SharePoint Sites**: Team sites, communication sites, and storage metrics

### Cloud Shell Optimizations
- **Non-interactive authentication**: Uses existing Cloud Shell session
- **Automatic module management**: Installs required modules if missing
- **Resource-aware execution**: Respects Cloud Shell memory/CPU limits
- **Automatic ZIP creation**: Packages all reports for easy download
- **Progress tracking**: Real-time status updates for long operations

### Output
- Individual CSV files for each data type
- Text-based summary report with key findings
- ZIP archive containing all reports
- Timestamp-based file naming for tracking

## Requirements

### Permissions Required
One of the following role assignments:
- **Global Administrator** (full access)
- **Exchange Administrator** + **SharePoint Administrator** (recommended)
- **Global Reader** (read-only alternative)

### Environment
- **Azure Cloud Shell** (PowerShell mode)
- **PowerShell 5.1+** (automatically available in Cloud Shell)
- **Modules** (auto-installed if missing):
  - ExchangeOnlineManagement (v3.0.0+)
  - Microsoft.Online.SharePoint.PowerShell (v16.0.0+)

## Usage

### Basic Execution
Open Azure Cloud Shell (PowerShell) and run:

```powershell
# Upload the script to Cloud Shell, then run:
.\Get-ComprehensiveO365Report.ps1
```

This performs a complete assessment with default settings:
- Collects all mailbox types (user, shared)
- Collects OneDrive and SharePoint statistics
- Skips archive mailboxes (faster execution)
- Skips inbox rules collection (faster execution)
- Creates reports in `cloudshell:\O365Reports_<timestamp>`

### Common Scenarios

#### Full Assessment with Archives
```powershell
.\Get-ComprehensiveO365Report.ps1 -IncludeArchives
```
Includes archive mailbox statistics in the mailbox size report.

#### Complete Assessment with Rules
```powershell
.\Get-ComprehensiveO365Report.ps1 -IncludeArchives -IncludeMailboxRules
```
**Warning**: Rules collection can take 5-10 seconds per mailbox. For 1000 mailboxes, expect 90+ minutes.

#### Specify Tenant Domain
```powershell
.\Get-ComprehensiveO365Report.ps1 -TenantDomain "contoso"
```
Manually specify SharePoint admin domain (contoso-admin.sharepoint.com). Auto-detected if omitted.

#### Custom Output Location
```powershell
.\Get-ComprehensiveO365Report.ps1 -OutputDirectory "cloudshell:\MyReports"
```
Save reports to a custom directory in Cloud Shell storage.

#### Exclude Shared Mailboxes
```powershell
.\Get-ComprehensiveO365Report.ps1
```
By default, shared mailboxes are included. Currently, filtering is manual (edit script to change filter).

### Advanced Options

#### Increase Parallelism
```powershell
.\Get-ComprehensiveO365Report.ps1 -MaxConcurrentJobs 5
```
Default is 3 to respect Cloud Shell resource limits. Increase cautiously.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `OutputDirectory` | String | `cloudshell:\O365Reports_<timestamp>` | Directory for report files |
| `IncludeArchives` | Switch | `$false` | Include archive mailbox statistics |
| `IncludeSharedMailboxes` | Switch | `$true` | Include shared mailboxes in report |
| `IncludeMailboxRules` | Switch | `$false` | Collect inbox rules (time-consuming) |
| `TenantDomain` | String | Auto-detected | SharePoint admin domain (e.g., "contoso") |
| `MaxConcurrentJobs` | Int | `3` | Maximum parallel collection jobs |

## Output Files

### Generated Reports

1. **MailboxSizes_\<timestamp\>.csv**
   - Columns: DisplayName, EmailAddress, MailboxType, TotalSizeGB, ItemCount, QuotaGB, etc.
   - One row per mailbox

2. **MailboxRules_\<timestamp\>.csv** (if `-IncludeMailboxRules`)
   - Columns: MailboxOwner, RuleName, Enabled, RedirectTo, ForwardTo, etc.
   - One row per inbox rule

3. **OneDriveSites_\<timestamp\>.csv**
   - Columns: Owner, Title, URL, UsedStorageGB, QuotaGB, LastContentModified, etc.
   - One row per OneDrive site

4. **SharePointSites_\<timestamp\>.csv**
   - Columns: Title, URL, Owner, Template, UsedStorageGB, Status, SharingCapability, etc.
   - One row per SharePoint site collection

5. **Summary_Report_\<timestamp\>.txt**
   - Text summary with aggregate statistics
   - Total counts, storage usage, largest mailboxes
   - Error/warning summary

6. **O365_Assessment_\<timestamp\>.zip**
   - Contains all CSV and TXT files above
   - Ready for download from Cloud Shell

## Downloading Reports

### Option 1: Cloud Shell Download Button
1. Navigate to the output directory: `cd cloudshell:\`
2. List files: `ls O365_Assessment_*.zip`
3. Click the **Download** button in Cloud Shell toolbar
4. Select the ZIP file

### Option 2: Download Command
```powershell
download cloudshell:\O365_Assessment_<timestamp>.zip
```

### Option 3: Azure Storage
Cloud Shell uses Azure Storage. Access files via:
- Azure Portal → Storage Account → File Shares → `.cloudconsole`

## Execution Time Estimates

| Scenario | Mailboxes | Expected Time |
|----------|-----------|---------------|
| Small tenant | <100 | 5-10 minutes |
| Medium tenant | 100-500 | 15-30 minutes |
| Large tenant | 500-2000 | 30-90 minutes |
| Large + Rules | 1000+ | 2-4 hours |

**Factors affecting speed**:
- Number of mailboxes
- Archive mailbox collection
- Inbox rules collection (slowest)
- SharePoint/OneDrive site count
- Network latency

## Troubleshooting

### Module Installation Fails
**Error**: `Failed to install ExchangeOnlineManagement`

**Solution**:
```powershell
# Manually install modules
Install-Module ExchangeOnlineManagement -Force -Scope CurrentUser
Install-Module Microsoft.Online.SharePoint.PowerShell -Force -Scope CurrentUser
```

### SharePoint Connection Fails
**Error**: `Failed to connect to SharePoint Online`

**Causes**:
- Incorrect tenant domain
- Missing SharePoint Administrator role
- Conditional Access blocking Cloud Shell

**Solution**:
```powershell
# Manually specify tenant domain
.\Get-ComprehensiveO365Report.ps1 -TenantDomain "yourtenant"

# Verify your tenant name
Get-OrganizationConfig | Select-Object Name, Identity
```

### Out of Memory in Cloud Shell
**Error**: Cloud Shell becomes unresponsive

**Solutions**:
- Restart Cloud Shell session
- Reduce `-MaxConcurrentJobs` to 1 or 2
- Skip `-IncludeMailboxRules` for large tenants
- Run script in smaller batches (modify to filter mailboxes)

### Authentication Errors
**Error**: `User authentication failed`

**Solution**: Cloud Shell should authenticate automatically. If issues persist:
```powershell
# Verify authentication
Get-AzContext

# Reconnect if needed
Disconnect-ExchangeOnline -Confirm:$false
# Re-run script
```

### Timeout Errors
**Error**: Long-running operations timeout

**Cloud Shell has 20-minute idle timeout**. Keep the browser tab active during long executions.

## Performance Tips

### For Large Tenants (1000+ Mailboxes)

1. **Skip inbox rules initially**
   ```powershell
   .\Get-ComprehensiveO365Report.ps1 -IncludeArchives
   ```

2. **Run rules collection separately** (if needed)
   - Edit script to add mailbox filtering
   - Process mailboxes in batches of 100-200

3. **Monitor progress**
   - Watch progress bars
   - Check error counts in real-time

4. **Use verbose output** for debugging
   ```powershell
   .\Get-ComprehensiveO365Report.ps1 -Verbose
   ```

## Security Considerations

### Data Sensitivity
Reports contain:
- User email addresses
- Mailbox sizes (potential PII indicator)
- SharePoint URLs (may reveal project names)
- Inbox rules (may show forwarding addresses)

**Recommendations**:
- Delete ZIP files after downloading
- Store reports securely
- Follow data retention policies
- Limit access to Global Administrators

### Permissions Scope
Script requires **read-only access**:
- No mailbox modifications
- No rule changes
- No site deletions
- Safe for production use

**Best Practice**: Use **Global Reader** role where possible instead of Global Administrator.

## Integration with Other Tools

### Import into Excel
```powershell
# All CSV files are Excel-compatible
# Double-click CSV files or use Excel import
```

### PowerBI Integration
```powershell
# Import CSV files into PowerBI
# Create dashboards for:
# - Storage trends
# - Mailbox growth
# - Rules analysis
```

### Compliance Analysis
Use MailboxRules CSV to identify:
- External forwarding rules
- Auto-delete rules
- Suspicious redirect rules

### Capacity Planning
Use size reports to:
- Project storage growth
- Identify mailboxes near quota
- Plan archive licensing

## Change Log

### Version 1.0 (2025-12-17)
- Initial release
- Cloud Shell optimized execution
- Mailbox, OneDrive, SharePoint collection
- Optional inbox rules collection
- Automatic ZIP archive creation
- Comprehensive error handling
- Summary report generation

## Related Scripts

- **scripts/Office365/.prep/Get-MailboxSizeReport.ps1**: Desktop version with interactive prompts
- **scripts/Office365/.prep/Get-MailboxRules.ps1**: Standalone rules collector
- **scripts/Office365/.prep/OneDriveSizeReportCSVUserList.ps1**: OneDrive collector with user list

## Support & Contributions

For issues or enhancements:
1. Check troubleshooting section
2. Review error messages in script output
3. Enable verbose mode for detailed logging
4. Refer to Microsoft documentation links in script header

## Additional Resources

- [Exchange Online PowerShell](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell-v2)
- [SharePoint Online PowerShell](https://learn.microsoft.com/en-us/powershell/sharepoint/sharepoint-online/connect-sharepoint-online)
- [Azure Cloud Shell Overview](https://learn.microsoft.com/en-us/azure/cloud-shell/overview)
- [Office 365 Permissions Reference](https://learn.microsoft.com/en-us/microsoft-365/admin/add-users/about-admin-roles)
