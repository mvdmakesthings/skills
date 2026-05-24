# track

Console-native billable hours tracker for Claude Code.

Most engineers lose money to "I forgot to start the timer." Toggl and friends live in a browser tab; switching to them mid-flow costs enough activation energy that tracking gets skipped and invoices get reconstructed from memory at month-end. `track` puts the timer one slash command away inside the same terminal where the work happens, and stores every session as a git-versioned plaintext JSONL line so the ledger is auditable, hand-editable, and survives the plugin getting uninstalled.

## Install

```
/plugin marketplace add mvdmakesthings/claude-marketplace
/plugin install track@mvdmakesthings
```

## Prerequisites

- **jq ≥ 1.6** — used for ISO-8601 date math and JSON manipulation
  - macOS: `brew install jq`
  - Debian / Ubuntu: `sudo apt install jq`
- **git** with `user.email` and `user.name` configured globally:
  ```bash
  git config --global user.email "you@example.com"
  git config --global user.name  "Your Name"
  ```

The first `/track:*` command you run will auto-create `~/.time-tracker/` as a git repo and prompt you (with the exact commands) if either prerequisite is missing.

## First 2 minutes (Quickstart)

Register your first client by writing one line to `clients.json`. Pick a short tag (letters / digits / dash / underscore) and your hourly rate in dollars:

```bash
echo '{"acme": {"rate": 150}}' > ~/.time-tracker/clients.json
```

Then start tracking inside Claude Code:

```
/track:start acme
```

→ `[track] started: acme @ 14:23`

Work for a bit. Check on the running timer at any time:

```
/track:status
```

→ `[track] active: acme · running for 1h 12m · started 14:23 local`

When done, stop and add a short note:

```
/track:stop wrote the design doc and a first draft of the API
```

→ `[track] stopped: acme · 1h 14m · today's acme total: 1h 14m`

At the end of the week (or whenever an invoice is due):

```
/track:report --week
```

→ a markdown table of every session in the last 7 days with hours, rates, per-session dollars, and a final dollar total — copy-paste-ready into an invoice.

That's the whole loop.

## Commands

### `/track:start <client>`

Start a timer for the named client. Errors if `<client>` is not in `clients.json` (and shows you the exact line to add). Errors if a timer is already running.

### `/track:stop [note...]`

Stop the active timer. The optional note is passed through stdin internally, so shell metacharacters (`;`, backticks, `$(...)`, newlines) are stored as literal text and never interpreted as code.

On success, prints the session length and today's total for that client. On failure (e.g. `git commit` fails because GPG agent is locked), prints a recovery hint and **preserves the active timer** so you can retry after fixing the underlying issue.

### `/track:status`

Prints the active timer (if any) and today's completed totals per client. Heads-up message appears if the active timer has been running > 12 hours.

### `/track:report [--week | --month YYYY-MM] [--client <name>]`

Prints an invoice-ready markdown table. Default is `--week` (last 7 days inclusive of today).

- `--week` — last 7 days, local-date based
- `--month YYYY-MM` — explicit month (e.g. `--month 2026-05`)
- `--client <name>` — filter to a single client

Output includes per-session rows (date, client, duration, rate, amount, note) and a `Total: $X,XXX.XX USD` line at the bottom.

## Storage

Everything lives in `~/.time-tracker/`, which is initialised as a git repo on first run:

```
~/.time-tracker/
├── .git/                       # commit history of every /track:stop
├── .gitignore                  # excludes active.json and the lock dir
├── clients.json                # {"acme": {"rate": 150}, ...}
├── entries/
│   └── YYYY-MM.jsonl           # one line per completed session
├── active.json                 # current running timer (not committed)
└── .lock/                      # short-lived mutex (not committed)
```

Each entry is a single JSON line:

```json
{"client":"acme","start":"2026-05-24T21:23:00Z","end":"2026-05-24T22:48:00Z","duration_min":85,"note":"design review"}
```

Timestamps are UTC; display and date-bucketing convert to local time at presentation. Sessions that cross a month boundary bucket by the **start** timestamp's local date.

### Hand-editing entries

The ledger is plaintext on purpose. If a session needs correcting:

```bash
$EDITOR ~/.time-tracker/entries/2026-05.jsonl
cd ~/.time-tracker && git add entries/2026-05.jsonl && git commit -m "fix: correct duration for May 23 acme session"
```

`/track:stop` only ever stages the file it just wrote — it will not accidentally sweep your hand-edits into its own commit.

### Audit trail

Every `/track:stop` produces a git commit. To prove when an entry was made:

```bash
git -C ~/.time-tracker log --all --oneline -- entries/2026-05.jsonl
git -C ~/.time-tracker show <commit>
```

This is the property that makes the plugin defensible in a billing dispute.

## Uninstall

```
/plugin uninstall track
```

Uninstalling the plugin **does not** delete `~/.time-tracker/`. Your ledger and git history stay on disk. Remove the directory by hand only if you intend to lose the history:

```bash
rm -rf ~/.time-tracker
```

## What is intentionally NOT in v1

- A `/track:client` command for managing the rate table (hand-edit `clients.json` for now)
- Backdated stops (`--end '14:00'`)
- Manual entries (`/track:add ...`)
- Per-session rounding to 15-minute increments
- Multi-device sync via git remote
- CSV export
- Auto-start via Claude Code session hooks (only added if the manual-start pattern proves insufficient)

These deferrals are deliberate. See the [design doc](https://github.com/mvdmakesthings/claude-marketplace) for the full reasoning and the v1.1 path.

## Reporting bugs / contributing

Open an issue or PR at <https://github.com/mvdmakesthings/claude-marketplace>. Bug reports are most useful when they include the dispatcher's stderr output and the relevant lines from `~/.time-tracker/entries/*.jsonl`.
