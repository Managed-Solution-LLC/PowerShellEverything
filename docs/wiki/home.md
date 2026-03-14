# PowerShellEveryting Wiki

Welcome to the PowerShellEveryting documentation wiki. This enterprise PowerShell toolkit provides production-ready scripts for Microsoft 365, Azure AD, Teams, Lync/Skype for Business, and Intune management.

## 📚 Documentation Categories

### 🎯 Lync/Skype for Business Assessments
**[Lync Assessment Scripts Overview →](README)**

Complete suite of Lync/Skype for Business assessment and migration tools:
- **[Start-LyncCsvExporter](Start-LyncCsvExporter)** - Interactive menu-driven CSV export tool
- **[Get-ComprehensiveLyncReport](Get-ComprehensiveLyncReport)** - Complete environment assessment with recommendations
- **[Get-LyncHealthReport](Get-LyncHealthReport)** - Health monitoring and diagnostics
- **[Get-LyncInfrastructureReport](Get-LyncInfrastructureReport)** - Infrastructure configuration analysis
- **[Get-LyncServiceStatus](Get-LyncServiceStatus)** - Service status and performance monitoring
- **[Get-LyncUserRegistrationReport](Get-LyncUserRegistrationReport)** - User registration and activity tracking
- **[Export-ADLyncTeamsMigrationData](Export-ADLyncTeamsMigrationData)** - AD export for Teams migration

### 📊 Microsoft 365 Assessments

Office 365 tenant assessment and reporting tools:
- **[Get-QuickO365Report](Get-QuickO365Report)** - Complete O365 assessment with Excel output
- **[Get-MailboxPermissionsReport](Get-MailboxPermissionsReport)** - Mailbox delegation and permissions audit
- **[Get-MailboxRules](Get-MailboxRules)** - Export mailbox rules (forwarding, redirects, auto-replies)
- **[Get-MigrationWizLicensing](Get-MigrationWizLicensing)** - BitTitan MigrationWiz license calculator

### 🏢 Office 365 User Management

User account creation and management automation:
- **[New-Office365Accounts](Office365/New-Office365Accounts)** - Bulk user account creation with password generation
  - CSV batch import or array input
  - Automatic secure password generation
  - OneDrive provisioning support
  - Cloud Shell optimized with persistent storage
  - Microsoft 365 or Active Directory support
  - Password export to secure timestamped CSV
- **[Sync-ContactsFromCsv](Office365/Sync-ContactsFromCsv)** - Sync contact folders from CSV to Microsoft Graph mailboxes
  - Retrieve users from Entra security groups
  - Phone number normalization and update
  - Optional name, company, and job title sync
  - Contact cleanup with deletion support
  - Parallel processing for large user sets
- **[Set-EmailToSharedAccount](Office365/Set-EmailToSharedAccount)** - Convert Exchange Online mailboxes to Shared and remove all M365 licenses
  - CSV, array, or single-identity input
  - Detects already-shared mailboxes (non-fatal skip)
  - `-SkipLicenseRemoval` for mailbox-only conversion
  - WhatIf support and timestamped CSV results
- **[Set-SMTPForward](Office365/Set-SMTPForward)** - Configure or clear SMTP forwarding on Exchange Online mailboxes in bulk
  - Set, update, or clear `ForwardingSmtpAddress` per mailbox
  - Control `DeliverToMailboxAndForward` per entry
  - Optional `-AllowAutoForward` updates tenant outbound spam policy
  - CSV, array, or single-identity input; WhatIf support
- **[Invoke-UserSignOutAndBlock](Office365/Invoke-UserSignOutAndBlock)** - Block sign-in, revoke all sessions, and disable devices for M365 accounts
  - Bulk operation via CSV, array, or single UPN
  - Blocks sign-in (AccountEnabled = $false) and revokes all refresh tokens immediately
  - Reports and optionally disables Entra ID-registered/joined devices
  - WhatIf support for safe pre-run validation
  - Designed for offboarding, incident response, and account compromise scenarios

### 🖥️ On-Premise Infrastructure Assessments

Active Directory and Windows Server assessment tools:
- **[Get-ComprehensiveADReport](Get-ComprehensiveADReport)** - Complete Active Directory assessment for AD to AD migrations
  - Full user, group, OU, and computer inventory
  - User matching attribute analysis (EmployeeID, email, UPN)
  - Privileged account identification
  - Cross-domain and cross-forest query support
  - Migration recommendations and data quality analysis
  - Executive summary with matching strategies
- **[Check-ADMTPrerequisites](Check-ADMTPrerequisites)** - ADMT migration readiness validation
  - Domain functional level and trust relationship checks
  - Permission and network connectivity validation
  - SID History and Password Export Server prerequisites
  - Port connectivity testing for all AD protocols
  - Automated remediation guidance
  - CSV export with pass/fail/warning status
- **[Start-FileShareAssessment](Start-FileShareAssessment)** - Comprehensive file share assessment with Excel reporting
  - Automatic SMB share discovery
  - Storage analysis and NTFS permission mapping
  - SharePoint/OneDrive compatibility checking
  - Professional Excel report generation

### 🔐 PKI Assessments

Public Key Infrastructure assessment and reporting:
- **[Get-ComprehensivePKIReport](Get-ComprehensivePKIReport)** - Complete PKI environment assessment
- **[Get-PKIHealthReport](Get-PKIHealthReport)** - PKI health monitoring and diagnostics
- **[Merge-PKIAssessmentReports](Merge-PKIAssessmentReports)** - Combine multiple PKI assessment reports

### � Microsoft Teams Assessments

Microsoft Teams infrastructure assessment and analysis:
- **[Get-ComprehensiveTeamsReport](Get-ComprehensiveTeamsReport)** - Complete Teams infrastructure assessment
  - Tenant configuration and policy analysis
  - Voice infrastructure (Direct Routing, Calling Plans)
  - User licensing and compliance reporting
  - Executive summary with recommendations

### 📱 Intune Management

Microsoft Intune device enrollment and management:
- **[Start-IntuneEnrollment](Start-IntuneEnrollment)** - Force enrollment of Entra Joined devices
  - 3-tiered enrollment detection
  - GitHub direct execution support
  - Automatic policy synchronization
  - Comprehensive enrollment validation

### 🌐 Microsoft Graph API Helpers

Reusable authentication, pagination, and reporting functions used across all scripts:
- **[Get-GraphToken](Graph%20Commands/Get-GraphToken)** - Acquire OAuth2 access tokens via MSAL.PS (client secret or interactive)
- **[Get-GraphHeaders](Graph%20Commands/Get-GraphHeaders)** - Build authorization header hashtables for REST API calls
- **[Get-AzureResourcePaging](Graph%20Commands/Get-AzureResourcePaging)** - Automatically follow `@odata.nextLink` across all result pages
- **[Get-EnterpriseAppUsage](Graph%20Commands/Get-EnterpriseAppUsage)** - Report sign-in usage and ownership of all app registrations
- **[Get-ExchangeErrorsGraph](Graph%20Commands/Get-ExchangeErrorsGraph)** - Surface Exchange Online provisioning errors via Graph beta endpoint
- **[Get-PBIWorkspaceUsageReport](Graph%20Commands/Get-PBIWorkspaceUsageReport)** - Power BI workspace and report usage across all workspaces

### 🔧 Development Resources
- **[Running Scripts from GitHub](Running-Scripts-from-GitHub)** - Execute PowerShell scripts directly from GitHub
- **Code Standards** - PowerShell coding standards and best practices _(coming soon)_

## 🎯 Featured Scripts

### New-Office365Accounts.ps1
Bulk user account creation for Microsoft 365 with automatic password generation, OneDrive provisioning, and Cloud Shell support. Accepts CSV files, arrays, or individual parameters.

**Quick Start:**
```powershell
# From array
$users = @(
    @{FirstName='John'; LastName='Doe'; EmailAddress='john.doe@contoso.com'; UsageLocation='US'}
)
.\New-Office365Accounts.ps1 -UserArray $users -InitializeOneDrive

# From Cloud Shell (auto-detects environment)
.\New-Office365Accounts.ps1 -CsvPath "users.csv"
```

[View Documentation →](Office365/New-Office365Accounts)

### Sync-ContactsFromCsv.ps1
Synchronizes contact information from a CSV file into users' Microsoft Graph contact folders. Pull target users from an Entra security group, sync phone numbers and contact details, and optionally delete contacts not in the source list.

**Quick Start:**
```powershell
# Sync contacts for all members of a security group
.\Sync-ContactsFromCsv.ps1 `
    -CsvPath "C:\contacts.csv" `
    -FolderName "Shared Contacts" `
    -SecurityGroup "Sales Team" `
    -UpdateNames -DeleteNotInCsv
```

[View Documentation →](Office365/Sync-ContactsFromCsv)

### Get-PBIWorkspaceUsageReport.ps1
Comprehensive Power BI workspace usage report covering all shared and personal workspaces. Correlates report inventory with Activity Log data for up to 90 days, surfacing view counts, unique users, and stale reports.

**Quick Start:**
```powershell
.\Get-PBIWorkspaceUsageReport.ps1 `
    -TenantId "<tenant-id>" `
    -ClientId "<client-id>" `
    -ClientSecret "<secret>" `
    -OutputPath "C:\Reports\PBI" `
    -OutputFormat "csv"
```

[View Documentation →](Graph%20Commands/Get-PBIWorkspaceUsageReport)

### Get-QuickO365Report.ps1
Complete Office 365 tenant assessment collecting mailboxes, licenses, OneDrive, SharePoint, Groups, Teams, and permissions. Generates professional Excel workbook with formatted tables.

**Quick Start:**
```powershell
.\Get-QuickO365Report.ps1 -TenantDomain "contoso"
```

[View Documentation →](Get-QuickO365Report)

### Get-MailboxPermissionsReport.ps1
Comprehensive mailbox delegation audit for Full Access, Send As, Send on Behalf, and folder-level permissions.

**Quick Start:**
```powershell
.\Get-MailboxPermissionsReport.ps1 -MailboxFilter SharedMailboxes
```

[View Documentation →](Get-MailboxPermissionsReport)

### Get-MailboxRules.ps1
Export and audit mailbox rules (inbox rules) to identify forwarding rules, auto-replies, folder moves, and automated actions. Essential for security audits and compliance.

**Quick Start:**
```powershell
# All users
.\Get-MailboxRules.ps1

# Specific user
.\Get-MailboxRules.ps1 -UserPrincipalName "user@contoso.com"
```

[View Documentation →](Get-MailboxRules)

### Start-FileShareAssessment.ps1
All-in-one file share assessment tool that discovers SMB shares, analyzes storage and permissions, checks SharePoint/OneDrive compatibility, and generates professional Excel reports.

**Quick Start:**
```powershell
.\Start-FileShareAssessment.ps1 -Domain "Contoso"
```

[View Documentation →](Start-FileShareAssessment)

### Get-ComprehensiveADReport.ps1
Complete Active Directory assessment for AD to AD migration planning. Exports all users, groups, OUs, and privileged accounts with user matching attribute analysis. Supports cross-domain and cross-forest queries.

**Quick Start:**
```powershell
# Basic assessment
.\Get-ComprehensiveADReport.ps1 -OrganizationName "Contoso"

# Query different domain
.\Get-ComprehensiveADReport.ps1 -Domain "sachicis.org" -OrganizationName "SACHICIS"

# Cross-forest with credentials
.\Get-ComprehensiveADReport.ps1 -Domain "partner.com" -Credential (Get-Credential)
```

[View Documentation →](Get-ComprehensiveADReport)

## 🚀 Quick Start

1. Clone the repository
2. Review script requirements in comment-based help
3. Install required PowerShell modules
4. Run scripts with appropriate permissions

## 📋 Requirements

- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Appropriate Microsoft 365 admin roles
- Required PowerShell modules (installed automatically by most scripts)

## 🔗 Key Links

- [GitHub Repository](https://github.com/Managed-Solution-LLC/PowerShellEveryting)
- [Contributing Guidelines](https://github.com/Managed-Solution-LLC/PowerShellEveryting/blob/main/CONTRIBUTING.md)
- [License](https://github.com/Managed-Solution-LLC/PowerShellEveryting/blob/main/LICENSE)

## ⚠️ Important Notes

**Client-Agnostic Development**: All public scripts are designed to work with any customer environment. Customer-specific scripts belong in `.prep/` directories only.

**Production Ready**: These scripts are actively used in enterprise IT environments for assessments, migrations, and automation.
