# Playbook — Schema design & implementation

From requirements to a deployable artifact: data model → user confirmation → migration + access policies + tests, all written in the **discovered** project conventions, applied and verified **locally only**. The deliverable is files the user ships through their own deploy path — not a live schema change.

## Steps

### 1. Discover (Step 0)

Run `references/discover.md` in full. This playbook leans hardest on D1 (you must match the migration convention exactly) and D2 (ADRs and domain vocabulary constrain your model; an existing migration is your style guide). Open 1–2 recent migrations that created tables and read them as templates: how the project writes RLS, grants, functions, comments, idempotency.

### 2. Clarify requirements before modeling

Ask about what the schema must serve, not just what it must store:

- **Entities and relationships** — and their cardinality (1:1, 1:N, M:N), lifecycle (who creates, who deletes, soft or hard delete).
- **Access patterns** — the queries that will actually run, and roughly how often. Indexes and even table shape follow from reads/writes, not from the ER diagram alone.
- **Tenancy and authorization** — who may see/write which rows? This decides RLS policies and write-path design, and it's far cheaper to decide now than to retrofit.
- **Volume and growth** — order-of-magnitude row counts steer key types, partitioning conversations, and index appetite.
- **Invariants** — what must *never* be true (orphan rows, double-bookings, negative balances). Invariants become constraints and, where cross-row, triggers or exclusion constraints.

Two or three crisp questions beat a questionnaire. If the user has already specified most of this, confirm your reading instead of re-asking.

### 3. Model

Propose the design: tables, columns + types, keys, constraints, relationships, and the indexes implied by the stated access patterns. Encode the rules in the schema — `NOT NULL` where null is meaningless, FKs where relationships exist, CHECK/unique constraints where duplicates or bad values are bugs. A schema you can read and know what's *impossible* beats documentation.

Defer rule-level choices (type selection, index types) to the best-practices skill and cite the rules you applied.

### 4. Confirm the model with the user

Show a compact text ER sketch plus the DDL outline (table names, columns, constraints — not yet the full migration) and the reasoning for anything non-obvious. This is the cheap moment to change course; after files exist, momentum fights corrections. Proceed on explicit OK.

### 5. Write the migration — in the discovered convention

- Filename matches the discovered pattern exactly (timestamp format, separator, extension).
- Content style mirrors the template migrations from step 1: same casing, same policy phrasing, same grant/revoke discipline.
- If the project's pattern gates writes behind a service layer (e.g. REVOKE writes from client roles + SECURITY DEFINER functions as the sole write path), **match it** — don't introduce direct-write tables into a single-write-path schema. The reverse also holds: don't impose RPC ceremony on a project that writes directly.
- If you create functions that signal deterministic conflicts, use a custom SQLSTATE — never a class-40 code (see safety model rule 7; retry-aware layers will loop forever on class-40).
- State the lock impact of each DDL statement in a comment when it matters (large-table index → `CONCURRENTLY`, noting it can't run inside a transaction; constraint on a big table → `NOT VALID` + `VALIDATE`).

### 6. Write tests — in the discovered convention

If D2 found a database test convention (pgTAP, etc.), new schema ships with tests in the same style. Mirror an existing test file's structure. Cover, as applicable:

- positive: expected access works for the roles that should have it
- negative: forbidden access fails — and fails with the *expected* error/SQLSTATE
- invariants: constraints reject the bad rows they exist to reject

If the project has no DB test convention, say so and offer a minimal starting one rather than silently shipping untested schema.

### 7. Apply and verify locally

Apply to the **local** stack only (e.g. `supabase db reset` to replay the full migration chain — which also proves your migration is well-ordered — then run the project's DB test command). Production application is the user's deploy path, full stop. If tests fail, fix before presenting; report results honestly either way.

### 8. End — hand off to the deploy path

Summarize: files created (paths), test results, and the project's own next steps for deploying (the checklist/commands D2/D4 discovered — e.g. push migrations before merging code that depends on them, verify on the dashboard). Close with the "what I did not touch" line: *nothing was applied beyond the local stack.*
