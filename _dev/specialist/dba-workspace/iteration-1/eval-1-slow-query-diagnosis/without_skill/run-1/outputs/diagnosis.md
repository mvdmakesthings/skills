# Slow query diagnosis: `brand_responses` lookup

**Query under investigation**

```sql
SELECT * FROM brand_responses WHERE brand_id = $1 AND question_key = $2;
```

**Environment:** local Supabase stack only (`postgresql://postgres:postgres@127.0.0.1:54322/postgres`). Read-only EXPLAIN/EXPLAIN ANALYZE; no indexes created, no rows or schema modified. Production was not touched.

---

## TL;DR

The slowness is **not** a missing index. The exact predicate `(brand_id, question_key)` is already backed by the unique constraint `brand_responses_brand_question_unique (brand_id, question_key)`, and every variant of the query (this one, the app's `brand_id`-only read, and the admin `account_id`-only read) uses an index in the plan.

The real cause is the **Row-Level Security policy** on the table:

```sql
USING ((account_id = ANY (current_user_account_ids())) OR is_admin())
```

`is_admin()` is declared **VOLATILE** (its `provolatile` is `'v'`). A volatile function in an RLS filter **cannot be hoisted** by the planner, so Postgres re-executes it **once per row scanned**. Each call runs `select exists(select 1 from public.admins where user_id = auth.uid())` — a fresh lookup against the `admins` table. On the tiny local table this is invisible, but the cost grows **linearly with the number of rows the scan touches**, which is exactly what produces "slow in our app" as real brands/accounts accumulate answers.

Measured on a 10,000-row scan: **~63–71 ms** with the volatile function vs **~1 ms** when the same logic is marked STABLE — a ~65x difference, and ~10,200 extra shared-buffer hits (one `admins` probe per row).

**Fix:** mark `is_admin()` `STABLE`. One word. The planner then evaluates it once per statement (a `One-Time Filter`). `current_user_account_ids()` is already correctly STABLE, so no change is needed there.

---

## Investigation trail

### 1. The index exists and matches the predicate

`\d brand_responses` on the live local DB:

```
Indexes:
    "brand_responses_pkey" PRIMARY KEY, btree (id)
    "brand_responses_brand_question_unique" UNIQUE CONSTRAINT, btree (brand_id, question_key)
    "idx_brand_responses_account_id" btree (account_id)
    "idx_brand_responses_brand_id" btree (account_id, brand_id)
```

The unique constraint backs the exact `(brand_id, question_key)` predicate. No index is missing for this query.

### 2. The literal query is fast and uses the index — even under RLS

Run as the `authenticated` role with a real account member's JWT `sub` set (i.e. the way PostgREST executes it), RLS active:

```
Index Scan using brand_responses_brand_question_unique on public.brand_responses
   Index Cond: ((brand_id = '…'::uuid) AND (question_key = '…'::text))
   Filter: ((account_id = ANY (current_user_account_ids())) OR is_admin())
 Execution Time: 0.334 ms
```

A single qualifying row, so the per-row RLS filter fires once — cheap here. This is what hides the problem at small scale.

### 3. The app's actual read paths

The literal `(brand_id, question_key)` query in the task matches only the stale-write fallback in
`app/portal/[accountSlug]/brand-strategy/[brandSlug]/_actions.ts` (the `.eq("brand_id").eq("question_key")` re-read).

The genuinely hot paths read **more rows** and so feel the per-row RLS cost harder:

- `app/portal/[accountSlug]/brand-strategy/[brandSlug]/page.tsx` and the `computeBrandCompletion` helper in `_actions.ts` both run
  `.from("brand_responses").select(...).eq("brand_id", brandId)` — every answer row for a brand, on **every page load and every autosave**.
- `app/(admin)/dashboard/accounts/[slug]/page.tsx` runs
  `.from("brand_responses").select("brand_id").eq("account_id", account.id)` — **every brand_responses row across an entire account**.

Each of these applies the RLS filter — and therefore `is_admin()` — to every scanned row.

### 4. Volatility of the RLS helper functions

```
         proname          | provolatile | prosecdef
--------------------------+-------------+-----------
 current_user_account_ids | s (STABLE)  | t
 is_admin                 | v (VOLATILE)| t   <-- root cause
```

`is_admin()` is VOLATILE. In a row filter the planner must call it per row. Defined in
`supabase/migrations/20260531000000_harden_is_admin_search_path.sql`:

```sql
create or replace function is_admin() returns boolean
  language sql
  security definer
  set search_path = public, auth, pg_temp
as $$
  select exists(select 1 from public.admins where user_id = auth.uid())
$$;
```

No `STABLE` keyword, so it defaults to VOLATILE. (`current_user_account_ids()` in the same RLS stack *is* declared STABLE — the inconsistency is the smoking gun.)

### 5. Empirical proof of per-row re-evaluation

A read-only scan of 10,000 synthetic rows (`generate_series`, touches no table data) applying the same VOLATILE `is_admin()`:

```
Function Scan on generate_series g
   Filter: is_admin()
 Buffers: shared hit=10220        <-- ~1 admins-table probe per row
 Execution Time: 63.311 ms
```

The full RLS predicate `(... = ANY(current_user_account_ids())) OR is_admin()` over the same 10k rows: **71.9 ms**, 10,202 buffers.

The same logic wrapped in a session-local **STABLE** function (`pg_temp`, auto-dropped, no app-schema DDL):

```
Result
   One-Time Filter: pg_temp.is_admin_stable()   <-- evaluated ONCE
 Buffers: shared hit=96
 Execution Time: 1.011 ms
```

VOLATILE 63–72 ms → STABLE ~1 ms over 10k rows. The planner collapses a STABLE function in the filter to a single `One-Time Filter` evaluation.

---

## Proposed fix (propose-only — not applied)

Mark `is_admin()` `STABLE`. It is a read-only `SELECT` whose result is constant within a single statement (`auth.uid()` and `admins` membership don't change mid-statement), so STABLE is correct — VOLATILE was simply an unintended default.

`create or replace` preserves existing EXECUTE grants and the search_path hardening from migration `20260531000000`, so this is a safe, in-place redefinition. The migration content is saved alongside this file as `fix_is_admin_stable.sql`.

```sql
create or replace function is_admin() returns boolean
  language sql
  stable                                   -- the fix
  security definer
  set search_path = public, auth, pg_temp  -- unchanged: pg_temp pinned LAST
as $$
  select exists(select 1 from public.admins where user_id = auth.uid())
$$;
```

### Why this is the right fix (and not a new index)

- The `(brand_id, question_key)` index already exists and is already used; adding an index changes nothing.
- The cost scales with **rows scanned**, not with the lookup — that is the signature of a per-row filter function, not a missing index.
- STABLE is the standard, Supabase-recommended posture for RLS helper functions precisely so the planner can evaluate them once per statement.

### Secondary observation (not the root cause, worth noting)

The local `brand_responses` table has **never been ANALYZEd**: `pg_class.reltuples = -1`, `relpages = 0`, all `pg_stat_user_tables` analyze/vacuum timestamps NULL, and 16 dead tuples against 6 live rows. On the local stack the planner still picks the index, so this is not causing the reported slowness, but on production stale/absent statistics can push the planner toward worse plans on larger tables. Worth a `VACUUM ANALYZE brand_responses` and a check that autovacuum is running — but this is hygiene, separate from the STABLE fix.

### Verification plan after applying

1. Re-check volatility: `select provolatile from pg_proc where proname = 'is_admin';` should return `s`.
2. Re-run EXPLAIN (ANALYZE) on the `account_id`-scoped admin read against a seeded/large dataset; the per-row `Filter` cost on the `admins` lookups should disappear (the function is evaluated once).
3. Confirm no behavior change: admin still sees all rows, non-member still sees none (the predicate is logically identical; only evaluation frequency changes).

---

## Confirmation I would have asked for (no human available)

- **"Can I apply the `is_admin()` STABLE fix as a migration in the charter repo?"** — Assumed **no** per the run constraints (propose-only, do not modify the repo). I saved the migration content as a standalone `.sql` file in the outputs directory instead.
- **"Is the production table large enough that this is the active pain?"** — Assumed yes (the report says it is slow "in our app"); I could only confirm the mechanism on the local stack, where data volume is too small to reproduce wall-clock slowness directly, so I demonstrated the per-row cost with a synthetic 10k-row scan.
