# Get-ComprehensiveADReport

## Overview
Comprehensive Active Directory assessment script designed for AD to AD migration planning. Exports all user accounts, groups, organizational units, and key attributes needed to match users across source and target AD environments.

This script is essential for migration planning, providing complete datasets that enable accurate user matching, group membership migration, and privilege account identification.

## Features
- **Complete User Export** - All user attributes including identifiers, organizational info, contact details, and account status
- **User Matching Attributes** - Exports EmployeeID, email, UPN, and samAccountName for cross-environment matching
- **Group Analysis** - All security and distribution groups with member counts and nested group analysis
- **Group Memberships** - Complete user-to-group mapping for migration planning
- **OU Structure** - Organizational unit hierarchy with user/computer distribution
- **Privileged Accounts** - Identifies users in administrative groups requiring special handling
- **Computer Objects** - Optional computer inventory with OS details (use `-IncludeComputers` switch)
- **Migration Recommendations** - Analyzes data quality and suggests matching strategies
- **Executive Summary** - Text report with statistics, analysis, and next steps

## Prerequisites
- **PowerShell**: 5.1 or later
- **Required Modules**: 
  - ActiveDirectory (RSAT Tools or Domain Controller)
- **Permissions**: 
  - Domain user with read access to Active Directory
  - For comprehensive data, Domain Admin or equivalent recommended
- **Environment**: 
  - Run on Domain Controller or workstation with RSAT installed
  - Network connectivity to domain controllers

## Parameters

### Required Parameters
None - script uses sensible defaults and can run without parameters.

### Optional Parameters

- **OutputDirectory**: Directory for assessment reports
  - Default: `C:\Reports\AD_Assessment`
  - Automatically created if doesn't exist
  - Example: `-OutputDirectory "C:\Migration\SourceAD"`

- **Domain**: Target domain FQDN to query
  - Overrides default domain context
  - Essential for querying different domains or forests
  - Example: `-Domain "contoso.com"`
  - **Note**: All AD queries will target this domain explicitly

- **DomainController**: Specific domain controller to query
  - If not specified, uses default DC
  - Can be combined with `-Domain` parameter
  - Example: `-DomainController "DC01.contoso.com"`

- **Credential**: Credentials for cross-forest/domain authentication
  - Use when querying different forest requiring separate authentication
  - PSCredential object (prompt with Get-Credential)
  - Example: `-Credential (Get-Credential)`
  - Commonly used with `-Domain` for cross-forest scenarios

- **IncludeDisabledUsers**: Include disabled user accounts in export
  - Default: Exports enabled users only
  - Example: `-IncludeDisabledUsers`

- **IncludeComputers**: Include computer objects in assessment
  - Exports computer inventory with OS details
  - Example: `-IncludeComputers`

- **IncludeGroupDetails**: Include detailed group analysis
  - Analyzes nested group memberships
  - Example: `-IncludeGroupDetails`

- **SearchBase**: Limit assessment to specific OU
  - Restricts scope to DN provided
  - Example: `-SearchBase "OU=Corporate,DC=contoso,DC=com"`

- **OrganizationName**: Organization name for report headers
  - Default: "Organization"
  - Example: `-OrganizationName "Contoso"`

## Usage Examples

### Example 1: Basic Assessment (Enabled Users Only)
```powershell
.\Get-ComprehensiveADReport.ps1
```
Runs assessment with default settings, exports enabled users and groups to `C:\Reports\AD_Assessment`.

### Example 2: Complete Assessment with All Users and Computers
```powershell
.\Get-ComprehensiveADReport.ps1 -OutputDirectory "C:\Migration\SourceAD" -IncludeDisabledUsers -IncludeComputers
```
Full assessment including disabled users and computers, saves to custom directory for migration planning.

### Example 3: Specific OU Assessment
```powershell
.\Get-ComprehensiveADReport.ps1 -SearchBase "OU=Corporate,DC=contoso,DC=com" -OrganizationName "Contoso"
```
Limits assessment to Corporate OU only, sets organization name for reports.

### Example 4: Target Specific DC with Detailed Groups
```powershell
.\Get-ComprehensiveADReport.ps1 -DomainController "DC01.contoso.com" -IncludeGroupDetails
```
Queries specific domain controller with detailed nested group analysis.

### Example 5: Pre-Migration Source AD Assessment
```powershell
.\Get-ComprehensiveADReport.ps1 -OutputDirectory "C:\ADMigration\Source" -IncludeDisabledUsers -IncludeComputers -OrganizationName "SourceOrg"
```
Complete source AD assessment for migration, includes all users, computers, and custom organization name.

### Example 6: Post-Migration Target AD Assessment
```powershell
.\Get-ComprehensiveADReport.ps1 -OutputDirectory "C:\ADMigration\Target" -OrganizationName "TargetOrg"
```
Target AD assessment to compare with source data for migration validation.

### Example 7: Query Different Domain
```powershell
.\Get-ComprehensiveADReport.ps1 -Domain "contoso.com" -OrganizationName "Contoso"
```
Query a specific domain by FQDN, useful when assessing multiple domains from single workstation.

### Example 8: Cross-Forest Assessment
```powershell
$Cred = Get-Credential
.\Get-ComprehensiveADReport.ps1 -Domain "partnerdomain.com" -Credential $Cred -OutputDirectory "C:\Migration\PartnerAD"
```
Assess AD in different forest requiring separate credentials. Prompts for credentials, then queries target domain.

## Output

### Output File Locations
Default: `C:\Reports\AD_Assessment` (or specify with `-OutputDirectory`)

### Output Files Generated

1. **AD_Users_Full_{timestamp}.csv**
   - Complete user export with 50+ attributes
   - Key columns for matching: SamAccountName, UserPrincipalName, EmailAddress, EmployeeID
   - Account status: Enabled, LockedOut, PasswordExpired, LastLogonDate
   - Organizational: Department, Title, Company, Manager
   - Contact: TelephoneNumber, Mobile, Address fields
   - Group memberships: Semi-colon delimited list

2. **AD_Groups_Summary_{timestamp}.csv**
   - All security and distribution groups
   - Columns: Name, GroupCategory, GroupScope, MemberCount, Description
   - Member breakdown: UserMembers, GroupMembers, ComputerMembers

3. **AD_GroupMemberships_{timestamp}.csv**
   - User-to-group mapping table
   - Columns: UserSamAccountName, UserUPN, GroupSamAccountName, GroupName
   - Essential for replicating group memberships in target AD

4. **AD_OUs_Structure_{timestamp}.csv**
   - Organizational unit hierarchy
   - Columns: Name, DistinguishedName, UserCount, ComputerCount, GroupCount
   - Use for planning target OU structure

5. **AD_Computers_{timestamp}.csv** (if `-IncludeComputers` used)
   - Computer inventory
   - Columns: Name, DNSHostName, OperatingSystem, IPv4Address, Enabled, LastLogonDate
   - OS breakdown for planning

6. **AD_PrivilegedAccounts_{timestamp}.csv**
   - Users in administrative groups
   - Groups monitored: Domain Admins, Enterprise Admins, Schema Admins, etc.
   - Columns: UserSamAccountName, UserName, PrivilegedGroup
   - **CRITICAL**: Review for special migration handling

7. **AD_Assessment_Report_{timestamp}.txt**
   - Executive summary with statistics
   - Domain information and functional levels
   - User/group/OU counts and analysis
   - Migration recommendations based on data quality
   - Suggested matching strategies
   - Next steps for migration

### Output File Naming
Pattern: `{Category}_{Type}_{YYYYMMDD_HHmmss}.{ext}`

Example: `AD_Users_Full_20260107_143052.csv`

## User Matching for AD Migration

### Primary Matching Attributes (in order)
1. **EmployeeID** - Most reliable if consistently populated in both environments
2. **EmailAddress** - Good fallback if EmployeeID not used
3. **UserPrincipalName** - Can work if UPN format consistent
4. **SamAccountName** - Last resort, may require manual validation

### Matching Strategy Workflow
1. Run script in **SOURCE** AD environment
2. Run script in **TARGET** AD environment  
3. Load both `AD_Users_Full_*.csv` files into Excel or PowerShell
4. Compare using chosen matching attribute:
   ```powershell
   $SourceUsers = Import-Csv "C:\Migration\Source\AD_Users_Full_20260107_143052.csv"
   $TargetUsers = Import-Csv "C:\Migration\Target\AD_Users_Full_20260107_150023.csv"
   
   # Match by EmployeeID
   $Matches = foreach ($SUser in $SourceUsers) {
       $TUser = $TargetUsers | Where-Object { $_.EmployeeID -eq $SUser.EmployeeID -and ![string]::IsNullOrWhiteSpace($_.EmployeeID) }
       if ($TUser) {
           [PSCustomObject]@{
               SourceSamAccountName = $SUser.SamAccountName
               TargetSamAccountName = $TUser.SamAccountName
               MatchedOn = "EmployeeID"
               EmployeeID = $SUser.EmployeeID
               SourceUPN = $SUser.UserPrincipalName
               TargetUPN = $TUser.UserPrincipalName
           }
       }
   }
   ```

5. Review non-matching users for manual mapping
6. Use `AD_GroupMemberships_*.csv` to plan group migration
7. Use `AD_PrivilegedAccounts_*.csv` to identify admin accounts needing special handling

### Data Quality Recommendations
The script analyzes your data and provides recommendations:
- If <80% of users have EmployeeID, consider using Email as primary match
- Review privileged accounts CSV before migration
- Validate OU structure mapping between environments

## Common Issues & Troubleshooting

### Issue: ActiveDirectory Module Not Found
**Symptoms**: "ActiveDirectory module not found" error

**Solution**: Install RSAT tools
```powershell
# Windows 10/11
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Windows Server
Install-WindowsFeature RSAT-AD-PowerShell
```

### Issue: Access Denied Errors
**Symptoms**: Permission errors when querying AD objects

**Solution**:
- Ensure you're logged in with domain credentials
- For full assessment, use Domain Admin or equivalent
- For read-only assessment, Domain User is sufficient
- Use `-DomainController` to target specific DC if permissions vary

### Issue: Large Dataset Performance
**Symptoms**: Script runs slowly with 10,000+ users

**Solution**:
- Use `-SearchBase` to limit scope to specific OUs
- Run during off-peak hours
- Target specific DC with `-DomainController` if some DCs are faster
- Consider breaking into multiple runs per OU

### Issue: Missing EmployeeID or Email Attributes
**Symptoms**: User matching difficult due to missing key attributes

**Solution**:
- Review the assessment report's "Matching Attribute Coverage" section
- If EmployeeID coverage low, use Email as primary match
- If both low, consider populating missing attributes before migration
- Use SamAccountName or DisplayName as last resort with manual validation

### Issue: Group Membership Export Takes Long Time
**Symptoms**: Group membership export phase slow with many groups

**Solution**:
- This is normal for large environments with complex group nesting
- Script processes each user's group memberships individually
- Consider using `-IncludeGroupDetails` only when needed for nested analysis
- Results are worth the wait for migration planning

### Issue: Querying Wrong Domain
**Symptoms**: Script returns data from current domain instead of specified domain

**Solution**:
- Use `-Domain` parameter with full FQDN: `-Domain "targetdomain.com"`
- Script explicitly passes domain to ALL AD cmdlets internally
- Verify with console output: "Connected to domain: targetdomain.com"
- For cross-forest scenarios, combine with `-Credential` parameter
- Ensure network connectivity to target domain controllers

### Issue: Privileged Accounts Analysis Incomplete
**Symptoms**: Some admin accounts not appearing in privileged accounts CSV

**Solution**:
- Script checks standard admin groups (Domain Admins, Enterprise Admins, etc.)
- Custom privileged groups may need manual review
- Review the full group memberships CSV for custom admin groups
- Consider adding custom group names to the script if needed repeatedly

## Migration Best Practices

### Pre-Migration Phase
1. **Run Assessment in Source AD** - Export all data with `-IncludeDisabledUsers` and `-IncludeComputers`
2. **Run Assessment in Target AD** - Compare structure and identify gaps
3. **Analyze Matching Quality** - Review EmployeeID and Email coverage percentages
4. **Document Custom Strategy** - Define how to handle non-matching users
5. **Review Privileged Accounts** - Plan manual migration for admin accounts

### Migration Planning
1. **Map OU Structures** - Use `AD_OUs_Structure_*.csv` to plan target OU creation
2. **Plan Group Recreation** - Use `AD_Groups_Summary_*.csv` to recreate groups in target
3. **Identify Dependencies** - Review group memberships for nested groups
4. **Test with Pilot** - Migrate subset of users first to validate matching

### Post-Migration Validation
1. **Run Assessment in Target AD** - After migration, export updated target state
2. **Compare Counts** - Validate user/group counts match expected
3. **Verify Memberships** - Compare group memberships before and after
4. **Audit Privileged Access** - Ensure admin accounts migrated correctly

## Related Scripts
- [Start-FileShareAssessment](Start-FileShareAssessment.md) - Assess file shares for migration
- Export-ADLyncTeamsMigrationData (Lync folder) - Export AD data with Lync attributes for Teams migration
- Check-PrivilegeRolestoPIM (Security folder) - Analyze privileged roles for PIM conversion

## Version History
- **v1.0** (2026-01-07): Initial release
  - Complete user, group, OU, and computer export
  - Privileged account identification
  - Migration recommendations
  - User matching attribute analysis
  - Executive summary reporting
  - Cross-domain querying with -Domain parameter
  - Cross-forest authentication with -Credential parameter
  - RSAT auto-install capability

## See Also
- [Microsoft AD Migration Documentation](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/plan/planning-domain-controller-placement)
- [Active Directory PowerShell Module](https://docs.microsoft.com/en-us/powershell/module/activedirectory/)
- [AD to AD Migration Guide](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/upgrade-domain-controllers)
