# Post-Incident Report: Checkout Service Outage — Missing DATABASE_URL

**Date:** 2026-06-05
**Duration:** ~32 minutes (14:32 – 15:04)
**Severity:** P1 — Customer-facing, revenue-impacting
**Status:** Resolved

---

## Summary

The checkout service returned HTTP 500 errors on all `POST /api/checkout` requests for approximately 32 minutes. Customers could not complete purchases during this window. Root cause was a missing `DATABASE_URL` environment variable in the production container, caused by the accidental removal of the Vault secret-fetching function from the deploy script during a refactoring commit the previous Thursday.

---

## Timeline

| Time  | Event |
|-------|-------|
| 14:32 | Checkout service begins returning 500 errors on `POST /api/checkout`. Customers unable to complete purchases. |
| ~14:35 | Application logs reviewed; `ECONNREFUSED` database connection errors found. |
| ~14:45 | Production container env vars inspected; `DATABASE_URL` confirmed missing. |
| ~14:55 | Root cause identified: `vault_secrets()` function removed from `deploy.sh` in commit `a3f8b2c` (last Thursday). |
| 15:04 | `vault_secrets()` restored to `deploy.sh`; redeployment to production complete. |
| 15:04 | Checkout service confirmed healthy; monitoring green. |

---

## Root Cause

A "cleanup" refactoring commit (`a3f8b2c`, landed last Thursday) removed the `vault_secrets()` function from `deploy.sh`. This function is responsible for pulling secrets — including `DATABASE_URL` — from HashiCorp Vault at deploy time and injecting them into the production container environment.

The removal went undetected because:
1. Local development environments have `DATABASE_URL` defined in `.env`, so developers saw no breakage.
2. The commit was described as a cleanup refactor, reducing scrutiny during review.
3. No automated check verified that required secrets were present after deployment.

The missing variable was only surfaced when a subsequent production deployment went out and the container started without `DATABASE_URL`, causing all database connections to fail immediately at runtime.

---

## Impact

- **User impact:** All customers attempting to check out during the 32-minute window received errors and could not complete purchases.
- **Revenue impact:** Unknown; all checkout transactions were blocked for the duration.
- **Data impact:** None — no data corruption or loss.

---

## Resolution

`vault_secrets()` was restored to `deploy.sh` and production was redeployed at 15:04. The function re-fetches all required secrets from HashiCorp Vault during the deploy process, restoring `DATABASE_URL` and any other Vault-managed secrets to the container environment.

---

## Contributing Factors

- **No post-deploy secret validation:** The deploy pipeline does not verify that required environment variables are present and non-empty after a deployment completes.
- **Local/prod environment parity gap:** Developers' local `.env` files mask missing Vault-sourced variables, making it easy to accidentally break secret injection without noticing locally.
- **Code review gap:** The refactoring PR was not recognized as affecting production secret delivery, suggesting the role of `vault_secrets()` was not well understood or documented.

---

## Action Items

| # | Action | Owner | Priority |
|---|--------|-------|----------|
| 1 | Add a post-deploy health check that asserts required env vars (e.g. `DATABASE_URL`) are set before marking a deployment successful | Platform / DevOps | High |
| 2 | Add a comment to `vault_secrets()` in `deploy.sh` explaining its purpose and that removing it will break secret injection in production | Whoever owns `deploy.sh` | High |
| 3 | Document the secret injection flow (Vault → `deploy.sh` → container) in the runbook / onboarding docs | Platform | Medium |
| 4 | Consider a CI lint step that warns if `vault_secrets` is removed from `deploy.sh` without a corresponding replacement | Platform / DevOps | Medium |
| 5 | Review whether `.env` files in local dev should explicitly exclude Vault-managed secrets (or use stubs) to surface this class of issue earlier | Dev Experience | Low |

---

## Lessons Learned

- **Secrets infrastructure is not "cleanup."** Functions that bridge secret stores to runtime environments are load-bearing, even if they look like boilerplate. Remove only with explicit intent and a migration path.
- **Local parity hides production risk.** Any secret that exists locally but not in production via an explicit delivery mechanism creates a latent gap that can survive code review undetected.
- **Smoke tests catch what code review misses.** A simple post-deploy check asserting database connectivity would have surfaced this within seconds of the bad deploy going out.
