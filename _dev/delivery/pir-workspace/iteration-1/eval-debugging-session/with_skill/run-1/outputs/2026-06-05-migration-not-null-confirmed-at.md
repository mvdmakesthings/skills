# Post-Incident Report: Migration Failure — NOT NULL on users.confirmed_at

**Date**: 2026-06-05
**Severity**: Medium
**Status**: Resolved
**Duration**: ~45 minutes

## Summary

A Rails migration that added a `NOT NULL` constraint to `users.confirmed_at` failed in staging with a `PG::NotNullViolation`. The root cause was 4,312 legacy user accounts created in 2021 that had never had `confirmed_at` set. The migration author had assumed universal coverage of this column. An attempted rollback also failed due to a dependent index that had to be dropped manually before the rollback could proceed. The incident was fully contained to staging: a backfill set `confirmed_at = created_at` for all null rows, and the migration was re-applied successfully with no data loss.

## Timeline

- `+00:00` — Migration `ALTER TABLE users ALTER COLUMN confirmed_at SET NOT NULL` fails in staging with `PG::NotNullViolation: ERROR: column "confirmed_at" of relation "users" contains null values`
- `+00:05` — Investigation confirms the cause: legacy accounts from 2021 have NULL in `confirmed_at`
- `+00:10` — Attempted rollback via `rake db:rollback` fails: `index users_on_confirmed_at depends on column confirmed_at`
- `+00:20` — Index manually dropped: `DROP INDEX CONCURRENTLY users_on_confirmed_at`; rollback succeeds
- `+00:25` — Backfill written and executed: `UPDATE users SET confirmed_at = created_at WHERE confirmed_at IS NULL` — 4,312 rows updated
- `+00:40` — Migration re-run successfully; constraint applied; staging verified clean
- `+00:45` — Incident closed

## Root Cause

The migration assumed all existing `users` rows had a non-null `confirmed_at` before adding the `NOT NULL` constraint. This assumption was incorrect: accounts created in 2021 were never backfilled when `confirmed_at` was originally introduced, leaving 4,312 rows with `NULL`. PostgreSQL enforces `NOT NULL` constraints against all existing rows at the time of the `ALTER TABLE`, so the migration failed immediately.

A secondary complication: a concurrent index on `confirmed_at` existed that Postgres would not allow to remain if the column were to be removed or altered in a way the index depended on, causing the rollback to fail without manual index removal first.

## Impact

- **Systems**: `users` table migration in the staging database; the Rails migration pipeline
- **Users**: Internal only — staging environment, no end users affected
- **Duration**: ~45 minutes of a blocked staging deployment
- **Data**: None lost or corrupted; 4,312 rows updated with best-available value (`created_at`)

## Resolution

1. Manually dropped the blocking index in staging:
   ```sql
   DROP INDEX CONCURRENTLY users_on_confirmed_at;
   ```
2. Rolled back the failed migration:
   ```
   rake db:rollback
   ```
3. Ran a backfill to eliminate all null values:
   ```sql
   UPDATE users SET confirmed_at = created_at WHERE confirmed_at IS NULL;
   ```
   (4,312 rows updated)
4. Re-applied the migration:
   ```
   rake db:migrate
   ```
   Migration succeeded. Staging verified healthy.

## Action Items

- [ ] Add a data guard to the migration (or a pre-migration check script) that raises if any null rows exist before applying `NOT NULL` — (unassigned)
- [ ] Apply the same `confirmed_at` backfill to production before this migration is run there — (unassigned)
- [ ] Audit other columns with recent `NOT NULL` additions to confirm equivalent backfills were run at the time — (unassigned)
- [ ] Document in migration conventions: always include a backfill step (or assert zero nulls) before adding `NOT NULL` to an existing column — (unassigned)

## Lessons Learned

**Assumption about data coverage was not verified.** The migration author assumed all users had `confirmed_at` set. A simple `SELECT COUNT(*) FROM users WHERE confirmed_at IS NULL` before writing the migration would have caught this. For any `NOT NULL` migration on an existing column, verifying zero nulls in all environments should be a mandatory preflight step.

**Rollback was not a clean escape hatch.** The dependent index made a standard `rake db:rollback` fail, requiring manual SQL intervention. Migrations that add both a column constraint and a related index should account for rollback ordering — drop the index before reversing the constraint, or use reversible migration DSL that handles this explicitly.

**The backfill value was a judgment call.** Using `created_at` as a proxy for `confirmed_at` is reasonable but not provably correct for every legacy account. This should be flagged in the production deploy plan so stakeholders are aware the value is an approximation, not historical truth.
