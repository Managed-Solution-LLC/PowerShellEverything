# Get-LyncInfrastructureReport.ps1

## Overview
Generates a detailed infrastructure and configuration report for Lync/Skype for Business environments. This reporting tool analyzes pools, computers, services, topology, and conference directories to provide administrators with comprehensive infrastructure documentation and health assessment.

## Features
- **Pool Categorization**: Automatic classification by pool type (Standard, SBA, IVR, Edge)
- **Computer Deployment Analysis**: Server distribution across pools
- **Service Configuration Review**: Role-based service mapping
- **Topology Documentation**: Site structure and configuration
- **Conference Directory Inventory**: Meeting infrastructure assessment
- **Infrastructure Health Summary**: Operational status indicators
- **Customizable Display Limits**: Control report verbosity
- **Flexible Pattern Matching**: Adapt to various naming conventions

## Prerequisites
- **PowerShell Version**: 3.0 or higher
- **Required Environment**: Lync/Skype for Business Management Shell
- **Required Permissions**: 
  - CsServerAdministrator or CsAdministrator role
  - Read access to Lync topology
- **Network Requirements**: Access to Lync Central Management Store

## Parameters

### Optional Parameters
- **OrganizationName**: Organization name
  - Type: String
  - Default: `"Organization"`
  - Description: Organization name for report headers

- **ReportPath**: Output file path
  - Type: String
  - Default: `"C:\Reports\Lync_Infrastructure_{timestamp}.txt"`
  - Description: Full path where infrastructure report will be saved

- **SBAPattern**: SBA pool identification pattern
  - Type: String
  - Default: `"*MSSBA*"`
  - Description: Wildcard pattern to identify Survivable Branch Appliance pools

- **IVRPattern**: IVR pool identification pattern
  - Type: String
  - Default: `"*ivr*"`
  - Description: Pattern to identify IVR (Interactive Voice Response) pools

- **EdgePattern**: Edge server pool pattern
  - Type: String
  - Default: `"*edge*"`
  - Description: Pattern to identify Edge server pools for external access

- **LyncPattern**: Standard Lync pool pattern
  - Type: String
  - Default: `"*lync*"`
  - Description: Pattern to identify standard Lync/Skype pools

- **MaxComputersPerPool**: Computer display limit
  - Type: Integer
  - Default: `5`
  - Description: Maximum computers to show per pool in detailed analysis

- **MaxServicesPerRole**: Service display limit
  - Type: Integer
  - Default: `5`
  - Description: Maximum services to show per role in detailed analysis

## Usage Examples

### Example 1: Standard Infrastructure Report
```powershell
.\Get-LyncInfrastructureReport.ps1
```
Generates infrastructure report with default organization name and patterns.

### Example 2: Custom Organization and Path
```powershell
.\Get-LyncInfrastructureReport.ps1 -OrganizationName "Contoso Corp" -ReportPath "D:\Reports\Contoso_Infrastructure.txt"
```
Creates report with custom organization name and output location.

### Example 3: Custom Pool Patterns
```powershell
.\Get-LyncInfrastructureReport.ps1 -SBAPattern "*Branch*" -LyncPattern "*teams*" -MaxComputersPerPool 10
```
Uses custom patterns for Teams-branded deployment with increased computer display.

### Example 4: Detailed Multi-Site Analysis
```powershell
.\Get-LyncInfrastructureReport.ps1 -OrganizationName "Global Corp" -EdgePattern "*dmz*" -MaxComputersPerPool 20 -MaxServicesPerRole 10
```
Detailed report for large multi-site deployment with custom Edge pattern.

### Example 5: Branch Office Focus
```powershell
.\Get-LyncInfrastructureReport.ps1 -SBAPattern "*sba*|*branch*|*remote*" -MaxComputersPerPool 3
```
Focuses on branch office infrastructure with multiple SBA patterns.

## Output

### Report Structure

#### 1. Infrastructure Overview Summary
- **Total Pools**: Count and breakdown by type
- **Total Computers**: Server count across all pools
- **Total Services**: Service instance count
- **Topology Sites**: Geographic/logical site count
- **Conference Directories**: Meeting infrastructure count

#### 2. Pool Architecture by Category

##### Standard Lync Pools
Core communication infrastructure:
- **Identity**: Full pool FQDN
- **Site**: Site assignment
- **Services**: Registrar, WebServices, Conferencing, Application
- **Computers**: Frontend servers, Director servers
- **Computer Count**: Number of servers in pool

##### Survivable Branch Appliances (SBA)
Branch office resilience:
- **Identity**: SBA FQDN
- **Site**: Branch location
- **Services**: Registrar, Gateway, Mediation
- **Computer**: SBA appliance or server
- **Purpose**: Branch survivability during WAN outage

##### IVR Pools
Voice response systems:
- **Identity**: IVR system FQDN
- **Services**: Application, UCMA services
- **Integration**: Workflow applications
- **Computer**: Application server

##### Edge Servers
External access infrastructure:
- **Identity**: Edge pool FQDN
- **Services**: Access Edge, Web Conferencing Edge, A/V Edge
- **External FQDN**: Public-facing address
- **Computer Count**: Number of Edge servers

##### Unclassified Pools
Pools not matching defined patterns:
- Listed for review and categorization
- May include appliances, third-party systems, or legacy servers

#### 3. Computer Deployment Details
For each pool (up to MaxComputersPerPool shown):
- **Computer FQDN**: Server fully qualified domain name
- **Pool Assignment**: Parent pool
- **Services Hosted**: Services running on server
- **Operating System**: Windows version (if available)
- **Physical/Virtual**: Deployment type (if detectable)

#### 4. Service Configuration by Role
Services grouped by role:
- **Registrar**: User registration and authentication
- **WebServices**: Web-based services and APIs
- **Conferencing**: Meeting and collaboration services
- **Application**: Application server and workflows
- **Mediation**: PSTN gateway mediation
- **Monitoring**: Call Quality and monitoring services
- **Archiving**: Compliance and archiving services
- **PersistentChat**: Persistent chat room services

For each service:
- Service name and role
- Pool assignment
- Computer hosting the service
- Status indicators

#### 5. Topology Sites
For each site:
- **Site Identity**: Site name
- **Pools in Site**: Pools assigned to location
- **Central Site**: Whether site is central or branch
- **Site Links**: Connectivity to other sites (if configured)

#### 6. Conference Directories
Conference infrastructure:
- **Directory ID**: Numeric identifier
- **Home Pool**: Pool hosting directory
- **Purpose**: Meeting ID range and assignment
- **Usage**: Active/inactive status

#### 7. Infrastructure Health Summary
- **Healthy Pools**: Pools with all services running
- **Pools with Warnings**: Pools with degraded services
- **Critical Pools**: Pools with service failures
- **Computer Distribution**: Balance across pools
- **Service Distribution**: Service role distribution

### Output File Locations
Default: `C:\Reports\`

### Output File Naming
Pattern: `Lync_Infrastructure_{YYYYMMDD_HHmmss}.txt`

Example: `Lync_Infrastructure_20251223_143052.txt`

### Console Output
Progress indicators:
- Pool categorization status
- Computer enumeration progress
- Service discovery status
- Report generation progress

## Common Issues & Troubleshooting

### Issue: "Access to the path is denied"
**Solution**: Ensure you have write permissions to output directory:
```powershell
# Test write access
New-Item -Path "C:\Reports\" -ItemType Directory -Force

# Or specify alternate path
.\Get-LyncInfrastructureReport.ps1 -ReportPath "$env:USERPROFILE\Desktop\Lync_Infra.txt"
```

### Issue: Pools Incorrectly Categorized
**Solution**: Adjust pattern parameters to match your naming convention:
```powershell
# First, identify your pool naming
Get-CsPool | Select-Object Identity

# Then adjust patterns accordingly
.\Get-LyncInfrastructureReport.ps1 -SBAPattern "*yoursbapattern*" -LyncPattern "*yourpoolpattern*"
```

### Issue: Too Much Detail (Report Too Long)
**Solution**: Reduce display limits:
```powershell
.\Get-LyncInfrastructureReport.ps1 -MaxComputersPerPool 3 -MaxServicesPerRole 3
```

### Issue: Not Enough Detail
**Solution**: Increase display limits:
```powershell
.\Get-LyncInfrastructureReport.ps1 -MaxComputersPerPool 50 -MaxServicesPerRole 50
```

### Issue: "Lync cmdlets not recognized"
**Solution**: Run from Lync Management Shell or import module:
```powershell
# Import Lync module
Import-Module "C:\Program Files\Common Files\Skype for Business Server 2015\Modules\SkypeForBusiness\SkypeForBusiness.psd1"

# Or launch Lync Management Shell
# Start Menu → Lync Server Management Shell
```

### Issue: Empty or Missing Sections
**Possible Causes**:
1. **No pools match patterns**: Adjust pattern parameters
2. **Permissions issue**: Verify CsAdministrator role
3. **Incomplete topology**: Verify topology publishing

**Solution**: Verify data availability:
```powershell
# Test each cmdlet manually
Get-CsPool
Get-CsComputer
Get-CsService
Get-CsTopology
Get-CsConferenceDirectory
```

### Issue: Multiple Pools Match Same Pattern
**Example**: Both "lyncpool" and "lyncsba" match "*lync*"

**Solution**: Use more specific patterns:
```powershell
# Use more specific patterns
.\Get-LyncInfrastructureReport.ps1 -LyncPattern "*lyncfe*" -SBAPattern "*lyncsba*"
```

## Use Case Scenarios

### Infrastructure Documentation
Complete infrastructure documentation:
1. Generate comprehensive infrastructure report
2. Archive for compliance and audit
3. Update network diagrams from pool/computer data
4. Document service distribution

### Capacity Planning
Analyze infrastructure for capacity:
1. Review computer distribution per pool
2. Identify overloaded pools
3. Plan new pool deployments
4. Document growth trends

### Migration Planning
Before Lync to Teams migration:
1. Document all pools and their purpose
2. Identify SBA locations needing Teams survivability
3. Map Edge servers to Direct Routing requirements
4. Capture conference directory assignments

### Disaster Recovery Documentation
For DR planning:
1. Document pool dependencies
2. Identify critical vs. non-critical pools
3. Map service distribution for recovery prioritization
4. Document site topology for geo-redundancy

### Change Management Baseline
Before major changes:
1. Generate pre-change infrastructure report
2. Perform infrastructure upgrade or change
3. Generate post-change infrastructure report
4. Compare reports to verify changes

### Troubleshooting Multi-Site Issues
For site connectivity problems:
1. Review topology sites section
2. Identify pool assignments per site
3. Verify site links and routing
4. Compare with network topology

### Security Audit
Infrastructure security assessment:
1. Identify all Edge servers (external access points)
2. Document service distribution (attack surface)
3. Review computer inventory for patching
4. Identify unclassified pools (potential rogue systems)

### Branch Office Assessment
Evaluate branch infrastructure:
1. Focus on SBA pools using custom pattern
2. Count branch locations
3. Assess survivability coverage
4. Plan Teams Phone survivability requirements

## Pattern Matching Guide

### Common Pool Naming Patterns

| Deployment Type | Example Names | Recommended Pattern |
|----------------|---------------|---------------------|
| Standard Pool | lyncpool01.contoso.com | `*lync*` or `*pool*` |
| SBA | boston-sba.contoso.com | `*sba*` or `*branch*` |
| Edge Server | edge.contoso.com | `*edge*` or `*dmz*` |
| IVR | ivr01.contoso.com | `*ivr*` or `*voice*` |
| Teams Hybrid | teamspool.contoso.com | `*teams*` |
| Multi-Site | newyork-lync.contoso.com | Use site prefix |

### Pattern Syntax
- `*` matches any characters: `*lync*` matches "prelync01", "lyncpool", "mylyncserver"
- Case insensitive: `*LYNC*` and `*lync*` are equivalent
- Multiple patterns: Not supported directly (use most specific pattern)

### Testing Patterns
Before running report, test your patterns:
```powershell
# Get all pools
$pools = Get-CsPool | Select-Object -ExpandProperty Identity

# Test SBA pattern
$pools -like "*MSSBA*"

# Test Lync pattern
$pools -like "*lync*"

# Adjust patterns as needed
```

## Infrastructure Health Indicators

### Healthy Pool Indicators
- ✅ All expected services running
- ✅ Computer count matches deployment
- ✅ Services distributed appropriately
- ✅ No configuration warnings

### Warning Signs
- ⚠️ Fewer computers than expected
- ⚠️ Unbalanced service distribution
- ⚠️ Services on unexpected computers
- ⚠️ Pools in unclassified category

### Critical Issues
- ❌ No computers in pool
- ❌ Required services missing
- ❌ Conference directories missing
- ❌ Topology inconsistencies

## Related Scripts
- [Get-ComprehensiveLyncReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveLyncReport) - Complete environment assessment
- [Get-LyncHealthReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncHealthReport) - Health monitoring and diagnostics
- [Get-LyncServiceStatus.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-LyncServiceStatus) - Service status details
- [Start-LyncCsvExporter.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Start-LyncCsvExporter) - CSV exports for data analysis

## Version History
- **v2.0** (2025-09-17): Enhanced infrastructure reporting
  - Added pool categorization by type
  - Enhanced service role grouping
  - Added topology site details
  - Improved conference directory reporting
  - Added customizable display limits
  - Enhanced infrastructure health summary
- **v1.0** (2024): Initial release
  - Basic infrastructure reporting
  - Pool and computer listing

## See Also
- [Lync Server Topology](https://docs.microsoft.com/en-us/skypeforbusiness/plan-your-deployment/topology-basics)
- [Plan for Edge Server](https://docs.microsoft.com/en-us/skypeforbusiness/plan-your-deployment/edge-server-deployments/)
- [Branch-Site Survivability](https://docs.microsoft.com/en-us/skypeforbusiness/plan-your-deployment/enterprise-voice-solution/branch-site)
