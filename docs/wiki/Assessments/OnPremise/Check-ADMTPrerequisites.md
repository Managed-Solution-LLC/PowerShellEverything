# Check-ADMTPrerequisites

## Overview
PowerShell script that validates environment readiness for Active Directory Migration Tool (ADMT) migrations. Performs comprehensive prerequisite checks including domain functional levels, trust relationships, network connectivity, permissions, and optional SID History and Password Export Server (PES) requirements.

This script helps identify and resolve issues **before** starting an ADMT migration project, reducing migration failures and downtime.

## Features
- **DNS Resolution Validation** - Verifies both source and target domains are resolvable
- **Domain Functional Level Checks** - Ensures domains meet minimum requirements
- **Trust Relationship Analysis** - Validates trust type, direction, and configuration
- **Permission Verification** - Confirms current user has necessary administrative rights
- **Network Connectivity Testing** - Tests critical AD ports (LDAP, Kerberos, SMB, RPC, etc.)
- **SID History Prerequisites** - Optional validation for SID History migration requirements
- **Password Export Server (PES) Checks** - Optional PES installation and configuration validation
- **SQL Server Detection** - Identifies SQL Server instances for ADMT database
- **ADMT Installation Status** - Checks if ADMT is already installed
- **Detailed Reporting** - Color-coded console output and CSV export with remediation steps

## Prerequisites
- **PowerShell**: 5.1 or later
- **Required Modules**: 
  - ActiveDirectory (RSAT Tools)
- **Permissions**: 
  - Domain Admin in target domain (recommended)
  - Read access to source domain
  - Ability to query both source and target domains
- **Network**: 
  - Connectivity to domain controllers in both domains
  - DNS resolution for both domains

## Parameters

### Required Parameters

- **SourceDomain**: FQDN of the source domain (domain you're migrating FROM)
  - Example: `"old.contoso.com"`, `"legacy.fabrikam.com"`

### Optional Parameters

- **TargetDomain**: FQDN of the target domain (domain you're migrating TO)
  - Default: Current domain (Get-ADDomain).DNSRoot
  - Example: `"new.contoso.com"`

- **CheckSIDHistory**: Switch parameter to include SID History prerequisite checks
  - Validates auditing, connectivity to source PDC, and special group creation
  - Example: `-CheckSIDHistory`

- **CheckPES**: Switch parameter to check Password Export Server requirements
  - Validates PES installation prerequisites
  - Example: `-CheckPES`

- **SourcePDC**: FQDN of source domain PDC Emulator
  - Required when using `-CheckSIDHistory`
  - Example: `"dc01.old.contoso.com"`

## Usage Examples

### Example 1: Basic Prerequisites Check
```powershell
.\Check-ADMTPrerequisites.ps1 -SourceDomain "old.contoso.com" -TargetDomain "new.contoso.com"
```
Performs core prerequisite checks for ADMT migration between two domains.

### Example 2: Full Check with SID History
```powershell
.\Check-ADMTPrerequisites.ps1 -SourceDomain "old.contoso.com" -TargetDomain "new.contoso.com" -CheckSIDHistory -SourcePDC "dc01.old.contoso.com"
```
Includes SID History prerequisites with connectivity tests to source PDC.

### Example 3: Check with Password Migration
```powershell
.\Check-ADMTPrerequisites.ps1 -SourceDomain "legacy.fabrikam.com" -CheckPES -CheckSIDHistory -SourcePDC "pdc.legacy.fabrikam.com"
```
Complete prerequisite check including Password Export Server requirements.

### Example 4: Target Current Domain
```powershell
.\Check-ADMTPrerequisites.ps1 -SourceDomain "old.domain.com"
```
Checks migration to current domain (useful when running from target domain controller).

## Check Categories

### 1. DNS Resolution
- **Source Domain DNS**: Verifies source domain FQDN resolves to IP addresses
- **Target Domain DNS**: Verifies target domain FQDN resolves to IP addresses
- **Purpose**: Ensures basic network connectivity and name resolution

### 2. Domain Functional Levels
- **Target Domain Level**: Reports target domain functional level
- **Target Forest Level**: Reports target forest functional level
- **Source Domain Level**: Validates source meets minimum (Windows 2000 Native)
- **Purpose**: ADMT requires minimum functional levels for proper operation

### 3. Trust Relationships
- **Trust Existence**: Verifies trust relationship exists between domains
- **Trust Direction**: Validates trust direction (BiDirectional optimal, Outbound sufficient)
- **Trust Type**: Reports trust type (External, Forest, etc.)
- **Purpose**: Target must trust Source for ADMT to read source objects

### 4. Permission Checks
- **Target Domain Admin**: Verifies current user is Domain Admin in target
- **Source Domain Read**: Confirms read access to source domain objects
- **Purpose**: ADMT requires admin rights in target and read rights in source

### 5. SID History Prerequisites (Optional with `-CheckSIDHistory`)
- **Auditing Configuration**: Validates account management auditing on source PDC
- **TCP Port 138**: Tests connectivity to source PDC on port 138 (NetBIOS)
- **Special Group**: Documents requirement for `$SourceDomain$$$` group on source PDC
- **Purpose**: SID History migration requires specific source domain configuration

### 6. Password Export Server (Optional with `-CheckPES`)
- **PES Installation Location**: Confirms PES must be on source domain DC
- **Encryption Key**: Documents 128-bit key requirement
- **Purpose**: Password migration requires PES installation on source domain

### 7. Network Connectivity
Tests critical Active Directory ports to target domain controller:
- **Port 389**: LDAP
- **Port 636**: LDAPS (secure LDAP)
- **Port 3268**: Global Catalog
- **Port 88**: Kerberos
- **Port 135**: RPC Endpoint Mapper
- **Port 445**: SMB (file sharing)
- **Purpose**: ADMT requires multiple AD protocols for migration operations

### 8. Database Requirements
- **SQL Server Detection**: Checks for existing SQL Server installations
- **SQL Server Express**: Notes that ADMT can install SQL Express if needed
- **Purpose**: ADMT requires SQL Server for migration database

### 9. ADMT Installation Status
- **Installation Directory**: Checks for C:\Windows\ADMT directory
- **Registry Keys**: Verifies ADMT registration in system
- **Purpose**: Determines if ADMT is already installed

## Output

### Console Output
Color-coded results displayed in terminal:
- **🟢 PASS** (Green): Check passed successfully
- **🔴 FAIL** (Red): Critical issue requiring resolution
- **🟡 WARNING** (Yellow): Non-critical issue or potential problem
- **🔵 INFO** (Cyan): Informational message

Each failed check includes:
- Description of the issue
- **Remediation** steps to resolve the problem

### CSV Export
Automatically exports results to timestamped CSV file:
- **Filename Pattern**: `ADMT_Prerequisites_YYYYMMDD_HHmmss.csv`
- **Columns**: Check, Status, Message, Remediation
- **Location**: Current directory

### Summary Report
Final summary shows:
- Total checks performed
- Count of PASS, FAIL, WARNING, and INFO results
- List of all failed items requiring attention
- Path to exported CSV file

## Common Issues & Troubleshooting

### Issue: Source Domain DNS Resolution Fails
**Symptoms**: Cannot resolve source domain FQDN

**Solution**:
- Verify DNS server configuration on ADMT server
- Add conditional forwarders for source domain
- Test with `nslookup source.domain.com`
- Check firewall allows DNS (UDP/TCP 53)

### Issue: No Trust Relationship Found
**Symptoms**: Trust check fails with "No trust relationship found"

**Solution**:
- Establish trust between domains (minimum: target trusts source)
- For full functionality, create two-way trust
- Verify trust with: `Get-ADTrust -Filter * -Server target.domain.com`
- Use Active Directory Domains and Trusts MMC snap-in

### Issue: Permission Denied on Source Domain
**Symptoms**: Cannot read from source domain

**Solution**:
- Ensure account has at least read permissions in source domain
- Add account to source domain's Domain Users group (minimum)
- For password migration, account needs additional source domain rights
- Consider using dedicated migration account with proper permissions

### Issue: Port Connectivity Failures
**Symptoms**: Multiple port checks fail to target DC

**Solution**:
- Check firewall rules between ADMT server and target DC
- Verify Windows Firewall on target DC allows inbound connections
- Test manually: `Test-NetConnection -ComputerName targetdc.domain.com -Port 389`
- Review any network security groups or hardware firewalls

### Issue: SID History Port 138 Fails
**Symptoms**: Cannot connect to TCP port 138 on source PDC

**Solution**:
- Enable NetBIOS on source PDC
- Open TCP port 138 in firewalls
- Verify source PDC hostname/IP is correct
- Consider using `-SourcePDC` parameter with PDC FQDN

### Issue: Source Domain Functional Level Too Low
**Symptoms**: Source domain level below Windows 2000 Native

**Solution**:
- Raise source domain functional level:
  ```powershell
  Set-ADDomainMode -Identity "source.domain.com" -DomainMode Windows2003Domain
  ```
- Ensure all DCs support higher functional level first
- Cannot be reversed - verify compatibility before raising

## ADMT Migration Checklist

Use this script as part of your ADMT migration preparation:

### Pre-Migration Phase
1. ✅ Run Check-ADMTPrerequisites.ps1 with `-CheckSIDHistory` and `-CheckPES`
2. ✅ Resolve all FAIL status items
3. ✅ Review and address WARNING items
4. ✅ Document current configuration (export CSV for records)
5. ✅ Obtain necessary credentials (Domain Admin in target, read access in source)

### Trust Configuration
1. ✅ Establish minimum trust (target trusts source)
2. ✅ Verify trust with `nltest /trusted_domains`
3. ✅ Test trust authentication: `runas /netonly /user:source\username cmd`

### SID History Setup (if needed)
1. ✅ Enable auditing on source domain PDC
2. ✅ Verify TCP port 138 connectivity
3. ✅ Run first migration to create `$SourceDomain$$$` group

### Password Migration Setup (if needed)
1. ✅ Install Password Export Server on source domain DC
2. ✅ Generate and securely store encryption key
3. ✅ Configure PES service account

### ADMT Installation
1. ✅ Install SQL Server (or allow ADMT to install SQL Express)
2. ✅ Install ADMT on target domain member server
3. ✅ Create ADMT migration database
4. ✅ Configure ADMT service account

### Post-Installation Validation
1. ✅ Re-run Check-ADMTPrerequisites.ps1
2. ✅ Perform test migration with pilot group
3. ✅ Validate migrated objects and permissions
4. ✅ Document migration procedures

## Related Scripts
- [Get-ComprehensiveADReport](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveADReport) - Assess source and target AD environments before migration
- [Start-FileShareAssessment](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Start-FileShareAssessment) - Assess file shares that may need permission updates post-migration

## Best Practices

### Run Early and Often
- Run this script **weeks before** planned migration
- Re-run after resolving issues to verify fixes
- Run immediately before migration window as final validation

### Document Everything
- Save all CSV exports for compliance and troubleshooting
- Screenshot any FAIL or WARNING results
- Maintain change log of remediation actions

### Staged Validation
1. **Initial Run**: Identify all issues and plan remediation
2. **Mid-Preparation**: Verify fixes and identify new issues
3. **Pre-Migration**: Final validation before migration window
4. **Post-Migration**: Verify environment remains properly configured

### Security Considerations
- Run script from secure workstation
- Use dedicated migration service account (not personal admin account)
- Store credentials securely (never in scripts or logs)
- Review permissions granted to migration accounts
- Remove migration accounts and trusts after project completion

## Version History
- **v1.0** (2026-01-14): Initial release
  - Core prerequisite checks for ADMT migrations
  - DNS, functional level, trust, and permission validation
  - Network connectivity testing
  - Optional SID History and PES checks
  - CSV export with remediation guidance
  - Summary reporting

## See Also
- [Microsoft ADMT Documentation](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/cc974332(v=ws.10))
- [ADMT Guide](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/cc974376(v=ws.10))
- [Active Directory Migration Best Practices](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/plan/planning-domain-controller-placement)
- [SID History Migration](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/cc974394(v=ws.10))
