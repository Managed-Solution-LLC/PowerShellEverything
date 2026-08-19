# Get-LyncUserRegistrationReport.ps1

## Overview
Generates a detailed report of Lync user registrations and activity status. This reporting tool provides insights into user registration details, including last activity dates, registration status, pool distribution, and user activity patterns to help administrators monitor user connectivity and system usage.

## Features
- **User Registration Analysis**: Current registration status and details
- **Activity Tracking**: Last activity dates and patterns
- **Pool Distribution**: User distribution across registrar pools
- **Voice Enablement Statistics**: Enterprise Voice and voice policy analysis
- **SBA User Identification**: Branch office user tracking
- **Recent Modification Tracking**: Recently changed user accounts
- **Sample User Listings**: Detailed examples for verification
- **Registration Health Indicators**: Active vs. inactive user identification

## Prerequisites
- **PowerShell Version**: 3.0 or higher
- **Required Environment**: Lync/Skype for Business Management Shell
- **Required Permissions**: 
  - CsUserAdministrator or CsAdministrator role
  - Read access to Lync user configuration
- **Network Requirements**: Access to Lync Front End servers and registrar pools

## Parameters

### Optional Parameters
- **OrganizationName**: Organization name
  - Type: String
  - Default: `"Organization"`
  - Description: Organization name for report headers

- **ReportPath**: Output file path
  - Type: String
  - Default: `"C:\Reports\Lync_Users_Registration_{timestamp}.txt"`
  - Description: Full path where registration report will be saved

- **SampleUserCount**: Sample size for detailed listing
  - Type: Integer
  - Default: `10`
  - Description: Number of sample users to include in detailed analysis

- **RecentModifiedDays**: Recent modification timeframe
  - Type: Integer
  - Default: `30`
  - Description: Number of days to look back for recently modified users

- **SBAPattern**: SBA pool identification pattern
  - Type: String
  - Default: `"*MSSBA*"`
  - Description: Wildcard pattern to identify Survivable Branch Appliance pools

## Usage Examples

### Example 1: Standard Registration Report
```powershell
.\Get-LyncUserRegistrationReport.ps1 -OrganizationName "Contoso"
```
Generates user registration report with default settings.

### Example 2: Custom Output Path
```powershell
.\Get-LyncUserRegistrationReport.ps1 -OrganizationName "Contoso" -ReportPath "C:\Reports\Contoso_Lync_Report.txt"
```
Creates report with custom organization name and output location.

### Example 3: Extended Sample Size and Timeframe
```powershell
.\Get-LyncUserRegistrationReport.ps1 -SampleUserCount 25 -RecentModifiedDays 60
```
Includes 25 sample users and 60-day recent modification window.

### Example 4: Branch Office Focus
```powershell
.\Get-LyncUserRegistrationReport.ps1 -OrganizationName "Global Corp" -SBAPattern "*Branch*" -SampleUserCount 5
```
Focuses on branch office users with custom SBA pattern.

### Example 5: Quick Assessment
```powershell
.\Get-LyncUserRegistrationReport.ps1 -SampleUserCount 3 -RecentModifiedDays 7
```
Quick assessment with minimal sample size and recent changes only.

## Output

### Report Structure

#### 1. Lync Enabled Users Summary
- **Total Lync-Enabled Users**: Count of all Lync-enabled accounts
- **Users by Registrar Pool**: Distribution across pools
  - Pool FQDN
  - User count per pool
  - Percentage of total users
- **Enabled Users**: Active user accounts
- **Disabled Users**: Disabled but Lync-enabled accounts

#### 2. User Registration Status
- **Currently Registered Users**: Users with active registrations
- **Unregistered Users**: Users not currently registered
- **Registration Rate**: Percentage of users currently signed in
- **Registration by Pool**: Active registrations per pool

Registration status indicators:
- ✅ **Registered**: User currently signed in
- ⚠️ **Unregistered**: User enabled but not signed in
- 🔴 **Disabled**: Account disabled (shouldn't be registered)

#### 3. Enterprise Voice Statistics
- **Voice-Enabled Users**: Users with Enterprise Voice enabled
- **Voice Disabled Users**: Lync users without voice capabilities
- **Voice Enablement Rate**: Percentage with Enterprise Voice
- **Users with LineURI**: Users with phone numbers assigned
- **Users without LineURI**: Voice users missing phone numbers
- **Voice Policy Distribution**: Users per voice policy

#### 4. SBA (Survivable Branch Appliance) Users
For users registered to SBA pools:
- **Total SBA Users**: Count of branch office users
- **SBA Pools**: List of branch appliance pools
- **Users per SBA**: Distribution across branches
- **Site Identification**: Branch locations (extracted from pool names)

#### 5. Recently Modified Users
Users modified within specified days:
- **User Count**: Recently changed accounts
- **Modification Types**: What changed (policies, enablement, etc.)
- **Sample Listings**: Detailed examples with:
  - Display name
  - SIP address
  - Last modification date
  - Modification type

#### 6. Sample User Details
Detailed information for sample users (up to SampleUserCount):
- **Display Name**: User's display name
- **SIP Address**: Primary SIP URI
- **UPN**: User Principal Name
- **Registrar Pool**: Assigned pool
- **Registration Status**: Currently registered (Yes/No)
- **Enterprise Voice**: Enabled/Disabled
- **LineURI**: Assigned phone number
- **Voice Policy**: Applied voice policy
- **Last Activity**: Most recent sign-in or activity timestamp
- **Enabled Status**: Account enabled/disabled

#### 7. User Activity Analysis
- **Active Users (Last 7 Days)**: Users with recent activity
- **Active Users (Last 30 Days)**: Monthly active users
- **Inactive Users (>30 Days)**: Users not signed in for over 30 days
- **Never Registered**: Users enabled but never signed in
- **Activity Rate**: Percentage of active users

#### 8. Registration Health Summary
- **Overall Health Score**: Based on registration rate, activity, and configuration
- **Healthy**: >90% users able to register
- **Warning**: 70-90% registration success
- **Critical**: <70% registration success
- **Issues Identified**: Common problems found
- **Recommendations**: Suggested actions

### Output File Locations
Default: `C:\Reports\`

### Output File Naming
Pattern: `Lync_Users_Registration_{YYYYMMDD_HHmmss}.txt`

Example: `Lync_Users_Registration_20251223_143052.txt`

### Console Output
Progress indicators during generation:
- User enumeration progress
- Registration status checks
- Activity analysis progress
- Report completion confirmation

## Common Issues & Troubleshooting

### Issue: "Get-CsUser cmdlet not found"
**Solution**: Run from Lync Management Shell:
```powershell
# Launch Lync Management Shell
# Start Menu → Lync Server Management Shell

# Or import module
Import-Module "C:\Program Files\Common Files\Skype for Business Server 2015\Modules\SkypeForBusiness\SkypeForBusiness.psd1"
```

### Issue: No Registration Data Available
**Possible Causes**:
1. Users not currently signed in
2. Registration cmdlets require additional permissions
3. User presence information not available

**Solution**: Verify cmdlet availability:
```powershell
# Test user registration cmdlet
Get-CsUserRegistrarStatus -UserUri "user@contoso.com"

# If unavailable, report shows enablement only
```

### Issue: Last Activity Shows Null or Empty
**Solution**: Last activity data may not be available for all users. This is expected when:
- User never signed in
- Activity tracking not enabled
- User information not synchronized

### Issue: SBA Users Not Identified
**Solution**: Adjust SBAPattern to match your naming convention:
```powershell
# First identify SBA pool names
Get-CsPool | Where-Object {$_.Services -like "*Registrar*"} | Select-Object Identity

# Then adjust pattern
.\Get-LyncUserRegistrationReport.ps1 -SBAPattern "*yoursbaname*"
```

### Issue: Report Generation Very Slow
**Solution**: For large environments (>10,000 users):
1. Reduce sample user count: `-SampleUserCount 5`
2. Run during off-peak hours
3. Consider filtering by pool:
   ```powershell
   # Manually filter before running
   $users = Get-CsUser -Filter {RegistrarPool -eq "pool.contoso.com"}
   ```

### Issue: "Access Denied" Errors
**Solution**: Ensure appropriate permissions:
```powershell
# Verify your role
Get-CsAdministratorRole | Where-Object {$_.Identity -match $env:USERNAME}

# Request access from admin
# Admin runs: Grant-CsUserAdministrator -Identity "DOMAIN\Username"
```

### Issue: Recent Modifications Shows No Users
**Interpretation**:
- ✅ **Good**: No changes means stable environment
- May indicate: RecentModifiedDays too short

**Solution**: Extend timeframe:
```powershell
.\Get-LyncUserRegistrationReport.ps1 -RecentModifiedDays 90
```

## Use Case Scenarios

### Daily Operations Monitoring
Monitor user registration health daily:
```powershell
# Schedule daily registration report
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"C:\Scripts\Get-LyncUserRegistrationReport.ps1`""
$Trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
Register-ScheduledTask -TaskName "Lync Daily Registration Check" -Action $Action -Trigger $Trigger
```

### User Onboarding Verification
Verify new user enablement:
```powershell
# Generate report focusing on recent changes
.\Get-LyncUserRegistrationReport.ps1 -RecentModifiedDays 7 -SampleUserCount 20

# Review "Recently Modified Users" section
# Verify new users can register
```

### Migration Planning
Pre-Teams migration analysis:
1. Identify total user count
2. Document pool distribution
3. Identify SBA users needing special migration handling
4. Capture voice-enabled user count
5. Document inactive users (candidates for removal)

### Capacity Planning
Analyze registration patterns for capacity:
1. Review users per pool
2. Identify registration rates
3. Plan pool expansion based on distribution
4. Monitor activity trends over time

### Inactive User Cleanup
Identify users for cleanup:
```powershell
# Generate report
.\Get-LyncUserRegistrationReport.ps1 -RecentModifiedDays 90

# Review "User Activity Analysis" section
# Identify "Never Registered" and ">30 Days Inactive"
# Plan deprovisioning for inactive accounts
```

### Branch Office Assessment
Evaluate branch office connectivity:
```powershell
# Focus on SBA users
.\Get-LyncUserRegistrationReport.ps1 -SBAPattern "*" -SampleUserCount 50

# Review SBA Users section
# Verify registration success at branches
# Identify connectivity issues
```

### Troubleshooting Registration Issues
User reports can't sign in:
1. Generate registration report
2. Find user in sample or by manual query
3. Check registration status
4. Verify pool assignment
5. Check enablement status
6. Review voice policy if voice issue

### Voice Enablement Audit
Verify voice configuration:
1. Review "Enterprise Voice Statistics"
2. Identify users with LineURI vs. without
3. Validate voice policy assignments
4. Plan phone number assignments

### Compliance Reporting
Regular compliance checks:
```powershell
# Monthly compliance report
.\Get-LyncUserRegistrationReport.ps1 -RecentModifiedDays 30 -SampleUserCount 50

# Document:
# - Total enabled users
# - Voice-enabled users
# - SBA users (branch locations)
# - Activity rates
```

## Registration Health Interpretation

### Healthy Indicators
- ✅ Registration rate >70% during business hours
- ✅ Active user rate >80% over 30 days
- ✅ All voice users have LineURI assigned
- ✅ Balanced pool distribution
- ✅ Minimal "never registered" users

### Warning Signs
- ⚠️ Registration rate 50-70%
- ⚠️ Active user rate 60-80%
- ⚠️ Voice users missing LineURI assignments
- ⚠️ Unbalanced pool distribution (>80% on one pool)
- ⚠️ Growing "never registered" count

### Critical Issues
- 🔴 Registration rate <50%
- 🔴 Active user rate <60%
- 🔴 Majority voice users missing LineURI
- 🔴 Pool unavailable (0 registrations)
- 🔴 High disabled user count

## Data Analysis Tips

### Calculating Registration Success Rate
```powershell
# From report data
$totalUsers = 1000  # From "Total Lync-enabled users"
$registeredUsers = 750  # From "Currently Registered Users"
$registrationRate = ($registeredUsers / $totalUsers) * 100
# Result: 75% registration rate
```

### Identifying Pool Imbalance
- **Healthy**: Users distributed evenly across pools
- **Warning**: One pool has >60% of users
- **Critical**: One pool has >80% of users (consider load balancing)

### Voice Enablement Completeness
```powershell
# From report data
$voiceEnabled = 500  # From "Voice-Enabled Users"
$withLineURI = 450  # From "Users with LineURI"
$completeness = ($withLineURI / $voiceEnabled) * 100
# Result: 90% completeness (50 users need phone numbers)
```

## Related Scripts
- [Start-LyncCsvExporter.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Start-LyncCsvExporter) - Export user data to CSV for analysis
- [Get-ComprehensiveLyncReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveLyncReport) - Complete environment assessment
- [Export-ADLyncTeamsMigrationData.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Export-ADLyncTeamsMigrationData) - AD attribute export for migration

## Version History
- **v2.0** (2025-09-17): Enhanced registration reporting
  - Added user activity analysis
  - Enhanced registration status tracking
  - Added voice enablement statistics
  - Improved SBA user identification
  - Added registration health summary
- **v1.0** (2024): Initial release
  - Basic user registration reporting
  - Pool distribution analysis

## See Also
- [Monitor User Registration](https://docs.microsoft.com/en-us/skypeforbusiness/manage/health-and-monitoring/user-registration)
- [User Accounts in Lync Server](https://docs.microsoft.com/en-us/skypeforbusiness/manage/users/)
- [Configure Voice for Users](https://docs.microsoft.com/en-us/skypeforbusiness/deploy/deploy-enterprise-voice/)
