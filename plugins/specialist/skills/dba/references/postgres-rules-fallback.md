# Postgres rules — condensed fallback

**Use this file only when the `supabase-postgres-best-practices` skill is not available in the session.** When it is available, defer to it and cite its rules — it covers all of this in proper depth, and two sources of truth drift. This page exists so the playbooks don't go ruleless in environments without that skill; it is intentionally thin.

## Indexing

- Index what the query proves it needs: columns in WHERE/JOIN/ORDER BY with selectivity. B-tree is the default; GIN for jsonb/array/full-text; partial indexes when queries always filter the same predicate (`WHERE deleted_at IS NULL`).
- Composite index column order: equality columns first, then range; the leading column must appear in the query's predicate for the index to be considered.
- Every index taxes every write to the table. Indexes need to earn their keep.
- Build/drop online: `CREATE INDEX CONCURRENTLY` / `DROP INDEX CONCURRENTLY` (no transaction block; failure leaves an invalid index to clean up).

## Schema

- `bigint` (or UUID where distribution demands) for keys — `int4` sequences exhaust. `timestamptz` over `timestamp`. `text` + CHECK over `varchar(n)`. `numeric` for money.
- Encode invariants as constraints: NOT NULL, FK, UNIQUE, CHECK. Constraints are the last line of defense and the cheapest documentation.
- Add big-table constraints online: `ADD CONSTRAINT ... NOT VALID` then `VALIDATE CONSTRAINT` (validation takes a weaker lock).
- Index every FK's child columns — parent-side deletes seq-scan the child otherwise.

## Queries

- `EXPLAIN (ANALYZE, BUFFERS)` and read actual-vs-estimated rows; order-of-magnitude misses mean stale stats (`ANALYZE`) or correlated columns (extended statistics).
- Functions/casts on a predicate column defeat plain indexes — use expression indexes or move the function to the literal side.
- Keyset pagination over OFFSET for deep pages. Avoid `SELECT *` where an index-only scan could serve.
- N+1: batch with `= ANY($1)` or joins; the fix lives in the application's data access.

## Connections & locking

- Keep transactions short; `idle in transaction` holds locks and blocks vacuum.
- Pool connections (PgBouncer/Supavisor); Postgres connections are expensive processes, not threads.
- Take locks in a consistent order to avoid deadlocks; use `SELECT ... FOR UPDATE SKIP LOCKED` for job queues; advisory locks for application-level serialization (key by a stable formula so they're auditable).
- DDL lock costs: plain `CREATE INDEX` blocks writes; `ALTER TABLE` variants range from metadata-only (adding a nullable column, or with a constant default on PG11+) to full rewrite (type changes) — know which one you're proposing.

## Maintenance & monitoring

- Autovacuum must keep up: watch `n_dead_tup` and `last_autovacuum`; long transactions silently pin vacuum's horizon.
- `pg_stat_statements` for query load — but it only records *successful* executions; failures live in logs and `xact_rollback`.
- Bloat that vacuum can't reclaim needs `REINDEX CONCURRENTLY` / `pg_repack`; `VACUUM FULL` takes an access-exclusive lock (outage on hot tables).

## Error semantics

- SQLSTATE choices are API contracts: class-40 (`40001`, `40P01`) means "transient, retry me" to drivers, poolers, and PostgREST. Deterministic rejections (validation, stale-write guards) must use custom codes (the `P0xxx` space) or retry-aware layers will loop forever.
