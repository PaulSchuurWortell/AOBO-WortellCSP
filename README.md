# AOBO-WortellCSP

## Introduction

**Admin On Behalf Of (AOBO)** is a security model in Azure that allows Managed Service Providers (MSPs) to manage customer Azure subscriptions on their behalf. This script automates the configuration of AOBO role assignments across all subscriptions in a customer tenant.

The `AOBO-WortellCSP.ps1` script configures role assignments for:

- **Wortell CSP Tier 1 AdminAgents** — Owner role
- **Wortell CSP Tier 2 AdminAgents** — Owner role
- **IngramMicroNL AdminAgents** — Support Request Contributor role

The script ensures these groups have the appropriate permissions on all management groups and subscriptions, enabling support teams to assist customers without requiring guest invitations.

## Prerequisites

- **Azure Cloud Shell** (recommended) or local PowerShell environment with Az module
- **Global Administrator** rights on the customer Azure tenant
- **Active connection to Azure** (`Connect-AzAccount`)
- **Active CSP reseller relationship** between the customer tenant and Wortell CSP partner tenant
- **Unrestricted Owner access** to the Azure subscriptions and/or management groups being configured
- **AOBO groups must be invited as guests** in the customer tenant:
  - Wortell CSP Tier 1 AdminAgents (`2e59f31c-83fd-4ca1-bed4-4b4ee704c0f7`)
  - Wortell CSP Tier 2 AdminAgents (`27f932e9-605d-4270-bf3f-a02249b1721c`)
  - IngramMicroNL AdminAgents (`34c4dd11-78c0-41e5-8370-c6dbf16bc3e9`)

## Usage

### Option 1: Direct Execution (Recommended)

Open **Azure Cloud Shell** (PowerShell) and paste this command:

```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -UseBasicParsing).Content
```

### Option 2: Download and Execute with Parameters

For advanced usage with parameters:

```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -OutFile "AOBO-WortellCSP.ps1"

# Execute normally
.\AOBO-WortellCSP.ps1

# Execute in dry-run mode
.\AOBO-WortellCSP.ps1 -DryRun

# Skip Phase 3 Owner pre-flight check (use when Owner is assigned via a parent management group
# and the check incorrectly marks subscriptions as inaccessible)
.\AOBO-WortellCSP.ps1 -SkipOwnerCheck

# Show verbose output including full exception details on errors
.\AOBO-WortellCSP.ps1 -Verbose
```

### Dry Run Mode

To validate prerequisites without making any changes:

```powershell
# Download first, then run with -DryRun
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -OutFile "AOBO-WortellCSP.ps1"
.\AOBO-WortellCSP.ps1 -DryRun
```

**What Dry Run does:**

- Validates all prerequisites (CSP relationship, group existence, permissions)
- Shows what role assignments would be created
- Shows what management group operations would be performed
- **No actual changes are made to your Azure environment**

## What the Script Does

The script follows a **nine-phase process** (phases 0–8), aborting early only on critical failures:

| Phase | Purpose | Abort condition |
| ----- | ------- | --------------- |
| 0 | Verify active CSP relationship and guest presence by test-assigning each unique foreign principal; distinguishes `RoleAssignmentExists` (treated as success), `AuthorizationFailed`, and other errors; full exception shown with `-Verbose`; failed principals are excluded from role assignments rather than aborting; only aborts if no principals pass | No principals validated |
| 1 | Discover all enabled subscriptions and current user identity | — |
| 2 | Check existing Foreign Principal role assignments (informational) | — |
| 3 | Verify effective Owner access on each subscription — accepts direct assignment, group membership, or parent MG inheritance; skip inaccessible ones. Use `-SkipOwnerCheck` to bypass entirely. | No accessible subscriptions |
| 4 | Validate management group access by creating/removing a temp MG — indirect Owner (via group or root MG) is accepted because this is a real action test | — |
| 5 | Assign configured roles to all management groups for validated principals only | — |
| 6 | Assign configured roles to all subscriptions for validated principals only | — |
| 7 | Assign configured roles at the Azure Reservations scope (`/providers/Microsoft.Capacity`) for validated principals only; failures recorded as non-blocking warnings | — |
| 8 | Remove temporary resources and display summary | — |

## Key Design Patterns

- **Idempotency:** Each role assignment checks if the assignment already exists before creating it — safe to run multiple times.
- **Dry-run throughout:** The `-DryRun` switch is checked inside every assignment block, not just at the entry point.
- **Error accumulation:** Errors are collected into an array and reported in the final summary rather than halting execution mid-run.
- **Counters:** The script tracks created vs. already-existing assignments separately for MGs and subscriptions.
- **Validated principals:** Phase 0 tests each foreign principal individually; only those that pass are used in Phases 5, 6, and 7. A partial failure warns and continues rather than aborting.
- **Non-blocking reservation warnings:** Phase 7 failures are collected separately and do not affect the SUCCESS/FAILURE outcome.

## Output

The script version (format `YYYYMMDDnnn`) is printed in the opening banner on every run.

Normal output is intentionally brief: phase headers, new assignments created, warnings, errors, and the final summary. Run with `-Verbose` to also see already-existing assignments, per-subscription progress, and full exception details.

## Example Output

```plaintext
================================================================================
Summary
================================================================================
  Management groups processed: 12
  Subscriptions processed:     4
  Subscriptions skipped:       0

  MG role assignments created:   0
  MG role assignments (already exist): 36

  Sub role assignments created:   0
  Sub role assignments (already exist): 12

================================================================================
✓ SUCCESS: AOBO configuration completed without errors
================================================================================
```

## Error Handling

- The script uses `try/catch` blocks for all operations that can fail
- Errors are collected and reported in a summary at the end
- The script continues processing even if individual role assignments fail
- If the current user lacks Owner on all subscriptions, the script returns with an error

## Support

For issues or questions about this script, refer to:

- [IngramMicroNL AOBO Scripts](https://github.com/IngramMicroNL/Azure/tree/main/AOBO%20-%20AdminOnBehalfOf) (reference implementation)
- [Microsoft AOBO Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-external-organizations)
