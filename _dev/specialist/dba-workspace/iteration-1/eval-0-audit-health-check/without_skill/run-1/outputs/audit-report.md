# Database Health Audit — charter (LOCAL Supabase stack)

**Date:** 2026-06-06
**Target:** LOCAL stack only — `postgresql://postgres:postgres@127.0.0.1:54322/postgres` (Postgres 17.6, Supabase `17.6.1.121`)
**Access:** All queries run READ-ONLY (`SET default_transaction_read_only = on`) via the `supabase_db_luxembourg` container's `psql`. No writes, no DDL, no remote/linked project touched.
**Scope:** Application schema `public` (17 tables, 15 MB total DB). Supabase-managed schemas (`auth`, `storage`, `realtime`, etc.) noted only where relevant.

---

## Reliability caveat — read this before the index section

This is a **seeded local dev database**, not production:

- Total DB size is **15 MB**; the largest table (`onboarding_form_fields`) has 77 rows. Most tables have single-digit row counts.
- Statistics were last reset **2026-06-05 21:48 UTC** (~16.5 h before this audit) and the server has been up ~16.5 h. The recorded workload is near-zero (seed scripts + a little manual QA).

Consequently, **`idx_scan = 0` and dead-tuple percentages on this stack are NOT trustworthy signals** of real production behavior. Where a finding depends on runtime statistics, it is labeled **LOW CONFIDENCE**. Where a finding is **structural** (true regardless of traffic — e.g. one index is a strict prefix of another), it is labeled **HIGH CONFIDENCE** and is safe to act on. To get meaningful usage/bloat data, re-run the runtime queries against production (read-only) after a representative window. Production query must be done by a human — it was explicitly out of scope here.

---

## Summary

| Area | Status | Notes |
|---|---|---|
| Schema drift (local) | **Clean** | 43 migrations applied = 43 files on disk, exact version match |
| RLS coverage | **Good, 2 items to confirm** | All 17 public tables have RLS enabled; 2 have RLS-on-but-zero-policies + broad table grants (latent risk) |
| Redundant indexes | **3 droppable duplicates** | Three single-column `(account_id)` indexes are strict prefixes of existing composites |
| Unused indexes | **Inconclusive locally** | Many show 0 scans, but that's the dev-traffic artifact above — re-check on prod |
| FK index coverage | **Good** | All hot/cascade FK paths covered; 10 uncovered FKs are all `auth.users` audit columns (acceptable) |
| SECURITY DEFINER hygiene | **Excellent** | All 53 SECURITY DEFINER functions pin `search_path` |
| Bloat | **None real** | High dead-tuple % is a tiny-table autovacuum-timing artifact, not bloat |
| Invalid indexes | **None** | No failed `CREATE INDEX CONCURRENTLY` leftovers |

---

## 1. Schema drift — CLEAN (locally)

- Applied migration versions in `supabase_migrations.schema_migrations`: **43**.
- Migration `.sql` files in `supabase/migrations/`: **43**.
- Every applied version maps 1:1 to a file (latest: `20260605213520_stale_seq_errcode_p0409`). No orphan applied versions, no unapplied files locally.

**Important limitation:** Per `CLAUDE.md`, migrations are **not** auto-applied on prod deploy (`supabase db push --linked` is manual). This audit can only confirm the **local** DB is in sync with the repo. It says **nothing** about whether production has the same 43 migrations applied. The genuine drift risk for this project lives on the linked prod project, which was out of scope. Recommend a human run `supabase migration list --linked` to confirm prod parity.

---

## 2. Row-Level Security

### All public tables have RLS enabled

All 17 `public` tables have `relrowsecurity = true`. None use `FORCE ROW LEVEL SECURITY` (`relforcerowsecurity = false`), which is normal — table owners/superusers and `BYPASSRLS` roles (service_role) intentionally bypass, and writes go through SECURITY DEFINER RPCs.

### Finding 2a — Two tables: RLS enabled, ZERO policies, but broad grants (CONFIRM)

`public.admins` and `public.onboarding_form_fields` have RLS **enabled** but **no policies**. RLS-on-with-no-policy is default-deny, so today neither `anon` nor `authenticated` can read or write them through PostgREST — **currently safe**. Reads happen via SECURITY DEFINER RPCs (`list_admins`, `is_admin`, `list_onboarding_form_fields`, etc.), which is the intended pattern.

The latent risk: both tables still carry **full table-level DML grants** (`SELECT, INSERT, UPDATE, DELETE, TRUNCATE, ...`) to `anon` and `authenticated`:

```
admins                  -> anon, authenticated: SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
onboarding_form_fields  -> anon, authenticated: SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
```

These are the Supabase default grants to the `anon`/`authenticated` roles. They are only held back by the RLS default-deny. This is **weaker than the defense-in-depth pattern `CLAUDE.md` describes for `internal_intake_responses`** (which additionally `REVOKE`s the grants so a future accidental permissive policy can't open a hole). For two tables holding admin identity (`admins`) and the form schema, the asymmetry is worth closing.

**Recommendation (would-confirm-with-owner; assuming safest = lock down):** mirror the `internal_intake_responses` hardening — `REVOKE INSERT/UPDATE/DELETE/TRUNCATE` (and `SELECT` where appropriate) from `anon`/`authenticated`, keeping writes solely on the SECURITY DEFINER RPC path. No behavior change today; removes the "one bad policy away from exposure" footgun. (No change made — this audit is read-only.)

### Not findings (normal Supabase behavior)

- `auth.*` tables show RLS-enabled-no-policy — managed by GoTrue via the service role; expected.
- `realtime.messages_*` partitions and `realtime.subscription`/`schema_migrations` have RLS **disabled** — managed by the Realtime service; expected, not an app gap.

---

## 3. Indexes

### Finding 3a — Three redundant single-column indexes (HIGH CONFIDENCE, droppable)

Each of these single-column `(account_id)` btree indexes is a **strict left-prefix** of an existing composite index, so the composite already serves every query the single-column index could. They add write overhead and storage for no read benefit, independent of traffic:

| Redundant index | Table | Superseded by |
|---|---|---|
| `idx_locations_account_id` `(account_id)` | `locations` | `idx_locations_account_brand_id (account_id, brand_id)` — also `locations_account_id_unique (account_id, id)` |
| `idx_brand_responses_account_id` `(account_id)` | `brand_responses` | `idx_brand_responses_brand_id (account_id, brand_id)` |
| `idx_brand_strategy_runs_account_id` `(account_id)` | `brand_strategy_runs` | `idx_brand_strategy_runs_brand_id (account_id, brand_id)` |

**Recommendation:** drop the three single-column `(account_id)` indexes. Use `DROP INDEX CONCURRENTLY` on prod. (Note the misleading naming: `idx_brand_responses_brand_id` and `idx_brand_strategy_runs_brand_id` actually lead with `account_id` — the composite, not the `account_id`-only index, is the one to keep.) No change made here.

### Finding 3b — "Unused" indexes (LOW CONFIDENCE — do not act on local data)

Many indexes show `idx_scan = 0` (e.g. `idx_locations_account_id`, `idx_brands_account_id`, `idx_grants_state_needs_verification`, `idx_account_deletions_deleted_at`, plus every primary key on a barely-touched table). On a 15 MB seed DB whose stats were reset ~16.5 h ago, **zero scans means "no representative workload has run," not "unused."** The planner also prefers sequential scans on tiny tables, so even exercised indexes can show 0.

The only index in the zero-scan list that is **also** structurally redundant is `idx_locations_account_id` — already covered in 3a. For the rest, **do not drop based on this data.** Pull `pg_stat_user_indexes.idx_scan` from production (read-only) after a real usage window, then reconsider. Partial indexes like `idx_grants_state_needs_verification` are cheap and clearly intentional (state-machine hot paths) — keep unless prod proves them dead.

### Finding 3c — FK index coverage is good

Of 26 single-column FKs in `public`, **10 have no leading-column index** — but all 10 are `auth.users` write-stamp / actor columns:

`created_by`, `updated_by` (×5 tables), `last_transitioned_by`, `actor_id`, `respondent_id`, `completed_by`, `billing_contact_updated_by`.

These are audit columns, never query predicates. The only cost of an uncovered FK is slower `DELETE`/`UPDATE` of the *referenced* row (an `auth.users` user) — rare, and the tables are small. **Leaving them unindexed is a reasonable choice.** All FK columns that sit on real lookup/cascade paths — `account_id`, `brand_id`, `location_id`, `grant_id`, `integration_type_id`, `field_id` — **are** covered.

One nuance: `locations.brand_id` (FK `locations_brand_id_fk`) is not *leading*-covered — both `locations` composites lead with `account_id`. Brand-scoped cascade deletes on `brand_id` alone won't use an index. Low impact at current scale; revisit only if brand deletion gets slow on prod.

### Finding 3d — No invalid indexes

No indexes with `indisvalid = false` (no failed `CREATE INDEX CONCURRENTLY` leftovers).

---

## 4. Bloat — none real

Several tables show eye-popping dead-tuple ratios (`internal_intake_responses` 2300%, `onboarding_responses` 633%, `integration_types` 269%). These are **artifacts of a tiny seeded DB**: with 1–13 live rows, a handful of seed re-runs / upserts leaves dead tuples that outnumber live ones by ratio while being trivial in absolute terms (max 35 dead tuples anywhere). Autovacuum has run on the larger tables and will clear these; the dead counts are well under any autovacuum threshold.

Index-to-table size ratios are normal (e.g. `account_integration_grants` 112 kB indexes / 160 kB total — expected for a table with 7 single/partial indexes on 6 rows). **No actionable bloat.** Real bloat assessment requires production data and the `pgstattuple` extension (not installed locally).

---

## 5. Security/hygiene bonus — SECURITY DEFINER search_path (EXCELLENT)

All **53** SECURITY DEFINER functions in `public` pin an explicit `search_path` (`public, pg_temp` or tighter, e.g. `is_admin` uses `public, auth, pg_temp`, `get_user_id_by_email` uses `auth`). **Zero** SECURITY DEFINER functions run with a mutable search_path — this closes the classic privilege-escalation vector and reflects the hardening in migration `20260531000000_harden_is_admin_search_path`. No action needed.

---

## Prioritized action list

1. **(Confirm intent, then low-risk)** Lock down `public.admins` and `public.onboarding_form_fields`: `REVOKE` the broad `anon`/`authenticated` DML grants so they match the `internal_intake_responses` defense-in-depth pattern. Closes a latent "one permissive policy from exposure" gap. *(Finding 2a)*
2. **(Safe cleanup)** Drop three prefix-redundant indexes — `idx_locations_account_id`, `idx_brand_responses_account_id`, `idx_brand_strategy_runs_account_id` — via `DROP INDEX CONCURRENTLY`. Structurally redundant regardless of traffic. *(Finding 3a)*
3. **(Verification, needs prod)** Run `supabase migration list --linked` to confirm production has all 43 migrations (local can't tell you this). *(Section 1)*
4. **(Verification, needs prod)** Re-pull `pg_stat_user_indexes` / `pg_stat_user_tables` from production read-only after a representative window before acting on any *usage*-based unused-index or bloat conclusion. *(Findings 3b, 4)*
5. **(Optional, low impact)** Consider an index on `locations.brand_id` only if brand-deletion cascades get slow at scale. *(Finding 3c)*

## Out of scope / explicitly not done

- The linked/remote **production** project was not queried (per constraints). Drift, real index usage, and real bloat all need a separate read-only prod pass by a human.
- No writes, DDL, or `VACUUM`/`ANALYZE` were executed. No repository files were modified.
- `pgstattuple` (exact bloat) is not installed locally; not installed (would be DDL).
