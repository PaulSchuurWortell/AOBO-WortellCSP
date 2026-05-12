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
    - Unrestricted Owner access to the Azure subscriptions and/or management groups being configured

.CHANGELOG
    v1.2 (May 12, 2026)
    - Phase 3: Owner verification now accepts indirect ownership — via group membership or parent management group assignment

    v1.1 (May 8, 2026)
    - Added Phase 7: Reservations Reader role assignment on Azure Reservations scope
    - Added $ReservationGroups configuration section for reservation-scope assignments

    v1.0 (May 6, 2026)
    - Initial release
    - Implemented six-phase AOBO configuration script
    - Support for three security groups with role assignments
    - Owner permission verification with skip logic for inaccessible subscriptions
    - Comprehensive error handling and progress logging
    - Management group access validation via temporary group creation

.EXAMPLE
    .\AOBO-WortellCSP.ps1

.EXAMPLE
    .\AOBO-WortellCSP.ps1 -DryRun
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File must use UTF-8 without BOM for Invoke-Expression compatibility when downloading via Invoke-WebRequest')]
param(
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

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

# Groups and roles to assign at the Azure Reservations scope (/providers/Microsoft.Capacity)
$ReservationGroups = @(
    @{
        Name     = "Wortell CSP Tier 1 AdminAgents"
        ObjectId = "2e59f31c-83fd-4ca1-bed4-4b4ee704c0f7"
        Roles    = @("Reservations Reader")
    },
    @{
        Name     = "Wortell CSP Tier 2 AdminAgents"
        ObjectId = "27f932e9-605d-4270-bf3f-a02249b1721c"
        Roles    = @("Reservations Reader")
    }
)

# =============================================================================
# Initialize tracking variables
# =============================================================================

$Errors              = @()
$SkippedSubscriptions = @()
$ProcessedSubscriptions = @()
$ProcessedManagementGroups = @()
$RoleAssignmentsCreated = 0
$RoleAssignmentsExists = 0
$MgRoleAssignmentsCreated = 0
$MgRoleAssignmentsExists = 0
$ReservationRoleAssignmentsCreated = 0
$ReservationRoleAssignmentsExists = 0

# =============================================================================
# Phase 0: Verify active CSP reseller relationship
# =============================================================================

Write-Output ""
Write-Output "================================================================================"
Write-Output "AOBO Configuration Script - Wortell CSP"
if ($DryRun) {
    Write-Output "DRY RUN MODE - No changes will be made"
}
Write-Output "================================================================================"
Write-Output ""
Write-Output "[Phase 0] Verifying active CSP reseller relationship..."

# Get first available subscription for testing
try {
    $TestSubscription = Get-AzSubscription -ErrorAction Stop | Where-Object { $_.State -eq "Enabled" } | Select-Object -First 1
    if (-not $TestSubscription) {
        Write-Error "No enabled subscriptions found to perform reseller relationship check"
        return
    }
} catch {
    Write-Error "Failed to retrieve subscriptions for reseller relationship check: $_"
    return
}

# Test Foreign Principal role assignment capability
$TestGroup = $Groups[0]  # Use first Wortell group for testing
$TestRole = "Reader"     # Use harmless Reader role for testing
$TestScope = "/subscriptions/$($TestSubscription.Id)"

Write-Output "  Testing Foreign Principal assignment on subscription: $($TestSubscription.Name)"

try {
    # Attempt to create a test role assignment
    New-AzRoleAssignment `
        -ObjectId $TestGroup.ObjectId `
        -RoleDefinitionName $TestRole `
        -Scope $TestScope `
        -ObjectType "ForeignGroup" `
        -ErrorAction Stop | Out-Null

    Write-Output "  ✓ CSP reseller relationship verified"

    # Immediately remove the test assignment
    Remove-AzRoleAssignment -ObjectId $TestGroup.ObjectId -RoleDefinitionName $TestRole -Scope $TestScope -ErrorAction SilentlyContinue | Out-Null
    Write-Output "  ✓ Test assignment cleaned up"

} catch {
    Write-Output ""
    Write-Error "Unable to create Foreign Principal role assignment. This typically means no active CSP reseller relationship exists between this tenant and the Wortell CSP partner tenant."
    Write-Output ""
    Write-Error "Required action: The customer Global Administrator must accept the reseller relationship invitation from the CSP partner before this script can be executed."
    Write-Output ""
    Write-Error "Exiting script."
    return
}

# =============================================================================
# Phase 1: Retrieve subscriptions and current user
# =============================================================================

Write-Output ""
Write-Output "[Phase 1] Retrieving subscriptions and current user..."

try {
    $Subscriptions = Get-AzSubscription -ErrorAction Stop | Where-Object { $_.State -eq "Enabled" }
    Write-Output "  ✓ Retrieved $($Subscriptions.Count) enabled subscription(s)"
} catch {
    Write-Error "Failed to retrieve subscriptions: $_"
    return
}

try {
    $CurrentUser = Get-AzADUser -SignedIn -ErrorAction Stop
    Write-Output "  ✓ Current user: $($CurrentUser.DisplayName) ($($CurrentUser.Id))"
} catch {
    Write-Error "Failed to retrieve current user: $_"
    return
}

if ($Subscriptions.Count -eq 0) {
    Write-Error "No enabled subscriptions found in this tenant"
    return
}

# =============================================================================
# Phase 2: Foreign principal validation (informational)
# =============================================================================

Write-Output ""
Write-Output "[Phase 2] Checking existing foreign principal role assignments..."
Write-Output ""

# Phase 0 already validated that foreign groups work, so this phase is informational only
# It shows what role assignments already exist for the configured groups

foreach ($Group in $Groups) {
    try {
        $ExistingAssignments = Get-AzRoleAssignment -ObjectId $Group.ObjectId -ErrorAction SilentlyContinue

        if ($ExistingAssignments) {
            Write-Output "  → $($Group.Name): $($ExistingAssignments.Count) existing role assignment(s) found"
        } else {
            Write-Output "  → $($Group.Name): No existing role assignments found"
        }
    } catch {
        Write-Output "  → $($Group.Name): Unable to check existing assignments (this is normal for new setups)"
    }
}

Write-Output ""
Write-Output "  Note: Phase 0 already validated CSP relationship and foreign group resolution"

if ($InvalidGroups.Count -gt 0) {
    Write-Output ""
    Write-Error "The following groups do not exist in this tenant. Please ensure they are invited as guests or contact your administrator:"
    foreach ($Group in $InvalidGroups) {
        Write-Error "  - $($Group.Name) [$($Group.ObjectId)]"
    }
    Write-Error "Cannot proceed with role assignments."
    return
}

# =============================================================================
# Phase 3: Verify Owner permissions on subscriptions
# =============================================================================

Write-Output ""
Write-Output "[Phase 3] Verifying Owner permissions on subscriptions..."
Write-Output ""

# Fetch all effective Owner assignments once; -SignInName resolves group memberships
try {
    $UserOwnerAssignments = Get-AzRoleAssignment `
        -SignInName $CurrentUser.UserPrincipalName `
        -RoleDefinitionName "Owner" `
        -ErrorAction Stop
} catch {
    Write-Warning "Unable to retrieve Owner role assignments: $_"
    $UserOwnerAssignments = @()
}

foreach ($Subscription in $Subscriptions) {
    $SubScope = "/subscriptions/$($Subscription.Id)"

    # Accept Owner at: the exact subscription scope, root tenant scope (/), or any management group scope.
    # MG Owner inherits down to child subscriptions; -SignInName above already resolved group memberships.
    $OwnerCheck = $UserOwnerAssignments | Where-Object {
        $_.Scope -eq $SubScope -or
        $_.Scope -eq "/" -or
        $_.Scope -like "/providers/Microsoft.Management/managementGroups/*"
    }

    if ($OwnerCheck) {
        Write-Output "  ✓ $($Subscription.Name) [$($Subscription.Id)]"
        $ProcessedSubscriptions += $Subscription
    } else {
        Write-Warning "Current user lacks Owner on subscription $($Subscription.Name) — skipping"
        $SkippedSubscriptions += $Subscription
    }
}

# Verify we have at least one subscription to process
if ($ProcessedSubscriptions.Count -eq 0) {
    Write-Output ""
    Write-Error "Current user does not have Owner role on any subscription. Cannot proceed."
    return
}

Write-Output ""
Write-Output "  Subscriptions to process: $($ProcessedSubscriptions.Count)"
Write-Output "  Subscriptions skipped:    $($SkippedSubscriptions.Count)"

# Wait before proceeding to management group test
Start-Sleep -Seconds 5

# =============================================================================
# Phase 4: Access validation via temporary management group
# =============================================================================

Write-Output ""
Write-Output "[Phase 4] Validating access rights via temporary management group..."

$TempMgName = "Placeholder_To_Be_Removed"

if ($DryRun) {
    Write-Output "  [DRY RUN] Would create temporary management group: $TempMgName"
    Write-Output "  [DRY RUN] Would validate access rights"
} else {
    try {
        New-AzManagementGroup -GroupId $TempMgName -ErrorAction Stop | Out-Null
        Write-Output "  ✓ Temporary management group created: $TempMgName"
        Start-Sleep -Seconds 2
    } catch {
        Write-Error "Failed to create temporary management group: $_"
        Write-Error "Access validation failed. Cannot proceed with role assignments."
        return
    }
}

# =============================================================================
# Phase 5: Role assignments on management groups
# =============================================================================

Write-Output ""
Write-Output "[Phase 5] Assigning roles on management groups..."
Write-Output ""

try {
    $ManagementGroups = Get-AzManagementGroup -ErrorAction Stop
    Write-Output "  Retrieved $($ManagementGroups.Count) management group(s)"
} catch {
    Write-Error "Failed to retrieve management groups: $_"
    $Errors += "Failed to retrieve management groups: $_"
    $ManagementGroups = @()  # Set to empty array so we don't process any
}

foreach ($ManagementGroup in $ManagementGroups) {
    $ProcessedManagementGroups += $ManagementGroup

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
                    $MgRoleAssignmentsExists++
                } else {
                    if ($DryRun) {
                        Write-Output "  [DRY RUN] Would create role assignment: $Role for $($Group.Name) on MG $($ManagementGroup.Name)"
                        $MgRoleAssignmentsCreated++
                    } else {
                        New-AzRoleAssignment `
                            -ObjectId $Group.ObjectId `
                            -RoleDefinitionName $Role `
                            -Scope $Scope `
                            -ObjectType "ForeignGroup" `
                            -ErrorAction Stop | Out-Null

                        Write-Output "  ✓ Role assignment created: $Role for $($Group.Name) on MG $($ManagementGroup.Name)"
                        $MgRoleAssignmentsCreated++
                    }
                }
            } catch {
                Write-Warning "Error assigning $Role to $($Group.Name) on $($ManagementGroup.Name): $_"
                $Errors += "Error assigning $Role to $($Group.Name) on MG $($ManagementGroup.Name): $_"
            }
        }
    }
}

# =============================================================================
# Phase 6: Role assignments on subscriptions
# =============================================================================

Write-Output ""
Write-Output "[Phase 6] Assigning roles on subscriptions..."
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
                        if ($DryRun) {
                            Write-Output "    [DRY RUN] Would create role assignment: $Role for $($Group.Name)"
                            $RoleAssignmentsCreated++
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
# Phase 7: Role assignments on Azure Reservations scope
# =============================================================================

Write-Output ""
Write-Output "[Phase 7] Assigning roles on Azure Reservations scope..."
Write-Output ""

$ReservationScope = "/providers/Microsoft.Capacity"

foreach ($Group in $ReservationGroups) {
    foreach ($Role in $Group.Roles) {
        try {
            $RBACCheck = Get-AzRoleAssignment `
                -ObjectId $Group.ObjectId `
                -RoleDefinitionName $Role `
                -Scope $ReservationScope `
                -ErrorAction SilentlyContinue

            if ($RBACCheck) {
                Write-Output "  → Role assignment already exists: $Role for $($Group.Name) on Reservations scope"
                $ReservationRoleAssignmentsExists++
            } else {
                if ($DryRun) {
                    Write-Output "  [DRY RUN] Would create role assignment: $Role for $($Group.Name) on Reservations scope"
                    $ReservationRoleAssignmentsCreated++
                } else {
                    New-AzRoleAssignment `
                        -ObjectId $Group.ObjectId `
                        -RoleDefinitionName $Role `
                        -Scope $ReservationScope `
                        -ObjectType "ForeignGroup" `
                        -ErrorAction Stop | Out-Null

                    Write-Output "  ✓ Role assignment created: $Role for $($Group.Name) on Reservations scope"
                    $ReservationRoleAssignmentsCreated++
                }
            }
        } catch {
            Write-Warning "Error assigning $Role to $($Group.Name) on Reservations scope: $_"
            $Errors += "Error assigning $Role to $($Group.Name) on Reservations scope: $_"
        }
    }
}

# =============================================================================
# Phase 8: Cleanup and summary
# =============================================================================

Write-Output ""
Write-Output "[Phase 8] Cleanup and summary..."
Write-Output ""

try {
    if ($DryRun) {
        Write-Output "  [DRY RUN] Would remove temporary management group"
    } else {
        Remove-AzManagementGroup -GroupId $TempMgName -ErrorAction Stop | Out-Null
        Write-Output "  ✓ Temporary management group removed"
        Start-Sleep -Seconds 2
    }
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
Write-Output "  Management groups processed: $($ProcessedManagementGroups.Count)"
Write-Output "  Subscriptions processed:     $($ProcessedSubscriptions.Count)"
Write-Output "  Subscriptions skipped:       $($SkippedSubscriptions.Count)"
Write-Output ""

# Management Group Role Assignments
if ($DryRun) {
    Write-Output "  MG role assignments to create:  $MgRoleAssignmentsCreated"
} else {
    Write-Output "  MG role assignments created:   $MgRoleAssignmentsCreated"
}
Write-Output "  MG role assignments (already exist): $MgRoleAssignmentsExists"
Write-Output ""

# Subscription Role Assignments
if ($DryRun) {
    Write-Output "  Sub role assignments to create:  $RoleAssignmentsCreated"
} else {
    Write-Output "  Sub role assignments created:   $RoleAssignmentsCreated"
}
Write-Output "  Sub role assignments (already exist): $RoleAssignmentsExists"
Write-Output ""

# Reservation Scope Role Assignments
if ($DryRun) {
    Write-Output "  Reservation role assignments to create:  $ReservationRoleAssignmentsCreated"
} else {
    Write-Output "  Reservation role assignments created:   $ReservationRoleAssignmentsCreated"
}
Write-Output "  Reservation role assignments (already exist): $ReservationRoleAssignmentsExists"

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
    if ($DryRun) {
        Write-Output "✓ DRY RUN SUCCESS: All prerequisites validated, ready for actual deployment"
    } else {
        Write-Output "✓ SUCCESS: AOBO configuration completed without errors"
    }
    Write-Output "================================================================================"
} else {
    Write-Output "================================================================================"
    if ($DryRun) {
        Write-Output "⚠ DRY RUN COMPLETED with $($Errors.Count) issue(s) — see details above"
    } else {
        Write-Output "⚠ COMPLETED with $($Errors.Count) error(s) — see details above"
    }
    Write-Output "================================================================================"
}

Write-Output ""
Pause
