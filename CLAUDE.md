# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerShell script that automates Azure AOBO (Admin On Behalf Of) role assignments for Wortell CSP. Assigns Owner and Support Request Contributor roles to three Wortell/Ingram Micro admin groups across all management groups and subscriptions in a customer tenant.

## Running the Script

```powershell
# Validate without making changes
.\AOBO-WortellCSP.ps1 -DryRun

# Execute (requires connected Azure context with Global Admin rights)
.\AOBO-WortellCSP.ps1
```

The script can also be executed directly via `Invoke-Expression (Invoke-WebRequest -Uri "...").Content` from Azure Cloud Shell without downloading.

**Prerequisites before running:**
- `Connect-AzAccount` with Global Administrator credentials on the customer tenant
- Az PowerShell module installed
- Groups must be invited as guest objects in the customer tenant

## Linting

PSScriptAnalyzer is used for linting but `Run-lint.ps1` is gitignored and not checked in. The script uses `[Diagnostics.CodeAnalysis.SuppressMessageAttribute]` at the top to suppress the BOM encoding rule (the file is intentionally UTF-8 without BOM for `Invoke-Expression` compatibility).

## Architecture: 7-Phase Execution Model

The script runs sequentially through phases — aborting early only on critical failures:

| Phase | Purpose | Abort condition |
|-------|---------|-----------------|
| 0 | Verify active CSP relationship exists via Foreign Principal | No CSP relationship found |
| 1 | Discover all enabled subscriptions and current user identity | — |
| 2 | Check existing Foreign Principal role assignments (informational) | — |
| 3 | Verify Owner access on each subscription; skip inaccessible ones | No accessible subscriptions |
| 4 | Validate management group access by creating/removing a temp MG | — |
| 5 | Assign configured roles to all management groups | — |
| 6 | Assign configured roles to all subscriptions | — |
| 7 | Remove temporary resources and display summary | — |

## Group Configuration

The three groups and their roles are hardcoded near the top of [AOBO-WortellCSP.ps1](AOBO-WortellCSP.ps1) (around line 50):

- **Wortell CSP Tier 1 AdminAgents** — Owner
- **Wortell CSP Tier 2 AdminAgents** — Owner  
- **IngramMicroNL AdminAgents** — Support Request Contributor

Each group entry has `Name`, `ObjectId`, and `Roles` fields. Object IDs are stable cross-tenant identifiers for CSP foreign principal groups.

## Key Design Patterns

- **Idempotency:** Each role assignment checks if the assignment already exists before creating it — safe to run multiple times.
- **Dry-run throughout:** The `-DryRun` switch is checked inside every assignment block, not just at the entry point.
- **Error accumulation:** Errors are collected into an array and reported in the final summary rather than halting execution mid-run.
- **Counters:** The script tracks created vs. already-existing assignments separately for MGs and subscriptions.
