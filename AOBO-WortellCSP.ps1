<#
.SYNOPSIS
    Configure Admin On Behalf Of (AOBO) role assignments on all Azure subscriptions.

.DESCRIPTION
    This script configures AOBO role assignments for Wortell CSP Tier 1 & 2 AdminAgents
    and IngramMicroNL AdminAgents on all subscriptions within a customer tenant.
    
    Based on: IngramMicroNL AOBO scripts
    Reference: https://github.com/IngramMicroNL/Azure/tree/main/AOBO%20-%20AdminOnBehalfOf

.NOTES
    Script:     AOBO-WortellCSP.ps1
    Purpose:    AOBO configuration for Wortell CSP Tier 1 & 2 plus IngramMicroNL
    Author:     Paul Schuur
    Date:       May 6, 2026
    
    Prerequisites:
    - Azure Cloud Shell or local environment with Az PowerShell module
    - Global Administrator rights on the customer tenant
    - Connected to Azure via Connect-AzAccount

.CHANGELOG
    v1.0 (May 6, 2026)
    - Initial release
    - Implemented six-phase AOBO configuration script
    - Support for three security groups with role assignments
    - Owner permission verification with skip logic for inaccessible subscriptions
    - Comprehensive error handling and progress logging
    - Management group access validation via temporary group creation

.EXAMPLE
    .\AOBO-WortellCSP.ps1
#>

# =============================================================================
# Configuration: Groups and Role Assignments
# =============================================================================

$Groups = @(
    @{ 
        Name     = "Wortell CSP Tier 1 AdminAgents"
        ObjectId = "2e59f31c-83fd-4ca1-bed4-4b4ee704c0f7"
        Roles    = @("Owner")
    },
    @{ 
        Name     = "Wortell CSP Tier 2 AdminAgents"
        ObjectId = "27f932e9-605d-4270-bf3f-a02249b1721c"
        Roles    = @("Owner")
    },
    @{ 
        Name     = "IngramMicroNL AdminAgents"
        ObjectId = "34c4dd11-78c0-41e5-8370-c6dbf16bc3e9"
        Roles    = @("Support Request Contributor")
    }
)

# =============================================================================
# Initialize tracking variables
# =============================================================================

$Errors              = @()
$SkippedSubscriptions = @()
$ProcessedSubscriptions = @()
$RoleAssignmentsCreated = 0
$RoleAssignmentsExists = 0

# =============================================================================
# Phase 1: Retrieve subscriptions and current user
# =============================================================================

Write-Output ""
Write-Output "================================================================================"
Write-Output "AOBO Configuration Script - Wortell CSP"
Write-Output "================================================================================"
Write-Output ""
Write-Output "[Phase 1] Retrieving subscriptions and current user..."

try {
    $Subscriptions = Get-AzSubscription -ErrorAction Stop | Where-Object { $_.State -eq "Enabled" }
    Write-Output "  ✓ Retrieved $($Subscriptions.Count) enabled subscription(s)"
} catch {
    Write-Error "Failed to retrieve subscriptions: $_"
    exit 1
}

try {
    $CurrentUser = Get-AzADUser -SignedIn -ErrorAction Stop
    Write-Output "  ✓ Current user: $($CurrentUser.DisplayName) ($($CurrentUser.Id))"
} catch {
    Write-Error "Failed to retrieve current user: $_"
    exit 1
}

if ($Subscriptions.Count -eq 0) {
    Write-Error "No enabled subscriptions found in this tenant"
    exit 1
}

# =============================================================================
# Phase 1.5: Validate group ObjectIds exist in tenant
# =============================================================================

Write-Output ""
Write-Output "[Phase 1.5] Validating group ObjectIds..."
Write-Output ""

$InvalidGroups = @()

foreach ($Group in $Groups) {
    try {
        $GroupCheck = Get-AzADGroup -ObjectId $Group.ObjectId -ErrorAction Stop
        Write-Output "  ✓ $($Group.Name) [$($Group.ObjectId)]"
    } catch {
        Write-Warning "Group not found: $($Group.Name) [$($Group.ObjectId)]"
        $InvalidGroups += $Group
    }
}

if ($InvalidGroups.Count -gt 0) {
    Write-Output ""
    Write-Error "The following groups do not exist in this tenant. Please ensure they are invited as guests or contact your administrator:"
    foreach ($Group in $InvalidGroups) {
        Write-Error "  - $($Group.Name) [$($Group.ObjectId)]"
    }
    Write-Error "Cannot proceed with role assignments."
    exit 1
}

# =============================================================================
# Phase 2: Verify Owner permissions on subscriptions
# =============================================================================

Write-Output ""
Write-Output "[Phase 2] Verifying Owner permissions on subscriptions..."
Write-Output ""

foreach ($Subscription in $Subscriptions) {
    try {
        # Check if the current user has Owner role on this subscription
        $OwnerCheck = Get-AzRoleAssignment `
            -SignInName $CurrentUser.UserPrincipalName `
            -RoleDefinitionName "Owner" `
            -Scope "/subscriptions/$($Subscription.Id)" `
            -ErrorAction SilentlyContinue
        
        if ($OwnerCheck) {
            Write-Output "  ✓ $($Subscription.Name) [$($Subscription.Id)]"
            $ProcessedSubscriptions += $Subscription
        } else {
            Write-Warning "Current user lacks Owner on subscription $($Subscription.Name) — skipping"
            $SkippedSubscriptions += $Subscription
        }
    } catch {
        Write-Warning "Error checking Owner status on $($Subscription.Name): $_"
        $SkippedSubscriptions += $Subscription
    }
}

# Verify we have at least one subscription to process
if ($ProcessedSubscriptions.Count -eq 0) {
    Write-Output ""
    Write-Error "Current user does not have Owner role on any subscription. Cannot proceed."
    exit 1
}

Write-Output ""
Write-Output "  Subscriptions to process: $($ProcessedSubscriptions.Count)"
Write-Output "  Subscriptions skipped:    $($SkippedSubscriptions.Count)"

# Wait before proceeding to management group test
Start-Sleep -Seconds 5

# =============================================================================
# Phase 3: Access validation via temporary management group
# =============================================================================

Write-Output ""
Write-Output "[Phase 3] Validating access rights via temporary management group..."

$TempMgName = "Placeholder_To_Be_Removed"

try {
    New-AzManagementGroup -GroupId $TempMgName -ErrorAction Stop | Out-Null
    Write-Output "  ✓ Temporary management group created: $TempMgName"
    Start-Sleep -Seconds 2
} catch {
    Write-Error "Failed to create temporary management group: $_"
    Write-Error "Access validation failed. Cannot proceed with role assignments."
    exit 1
}

# =============================================================================
# Phase 4: Role assignments on management groups
# =============================================================================

Write-Output ""
Write-Output "[Phase 4] Assigning roles on management groups..."
Write-Output ""

try {
    $ManagementGroups = Get-AzManagementGroup -ErrorAction Stop
    Write-Output "  Retrieved $($ManagementGroups.Count) management group(s)"
} catch {
    Write-Error "Failed to retrieve management groups: $_"
    $Errors += "Failed to retrieve management groups: $_"
}

foreach ($ManagementGroup in $ManagementGroups) {
    foreach ($Group in $Groups) {
        foreach ($Role in $Group.Roles) {
            $Scope = "/providers/Microsoft.Management/managementgroups/$($ManagementGroup.Name)"
            
            try {
                # Check if role assignment already exists
                $RBACCheck = Get-AzRoleAssignment `
                    -ObjectId $Group.ObjectId `
                    -RoleDefinitionName $Role `
                    -Scope $Scope `
                    -ErrorAction SilentlyContinue
                
                if ($RBACCheck) {
                    Write-Output "  → Role assignment already exists: $Role for $($Group.Name) on MG $($ManagementGroup.Name)"
                    $RoleAssignmentsExists++
                } else {
                    New-AzRoleAssignment `
                        -ObjectId $Group.ObjectId `
                        -RoleDefinitionName $Role `
                        -Scope $Scope `
                        -ObjectType "ForeignGroup" `
                        -ErrorAction Stop | Out-Null
                    
                    Write-Output "  ✓ Role assignment created: $Role for $($Group.Name) on MG $($ManagementGroup.Name)"
                    $RoleAssignmentsCreated++
                }
            } catch {
                Write-Warning "Error assigning $Role to $($Group.Name) on $($ManagementGroup.Name): $_"
                $Errors += "Error assigning $Role to $($Group.Name) on MG $($ManagementGroup.Name): $_"
            }
        }
    }
}

# =============================================================================
# Phase 5: Role assignments on subscriptions
# =============================================================================

Write-Output ""
Write-Output "[Phase 5] Assigning roles on subscriptions..."
Write-Output ""

foreach ($Subscription in $ProcessedSubscriptions) {
    try {
        Set-AzContext -SubscriptionId $Subscription.Id -ErrorAction Stop | Out-Null
        Write-Output ""
        Write-Output "  Processing subscription: $($Subscription.Name) [$($Subscription.Id)]"
        
        foreach ($Group in $Groups) {
            foreach ($Role in $Group.Roles) {
                $Scope = "/subscriptions/$($Subscription.Id)"
                
                try {
                    # Check if role assignment already exists
                    $RBACCheck = Get-AzRoleAssignment `
                        -ObjectId $Group.ObjectId `
                        -RoleDefinitionName $Role `
                        -Scope $Scope `
                        -ErrorAction SilentlyContinue
                    
                    if ($RBACCheck) {
                        Write-Output "    → Role assignment already exists: $Role for $($Group.Name)"
                        $RoleAssignmentsExists++
                    } else {
                        New-AzRoleAssignment `
                            -ObjectId $Group.ObjectId `
                            -RoleDefinitionName $Role `
                            -Scope $Scope `
                            -ObjectType "ForeignGroup" `
                            -ErrorAction Stop | Out-Null
                        
                        Write-Output "    ✓ Role assignment created: $Role for $($Group.Name)"
                        $RoleAssignmentsCreated++
                    }
                } catch {
                    Write-Warning "    Error assigning $Role to $($Group.Name): $_"
                    $Errors += "Error assigning $Role to $($Group.Name) on subscription $($Subscription.Name): $_"
                }
            }
        }
    } catch {
        Write-Error "Failed to switch context to subscription $($Subscription.Name): $_"
        $Errors += "Failed to switch context to subscription $($Subscription.Name): $_"
    }
}

# =============================================================================
# Phase 6: Cleanup and summary
# =============================================================================

Write-Output ""
Write-Output "[Phase 6] Cleanup and summary..."
Write-Output ""

try {
    Remove-AzManagementGroup -GroupId $TempMgName -ErrorAction Stop | Out-Null
    Write-Output "  ✓ Temporary management group removed"
    Start-Sleep -Seconds 2
} catch {
    Write-Warning "Failed to remove temporary management group: $_"
    $Errors += "Failed to remove temporary management group: $_"
}

# =============================================================================
# Display summary
# =============================================================================

Write-Output ""
Write-Output "================================================================================"
Write-Output "Summary"
Write-Output "================================================================================"
Write-Output "  Subscriptions processed:     $($ProcessedSubscriptions.Count)"
Write-Output "  Subscriptions skipped:       $($SkippedSubscriptions.Count)"
Write-Output "  Role assignments created:   $RoleAssignmentsCreated"
Write-Output "  Role assignments (already exist): $RoleAssignmentsExists"

if ($SkippedSubscriptions.Count -gt 0) {
    Write-Output ""
    Write-Output "  Skipped subscriptions:"
    foreach ($Sub in $SkippedSubscriptions) {
        Write-Output "    - $($Sub.Name) [$($Sub.Id)]"
    }
}

if ($Errors.Count -gt 0) {
    Write-Output ""
    Write-Output "  Errors encountered:"
    foreach ($ErrorMessage in $Errors) {
        Write-Output "    - $ErrorMessage"
    }
}

Write-Output ""

if ($Errors.Count -eq 0) {
    Write-Output "================================================================================"
    Write-Output "✓ SUCCESS: AOBO configuration completed without errors"
    Write-Output "================================================================================"
} else {
    Write-Output "================================================================================"
    Write-Output "⚠ COMPLETED with $($Errors.Count) error(s) — see details above"
    Write-Output "================================================================================"
}

Write-Output ""
Pause
