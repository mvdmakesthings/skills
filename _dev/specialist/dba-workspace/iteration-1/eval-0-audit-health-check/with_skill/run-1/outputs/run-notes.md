# Run notes — Charter DB health audit (2026-06-06)

Read-only audit following the `dba` skill's audit playbook. Rule-level guidance deferred to the
`supabase-postgres-best-practices` skill. All SQL ran against the **local** stack only.

## Discovery (Step 0 / D1–D5)

- `ls -d supabase/migrations …` + `ls -1 supabase/migrations` → 43 `.sql` files, timestamped
  convention `YYYYMMDDHHMMSS_name.sql`, latest `20260605213520_stale_seq_errcode_p0409.sql`.
- `ls docs/pir docs/adr supabase/tests` → 1 PIR (read in full), 11 ADRs, ~35 pgTAP tests.
- Read: `CLAUDE.md` (provided), `docs/pir/2026-06-05-postgrest-40001-retry-storm.md`.
- `supabase status` → local stack up; DB `postgresql://postgres:postgres@127.0.0.1:54322/postgres`.
- Access method: host `psql` absent → exec into local DB container.
  Constraint: linked/prod project off-limits, so Supabase MCP tools were **not** used.
- Deploy model: manual `supabase db push --linked` (drift possible) — from CLAUDE.md.

## Connection / harness

```bash
docker ps --format '{{.Names}}' | grep supabase_db          # → supabase_db_luxembourg
docker exec supabase_db_luxembourg psql -U postgres -d postgres -c "select 1;"   # connectivity
# all subsequent queries: SQL written to /tmp/dba-audit/*.sql, piped via stdin:
docker exec -i supabase_db_luxembourg psql -U postgres -d postgres -P pager=off -f - < /tmp/dba-audit/<file>.sql
```

(`/tmp/dba-audit/` used as scratch — NOT inside the charter repo, per the no-modify constraint.)

## Queries executed (by skill Q-ID)

| File | Q-IDs / purpose |
|------|-----------------|
| q-extensions.sql | Q-EXTENSIONS — pg_stat_statements present, pgstattuple absent |
| q-overview.sql | Q-DB-OVERVIEW, Q-TBL-NO-PK, Q-FK-NO-INDEX (all schemas) |
| q-rls.sql | Q-RLS-STATUS (public), Q-TABLE-GRANTS (anon/authenticated/service_role) |
| q-policies.sql | All `pg_policy` rows in public — roles, cmd, USING/WITH CHECK quals |
| q-anon-test.sql | Rolled-back `set local role anon` INSERT probe; admins/onboarding_form_fields owner+RLS; `is_admin()` definition |
| q-defpriv.sql | `pg_default_acl` — traced anon grants to stock Supabase ALTER DEFAULT PRIVILEGES |
| q-idx.sql | Q-IDX-INVALID, Q-IDX-DUPLICATE, Q-IDX-UNUSED (public), full index scan-count list |
| q-size-load.sql | Q-RELATION-SIZES, Q-DEAD-TUPLES, live row counts, Q-SEQ-EXHAUSTION, Q-ROLLBACK-RATIO, Q-TOP-TOTAL-TIME, Q-TEMP-SPILL |
| q-drift.sql | `supabase_migrations.schema_migrations` count/latest; public FK-no-index detail w/ referenced table |
| q-anon-select.sql | Rolled-back anon SELECT probe on `accounts`; list of public tables granting SELECT to anon |

Plus shell:
```bash
ls -1 supabase/migrations/*.sql | wc -l            # 43 — matches applied count
grep -rl "anon" supabase/migrations                # which migrations mention anon
git -C /Users/michaelvandyke/Dev/charter status --porcelain=v1   # clean working tree
```

## Writes performed
None. Two `BEGIN; set local role anon; … ; ROLLBACK;` blocks were used solely to *observe* RLS
enforcement (no rows changed). No DDL, DML-to-keep, or destructive statements. Prod never queried.

## Key data points captured
- DB near-empty: largest table `onboarding_form_fields` 77 rows / 184 kB; all indexes 16 kB.
- `stats_reset = 2026-06-05 21:48` (~1 day) → idx_scan/bloat/load signals not production-representative.
- Rollback ratio 0.23%; cache hit 99.97%; deadlocks 0.
- 43 applied == 43 repo migrations, both at `20260605213520`. No local drift.
