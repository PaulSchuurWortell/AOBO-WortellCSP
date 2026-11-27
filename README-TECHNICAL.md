# AOBO-WortellCSP

Assigns Azure RBAC roles to Wortell and Ingram Micro admin groups across all subscriptions in a customer tenant, so Wortell support staff can manage the customer environment without requiring guest invitations or manual access requests. Management group assignments are opt-in via `-IncludeManagementGroups`.

## Introduction

**Admin On Behalf Of (AOBO)** is a security model in Azure that allows Managed Service Providers (MSPs) to manage customer Azure subscriptions on their behalf. This script automates the configuration of AOBO role assignments across all subscriptions in a customer tenant, with management groups included on request.

The `AOBO-WortellCSP.ps1` script configures role assignments for:

- **Wortell CSP Tier 1 AdminAgents** — Owner role
- **Wortell CSP Tier 2 AdminAgents** — Owner role
- **IngramMicroNL AdminAgents** — Support Request Contributor, Quota Request Operator, Reservation Purchaser, Reservations Reader

### Roles per principal

| Principal | Role | Scope | Condition |
| --------- | ---- | ----- | --------- |
| Wortell CSP Tier 1 / Tier 2 AdminAgents | Owner | Every subscription (management groups only with explicit `-IncludeManagementGroups`; not part of the defaults) | — |
| Wortell CSP Tier 1 / Tier 2 AdminAgents | Reservation Purchaser (`f7b75c60-3036-4b75-91c3-6b41c27c1689`) | Subscription | Only where the group has no Owner on that subscription |
| Wortell CSP Tier 1 / Tier 2 AdminAgents | Reservations Reader (`582fc458-8989-419f-a480-75249bc5db7a`) | `/providers/Microsoft.Capacity` | Requires elevated access |
| Wortell CSP Tier 1 / Tier 2 AdminAgents | Reservations Administrator (`a8889054-8d42-49c9-bc1c-52486c10e7cd`) | `/providers/Microsoft.Capacity` | Only with `-IncludeReservationsAdministrator`; requires elevated access |
| IngramMicroNL AdminAgents | Support Request Contributor, Quota Request Operator | Every subscription | — |
| IngramMicroNL AdminAgents | Reservation Purchaser (`f7b75c60-3036-4b75-91c3-6b41c27c1689`) | Every subscription | — |
| IngramMicroNL AdminAgents | Reservations Reader (`582fc458-8989-419f-a480-75249bc5db7a`) | `/providers/Microsoft.Capacity` | Requires elevated access |

Reservation Purchaser is assigned by role definition ID. Reservations Reader and Reservations Administrator are assigned by role **name**, because on `/providers/Microsoft.Capacity` Azure does not resolve a role definition ID (`RoleDefinitionDoesNotExist`). Phase 1 validates every ID against its role name (looking it up on several scopes) and skips a role, with a warning, if the ID resolves to a different role. Because Reservation Purchaser allows purchases that are billed to the customer, RI purchases should only run via an order from Wortell to Ingram Micro.

By default, the script ensures these groups have the appropriate permissions on all subscriptions, enabling support teams to assist customers without requiring guest invitations. **The defaults do not include any rights on management groups** — only subscriptions (and the Reservations scope). Use `-Enforce` to remove management group assignments that exist; assignments on the tenant root management group are ignored. Pass `-IncludeManagementGroups` only in exceptional cases to also assign roles at the management group level.

---

## Getting Started: Run via Azure Cloud Shell

The recommended and easiest way to run this script is directly from **Azure Cloud Shell** — no downloads or local setup needed.

### Step 1 — Open the customer tenant in the Azure portal

1. Go to [portal.azure.com](https://portal.azure.com)
2. If you have access to multiple directories, click your account name in the top-right corner, select **Switch directory**, and choose the **customer tenant** you want to configure

### Step 2 — Open Cloud Shell in PowerShell mode

1. Click the **Cloud Shell** button ( `>_` ) in the top navigation bar
2. If prompted, select an arbitrary subscription to associate with Cloud Shell and confirm
3. If the shell opens in **Bash** mode, switch to **PowerShell** using the dropdown in the Cloud Shell toolbar (top-left of the shell panel)
4. Wait for the PowerShell prompt to appear

### Step 3 — Run the script

Paste and run:

```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -UseBasicParsing).Content
```

---

## Prerequisites

- **Azure Cloud Shell** (recommended) or local PowerShell environment with Az module
- **Active connection to Azure** (`Connect-AzAccount`)
- **Owner or User Access Administrator at the root management group scope** on the customer tenant
  - In practice this is obtained by using the **Elevate access** button in Entra ID → Properties, which is only available to **Global Administrators**. Once elevated, the Global Admin has User Access Administrator at root scope.
  - If a customer has already granted you Owner at root management group scope directly, Global Administrator is not required.
- **Elevated access enabled for Phase 4 (Reservations scope)**
  - The Reservations scope (`/providers/Microsoft.Capacity`) sits outside the management group hierarchy. Owner at root MG does not cover it.
  - To assign roles there, go to **Entra ID → Properties**, set **Access management for Azure resources** to **Yes**, and click **Save** before running the script.
  - You can disable it again after the script completes — the script reminds you in the summary.
  - Phase 1 checks for elevated access (root scope `/`, with a read on `/providers/Microsoft.Capacity` as fallback). If it is missing, **only the Capacity-scope assignments are skipped**, a warning with a link to [Elevate access](https://learn.microsoft.com/azure/role-based-access-control/elevate-access-global-admin) is shown, and the rest of the script runs normally. Re-run with `-ReservationsOnly` after enabling elevated access.
- **Active GDAP relationship** with both Wortell and Ingram Micro — accepting GDAP automatically registers the following groups as guest service principals in the customer tenant (no manual invitation needed):
  - Wortell CSP Tier 1 AdminAgents (`2e59f31c-83fd-4ca1-bed4-4b4ee704c0f7`)
  - Wortell CSP Tier 2 AdminAgents (`27f932e9-605d-4270-bf3f-a02249b1721c`)
  - IngramMicroNL AdminAgents (`34c4dd11-78c0-41e5-8370-c6dbf16bc3e9`)

---

## Usage with Parameters

For advanced usage, download the script first:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -OutFile "AOBO-WortellCSP.ps1"
```

Then run with any combination of parameters:

```powershell
# Execute normally
.\AOBO-WortellCSP.ps1

# Validate without making any changes
.\AOBO-WortellCSP.ps1 -WhatIf

# Pre-validate that all foreign principals can receive assignments before proceeding
# (use when GDAP registration is uncertain; omit if confirmed but API test fails)
.\AOBO-WortellCSP.ps1 -PrincipalCheck

# Pre-verify Owner access on each subscription before assigning roles
# (use when you want to filter out inaccessible subscriptions upfront)
.\AOBO-WortellCSP.ps1 -OwnerCheck

# Limit to specific subscriptions (by name or ID; accepts one or more values)
.\AOBO-WortellCSP.ps1 -Subscription "My Subscription"
.\AOBO-WortellCSP.ps1 -Subscription "My Subscription", "00000000-0000-0000-0000-000000000000"

# Also assign roles on management groups (Phase 2 is skipped by default)
.\AOBO-WortellCSP.ps1 -IncludeManagementGroups

# Limit to specific management groups (by name or display name; accepts one or more values)
# Implies -IncludeManagementGroups — no need to pass both
.\AOBO-WortellCSP.ps1 -ManagementGroup "Production"
.\AOBO-WortellCSP.ps1 -ManagementGroup "Production", "Staging"

# Assign roles on the Reservations scope only (requires elevated access in Entra ID)
.\AOBO-WortellCSP.ps1 -ReservationsOnly

# Combine targeting parameters (also adds Phase 4 to a targeted run)
.\AOBO-WortellCSP.ps1 -ManagementGroup "Production" -Subscription "My Subscription"
.\AOBO-WortellCSP.ps1 -Subscription "My Subscription" -ReservationsOnly

# Also give Wortell "Reservations Administrator" on /providers/Microsoft.Capacity (default off;
# lets Wortell change the scope of a Reserved Instance after purchase)
.\AOBO-WortellCSP.ps1 -IncludeReservationsAdministrator

# Check the current assignments and restore them to the script defaults (see "Enforce Mode")
# Always preview first with -WhatIf
.\AOBO-WortellCSP.ps1 -Enforce -WhatIf
.\AOBO-WortellCSP.ps1 -Enforce -IncludeManagementGroups -WhatIf
.\AOBO-WortellCSP.ps1 -Enforce

# Show verbose output including full exception details on errors
.\AOBO-WortellCSP.ps1 -Verbose
```

### Enforce Mode

`-Enforce` checks the role assignments of the three AOBO groups and restores them to the defaults of this script:

- **Missing** default assignments are created, exactly as in a normal run.
- **Extra** direct assignments of the AOBO groups that are not part of the defaults are **removed**. Examples: a Contributor role for IngramMicroNL AdminAgents on a subscription, or Reservations Administrator on the Reservations scope without `-IncludeReservationsAdministrator`.
- Scopes checked: subscriptions, the Reservations scope (`/providers/Microsoft.Capacity`, needs elevated access) and **management groups**. Resource group and resource level assignments are never checked.
- **Management groups: the default is no assignments.** The new defaults only place rights on subscriptions (and the Reservations scope). `-Enforce` therefore **removes** assignments of the three AOBO groups on every management group, without needing `-IncludeManagementGroups`. This is skipped in targeted mode (`-Subscription`, `-ReservationsOnly`).
- **Tenant root management group is ignored.** Assignments of the groups on the tenant root group (the management group whose name equals the tenant ID) are never removed by `-Enforce`.
- Explicit opt-in: if you pass `-IncludeManagementGroups` or `-ManagementGroup`, the script still assigns the configured roles on management groups, and `-Enforce` then treats those roles as the defaults there (extras are still removed; tenant root still ignored). This is only for exceptional situations — it is not part of the new defaults.
- The defaults per scope are the roles in the table under [Roles per principal](#roles-per-principal). On a subscription, Reservation Purchaser for Wortell is only a default where the group has no Owner.
- Never touched: assignments of other principals, inherited assignments (only the exact scope is evaluated), and roles whose ID could not be validated in Phase 1.
- Combine with `-WhatIf` to see what would change: each removal is shown as `What if: Performing the operation "Remove '<role>' from <group>"` and the summary lists all of them. `-Confirm` asks per removal.
- Without `-WhatIf`, the script asks for one confirmation before it starts removing (skip with `-Force`).
- `-Enforce` works together with `-Subscription`, `-ManagementGroup` and `-ReservationsOnly`: only the scopes that are in scope for that run are enforced.

> **Note:** if a customer deliberately granted one of these groups extra rights, `-Enforce` removes them. Run with `-WhatIf` first.

### WhatIf Mode (Dry Run)

To validate prerequisites without making any changes:

```powershell
.\AOBO-WortellCSP.ps1 -WhatIf
```

`-WhatIf` is a native PowerShell switch (the script uses `SupportsShouldProcess`), so `-Confirm` is available too: each assignment then asks for confirmation. `-DryRun` is kept as a legacy switch and behaves exactly like `-WhatIf`. In `-WhatIf` mode `-PrincipalCheck` is skipped, because it creates a temporary test assignment.

**What WhatIf does:**

- Shows what role assignments would be created
- Shows what management groups would be processed
- **No actual changes are made to your Azure environment**
- The 5-second cancel window is skipped

### Targeted Mode

Use `-Subscription`, `-ManagementGroup`, and/or `-IncludeManagementGroups` to restrict or expand the script's scope. This is useful when a customer has many subscriptions or management groups and only a subset needs to be configured, or when management groups should be included alongside the default subscription-only run.

```powershell
# Only assign roles on the "Production" management group
.\AOBO-WortellCSP.ps1 -ManagementGroup "Production"

# Only assign roles on two specific subscriptions
.\AOBO-WortellCSP.ps1 -Subscription "Sub A", "Sub B"

# Combine: specific MG and specific subscription
.\AOBO-WortellCSP.ps1 -ManagementGroup "Production" -Subscription "Sub A"

# Default subscription run, plus all management groups
.\AOBO-WortellCSP.ps1 -IncludeManagementGroups
```

**Behavior by flag combination:**

| Targeting | Phase 2 (MGs) | Phase 3 (Subscriptions) | Phase 4 (Reservations) |
| --------- | ------------- | ----------------------- | ---------------------- |
| None set (default) | Skipped | All subscriptions | ✓ |
| `-IncludeManagementGroups` | All MGs | All subscriptions | ✓ |
| `-ManagementGroup` only | Filtered MGs | Skipped | Skipped |
| `-Subscription` only | Skipped | Filtered subscriptions | Skipped |
| `-ReservationsOnly` | Skipped | Skipped | ✓ |
| `-Subscription -IncludeManagementGroups` | All MGs | Filtered subscriptions | Skipped |
| `-Subscription -ReservationsOnly` | Skipped | Filtered subscriptions | ✓ |
| `-ManagementGroup -ReservationsOnly` | Filtered MGs | Skipped | ✓ |
| `-ManagementGroup -Subscription` | Filtered MGs | Filtered subscriptions | Skipped |
| All targeting parameters set | Filtered MGs | Filtered subscriptions | ✓ |

`-ManagementGroup` always runs Phase 2 targeted to the specified group(s) — it implies `-IncludeManagementGroups`, so there's no need to pass both.

**Notes:**

- Values are matched against both technical name and display name (MGs) or name and subscription ID (subscriptions)
- If a specified value matches multiple resources with the same name, all matches are targeted and a warning is printed
- If a specified value is not found, a warning is printed and the script continues with whatever was matched
- Phase 4 requires elevated access in Entra ID — see [Prerequisites](#prerequisites)

**Running with no parameters at all** performs a live (non-dry-run) execution: Phase 2 is skipped, Phase 3 assigns roles on every enabled subscription in the tenant, and Phase 4 assigns roles on the Reservations scope — see the "None set (default)" row above. Use `-WhatIf` first if you want to preview this without making changes.

**Cancel window:**

When running without `-WhatIf`, the script pauses for 5 seconds after Phase 1 (discovery) before making any changes. Press **Ctrl+C** during this window to abort without any assignments being made.

**End-of-run pause:**

After printing the summary, the script calls `Pause` and waits for a keypress (Enter) before returning control to the shell. This is expected — the script has already finished; it is not stuck.

---

## What the Script Does

The script runs through **four phases**, then prints a summary. It aborts early only on critical failures:

| Phase | Purpose | Abort condition |
| ----- | ------- | --------------- |
| 1 | Discover enabled subscriptions and current user identity; optionally filter to specific subscriptions (`-Subscription`), validate foreign principals (`-PrincipalCheck`), or verify Owner access per subscription (`-OwnerCheck`); validate role definition IDs; check for elevated access (needed for Phase 4) | No enabled subscriptions; `-PrincipalCheck` used and no principals pass; or `-Subscription` filter matches nothing |
| 2 | Skipped by default. Runs when `-IncludeManagementGroups` or `-ManagementGroup` is used, assigning configured roles to all management groups (or those matching `-ManagementGroup`); `PrincipalNotFound` excludes the group from all remaining phases; `AuthorizationFailed` is a non-blocking warning | — |
| 3 | Assign configured roles to all subscriptions (or those passing `-OwnerCheck`); conditional roles (Wortell Reservation Purchaser) are skipped where the group has Owner; skipped entirely when `-ManagementGroup` is set without `-Subscription` | — |
| 4 | Assign configured roles at the Azure Reservations scope (`/providers/Microsoft.Capacity`); skipped in targeted mode unless `-ReservationsOnly` is set; requires elevated access in Entra ID — without it the phase is skipped with a warning; other failures are non-blocking warnings | — |
| Summary | Display results — MG and subscription counts, role assignment totals, skipped principals, and any warnings or errors | — |

---

## Key Design Patterns

- **Idempotency:** Each role assignment checks if the assignment already exists before creating it — safe to run multiple times.
- **WhatIf throughout:** The `-WhatIf` switch is checked inside every assignment block, not just at the entry point.
- **Enforce:** `-Enforce` compares the AOBO groups' direct assignments per scope with the defaults and removes extras (via `Invoke-EnforceScope`, which honors `-WhatIf`/`-Confirm`); defaults: no MG assignments (tenant root ignored), unless the MG opt-in is used.
- **Graceful principal handling:** If a foreign principal is not found in the tenant during assignment, it is skipped for all remaining phases without retrying. Use `-PrincipalCheck` for early detection.
- **Non-blocking warnings:** Authorization failures on individual assignments and all Reservations-scope errors are reported as warnings — they appear in the summary but do not change SUCCESS to FAILURE.

---

## Output

The script version (format `YYYYMMDDnnn`) is printed in the opening banner on every run.

Normal output shows phase headers, a progress line per management group and subscription, new assignments created, warnings, errors, and the final summary. Run with `-Verbose` to also see already-existing assignments and full exception details.

## Example Output

Example of a run with `-IncludeManagementGroups` (Phase 2 is skipped by default):

```plaintext
[Phase 2] Assigning roles on management groups...
  [1/12] Root Management Group
  [2/12] Production
  ...

[Phase 3] Assigning roles on subscriptions...
  [1/42] My Subscription
  [2/42] Another Subscription
  ...

================================================================================
Summary
================================================================================
  Management groups processed: 12
  Subscriptions processed:     42
  Subscriptions skipped:       0

  MG role assignments created:         0
  MG role assignments (already exist): 36

  Sub role assignments created:         0
  Sub role assignments (already exist): 126

  Reservation assignments created:         0
  Reservation assignments (already exist): 4

================================================================================
✓ SUCCESS: AOBO configuration completed without errors
================================================================================
```

---

## Error Handling

- The script uses `try/catch` blocks for all operations that can fail
- `PrincipalNotFound` on any assignment excludes the group from all further phases — no retries
- `AuthorizationFailed` on individual assignments is a non-blocking warning, not a failure
- Unexpected errors are collected and reported in the summary

---

## Support

For issues or questions about this script, refer to:

- [IngramMicroNL AOBO Scripts](https://github.com/IngramMicroNL/Azure/tree/main/AOBO%20-%20AdminOnBehalfOf) (reference implementation)
- [Microsoft AOBO Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-external-organizations)
