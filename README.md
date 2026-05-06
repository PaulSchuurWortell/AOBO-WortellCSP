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

## Usage

### Option 1: Execute Directly from GitHub (Recommended for Cloud Shell)

Open **Azure Cloud Shell** (PowerShell) and run:

```powershell
$uri = "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1"
Invoke-WebRequest -Uri $uri -OutFile AOBO-WortellCSP.ps1
.\AOBO-WortellCSP.ps1
```

**Or as a one-liner:**

```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -UseBasicParsing).Content
```

### Option 2: Run Locally

1. Clone or download the repository
2. Open PowerShell as Administrator
3. Ensure you are connected to Azure:
   ```powershell
   Connect-AzAccount
   ```
4. Execute the script:
   ```powershell
   .\AOBO-WortellCSP.ps1
   ```

## What the Script Does

The script follows a **six-phase process**:

1. **Phase 1** — Retrieves all enabled subscriptions and identifies the current user
2. **Phase 2** — Verifies that the current user has Owner permissions on each subscription
   - Subscriptions without Owner access are skipped with a warning
3. **Phase 3** — Validates access rights by creating and removing a temporary management group
4. **Phase 4** — Assigns configured roles to all management groups
5. **Phase 5** — Assigns configured roles to all subscriptions
6. **Phase 6** — Cleans up temporary resources and displays a summary

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
- If the current user lacks Owner on all subscriptions, the script exits with an error

## Support

For issues or questions about this script, refer to:
- [IngramMicroNL AOBO Scripts](https://github.com/IngramMicroNL/Azure/tree/main/AOBO%20-%20AdminOnBehalfOf) (reference implementation)
- [Microsoft AOBO Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-external-organizations)
