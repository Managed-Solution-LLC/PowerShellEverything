# Start-LyncCsvExporter.ps1

## Overview
Interactive menu-driven tool for exporting Lync/Skype for Business data to CSV files. This comprehensive exporter provides organized access to user data, phone/device inventory, infrastructure configuration, and voice policies through an easy-to-use menu interface.

## Features
- **Interactive Menu System**: User-friendly categorized export options
- **User Data Exports**: Summary, voice-enabled, SBA users, and complete user records
- **Phone/Device Inventory**: Common area phones, analog devices, USB devices
- **Infrastructure Exports**: Pools, policies, and configuration
- **Bulk Export Options**: Export all data types at once
- **CSV Format**: Excel and Power BI compatible exports
- **Timestamp-Based Naming**: Prevents file overwrites with automatic timestamps
- **Progress Indicators**: Real-time feedback during export operations
- **Error Handling**: Robust error reporting with color-coded messages

## Prerequisites
- **PowerShell Version**: 3.0 or higher
- **Required Environment**: Lync/Skype for Business Management Shell
- **Required Permissions**: 
  - Read access to Lync configuration
  - CsUserAdministrator or CsAdministrator role
- **Network Requirements**: Access to Lync Front End servers

## Parameters

### Optional Parameters
- **OutputDirectory**: Directory for CSV exports
  - Type: String
  - Default: `C:\Reports\CSV_Exports`
  - Description: All CSV files will be saved to this location

- **OrganizationName**: Organization name for reports
  - Type: String
  - Default: `"Organization"`
  - Description: Used in file naming and report headers

- **SBAPattern**: Pattern to identify SBA pools
  - Type: String
  - Default: `"*MSSBA*"`
  - Description: Wildcard pattern for Survivable Branch Appliance identification

## Usage Examples

### Example 1: Start with Default Settings
```powershell
.\Start-LyncCsvExporter.ps1
```
Launches the interactive menu with default output directory and organization name.

### Example 2: Specify Organization and Output Path
```powershell
.\Start-LyncCsvExporter.ps1 -OutputDirectory "D:\Lync_Reports" -OrganizationName "Contoso"
```
Sets custom output path and organization name for all exports.

### Example 3: Custom SBA Pattern
```powershell
.\Start-LyncCsvExporter.ps1 -OrganizationName "Fabrikam" -SBAPattern "*Branch*"
```
Uses custom pattern to identify branch office SBA pools.

## Interactive Menu Structure

### Main Menu Categories

#### 📊 User Exports
1. **Users - Summary**: Basic user information (name, SIP, pool, voice status)
2. **Users - Voice Enabled Only**: Enterprise Voice enabled users with routing details
3. **Users - SBA Users**: Users registered to Survivable Branch Appliances
4. **Users - Complete**: All available user attributes (comprehensive)

#### 📱 Phone/Device Inventory
5. **Common Area Phones**: Shared phones (lobbies, conference rooms)
6. **Analog Devices**: Fax machines, modems, overhead paging
7. **USB Devices**: USB-connected phones and headsets

#### 🏢 Infrastructure & Configuration
8. **Pools**: All Lync pools and their configuration
9. **Voice Policies**: Enterprise Voice policy definitions

#### 📦 Bulk Operations
10. **Export All User Types**: All user export types at once
11. **Export All Phone Inventory**: All device types in one operation
12. **Export Everything**: Complete data export (all categories)

#### ⚙️ Menu Options
- **[Q] Quit**: Exit the application

## Output

### CSV Export Details

#### User Exports

**Summary Export** includes:
- DisplayName, SIPAddress, UPN
- Enabled status
- Pool assignment
- VoiceEnabled (EnterpriseVoiceEnabled)
- LineURI (phone number)
- VoicePolicy

**Voice Users Export** includes:
- All summary fields plus:
- VoiceRoutingPolicy
- HostedVoiceMail status
- LocationPolicy

**SBA Users Export** includes:
- DisplayName, SIPAddress
- SchoolSite (extracted from pool name)
- SBAPool (full pool FQDN)
- VoiceEnabled, LineURI, VoicePolicy

**Complete User Export** includes:
- All standard user properties
- All policy assignments
- Federation settings
- Rich presence configuration
- Public network settings
- GUID, SID, Distinguished Name
- Timestamps (WhenCreated, WhenChanged)

#### Phone/Device Inventory Exports

**Common Area Phones** includes:
- DisplayName, LineURI
- SIPAddress, RegistrarPool
- Description, OU location

**Analog Devices** includes:
- DisplayName, LineURI
- Gateway assignment
- AnalogFax status
- SIPAddress, RegistrarPool

**USB Devices** includes:
- DisplayName, LineURI
- SIPAddress, RegistrarPool
- Policy assignments

#### Infrastructure Exports

**Pools Export** includes:
- Pool Identity (FQDN)
- Site assignment
- Services (Registrar, WebServices, etc.)
- Computer count

**Voice Policies Export** includes:
- Policy Identity and Description
- PSTN usage configurations
- Call forwarding settings
- Simultaneous ring settings

### Output File Locations
Default: `C:\Reports\CSV_Exports\`

The script creates this directory automatically if it doesn't exist.

### Output File Naming
Pattern: `Lync_{Category}_{Type}_{YYYYMMDD_HHmmss}.csv`

Examples:
- `Lync_Users_Summary_20251223_143052.csv`
- `Lync_Users_Voice_20251223_143105.csv`
- `Lync_CommonAreaPhones_20251223_143120.csv`
- `Lync_Pools_20251223_143135.csv`

### Console Output
Color-coded status messages:
- 🟢 Green: Successful exports with record counts
- 🟡 Yellow: Processing indicators
- 🔴 Red: Errors and failures
- 🔵 Cyan: Menu headers and section dividers

## Common Issues & Troubleshooting

### Issue: Lync Cmdlets Not Found
**Error**: "The term 'Get-CsUser' is not recognized..."

**Solution**: This script must be run from Lync/Skype for Business Management Shell:
1. Start Menu → Lync Server Management Shell (or Skype for Business Server Management Shell)
2. Navigate to script directory
3. Run the script

Alternatively, import the Lync module:
```powershell
Import-Module "C:\Program Files\Common Files\Skype for Business Server 2015\Modules\SkypeForBusiness\SkypeForBusiness.psd1"
```

### Issue: Access Denied
**Solution**: Ensure you have appropriate permissions:
- CsUserAdministrator role (minimum)
- CsAdministrator role (recommended)

Request role assignment from Lync administrators:
```powershell
# Admin runs this to grant access
Grant-CsUserAdministrator -Identity "DOMAIN\Username"
```

### Issue: Empty Exports (0 Records)
**Possible Causes**:
1. **No data exists**: Verify data with manual commands
   ```powershell
   Get-CsUser | Measure-Object
   Get-CsCommonAreaPhone | Measure-Object
   ```

2. **Incorrect SBA pattern**: Adjust the `-SBAPattern` parameter
   ```powershell
   # Check actual pool names
   Get-CsPool | Select-Object Identity
   ```

3. **Permissions issue**: Verify cmdlet access
   ```powershell
   Get-CsAdministratorRole | Where-Object {$_.Identity -match $env:USERNAME}
   ```

### Issue: CSV Opens with Garbled Characters
**Solution**: The CSV uses UTF8 encoding. In Excel:
1. Open Excel (don't double-click the CSV)
2. Data → From Text/CSV
3. File Origin: 65001 (UTF-8)
4. Click Load

Or use PowerShell to convert:
```powershell
Import-Csv "file.csv" -Encoding UTF8 | Export-Csv "file_fixed.csv" -NoTypeInformation
```

### Issue: Export Takes Too Long
**Solution**: For large environments (>10,000 users):
- Export specific categories instead of "Export Everything"
- Run during off-peak hours
- Consider using filters (e.g., SBA users only)

## Use Case Scenarios

### Pre-Migration Inventory
Before Teams migration:
1. Export "Users - Complete" for baseline inventory
2. Export all phone inventory for hardware tracking
3. Export voice policies for Teams policy mapping
4. Document pools for cloud connector planning

### Phone System Documentation
For voice infrastructure documentation:
1. Export "Common Area Phones" for shared device inventory
2. Export "Analog Devices" for gateway planning
3. Export "Voice Users" for extension directory
4. Export "Voice Policies" for dial plan mapping

### Branch Office Assessment
For SBA evaluation:
1. Export "Users - SBA Users" for branch user count
2. Identify school sites from pool names
3. Plan Teams survivability requirements
4. Document extension patterns

### Compliance & Audit
For compliance reporting:
1. Export "Users - Complete" for full user audit
2. Export "Pools" for infrastructure inventory
3. Regular exports for change tracking
4. Compare exports over time for drift analysis

### Decommissioning Planning
Before Lync decommissioning:
1. "Export Everything" for complete historical record
2. Validate all users migrated to Teams
3. Document remaining analog devices
4. Archive pool configurations

## Bulk Export Operations

### Export All User Types
Sequentially exports:
1. Users - Summary
2. Users - Voice Enabled
3. Users - SBA Users
4. Users - Complete

### Export All Phone Inventory
Sequentially exports:
1. Common Area Phones
2. Analog Devices
3. USB Devices

### Export Everything
Complete data export including:
1. All user types (4 exports)
2. All phone inventory (3 exports)
3. Pools
4. Voice Policies

**Total: 9 CSV files** with complete environment snapshot.

## Related Scripts
- [Export-ADLyncTeamsMigrationData.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Export-ADLyncTeamsMigrationData) - AD attribute export for migration
- [Get-ComprehensiveLyncReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveLyncReport) - Detailed text report
- [Get-LyncUserRegistrationReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncUserRegistrationReport) - User registration analysis

## Version History
- **v2.0** (2025-09-17): Phone inventory support
  - Added Common Area Phones export
  - Added Analog Devices export
  - Added USB Devices export
  - Enhanced menu structure
  - Updated bulk export operations
- **v1.0** (2024): Initial release
  - User export functionality
  - Infrastructure exports
  - Interactive menu system

## See Also
- [Lync Server Management Shell](https://docs.microsoft.com/en-us/skypeforbusiness/manage/management-shell)
- [Lync Server Cmdlet Reference](https://docs.microsoft.com/en-us/powershell/skype/)
- [Office365 Migration Guide](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Office365-Quick-Start)
