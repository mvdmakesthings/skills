# Charter — Database Health Audit

**Date:** 2026-06-06
**Target:** LOCAL Supabase stack only — `postgres` @ `127.0.0.1:54322` (container `supabase_db_luxembourg`). The linked/remote `charter-prod` project was **not** touched (off-limits per run constraints).
**Mode:** Read-only. No writes, DDL, or destructive statements were executed. The two `set local role anon` probes ran inside `BEGIN; … ROLLBACK;` purely to confirm RLS behaviour.
**Method:** Postgres catalog + `pg_stat_*` queries from the `dba` skill's diagnostic library (Q-IDs cited per finding). Rule-level recommendations defer to the `supabase-postgres-best-practices` skill and cite the applied rule.

---

## Executive summary

The schema's **security posture is sound and consistent with the documented model**: every `public` table has RLS enabled, writes are funneled through `SECURITY DEFINER` RPCs (client roles hold no INSERT/UPDATE/DELETE grant on the sensitive tables), and the `internal_intake_responses` hardening described in `CLAUDE.md` is in place. RLS empirically blocks `anon` reads and writes even on tables where stock Supabase default-privileges left broad grants behind. No invalid indexes, no missing primary keys, no repo-vs-local migration drift, and a healthy 0.23% rollback ratio (no recurrence of the 2026-06-05 `40001` storm).

The two things that actually matter:

1. **Defense-in-depth gap (Medium):** stock Supabase `ALTER DEFAULT PRIVILEGES` granted `anon` full DML — and SELECT on 8 tables, including `accounts`/`admins`/`account_user` — on every `public` table. RLS is currently the *only* barrier; if RLS were ever disabled on a table (a one-line mistake), `anon` would have write/read access. The project already REVOKEs writes from `authenticated`; it does not do the symmetric REVOKE for `anon`.
2. **Unindexed foreign keys (Low–Medium):** 10 FK columns referencing `auth.users` (the `*_by` / `respondent_id` attribution columns) have no covering index.

**What I did NOT examine / could not conclude here:**

- **Unused indexes, bloat, and query-load are INCONCLUSIVE on this data.** The local DB is essentially empty (largest table 77 rows; total app data < 1 MB; every index 16 kB) and `pg_stat` counters were reset ~1 day ago (`2026-06-05 21:48`). `idx_scan = 0` here means "not hit in a day of local dev/tests," not "unused in production" — the list even includes primary keys. Bloat percentages (72–100% dead tuples) are meaningless at 0–35 rows. These three areas must be re-run against **production** statistics to draw any conclusion.
- **Production schema drift could not be verified.** Repo migrations match the local DB exactly, but the linked/prod project was off-limits, so repo-vs-prod drift (the real risk, given manual `db push`) is unconfirmed.
- `pgstattuple` is not installed, so any bloat figure would be an estimate regardless.

---

## Findings

| # | Area | Severity | Evidence | Recommendation | Fix (SQL — not executed) |
|---|------|----------|----------|----------------|--------------------------|
| 1 | Write-path integrity / grants | **Medium** | Q-TABLE-GRANTS + `pg_default_acl`: `anon` holds `INSERT, UPDATE, DELETE, TRUNCATE` on **all 17** `public` tables (incl. `internal_intake_responses`, `brand_responses`, `accounts`) and `SELECT` on 8 (incl. `accounts`, `admins`, `account_user`, `locations`, `onboarding_responses`). Source is stock Supabase `ALTER DEFAULT PRIVILEGES` for `postgres`/`supabase_admin` (`anon=arwdDxtm` on `public`), not a project migration. RLS empirically denies it today (anon INSERT → `42501`; anon SELECT on `accounts` → 0 rows). | RLS is the sole barrier; remove the unnecessary surface so a future "disable RLS" mistake isn't a data breach. Mirror the existing `authenticated` REVOKE pattern for `anon`. Per `supabase-postgres-best-practices` data-access / least-privilege guidance. Track as a follow-up cleanup. | `REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon;` and `REVOKE SELECT ON public.accounts, public.admins, public.account_user, public.locations, public.onboarding_responses, public.brands, public.location_intake_completion, public.onboarding_form_fields FROM anon;` — confirm no anon read path depends on these first. |
| 2 | Index health — FK coverage | **Low–Medium** | Q-FK-NO-INDEX (public only): 10 FKs to `auth.users` with no covering index — `accounts.created_by`, `accounts.billing_contact_updated_by`, `onboarding_responses.updated_by`, `location_intake_completion.completed_by`, `internal_intake_responses.updated_by`, `account_integration_grants.last_transitioned_by`, `integration_grant_transitions.actor_id`, `account_intake_responses.updated_by`, `brand_responses.respondent_id`, `brand_responses.updated_by`. | Per `query-missing-indexes`, FK columns should be covered so a parent-side DELETE/UPDATE doesn't seq-scan the child. Real-world severity is muted because the parent is `auth.users` (rarely hard-deleted) and these columns are attribution metadata, not query predicates — so this is a "schedule it" item, not urgent. Add only if user deletion or attribution-filtered queries become real. | e.g. `CREATE INDEX CONCURRENTLY idx_brand_responses_respondent_id ON public.brand_responses(respondent_id);` (one per column). `CONCURRENTLY` avoids the write-blocking lock of a plain `CREATE INDEX`; cannot run inside a migration transaction block. |
| 3 | Unused indexes | **Low (inconclusive)** | Q-IDX-UNUSED: 16 `public` indexes at `idx_scan = 0`, but `stats_reset = 2026-06-05 21:48` (~1 day) and the DB is near-empty. The zero-scan list includes primary keys (`account_user_pkey`, `onboarding_responses_pkey`, …) — proof the signal is "untouched in dev," not "useless." | **Do not drop anything on this evidence.** Re-run Q-IDX-UNUSED against production after a representative window (≥ 1–2 weeks since the last `stats_reset`), then risk-rank (constraint-backing, rare-but-critical paths) via the cleanup workflow. | None — measurement gap, not a fix. |
| 4 | Bloat & dead tuples | **Low (inconclusive)** | Q-DEAD-TUPLES shows 72–100% dead on several tables (`integration_types` 35 dead, `internal_intake_responses` 23, `onboarding_responses` 19) — but live counts are 0–35 rows; this is normal test-run churn autovacuum hasn't swept. Q-RELATION-SIZES: largest table 184 kB. `pgstattuple` not installed. | No bloat concern at this scale. Re-assess on production; install/enable `pgstattuple` there for exact figures rather than the `pg_stat_user_tables` estimate. | None — no actionable bloat locally. |
| 5 | Query & load health | **Low (inconclusive)** | Q-TOP-TOTAL-TIME top entries are all test/platform noise: pgTAP harness (`select plan()`, `finish()`, `throws_ok`), Supabase realtime/PostgREST internals, `pg_timezone_names`. Q-TEMP-SPILL: none. No application query load exists locally. | Re-run Q-TOP-TOTAL-TIME / Q-TOP-MEAN-TIME against production to find real hot paths; cross-reference with Q-SEQSCAN-HEAVY there. `pg_stat_statements` is installed (good — load analysis is possible in prod). | None — no real workload to optimize locally. |
| 6 | Operational posture — alerting | **Medium** | PIR `2026-06-05-postgrest-40001-retry-storm.md` open action item: *"Add alerting on rollback ratio (`xact_rollback`/`xact_commit`) or REST 5xx rate"* is still unchecked (`[ ]`, unassigned). Current local ratio is healthy (0.23%), so nothing is firing — but the detection gap that let the storm run 4 hours unnoticed remains open. | Implement the rollback-ratio / 5xx alert. This is the single highest-leverage operational fix from the last incident; the code-level causes were already remediated (no `40001` in deterministic RPC paths — confirmed by the migration). | None (alerting/infra change, outside DB DDL). |
| 7 | RLS — enabled, zero policies | **Low (by design)** | Q-RLS-STATUS: `admins` and `onboarding_form_fields` have RLS enabled but **0 policies**. | Verified intentional: both are read via `is_admin()` (`SECURITY DEFINER`, bypasses RLS as owner) / the admin RPC path; zero policies correctly denies direct `authenticated`/`anon` access. Consistent with `CLAUDE.md` "defense by construction." No change — flagged so a future reviewer doesn't misread it as a lockout bug. | None. |
| 8 | Migration drift (local) | **None (informational)** | 43 repo `.sql` migrations == 43 rows in `supabase_migrations.schema_migrations`; both top out at `20260605213520`. Working tree clean. | No repo-vs-local drift. **Caveat:** repo-vs-**prod** drift was not checkable (prod off-limits). Given the documented manual `supabase db push --linked` deploy model, verify prod is on `20260605213520` via `supabase migration list --linked` per `docs/PR-CHECKLIST.md` before relying on this. | None locally. |

### Not findings (verified healthy)
- **Primary keys:** Q-TBL-NO-PK — zero `public` tables without a PK (the only no-PK tables are in the `net` extension schema).
- **Invalid indexes:** Q-IDX-INVALID — none. **Duplicate indexes:** Q-IDX-DUPLICATE — none in `public` (the 2 hits are Supabase-managed `storage`/`auth` tables).
- **Sequences:** Q-SEQ-EXHAUSTION — only `auth.refresh_tokens_id_seq` at 0.0000% of a `bigint` max. No `int4` PK exhaustion risk.
- **Rollback ratio:** Q-ROLLBACK-RATIO — 0.23%, deadlocks 0. No sign of the `40001` retry storm; cache hit 99.97%.
- **`internal_intake_responses` hardening:** `authenticated` holds only `SELECT, REFERENCES, TRIGGER, TRUNCATE` (no INSERT/UPDATE/DELETE) and its sole read policy is `is_admin()` — matches the `CLAUDE.md` Tier-0 model.

---

## Recommended next steps

1. **Re-run the load/index/bloat portions against production** (read-only catalog/stats queries are prod-safe) after a representative observation window — findings #3, #4, #5 are gated on that. This is where unused-index and bloat decisions actually get made; the cleanup workflow can take them from there.
2. **Schedule finding #1** (revoke stale `anon` grants) and **finding #2** (FK indexes) as small migrations through the project's normal `supabase db push` path + pgTAP coverage — not as live DDL.
3. **Close the PIR alerting gap (#6)** — highest operational leverage.
4. **Confirm prod migration parity** (`supabase migration list --linked`) to close finding #8's caveat.

I can spin findings #1/#2 into the **cleanup** workflow (measured candidates → risk-ranked → gated migration with lock costs) or take the prod load/index re-run into the **slow-query / cleanup** workflows whenever you want. Want me to?

*What I did not touch: no writes, DDL, or destructive operations were executed; the two anon probes were rolled back; the linked/prod project was never queried. All fixes above are proposals shown as SQL, not run.*
