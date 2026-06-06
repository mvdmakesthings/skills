# Playbook — Cleanup (indexes, bloat, dead weight)

Measured, gated removal of database dead weight: unused/duplicate/invalid indexes, table and index bloat, orphaned objects. The discipline: **measure → risk-rank → propose → gate → execute concurrently → verify**. Nothing is dropped on a hunch, and nothing runs before the user has seen the SQL.

Query IDs reference `references/queries.md`.

## Steps

### 1. Discover (Step 0)

Run `references/discover.md`. Cleanup cares especially about D4 (target + blast radius — index drops on prod go through the gate or, better, through a migration) and D2 (a PIR or checklist may explain why a weird-looking object exists; an ADR may protect it).

### 2. Measure — never guess

Collect candidates with evidence:

- Unused indexes — Q-IDX-UNUSED. **Check `stats_reset` first** (Q-DB-OVERVIEW): `idx_scan = 0` since yesterday means nothing. You want a stats window long enough to include periodic workloads (a month-end job, a weekly report).
- Duplicate indexes — Q-IDX-DUPLICATE (exact dups are free wins; prefix-overlaps need judgment).
- Invalid indexes — Q-IDX-INVALID (failed concurrent builds: pure cost, zero benefit — always safe to drop, often worth rebuilding).
- Bloat — Q-DEAD-TUPLES for the estimate; if `pgstattuple` is installed (Q-EXTENSIONS), measure the worst offenders exactly (`pgstattuple_approx` for big tables — it's cheaper). Distinguish *dead tuples vacuum will reclaim* from *bloat that needs a rewrite* (VACUUM FULL / `pg_repack` / REINDEX).
- Old transactions pinning bloat — Q-LONG-RUNNING. If a 3-day-old idle transaction is blocking vacuum, the cleanup is killing *that* (gated), not adding maintenance.
- Orphaned objects: tables/sequences obviously abandoned (zero rows + zero activity + no code references — grep the repo before calling anything orphaned).

### 3. Risk-rank the candidates

For every candidate, ask what could go wrong if it's removed:

- An `idx_scan = 0` index may **back a UNIQUE or FK constraint** (`backs_constraint` in Q-IDX-UNUSED) — dropping it changes semantics, not just performance. Constraint-backed indexes leave this list entirely.
- It may serve a **rare-but-critical path**: quarterly close, the one admin search, a disaster-recovery query. Grep the codebase for the index's columns in WHERE/ORDER BY clauses before sentencing it.
- It may be used **only on a replica** (replica stats are separate). If replicas exist, check there too or say you couldn't.
- For bloat rewrites: VACUUM FULL takes an exclusive lock for the duration — on a hot table that's an outage. Prefer `pg_repack`/`REINDEX CONCURRENTLY` and say why.

Rank: safe (invalid indexes, exact duplicates) → probably-safe (unused, evidence strong, code-grep clean) → needs-owner-judgment (everything else).

### 4. Propose the plan — SQL shown, nothing run

Present a table: object · evidence (scans, size, age of stats window) · risk rank · proposed SQL · lock cost · expected reclaim. Use online variants by default: `DROP INDEX CONCURRENTLY`, `REINDEX CONCURRENTLY` — and note that CONCURRENTLY can't run inside a transaction block.

Two execution routes, by target:
- **Local/dev**: run directly after a light confirm.
- **Production/linked**: prefer emitting a **migration** (in the discovered convention) so drops ride the project's review + deploy path. Live execution on prod only with per-statement confirmation.

### 5. Gate

Confirm the route and the list. Honor partial approval — the user striking two items from the list is the system working, not friction.

### 6. Execute

Run approved statements one at a time, CONCURRENTLY where applicable, checking for errors between statements (a failed `DROP INDEX CONCURRENTLY` can leave an invalid index — re-check Q-IDX-INVALID after). For vacuum-debt items, trigger `VACUUM (ANALYZE)` on the named tables rather than waiting for autovacuum, when the user approves.

### 7. Verify — before/after

Re-measure what you touched: relation sizes (Q-RELATION-SIZES), dead tuples (Q-DEAD-TUPLES), and confirm no invalid indexes remain (Q-IDX-INVALID). Present a before/after table with actual reclaimed numbers. Then confirm nothing broke: constraints intact (the dropped index backed none), the project's test suite passes if one exists, app smoke if available.

### 8. End

Summary: what was removed/reclaimed (with numbers), what was deliberately left alone and why, and the "what I did not touch" line. If candidates were deferred for owner judgment, list them so they aren't lost.
