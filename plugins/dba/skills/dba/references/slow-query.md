# Playbook — Slow-query diagnosis & fix

One query, end to end: reproduce → capture the plan → diagnose the mechanism → propose the fix with its lock cost → validate on a safe target with before/after plans → deliver the fix as a migration. The deliverable is a *verified* plan change, not a plausible index.

Query IDs reference `references/queries.md`.

## Steps

### 1. Discover (Step 0)

Run `references/discover.md`. You need the access method, the target (EXPLAIN ANALYZE on prod SELECTs is usually acceptable; anything else needs the local stack), and the schema context (existing indexes, table sizes).

### 2. Identify the query

If the user supplied it, use it verbatim — including the real parameter *values* if you can get them (plans can differ wildly by parameter; a query that's fast for most tenants and slow for the biggest one is a parameter-distribution problem, not a missing index). If the user said "the app is slow" instead, find the offender via Q-TOP-TOTAL-TIME / Q-TOP-MEAN-TIME and confirm with them which one you're chasing.

### 3. Establish the baseline plan — EXPLAIN first

- Plain `EXPLAIN` first. It's free and never executes.
- Then `EXPLAIN (ANALYZE, BUFFERS)` for the real numbers — **SELECTs only, directly**. For INSERT/UPDATE/DELETE, only inside `BEGIN; ... ROLLBACK;`, and say so (safety model rule 4).
- Capture the full plan text — it's your "before" artifact. Record the sequence in the deliverable too (plain EXPLAIN shown first, then the ANALYZE numbers): the safety discipline should be *visible* in the diagnosis, not just followed — it's what lets a reviewer trust that nothing executed before its cost was known.

### 4. Look at what's there before designing what's missing

Inspect the table's existing indexes (`\d table` or `pg_indexes`) and stats freshness (`last_analyze` in Q-DEAD-TUPLES) **before** proposing anything. The four cheapest outcomes, in order of cheapness:

1. **Stale statistics** — bad row estimates (plan says 1 row, ANALYZE says 50,000) with an old `last_analyze`: run `ANALYZE table` and re-plan before anything else.
2. **An existing index isn't being used** — predicate wraps the column in a function (`lower(email)`, `date(created_at)`), type mismatch forcing a cast, or leading-column mismatch on a composite. Fix the query or add the matching expression index.
3. **The query asks for too much** — `SELECT *` defeating index-only scans, missing LIMIT, OFFSET-pagination deep into a table. Rewrite beats index.
4. **The index is genuinely missing** — only now design one.

### 5. Diagnose the mechanism

Read the ANALYZE plan for the dominant cost and name the mechanism explicitly:

- Seq scan on a large table where rows-returned is small → missing/unusable index
- Estimate vs. actual rows off by orders of magnitude → stats or correlated columns (consider extended statistics)
- Sort/Hash spilling (`BUFFERS` shows temp reads/writes; cross-check Q-TEMP-SPILL) → work_mem or an index providing the order
- Nested-loop with a huge inner count → join order/estimate problem
- Many round trips of a fast query (high calls × low mean in Q-TOP-TOTAL-TIME) → it's an N+1; the fix is in the app's data access, not the plan

For interpretation depth and index-selection rules, defer to the best-practices skill and cite the specific rule (e.g. its EXPLAIN and missing-index rules) rather than restating.

### 6. Propose the fix — with its cost

Show the exact SQL. For an index: name the lock impact and default to `CREATE INDEX CONCURRENTLY` (no write blocking; can't run in a transaction; on failure leaves an invalid index to clean up). Also state the *write tax* — every index slows every write to that table; an index serving one rare query may not earn its keep. For a rewrite: show before/after SQL side by side.

### 7. Validate on a safe target

Apply the fix on the local stack (or a branch database), re-run `EXPLAIN (ANALYZE, BUFFERS)`, and confirm the **plan actually changed for the right reason** — the new index is used, estimates are sane, buffers/time dropped. Present before/after plans side by side with the headline numbers. A fix whose plan didn't change is a hypothesis that failed — go back to step 5, don't ship it.

If the local data volume is too small to trigger the production plan shape (planner may prefer seq scan on tiny tables), say so explicitly: validate what you can (index is used when forced / plan shape with `enable_seqscan` toggled diagnostically), and label the residual uncertainty instead of overclaiming.

### 8. End — deliver as a migration

Write the fix as a migration in the discovered convention (plus a test if the project tests schema), report the measured improvement, and point at the project's deploy path. Close with "what I did not touch": *nothing was applied beyond the local stack; production plan should be re-checked after deploy* (plans depend on prod stats).
