# Runbook: charter-prod high-CPU + portal timeouts — database-level investigation

**Scope:** prod Supabase project `charter-prod` (`gmlhwnttzynchbeidgqh`) is firing high-CPU
alerts and operators are seeing the portal time out. This is the playbook for finding the
cause **at the database layer** and deciding what to do about it.

**The single most important thing to know up front:** this exact symptom pattern
(high CPU + portal timeouts) has already taken charter-prod down once — the
**2026-06-05 PostgREST 40001 retry-storm** (`docs/pir/2026-06-05-postgrest-40001-retry-storm.md`).
High CPU was the *first* alert that fired, ~4 hours into a server-side infinite-retry loop.
So before anything else: **assume a failure storm until the numbers say otherwise, and check the
known-incident signature first.** It will either confirm a regression or rule it out in two minutes.

---

## 0. Ground rules before you touch anything

- **Read-only until you understand the cause.** Killing connections or replacing functions
  blind bought *seconds* last time, not minutes — the storm re-ignited from a single fresh
  request. Diagnose the mechanism first, then mitigate the mechanism.
- **Trust the Postgres error log over the API/edge log under load.** During the last incident
  the API edge log stream lagged ~3 hours and nearly got misread as "traffic stopped." Postgres
  logs were real-time.
- **Have these open:** Supabase dashboard → Database → Roles/Connections + the SQL editor (or a
  `psql` against prod), the Logs Explorer (Postgres logs, not just API logs), and the CPU/Disk
  metrics panel.
- **One person drives the DB, one person watches metrics and writes the timeline.** Note every
  destructive action with a UTC timestamp — you'll want it for the PIR.

> Connection note for prod: use the Supabase dashboard SQL editor or a pooler/direct connection
> string from project settings. Everything below is **read-only `SELECT`** except the explicitly
> labelled MITIGATION section at the end. Run the read-only block end to end first.

---

## 1. Is this a failure storm? (rollback ratio — the decisive signal)

Failed/aborted transactions **do not** show up in `pg_stat_statements`. That's the trap: the
top-queries view looked innocent last time while the DB burned ~1,400 rolled-back txns/sec. The
one number that told the whole story was the **rollback ratio** in `pg_stat_database`.

```sql
-- A) cumulative ratio since stats reset
SELECT
  datname,
  xact_commit,
  xact_rollback,
  round(100.0 * xact_rollback / NULLIF(xact_commit + xact_rollback, 0), 1) AS rollback_pct,
  numbackends
FROM pg_stat_database
WHERE datname = current_database();
```

Then measure the **rate** — cumulative counters hide a storm that started recently. Sample,
wait ~15–30s, sample again:

```sql
-- B) run this, wait ~20s, run it again; subtract.
SELECT now() AS t, xact_rollback, xact_commit
FROM pg_stat_database WHERE datname = current_database();
```

**Interpretation**
- Rollback rate of hundreds–thousands/sec, and/or rollback_pct in the double digits → **failure
  storm.** This is the 2026-06-05 signature. Go straight to §2 then §5 (mitigation).
  (Last incident: 94% rollbacks, ~1,431/sec, `xact_rollback` 21.0M vs `xact_commit` 1.3M.)
- Rollback rate near zero, rollback_pct ~0–1% → **not a storm.** CPU is being burned by *committed*
  work (heavy/looping queries, missing index, vacuum, traffic spike). Skip to §3/§4.

*Healthy baseline measured on the local stack for reference:* `rollback_pct = 0.2`,
`xact_rollback` flat across two samples (71 → 71). That's what "no storm" looks like.

---

## 2. What is actually running right now? (active backends)

```sql
SELECT
  pid, usename, state, wait_event_type, wait_event,
  now() - xact_start AS xact_age,
  now() - query_start AS query_age,
  left(regexp_replace(query, '\s+', ' ', 'g'), 80) AS query
FROM pg_stat_activity
WHERE datname = current_database()
  AND state <> 'idle'
  AND pid <> pg_backend_pid()
ORDER BY xact_start NULLS LAST;
```

**What you're looking for**
- **Many `active` backends all running the *same* RPC** (e.g. `upsert_response`,
  `upsert_brand_response`, `persist_brand_strategy_run_step`) under the `authenticator` role →
  classic retry storm. Last time **all 8 active connections** were stuck in `upsert_response`.
- **`active` with `wait_event_type = Lock`** → lock contention; jump to §6.
- **One or two backends with a huge `query_age`** and high CPU → a single expensive/looping
  query (seq scan, cartesian join, runaway recursive CTE). Capture the query text and
  `EXPLAIN` it later.
- **`idle in transaction` with large `xact_age`** → a client holding a transaction open (often a
  leaked connection or an app bug), pinning locks and a pool slot. See §6.

Also bucket the connections to spot **pool saturation** (the cause of the portal timeouts — when
the `authenticator` pool is full, every DB-backed REST request 504s):

```sql
SELECT usename, state, count(*)
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY usename, state
ORDER BY count(*) DESC;
```

Compare the live `authenticator`/total count against `max_connections` (see §7). If the
`authenticator` connections are pegged and all `active` on one RPC, that's your pool saturation
mechanism — the portal timeouts and the CPU alert are the *same* event.

---

## 3. Top queries by cost (only meaningful for *committed* load)

Use this when §1 says "not a storm," or to corroborate a single-runaway-query theory. Remember:
**failed queries never land here**, so an innocent-looking top-N during a confirmed storm is
expected, not reassuring.

```sql
SELECT
  calls,
  round(total_exec_time::numeric, 1) AS total_ms,
  round(mean_exec_time::numeric, 2)  AS mean_ms,
  rows,
  left(regexp_replace(query, '\s+', ' ', 'g'), 70) AS query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

- A query with **huge `calls` and low `mean_ms`** = something hammering the DB in a tight loop
  (app retry bug, missing cache, N+1). Find the caller.
- **Low `calls`, huge `mean_ms`** = an expensive query; `EXPLAIN (ANALYZE, BUFFERS)` a
  representative call (read-only) and look for seq scans / bad row estimates / missing index.
- If nothing here explains the CPU, that itself is evidence the load is in **failed**
  transactions → go back to §1.

> Optional: if you want a clean rate read, you *could* `SELECT pg_stat_statements_reset();` and
> re-sample — but that's a write to the stats and it destroys forensic history. **Assume "do not
> reset" during a live incident** (safest answer; preserves evidence for the PIR). Only reset if
> you've already captured the current snapshot and explicitly decide the delta is worth it.

---

## 4. Is it not-the-app at all? (autovacuum / maintenance / replication)

Quick rule-outs so you don't chase the app when it's housekeeping:

```sql
-- autovacuum / autoanalyze workers chewing CPU
SELECT pid, now() - query_start AS age, left(query, 60) AS query
FROM pg_stat_activity
WHERE query ILIKE 'autovacuum:%' OR query ILIKE 'VACUUM%' OR query ILIKE 'ANALYZE%';

-- tables with massive dead-tuple bloat that would explain vacuum pressure
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC
LIMIT 10;
```

A long-running autovacuum on a hot table can spike CPU but usually doesn't cause *portal
timeouts*. If portal timeouts are present, the cause is almost always connection/pool related
(§2) or lock contention (§6), not vacuum.

---

## 5. Long-running transactions & lock contention (the other timeout cause)

If §1 is clean but the portal still times out, suspect **locks**, not CPU-bound work.

```sql
-- transactions open longer than 30s (idle-in-transaction leaks, slow writers)
SELECT pid, usename, state, now() - xact_start AS xact_age,
       left(regexp_replace(query, '\s+', ' ', 'g'), 60) AS query
FROM pg_stat_activity
WHERE datname = current_database()
  AND xact_start IS NOT NULL
  AND now() - xact_start > interval '30 seconds'
ORDER BY xact_start;

-- who is blocking whom
SELECT
  blocked.pid  AS blocked_pid,
  blocking.pid AS blocking_pid,
  blocked.wait_event_type, blocked.wait_event,
  left(blocked.query, 50)  AS blocked_query,
  left(blocking.query, 50) AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
  ON blocking.pid = ANY (pg_blocking_pids(blocked.pid))
WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0;
```

If a single `blocking_pid` is gating a queue of blocked operator requests, that one backend (or
the transaction it's stuck in) is your culprit — terminate *it* specifically (§ mitigation),
don't shotgun every connection.

---

## 6. Fingerprint the exact row under attack (advisory-lock trick)

charter's write RPCs serialize per-entity with a transaction-scoped advisory lock. Confirmed live
on the schema, `upsert_response` takes:

```
pg_advisory_xact_lock(hashtext('location:' || p_location_id::text))
```

So during a storm you can name the exact location being hammered **without any app logging** by
matching the held advisory `objid` back to candidate ids:

```sql
-- which advisory lock(s) have a crowd waiting on them
SELECT locktype, objid, mode, count(*) AS holders_and_waiters
FROM pg_locks
WHERE locktype = 'advisory'
GROUP BY locktype, objid, mode
ORDER BY holders_and_waiters DESC
LIMIT 10;

-- then resolve the objid to a location id (read-only)
SELECT id
FROM public.locations
WHERE hashtext('location:' || id::text) = <objid_from_above>;
```

(Same pattern applies to the brand-strategy RPCs keyed by `brand_id` — adjust the `hashtext('...')`
prefix to match the RPC body if the storm is on a brand-strategy write.)

This is how the last incident pinpointed the single location an operator's autosave was racing.

---

## 7. The known-incident regression check (do this even if the storm looks new)

The 2026-06-05 fix moved every deterministic conflict rejection off SQLSTATE `40001`
(serialization_failure, which **PostgREST auto-retries forever** — postgrest#3673) to the custom
`P0409`. If a migration drift or a hand-edit reintroduced a class-40 code on prod, the storm is
back by construction. Verify on prod:

```sql
-- A) NO public RPC should raise any class-40 code. Expect 0 rows.
SELECT n.nspname AS schema, p.proname AS function
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (p.prosrc ILIKE '%40001%'
       OR p.prosrc ~* 'errcode\s*:?=?\s*''40[0-9]{3}''');

-- B) the five conflict RPCs must each raise P0409. Expect raises_p0409 = t for all five.
SELECT p.proname, (p.prosrc ILIKE '%P0409%') AS raises_p0409
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('upsert_response','upsert_internal_response',
                    'upsert_account_intake_response','upsert_brand_response',
                    'persist_brand_strategy_run_step')
ORDER BY p.proname;
```

*Verified on the local stack (matches the post-fix expectation):* query A returns **0 rows**, and
all five RPCs in query B return `raises_p0409 = t`. If prod disagrees with this, you've found
either the regression or undeployed/over-deployed schema drift — remember **migrations are NOT
auto-applied on deploy** (`supabase db push --linked` is manual; cross-check
`supabase migration list --linked`).

Sanity-check the pool/timeout guardrails too — `statement_timeout`/`idle_in_transaction_session_timeout`
of `0` (unlimited) means nothing will self-heal a stuck backend:

```sql
SELECT name, setting, unit FROM pg_settings
WHERE name IN ('max_connections','idle_in_transaction_session_timeout',
               'statement_timeout','lock_timeout');
```

---

## 8. Read the Postgres error log (real-time truth under load)

In the Supabase dashboard, open **Logs → Postgres** (not the API/edge log — it lags under load).
Look for a high-frequency repeating ERROR. A storm shows as a firehose of the *same* error:

- `stale_client_seq` / `lease_lost` raised with `P0409` at very high frequency, all targeting one
  entity → an autosave/client race re-sending a used `client_seq` (the 2026-06-05 trigger). With
  `P0409` in place these are **rejected once and not retried** — so a firehose of P0409 means a
  misbehaving *client* (open tab spamming), not the retry-forever loop.
- The same error carrying a **class-40 code (`40001`)** → the retry-forever loop is live; this is
  the actual outage mechanism and §7 will have already flagged the regression.

(If you have shell access to a self-hosted/local node, the equivalent is
`docker logs <pg_container> 2>&1 | grep -iE 'ERROR|FATAL|stale|P0409|40001'`.)

---

## Decision tree (what to do about what you find)

| Finding | Cause | Action |
|---|---|---|
| High rollback rate + many `active` backends on one RPC + class-40 code present (§1,§2,§7) | **Retry-forever storm regression** | Apply MITIGATION below: fix the errcode, then drain. This is an outage. |
| High rollback rate + RPCs already on `P0409` + Postgres log firehose of `stale_client_seq` on one entity (§1,§7,§8) | **Misbehaving client** re-sending used `client_seq` (no infinite loop, but still load) | Identify the entity via §6; have the operator close/refresh the offending tab; consider a temporary per-entity throttle. App-side fix is the autosave seq accounting (VYT-29 / `AutosaveForm`). |
| Low rollback, one backend with huge `query_age` / high cost in `pg_stat_statements` (§3,§5) | **Runaway / unindexed query** | `EXPLAIN (ANALYZE)` it; terminate that one `pid`; fix the query/index after. |
| Blocked queue behind one `blocking_pid`; `idle in transaction` (§5) | **Lock contention / leaked txn** | Terminate the specific blocker `pid`; investigate the client that leaked it. |
| Long autovacuum / high dead tuples, low rollback, no lock queue (§4) | **Maintenance pressure** | Usually self-resolves; only intervene if it's blocking. Not a portal-timeout cause on its own. |
| `authenticator` connections pegged at `max_connections`, all on one RPC (§2) | **Pool saturation** (the portal-timeout symptom) | Same root as the storm rows above — fix the mechanism, don't just bump `max_connections`. |

---

## MITIGATION (the only writes in this runbook — do these only after diagnosis)

Order matters. The lesson from 2026-06-05: **killing connections without removing the cause
re-ignites in seconds.** Fix the mechanism first.

1. **If §7 found a class-40 regression** — replace the offending function's errcode on prod
   (`CREATE OR REPLACE FUNCTION ...` changing only `errcode = '40001'` → `'P0409'`). This drains
   a PostgREST retry loop *instantly* because PostgREST does not retry non-class-40 errors. This
   is the proven fix.

   *Confirmation I would normally seek here:* "OK to hot-patch the function on prod ahead of a
   migration?" No human is available, so I assume **yes for the errcode hot-patch** — it is the
   minimal, reversible change that stops an active outage and is exactly what resolved the prior
   incident — and I would immediately follow it with the proper migration + `supabase db push
   --linked` so the schema and the repo agree (migrations are not auto-applied).

2. **Then** terminate the stuck backends so the pool drains:
   ```sql
   -- target precisely: the role + the RPC you confirmed in §2 (NOT a blanket kill)
   SELECT pid, pg_terminate_backend(pid)
   FROM pg_stat_activity
   WHERE datname = current_database()
     AND usename = 'authenticator'
     AND state = 'active'
     AND query ILIKE '%upsert_response%';   -- adjust to the RPC you actually saw
   ```
   For a single runaway query or a single lock blocker, terminate just that one `pid` instead.

3. **Verify drained:** re-run §1B twice — `xact_rollback` should go flat (last time it froze at
   23,606,997 once the loop stopped). Confirm `authenticator` connections fall back to normal and
   the portal recovers.

4. **Address the trigger client-side:** the upstream cause is the autosave/client race
   re-sending a used `client_seq`. The durable fix is the `lastSentSeq` (max of
   committed/dispatched) accounting + per-field circuit breaker in `AutosaveForm`
   (shipped under VYT-29). If an operator's open tab is still spamming, have them close/refresh it.

5. **Do NOT** reach for `max_connections` as the fix. A bigger pool just means more loopers before
   saturation. The fix is always the mechanism (errcode / client race / the one bad query).

---

## After the fire is out

- Capture the UTC timeline of every action taken (you'll need it for the PIR; see
  `docs/pir/` and the `/pir` skill).
- The still-open action item from last time is the real prevention: **alert on rollback ratio
  (`xact_rollback`/`xact_commit`) or REST 5xx rate** so a storm pages at minute one, not hour four.
  CPU is a lagging, indirect symptom — it's why this incident class is hard to catch early.
- Re-run §7 against prod and cross-check `supabase migration list --linked` to confirm no schema
  drift remains.

---

### Appendix: what was verified live (local stack, read-only)

All diagnostic queries above were executed against the **local** Supabase stack
(`postgresql://postgres:postgres@127.0.0.1:54322/postgres`, Postgres 17.6, PostgREST v14.10,
`pg_stat_statements` 1.11) to confirm they run and to capture healthy-baseline output. The local
DB showed a healthy system (rollback_pct 0.2, no active non-idle backends, no lock waits, no
class-40 errcodes, all five conflict RPCs on `P0409`, advisory-lock formula confirmed as
`hashtext('location:'||p_location_id::text)`). **Prod was not touched** — per the incident
constraints, the linked/remote project is off-limits; these queries are intended to be run by a
human against prod via the dashboard SQL editor or a direct connection.
