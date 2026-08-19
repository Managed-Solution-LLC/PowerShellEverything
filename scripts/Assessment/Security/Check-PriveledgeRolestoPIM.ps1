<#
.SYNOPSIS
    Assess Azure AD privileged role assignments for PIM conversion recommendations.

.DESCRIPTION
    This script analyzes current permanent privileged role assignments in Azure AD,
    checks if they've been utilized, and provides recommendations for which roles
    can be converted to eligible (PIM) assignments vs. remaining permanent.
    Designed to run in Azure CLI Cloud Shell.

.PARAMETER OutputPath
    Path where the assessment spreadsheet will be saved. Defaults to current directory.

.PARAMETER IncludeUnusedOnly
    Only show roles that haven't been used recently (candidates for removal or PIM).

.EXAMPLE
    .\Check-PriveledgeRolestoPIM.ps1 -OutputPath "~/pim-assessment.csv"

.NOTES
    Requires: Azure CLI with Microsoft Graph permissions
    Author: Managed Solution LLC
    Date: December 2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "~/PIM-Assessment-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeUnusedOnly,
    
    [Parameter(Mandatory = $false)]
    [int]$DaysToCheckUsage = 30,
    
    [Parameter(Mandatory = $false)]
    [string]$BreakGlassGroupName = "",
    
    [Parameter(Mandatory = $false)]
    [string[]]$BreakGlassAccountUPNs = @(),
    
    [Parameter(Mandatory = $false)]
    [string]$BreakGlassNamingPattern = "^(BG-|BreakGlass|Break Glass|Emergency|EMERGENCY-).*",
    
    [Parameter(Mandatory = $false)]
    [int]$BreakGlassAccountAgeMinDays = 180
)

# Ensure we're logged in to Azure CLI
Write-Host "Checking Azure CLI authentication..." -ForegroundColor Cyan
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Host "Please login to Azure CLI first: az login" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Connected to tenant: $($account.tenantId)" -ForegroundColor Green
} catch {
    Write-Host "Error checking Azure CLI authentication. Please run: az login" -ForegroundColor Red
    exit 1
}

# Check current user's permissions
Write-Host "Checking current user and permissions..." -ForegroundColor Cyan
$currentUser = az ad signed-in-user show | ConvertFrom-Json
Write-Host "Signed in as: $($currentUser.userPrincipalName)" -ForegroundColor Green

# Test Graph API permissions by attempting to read sign-in activity
Write-Host "Testing Microsoft Graph API permissions..." -ForegroundColor Cyan
try {
    $testUri = "https://graph.microsoft.com/beta/users/$($currentUser.id)?`$select=signInActivity"
    $testResult = az rest --method GET --uri $testUri 2>$null | ConvertFrom-Json
    if ($testResult) {
        Write-Host "✓ Sign-in activity access: Available" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠ Sign-in activity access: Limited - Will use alternative data sources" -ForegroundColor Yellow
    Write-Host "  Note: Full sign-in data requires AuditLog.Read.All or Directory.Read.All permissions" -ForegroundColor DarkGray
}

# Get Break Glass group members if group name is provided
Write-Host "`nConfiguring Break Glass account detection..." -ForegroundColor Cyan
$breakGlassGroupMembers = @()
if ($BreakGlassGroupName) {
    Write-Host "Looking for Break Glass group: $BreakGlassGroupName" -ForegroundColor Yellow
    try {
        $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$BreakGlassGroupName'"
        $groupResult = az rest --method GET --uri $groupUri | ConvertFrom-Json
        
        if ($groupResult.value.Count -gt 0) {
            $groupId = $groupResult.value[0].id
            $membersUri = "https://graph.microsoft.com/v1.0/groups/$groupId/members"
            $members = az rest --method GET --uri $membersUri | ConvertFrom-Json
            $breakGlassGroupMembers = $members.value | ForEach-Object { $_.id }
            Write-Host "✓ Found $($breakGlassGroupMembers.Count) members in Break Glass group" -ForegroundColor Green
        } else {
            Write-Host "⚠ Break Glass group '$BreakGlassGroupName' not found" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠ Could not retrieve Break Glass group members: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Display Break Glass detection configuration
Write-Host "Break Glass Detection Methods:" -ForegroundColor Cyan
Write-Host "  1. Group Membership: $(if ($breakGlassGroupMembers.Count -gt 0) { "✓ $($breakGlassGroupMembers.Count) accounts" } else { '✗ Not configured' })" -ForegroundColor $(if ($breakGlassGroupMembers.Count -gt 0) { 'Green' } else { 'DarkGray' })
Write-Host "  2. Explicit UPN List: $(if ($BreakGlassAccountUPNs.Count -gt 0) { "✓ $($BreakGlassAccountUPNs.Count) accounts" } else { '✗ Not configured' })" -ForegroundColor $(if ($BreakGlassAccountUPNs.Count -gt 0) { 'Green' } else { 'DarkGray' })
Write-Host "  3. Naming Pattern: ✓ Regex pattern configured" -ForegroundColor Green
Write-Host "  4. Account Age: ✓ Checking for accounts older than $BreakGlassAccountAgeMinDays days with no sign-ins" -ForegroundColor Green
Write-Host "  5. MFA Status: ✓ Checking MFA configuration" -ForegroundColor Green

# Get all directory roles
Write-Host "`nFetching Azure AD directory roles..." -ForegroundColor Cyan
$roles = az rest --method GET --uri "https://graph.microsoft.com/v1.0/directoryRoles" | ConvertFrom-Json

$assessmentResults = @()
$signInDataMissing = 0

foreach ($role in $roles.value) {
    Write-Host "Processing role: $($role.displayName)" -ForegroundColor Yellow
    
    # Get members of this role
    $members = az rest --method GET --uri "https://graph.microsoft.com/v1.0/directoryRoles/$($role.id)/members" | ConvertFrom-Json
    
    foreach ($member in $members.value) {
        # Get role assignment details
        $assignmentUri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=roleDefinitionId eq '$($role.roleTemplateId)' and principalId eq '$($member.id)'"
        $assignments = az rest --method GET --uri $assignmentUri | ConvertFrom-Json
        
        foreach ($assignment in $assignments.value) {
            # Check if it's a permanent or eligible assignment
            $assignmentType = if ($assignment.assignmentType -eq 'Assigned') { 'Permanent' } else { 'Eligible' }
            
            # Get sign-in activity for the user (if it's a user)
            $lastSignIn = $null
            $daysSinceSignIn = $null
            $hasRecentActivity = $false
            $signInDataSource = 'N/A'
            $isBreakGlassAccount = $false
            $breakGlassDetectionMethod = @()
            $accountCreatedDate = $null
            $accountAgeDays = $null
            $mfaStatus = 'Unknown'
            
            if ($member.'@odata.type' -eq '#microsoft.graph.user') {
                try {
                    # Try to get comprehensive sign-in data from beta endpoint
                    $signInUri = "https://graph.microsoft.com/beta/users/$($member.id)?`$select=signInActivity,userPrincipalName,displayName,createdDateTime"
                    $userDetails = az rest --method GET --uri $signInUri 2>$null | ConvertFrom-Json
                    
                    # Get account creation date
                    if ($userDetails.createdDateTime) {
                        $accountCreatedDate = [datetime]$userDetails.createdDateTime
                        $accountAgeDays = [math]::Round((New-TimeSpan -Start $accountCreatedDate -End (Get-Date)).TotalDays, 0)
                    }
                    
                    # Get MFA/authentication methods
                    try {
                        $authMethodsUri = "https://graph.microsoft.com/beta/users/$($member.id)/authentication/methods"
                        $authMethods = az rest --method GET --uri $authMethodsUri 2>$null | ConvertFrom-Json
                        $mfaMethodCount = ($authMethods.value | Where-Object { $_.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod' }).Count
                        $mfaStatus = if ($mfaMethodCount -eq 0) { 'No MFA' } elseif ($mfaMethodCount -eq 1) { '1 Method' } else { "$mfaMethodCount Methods" }
                    } catch {
                        $mfaStatus = 'Unable to Check'
                    }
                    
                    if ($userDetails.signInActivity) {
                        # Check both interactive and non-interactive sign-ins
                        $interactiveSignIn = $userDetails.signInActivity.lastSignInDateTime
                        $nonInteractiveSignIn = $userDetails.signInActivity.lastNonInteractiveSignInDateTime
                        
                        # Use the most recent sign-in
                        if ($interactiveSignIn -and $nonInteractiveSignIn) {
                            $interactiveDate = [datetime]$interactiveSignIn
                            $nonInteractiveDate = [datetime]$nonInteractiveSignIn
                            
                            if ($interactiveDate -gt $nonInteractiveDate) {
                                $lastSignIn = $interactiveSignIn
                                $signInDataSource = 'Interactive'
                            } else {
                                $lastSignIn = $nonInteractiveSignIn
                                $signInDataSource = 'Non-Interactive'
                            }
                        } elseif ($interactiveSignIn) {
                            $lastSignIn = $interactiveSignIn
                            $signInDataSource = 'Interactive'
                        } elseif ($nonInteractiveSignIn) {
                            $lastSignIn = $nonInteractiveSignIn
                            $signInDataSource = 'Non-Interactive'
                        }
                        
                        if ($lastSignIn) {
                            $daysSinceSignIn = [math]::Round((New-TimeSpan -Start ([datetime]$lastSignIn) -End (Get-Date)).TotalDays, 0)
                            $hasRecentActivity = $daysSinceSignIn -le $DaysToCheckUsage
                        }
                    } else {
                        $signInDataMissing++
                        $signInDataSource = 'Unavailable'
                        Write-Host "  ⚠ No sign-in data available for $($member.displayName)" -ForegroundColor DarkGray
                    }
                } catch {
                    $signInDataMissing++
                    $signInDataSource = 'Error'
                    Write-Host "  ⚠ Could not retrieve sign-in activity for $($member.displayName)" -ForegroundColor DarkGray
                }
                
                # Check if this is a Break Glass account using multiple methods
                # Method 1: Group membership
                if ($breakGlassGroupMembers -contains $member.id) {
                    $isBreakGlassAccount = $true
                    $breakGlassDetectionMethod += 'Group Membership'
                }
                
                # Method 2: Explicit UPN list
                if ($BreakGlassAccountUPNs -contains $member.userPrincipalName) {
                    $isBreakGlassAccount = $true
                    $breakGlassDetectionMethod += 'Explicit UPN List'
                }
                
                # Method 3: Naming pattern
                if ($member.displayName -match $BreakGlassNamingPattern -or $member.userPrincipalName -match $BreakGlassNamingPattern) {
                    $isBreakGlassAccount = $true
                    $breakGlassDetectionMethod += 'Naming Pattern'
                }
                
                # Method 4: Account age + no sign-ins (likely break glass)
                if ($accountAgeDays -ge $BreakGlassAccountAgeMinDays -and ($null -eq $daysSinceSignIn -or $daysSinceSignIn -ge $BreakGlassAccountAgeMinDays)) {
                    $isBreakGlassAccount = $true
                    $breakGlassDetectionMethod += 'Account Age + No Activity'
                }
                
                # Method 5: No MFA configured (common for break glass accounts)
                if ($mfaStatus -eq 'No MFA' -and $accountAgeDays -ge 90) {
                    $breakGlassDetectionMethod += 'No MFA Configured'
                }
            }
            
            # Determine recommendation
            $recommendation = if ($assignmentType -eq 'Permanent') {
                if ($member.'@odata.type' -eq '#microsoft.graph.servicePrincipal') {
                    'Keep Permanent (Service Principal)'
                } elseif ($isBreakGlassAccount) {
                    "Keep Permanent (Break Glass: $($breakGlassDetectionMethod -join ', '))"
                } elseif ($hasRecentActivity) {
                    'Convert to Eligible (PIM) - Active User'
                } elseif ($null -ne $daysSinceSignIn -and $daysSinceSignIn -gt 90) {
                    'Review - Inactive User (Consider Removal)'
                } elseif ($signInDataSource -eq 'Unavailable' -or $signInDataSource -eq 'Error') {
                    'Convert to Eligible (PIM) - Sign-in Data Unavailable'
                } else {
                    'Convert to Eligible (PIM)'
                }
            } else {
                'Already Eligible (PIM)'
            }
            
            # Check if PIM license is available
            $pimEligible = $true  # Assume yes, can be enhanced with license check
            
            $assessmentResults += [PSCustomObject]@{
                RoleName = $role.displayName
                MemberName = $member.displayName
                MemberType = $member.'@odata.type'.Replace('#microsoft.graph.', '')
                MemberUPN = if ($member.userPrincipalName) { $member.userPrincipalName } else { 'N/A' }
                AssignmentType = $assignmentType
                LastSignIn = if ($lastSignIn) { ([datetime]$lastSignIn).ToString('yyyy-MM-dd HH:mm:ss') } else { 'N/A' }
                DaysSinceSignIn = if ($null -ne $daysSinceSignIn) { $daysSinceSignIn } else { 'N/A' }
                SignInType = $signInDataSource
                HasRecentActivity = $hasRecentActivity
                IsBreakGlass = $isBreakGlassAccount
                BreakGlassDetectionMethod = if ($breakGlassDetectionMethod.Count -gt 0) { $breakGlassDetectionMethod -join '; ' } else { 'N/A' }
                AccountAgeDays = if ($null -ne $accountAgeDays) { $accountAgeDays } else { 'N/A' }
                MFAStatus = $mfaStatus
                PIMEligible = $pimEligible
                Recommendation = $recommendation
                AssignmentId = $assignment.id
                RoleId = $role.id
            }
        }
    }
}

# Filter results if requested
if ($IncludeUnusedOnly) {
    $assessmentResults = $assessmentResults | Where-Object { 
        $_.Recommendation -like '*Convert*' -or $_.Recommendation -like '*Review*' 
    }
}

# Display summary
Write-Host "`n========== PIM Assessment Summary ==========" -ForegroundColor Cyan
Write-Host "Total role assignments analyzed: $($assessmentResults.Count)" -ForegroundColor White

$permanentCount = ($assessmentResults | Where-Object { $_.AssignmentType -eq 'Permanent' }).Count
$eligibleCount = ($assessmentResults | Where-Object { $_.AssignmentType -eq 'Eligible' }).Count
$convertRecommended = ($assessmentResults | Where-Object { $_.Recommendation -like '*Convert*' }).Count
$reviewRecommended = ($assessmentResults | Where-Object { $_.Recommendation -like '*Review*' }).Count
$breakGlassCount = ($assessmentResults | Where-Object { $_.IsBreakGlass -eq $true }).Count

Write-Host "Permanent assignments: $permanentCount" -ForegroundColor Yellow
Write-Host "Eligible (PIM) assignments: $eligibleCount" -ForegroundColor Green
Write-Host "Break Glass accounts detected: $breakGlassCount" -ForegroundColor Magenta
Write-Host "Recommended for PIM conversion: $convertRecommended" -ForegroundColor Cyan
Write-Host "Recommended for review/removal: $reviewRecommended" -ForegroundColor Magenta
Write-Host "============================================`n" -ForegroundColor Cyan

# Export to CSV
if ($assessmentResults.Count -gt 0) {
    $assessmentResults | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Host "Assessment report exported to: $OutputPath" -ForegroundColor Green
    
    # Display top recommendations
    Write-Host "`nTop 10 Recommendations:" -ForegroundColor Cyan
    $assessmentResults | Where-Object { $_.Recommendation -like '*Convert*' } | 
        Select-Object -First 10 RoleName, MemberName, AssignmentType, DaysSinceSignIn, Recommendation |
        Format-Table -AutoSize
} else {
    Write-Host "No role assignments found." -ForegroundColor Yellow
}

Write-Host "`nScript completed successfully!" -ForegroundColor Green