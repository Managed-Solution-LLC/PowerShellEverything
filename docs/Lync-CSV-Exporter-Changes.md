# Lync CSV Exporter - Version 2.1 Changes & Data Structure Documentation

## Overview
This document outlines the changes made to the Lync CSV Exporter tool to support enhanced data visualization and analysis in web applications. The updates include new export types, enhanced data fields, and improved data structure for better analysis.

## Version Information
- **Version**: 2.1
- **Previous Version**: 2.0
- **Date**: September 19, 2025
- **Author**: W. Ford

---

## 🆕 New Export Options

### 1. Phone Number Export (Option 13)
**File**: `Lync_AllPhoneNumbers_[timestamp].csv`

Comprehensive export of all phone numbers (LineURIs) across the entire Lync environment.

**Data Sources**:
- Regular Users (`Get-CsUser`)
- Common Area Phones (`Get-CsCommonAreaPhone`)
- Analog Devices (`Get-CsAnalogDevice`)
- Meeting Rooms (`Get-CsMeetingRoom`)

**CSV Structure**:
```csv
PhoneNumber,Extension,FullLineURI,AssignedTo,AssignedType,SIPAddress,UserPrincipalName,Pool,VoicePolicy,VoiceEnabled,Enabled,Site,FirstName,LastName,Department,Title,DistinguishedName
```

**Field Descriptions**:
- `PhoneNumber`: Clean phone number (tel: prefix removed)
- `Extension`: Extension number if present
- `FullLineURI`: Complete original LineURI format
- `AssignedTo`: Display name of the assigned entity
- `AssignedType`: Type of assignment (User, Common Area Phone, Fax Machine, etc.)
- `Site`: Extracted from pool/gateway names
- Additional fields for user context and organizational data

**Additional Files Generated**:
- `Lync_DuplicatePhoneNumbers_[timestamp].csv`: Contains duplicate number analysis when duplicates are found

### 2. Site Policy Mappings (Option 12)
**File**: `Lync_SitePolicyMappings_[timestamp].csv`

Maps each Lync site to its assigned policies.

**CSV Structure**:
```csv
SiteIdentity,SiteName,SiteDescription,SiteId,VoicePolicy,ConferencingPolicy,LocationPolicy,ClientPolicy,Pools,CentralSite
```

**Field Descriptions**:
- `SiteIdentity`: Unique site identifier
- `SiteName`: Display name of the site
- `VoicePolicy`: Assigned voice policy or "Not Set (Uses Global)"
- `Pools`: Semicolon-separated list of pools in the site
- `CentralSite`: Central site reference

---

## 📈 Enhanced Export Options

### Voice Policies Export (Enhanced)
**File**: `Lync_VoicePolicies_[timestamp].csv`

**New Fields Added**:
- `Site`: Extracted from policy Identity
- `Scope`: Policy scope (Global, Site, User/Tag, Other)
- `AssignedUsers`: Count of users assigned to each policy
- `PstnUsages`: Semicolon-separated list of PSTN usages

**Enhanced CSV Structure**:
```csv
Identity,Name,Description,Site,Scope,EnableDelegation,EnableTeamCall,EnableCallTransfer,EnableCallPark,EnableMaliciousCallTracing,EnableBWPolicyOverride,PstnUsages,AssignedUsers
```

**Site Extraction Logic**:
- Parses `site:SiteName` format policies
- Identifies Global vs Site vs User/Tag policies
- Attempts to parse site from policy naming patterns
- Provides usage statistics for each policy

---

## 📊 Data Analysis Features

### Phone Number Export Analytics
The phone number export includes built-in analytics:

1. **Summary Statistics**: Breakdown by assignment type
2. **Duplicate Detection**: Automatic identification of duplicate numbers
3. **Number Pattern Analysis**: Common number patterns/ranges
4. **Site Distribution**: Numbers by site/location

### Voice Policy Analytics
Enhanced voice policy export provides:

1. **Scope Summary**: Breakdown by policy scope
2. **Usage Statistics**: Number of assigned users per policy
3. **Site Mapping**: Policy-to-site relationships

---

## 🗂️ File Naming Convention

All CSV files follow the pattern: `Lync_[ExportType]_[timestamp].csv`

**Timestamp Format**: `yyyyMMdd_HHmmss`

**Export Types**:
- `Users_[Type]`: User exports (Summary, Voice, SBA, Complete)
- `CommonAreaPhones`: Common area phone inventory
- `AnalogDevices`: Analog device inventory  
- `IPPhones`: IP phone devices
- `UsbDevices`: USB communication devices
- `RegisteredDevices`: Client/device sessions
- `ClientVersionConfig`: Client version configuration
- `Pools`: Pool information
- `VoicePolicies`: Enhanced voice policies
- `ConferencingPolicies`: Conferencing policies
- `SitePolicyMappings`: Site-to-policy mappings
- `AllPhoneNumbers`: Comprehensive phone number export
- `DuplicatePhoneNumbers`: Duplicate number analysis

---

## 🔄 Web App Integration Guidelines

### Data Import Recommendations

1. **Primary Keys**:
   - Users: `SipAddress` or `UserPrincipalName`
   - Phones: `LineURI` or `SIPAddress`
   - Policies: `Identity`
   - Sites: `SiteIdentity`

2. **Relationship Mapping**:
   - Users → Voice Policies: `VoicePolicy` field
   - Sites → Policies: Use `SitePolicyMappings.csv`
   - Numbers → Assignments: `AssignedTo` and `AssignedType`

3. **Data Types**:
   - Boolean fields: `Enabled`, `VoiceEnabled`, etc.
   - Numeric fields: `AssignedUsers`, `Extension`, `MaxMeetingSize`
   - Array fields: `PstnUsages`, `Services`, `Computers` (semicolon-separated)

### Visualization Opportunities

#### Phone Number Dashboard
- **Number Distribution**: By site, type, assignment
- **Duplicate Analysis**: Visual representation of conflicts
- **Pattern Analysis**: Number range utilization
- **Extension Mapping**: Extension vs. main number correlation

#### Policy Management View
- **Policy Hierarchy**: Global → Site → User policies
- **Usage Statistics**: Policies by assignment count
- **Site Coverage**: Which sites have custom policies
- **Compliance View**: Policy standardization across sites

#### Inventory Management
- **Device Types**: Breakdown of phone/device types
- **Site Distribution**: Hardware distribution across locations
- **Utilization**: Assigned vs. unassigned devices
- **Manufacturer Analysis**: Hardware vendor breakdown

### Sample Queries for Web App

#### Find All Numbers for a Site
```sql
SELECT * FROM PhoneNumbers WHERE Site = 'SiteName'
```

#### Policy Usage Analysis
```sql
SELECT VoicePolicy, COUNT(*) as UserCount 
FROM Users 
WHERE VoiceEnabled = true 
GROUP BY VoicePolicy
```

#### Duplicate Number Detection
```sql
SELECT PhoneNumber, COUNT(*) as Duplicates, 
       GROUP_CONCAT(AssignedTo) as Assignments
FROM PhoneNumbers 
GROUP BY PhoneNumber 
HAVING COUNT(*) > 1
```

---

## 🔧 Technical Changes

### New Functions Added
- `Export-PhoneNumbers()`: Comprehensive phone number export
- `Export-SitePolicyMappings()`: Site-to-policy mapping export

### Enhanced Functions
- `Export-LyncPolicies()`: Added site extraction and usage statistics

### Menu Updates
- Added Option 13: All Phone Numbers (LineURIs)
- Added Option 12: Site Policy Mappings
- Updated Option 14: Export All (now includes new exports)

### Performance Considerations
- Phone number export processes all users, phones, and devices
- Site policy mapping queries each site individually
- Voice policy enhancement includes user counting (may be slow for large environments)

---

## 📋 Data Validation & Quality

### Built-in Data Quality Checks
1. **Duplicate Detection**: Automatic identification in phone numbers
2. **Missing Data Handling**: Graceful handling of null/empty fields
3. **Error Handling**: Continue processing on individual item failures
4. **Data Consistency**: Standardized field naming across exports

### Recommendations for Web App
1. **Data Validation**: Implement client-side validation for imported data
2. **Error Logging**: Track import failures and data quality issues
3. **Data Refresh**: Implement mechanisms to update data from new exports
4. **Backup Strategy**: Maintain historical data for trend analysis

---

## 🎯 Use Cases for Web Application

### IT Administration
- **Number Management**: Track and manage phone number assignments
- **Policy Compliance**: Ensure consistent policy application
- **Inventory Tracking**: Monitor hardware distribution and utilization
- **Change Management**: Track changes over time

### Business Analysis
- **Cost Analysis**: Hardware and licensing utilization
- **Usage Patterns**: Identify underutilized resources
- **Growth Planning**: Forecast needs based on current utilization
- **Compliance Reporting**: Generate regulatory compliance reports

### Operations Management
- **Troubleshooting**: Quick lookup of user configurations
- **Migration Planning**: Data for system migrations
- **Audit Support**: Comprehensive system documentation
- **Capacity Planning**: Resource utilization analysis

---

## 🔮 Future Enhancements

### Planned Features
1. **Real-time Data**: Direct API integration for live data
2. **Change Tracking**: Delta exports for incremental updates
3. **Configuration Backup**: Complete configuration export/import
4. **Health Monitoring**: System health and performance metrics

### Web App Suggestions
1. **Interactive Dashboards**: Real-time visualization of key metrics
2. **Alerting System**: Notifications for duplicates, misconfigurations
3. **Reporting Engine**: Automated report generation
4. **API Integration**: Direct connection to Lync/Skype for Business

---

## 📞 Support & Documentation

For questions about the CSV export tool or data structure, contact:
- **Author**: W. Ford
- **Repository**: PowerShellEveryting/scripts/Assessment/.prep/
- **Documentation**: This file and inline script comments

### Related Files
- `Start-LyncCsvExporter.ps1`: Main export script
- Sample CSV files in output directory
- PowerShell module documentation

---

*Last Updated: September 19, 2025*
*Document Version: 1.0*
