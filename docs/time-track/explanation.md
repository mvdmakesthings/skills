# Why `track` is built the way it is

This document explains the design decisions behind the `track` plugin. For what it does, see [reference.md](reference.md). For how to use it, see [how-to.md](how-to.md).

## The problem

Most engineers lose money to "I forgot to start the timer."

The dominant time trackers (Toggl, Harvest, Clockify) live in a browser tab. Switching to that tab mid-flow costs enough activation energy that tracking gets skipped, and invoices get reconstructed from memory at month-end. Reconstructed hours are systematically under-counted. The cost is real: a freelancer who under-reports by 15% on a $150/hour rate loses about $4,500 per quarter against full effort.

The structural fix is not a better UI. It is putting the timer in the same surface where the work happens. For an engineer working in Claude Code, that surface is the terminal.

## The approach

`track` puts the timer one slash command away from your work, and stores every session as a plaintext JSONL line under git. Three primitives:

1. **`/track:start`, `/track:stop`, `/track:status`, `/track:report`** as Claude Code slash commands, so the timer is reachable without leaving the conversation.
2. **A plaintext JSONL ledger at `~/.time-tracker/`**, hand-editable and survivable past the plugin's lifetime.
3. **A git commit per stop**, producing an audit trail.

Everything else is consequence.

```
work happens here              tracking happens here              billing happens here
─────────────────────          ─────────────────────              ─────────────────────
Claude Code terminal    ───→   /track:start, /track:stop   ───→   /track:report → invoice
                                       │
                                       ▼
                               ~/.time-tracker/
                                ├── clients.json
                                ├── active.json   (uncommitted)
                                ├── entries/2026-05.jsonl
                                └── .git/         (one commit per /track:stop)
```

## Trade-offs

Every design choice gave something up.

### Plaintext JSONL, not SQLite

We chose append-only JSONL files over a sqlite database for three reasons:

| Property | JSONL | SQLite |
|---|---|---|
| Hand-editable with `$EDITOR` | yes | no, needs sqlite CLI |
| Renders meaningfully in `git diff` and `git log -p` | yes | no, binary diff |
| Survives the plugin being uninstalled | yes, you can `cat` the files anywhere | yes but you need sqlite to read |
| Concurrent-write safe out of the box | no, hence the lock | yes |
| Cross-month query speed | linear scan over one month per file | indexed |

What we gave up: speed at scale. A freelancer billing 40 hours a week generates about 5 entries per day, 100 per month. Linear scan over a month's JSONL takes single-digit milliseconds. The break-even where SQLite would matter is around 10,000 entries per month, which is more than a single human can produce.

### Git commit per stop, not per day

Each `/track:stop` produces one commit. We chose this over batched daily commits because:

- The commit timestamp **is** the audit evidence. "Did you really work that hour on May 24?" → `git log -p entries/2026-05.jsonl` shows the diff and the commit author timestamp, signed if the user has GPG configured.
- Billing dispute defensibility was the explicit goal. A daily batch commit makes individual sessions less attestable.

What we gave up: a tidy commit history. 200 commits per month in `~/.time-tracker/.git/` is normal. We treat that as a feature, not noise.

### Note via stdin, not argv

The session note is the only user-controlled string in the system. If the dispatcher accepted it via argv, every shell metacharacter (`;`, backticks, `$(...)`, newlines) would be a potential injection vector.

Specifically, this attack is real:
```
/track:stop wrote design; rm -rf /tmp/important
```

If the skill assembled this into a shell command, the `rm` would run. By piping the note through stdin (`printf '%s' "<NOTE>" | bash track.sh stop`), the dispatcher's `note=$(cat)` reads the bytes as literal text. The note round-trips into the JSONL file with the semicolon stored verbatim and nothing else executed. This is exercised by `tests/note-safety.bats`.

What we gave up: nothing. Stdin piping costs nothing in user experience.

### Skill is a thin wrapper, not a worker

The `track` skill (`skills/track/SKILL.md`) contains zero ledger logic. It constructs a Bash invocation and that is all. All time arithmetic, locking, file I/O, jq math, and error messages live in `bin/track.sh`.

We picked this split because:

- The skill prompt is consumed by an LLM at runtime. Time arithmetic in prose ("calculate the duration as end minus start in minutes") is unreliable: LLMs miscount minute boundaries, get UTC vs. local time wrong, and round in idiosyncratic ways. A bash script with `jq` does it deterministically.
- Errors and recovery hints live where they can be printed verbatim. The skill's job is to print whatever the dispatcher prints, without paraphrasing.
- The dispatcher can be tested with `bats`. The skill cannot.

What we gave up: the option to use Claude Code's tool-calling for anything fancier than `Bash`. We do not need that. The dispatcher is the right boundary.

### Month bucketing by **start** local date

A session starting at 23:30 PDT on May 31 and ending at 00:15 PDT on June 1 lands in `2026-05.jsonl`, not `2026-06.jsonl`. This is because:

- Invoices are mental-modeled by "when I started working" more than "when I finished."
- It avoids the orphan case of a session that starts and ends in the same local day but crosses a UTC midnight, which would otherwise split into two month files.

We tested this explicitly in `tests/month-bucketing.bats` with a session whose start's UTC value is in February but whose local date is January 31 PST. The entry goes into `2026-01.jsonl`.

### `--at` and `--ago` are mutually exclusive

We rejected `--at 14:00 --ago 30m` rather than picking one with a precedence rule. Two reasons:

- Precedence rules invite bugs. A user who runs `--at 14:00 --ago 30m` probably typed one by mistake; refusing surfaces the mistake.
- The error message ("--at and --ago are mutually exclusive") is one line and easy to fix.

### Active timer preserved on every recoverable failure

When `/track:stop` fails for a reason the user can fix (commit failed because GPG agent is locked, end timestamp is before start), we leave `active.json` on disk. The user can re-run `/track:stop` after fixing the underlying cause.

The alternative would be to delete `active.json` and ask the user to recreate it. That loses the start timestamp, which the user cannot reconstruct.

`tests/commit-failure.bats` and the end-before-start test in `tests/start-stop.bats` lock this in.

## Alternatives considered

### "Why not store the ledger in the project directory?"

We picked `~/.time-tracker/` over a per-project ledger because:

- One ledger across projects matches how freelancers actually invoice: by client, not by repo. A single client often spans multiple repos.
- Per-project ledgers would multiply the git-init dance and require figuring out where the project root is from inside Claude Code.

What we gave up: project-specific time queries. A freelancer who wants "hours spent on the auth migration" has to filter by note text, not by repo. That seems fine; notes are searchable with `grep`.

### "Why not auto-start the timer via Claude Code session hooks?"

The first version of the design considered hooking Claude Code's `session-start` event to auto-`/track:start`. We deferred this because:

- It needs a way to pick the client. Asking on every session is worse than typing `/track:start acme` once.
- A timer that auto-starts also has to know when to auto-stop, and "the user closed the terminal" is a poor proxy for "work is done."

If the manual-start pattern turns out to be insufficient in practice, we revisit. The deferral list is documented in the plugin's README ("What is intentionally NOT in v1").

### "Why not a CSV export?"

`/track:report` produces markdown because markdown is the format invoices arrive in. CSV is one `jq` command away from any JSONL file:

```bash
jq -r '[.client, .start, .end, .duration_min, .note] | @csv' \
  ~/.time-tracker/entries/2026-05.jsonl > may.csv
```

A built-in CSV exporter would just be a wrapper around that one-liner. We did not write the wrapper.

## What this means for you

When you are using `track`, the design above means:

- **Your ledger outlives the plugin.** If you uninstall `track`, the files in `~/.time-tracker/` are still readable text, still queryable with `jq`, still a real git repo.
- **You can correct entries by hand.** Open the JSONL in `$EDITOR`, fix the line, commit. The dispatcher only stages files it wrote itself; your hand-edit is not swept into the next `/track:stop` commit. See [how-to.md](how-to.md#correct-a-session-by-hand).
- **A billing dispute is winnable.** Show the git log. Each commit's author timestamp is a contemporaneous record of when the session ended.
- **You will not be saved from typing the wrong client name.** The dispatcher validates `clients.json` membership and errors if missing, but it cannot tell `acme` from `acmee`. Read the start message echo before walking away.

## Related

- [Reference: complete surface](reference.md)
- [How-to: common tasks](how-to.md)
- [Tutorial: from zero to first invoice](tutorial.md)
