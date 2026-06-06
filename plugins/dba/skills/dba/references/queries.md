# Diagnostic query library

Read-only diagnostic SQL, keyed by ID. Playbooks cite these IDs instead of re-pasting SQL. All queries are safe to run on production — they read catalogs and statistics views only. Column names target Postgres 13+ (`total_exec_time` etc.; on older versions some `pg_stat_statements` columns drop the `_exec` infix).

Substitute schema filters as needed — the examples filter to `public`; multi-schema projects should widen this.

## Contents

- [Load & throughput](#load--throughput): Q-DB-OVERVIEW, Q-ROLLBACK-RATIO, Q-CACHE-HIT, Q-TOP-TOTAL-TIME, Q-TOP-MEAN-TIME, Q-TEMP-SPILL
- [Schema integrity](#schema-integrity): Q-TBL-NO-PK, Q-FK-NO-INDEX, Q-RLS-STATUS, Q-TABLE-GRANTS
- [Index health](#index-health): Q-IDX-UNUSED, Q-IDX-DUPLICATE, Q-IDX-INVALID, Q-SEQSCAN-HEAVY
- [Bloat & maintenance](#bloat--maintenance): Q-DEAD-TUPLES, Q-RELATION-SIZES, Q-AUTOVAC-RUNNING, Q-SEQ-EXHAUSTION
- [Live activity & locks](#live-activity--locks): Q-ACTIVITY-NOW, Q-LONG-RUNNING, Q-BLOCKING-CHAINS, Q-ADVISORY-LOCKS, Q-CONN-SUMMARY, Q-WAIT-EVENTS
- [Meta](#meta): Q-EXTENSIONS

---

## Load & throughput

### Q-DB-OVERVIEW — database-level vital signs

```sql
select datname,
       xact_commit, xact_rollback,
       round(100.0 * xact_rollback / nullif(xact_commit + xact_rollback, 0), 2) as rollback_pct,
       blks_hit, blks_read,
       round(100.0 * blks_hit / nullif(blks_hit + blks_read, 0), 2) as cache_hit_pct,
       deadlocks, temp_files, pg_size_pretty(temp_bytes) as temp_bytes,
       stats_reset
from pg_stat_database
where datname = current_database();
```

Counters are cumulative since `stats_reset` — for "what's happening *now*", sample twice with a pause and diff.

### Q-ROLLBACK-RATIO — the failed-vs-slow discriminator

```sql
select xact_commit, xact_rollback,
       round(100.0 * xact_rollback / nullif(xact_commit + xact_rollback, 0), 2) as rollback_pct
from pg_stat_database where datname = current_database();
```

Healthy OLTP is typically well under 1–2% rollbacks. A high or *climbing* ratio means the load is **failures** — which never appear in `pg_stat_statements` (it records successful executions only). Hunt failures in logs and `pg_stat_activity`, not in the statements view. To see it climb live: run twice ~30s apart and diff `xact_rollback`.

### Q-CACHE-HIT — buffer cache effectiveness

```sql
select relname,
       heap_blks_read, heap_blks_hit,
       round(100.0 * heap_blks_hit / nullif(heap_blks_hit + heap_blks_read, 0), 2) as hit_pct
from pg_statio_user_tables
order by heap_blks_read desc limit 20;
```

Overall hit % is in Q-DB-OVERVIEW. Sustained <99% on a hot OLTP table suggests the working set exceeds shared_buffers or a query is scanning more than it should.

### Q-TOP-TOTAL-TIME — where the database spends its life

Requires `pg_stat_statements` (check Q-EXTENSIONS).

```sql
select round(total_exec_time::numeric, 1) as total_ms, calls,
       round(mean_exec_time::numeric, 2) as mean_ms,
       rows, left(query, 120) as query
from pg_stat_statements
order by total_exec_time desc limit 15;
```

High total + low mean = high-frequency query (optimize or cache); high total + high mean = expensive query (plan work).

### Q-TOP-MEAN-TIME — slowest individual statements

```sql
select round(mean_exec_time::numeric, 1) as mean_ms, calls,
       round(total_exec_time::numeric, 1) as total_ms,
       left(query, 120) as query
from pg_stat_statements
where calls > 5
order by mean_exec_time desc limit 15;
```

The `calls > 5` filter drops one-off migrations/admin statements that would otherwise dominate.

### Q-TEMP-SPILL — sorts/hashes spilling to disk

```sql
select left(query, 100) as query, calls,
       temp_blks_read, temp_blks_written
from pg_stat_statements
where temp_blks_written > 0
order by temp_blks_written desc limit 10;
```

Spills mean `work_mem` is too small for the operation or the query sorts/hashes far more rows than it should.

---

## Schema integrity

### Q-TBL-NO-PK — tables without a primary key

```sql
select n.nspname as schema, c.relname as table
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and n.nspname not in ('pg_catalog', 'information_schema')
  and not exists (select 1 from pg_constraint x
                  where x.conrelid = c.oid and x.contype = 'p')
order by 1, 2;
```

No PK means no identity, broken logical replication, and painful dedup later.

### Q-FK-NO-INDEX — foreign keys without a covering index

```sql
select c.conrelid::regclass as table, c.conname,
       string_agg(a.attname, ', ' order by x.n) as fk_columns
from pg_constraint c
cross join lateral unnest(c.conkey) with ordinality as x(attnum, n)
join pg_attribute a on a.attrelid = c.conrelid and a.attnum = x.attnum
where c.contype = 'f'
  and not exists (
    select 1 from pg_index i
    where i.indrelid = c.conrelid
      and (i.indkey::int2[])[0:cardinality(c.conkey)-1]
          operator(pg_catalog.@>) c.conkey
  )
group by c.conrelid, c.conname
order by 1;
```

Unindexed FKs make parent-side DELETE/UPDATE seq-scan the child table — under load this shows up as mystery lock waits.

### Q-RLS-STATUS — row-level security coverage

```sql
select c.relname as table,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as rls_forced,
       count(p.polname) as policy_count
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_policy p on p.polrelid = c.oid
where c.relkind = 'r' and n.nspname = 'public'
group by 1, 2, 3
order by rls_enabled, c.relname;
```

Flag: RLS disabled on tables holding tenant/user data; RLS *enabled but zero policies* (locks everyone out — or worse, the table is accessed only via SECURITY DEFINER and nobody noticed); policies present but trivially-true.

### Q-TABLE-GRANTS — who can write what

```sql
select table_name, grantee, string_agg(privilege_type, ', ') as privileges
from information_schema.table_privileges
where table_schema = 'public'
  and grantee not in ('postgres')
group by 1, 2
order by 1, 2;
```

On PostgREST/Supabase-style stacks, look hard at `anon` and `authenticated`: direct INSERT/UPDATE/DELETE grants on sensitive tables usually mean the single-write-path convention (writes only via RPC) is broken for that table.

---

## Index health

### Q-IDX-UNUSED — indexes with zero scans

```sql
select s.schemaname, s.relname as table, s.indexrelname as index,
       s.idx_scan,
       pg_size_pretty(pg_relation_size(s.indexrelid)) as size,
       i.indisunique, i.indisprimary,
       exists (select 1 from pg_constraint c where c.conindid = s.indexrelid) as backs_constraint
from pg_stat_user_indexes s
join pg_index i on i.indexrelid = s.indexrelid
where s.idx_scan = 0
order by pg_relation_size(s.indexrelid) desc;
```

`idx_scan = 0` is a *candidate*, not a verdict: the counter resets with stats (check `stats_reset` in Q-DB-OVERVIEW), the index may back a UNIQUE/FK constraint (`backs_constraint`), serve a rare-but-critical path (month-end job), or matter only on a replica. The cleanup playbook owns the risk-ranking.

### Q-IDX-DUPLICATE — same column prefix, twice

```sql
select a.indrelid::regclass as table,
       a.indexrelid::regclass as index_a,
       b.indexrelid::regclass as index_b,
       pg_size_pretty(pg_relation_size(a.indexrelid)) as size_a
from pg_index a
join pg_index b on a.indrelid = b.indrelid
  and a.indexrelid > b.indexrelid
  and a.indkey::text = b.indkey::text
  and a.indpred is not distinct from b.indpred
  and a.indexprs is not distinct from b.indexprs;
```

Exact duplicates are pure waste. Near-duplicates (one index a prefix of another) need eyes — the wider one may make the narrower redundant.

### Q-IDX-INVALID — failed concurrent builds

```sql
select indexrelid::regclass as index, indrelid::regclass as table
from pg_index where not indisvalid;
```

Invalid indexes (usually a failed `CREATE INDEX CONCURRENTLY`) consume space and write overhead but serve no queries. Drop and rebuild.

### Q-SEQSCAN-HEAVY — big tables being sequentially scanned

```sql
select relname, seq_scan, seq_tup_read, idx_scan,
       n_live_tup,
       pg_size_pretty(pg_total_relation_size(relid)) as total_size
from pg_stat_user_tables
where seq_scan > 0 and n_live_tup > 10000
order by seq_tup_read desc limit 15;
```

High `seq_scan` on large tables = candidate missing index; cross-check against the top queries (Q-TOP-TOTAL-TIME).

---

## Bloat & maintenance

### Q-DEAD-TUPLES — dead rows and vacuum recency

```sql
select relname, n_live_tup, n_dead_tup,
       round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 1) as dead_pct,
       last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
from pg_stat_user_tables
where n_dead_tup > 1000
order by n_dead_tup desc limit 20;
```

Sustained dead_pct > ~20% with stale `last_autovacuum` means autovacuum can't keep up (or is blocked by long transactions — check Q-LONG-RUNNING). For *exact* bloat, use `pgstattuple` if installed; this view is the estimate.

### Q-RELATION-SIZES — what's big

```sql
select c.oid::regclass as relation,
       pg_size_pretty(pg_table_size(c.oid)) as table_size,
       pg_size_pretty(pg_indexes_size(c.oid)) as index_size,
       pg_size_pretty(pg_total_relation_size(c.oid)) as total
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r' and n.nspname = 'public'
order by pg_total_relation_size(c.oid) desc limit 20;
```

An index footprint rivaling or exceeding its table is a smell worth itemizing (Q-IDX-UNUSED, Q-IDX-DUPLICATE).

### Q-AUTOVAC-RUNNING — vacuums in flight

```sql
select pid, datname, relid::regclass as table, phase,
       heap_blks_scanned, heap_blks_total
from pg_stat_progress_vacuum;
```

### Q-SEQ-EXHAUSTION — sequences approaching their max

```sql
select schemaname, sequencename, last_value, max_value,
       round(100.0 * last_value / max_value, 2) as pct_used
from pg_sequences
where last_value is not null
order by pct_used desc limit 10;
```

An `int4` PK sequence past ~50% deserves a migration plan now, not at 99%.

---

## Live activity & locks

### Q-ACTIVITY-NOW — what is running right now

```sql
select pid, usename, application_name, client_addr, state,
       wait_event_type, wait_event,
       now() - query_start as query_age,
       now() - xact_start as xact_age,
       left(query, 100) as query
from pg_stat_activity
where state <> 'idle' and pid <> pg_backend_pid()
order by query_start;
```

### Q-LONG-RUNNING — old transactions and idle-in-transaction

```sql
select pid, usename, state,
       now() - xact_start as xact_age,
       now() - state_change as state_age,
       left(query, 100) as query
from pg_stat_activity
where xact_start is not null
  and now() - xact_start > interval '5 minutes'
order by xact_start;
```

Old transactions block vacuum (bloat grows) and hold locks. `idle in transaction` for minutes is almost always an application bug (connection checked out, transaction never closed).

### Q-BLOCKING-CHAINS — who blocks whom

```sql
select blocked.pid as blocked_pid,
       blocked.usename as blocked_user,
       left(blocked.query, 80) as blocked_query,
       blocking.pid as blocking_pid,
       blocking.state as blocking_state,
       left(blocking.query, 80) as blocking_query
from pg_stat_activity blocked
join lateral unnest(pg_blocking_pids(blocked.pid)) as b(pid) on true
join pg_stat_activity blocking on blocking.pid = b.pid;
```

Walk the chain to its head: the root blocker is the one to understand (and possibly terminate — gated, see safety model).

### Q-ADVISORY-LOCKS — application-level locks held

```sql
select l.pid, l.locktype, l.classid, l.objid, l.granted,
       a.state, now() - a.xact_start as xact_age,
       left(a.query, 80) as query
from pg_locks l
join pg_stat_activity a on a.pid = l.pid
where l.locktype = 'advisory'
order by a.xact_start;
```

If the app derives advisory-lock keys from a known formula (e.g. `hashtext('entity:' || id)`), you can reverse a hot `objid` to the contended entity by computing `hashtext(...)` for candidate IDs and comparing.

### Q-CONN-SUMMARY — connection census

```sql
select state, application_name, count(*),
       max(now() - state_change) as oldest_in_state
from pg_stat_activity
group by 1, 2
order by count(*) desc;
```

Compare against `show max_connections;`. Pool saturation shows up as count pinned at the pool size with new work queuing upstream.

### Q-WAIT-EVENTS — what active backends wait on

```sql
select wait_event_type, wait_event, count(*)
from pg_stat_activity
where state = 'active' and wait_event is not null
group by 1, 2 order by 3 desc;
```

A dominant `Lock` type points to Q-BLOCKING-CHAINS; heavy `IO` points at cache/storage; `LWLock` at internal contention.

---

## Meta

### Q-EXTENSIONS — what diagnostics are available

```sql
select extname, extversion from pg_extension order by 1;
```

Run early (D3). `pg_stat_statements` gates the load queries above; `pgstattuple` gates exact bloat measurement. If an extension you need is missing, *say so* and use the coarser fallback rather than silently skipping the check.
