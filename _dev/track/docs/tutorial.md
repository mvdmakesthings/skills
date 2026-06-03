# Tutorial: from zero to your first invoice with `track`

You'll install the `track` plugin, register a client, run a real timer, and produce an invoice-ready markdown report. End-to-end takes about 10 minutes plus the time you actually work.

## What you'll need

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.33 or later.
- `jq` ≥ 1.6:
  - macOS: `brew install jq`
  - Debian / Ubuntu: `sudo apt install jq`
- `git` with `user.email` and `user.name` set globally:
  ```bash
  git config --global user.email "you@example.com"
  git config --global user.name  "Your Name"
  ```

You do not need to create `~/.time-tracker/` yourself. The first `/track:*` command does that.

## Step 1: Install the plugin

Open Claude Code in any terminal and add the marketplace:

```
/plugin marketplace add mvdmakesthings/claude-marketplace
```

Then install the plugin:

```
/plugin install track@mvdmakesthings
```

Confirm the four `/track:*` commands are available:

```
/track:status
```

The first run does the preflight: creates `~/.time-tracker/`, initializes a git repo there, bootstraps a `.gitignore`, and creates an empty `clients.json`. You should see:

```
[track] no active timer.
today completed sessions: (none)
```

If you instead see `[track] git user.email is not configured` or `[track] jq is required`, the error message includes the exact fix. Run it and re-try `/track:status`.

## Step 2: Register a client

`track` keeps a rate table at `~/.time-tracker/clients.json`. Right now it's empty (`{}`). Pick a short tag for a real client and an hourly rate. We'll use `acme` at $150/hour for the rest of this tutorial.

```bash
echo '{"acme": {"rate": 150}}' > ~/.time-tracker/clients.json
```

Tags must match `^[a-zA-Z0-9_-]+$`: letters, digits, dash, underscore. No spaces. Rates are dollars per hour, integer or float.

To add more clients later, edit the file by hand and add additional keys:

```json
{
  "acme":    {"rate": 150},
  "globex":  {"rate": 200},
  "soylent": {"rate": 125}
}
```

There is no `/track:client` command. The rate table is hand-edited on purpose; see [explanation.md](explanation.md) for why.

## Step 3: Start a timer

Pick something small you can actually do for 5 to 10 minutes. Then start the timer:

```
/track:start acme
```

You should see:

```
[track] started: acme @ 14:23
```

(Your time will be the current local time in 24-hour format.)

Look in `~/.time-tracker/` and you'll see a new file called `active.json`. It is not committed; it's the only record of the running timer.

```bash
cat ~/.time-tracker/active.json
```

```json
{"client":"acme","start":"2026-05-24T21:23:00Z"}
```

Timestamps are stored in UTC. The dispatcher converts to your local time for display.

## Step 4: Do the work

Go do the thing. Five minutes is plenty for this tutorial.

While you work, you can check on the timer:

```
/track:status
```

```
[track] active: acme · running for 7m · started 14:23 local
today completed sessions: (none)
```

## Step 5: Stop the timer with a note

When the session is done, stop the timer and describe what you did:

```
/track:stop wrote the tutorial draft and verified the install steps
```

You should see:

```
[track] stopped: acme · 7m · today's acme total: 7m
```

Behind the scenes, the dispatcher just did six things:

1. Read `active.json` to find the start timestamp.
2. Computed the duration (now minus start, floored to minutes).
3. Appended a single JSON line to `~/.time-tracker/entries/2026-05.jsonl` (or whichever month file matches the start's local date).
4. Ran `git add entries/2026-05.jsonl` (only that file) and `git commit -m "track: acme 7m"`.
5. Deleted `active.json`.
6. Released its lock.

You can verify with `git`:

```bash
git -C ~/.time-tracker log --oneline
```

```
a1b2c3d track: acme 7m
e4f5g6h track: init ledger
```

The note you typed lives in the JSONL entry, not the commit message. Have a look:

```bash
cat ~/.time-tracker/entries/2026-05.jsonl
```

```json
{"client":"acme","start":"2026-05-24T21:23:00Z","end":"2026-05-24T21:30:00Z","duration_min":7,"note":"wrote the tutorial draft and verified the install steps"}
```

## Step 6: Run the report

Now produce an invoice-ready report:

```
/track:report
```

By default this covers the last 7 days. You should see something like:

```markdown
| Date       | Client | Duration | Rate     | Amount   | Note |
|------------|--------|----------|----------|----------|------|
| 2026-05-24 | acme   | 7m       | $150/hr  | $17.5    | wrote the tutorial draft and verified the install steps |

**Total: $17.5 USD** — 7m total (0.12h)
```

That output is real markdown. You can copy it, paste it into your invoicing template, and send.

## Step 7: Try the backdating flags

Real-world: you start a session and forget to run `/track:start`. The plugin handles this with `--at` (backdate to a specific local time today) and `--ago` (backdate by a duration).

Try it:

```
/track:start acme --ago 30m
```

```
[track] started: acme @ <30 minutes ago>
```

Stop immediately:

```
/track:stop testing the --ago flag
```

```
[track] stopped: acme · 30m · today's acme total: 37m
```

The same flags work on `/track:stop` for when you forgot to stop:

```
/track:start acme
# work for two hours
/track:stop --at 16:00 had to run, forgot to stop until later
```

`--at` and `--ago` are mutually exclusive. The dispatcher rejects `/track:start acme --at 14:00 --ago 30m` with `[track] --at and --ago are mutually exclusive`.

## What you built

You now have:

- A working timer reachable from inside Claude Code via four slash commands.
- A plaintext, git-versioned ledger at `~/.time-tracker/` that survives the plugin getting uninstalled.
- One real client and at least two sessions recorded with notes, hours, and rate.
- A markdown report you could send to a client as the body of an invoice.

The whole system is two files of yours (`clients.json` and `entries/YYYY-MM.jsonl`) plus a git repo that records every stop as a commit. If you ever uninstall the plugin, those files are still readable text and the git history is intact.

## What to read next

- **The complete command surface** lives in [reference.md](reference.md). Every flag, every file format, every exit code.
- **How to handle recovery scenarios** (commit failure, hand-editing, audits, `jq` queries against the ledger) is in [how-to.md](how-to.md).
- **Why the plugin is built the way it is** (plaintext over SQLite, stdin for notes, git commit per stop) is in [explanation.md](explanation.md).
