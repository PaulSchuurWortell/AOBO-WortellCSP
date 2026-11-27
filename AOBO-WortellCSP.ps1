<#
.SYNOPSIS
    Configure Admin On Behalf Of (AOBO) role assignments on all Azure subscriptions.

.DESCRIPTION
    This script configures AOBO role assignments for Wortell CSP Tier 1 & 2 AdminAgents
    and IngramMicroNL AdminAgents on all subscriptions within a customer tenant. Management
    group assignments are opt-in via -IncludeManagementGroups or -ManagementGroup.

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
    - Elevated access ("Access management for Azure resources") enabled for the Global Admin,
      required for the /providers/Microsoft.Capacity assignments (Phase 4). Without it only
      those assignments are skipped. Disable elevated access again after the run.
      https://learn.microsoft.com/azure/role-based-access-control/elevate-access-global-admin

.CHANGELOG
    v1.19 (November 27, 2026)
    - Fix: "A parameter cannot be found that matches parameter name 'Confirm'" — removed
      -Confirm:$false from New-/Remove-AzRoleAssignment (not supported by those cmdlets) and
      switched Set-AzContext to preference variables instead of -WhatIf/-Confirm parameters

    v1.18 (November 27, 2026)
    - Fix: "You cannot call a method on a null-valued expression" when the script is run via
      Invoke-Expression (Cloud Shell one-liner). $PSCmdlet does not exist in that case, so
      ShouldProcess/ShouldContinue now go through a fallback that works without it. Parameters
      such as -WhatIf and -Enforce still require running the downloaded script file

    v1.17 (November 27, 2026)
    - New defaults: the AOBO groups get no role assignments on management groups, only on
      subscriptions (and the Reservations scope). -Enforce now removes assignments of the groups
      on all management groups, without needing -IncludeManagementGroups. The tenant root
      management group is ignored. Not done in targeted mode (-Subscription / -ReservationsOnly)
    - Explicit opt-in (-IncludeManagementGroups / -ManagementGroup) still assigns the roles on
      management groups and -Enforce then treats those roles as the defaults there (tenant root
      still ignored)

    v1.16 (November 27, 2026)
    - Added -Enforce: check the role assignments of the three AOBO groups and restore them to
      the script defaults. Missing assignments are created; direct assignments that are not part
      of the defaults are removed, per scope (subscriptions, Reservations scope and - only with
      -IncludeManagementGroups / -ManagementGroup - management groups). Works with -WhatIf to
      preview, asks for confirmation before removing (skip with -Force), and never touches
      other principals, inherited assignments or roles whose ID could not be validated
    - Summary lists every assignment removed (or to be removed with -WhatIf)
    - Assignments created by the script no longer double-prompt when -Confirm is used

    v1.15 (November 27, 2026)
    - Implemented SupportsShouldProcess: -WhatIf and -Confirm are now native; every role
      assignment is guarded by ShouldProcess. -DryRun remains as a legacy switch (sets -WhatIf)
    - -PrincipalCheck is skipped in -WhatIf mode (it creates a temporary test assignment)
    - Context switches (Set-AzContext) are never subject to -WhatIf/-Confirm

    v1.14 (November 27, 2026)
    - Renamed -DryRun to -WhatIf for PowerShell convention; -DryRun remains available as an alias

    v1.13 (November 27, 2026)
    - Added "Reservation Purchaser" (subscription scope) and "Reservations Reader"
      (/providers/Microsoft.Capacity) to IngramMicroNL AdminAgents
    - Added "Reservations Reader" (/providers/Microsoft.Capacity) to Wortell AdminAgents
      (already present since v1.1); "Reservation Purchaser" only where Wortell has no Owner
    - Optional switch -IncludeReservationsAdministrator for "Reservations Administrator"
      for Wortell (default off)
    - Pre-flight check for Global Admin elevated access; Capacity assignments are skipped
      with a warning when it is missing
    - New roles are assigned by role definition ID (validated against the role name in Phase 1)
    - Summary reports skipped assignments and reminds to disable elevated access

    v1.12 (September 17, 2026)
    - README: added Owner / User Access Administrator subscription-level requirement to
      "What you need" (previously only in README-TECHNICAL prerequisites)

    v1.11 (September 17, 2026)
    - README/README-TECHNICAL: documented that running with no parameters performs a live
      (non-dry-run) run across all subscriptions, plus the 5-second cancel window and the
      end-of-run Pause prompt

    v1.10 (September 17, 2026)
    - Added "Quota Request Operator" role to IngramMicroNL AdminAgents, alongside existing
      "Support Request Contributor" role

    v1.9 (September 2, 2026)
    - Renamed "Azure Active Directory" / "Azure AD" references to "Entra ID" in script warning
      messages, matching Microsoft's current product naming

    v1.8 (September 2, 2026)
    - Changed default scope: Phase 2 (management groups) is now opt-in via -IncludeManagementGroups
    - -ManagementGroup continues to run Phase 2 targeted to the specified group(s) without requiring
      -IncludeManagementGroups
    - Banner and Phase 2 skip message reflect the new default

    v1.6 (July 14, 2026)
    - Added -Subscription parameter: limit Phase 3 to one or more specific subscriptions (name or ID)
    - Added -ManagementGroup parameter: limit Phase 2 to one or more specific management groups (name or display name)
    - Banner shows active targeting filters when either parameter is used
    - Unknown subscription/MG names emit a warning and are skipped
    - Phases 2/3/4 are skipped when not relevant to the active targeting filter
    - MG lookup now fetches by name directly to avoid requiring list-all permission
    - Warns when a name matches multiple subscriptions or management groups
    - 5-second cancel window after Phase 1 (non-WhatIf only)
    - Per-item progress counters in Phase 2 and Phase 3

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
    .\AOBO-WortellCSP.ps1 -WhatIf

.EXAMPLE
    .\AOBO-WortellCSP.ps1 -IncludeManagementGroups

.EXAMPLE
    # Preview which assignments would be added or removed to restore the defaults
    .\AOBO-WortellCSP.ps1 -Enforce -IncludeManagementGroups -WhatIf
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File must use UTF-8 without BOM for Invoke-Expression compatibility when downloading via Invoke-WebRequest')]
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    # Note: -WhatIf and -Confirm are provided by SupportsShouldProcess.

    # Legacy switch, kept for backward compatibility: equivalent to -WhatIf.
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
    # Omit to process all management groups. Implies -IncludeManagementGroups.
    [Parameter(Mandatory = $false)]
    [string[]]$ManagementGroup,

    # Opt-in: also run Phase 2 (management group role assignments).
    # By default, only subscriptions (Phase 3) are targeted. Not needed when -ManagementGroup is used.
    [Parameter(Mandatory = $false)]
    [switch]$IncludeManagementGroups,

    # Run Phase 4 (Reservations scope) even in targeted mode.
    # When used alone, skips Phases 2 and 3. Can be combined with -Subscription or -ManagementGroup.
    [Parameter(Mandatory = $false)]
    [switch]$ReservationsOnly,

    # Opt-in: also assign "Reservations Administrator" on /providers/Microsoft.Capacity to the
    # Wortell groups, so they can change the scope of a Reserved Instance after purchase.
    [Parameter(Mandatory = $false)]
    [switch]$IncludeReservationsAdministrator,

    # Opt-in: check the current role assignments of the AOBO groups and restore them to the defaults
    # of this script. Missing assignments are created (as normal) and direct assignments that are NOT
    # part of the defaults are REMOVED, per scope: subscriptions, Reservations scope (/providers/
    # Microsoft.Capacity) and management groups. The default on management groups is NO assignments
    # (unless -IncludeManagementGroups / -ManagementGroup is used); the tenant root management group
    # is ignored. Only assignments of the three AOBO groups on the exact scope are touched.
    # Preview with -WhatIf.
    [Parameter(Mandatory = $false)]
    [switch]$Enforce,

    # Skip the confirmation prompt that -Enforce shows before removing assignments.
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# =============================================================================
# Version
# =============================================================================

$Version = "20261127007"

# $PSCmdlet only exists when the script runs as a script file. When run via Invoke-Expression
# (Cloud Shell one-liner) it is $null, so all ShouldProcess calls go through Test-ShouldProcess.
$ScriptCmdlet = $PSCmdlet

function Test-ShouldProcess {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Wrapper around the script cmdlet ShouldProcess; falls back when $PSCmdlet is unavailable (Invoke-Expression)')]
    param([string]$Target, [string]$Action)
    if ($ScriptCmdlet) { return $ScriptCmdlet.ShouldProcess($Target, $Action) }
    # No script cmdlet (Invoke-Expression): no -WhatIf/-Confirm parameters, but honor $WhatIfPreference
    if ($WhatIfPreference) {
        Write-Host "What if: Performing the operation `"$Action`" on target `"$Target`"."
        return $false
    }
    return $true
}

# -DryRun (legacy) is equivalent to -WhatIf. $DryRun is then used throughout the script as the
# "preview only" flag for messages and counters; the actual writes are guarded by ShouldProcess.
if ($DryRun) { $WhatIfPreference = $true }
$DryRun = [bool]$WhatIfPreference

# =============================================================================
# Configuration: Groups and Role Assignments
# =============================================================================

# Role definition IDs for roles that are assigned by ID instead of by name.
# Phase 1 validates each ID against its role name; a mismatch excludes that role.
$RoleIds = @{
    "Reservation Purchaser"      = "f7b75c60-3036-4b75-91c3-6b41c27c1689"
    "Reservations Reader"        = "582fc458-8989-419f-a480-75249bc5db7a"
    "Reservations Administrator" = "a8889054-8d42-49c9-bc1c-52486c10e7cd"
}

# Roles: assigned on every subscription.
# ConditionalRoles: assigned on a subscription only when the group has no Owner there
# (checked per subscription in Phase 3).
$Groups = @(
    @{
        Name             = "Wortell CSP Tier 1 AdminAgents"
        ObjectId         = "2e59f31c-83fd-4ca1-bed4-4b4ee704c0f7"
        Roles            = @("Owner")
        ConditionalRoles = @("Reservation Purchaser")
    },
    @{
        Name             = "Wortell CSP Tier 2 AdminAgents"
        ObjectId         = "27f932e9-605d-4270-bf3f-a02249b1721c"
        Roles            = @("Owner")
        ConditionalRoles = @("Reservation Purchaser")
    },
    @{
        Name             = "IngramMicroNL AdminAgents"
        ObjectId         = "34c4dd11-78c0-41e5-8370-c6dbf16bc3e9"
        Roles            = @("Support Request Contributor", "Quota Request Operator", "Reservation Purchaser")
        ConditionalRoles = @()
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
    },
    @{
        Name     = "IngramMicroNL AdminAgents"
        ObjectId = "34c4dd11-78c0-41e5-8370-c6dbf16bc3e9"
        Roles    = @("Reservations Reader")
    }
)

# Optional (-IncludeReservationsAdministrator): Wortell can change the scope of an RI after purchase
if ($IncludeReservationsAdministrator) {
    foreach ($G in ($ReservationGroups | Where-Object { $_.Name -like "Wortell CSP*" })) {
        $G.Roles += "Reservations Administrator"
    }
}

# Returns the role parameter for Get-/New-AzRoleAssignment: by ID when known, otherwise by name
function Get-RoleParam {
    param([string]$Role)
    if ($RoleIds.ContainsKey($Role)) { return @{ RoleDefinitionId = $RoleIds[$Role] } }
    return @{ RoleDefinitionName = $Role }
}

# -Enforce: removes direct assignments of a group on exactly one scope that are not in $DesiredRoles.
# Assignments of other principals, inherited assignments and roles whose ID could not be validated
# ($InvalidRoles) are never touched. Honors -WhatIf / -Confirm of the script.
function Invoke-EnforceScope {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Scope,
        [string]$ScopeLabel,
        [hashtable]$Group,
        [string[]]$DesiredRoles
    )

    try {
        $Existing = @(Get-AzRoleAssignment -ObjectId $Group.ObjectId -Scope $Scope -ErrorAction Stop |
            Where-Object { $_.Scope -eq $Scope })
    } catch {
        Write-Warning "    Enforce: unable to read assignments of $($Group.Name) on $ScopeLabel — $($_.Exception.Message)"
        $script:Warnings += "Enforce: could not read assignments of $($Group.Name) on $ScopeLabel"
        return
    }

    foreach ($Assignment in $Existing) {
        $RoleName = $Assignment.RoleDefinitionName
        if ($RoleName -in $DesiredRoles -or $RoleName -in $script:InvalidRoles) { continue }

        $Line = "$RoleName for $($Group.Name) on $ScopeLabel"
        if (-not $PSCmdlet.ShouldProcess($Scope, "Remove '$RoleName' from $($Group.Name)")) {
            if ($script:DryRun) {
                $script:EnforceRemoved++
                $script:EnforceLog += "Would remove: $Line"
            }
            continue
        }

        try {
            Remove-AzRoleAssignment `
                -ObjectId $Group.ObjectId `
                -RoleDefinitionName $RoleName `
                -Scope $Scope `
                -ErrorAction Stop | Out-Null
            Write-Output "    ✗ Removed: $Line"
            $script:EnforceRemoved++
            $script:EnforceLog += "Removed: $Line"
        } catch {
            Write-Verbose "    Exception removing $Line : $($_.Exception)"
            if ($_.Exception.Message -like "*AuthorizationFailed*") {
                Write-Warning "    Access denied: could not remove $Line"
                $script:Warnings += "Enforce: access denied removing $Line"
            } else {
                Write-Warning "    Error removing $Line : $_"
                $script:Errors += "Error removing $Line : $_"
            }
        }
    }
}

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
$SkippedAssignments                = 0   # conditional roles skipped because the group already has Owner
$CapacitySkipped                   = 0   # Capacity-scope assignments skipped (no elevated access)
$InvalidRoles                      = @()
$HasElevatedAccess                 = $false
$SkipCapacity                      = $false
$EnforceRemoved                    = 0   # -Enforce: assignments removed (or to remove in -WhatIf mode)
$EnforceLog                        = @()

# =============================================================================
# Banner
# =============================================================================

Write-Output ""
Write-Output "================================================================================"
Write-Output "AOBO Configuration Script - Wortell CSP  (version $Version)"
if ($DryRun) {
    Write-Output "DRY RUN MODE - No changes will be made"
}
if ($Subscription -or $ManagementGroup -or $ReservationsOnly) {
    Write-Output "TARGETED MODE"
    if ($Subscription)     { Write-Output "  Subscriptions:     $($Subscription    -join ', ')" }
    if ($ManagementGroup)  { Write-Output "  Management groups: $($ManagementGroup -join ', ')" }
    if ($ReservationsOnly) { Write-Output "  Reservations:      yes" }
}
if ($IncludeReservationsAdministrator) {
    Write-Output "Reservations Administrator for Wortell: included"
}
if ($Enforce) {
    if ($DryRun) {
        Write-Output "ENFORCE MODE - assignments that are not part of the defaults would be removed (preview)"
    } else {
        Write-Output "ENFORCE MODE - assignments of the AOBO groups that are not part of the defaults will be REMOVED"
    }
    if ($ManagementGroup -or $IncludeManagementGroups) {
        Write-Output "  Defaults: subscriptions + Reservations scope; management groups per explicit opt-in (tenant root ignored)"
    } else {
        Write-Output "  Defaults: subscriptions + Reservations scope only; no management group assignments (tenant root ignored)"
    }
}
if ($ManagementGroup -or $IncludeManagementGroups) {
    Write-Output "Management groups: included"
} else {
    Write-Output "Management groups: excluded by default (use -IncludeManagementGroups to include)"
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

# Tenant ID: the tenant root management group has this ID as its name (ignored by -Enforce)
$TenantId = $null
try { $TenantId = (Get-AzContext -ErrorAction Stop).Tenant.Id } catch { Write-Verbose "  Unable to determine tenant ID: $($_.Exception.Message)" }

# --- Validate role definition IDs against their role names ---
foreach ($RoleName in @($RoleIds.Keys)) {
    if ($RoleName -eq "Reservations Administrator" -and -not $IncludeReservationsAdministrator) { continue }
    try {
        $RoleDef = Get-AzRoleDefinition -Id $RoleIds[$RoleName] -ErrorAction Stop
        if (-not $RoleDef -or $RoleDef.Name -ne $RoleName) {
            throw "ID $($RoleIds[$RoleName]) resolves to '$($RoleDef.Name)'"
        }
        Write-Verbose "  ✓ Role definition: $RoleName [$($RoleIds[$RoleName])]"
    } catch {
        Write-Warning "  Role definition check failed for '$RoleName': $($_.Exception.Message) — role will be skipped"
        $Warnings += "Role '$RoleName' skipped — role definition ID could not be validated"
        $InvalidRoles += $RoleName
    }
}

# --- Elevated access check (needed for the /providers/Microsoft.Capacity assignments in Phase 4) ---
$Phase4Planned = -not (($Subscription -or $ManagementGroup) -and -not $ReservationsOnly)
if ($Phase4Planned) {
    try {
        $RootAssign = @(Get-AzRoleAssignment -Scope "/" -ObjectId $CurrentUser.Id -ErrorAction Stop |
            Where-Object { $_.Scope -eq "/" -and $_.RoleDefinitionName -in @("Owner", "User Access Administrator") })
        if ($RootAssign.Count -gt 0) {
            $HasElevatedAccess = $true
        } else {
            # Fallback: a successful read on the Capacity scope also indicates sufficient access
            Get-AzRoleAssignment -Scope "/providers/Microsoft.Capacity" -ErrorAction Stop | Out-Null
            $HasElevatedAccess = $true
        }
    } catch {
        Write-Verbose "  Elevated access check exception: $($_.Exception)"
    }

    if ($HasElevatedAccess) {
        Write-Output "  ✓ Elevated access confirmed (root scope)"
    } else {
        $SkipCapacity = $true
        Write-Warning "  Elevated access not detected — /providers/Microsoft.Capacity assignments (Phase 4) will be skipped."
        Write-Warning "  Enable 'Access management for Azure resources' (Entra ID → Properties) and re-run: https://learn.microsoft.com/azure/role-based-access-control/elevate-access-global-admin"
        $Warnings += "Capacity-scope assignments skipped — elevated access not detected (https://learn.microsoft.com/azure/role-based-access-control/elevate-access-global-admin)"
    }
}

# --- Targeting filter: limit to specific subscriptions (-Subscription) ---
if ($Subscription) {
    $MatchedSubs = @($Subscriptions | Where-Object { $_.Id -in $Subscription -or $_.Name -in $Subscription })
    foreach ($s in ($Subscription | Where-Object { $_ -notin $Subscriptions.Id })) {
        $DupCount = @($Subscriptions | Where-Object { $_.Name -eq $s }).Count
        if ($DupCount -gt 1) {
            Write-Warning "  '$s' matches $DupCount subscriptions — all will be targeted"
        }
    }
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

if ($PrincipalCheck -and $DryRun) {
    Write-Warning "  [PrincipalCheck] Skipped in -WhatIf mode: the check creates and removes a test assignment."
} elseif ($PrincipalCheck) {
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

if (-not $DryRun) {
    Write-Output ""
    Write-Output "Starting in 5 seconds — press Ctrl+C to cancel..."
    for ($i = 5; $i -ge 1; $i--) {
        Write-Output "  $i..."
        Start-Sleep -Seconds 1
    }
}

if ($Enforce -and -not $DryRun -and -not $Force) {
    $EnforceQuery = "-Enforce will REMOVE role assignments of the AOBO groups that are not part of the defaults (use -WhatIf first to preview). Continue?"
    if ($ScriptCmdlet) {
        $EnforceConfirmed = $ScriptCmdlet.ShouldContinue($EnforceQuery, "Enforce")
    } else {
        $EnforceConfirmed = (Read-Host "$EnforceQuery Type YES to continue") -eq "YES"
    }
    if (-not $EnforceConfirmed) {
        Write-Output "Cancelled — nothing was changed."
        return
    }
}

# =============================================================================
# Phase 2: Assign roles on management groups
# =============================================================================

Write-Output ""
Write-Output "[Phase 2] Assigning roles on management groups..."

if (-not ($ManagementGroup -or $IncludeManagementGroups)) {
    Write-Output "  Skipped — management groups excluded by default (use -IncludeManagementGroups to include)"

    # -Enforce: the default is NO assignments of the AOBO groups on management groups, so remove any
    # that exist. The tenant root management group is ignored. Not done in targeted mode
    # (-Subscription / -ReservationsOnly).
    if ($Enforce -and -not ($Subscription -or $ReservationsOnly)) {
        Write-Output "  Enforce: checking management groups for assignments of the AOBO groups (default: none; tenant root ignored)..."
        try {
            $EnforceMGs = @(Get-AzManagementGroup -ErrorAction Stop)
        } catch {
            Write-Warning "  Enforce: unable to list management groups — $($_.Exception.Message)"
            $Warnings += "Enforce: could not list management groups, management group assignments not checked"
            $EnforceMGs = @()
        }
        foreach ($MG in $EnforceMGs) {
            if ($MG.Name -eq $TenantId) {
                Write-Verbose "  Ignored tenant root management group: $($MG.DisplayName)"
                continue
            }
            $ProcessedManagementGroups += $MG
            $MgScope = "/providers/Microsoft.Management/managementgroups/$($MG.Name)"
            foreach ($Group in $ActiveGroups) {
                if ($Group.ObjectId -in $SkippedPrincipalIds) { continue }
                Invoke-EnforceScope -Scope $MgScope -ScopeLabel "MG $($MG.DisplayName)" -Group $Group -DesiredRoles @()
            }
        }
    }
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

$MgIndex = 0
foreach ($MG in $ManagementGroups) {
    $MgIndex++
    Write-Output "  [$MgIndex/$($ManagementGroups.Count)] $($MG.DisplayName)"
    $ProcessedManagementGroups += $MG
    $MgScope = "/providers/Microsoft.Management/managementgroups/$($MG.Name)"

    foreach ($Group in $ActiveGroups) {
        if ($Group.ObjectId -in $SkippedPrincipalIds) { continue }

        foreach ($Role in $Group.Roles) {
            if ($Role -in $InvalidRoles) { continue }
            $RoleParam = Get-RoleParam $Role
            try {
                $RBACCheck = Get-AzRoleAssignment `
                    -ObjectId $Group.ObjectId `
                    @RoleParam `
                    -Scope $MgScope `
                    -ErrorAction SilentlyContinue |
                    Where-Object { $_.Scope -eq $MgScope }

                if ($RBACCheck) {
                    Write-Verbose "  → Already exists: $Role for $($Group.Name) on $($MG.DisplayName)"
                    $MgRoleAssignmentsExists++
                } elseif (-not (Test-ShouldProcess -Target $MgScope -Action "Assign '$Role' to $($Group.Name)")) {
                    if ($DryRun) {
                        Write-Verbose "  [WhatIf] Would assign: $Role for $($Group.Name) on $($MG.DisplayName)"
                        $MgRoleAssignmentsCreated++
                    } else {
                        Write-Verbose "  Declined: $Role for $($Group.Name) on $($MG.DisplayName)"
                    }
                } else {
                    New-AzRoleAssignment `
                        -ObjectId $Group.ObjectId `
                        @RoleParam `
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

        # -Enforce: remove assignments of this group on this MG that are not part of the defaults
        if ($Enforce -and $Group.ObjectId -notin $SkippedPrincipalIds -and $MG.Name -ne $TenantId) {
            Invoke-EnforceScope -Scope $MgScope -ScopeLabel "MG $($MG.DisplayName)" -Group $Group -DesiredRoles @($Group.Roles)
        }
    }
}

}

# =============================================================================
# Phase 3: Assign roles on subscriptions
# =============================================================================

Write-Output ""
Write-Output "[Phase 3] Assigning roles on subscriptions..."

if (($ManagementGroup -or $ReservationsOnly) -and -not $Subscription) {
    Write-Output "  Skipped — management-group-only targeting active"
} else {

$SubIndex = 0
foreach ($Sub in $ProcessedSubscriptions) {
    $SubIndex++
    Write-Output "  [$SubIndex/$($ProcessedSubscriptions.Count)] $($Sub.Name)"
    try {
        # Switching context is not a change to Azure: never subject it to -WhatIf/-Confirm
        # (done via the preference variables: not every Az cmdlet/version has -WhatIf/-Confirm parameters)
        $SavedWhatIfPreference   = $WhatIfPreference
        $SavedConfirmPreference  = $ConfirmPreference
        $WhatIfPreference        = $false
        $ConfirmPreference       = 'None'
        try {
            Set-AzContext -SubscriptionId $Sub.Id -ErrorAction Stop | Out-Null
        } finally {
            $WhatIfPreference  = $SavedWhatIfPreference
            $ConfirmPreference = $SavedConfirmPreference
        }
        Write-Verbose "  Processing subscription: $($Sub.Name) [$($Sub.Id)]"

        foreach ($Group in $ActiveGroups) {
            if ($Group.ObjectId -in $SkippedPrincipalIds) { continue }

            $OwnerOk      = $false
            $DesiredHere  = @()   # roles this group should have on this subscription (for -Enforce)

            foreach ($Role in (@($Group.Roles) + @($Group.ConditionalRoles))) {
                $Scope = "/subscriptions/$($Sub.Id)"
                if ($Role -in $InvalidRoles) { continue }
                $RoleParam = Get-RoleParam $Role

                # Conditional roles: only where the group has no Owner on this subscription
                if ($Role -in @($Group.ConditionalRoles)) {
                    $HasOwner = $OwnerOk -or [bool](Get-AzRoleAssignment `
                        -ObjectId $Group.ObjectId `
                        -RoleDefinitionName "Owner" `
                        -Scope $Scope `
                        -ErrorAction SilentlyContinue)
                    if ($HasOwner) {
                        Write-Verbose "    → Skipped: $Role for $($Group.Name) on $($Sub.Name) (Owner present)"
                        $SkippedAssignments++
                        continue
                    }
                }

                $DesiredHere += $Role

                try {
                    $RBACCheck = Get-AzRoleAssignment `
                        -ObjectId $Group.ObjectId `
                        @RoleParam `
                        -Scope $Scope `
                        -ErrorAction SilentlyContinue |
                        Where-Object { $_.Scope -eq $Scope }

                    if ($RBACCheck) {
                        Write-Verbose "    → Already present: $Role for $($Group.Name)"
                        $RoleAssignmentsExists++
                    } elseif (-not (Test-ShouldProcess -Target $Scope -Action "Assign '$Role' to $($Group.Name)")) {
                        if ($DryRun) {
                            Write-Verbose "    [WhatIf] Would assign: $Role for $($Group.Name) on $($Sub.Name)"
                            $RoleAssignmentsCreated++
                        } else {
                            Write-Verbose "    Declined: $Role for $($Group.Name) on $($Sub.Name)"
                        }
                    } else {
                        New-AzRoleAssignment `
                            -ObjectId $Group.ObjectId `
                            @RoleParam `
                            -Scope $Scope `
                            -ObjectType "ForeignGroup" `
                            -ErrorAction Stop | Out-Null

                        Write-Verbose "    ✓ Assigned: $Role for $($Group.Name) on $($Sub.Name)"
                        $RoleAssignmentsCreated++
                    }
                    if ($Role -eq "Owner") { $OwnerOk = $true }
                } catch {
                    Write-Verbose "    Exception for '$($Group.Name)' on '$($Sub.Name)': $($_.Exception)"

                    if ($_.Exception.Message -like "*PrincipalNotFound*") {
                        Write-Warning "    Principal not found: $($Group.Name) — excluded from all remaining assignments"
                        $SkippedPrincipalIds += $Group.ObjectId
                        break
                    } elseif ($_.Exception.Message -like "*RoleAssignmentExists*" -or $_.Exception.Message -like "*already exists*") {
                        Write-Verbose "    → Already present (concurrent): $Role for $($Group.Name) on $($Sub.Name)"
                        $RoleAssignmentsExists++
                        if ($Role -eq "Owner") { $OwnerOk = $true }
                    } elseif ($_.Exception.Message -like "*AuthorizationFailed*") {
                        Write-Warning "    Access denied: $Role for $($Group.Name) on $($Sub.Name)"
                        $Warnings += "Access denied: $Role for $($Group.Name) on subscription $($Sub.Name)"
                    } else {
                        Write-Warning "    Error: $Role for $($Group.Name) on $($Sub.Name): $_"
                        $Errors += "Error assigning $Role to $($Group.Name) on subscription $($Sub.Name): $_"
                    }
                }
            }

            # -Enforce: remove assignments of this group on this subscription that are not part of the defaults
            if ($Enforce -and $Group.ObjectId -notin $SkippedPrincipalIds) {
                Invoke-EnforceScope -Scope "/subscriptions/$($Sub.Id)" -ScopeLabel "subscription $($Sub.Name)" -Group $Group -DesiredRoles $DesiredHere
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

if (($Subscription -or $ManagementGroup) -and -not $ReservationsOnly) {
    Write-Output "  Skipped — targeted mode active"
} else {

$ReservationScope = "/providers/Microsoft.Capacity"

if ($SkipCapacity) {
    $CapacitySkipped = @($ActiveReservationGroups | ForEach-Object { $_.Roles } | Where-Object { $_ -notin $InvalidRoles }).Count
    Write-Output "  Skipped — elevated access not detected ($CapacitySkipped assignment(s) not performed)"
    $ActiveReservationGroups = @()
}

foreach ($Group in $ActiveReservationGroups) {
    if ($Group.ObjectId -in $SkippedPrincipalIds) { continue }

    foreach ($Role in $Group.Roles) {
        if ($Role -in $InvalidRoles) { continue }
        $RoleParam = Get-RoleParam $Role
        try {
            $RBACCheck = Get-AzRoleAssignment `
                -ObjectId $Group.ObjectId `
                @RoleParam `
                -Scope $ReservationScope `
                -ErrorAction SilentlyContinue

            if ($RBACCheck) {
                Write-Verbose "  → Already exists: $Role for $($Group.Name) on Reservations scope"
                $ReservationRoleAssignmentsExists++
            } elseif (-not (Test-ShouldProcess -Target $ReservationScope -Action "Assign '$Role' to $($Group.Name)")) {
                if ($DryRun) {
                    Write-Verbose "  [WhatIf] Would assign: $Role for $($Group.Name) on Reservations scope"
                    $ReservationRoleAssignmentsCreated++
                } else {
                    Write-Verbose "  Declined: $Role for $($Group.Name) on Reservations scope"
                }
            } else {
                New-AzRoleAssignment `
                    -ObjectId $Group.ObjectId `
                    @RoleParam `
                    -Scope $ReservationScope `
                    -ObjectType "ForeignGroup" `
                    -ErrorAction Stop | Out-Null

                Write-Verbose "  ✓ Assigned: $Role for $($Group.Name) on Reservations scope"
                $ReservationRoleAssignmentsCreated++
            }
        } catch {
            Write-Verbose "  Exception for '$($Group.Name)' on Reservations scope: $($_.Exception)"
            if ($_.Exception.Message -like "*AuthorizationFailed*") {
                Write-Warning "  Access denied: $Role for $($Group.Name) on Reservations scope — ensure 'Elevated access' is enabled under Entra ID → Properties before running"
                $Warnings += "Reservations: $Role for $($Group.Name) — access denied (elevated access required)"
            } else {
                Write-Warning "  Error assigning $Role to $($Group.Name) on Reservations scope: $_"
                $Warnings += "Reservations: $Role for $($Group.Name) — $($_.Exception.Message)"
            }
        }
    }

    # -Enforce: remove assignments of this group on the Reservations scope that are not part of the defaults
    if ($Enforce -and $Group.ObjectId -notin $SkippedPrincipalIds) {
        Invoke-EnforceScope -Scope $ReservationScope -ScopeLabel "Reservations scope" -Group $Group -DesiredRoles @($Group.Roles)
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
Write-Output "  Skipped (conditional role, Owner present): $SkippedAssignments"
Write-Output "  Skipped (Capacity scope, no elevated access): $CapacitySkipped"

if ($Enforce) {
    Write-Output ""
    if ($DryRun) {
        Write-Output "  Enforce: assignments to remove:       $EnforceRemoved"
    } else {
        Write-Output "  Enforce: assignments removed:         $EnforceRemoved"
    }
    foreach ($L in $EnforceLog) {
        Write-Output "    - $L"
    }
    if ($Subscription -or $ReservationsOnly) {
        Write-Output "  (management groups not checked — targeted mode)"
    } elseif (-not ($ManagementGroup -or $IncludeManagementGroups)) {
        Write-Output "  (management groups: default is no assignments — any found were removed; tenant root ignored)"
    }
}

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

if ($HasElevatedAccess) {
    Write-Output "REMINDER: disable elevated access again (Entra ID → Properties → Access management for Azure resources → No)."
    Write-Output "          https://learn.microsoft.com/azure/role-based-access-control/elevate-access-global-admin"
    Write-Output ""
}

Pause
