# Run notes — DB health audit (charter LOCAL stack)

**Date:** 2026-06-06
**Constraints honored:** READ-ONLY, LOCAL stack only, no remote/linked project, no file modifications in the charter repo, no INSERT/UPDATE/DELETE/DDL.

## Environment discovery

```bash
supabase status            # in /Users/michaelvandyke/Dev/charter — got DB URL + confirmed running
which psql                 # NOT found on host
docker ps --format '{{.Names}}\t{{.Image}}' | grep -iE 'postgres|supabase_db'
                           # found container: supabase_db_luxembourg (supabase/postgres:17.6.1.121)
docker exec supabase_db_luxembourg psql -U postgres -d postgres -t -A -c "select version();"
                           # confirmed psql reachable inside the container
```

**Decision:** host `psql` missing; libpq psql at `/opt/homebrew/opt/libpq/bin/psql` exists but to avoid any host networking issues I ran all SQL inside the running `supabase_db_luxembourg` container via `docker exec ... psql`. This is the same local stack (port 54322), just reached over the container's local socket. Confirmed read-only by prefixing every session with `SET default_transaction_read_only = on;` (a write would error out).

## Queries executed (all read-only)

Every query was prefixed with `SET default_transaction_read_only = on;` in the same `psql -c` session.

1. **Schema/table inventory** — table count per schema (`pg_class` + `pg_namespace`, `relkind='r'`).
2. **RLS status (public)** — `relrowsecurity`, `relforcerowsecurity`, policy count via correlated `pg_policy`, total size, est rows.
3. **Index usage (public)** — `pg_stat_user_indexes` joined to `pg_index`, ordered by `idx_scan ASC`, with size/unique/primary flags.
4. **Bloat proxy** — `pg_stat_user_tables`: live/dead tuples, dead %, mods since analyze, last (auto)vacuum/(auto)analyze.
5. **RLS-enabled-no-policy** — all non-system schemas: `relrowsecurity = true` AND `NOT EXISTS` matching `pg_policy`.
6. **RLS-disabled** — `public`/`storage`/`realtime` tables with `relrowsecurity = false`.
7. **Grants on zero-policy tables** — `information_schema.role_table_grants` for `admins` + `onboarding_form_fields`, grouped by grantee.
8. **Migration drift** — `SELECT version FROM supabase_migrations.schema_migrations ORDER BY version` and `count(*)`, compared against `ls supabase/migrations/*.sql` on disk (43 == 43).
9. **FK index coverage (first pass)** — `pg_constraint` (contype='f') expanded via `unnest(conkey)`, flagging FKs whose leading column has no index.
10. **FK index coverage (reconciled)** — single-column FKs vs. `EXISTS` of any index whose leading key = FK column (catches partial indexes).
11. **SECURITY DEFINER functions** — `pg_proc.prosecdef = true` in `public` with `proconfig` (search_path) listed (53 functions, all pinned).
12. **Extensions + DB size** — `pg_extension`; `pg_database_size('postgres')` = 15 MB.
13. **locations index definitions** — `pg_get_indexdef` for all indexes on `public.locations` (confirmed `idx_locations_account_id` is a prefix duplicate).
14. **Stats reset / uptime** — `pg_stat_database.stats_reset` (2026-06-05 21:48 UTC) and `current_timestamp - pg_postmaster_start_time()` (~16.5 h) to caveat the idx_scan=0 readings.
15. **Prefix-redundant index scan (app-wide)** — `pg_get_indexdef` for all public indexes, filtered for `(account_id)` / `(brand_id)` / `(location_id)` / `(state)` leading columns to find duplicates beyond `locations`.
16. **Invalid indexes** — `pg_index.indisvalid = false` in public (none) + top-5 tables by total/index size.

## Key reconciliations

- FK first pass (q9) flagged 15 FKs; reconciled pass (q10) showed all hot-path FK columns are covered by composite/partial indexes — the 10 genuinely uncovered are all `auth.users` audit columns.
- Three single-column `(account_id)` indexes confirmed as strict prefixes of existing composites (q13, q15) — structural duplicates, safe to drop regardless of usage stats.
- High dead-tuple % and idx_scan=0 attributed to the 15 MB seed DB + 16.5 h-old stats reset (q14), so labeled LOW CONFIDENCE / artifact rather than real bloat / unused.

## Confirmations I would have asked a human (assumed safest, proceeded)

- "Are the broad anon/authenticated grants on `admins` / `onboarding_form_fields` intentional?" — assumed they should be locked down (safest); reported as a recommendation, made no change.
- "Should I check the linked prod project for drift / real usage?" — constraint says prod is off-limits; assumed NO, flagged it as human follow-up instead.

## Not done (by constraint)

- No queries against the linked/remote prod project.
- No DDL (so `pgstattuple` not installed; no exact bloat numbers).
- No writes/VACUUM/ANALYZE. No edits to any charter repo file.
```