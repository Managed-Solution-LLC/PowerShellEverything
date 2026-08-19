# Get-MigrationWizLicensing

## Overview
Calculates BitTitan MigrationWiz license requirements and costs based on Microsoft 365 assessment data. The script analyzes user mailboxes, shared mailboxes, Teams sites, SharePoint libraries, OneDrive sites, and public folders to provide accurate license recommendations and cost estimates.

## Features
- **Smart License Selection**: Automatically chooses the most cost-effective license tier based on migration scope
- **Data-Driven Filtering**: Only licenses resources that contain actual data to migrate
- **Tiered Pricing**: Applies correct pricing tiers based on data size (e.g., 50GB vs 100GB SharePoint libraries)
- **Teams Site Detection**: Identifies genuine Teams sites with data vs empty M365 Group sites
- **Shared Mailbox Separation**: Distinguishes between user and shared mailboxes for accurate licensing
- **Professional Reports**: Generates formatted text reports with tables and cost breakdowns
- **Flexible Bundles**: Supports Mailbox ($14), User Migration Bundle ($17.50), and Tenant Migration Bundle ($57)

## Prerequisites
- **PowerShell**: 5.1 or later
- **ImportExcel Module**: Auto-installs if missing
- **Assessment Excel File**: Output from Get-QuickO365Report.ps1 or Get-ComprehensiveO365Report.ps1

### Required Excel Worksheets
The script expects an Excel file with these worksheets:
- **Mailboxes**: User and shared mailbox data with `MailboxType` and `TotalSizeGB` columns
- **OneDrive** (optional): OneDrive site data
- **Teams Sites** (optional): Teams data with `HasTeamsIntegration` and `StorageUsedGB` columns
- **SharePoint** (optional): SharePoint site data with `UsedGB` and `Template` columns
- **Public Folders** (optional): Public folder data with size information

## Parameters

### Required Parameters

#### `-InputExcelFile`
- **Type**: String
- **Description**: Path to the Microsoft 365 assessment Excel file
- **Validation**: File must exist
- **Example**: `"C:\Assessments\Contoso_Assessment.xlsx"`

### Optional Parameters

#### `-OutputDirectory`
- **Type**: String
- **Default**: `C:\Temp\MigrationWiz`
- **Description**: Directory where license calculation reports will be saved

#### `-OrganizationName`
- **Type**: String
- **Default**: `"Organization"`
- **Description**: Organization name displayed in the report header

#### `-IncludeArchives`
- **Type**: Switch
- **Description**: Include archive mailboxes in calculations (requires User Migration Bundle)

#### `-IncludeTeams`
- **Type**: Switch
- **Description**: Include Microsoft Teams sites in calculations

#### `-IncludeSharePoint`
- **Type**: Switch
- **Description**: Include SharePoint document libraries in calculations

#### `-IncludePublicFolders`
- **Type**: Switch
- **Description**: Include public folders in calculations

#### `-UseUserMigrationBundle`
- **Type**: Switch
- **Description**: Use User Migration Bundle ($17.50) instead of basic Mailbox license ($14)
- **Recommended**: For mailboxes >50GB or when OneDrive migration is needed

#### `-UseTenantMigrationBundle`
- **Type**: Switch
- **Description**: Use Tenant Migration Bundle ($57) for comprehensive migrations
- **Includes**: Mailbox + OneDrive + Archives + Teams/SharePoint (100GB)

## Usage Examples

### Example 1: Basic Mailbox-Only Migration
```powershell
.\Get-MigrationWizLicensing.ps1 -InputExcelFile "C:\Assessments\Contoso_Assessment.xlsx"
```
Calculates licensing for mailboxes only using the basic $14/user pricing.

### Example 2: User Migration Bundle with Organization Name
```powershell
.\Get-MigrationWizLicensing.ps1 `
    -InputExcelFile "C:\Assessments\Contoso_Assessment.xlsx" `
    -UseUserMigrationBundle `
    -OrganizationName "Contoso Corporation"
```
Uses User Migration Bundle ($17.50) for unlimited mailbox data and includes OneDrive.

### Example 3: Full Migration with Teams and SharePoint
```powershell
.\Get-MigrationWizLicensing.ps1 `
    -InputExcelFile "C:\Assessments\Assessment.xlsx" `
    -UseUserMigrationBundle `
    -IncludeTeams `
    -IncludeSharePoint `
    -OrganizationName "Fabrikam Inc"
```
Comprehensive migration including Teams sites and SharePoint libraries.

### Example 4: Complete Tenant Migration
```powershell
.\Get-MigrationWizLicensing.ps1 `
    -InputExcelFile "C:\Assessments\Assessment.xlsx" `
    -UseTenantMigrationBundle `
    -IncludeTeams `
    -IncludeSharePoint `
    -IncludeArchives `
    -IncludePublicFolders `
    -OutputDirectory "D:\Reports"
```
Full tenant migration with all workloads using Tenant Migration Bundle.

### Example 5: Custom Output Location
```powershell
.\Get-MigrationWizLicensing.ps1 `
    -InputExcelFile "C:\Assessments\Assessment.xlsx" `
    -UseUserMigrationBundle `
    -IncludeTeams `
    -OutputDirectory "C:\Reports\Licensing"
```
Saves report to custom directory location.

## Output

### Report File Naming
Pattern: `MigrationWiz_Licensing_{OrganizationName}_{YYYYMMDD_HHmmss}.txt`

Example: `MigrationWiz_Licensing_Contoso_20251223_161143.txt`

### Report Sections

#### 1. Migration Scope
Summary of discovered resources:
```
User Mailboxes:      69
Shared Mailboxes:    39
OneDrive Sites:      69
Teams Sites:         15 total
  (Licensed):        1 with data & Teams integration
SharePoint Sites:    20 total
  (M365 Groups):     15 (potential Teams sites)
  (Licensed):        4 with data
```

#### 2. License Requirements Table
Professional table showing license breakdown:
```
┌────────────────────────────────┬──────────┬─────────────┬──────────────┬──────────────┐
│ License Type                   │ Quantity │ Unit        │ Price/Unit   │ Subtotal     │
├────────────────────────────────┼──────────┼─────────────┼──────────────┼──────────────┤
│ User Migration Bundle          │       69 │ user        │        $17.5 │      $1207.5 │
│ Teams Collaboration            │        1 │ team        │          $48 │          $48 │
│ Shared Documents (50GB)        │        4 │ library     │          $25 │         $100 │
│ Mailbox (Shared)               │       39 │ shared mail │          $14 │         $546 │
├────────────────────────────────┴──────────┴─────────────┴──────────────┼──────────────┤
│ TOTAL ESTIMATED COST                                                   │ $    1,901.50│
└────────────────────────────────────────────────────────────────────────┴──────────────┘
```

#### 3. License Notes
Details about each license type's features and limitations.

#### 4. General Notes
- Pricing effective date
- Volume discount availability
- Educational/non-profit discounts
- PowerSyncPro requirements

#### 5. Recommendations
Context-aware suggestions based on migration scope.

## Licensing Logic

### Mailbox Licensing
- **User Mailboxes**: Excludes mailboxes with 0 GB data
- **Shared Mailboxes**: Always use basic Mailbox license ($14)
- **Bundle Selection**: 
  - Basic Mailbox ($14): Up to 50GB per mailbox
  - User Migration Bundle ($17.50): Unlimited data, includes OneDrive
  - Tenant Migration Bundle ($57): Includes Teams/SharePoint

### Teams Site Licensing
Only licenses Teams sites that meet **BOTH** criteria:
1. `HasTeamsIntegration = True` (actual Teams site, not just M365 Group)
2. `StorageUsedGB > 0` (contains data to migrate)

### SharePoint Licensing
- **50GB Tier ($25)**: Libraries with ≤50GB data
- **100GB Tier ($48)**: Libraries with >50GB data
- **Filtering**: Only licenses libraries with data (UsedGB > 0)
- **Detection**: Identifies M365 Group sites (GROUP#0 template)

### Public Folder Licensing
Priced at $114 per 10GB block (rounded up).

## Cost Optimization

The script automatically optimizes costs by:

1. **Excluding Empty Resources**
   - Mailboxes with 0 GB data
   - Teams sites without data or Teams integration
   - SharePoint libraries with no content

2. **Tiered Pricing**
   - Uses $25 license for SharePoint libraries under 50GB
   - Uses $48 license only for libraries over 50GB

3. **Smart Bundle Selection**
   - Recommends User Migration Bundle when OneDrive detected
   - Suggests Tenant Migration Bundle for Teams migrations

4. **Shared Mailbox Separation**
   - Licenses shared mailboxes separately at basic $14 rate
   - Doesn't apply expensive bundles to shared mailboxes

## Common Issues & Troubleshooting

### Issue: ImportExcel Module Not Found
**Error**: `ImportExcel module not installed`

**Solution**: The script auto-installs the module. If this fails:
```powershell
Install-Module ImportExcel -Scope CurrentUser -Force
```

### Issue: Worksheet Not Found
**Error**: `Worksheet 'Users' not found`

**Solution**: Ensure the Excel file is from Get-QuickO365Report.ps1 or contains the expected worksheet names:
- "Mailboxes" (not "Users")
- "Teams Sites" (not "Teams")
- "SharePoint"

### Issue: No Teams Sites Licensed
**Symptom**: Report shows "0 with data & Teams integration"

**Cause**: Teams sites either lack data or don't have Teams integration enabled

**Verification**: Check the "Teams Sites" worksheet for:
- `HasTeamsIntegration` column = True
- `StorageUsedGB` column > 0

### Issue: All SharePoint Libraries Show 0 Data
**Symptom**: "(Licensed): 0 with data"

**Cause**: Column name mismatch or all libraries are empty

**Solution**: Verify SharePoint worksheet has `UsedGB` column with numeric values

### Issue: Higher Cost Than Expected
**Symptom**: Total cost seems high

**Analysis Steps**:
1. Check if empty resources are being excluded (look for "Excluded" messages)
2. Verify correct bundle is selected (User vs Tenant)
3. Review SharePoint tier distribution (50GB vs 100GB)
4. Confirm Teams filtering is working (Teams integration + data)

## Pricing Reference

Current pricing as of 2025-12-23:

| License Type | Price | Notes |
|---|---|---|
| Mailbox | $14/user | Up to 50GB per mailbox |
| User Migration Bundle | $17.50/user | Unlimited mailbox + OneDrive + archives |
| Tenant Migration Bundle | $57/user | Full tenant including Teams/SharePoint (100GB) |
| Teams Collaboration | $48/team | Up to 100GB per team |
| Shared Documents (50GB) | $25/library | Up to 50GB per library |
| Shared Documents (100GB) | $48/library | Up to 100GB per library |
| Public Folders | $114/10GB | Per 10GB block |
| AD/Entra ID SMB | $6.25/user | ≤1000 users, 12 months |
| AD/Entra ID Enterprise | $8/user | 12 months |
| Migration Agent | $13.50/device | 12 months validity |

**Note**: Volume discounts and educational/non-profit pricing available through BitTitan sales.

## Performance Notes

- **Excel Reading**: Uses ImportExcel module for efficient data import
- **Memory Usage**: Processes large datasets in memory; tested with 1000+ mailboxes
- **Execution Time**: Typically completes in 5-15 seconds depending on Excel file size
- **Output Size**: Text reports are typically 2-5 KB

## Integration with Assessment Scripts

This script works seamlessly with:

### Get-QuickO365Report.ps1
```powershell
# Run assessment
.\Get-QuickO365Report.ps1 -OutputPath "C:\Assessments"

# Calculate licensing
.\Get-MigrationWizLicensing.ps1 `
    -InputExcelFile "C:\Assessments\O365_Assessment_20251223_134603.xlsx" `
    -UseUserMigrationBundle `
    -IncludeTeams `
    -IncludeSharePoint
```

### Get-ComprehensiveO365Report.ps1
Compatible with comprehensive assessment output as long as worksheet names match.

## Related Scripts
- [Get-QuickO365Report](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-QuickO365Report) - Quick O365 tenant assessment
- [Get-MailboxPermissionsReport](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-MailboxPermissionsReport) - Mailbox delegation analysis
- [Get-MailboxRules](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-MailboxRules) - Mailbox rule auditing

## Version History
- **v1.2** (2025-12-23): Added Teams site filtering, SharePoint tier pricing, empty mailbox exclusion, M365 Group detection, table format output
- **v1.1** (2025-12-23): Added shared mailbox distinction, SharePoint data filtering
- **v1.0** (2025-12-23): Initial release - Core functionality

## Additional Resources
- [BitTitan MigrationWiz Pricing](https://www.bittitan.com/pricing-bittitan-migrationwiz/)
- [BitTitan Sales Contact](https://www.bittitan.com/contactsales/)
- [BitTitan Store](https://store.bittitan.com/)

## See Also
- [Microsoft 365 Migration Best Practices](https://docs.microsoft.com/microsoft-365/enterprise/microsoft-365-migration-best-practices)
- [BitTitan MigrationWiz Documentation](https://www.bittitan.com/migrationwiz/)
