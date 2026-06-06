# Playbook — Live incident investigation

The database is misbehaving *now*: high CPU, error spikes, timeouts, connection exhaustion, lock storms. The job: find the mechanism, separate mitigation from root cause, verify the fix held, and hand the story to `/pir`. Investigation is read-only; any intervention (kills, config, code) is gated and shown first.

Query IDs reference `references/queries.md`.

## Steps

### 1. Discover — abbreviated but not skipped

Run `references/discover.md` fast. The non-negotiable parts under time pressure:

- **D2's incident history.** Read past PIRs *first* — incidents rhyme, and ten minutes of reading regularly saves two hours of rediscovery. If a prior incident matches the symptom shape, start from its mechanism as hypothesis #1.
- **D3/D4: access + target.** You'll be reading live production state; know what you're connected to.

### 2. Triage signals — don't anchor on the first alarm

The alert that fired is a *symptom*, often a lagging one. CPU alerts in particular lag the mechanism by many minutes; error-rate signals lead. Sweep wide before going deep:

- Live logs (platform tooling, e.g. MCP `get_logs`, or the Postgres log) — what errors, how fast, since when?
- Error rate at the API/app layer — when did it inflect? "Since when" bounds what changed (deploy? traffic? data shape?).
- Q-DB-OVERVIEW — vital signs in one row.
- Q-CONN-SUMMARY — is the pool saturated? By whom?

### 3. The decisive one-number check: rollback ratio

Run Q-ROLLBACK-RATIO, then run it again ~30s later and diff `xact_rollback`.

Why this is the pivotal check: **failed statements never appear in `pg_stat_statements`** — it records successful executions only. A database can be 100% busy doing work that fails, and every per-query view will swear nothing is wrong. A climbing rollback counter tells you the load is *failures*, and redirects the whole investigation: hunt in logs and `pg_stat_activity`, not in top-queries.

If rollbacks are flat and commits are high, the load is real work — go the slow-query route (Q-TOP-TOTAL-TIME) instead.

### 4. Live forensics

- Q-ACTIVITY-NOW — what's running; sort by age. Note `wait_event_type` distribution (Q-WAIT-EVENTS): dominant `Lock` → blocking; `IO` → storage/cache; nothing waiting but tons active → pure throughput.
- Q-LONG-RUNNING — the oldest transaction is a suspect by default (blocks vacuum, holds locks, may be the stuck thing itself). `idle in transaction` measured in minutes is an app bug holding resources.
- Q-BLOCKING-CHAINS — walk to the head blocker. The root of the chain is the thing to understand; everything downstream is collateral.
- Q-ADVISORY-LOCKS — if the app uses advisory locks with a derivable key formula, reverse the hot `objid` to a concrete entity by computing the formula for candidate IDs. One contended entity (one hot row, one tenant, one document) often explains a whole storm.
- Repetition is signal: many backends running the *same statement shape* with the same parameters means a retry loop — something upstream (client, PostgREST, a job runner) is resubmitting failures.

### 5. Form the hypothesis: signal → mechanism

State it as a sentence connecting evidence to mechanism: *"Rollbacks climbing ~1,400/s + N backends repeating the same UPDATE + advisory lock hot on entity X ⇒ a deterministic rejection is being auto-retried by a layer that treats the error as transient."* A hypothesis you can't phrase as mechanism isn't ready to act on.

Classic mechanisms worth keeping on the shelf: deterministic error + retry-happy layer (class-40 SQLSTATE, see safety model rule 7 — this exact shape has produced multi-hour outages); pool exhaustion from slow queries (each connection held longer → fewer available → queueing amplifies); lock convoy behind one long transaction; autovacuum starvation → bloat → everything slower → more concurrency → worse; thundering-herd cache expiry; a deploy that changed a plan.

### 6. Mitigate vs. root cause — and say which is which

- **Mitigation** buys time but doesn't remove the mechanism: `pg_terminate_backend(pid)` on loopers, pausing a job, rate-limiting upstream. Be explicit that if the mechanism persists, mitigation *re-ignites* — killed retry loops come back on the next client attempt. Mitigation on prod is a write: show the exact statement (with the specific pids and what they're running) and gate it.
- **Root cause** removal targets the mechanism: fixing the errcode, fixing the client's retry policy, adding the missing index, closing the idle transaction's code path. Prefer the smallest intervention that removes the mechanism — an emergency `CREATE OR REPLACE FUNCTION` changing one error code can end a storm instantly; the tidy refactor can come tomorrow.

If the root cause needs a code/schema change beyond the emergency surgery, do the gated emergency fix now and queue the proper change through design-implement.

### 7. Verify the fix held

Re-sample the decisive metric across at least two windows: rollback counter frozen (diff = 0-ish), pool back under threshold, blocking chains gone, error rate at baseline. A fix verified at one instant may be a lull — the second sample is what distinguishes "fixed" from "breathing".

### 8. End — hand off to the PIR

Assemble the findings timeline (first signal → checks run with their evidence → hypothesis → interventions with timestamps → verification) and hand off to the `/pir` skill if available — don't author the post-incident report here; that skill owns the format and the lessons-learned discipline. If `/pir` isn't available, leave the structured timeline as the artifact. Close with "what I did not touch", including any mitigation whose root cause is still open — that's the most important line in the handoff.
