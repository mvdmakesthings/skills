# Discover — the project-discovery protocol

Run this before any DBA workflow. Its purpose is to replace assumptions with observations: how this project stores schema, how it tests, how it deploys, and how you can reach its database. Five steps, D1–D5. The whole protocol is read-only.

## D1 — Locate the schema source of truth

Probe for a migrations directory:

```bash
ls -d supabase/migrations db/migrate migrations db/migrations prisma/migrations alembic/versions 2>/dev/null
```

When you find one, **read the convention off the actual filenames** — timestamped SQL (`20260527000000_brands_entity.sql`), Rails sequential (`0042_add_index.rb`), Prisma directories, Alembic revisions. Note:

- the filename pattern (you will have to match it exactly if you create a migration),
- roughly how many migrations exist and how recent the latest is (active vs. dormant schema),
- whether migrations are plain SQL or framework DSL.

If there is no migrations directory, look for a declarative schema (`schema.sql`, `schema.prisma`, ORM models) — that changes how "implementation" works in the design playbook. If there's nothing at all, the schema lives only in the database; say so, and treat the live catalog as the source of truth.

## D2 — Read the project's database knowledge

Projects accumulate hard-won database knowledge in prose. Read what exists before acting — especially before touching anything that has caused an incident before:

- **Project instructions**: `CLAUDE.md` (root and nested), `CONTRIBUTING.md`, `README` sections about the database.
- **Incident history**: `docs/pir/`, `docs/postmortems/`, `docs/incidents/` — glob for them. If the current task touches an area with a past incident, read that report first; incidents rhyme.
- **Decision records**: `docs/adr/` or similar. An ADR you contradict silently is a regression, even if your change "works".
- **Checklists**: `docs/PR-CHECKLIST.md` or any `*checklist*` file — these encode the project's deploy and review contract for schema changes. Your output must fit it.
- **Test conventions**: look for database tests (`supabase/tests/*.sql` → pgTAP; `*_test.sql`; `pytest` + a Postgres fixture) and how they run (`grep -i "test:db\|pgtap\|pg_prove" package.json Makefile` or equivalent). If the project tests its schema, your schema changes come with tests in the same style.

Capture what you learn in two or three bullets — you'll echo them in D5.

## D3 — Detect the access method

Try in priority order; stop at the first that works:

1. **Database MCP tools** — e.g. Supabase MCP (`execute_sql`, `list_tables`, `get_advisors`, `get_logs`). Fast and structured. **Caution:** these usually point at the *linked* project, which is often production — that's a D4 question before you run anything.
2. **Local stack** — `supabase status` (Supabase), `docker ps` (a compose-managed Postgres), a dev `DATABASE_URL` pointing at localhost. A local stack is the preferred target for anything beyond read-only catalog queries.
3. **Connection string / psql** — `DATABASE_URL` or similar in `.env*` files (read the variable *name and host*, don't print credentials), or an existing `psql` invocation in the project's scripts.
4. **Ask.** If none of the above resolves, ask the user how to reach the database rather than guessing.

Also check which diagnostic extensions are available once connected (`Q-EXTENSIONS` in `references/queries.md`): `pg_stat_statements` makes query-load analysis possible; `pgstattuple` enables exact bloat measurement. If they're absent, you fall back to coarser signals — say so rather than silently degrading.

## D4 — Establish target and blast radius

For every access method you found, answer: **which database does this hit?**

- Local stack → safe playground; resets are cheap.
- Linked/hosted project via MCP or remote connection string → assume **production** unless the user says otherwise. Read-only catalog queries are fine; anything else is gated (see the safety model in SKILL.md).

Also pin down the **deploy model**: are schema migrations applied automatically on deploy, or by a manual step (e.g. `supabase db push --linked`)? When schema deploys are decoupled from code deploys, *drift* — migrations in the repo not yet applied remotely, or vice versa — is a standing risk. Audits must check it; implementations must end by pointing at the project's deploy step rather than assuming the migration is live.

## D5 — Echo the discovery summary and confirm intent

Before doing the actual work, state one compact summary back to the user and get a single go-ahead. Template:

> **Discovered:** [migrations: `supabase/migrations`, timestamped SQL, 45 files] · [tests: pgTAP via `pnpm test:db`] · [access: Supabase MCP → linked project (treating as **prod**, read-only) + local stack running] · [deploy: manual `db push` — drift possible].
> **Plan:** running the [audit] read-only against [target]. OK?

This one confirmation is the gate that lets the rest of the run proceed autonomously. If anything material changes mid-run (you need a write, you need to switch targets), that's a new gate — re-confirm.
