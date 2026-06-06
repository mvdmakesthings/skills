# Playbook — Database health audit

A read-only, end-to-end sweep of schema integrity, index health, query load, maintenance state, and operational drift, ending in a severity-ranked findings report. The audit executes **no writes** — fixes are proposed as SQL but never run; offer to spin them into the cleanup or slow-query workflows afterwards.

Query IDs reference `references/queries.md`.

## Steps

### 1. Discover (Step 0)

Run the full discovery protocol (`references/discover.md`). The audit needs all of it: conventions to audit *against*, an access method, and a confirmed read-only target. If the only reachable target is production/linked, that's fine — every audit query is catalog/statistics-only — but say so in the D5 summary.

### 2. Platform advisors (fast first pass, when available)

If a Supabase MCP is connected, pull `get_advisors` (security **and** performance lints) and fold the results into your findings rather than re-deriving them. Platform advisors know platform-specific hazards (exposed schemas, missing RLS on exposed tables) that generic catalog queries miss. Don't stop here — advisors don't cover load, bloat, or drift.

### 3. Schema & integrity sweep

- Tables without primary keys — Q-TBL-NO-PK
- Foreign keys without covering indexes — Q-FK-NO-INDEX
- RLS coverage — Q-RLS-STATUS. Judge against the *project's* model discovered in D2: in a multi-tenant app, an RLS-disabled table holding tenant data is Critical; in a single-tenant internal tool it may be Low.
- Write-path integrity — Q-TABLE-GRANTS. If the project's convention is "writes only via RPC/service layer" (common on PostgREST/Supabase stacks), direct write grants to client roles on sensitive tables are findings.
- While you're in the schema: columns that are obviously untyped (`text` for timestamps/enums with a CHECK nowhere in sight), missing `NOT NULL` on semantically-required columns. Sample a few central tables rather than boiling the ocean; depth belongs to design reviews.

### 4. Index health

- Unused indexes — Q-IDX-UNUSED (respect its caveats: stats age, constraint-backing, rare-critical paths)
- Exact duplicates — Q-IDX-DUPLICATE
- Invalid indexes — Q-IDX-INVALID (these are free wins: pure overhead, no benefit)
- Seq-scan-heavy large tables — Q-SEQSCAN-HEAVY, cross-referenced with step 5's top queries to find the actual missing index

For *which* index to recommend, defer to the best-practices skill (index-selection rules) and cite it.

### 5. Query & load health

Requires `pg_stat_statements` (Q-EXTENSIONS; if absent, note it as a finding in itself — flying blind on query load is an operational gap).

- Top by total time and by mean time — Q-TOP-TOTAL-TIME, Q-TOP-MEAN-TIME
- Cache hit ratio — Q-CACHE-HIT (overall and per-hot-table)
- **Rollback ratio — Q-ROLLBACK-RATIO.** Always include this even when nothing looks wrong: it's cheap, and a quietly climbing rollback count is the classic signature of a failure mode that `pg_stat_statements` cannot see.
- Temp spills — Q-TEMP-SPILL

### 6. Bloat & maintenance

- Dead tuples + vacuum recency — Q-DEAD-TUPLES
- Relation sizes — Q-RELATION-SIZES (index footprint vs table footprint)
- Old transactions that block vacuum — Q-LONG-RUNNING
- Sequence headroom — Q-SEQ-EXHAUSTION

### 7. Drift & operational posture

Using what D1/D4 discovered:

- **Migration drift**: compare repo migrations against what's applied to the remote (e.g. `supabase migration list --linked`, `schema_migrations` table, or the project's equivalent). Unapplied migrations sitting in the repo — or remote objects with no migration — are findings, not trivia: when schema deploys are manual, drift is how outages incubate.
- **Deploy-model risk**: if D4 found that code deploys don't carry schema (manual push step), state it in the report with the project's own mitigation (their checklist) cited.
- Past-incident follow-ups: if D2's PIRs list open action items relevant to the database, check whether they happened.

### 8. Score and write the report

Use the shared findings format from SKILL.md:

```markdown
| # | Area | Severity | Evidence | Recommendation | Fix (SQL — not executed) |
```

- Every finding carries **evidence** — the actual numbers/names a catalog query returned. No evidence, no finding.
- Severity per the shared scale. Be honest about Lows; an audit that ranks everything High teaches the reader to ignore it.
- Where a fix is rule-shaped (which index, which type), cite the best-practices rule rather than re-arguing it.
- Lead the report with a 3–5 line executive summary: overall posture, the one or two things that actually matter, and what you did NOT examine (e.g. "no pgstattuple — bloat figures are estimates"; "replica health not in scope").

### 9. End

Present the report. Offer — explicitly, as a question — to take Critical/High findings into the appropriate follow-up workflow (cleanup for index/bloat items, slow-query for load items, design & implement for schema changes). Close with the "what I did not touch" line: *no writes were executed; all fixes above are proposals.*
