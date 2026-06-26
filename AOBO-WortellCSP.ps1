<#
.SYNOPSIS
    Configure Admin On Behalf Of (AOBO) role assignments on all Azure subscriptions.

.DESCRIPTION
    This script configures AOBO role assignments for Wortell CSP Tier 1 & 2 AdminAgents
    and IngramMicroNL AdminAgents on all subscriptions and management groups within a
    customer tenant.

    Based on: IngramMicroNL AOBO scripts
    Reference: https://github.com/IngramMicroNL/Azure/tree/main/AOBO%20-%20AdminOnBehalfOf

.NOTES
    Script:     AOBO-WortellCSP.ps1
    Purpose:    AOBO configuration for Wortell CSP Tier 1 & 2 plus IngramMicroNL
    Author:     Paul Schuur
    Date:       May 6, 2026

    Prerequisites:
    - Azure Cloud Shell or local environment with Az PowerShell module
    - Owner or User Access Administrator at root management group scope
    - Connected to Azure via Connect-AzAccount
    - Active GDAP relationship with Wortell and Ingram Micro

.CHANGELOG
    v1.6 (June 26, 2026)
    - Added -Subscription parameter: limit Phase 3 to one or more specific subscriptions (name or ID)
    - Added -ManagementGroup parameter: limit Phase 2 to one or more specific management groups (name or display name)
    - Banner shows active targeting filters when either parameter is used
    - Unknown subscription/MG names emit a warning and are skipped

    v1.5 (June 25, 2026)
    - Phase 2/3: idempotency check now filters to exact scope (Where-Object Scope -eq) so inherited
      MG-level assignments no longer prevent creating direct subscription-level assignments
    - Phase 2/3: RoleAssignmentExists/already exists caught explicitly and treated as success
      (increments exists counter) rather than falling through to $Errors

    v1.4 (June 12, 2026)
    - Simplified from 9 phases to 4: Discover, Assign MGs, Assign subscriptions, Assign Reservations
    - Removed pre-flight validation phases; assignments now fail gracefully per principal and scope
    - PrincipalNotFound in any assignment excludes the group from all remaining phases (no retry)
    - AuthorizationFailed on any assignment is a non-blocking warning, not an error
    - Replaced -SkipPrincipalCheck with -PrincipalCheck (opt-in pre-validation before Phase 2)
    - Replaced -SkipOwnerCheck with -OwnerCheck (opt-in Owner access filter before Phase 2)
    - Removed temporary management group creation/cleanup entirely
    - Unified $Errors (hard failures) and $Warnings (access-denied, reservations) in summary

    v1.3 (June 11, 2026)
    - Added -SkipPrincipalCheck switch to bypass Phase 0 foreign principal validation

    v1.3 (June 9, 2026)
    - Phase 0: Non-aborting group availability check — all foreign principals are tested;
      validated ones collected in $ValidatedGroups; script only aborts if zero principals pass
    - Phase 5/6: Role assignments now iterate $ValidatedGroups instead of $Groups
    - Phase 7: Iterates $ValidatedReservationGroups; failures collected in $ReservationWarnings
    - Phase 8: Reservation warnings shown in a separate summary section

    v1.2 (May 12, 2026)
    - Phase 0: CSP relationship check now tests all foreign principals
    - Phase 3: Owner verification now accepts indirect ownership via group or parent MG
    - Phase 3: Added -SkipOwnerCheck switch

    v1.1 (May 8, 2026)
    - Added Phase 7: Reservations Reader role assignment on Azure Reservations scope
    - Added $ReservationGroups configuration section

    v1.0 (May 6, 2026)
    - Initial release

.EXAMPLE
    .\AOBO-WortellCSP.ps1

.EXAMPLE
    .\AOBO-WortellCSP.ps1 -DryRun
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File must use UTF-8 without BOM for Invoke-Expression compatibility when downloading via Invoke-WebRequest')]
param(
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    # Opt-in: validate that each foreign principal can receive a test assignment before Phase 2.
    # Failed principals are excluded from all role assignments.
    # Use when GDAP registration is uncertain and you want an early warning.
    # Omit if GDAP is confirmed but the test-assignment itself fails due to API limitations.
    [Parameter(Mandatory = $false)]
    [switch]$PrincipalCheck,

    # Opt-in: verify the running account has Owner on each subscription before Phase 3.
    # Subscriptions without confirmed Owner access are skipped.
    # Omit to attempt all subscriptions and let access-denied results appear as warnings.
    [Parameter(Mandatory = $false)]
    [switch]$OwnerCheck,

    # Limit Phase 3 to one or more specific subscriptions (by name or ID).
    # Omit to process all enabled subscriptions.
    [Parameter(Mandatory = $false)]
    [string[]]$Subscription,

    # Limit Phase 2 to one or more specific management groups (by name or display name).
    # Omit to process all management groups.
    [Parameter(Mandatory = $false)]
    [string[]]$ManagementGroup
)

# =============================================================================
# Version
# =============================================================================

$Version = "20260626004"

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

$Errors                            = @()
$Warnings                          = @()
$SkippedPrincipalIds               = @()
$SkippedSubscriptions              = @()
$ProcessedSubscriptions            = @()
$ProcessedManagementGroups         = @()
$RoleAssignmentsCreated            = 0
$RoleAssignmentsExists             = 0
$MgRoleAssignmentsCreated          = 0
$MgRoleAssignmentsExists           = 0
$ReservationRoleAssignmentsCreated = 0
$ReservationRoleAssignmentsExists  = 0

# =============================================================================
# Banner
# =============================================================================

Write-Output ""
Write-Output "================================================================================"
Write-Output "AOBO Configuration Script - Wortell CSP  (version $Version)"
if ($DryRun) {
    Write-Output "DRY RUN MODE - No changes will be made"
}
if ($Subscription -or $ManagementGroup) {
    Write-Output "TARGETED MODE"
    if ($Subscription)    { Write-Output "  Subscriptions:     $($Subscription    -join ', ')" }
    if ($ManagementGroup) { Write-Output "  Management groups: $($ManagementGroup -join ', ')" }
}
Write-Output "================================================================================"
Write-Output ""

# =============================================================================
# Phase 1: Discover subscriptions, identity, and optional pre-checks
# =============================================================================

Write-Output "[Phase 1] Discovering environment..."

try {
    $Subscriptions = Get-AzSubscription -ErrorAction Stop | Where-Object { $_.State -eq "Enabled" }
    Write-Output "  ✓ $($Subscriptions.Count) enabled subscription(s)"
} catch {
    Write-Error "Failed to retrieve subscriptions: $_"
    return
}

try {
    $CurrentUser = Get-AzADUser -SignedIn -ErrorAction Stop
    Write-Output "  ✓ Current user: $($CurrentUser.DisplayName) ($($CurrentUser.UserPrincipalName))"
} catch {
    Write-Error "Failed to retrieve current user: $_"
    return
}

if ($Subscriptions.Count -eq 0) {
    Write-Error "No enabled subscriptions found in this tenant"
    return
}

# --- Targeting filter: limit to specific subscriptions (-Subscription) ---
if ($Subscription) {
    $MatchedSubs = @($Subscriptions | Where-Object { $_.Id -in $Subscription -or $_.Name -in $Subscription })
    foreach ($s in ($Subscription | Where-Object { $_ -notin $Subscriptions.Id -and $_ -notin $Subscriptions.Name })) {
        Write-Warning "  Subscription not found: '$s'"
    }
    if ($MatchedSubs.Count -eq 0) {
        Write-Error "No matching subscriptions found for the specified -Subscription filter."
        return
    }
    Write-Output "  Targeting $($MatchedSubs.Count) of $($Subscriptions.Count) subscription(s)"
    $Subscriptions = $MatchedSubs
}

# Active groups default to the full configured lists; -PrincipalCheck may filter them
$ActiveGroups            = $Groups
$ActiveReservationGroups = $ReservationGroups

# --- Optional: Validate foreign principals (-PrincipalCheck) ---

if ($PrincipalCheck) {
    Write-Output ""
    Write-Output "  [PrincipalCheck] Validating foreign principals..."

    $TestSubscription   = $Subscriptions | Select-Object -First 1
    $TestRole           = "Reader"
    $TestScope          = "/subscriptions/$($TestSubscription.Id)"
    $AllForeignGroups   = ($Groups + $ReservationGroups) | Sort-Object -Property ObjectId -Unique
    $ValidatedObjectIds = @()

    Write-Output "  Testing on subscription: $($TestSubscription.Name)"

    foreach ($Group in $AllForeignGroups) {
        try {
            New-AzRoleAssignment `
                -ObjectId $Group.ObjectId `
                -RoleDefinitionName $TestRole `
                -Scope $TestScope `
                -ObjectType "ForeignGroup" `
                -ErrorAction Stop | Out-Null

            Write-Verbose "  ✓ $($Group.Name)"
            $ValidatedObjectIds += $Group.ObjectId
            Remove-AzRoleAssignment -ObjectId $Group.ObjectId -RoleDefinitionName $TestRole -Scope $TestScope -ErrorAction SilentlyContinue | Out-Null

        } catch {
            Write-Verbose "  Exception for '$($Group.Name)': $($_.Exception)"

            if ($_.Exception.Message -like "*RoleAssignmentExists*" -or $_.Exception.Message -like "*already exists*") {
                Write-Verbose "  ✓ $($Group.Name) — assignment already exists"
                $ValidatedObjectIds += $Group.ObjectId
            } elseif ($_.Exception.Message -like "*AuthorizationFailed*") {
                Write-Warning "  ✗ $($Group.Name) — authorization failed on '$($TestSubscription.Name)'. Group excluded."
            } else {
                Write-Warning "  ✗ $($Group.Name) [$($Group.ObjectId)] — $($_.Exception.Message). Group excluded."
            }
        }
    }

    if ($ValidatedObjectIds.Count -eq 0) {
        Write-Error "No foreign principals could be validated. Ensure an active GDAP relationship exists."
        return
    }

    if ($ValidatedObjectIds.Count -lt $AllForeignGroups.Count) {
        Write-Warning "  $($AllForeignGroups.Count - $ValidatedObjectIds.Count) of $($AllForeignGroups.Count) foreign principal(s) excluded."
    }

    Write-Output "  ✓ $($ValidatedObjectIds.Count) of $($AllForeignGroups.Count) foreign principals confirmed"

    $ActiveGroups            = $Groups            | Where-Object { $_.ObjectId -in $ValidatedObjectIds }
    $ActiveReservationGroups = $ReservationGroups | Where-Object { $_.ObjectId -in $ValidatedObjectIds }
}

# --- Optional: Verify Owner access per subscription (-OwnerCheck) ---

if ($OwnerCheck) {
    Write-Output ""
    Write-Output "  [OwnerCheck] Verifying Owner access on subscriptions..."

    $HasMgOwner = $false
    try {
        $AllMGs = Get-AzManagementGroup -ErrorAction Stop
        foreach ($MG in $AllMGs) {
            $MgScope = "/providers/Microsoft.Management/managementGroups/$($MG.Name)"
            $MgCheck = Get-AzRoleAssignment `
                -SignInName $CurrentUser.UserPrincipalName `
                -RoleDefinitionName "Owner" `
                -Scope $MgScope `
                -ErrorAction SilentlyContinue
            if ($MgCheck) {
                $HasMgOwner = $true
                Write-Output "  ✓ Owner at management group: $($MG.DisplayName) — all subscriptions accepted"
                break
            }
        }
    } catch {
        Write-Warning "  Unable to query management group role assignments: $_"
    }

    foreach ($Sub in $Subscriptions) {
        $SubScope    = "/subscriptions/$($Sub.Id)"
        $OwnerAssign = Get-AzRoleAssignment `
            -SignInName $CurrentUser.UserPrincipalName `
            -RoleDefinitionName "Owner" `
            -Scope $SubScope `
            -ErrorAction SilentlyContinue

        if ($OwnerAssign -or $HasMgOwner) {
            Write-Verbose "  ✓ $($Sub.Name)"
            $ProcessedSubscriptions += $Sub
        } else {
            Write-Warning "  Owner not confirmed on $($Sub.Name) — skipping"
            $SkippedSubscriptions += $Sub
        }
    }

    if ($ProcessedSubscriptions.Count -eq 0) {
        Write-Error "No accessible subscriptions found. Cannot proceed."
        return
    }

    Write-Output "  Subscriptions to process: $($ProcessedSubscriptions.Count) (skipped: $($SkippedSubscriptions.Count))"
} else {
    $ProcessedSubscriptions = @($Subscriptions)
}

# =============================================================================
# Phase 2: Assign roles on management groups
# =============================================================================

Write-Output ""
Write-Output "[Phase 2] Assigning roles on management groups..."

if ($Subscription -and -not $ManagementGroup) {
    Write-Output "  Skipped — subscription-only targeting active"
} else {
if ($ManagementGroup) {
    # Fetch each specified MG directly by name to avoid requiring list-all permission.
    # Falls back to list-all only for values not found by name, to support display names.
    $ManagementGroups = @()
    $NeedDisplayLookup = @()
    foreach ($MgFilter in $ManagementGroup) {
        try {
            $ManagementGroups += Get-AzManagementGroup -GroupName $MgFilter -ErrorAction Stop
        } catch {
            $NeedDisplayLookup += $MgFilter
        }
    }
    if ($NeedDisplayLookup) {
        try {
            $AllManagementGroups = Get-AzManagementGroup -ErrorAction Stop
            foreach ($MgFilter in $NeedDisplayLookup) {
                $Matched = @($AllManagementGroups | Where-Object { $_.DisplayName -eq $MgFilter })
                if ($Matched.Count -gt 1) {
                    Write-Warning "  '$MgFilter' matches $($Matched.Count) management groups — all will be targeted"
                } elseif ($Matched.Count -eq 0) {
                    Write-Warning "  Management group not found: '$MgFilter'"
                }
                $ManagementGroups += $Matched
            }
        } catch {
            foreach ($MgFilter in $NeedDisplayLookup) {
                Write-Warning "  Management group not found: '$MgFilter'"
            }
        }
    }
    Write-Output "  Targeting $($ManagementGroups.Count) management group(s)"
} else {
    try {
        $ManagementGroups = @(Get-AzManagementGroup -ErrorAction Stop)
        Write-Output "  $($ManagementGroups.Count) management group(s) found"
    } catch {
        Write-Error "Failed to retrieve management groups: $_"
        $Errors += "Failed to retrieve management groups: $_"
        $ManagementGroups = @()
    }
}

foreach ($MG in $ManagementGroups) {
    $ProcessedManagementGroups += $MG
    $MgScope = "/providers/Microsoft.Management/managementgroups/$($MG.Name)"

    foreach ($Group in $ActiveGroups) {
        if ($Group.ObjectId -in $SkippedPrincipalIds) { continue }

        foreach ($Role in $Group.Roles) {
            try {
                $RBACCheck = Get-AzRoleAssignment `
                    -ObjectId $Group.ObjectId `
                    -RoleDefinitionName $Role `
                    -Scope $MgScope `
                    -ErrorAction SilentlyContinue |
                    Where-Object { $_.Scope -eq $MgScope }

                if ($RBACCheck) {
                    Write-Verbose "  → Already exists: $Role for $($Group.Name) on $($MG.DisplayName)"
                    $MgRoleAssignmentsExists++
                } elseif ($DryRun) {
                    Write-Verbose "  [DRY RUN] Would assign: $Role for $($Group.Name) on $($MG.DisplayName)"
                    $MgRoleAssignmentsCreated++
                } else {
                    New-AzRoleAssignment `
                        -ObjectId $Group.ObjectId `
                        -RoleDefinitionName $Role `
                        -Scope $MgScope `
                        -ObjectType "ForeignGroup" `
                        -ErrorAction Stop | Out-Null

                    Write-Verbose "  ✓ Assigned: $Role for $($Group.Name) on $($MG.DisplayName)"
                    $MgRoleAssignmentsCreated++
                }
            } catch {
                Write-Verbose "  Exception for '$($Group.Name)' on '$($MG.DisplayName)': $($_.Exception)"

                if ($_.Exception.Message -like "*PrincipalNotFound*") {
                    Write-Warning "  Principal not found: $($Group.Name) — excluded from all remaining assignments"
                    $SkippedPrincipalIds += $Group.ObjectId
                    break
                } elseif ($_.Exception.Message -like "*RoleAssignmentExists*" -or $_.Exception.Message -like "*already exists*") {
                    Write-Verbose "  → Already exists (concurrent): $Role for $($Group.Name) on $($MG.DisplayName)"
                    $MgRoleAssignmentsExists++
                } elseif ($_.Exception.Message -like "*AuthorizationFailed*") {
                    Write-Warning "  Access denied: $Role for $($Group.Name) on $($MG.DisplayName)"
                    $Warnings += "Access denied: $Role for $($Group.Name) on MG $($MG.DisplayName)"
                } else {
                    Write-Warning "  Error: $Role for $($Group.Name) on $($MG.DisplayName): $_"
                    $Errors += "Error assigning $Role to $($Group.Name) on MG $($MG.DisplayName): $_"
                }
            }
        }
    }
}

}

# =============================================================================
# Phase 3: Assign roles on subscriptions
# =============================================================================

Write-Output ""
Write-Output "[Phase 3] Assigning roles on subscriptions..."

if ($ManagementGroup -and -not $Subscription) {
    Write-Output "  Skipped — management-group-only targeting active"
} else {

foreach ($Sub in $ProcessedSubscriptions) {
    try {
        Set-AzContext -SubscriptionId $Sub.Id -ErrorAction Stop | Out-Null
        Write-Verbose "  Processing subscription: $($Sub.Name) [$($Sub.Id)]"

        foreach ($Group in $ActiveGroups) {
            if ($Group.ObjectId -in $SkippedPrincipalIds) { continue }

            foreach ($Role in $Group.Roles) {
                $Scope = "/subscriptions/$($Sub.Id)"

                try {
                    $RBACCheck = Get-AzRoleAssignment `
                        -ObjectId $Group.ObjectId `
                        -RoleDefinitionName $Role `
                        -Scope $Scope `
                        -ErrorAction SilentlyContinue |
                        Where-Object { $_.Scope -eq $Scope }

                    if ($RBACCheck) {
                        Write-Verbose "    → Already exists: $Role for $($Group.Name)"
                        $RoleAssignmentsExists++
                    } elseif ($DryRun) {
                        Write-Verbose "    [DRY RUN] Would assign: $Role for $($Group.Name) on $($Sub.Name)"
                        $RoleAssignmentsCreated++
                    } else {
                        New-AzRoleAssignment `
                            -ObjectId $Group.ObjectId `
                            -RoleDefinitionName $Role `
                            -Scope $Scope `
                            -ObjectType "ForeignGroup" `
                            -ErrorAction Stop | Out-Null

                        Write-Verbose "    ✓ Assigned: $Role for $($Group.Name) on $($Sub.Name)"
                        $RoleAssignmentsCreated++
                    }
                } catch {
                    Write-Verbose "    Exception for '$($Group.Name)' on '$($Sub.Name)': $($_.Exception)"

                    if ($_.Exception.Message -like "*PrincipalNotFound*") {
                        Write-Warning "    Principal not found: $($Group.Name) — excluded from all remaining assignments"
                        $SkippedPrincipalIds += $Group.ObjectId
                        break
                    } elseif ($_.Exception.Message -like "*RoleAssignmentExists*" -or $_.Exception.Message -like "*already exists*") {
                        Write-Verbose "    → Already exists (concurrent): $Role for $($Group.Name) on $($Sub.Name)"
                        $RoleAssignmentsExists++
                    } elseif ($_.Exception.Message -like "*AuthorizationFailed*") {
                        Write-Warning "    Access denied: $Role for $($Group.Name) on $($Sub.Name)"
                        $Warnings += "Access denied: $Role for $($Group.Name) on subscription $($Sub.Name)"
                    } else {
                        Write-Warning "    Error: $Role for $($Group.Name) on $($Sub.Name): $_"
                        $Errors += "Error assigning $Role to $($Group.Name) on subscription $($Sub.Name): $_"
                    }
                }
            }
        }
    } catch {
        Write-Error "Failed to switch context to subscription $($Sub.Name): $_"
        $Errors += "Failed to switch context to subscription $($Sub.Name): $_"
    }
}

}

# =============================================================================
# Phase 4: Assign roles on Azure Reservations scope
# =============================================================================

Write-Output ""
Write-Output "[Phase 4] Assigning roles on Azure Reservations scope..."

if ($Subscription -or $ManagementGroup) {
    Write-Output "  Skipped — targeted mode active"
} else {

$ReservationScope = "/providers/Microsoft.Capacity"

foreach ($Group in $ActiveReservationGroups) {
    if ($Group.ObjectId -in $SkippedPrincipalIds) { continue }

    foreach ($Role in $Group.Roles) {
        try {
            $RBACCheck = Get-AzRoleAssignment `
                -ObjectId $Group.ObjectId `
                -RoleDefinitionName $Role `
                -Scope $ReservationScope `
                -ErrorAction SilentlyContinue

            if ($RBACCheck) {
                Write-Verbose "  → Already exists: $Role for $($Group.Name) on Reservations scope"
                $ReservationRoleAssignmentsExists++
            } elseif ($DryRun) {
                Write-Verbose "  [DRY RUN] Would assign: $Role for $($Group.Name) on Reservations scope"
                $ReservationRoleAssignmentsCreated++
            } else {
                New-AzRoleAssignment `
                    -ObjectId $Group.ObjectId `
                    -RoleDefinitionName $Role `
                    -Scope $ReservationScope `
                    -ObjectType "ForeignGroup" `
                    -ErrorAction Stop | Out-Null

                Write-Verbose "  ✓ Assigned: $Role for $($Group.Name) on Reservations scope"
                $ReservationRoleAssignmentsCreated++
            }
        } catch {
            Write-Verbose "  Exception for '$($Group.Name)' on Reservations scope: $($_.Exception)"
            Write-Warning "  Error assigning $Role to $($Group.Name) on Reservations scope: $_"
            $Warnings += "Reservations: $Role for $($Group.Name) — $($_.Exception.Message)"
        }
    }
}

}

# =============================================================================
# Summary
# =============================================================================

Write-Output ""
Write-Output "================================================================================"
Write-Output "Summary"
Write-Output "================================================================================"
Write-Output "  Management groups processed: $($ProcessedManagementGroups.Count)"
Write-Output "  Subscriptions processed:     $($ProcessedSubscriptions.Count)"
Write-Output "  Subscriptions skipped:       $($SkippedSubscriptions.Count)"
Write-Output ""

if ($DryRun) {
    Write-Output "  MG role assignments to create:       $MgRoleAssignmentsCreated"
} else {
    Write-Output "  MG role assignments created:         $MgRoleAssignmentsCreated"
}
Write-Output "  MG role assignments (already exist): $MgRoleAssignmentsExists"
Write-Output ""

if ($DryRun) {
    Write-Output "  Sub role assignments to create:       $RoleAssignmentsCreated"
} else {
    Write-Output "  Sub role assignments created:         $RoleAssignmentsCreated"
}
Write-Output "  Sub role assignments (already exist): $RoleAssignmentsExists"
Write-Output ""

if ($DryRun) {
    Write-Output "  Reservation assignments to create:       $ReservationRoleAssignmentsCreated"
} else {
    Write-Output "  Reservation assignments created:         $ReservationRoleAssignmentsCreated"
}
Write-Output "  Reservation assignments (already exist): $ReservationRoleAssignmentsExists"

if ($SkippedPrincipalIds.Count -gt 0) {
    Write-Output ""
    Write-Output "  Principals skipped (not found in tenant):"
    $SkippedGroups = ($Groups + $ReservationGroups) | Where-Object { $_.ObjectId -in $SkippedPrincipalIds } | Group-Object Name | ForEach-Object { $_.Group[0] }
    foreach ($G in $SkippedGroups) {
        Write-Output "    - $($G.Name)"
    }
}

if ($SkippedSubscriptions.Count -gt 0) {
    Write-Output ""
    Write-Output "  Skipped subscriptions (-OwnerCheck):"
    foreach ($Sub in $SkippedSubscriptions) {
        Write-Output "    - $($Sub.Name) [$($Sub.Id)]"
    }
}

if ($Warnings.Count -gt 0) {
    Write-Output ""
    Write-Output "  Warnings:"
    foreach ($W in $Warnings) {
        Write-Output "    - $W"
    }
}

if ($Errors.Count -gt 0) {
    Write-Output ""
    Write-Output "  Errors:"
    foreach ($E in $Errors) {
        Write-Output "    - $E"
    }
}

Write-Output ""

$SuccessNote = @()
if ($SkippedPrincipalIds.Count -gt 0) { $SuccessNote += "$($SkippedPrincipalIds.Count) principal(s) not found" }
if ($Warnings.Count -gt 0)            { $SuccessNote += "$($Warnings.Count) warning(s)" }
$SuccessSuffix = if ($SuccessNote.Count -gt 0) { " — $($SuccessNote -join ', '), see above" } else { " without errors" }

if ($Errors.Count -eq 0) {
    Write-Output "================================================================================"
    if ($DryRun) {
        Write-Output "✓ DRY RUN SUCCESS: All prerequisites validated, ready for actual deployment"
    } else {
        Write-Output "✓ SUCCESS: AOBO configuration completed$SuccessSuffix"
    }
    Write-Output "================================================================================"
} else {
    Write-Output "================================================================================"
    if ($DryRun) {
        Write-Output "⚠ DRY RUN COMPLETED with $($Errors.Count) error(s) — see details above"
    } else {
        Write-Output "⚠ COMPLETED with $($Errors.Count) error(s) — see details above"
    }
    Write-Output "================================================================================"
}

Write-Output ""
Pause
