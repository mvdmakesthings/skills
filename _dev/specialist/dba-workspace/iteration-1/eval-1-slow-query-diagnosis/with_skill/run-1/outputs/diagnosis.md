# Slow-query diagnosis — `brand_responses` by `(brand_id, question_key)`

**Query under investigation**

```sql
SELECT * FROM brand_responses WHERE brand_id = $1 AND question_key = $2;
```

**Verdict (headline):** This query is **not slow at the database level** and **does not need a new index.** It already has an exact-match composite index (`brand_responses_brand_question_unique` on `(brand_id, question_key)`), and on the live local schema it runs as a single-row **Index Scan in ~0.15 ms warm**. The "add an index" reflex is the wrong fix here — the index exists. If the app *feels* slow on the Brand Strategy fill/save path, the cost is almost certainly somewhere this query isn't: per-keystroke autosave round-trips (an N+1-shaped pattern in the application), cold-plan/catalog overhead on a fresh connection, or network/round-trip latency to Supabase — not the index access path.

This was a READ-ONLY investigation against the **local** Supabase stack only (`postgresql://postgres:postgres@127.0.0.1:54322`). Nothing was executed against the linked/production project. No DDL, no test indexes were created — proposals below are not applied.

---

## How the query is actually used

The exact predicate appears in the Brand Strategy save action as the **stale-write resync read** (`app/portal/[accountSlug]/brand-strategy/[brandSlug]/_actions.ts:79–84`):

```ts
await supabase.from("brand_responses").select("client_seq")
  .eq("brand_id", brandId).eq("question_key", questionKey).maybeSingle();
```

It is issued through PostgREST as the `authenticated` role, so **RLS is in effect** — the policy `brand_responses_read` (`using (account_id = any(current_user_account_ids()) or is_admin())`) is injected into the plan.

Two *adjacent* hot reads on the same table use a `brand_id`-only predicate (whole-brand answer hydration / completion recompute):
- `page.tsx:68–71` — `select(question_key, answer, client_seq).eq("brand_id", …)`
- `_actions.ts:132–135` — `select(question_key, answer).eq("brand_id", …)` — fired on **every** save via `computeBrandCompletion`.

These also indexed cleanly (see below).

## Schema facts (live local catalog)

`brand_responses` indexes:

| Index | Definition | Role | idx_scan (local) |
|---|---|---|---|
| `brand_responses_brand_question_unique` | UNIQUE `(brand_id, question_key)` | serves the query verbatim **and** `brand_id`-only reads (leading col) | **191** |
| `idx_brand_responses_brand_id` | `(account_id, brand_id)` | FK reverse-lookup; leading col is `account_id` | 9 |
| `idx_brand_responses_account_id` | `(account_id)` | RLS account filter | 0 |
| `brand_responses_pkey` | `(id)` | PK | 0 |

Table is tiny on local: **6 live rows, 16 dead, 80 kB, never ANALYZEd** (`reltuples = -1`). RLS helpers: `current_user_account_ids()` is `STABLE SECURITY DEFINER`; `is_admin()` is `VOLATILE SECURITY DEFINER`.

## Plans captured (local stack, `EXPLAIN (ANALYZE, BUFFERS)`)

**A. Bare query, superuser (RLS bypassed):**
```
Index Scan using brand_responses_brand_question_unique on brand_responses
  (cost=0.15..8.17 rows=1) (actual time=0.185..0.186 rows=1 loops=1)
  Index Cond: ((brand_id = $1) AND (question_key = $2))
  Buffers: shared hit=2
Execution Time: 0.290 ms
```

**B. Same query as `authenticated` (RLS active) — what the app hits:**
```
Index Scan using brand_responses_brand_question_unique on brand_responses
  (cost=0.15..8.68 rows=1) (actual time=0.312..0.313 rows=1 loops=1)
  Index Cond: ((brand_id = $1) AND (question_key = $2))
  Filter: ((account_id = ANY (current_user_account_ids())) OR is_admin())
  Buffers: shared hit=3
Execution Time: 0.361 ms
```
The RLS policy lands as a `Filter` *on top of* the index scan. Because the index narrows to ≤1 row first, the filter (including the VOLATILE `is_admin()` subquery) runs at most once — negligible here.

**C. Cold vs. warm planning (same query, two runs in one session):**
```
run 1 (cold): Planning Time: 8.934 ms   Execution Time: 1.204 ms
run 2 (warm): Planning Time: 0.298 ms   Execution Time: 0.147 ms
```
**Planning dominates execution, and only when cold.** The cold cost is catalog/plan construction (many policies + SECURITY DEFINER function resolution + four indexes to consider), not data access. It evaporates on the warm run.

## Root-cause analysis — what's actually going on

Per the slow-query playbook's "look at what's there before designing what's missing" ladder, and `supabase-postgres-best-practices` (`query-indexes` / index-selection rules):

1. **Stale statistics?** The local table was never ANALYZEd (`reltuples = -1`). On 6 rows the planner can't be triggered into a prod-shape plan regardless. Not the cause of any real slowness, but worth an `ANALYZE` hygiene note. **Residual uncertainty:** local volume is far too small to reproduce a production plan — at scale Postgres could in principle pick a different shape, though with a unique exact-match predicate that is extremely unlikely.
2. **Existing index unusable?** No — the predicate matches the unique index's exact column order; it's used directly (plans A & B). No function-wrapping, no type cast (uuid = uuid, text = text).
3. **Query asks for too much?** `SELECT *` here returns one row by a unique key, so width is irrelevant. (For the *whole-brand* reads in `page.tsx`/`computeBrandCompletion`, `SELECT *` would matter at scale, but those already trim columns.)
4. **Genuinely missing index?** No.

So the database is exonerated for this statement. The plausible real causes of perceived app slowness, in order:

- **Most likely — application round-trip amplification (N+1-shaped).** Each autosave does an `upsert_brand_response` RPC *and then* `computeBrandCompletion`, which re-reads the brand's whole answer set (`_actions.ts:132`); the page load does its own whole-brand read (`page.tsx:68`). Rapid typing → many save calls → many sequential Supabase round-trips. Each call is ~1 ms in Postgres but carries full network + auth + PostgREST overhead. The fix is in the data-access pattern (debounce/batch saves, or have `upsert_brand_response` return the recomputed completion in one round-trip), **not** the plan. Cite: best-practices data-access / round-trip guidance.
- **Cold-connection planning overhead** (plan C). Mitigated in production by PgBouncer + PostgREST prepared-statement plan caching; shows up only on the first hit of a fresh backend.
- **Network/region latency** between the app and Supabase — outside the query.

## Proposed fix

**Primary recommendation: do NOT add an index for this query.** The matching unique index already exists and is used. Adding another `(brand_id, question_key)` index would be pure write tax (every insert/update to the table maintains it) for zero read benefit.

If the goal is to reduce the *app's* latency on the Brand Strategy save path, the highest-leverage change is to **collapse the save round-trips** — e.g. extend `upsert_brand_response` to return the recomputed section/gate completion so the action doesn't need the follow-up whole-brand read, and debounce client autosave. That is an application + RPC change, outside the scope of "this SELECT," and should go through the normal coding flow.

**Optional schema hygiene (low priority, separate from this query):**
- `idx_brand_responses_brand_id (account_id, brand_id)` is largely redundant for reads: the unique index already serves `brand_id`-only and `(brand_id, question_key)` lookups, and the account-scoped RLS read is covered by `idx_brand_responses_account_id`. Its one defensible purpose is backing the composite FK `(account_id, brand_id) → brands`. **Recommendation: leave it for now** (FK support + cheap on a small table); flag for a future cleanup/audit pass rather than dropping blind. A drop would be `DROP INDEX CONCURRENTLY` (ShareUpdateExclusiveLock, no write blocking) — propose, do not apply.
- Run `ANALYZE brand_responses` so the planner has real stats once the table grows (it has never been analyzed). Plain `ANALYZE` takes only a brief lock and is safe, but it is still a write-side maintenance op — propose, not applied here.

I am providing `proposed_analyze.sql` as the single, safe, optional statement. **No index migration is proposed**, because the correct conclusion is that no index is missing. (Per the run constraints I did not create any test index on the local stack, and I did not add anything to the charter repo.)

## Validation note

Because the local table holds 6 rows, I could not reproduce a production-scale plan shape, and I say so explicitly rather than overclaiming. What I *did* validate: (a) the unique index is the chosen access path both with and without RLS (plans A & B); (b) the RLS filter is a post-index single-row filter, not a scan driver; (c) the only multi-ms number anywhere is cold *planning*, which disappears warm (plan C); (d) index-usage counters show the unique index doing 191 of the 200 scans. After any production change, the prod plan should be re-checked since plans depend on prod statistics.

## What I did not touch

- No writes, DDL, or test indexes were executed against any database (read-only EXPLAIN/catalog queries only, local stack only).
- The linked/production project was never queried.
- No files in the charter repository were modified; the proposed `.sql` lives only in this outputs directory.
