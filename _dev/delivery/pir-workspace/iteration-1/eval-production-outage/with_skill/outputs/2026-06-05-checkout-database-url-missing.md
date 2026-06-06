# Post-Incident Report: Checkout Service Down — Missing DATABASE_URL in Production

**Date**: 2026-06-05
**Severity**: Critical
**Status**: Resolved
**Duration**: ~32 minutes

## Summary

At 14:32, the production checkout service began returning HTTP 500 errors on all `POST /api/checkout` requests, preventing customers from completing purchases. The root cause was a missing `DATABASE_URL` environment variable in the production container — the result of a "cleanup" refactor (commit `a3f8b2c`) the previous Thursday that removed the `vault_secrets()` function from `deploy.sh` without anyone noticing. Because `DATABASE_URL` is present in local `.env` files, the removal went undetected in development and was only exposed on the next production deploy. The `vault_secrets()` function was restored and a redeployment completed at 15:04, returning the service to normal.

## Timeline

- `14:32` — HTTP 500 errors begin appearing on `POST /api/checkout` in production
- `14:32` — Customers unable to complete purchases
- `14:3x` — Application logs examined; error identified: `could not connect to database — ECONNREFUSED`
- `14:4x` — Production container environment inspected; `DATABASE_URL` confirmed unset
- `14:5x` — `deploy.sh` audited; `vault_secrets()` function found removed in commit `a3f8b2c` (merged previous Thursday, described as a cleanup refactor)
- `14:5x` — Root cause confirmed: secrets were no longer pulled from HashiCorp Vault during deploy
- `~15:00` — `vault_secrets()` restored to `deploy.sh`
- `15:04` — Redeployment to production completed
- `15:04` — Checkout service confirmed working; monitoring green

## Root Cause

The `deploy.sh` script contained a `vault_secrets()` function responsible for fetching secrets from HashiCorp Vault (including `DATABASE_URL`) and injecting them into the production container environment at deploy time. Commit `a3f8b2c`, landed the previous Thursday as a routine cleanup refactor, removed this function without understanding its purpose. Because all developer machines have `DATABASE_URL` defined in local `.env` files, no failure was observable in development or CI. The gap only materialized when the next production deployment ran the modified script — producing a container with no database credentials and causing every database-dependent request to fail immediately.

## Impact

- **Systems**: Checkout service (`POST /api/checkout`), production container runtime, downstream database connection pool
- **Users**: All customers attempting to complete a purchase during the outage window
- **Duration**: ~32 minutes (14:32–15:04)
- **Data**: None — no data loss or corruption; requests failed before reaching the database

## Resolution

1. Identified commit `a3f8b2c` as the source of the regression by auditing `deploy.sh` git history.
2. Restored the `vault_secrets()` function to `deploy.sh` (reverting the removal from the cleanup refactor).
3. Triggered a fresh production deployment; the function re-ran, populating `DATABASE_URL` and other secrets in the container environment.
4. Verified recovery at 15:04 via application logs and uptime monitoring.

## Action Items

- [ ] Add a deployment smoke test or pre-flight check that verifies required env vars (e.g. `DATABASE_URL`) are present in the container before routing traffic — (unassigned)
- [ ] Add a CI lint or test step that fails the pipeline if `vault_secrets()` (or its replacement) is absent from `deploy.sh` — (unassigned)
- [ ] Document the role of `vault_secrets()` in `deploy.sh` with a comment block so future refactors understand the function must not be removed — (unassigned)
- [ ] Review the cleanup refactor commit (`a3f8b2c`) for any other removed logic that may have unintended side effects — (unassigned)
- [ ] Consider adding `DATABASE_URL` (and other required production secrets) to a required-env checklist in the runbook or deployment docs — (unassigned)

## Lessons Learned

- **Local `.env` files masked the regression entirely.** The missing `vault_secrets()` call had no visible effect in development because developers carry the secret locally. A production-parity check in CI — even a simple "does this env var exist?" assertion in a deploy dry-run — would have caught this before it reached customers.
- **"Cleanup" commits are high risk if the reviewer doesn't understand what they're cleaning up.** The function had no documentation or comments explaining why it existed. A one-line comment ("This populates secrets from Vault — do not remove") would have blocked the deletion.
- **The outage was fully recoverable in 32 minutes, but detection took time.** The error message (`ECONNREFUSED`) pointed to the database but not to the cause. A startup check that explicitly asserts required env vars are set — and logs a clear message like `DATABASE_URL is not set — aborting` — would cut diagnosis time from minutes to seconds.
