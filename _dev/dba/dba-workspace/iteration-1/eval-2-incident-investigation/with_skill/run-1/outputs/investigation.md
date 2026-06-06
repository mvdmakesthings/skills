# Investigation runbook — charter-prod high CPU + portal timing out

**Symptom:** Supabase prod project (`charter-prod`, ref `gmlhwnttzynchbeidgqh`) fired high-CPU
alerts and the `/portal` surface is timing out for operators.

**Workflow:** Live incident investigation (DBA skill `references/investigate.md`). Read-only.
Every intervention is gated and shown before it runs.

> **Scope note for this document.** The diagnostic SQL below was *demonstrated against the LOCAL
> Supabase stack* (`postgresql://postgres:postgres@127.0.0.1:54322/postgres`, via
> `docker exec supabase_db_luxembourg psql`) so you can see the shape of each query's output. The
> prod project was **not** touched. When you run this for real, point the same read-only queries at
> prod (Supabase MCP `execute_sql` against the linked project, or a read-only prod connection). The
> local stack is healthy, so its output doubles as the "what normal looks like" baseline you'll
> contrast the incident state against.

---

## Step 0 — Discovery summary (done first, abbreviated under pressure)

| Dimension | Finding |
|---|---|
| **Migrations** | `supabase/migrations`, timestamped SQL (`YYYYMMDDHHMMSS_name.sql`), 43 files, very active — latest is `20260605213520_stale_seq_errcode_p0409.sql` (yesterday). |
| **Incident history** | `docs/pir/2026-06-05-postgrest-40001-retry-storm.md` — **a prior incident with the exact symptom shape: high CPU + portal timeouts for operators.** This is hypothesis #1. |
| **Decision records** | `docs/adr/0001`–`0011`; relevant: brand-strategy is a separate write stack (0001), cron-driven run-state machine (0003). |
| **Test convention** | pgTAP via `pnpm test:db` (`supabase/tests/*.sql`), Vitest units. |
| **Access method** | Supabase MCP → linked project = **PROD** (read-only only). Local stack running for query rehearsal. `psql` not on PATH locally → use `docker exec supabase_db_luxembourg psql -U postgres -d postgres`. |
| **Extensions (local)** | `pg_stat_statements` 1.11 present (load queries work); `pgstattuple` **absent** (exact bloat would need a coarser fallback — not relevant to this symptom). |
| **Deploy model** | Migrations are **NOT** auto-applied on deploy — `supabase db push --linked` is a manual step. Schema can drift from code. Relevant because an emergency `CREATE OR REPLACE` on prod can later be silently reverted by a re-applied migration if they disagree. |

**Confirmation gate (no human available):** I would normally ask "Confirm I'm running read-only
diagnostics against charter-prod, and that any mitigation (backend kills / emergency RPC swap) needs
per-statement sign-off?" Assuming the safest answer — **read-only investigation, every write gated
and shown first** — and proceeding.

**Why incident history first:** incidents rhyme. The 2026-06-05 PIR documents a PostgREST
infinite-retry storm: an operator autosave re-sent a stale `client_seq`, the RPC rejected it with
SQLSTATE `40001`, and PostgREST's transaction layer (which treats class-40 as "transient — retry")
retried the *deterministic* rejection forever. The pool saturated, every DB-backed REST request
504'd (portal down for operators), and the DB burned ~1,400 rolled-back transactions/sec with CPU
pegged for ~4.6 hours. **The CPU alert was the first signal four hours in — it lagged the mechanism
badly.** Start the investigation from this mechanism as the leading hypothesis, but verify with
evidence rather than assuming a repeat.

---

## The order of checks (and why this order)

The governing principle from the skill safety model and the PIR: **failed statements never appear
in `pg_stat_statements`** — it records only successful executions. A database can be 100% busy doing
work that *fails*, and every per-query view will swear nothing is wrong. So the investigation leads
with signals that catch failure load (rollback ratio, logs), not with the top-queries view. The CPU
alert is a lagging symptom; don't anchor on it.

```
1. Triage wide      → logs + error-rate inflection + Q-DB-OVERVIEW + Q-CONN-SUMMARY
2. Decisive check   → Q-ROLLBACK-RATIO, sampled twice ~30s apart (failed-vs-slow discriminator)
3a. If rollbacks climbing  → live forensics on FAILURES (activity, advisory-lock fingerprint, logs)
3b. If rollbacks flat/high commits → slow-query route (Q-TOP-TOTAL-TIME) instead
4. Hypothesis: signal → mechanism (one sentence)
5. Mitigate vs. root cause (say which is which; both gated on prod)
6. Verify across ≥2 windows
7. Hand off to /pir
```

---

## Step 1 — Triage signals (sweep wide, don't go deep yet)

**a) Live logs first — they lead; CPU lags.** Pull the Postgres error log and the PostgREST/API
log. From the PIR: trust the **Postgres error log** under load — during the last incident the API
edge log stream lagged ~3 hours and was nearly misread as "traffic stopped." Look for a *firehose of
the same error* — last time it was `stale_client_seq` at ~100 errors / 190 ms.

- Via MCP: `get_logs` (service `postgres`, then `api`).
- What to extract: which error, how fast, **since when** (the inflection time bounds what changed —
  deploy? traffic spike? a single operator's tab left open?).

**b) Q-DB-OVERVIEW — vital signs in one row.** Local (healthy baseline) output:

```
 datname  | xact_commit | xact_rollback | rollback_pct | cache_hit_pct | deadlocks | temp_files | stats_reset
----------+-------------+---------------+--------------+---------------+-----------+------------+------------------
 postgres |       32558 |            71 |         0.22 |         99.97 |         0 |          0 | 2026-06-05 21:48
```

`rollback_pct = 0.22` and `cache_hit_pct = 99.97` is what *healthy* looks like. On prod during the
incident the PIR measured **94% rollbacks**. Note `stats_reset` — counters are cumulative since then,
so for "what's happening now" you must sample twice and diff (Step 2).

**c) Q-CONN-SUMMARY — is the pool saturated, and by whom?** Local output:

```
 state  |        application_name         | count | oldest_in_state
--------+---------------------------------+-------+------------------
 idle   | supabase_mt_realtime            |     5 | 00:00:00.32
 idle   | PostgREST 14.10                 |     1 | 16:28:05
 active | psql                            |     1 |
```

Compare `count` for `application_name = 'authenticator'` / `PostgREST` against `show max_connections;`
and the PostgREST pool size. **Saturation fingerprint from the PIR:** all active connections pinned
at the pool ceiling (it was 8), every one of them running the *same* RPC. Many backends running the
same statement shape with the same parameters = a retry loop upstream resubmitting failures.

---

## Step 2 — The decisive one-number check: rollback ratio

This is the pivot of the whole investigation. Run **Q-ROLLBACK-RATIO**, wait ~30 s, run it again,
and **diff `xact_rollback`**:

```sql
select xact_commit, xact_rollback,
       round(100.0 * xact_rollback / nullif(xact_commit + xact_rollback, 0), 2) as rollback_pct
from pg_stat_database where datname = current_database();
```

Interpretation:

- **Rollbacks climbing fast** (PIR: 40,169 in 28 s ≈ 1,431/sec; ratio ~94%) → the load is
  **failures**. They are invisible in `pg_stat_statements`. **Redirect the entire investigation to
  logs and `pg_stat_activity`** — Step 3a. This is the confirmation that you're in a retry-storm,
  not a slow-query problem.
- **Rollbacks flat, commits high** → the load is real successful work → go the slow-query route
  (Q-TOP-TOTAL-TIME / Q-TOP-MEAN-TIME), Step 3b. Per `supabase-postgres-best-practices`
  `monitoring-pg-stat-statements`, high total + low mean = high-frequency (cache/optimize); high
  total + high mean = an expensive plan to fix.

> Per skill safety rule 8 ("failed is not slow"): if top queries don't explain the CPU, a high
> rollback ratio is the explanation, and you stop looking at the statements view.

---

## Step 3a — Live forensics on the failure load (the likely path)

**Q-ACTIVITY-NOW — what's running, sorted by age.** During the storm this showed every active
backend running the same RPC (`upsert_response` last time). Local (idle/healthy) shows zero rows.

```sql
select pid, usename, application_name, state, wait_event_type, wait_event,
       now() - query_start as query_age, left(query, 100) as query
from pg_stat_activity
where state <> 'idle' and pid <> pg_backend_pid()
order by query_start;
```

**Q-WAIT-EVENTS — what active backends wait on.** Dominant `Lock` → blocking (go to blocking
chains); `IO` → cache/storage; `LWLock` → internal contention; **nothing waiting but many active
running the same statement → pure throughput burned on a retry loop** (the storm signature — work is
*executing and failing*, not waiting).

```sql
select wait_event_type, wait_event, count(*) from pg_stat_activity
where state = 'active' and wait_event is not null group by 1,2 order by 3 desc;
```

**Q-LONG-RUNNING / Q-BLOCKING-CHAINS** — rule out the *other* classic mechanisms before committing
to the retry-storm hypothesis: an `idle in transaction` backend measured in minutes (app bug holding
a connection + blocking vacuum), or a lock convoy behind one head blocker. Walk
`pg_blocking_pids()` to the root; the head of the chain is the thing to understand, everything
downstream is collateral.

**Q-ADVISORY-LOCKS + fingerprint reversal — pinpoint the contended entity.** charter's write RPCs
all take a transaction-scoped advisory lock with a derivable key. I confirmed the formulas in the
migrations:

| RPC | Advisory-lock key |
|---|---|
| `upsert_response` | `hashtext('location:' \|\| <location_id>)` |
| `upsert_account_intake_response` | `hashtext('account_intake:account:' \|\| <account_id>)` |
| `upsert_internal_response` | `hashtext('internal:account:' \|\| <account_id>)` |
| `upsert_brand_response` | `hashtext('brand_response:brand:' \|\| <brand_id>)` |
| `persist_brand_strategy_run_step` | `hashtext('brand_strategy_run:brand:' \|\| <brand_id>)` |

So a hot `objid` in `pg_locks` can be reversed to a concrete entity by computing `hashtext()` for
candidate IDs. Demonstrated locally:

```sql
select hashtext('location:46cba613-...') as example_location_objid;  -- → 900646272
```

Match the live `pg_locks.objid` against `hashtext('location:'||id)` for the operator's recently-saved
locations. The PIR used exactly this to identify the single location under attack with **no logging
required.** One contended entity (one location, one tenant, one brand) usually explains a whole
storm.

**Repetition is signal.** N backends running the identical statement with identical parameters is
the tell that something upstream — the client, PostgREST, a job runner — is resubmitting failures.

---

## Step 3b — If it's real load, not failures (alternate path)

If Step 2 shows flat rollbacks + high commits, this is a genuine slow-query / throughput problem,
not a storm. Run **Q-TOP-TOTAL-TIME** and **Q-TOP-MEAN-TIME** (needs `pg_stat_statements`),
correlate the hot query with **Q-SEQSCAN-HEAVY** for a missing index, and switch to the slow-query
playbook. Also sanity-check **Q-CACHE-HIT** for a hot table dropping below ~99% (working set
exceeding shared_buffers). Defer index/plan specifics to `supabase-postgres-best-practices`
(`query-missing-indexes`, `query-optimization`).

---

## Step 4 — Form the hypothesis: signal → mechanism

State it as one sentence connecting evidence to mechanism. The expected shape here, matching the
prior incident:

> *Rollbacks climbing ~1,400/sec + every pooled backend repeating the same `upsert_*` RPC +
> advisory lock hot on one entity ⇒ a deterministic stale-`client_seq` rejection is being
> auto-retried forever by PostgREST (which treats the SQLSTATE as transient), saturating the pool
> and pegging CPU.*

**Confirm the errcode before acting** — this is also the regression check. The 2026-06-05 fix moved
all five conflict RPCs off `40001` onto `P0409`. Verify prod still reflects that (a re-applied
migration or a manual `CREATE OR REPLACE` could have drifted it back). Demonstrated locally:

```sql
select p.proname,
       (pg_get_functiondef(p.oid) ilike '%40001%') as raises_40001,
       (pg_get_functiondef(p.oid) ilike '%P0409%')  as raises_p0409
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('upsert_response','upsert_internal_response',
                    'upsert_account_intake_response','upsert_brand_response',
                    'persist_brand_strategy_run_step')
order by 1;
```

Local result — the healthy/post-fix state (all `P0409`, none `40001`):

```
             proname             | raises_40001 | raises_p0409
---------------------------------+--------------+--------------
 persist_brand_strategy_run_step | f            | t
 upsert_account_intake_response  | f            | t
 upsert_brand_response           | f            | t
 upsert_internal_response        | f            | t
 upsert_response                 | f            | t
```

- **If prod also shows all `P0409`:** the known mechanism is *already* closed at the DB layer. The
  storm, if real, has a *different* trigger — a *new* class-40 code somewhere, or a genuinely
  transient `40001`/`40P01` (deadlock) being legitimately retried. Widen the search:
  `pg_get_functiondef ilike '%40001%'` across all `public` functions (scope by name to avoid
  `pg_get_functiondef` erroring on aggregate-named functions), and check `deadlocks` in
  Q-DB-OVERVIEW.
- **If any RPC shows `raises_40001 = t`:** drift has reintroduced the exact 2026-06-05 mechanism.
  That's your root cause — go to Step 5.

Other mechanisms to keep on the shelf (skill investigate.md §5): pool exhaustion from slow queries;
lock convoy behind one long transaction; autovacuum starvation → bloat; thundering-herd cache
expiry; a deploy that changed a plan.

---

## Step 5 — Mitigate vs. root cause (both gated on prod; show SQL first)

Per skill safety rules 2–3, every prod write is shown exactly and confirmed per-operation. Prefer
the smallest intervention that removes the *mechanism*.

**Mitigation (buys time, does NOT remove the mechanism — it re-ignites):** terminate the stuck
loopers. From the PIR this bought *seconds*: the storm re-ignited from a single fresh request at
~3,000/sec. Only do this paired with the root-cause fix, or to relieve the pool while preparing it.

```sql
-- SHOWN, NOT RUN — would target prod. Identify exact pids from Q-ACTIVITY-NOW first.
-- (List the specific pids and the statement each is running before confirming.)
select pg_terminate_backend(<pid>);   -- one per stuck looper, e.g. the 8 'authenticator' backends
```

**Root cause (removes the mechanism):** if an RPC regressed to `40001`, emergency-replace just the
errcode — the same surgery that drained the loop instantly last time:

```sql
-- SHOWN, NOT RUN — emergency CREATE OR REPLACE on prod, errcode 40001 → P0409 only.
-- PostgREST does not retry non-class-40 codes, so the loop drains the moment this lands.
-- Map prod rejections to P0409 per lib/supabase/sqlstate.ts (P0409 → stale).
```

> Because migrations are NOT auto-applied (manual `db push --linked`), an emergency
> `CREATE OR REPLACE` on prod must be **immediately followed by a committed migration** in
> `supabase/migrations/` (timestamped SQL, matching the convention) so the next `db push` can't
> silently revert it. The existing `20260605213520_stale_seq_errcode_p0409.sql` is the template.
> If the trigger is instead the *client* (the autosave race re-sending a used `client_seq`), the DB
> errcode fix stops the *storm*; the client race is a separate code change queued through the normal
> flow (the PIR's VYT-29 work covers `lastSentSeq` accounting + a per-field circuit breaker).

Never raise a class-40 SQLSTATE for a deterministic rejection (skill safety rule 7, CLAUDE.md ban,
PIR lesson #1) — that's the whole reason this incident class exists.

---

## Step 6 — Verify the fix held (≥2 windows)

A fix verified at one instant may be a lull. Re-sample the decisive metric across at least two
windows ~30 s apart:

- **Q-ROLLBACK-RATIO twice → `xact_rollback` diff ≈ 0** (PIR froze it at 23,606,997). This is the
  single most important confirmation.
- **Q-CONN-SUMMARY** → pooled backends back below the pool ceiling, no cluster of identical RPCs.
- **Q-BLOCKING-CHAINS** → empty.
- **API 5xx / portal load** → back to baseline; an operator save succeeds.
- **The errcode guard from Step 4** → 0 functions raising `40001`.

---

## Step 7 — Hand off to /pir

Assemble the findings timeline — first signal (CPU alert) → checks run with their evidence (rollback
ratio, activity, advisory-lock fingerprint, errcode guard) → hypothesis → interventions with
timestamps → verification across two windows — and hand off to the **`/pir`** skill, which is
available in this project (the existing `docs/pir/2026-06-05-...` is its output format). Do not
author the post-incident report inside the investigation; that skill owns the format and
lessons-learned discipline.

**Open follow-up worth surfacing to /pir:** the 2026-06-05 PIR's last action item is still unchecked
— *"Add alerting on rollback ratio (`xact_rollback`/`xact_commit`) or REST 5xx rate so a failure
storm pages at minute one, not hour four."* If this investigation was again triggered by a *CPU*
alert rather than a rollback/5xx alert, that gap is the reason you found out hours late — call it out.

---

## What I did NOT touch

- **No queries against prod / the linked project.** All SQL here was demonstrated read-only against
  the **local** stack only; the prod-targeted statements in Steps 5 are shown, not run.
- **No writes, DDL, kills, or config changes anywhere** — investigation was entirely read-only
  (catalog + `pg_stat_*` views).
- **No files in the charter repo were modified.** The advisory-lock formulas and migration
  conventions above were read, not changed.
- **Mitigation with an open root cause:** if you run the Step 5 backend-kill mitigation without the
  errcode fix, the storm re-ignites — that mitigation must not be left standing alone.
