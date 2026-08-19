# Export-ADLyncTeamsMigrationData.ps1

## Overview
Exports comprehensive Active Directory user information for Lync/Skype for Business to Microsoft Teams migration analysis. This script captures critical user attributes, Lync-specific configuration, voice routing details, and Teams migration readiness indicators to facilitate smooth cloud migrations.

## Features
- Exports standard AD user information (Name, UPN, Email, Department, etc.)
- Captures Lync/SfB specific attributes (msRTCSIP-*, proxyAddresses)
- Retrieves corporate telephone numbers and extension information
- Extracts SIP addresses and voice routing attributes
- Identifies account status and organizational information
- Provides Teams migration readiness indicators
- Automatically detects available Lync schema attributes
- Flexible filtering options (enabled/disabled users, service accounts)
- CSV export for easy analysis in Excel or Power BI

## Prerequisites
- **PowerShell Version**: 5.1 or higher
- **Required Modules**: Active Directory PowerShell module (RSAT)
- **Required Permissions**: Read access to Active Directory user attributes
- **Network Requirements**: Domain controller access
- **Special Requirements**: Access to Lync/SfB specific AD attributes

## Parameters

### Optional Parameters
- **OutputDirectory**: Directory for exported CSV files
  - Type: String
  - Default: `C:\Reports\Teams_Migration_AD_Export`
  - Description: Path where CSV files will be saved

- **OrganizationName**: Organization name for reports
  - Type: String
  - Default: `"Organization"`
  - Description: Used in report headers and file naming

- **IncludeDisabledUsers**: Include disabled user accounts
  - Type: Switch
  - Default: False
  - Description: When specified, includes disabled AD accounts in export

- **IncludeServiceAccounts**: Include service accounts
  - Type: Switch
  - Default: False
  - Description: When specified, includes Lync device/service accounts

- **ExportToCsv**: Export results to CSV files
  - Type: Switch
  - Default: False
  - Description: Must be specified to create CSV output

- **SearchBase**: Specific OU to search
  - Type: String
  - Default: Entire domain
  - Description: Distinguished name of OU to limit search scope

- **MaxUsers**: Maximum number of users to process
  - Type: Integer
  - Default: 0 (unlimited)
  - Description: Limits export to first N users

- **SipUsersOnly**: Export only SIP-enabled users
  - Type: Switch
  - Default: False
  - Description: Filters to only Lync/SfB enabled users

## Usage Examples

### Example 1: Basic Export for Organization
```powershell
.\Export-ADLyncTeamsMigrationData.ps1 -OrganizationName "Contoso" -ExportToCsv
```
Exports all enabled users with Lync attributes for Contoso organization.

### Example 2: Export Only SIP-Enabled Users
```powershell
.\Export-ADLyncTeamsMigrationData.ps1 -OrganizationName "Fabrikam" -SipUsersOnly -ExportToCsv
```
Exports only users that have SIP addresses (Lync/SfB enabled users).

### Example 3: Comprehensive Export Including Disabled Accounts
```powershell
.\Export-ADLyncTeamsMigrationData.ps1 -OrganizationName "Contoso" -IncludeDisabledUsers -IncludeServiceAccounts -ExportToCsv
```
Exports all users including disabled accounts and service accounts.

### Example 4: Export from Specific OU
```powershell
.\Export-ADLyncTeamsMigrationData.ps1 -OrganizationName "Contoso" -SearchBase "OU=Users,DC=contoso,DC=com" -ExportToCsv
```
Limits export to users in a specific organizational unit.

### Example 5: Test Export with Limited Users
```powershell
.\Export-ADLyncTeamsMigrationData.ps1 -OrganizationName "Contoso" -MaxUsers 100 -ExportToCsv
```
Exports only the first 100 users for testing purposes.

## Output

### CSV Export
The script exports detailed user data with the following columns:

**Standard User Attributes**:
- DisplayName, GivenName, Surname
- SamAccountName, UserPrincipalName
- EmailAddress, Mail, MailNickname
- Enabled, Department, Title, Office, Company
- Manager, WhenCreated, WhenChanged, LastLogonDate

**Telephone Attributes**:
- TelephoneNumber, HomePhone, MobilePhone
- Fax, IPPhone, OtherTelephone

**Lync/SfB Specific Attributes** (when available):
- msRTCSIP-UserEnabled
- msRTCSIP-PrimaryUserAddress (SIP address)
- msRTCSIP-PrimaryHomeServer
- msRTCSIP-EnterpriseVoiceEnabled
- msRTCSIP-LineURI (phone number)
- msRTCSIP-FederationEnabled
- msRTCSIP-InternetAccessEnabled
- msRTCSIP-DeploymentLocator (for hybrid)
- ProxyAddresses (includes SIP addresses)

### Output File Locations
Default: `C:\Reports\Teams_Migration_AD_Export\`

### Output File Naming
Pattern: `AD_Lync_Teams_Migration_{OrganizationName}_{YYYYMMDD_HHmmss}.csv`

Example: `AD_Lync_Teams_Migration_Contoso_20251223_143052.csv`

### Console Output
The script provides color-coded status messages:
- ✅ Green: Successful operations and attribute availability
- ⚠️ Yellow: Warnings and unavailable attributes
- ❌ Red: Errors and failures
- 🔍 Cyan: Processing information

## Common Issues & Troubleshooting

### Issue: Active Directory Module Not Found
**Solution**: Install Remote Server Administration Tools (RSAT):
```powershell
# Windows 10/11
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Or install from PowerShell Gallery
Install-Module -Name ActiveDirectory -Scope CurrentUser
```
Alternatively, run the script from a domain controller.

### Issue: Lync Attributes Not Available
**Error**: "⚠️ msRTCSIP-UserEnabled - Not available or accessible"

**Solution**: This is expected if:
- Lync/SfB schema extensions were never applied
- Your account lacks read permissions to Lync attributes
- Searching a non-Lync enabled domain

The script will continue with available attributes only.

### Issue: Access Denied Errors
**Solution**: Ensure your account has:
- Read permissions to Active Directory
- Permissions to query extended attributes
- Access to the specified SearchBase OU

Run as a domain admin or request delegated permissions.

### Issue: CSV Export Path Not Writable
**Solution**: Ensure the output directory exists and you have write permissions:
```powershell
# Test write access
Test-Path "C:\Reports\Teams_Migration_AD_Export\" -PathType Container
```

### Issue: Too Many Users Returned
**Solution**: Use filters to narrow results:
```powershell
# Limit by OU
-SearchBase "OU=Corporate,DC=contoso,DC=com"

# Limit by count for testing
-MaxUsers 100

# Exclude disabled users
# (Default behavior - don't use -IncludeDisabledUsers)
```

## Migration Analysis Use Cases

### Pre-Migration Assessment
Use this export to:
1. Identify all Lync/SfB enabled users
2. Validate SIP address formatting
3. Check voice enablement status
4. Verify phone number (LineURI) assignments
5. Identify users missing required attributes

### Cleanup Planning
Export helps identify:
- Users with malformed SIP addresses
- Duplicate phone number assignments
- Users missing required telephone attributes
- Service accounts needing special handling
- Disabled accounts that can be removed

### Voice Routing Preparation
Use exported data to:
- Map existing LineURIs to Teams phone numbers
- Plan Direct Routing number assignments
- Identify extension patterns for auto-attendants
- Validate E.164 formatting compliance

### Hybrid Configuration
For hybrid deployments:
- Verify msRTCSIP-DeploymentLocator values
- Identify users ready for cloud migration
- Plan phased migration batches
- Validate federation settings

## Related Scripts
- [Start-LyncCsvExporter.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Start-LyncCsvExporter) - Interactive Lync data export tool
- [Get-ComprehensiveLyncReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveLyncReport) - Complete environment assessment
- Get-TeamsUserInventory.ps1 - Post-migration Teams user analysis

## Version History
- **v1.0** (2025-09-24): Initial release
  - Core AD export functionality
  - Lync attribute detection
  - Flexible filtering options
  - CSV export with UTF8 encoding

## See Also
- [Plan for Skype for Business to Teams Upgrade](https://docs.microsoft.com/en-us/microsoftteams/upgrade-start-here)
- [Active Directory Schema for Lync Server](https://docs.microsoft.com/en-us/skypeforbusiness/schema-reference/active-directory-schema-extensions-classes-and-attributes)
- [Teams Migration Guide](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Office365-Quick-Start)
