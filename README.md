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
- Active connection to Azure (`Connect-AzAccount`)
- **Active CSP reseller relationship** between the customer tenant and Wortell CSP partner tenant
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

For advanced usage with parameters like dry-run mode:

```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -OutFile "AOBO-WortellCSP.ps1"

# Execute normally
.\AOBO-WortellCSP.ps1

# Or execute in dry-run mode
.\AOBO-WortellCSP.ps1 -DryRun
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

The script follows a **seven-phase process**:

0. **Phase 0** — Verifies that an active CSP reseller relationship exists by testing Foreign Principal role assignment capability
1. **Phase 1** — Retrieves all enabled subscriptions and identifies the current user
2. **Phase 2** — Checks existing foreign principal role assignments (informational only)
3. **Phase 3** — Verifies that the current user has Owner permissions on each subscription
   - Subscriptions without Owner access are skipped with a warning
4. **Phase 4** — Validates access rights by creating and removing a temporary management group
5. **Phase 5** — Assigns configured roles to all management groups
6. **Phase 6** — Assigns configured roles to all subscriptions
7. **Phase 7** — Cleans up temporary resources and displays a summary

## Output

The script provides detailed progress logging at each step, including:
- Number of subscriptions processed and skipped
- Each role assignment created or already existing
- Any errors encountered with descriptions
- Final summary with success or warning status

## Error Handling

- The script uses `try/catch` blocks for all operations that can fail
- Errors are collected and reported in a summary at the end
- The script continues processing even if individual role assignments fail
- If the current user lacks Owner on all subscriptions, the script returns with an error

## Support

For issues or questions about this script, refer to:
- [IngramMicroNL AOBO Scripts](https://github.com/IngramMicroNL/Azure/tree/main/AOBO%20-%20AdminOnBehalfOf) (reference implementation)
- [Microsoft AOBO Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-external-organizations)
