# AOBO-WortellCSP

## Introduction

**Admin On Behalf Of (AOBO)** is a security model in Azure that allows Managed Service Providers (MSPs) to manage customer Azure subscriptions on their behalf. This script automates the configuration of AOBO role assignments across all subscriptions and management groups in a customer tenant.

The `AOBO-WortellCSP.ps1` script configures role assignments for:

- **Wortell CSP Tier 1 AdminAgents** — Owner role
- **Wortell CSP Tier 2 AdminAgents** — Owner role
- **IngramMicroNL AdminAgents** — Support Request Contributor role

The script ensures these groups have the appropriate permissions on all management groups and subscriptions, enabling support teams to assist customers without requiring guest invitations.

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
  - In practice this is obtained by using the **Elevate access** button in Azure AD → Properties, which is only available to **Global Administrators**. Once elevated, the Global Admin has User Access Administrator at root scope.
  - If a customer has already granted you Owner at root management group scope directly, Global Administrator is not required.
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
.\AOBO-WortellCSP.ps1 -DryRun

# Pre-validate that all foreign principals can receive assignments before proceeding
# (use when GDAP registration is uncertain; omit if confirmed but API test fails)
.\AOBO-WortellCSP.ps1 -PrincipalCheck

# Pre-verify Owner access on each subscription before assigning roles
# (use when you want to filter out inaccessible subscriptions upfront)
.\AOBO-WortellCSP.ps1 -OwnerCheck

# Show verbose output including full exception details on errors
.\AOBO-WortellCSP.ps1 -Verbose
```

### Dry Run Mode

To validate prerequisites without making any changes:

```powershell
.\AOBO-WortellCSP.ps1 -DryRun
```

**What Dry Run does:**

- Shows what role assignments would be created
- Shows what management groups would be processed
- **No actual changes are made to your Azure environment**

---

## What the Script Does

The script runs through **four phases**, then prints a summary. It aborts early only on critical failures:

| Phase | Purpose | Abort condition |
| ----- | ------- | --------------- |
| 1 | Discover enabled subscriptions and current user identity; optionally validate foreign principals (`-PrincipalCheck`) or verify Owner access per subscription (`-OwnerCheck`) | No enabled subscriptions; or `-PrincipalCheck` used and no principals pass |
| 2 | Assign configured roles to all management groups; `PrincipalNotFound` excludes the group from all remaining phases (no retry); `AuthorizationFailed` recorded as a non-blocking warning | — |
| 3 | Assign configured roles to all subscriptions (or only those passing `-OwnerCheck`) | — |
| 4 | Assign configured roles at the Azure Reservations scope (`/providers/Microsoft.Capacity`); failures recorded as non-blocking warnings | — |
| Summary | Display results — MG and subscription counts, role assignment totals, skipped principals, and any warnings or errors | — |

---

## Key Design Patterns

- **Idempotency:** Each role assignment checks if the assignment already exists before creating it — safe to run multiple times.
- **Dry-run throughout:** The `-DryRun` switch is checked inside every assignment block, not just at the entry point.
- **Graceful principal handling:** If a foreign principal is not found in the tenant during assignment, it is skipped for all remaining phases without retrying. Use `-PrincipalCheck` for early detection.
- **Non-blocking warnings:** Authorization failures on individual assignments and all Reservations-scope errors are reported as warnings — they appear in the summary but do not change SUCCESS to FAILURE.

---

## Output

The script version (format `YYYYMMDDnnn`) is printed in the opening banner on every run.

Normal output is intentionally brief: phase headers, new assignments created, warnings, errors, and the final summary. Run with `-Verbose` to also see already-existing assignments, per-subscription progress, and full exception details.

## Example Output

```plaintext
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
