# Post-Incident Report: Rails Migration Failure — `users.confirmed_at` NOT NULL Violation

**Date:** 2026-06-05
**Environment:** Staging
**Duration:** ~45 minutes
**User Impact:** None (staging only)

---

## Summary

A Rails migration that added a `NOT NULL` constraint to `users.confirmed_at` failed in staging because 4,312 legacy user accounts (created circa 2021) had `NULL` in that column. An initial rollback attempt also failed due to a dependent index. The index was manually dropped, the rollback succeeded, a backfill was applied, and the migration was re-run successfully.

---

## Timeline

| Time | Event |
|------|-------|
| T+0  | Migration runs in staging. Fails with `PG::NotNullViolation: column "confirmed_at" of relation "users" contains null values`. |
| T+~5 | `rake db:rollback` attempted. Fails: `index users_on_confirmed_at depends on column confirmed_at`. |
| T+~15 | Index manually dropped: `DROP INDEX CONCURRENTLY users_on_confirmed_at;`. Rollback succeeds. |
| T+~25 | Backfill written and executed: `UPDATE users SET confirmed_at = created_at WHERE confirmed_at IS NULL;` — 4,312 rows updated. |
| T+~40 | Migration re-run. Succeeds. No data loss. |
| T+~45 | Incident resolved. |

---

## Root Cause

The migration assumed all existing `users` rows had a non-null `confirmed_at`. This assumption was incorrect: legacy accounts from 2021 were created before the `confirmed_at` column was reliably populated. Adding `NOT NULL` without a prior backfill or a `DEFAULT` clause causes Postgres to reject the `ALTER TABLE` immediately on any row where the column is null.

---

## Contributing Factors

- **No pre-migration data audit.** The presence of null values in `confirmed_at` was not verified before writing the migration.
- **Dependent index blocked rollback.** The migration (or a prior one) created an index on `confirmed_at`. Postgres will not drop or alter a column while an index depends on it, so the automatic rollback path was unavailable until the index was removed manually.

---

## Resolution

1. Manually dropped the blocking index: `DROP INDEX CONCURRENTLY users_on_confirmed_at;`
2. Rolled back the failed migration via `rake db:rollback`.
3. Applied a targeted backfill to fill null values with a reasonable default (`created_at`): `UPDATE users SET confirmed_at = created_at WHERE confirmed_at IS NULL;`
4. Re-ran the migration successfully.

---

## What Went Well

- Issue was contained to staging; no production data or users were affected.
- The backfill strategy (using `created_at` as a proxy) was a reasonable, non-destructive default.
- Full recovery achieved in under an hour.

---

## Action Items

| # | Action | Priority |
|---|--------|----------|
| 1 | **Add a pre-migration check pattern to the team playbook**: before adding `NOT NULL` to an existing column, query for null counts and run a backfill migration first. | High |
| 2 | **Codify the safe NOT NULL pattern**: new migration → backfill migration → constraint migration (three-step deploy), or use `add_not_null_constraint` with `validate: false` if the Rails version/PG version supports it. | High |
| 3 | **Document the dependent-index rollback gotcha**: when a rollback fails citing a dependent index, the fix is `DROP INDEX CONCURRENTLY` first, then rollback. | Medium |
| 4 | **Consider a staging data-quality check in CI**: a lightweight rake task that flags columns with unexpected nulls before migration runs. | Low |

---

## Notes

- Rows updated by backfill: **4,312**
- Backfill used `confirmed_at = created_at`, which is a sensible proxy (the account existed, so treating the creation time as confirmation time is acceptable for legacy records).
- `DROP INDEX CONCURRENTLY` was used to avoid locking the table; appropriate for staging and should be the default approach for production as well.
