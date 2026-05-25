# `track` reference

Complete reference for the `track` plugin: slash commands, dispatcher subcommands, file formats, exit codes, environment variables, and constraints.

## Slash commands

All four commands route to the `track` skill, which calls `bin/track.sh` with the matching subcommand. The skill never does time arithmetic, file I/O, or git work; the dispatcher does.

### `/track:start <client> [--at HH:MM | --ago <duration>]`

Start a timer for the named client.

| Argument | Type | Constraint | Required |
|---|---|---|---|
| `<client>` | string | `^[a-zA-Z0-9_-]+$`, must exist as a key in `clients.json` | yes |
| `--at HH:MM` | flag | 24-hour local time, hour 0-23, minute 0-59 | no |
| `--ago <duration>` | flag | `<Nh><Nm><Ns>` (e.g. `30m`, `2h`, `1h30m`, `90s`) | no |

`--at` and `--ago` are mutually exclusive. Without either flag, the start time is "now" in UTC.

Effects:
- Writes `~/.time-tracker/active.json` atomically (tmp + mv).
- Errors if a timer is already running (active.json is untouched).
- Errors if the client is not registered (prints the exact `echo` command to add it).

Output on success:
```
[track] started: <client> @ HH:MM
```

### `/track:stop [--at HH:MM | --ago <duration>] [note...]`

Stop the active timer. The note describes the session and is piped through stdin internally by the skill, never passed on argv.

| Argument | Type | Constraint | Required |
|---|---|---|---|
| `--at HH:MM` | flag | same as `start` | no |
| `--ago <duration>` | flag | same as `start` | no |
| `[note...]` | string | any text including shell metacharacters, newlines, quotes | no |

Effects:
- Appends one JSONL line to `~/.time-tracker/entries/YYYY-MM.jsonl`, bucketed by the start timestamp's local date.
- Runs `git add entries/YYYY-MM.jsonl` (only that file) and commits with message `track: <client> <duration_min>m`.
- Removes `active.json`.
- Refuses if the resolved end timestamp is before the start; `active.json` is preserved so you can retry with a valid `--at`/`--ago`.
- Refuses unknown positional argv tokens with: `[track] /track:stop unknown arg: '<x>' (the note must come via stdin, not argv)`.

Output on success:
```
[track] stopped: <client> · <duration> · today's <client> total: <hours>
```

Output on commit failure (e.g. GPG agent locked):
```
[track] commit failed:
<git stderr>

Your session was appended to entries/YYYY-MM.jsonl but is NOT committed.
The active timer is preserved — fix the underlying issue and re-run /track:stop.
...
```

### `/track:status`

Print the active timer (if any) plus today's completed totals per client. No arguments.

Output forms:
```
[track] active: <client> · running for <duration> · started HH:MM local
today completed sessions:
  <client-a>: <minutes>m
  <client-b>: <minutes>m
```

Or:
```
[track] no active timer.
today completed sessions: (none)
```

Heads-up message appears when the active timer has been running for more than 720 minutes (12 hours):
```
[track] heads-up: timer has been running for <duration>. Did you forget to /track:stop?
```

### `/track:report [--week | --month YYYY-MM] [--client <name>]`

Print an invoice-ready markdown table.

| Flag | Default | Constraint |
|---|---|---|
| `--week` | yes (default) | last 7 days inclusive of today, local-date based |
| `--month YYYY-MM` | no | `^[0-9]{4}-[0-9]{2}$` |
| `--client <name>` | no | `^[a-zA-Z0-9_-]+$` |

Output is a markdown table with columns: Date, Client, Duration, Rate, Amount, Note. The amount uses each session's start-time-month rate from `clients.json`. The footer is:
```
**Total: $X,XXX.XX USD** — <minutes>m total (<hours>h)
```

Empty period prints `(no entries in the last 7 days)` or `(no entries for <month>)`.

## Dispatcher (`bin/track.sh`)

Subcommands: `start`, `stop`, `status`, `report`. All four commands run a single `preflight()` first.

### Preflight (every command)

1. Create `~/.time-tracker/` if missing.
2. Init `~/.time-tracker/.git/` if missing.
3. Validate `git config user.email` and `user.name` (errors with a config command hint if either is missing).
4. Check `jq` is on PATH and version ≥ 1.6 (required for `strflocaltime`).
5. Bootstrap `.gitignore` with `active.json`, `active.json.tmp`, `.lock/` on first run.
6. Create `clients.json` as `{}` if missing.
7. Create `entries/` if missing.

### Locking

`acquire_lock()` uses `mkdir ~/.time-tracker/.lock/` as an atomic check. On contention:
- Reads `.lock/pid`. If the PID is dead (no `kill -0`), reaps the stale lock and retries.
- If the PID is alive, exits with `[track] another track command is running (pid <N>)`.
- If `.lock/pid` does not exist yet, retries up to 3 times with 0.1s backoff.

The lock is released by an `EXIT INT TERM` trap so it survives errors.

## File formats

### `~/.time-tracker/clients.json`

JSON object. Keys are client tags (`^[a-zA-Z0-9_-]+$`). Values are objects with at least a `rate` field (dollars per hour, integer or float).

```json
{
  "acme":   {"rate": 150},
  "globex": {"rate": 200}
}
```

There is no `/track:client` command. Edit this file by hand.

### `~/.time-tracker/active.json`

Present only while a timer is running. Not committed (gitignored). Atomic write via `active.json.tmp` then `mv`.

```json
{
  "client": "acme",
  "start":  "2026-05-24T21:23:00Z"
}
```

Timestamps are UTC ISO-8601.

### `~/.time-tracker/entries/YYYY-MM.jsonl`

One JSON line per completed session. The filename uses the start timestamp's **local** year-month, not UTC and not the stop time. A session that starts on May 31 local but stops on June 1 UTC lands in `2026-05.jsonl`.

```json
{"client":"acme","start":"2026-05-24T21:23:00Z","end":"2026-05-24T22:48:00Z","duration_min":85,"note":"design review"}
```

Field shapes:
| Field | Type | Notes |
|---|---|---|
| `client` | string | matches a key in `clients.json` |
| `start` | string | UTC ISO-8601 |
| `end` | string | UTC ISO-8601, always `>= start` |
| `duration_min` | integer | `floor((end - start) / 60)` |
| `note` | string | may be empty, may contain newlines, never interpreted as code |

### `~/.time-tracker/.gitignore`

Bootstrapped on first run with:
```
active.json
active.json.tmp
.lock/
```

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | runtime error (preflight failed, lock held, client not registered, end-before-start, commit failed) |
| 2 | usage error (missing argument, bad flag value, unknown subcommand) |

## Environment variables

| Variable | Effect |
|---|---|
| `TRACK_DIR_OVERRIDE` | Override the tracker directory. Test suite uses this with a `mktemp -d`. Production: leave unset. |
| `HOME` | Used to derive the default tracker directory (`$HOME/.time-tracker`). |

## Prerequisites

- `jq` ≥ 1.6. The dispatcher checks this explicitly; older `jq` lacks `strflocaltime` and the dispatcher will exit with an install hint.
- `git` with global `user.email` and `user.name` set.
- `bash`. The dispatcher targets stock macOS bash 3.2 and modern Linux bash. No bash 4+ features (no associative arrays, no negative array indices).
- `date`. The dispatcher uses BSD `date -v` first and falls back to GNU `date -d`, so both macOS and Linux work.

## Skill invocation contract

The `/track:*` slash commands invoke the `track` skill, which constructs a Bash invocation:

- `start`: `bash "${CLAUDE_PLUGIN_ROOT}/bin/track.sh" start $ARGUMENTS`
- `stop` (no note): `bash "${CLAUDE_PLUGIN_ROOT}/bin/track.sh" stop [<FLAG> <VAL>]`
- `stop` (with note): `printf '%s' "<NOTE>" | bash "${CLAUDE_PLUGIN_ROOT}/bin/track.sh" stop [<FLAG> <VAL>]`
- `status`: `bash "${CLAUDE_PLUGIN_ROOT}/bin/track.sh" status`
- `report`: `bash "${CLAUDE_PLUGIN_ROOT}/bin/track.sh" report $ARGUMENTS`

The note is piped through stdin, not argv, so shell metacharacters in the note are stored as literal text. See [explanation.md](explanation.md#why-stdin-for-the-note) for the security rationale.

## Related

- [How-to: common tasks](how-to.md)
- [Tutorial: from zero to first invoice](tutorial.md)
- [Explanation: design rationale](explanation.md)
- [Plugin README](../../plugins/time-track/README.md)
