# `track` how-to

Task-oriented guides for common `track` workflows. For the complete command surface, see [reference.md](reference.md). For the first-time walk-through, see [tutorial.md](tutorial.md).

## How to register a new client

`track` does not have a `/track:client` command. Edit the rate table by hand.

### Prerequisites
- `track` is installed (see [tutorial.md](tutorial.md)).
- You have run any `/track:*` command at least once, so `~/.time-tracker/clients.json` exists.

### Steps

1. Open the rate table:
   ```bash
   $EDITOR ~/.time-tracker/clients.json
   ```

2. Add an entry. The key is a short tag matching `^[a-zA-Z0-9_-]+$`; the value is an object with at least a `rate` field in dollars per hour.
   ```json
   {
     "acme":   {"rate": 150},
     "globex": {"rate": 200}
   }
   ```

3. Save. No commit is needed; `clients.json` is committed automatically by the next `/track:stop`.

### Verification

```
/track:start globex
```

Should print:
```
[track] started: globex @ HH:MM
```

If you see `[track] client 'globex' is not registered`, your JSON did not parse. Run `jq . ~/.time-tracker/clients.json` to find the error.

## How to backdate a session you forgot to start

The classic failure mode: you started working at 9:00 but did not run `/track:start` until 10:30.

### Option A: backdate with `--at`
```
/track:start acme --at 09:00
```

Stores a start timestamp at today's local 09:00. The dispatcher converts your local HH:MM to UTC before writing.

### Option B: backdate with `--ago`
```
/track:start acme --ago 90m
```

Stores a start timestamp 90 minutes before now.

Both flags work on `/track:stop` as well, for the case where you forgot to stop a timer until well after the session ended.

### Constraints

- `--at` is 24-hour local time. `--at 25:00` and `--at 14:99` are rejected.
- `--ago` accepts `<Nh><Nm><Ns>` combinations: `30m`, `2h`, `1h30m`, `90s`. Zero (`0m`) and malformed strings (`30x`, `abc`) are rejected.
- `--at` and `--ago` together are rejected (`mutually exclusive`).
- On `/track:stop`, an end timestamp before the start is rejected and `active.json` is preserved.

## How to correct a session by hand

The ledger is plaintext on purpose. To fix a session whose duration or note is wrong:

### Steps

1. Find the month file:
   ```bash
   ls ~/.time-tracker/entries/
   ```

2. Edit the relevant line:
   ```bash
   $EDITOR ~/.time-tracker/entries/2026-05.jsonl
   ```

   Each line is a complete JSON object. If you change `duration_min`, also change `end` to keep them consistent (or just edit one and let it diverge if you only need to fix what `/track:report` shows).

3. Commit the fix yourself:
   ```bash
   cd ~/.time-tracker
   git add entries/2026-05.jsonl
   git commit -m "fix: correct duration for May 23 acme session"
   ```

### Why a separate commit?

`/track:stop` only stages the file it just wrote. Your hand-edit to a different file (or a different line in the same file) will not be swept into the next stop's commit. This is enforced by [`tests/start-stop.bats:88-100`](../../plugins/time-track/tests/start-stop.bats).

If you edit and forget to commit, your fix sits as an uncommitted working-tree change. Next `/track:stop` does not touch it. Run `git -C ~/.time-tracker status` to find dangling edits.

## How to recover from a commit failure

The most common cause: GPG agent is locked and `git commit -S` (signed commit) fails.

### Symptom

```
[track] commit failed:
error: gpg failed to sign the data
fatal: failed to write commit object

Your session was appended to entries/2026-05.jsonl but is NOT committed.
The active timer is preserved — fix the underlying issue and re-run /track:stop.

To recover by hand:
  cd ~/.time-tracker && git add entries/ && git commit -m 'manual recovery'

If the message above mentions "gpg failed to sign", your GPG agent needs to be unlocked.
Try:  gpg --sign /dev/null </dev/null   then re-run /track:stop.
```

### What is true at this point

- The JSONL entry **was appended** to `entries/YYYY-MM.jsonl`. Your work is recorded; it is just not in a commit.
- `active.json` **was preserved**. The timer is still running from the dispatcher's perspective.
- The lock **was released**, so the next `/track:*` command will run.

### Fix and retry

1. Unlock the GPG agent:
   ```bash
   gpg --sign /dev/null </dev/null
   ```
   This prompts for your GPG passphrase, after which the agent stays unlocked for some minutes.

2. Re-run the stop:
   ```
   /track:stop <same note as before>
   ```

   The retry will append a **second** JSONL entry. You probably do not want that. See "Cleanup after retry" below.

### Alternative: commit by hand, skip the retry

1. Stage and commit the entry the dispatcher already wrote:
   ```bash
   cd ~/.time-tracker
   git add entries/$(date +%Y-%m).jsonl
   git commit -m "track: <client> <minutes>m (manual recovery)"
   ```

2. Remove the active timer:
   ```bash
   rm ~/.time-tracker/active.json
   ```

3. Confirm with:
   ```
   /track:status
   ```
   Should print `[track] no active timer.`

### Cleanup after retry

If you re-ran `/track:stop` (option above) without first deleting the orphaned JSONL line, the entry file now has two lines for the same session.

1. Open `~/.time-tracker/entries/YYYY-MM.jsonl` in `$EDITOR`.
2. Delete the older of the two lines (the one with the earlier `start` timestamp will be a duplicate; delete the duplicate).
3. Commit:
   ```bash
   cd ~/.time-tracker
   git add entries/ && git commit -m "fix: remove duplicate from commit-failure retry"
   ```

## How to audit a session

To prove when a session was recorded:

```bash
# Find every commit that touched this month's entries
git -C ~/.time-tracker log --oneline -- entries/2026-05.jsonl

# Show the commit that added a specific session
git -C ~/.time-tracker log -p -- entries/2026-05.jsonl | less

# Show every commit author timestamp (the contemporaneous record)
git -C ~/.time-tracker log --pretty=format:'%h %ad %s' --date=iso -- entries/2026-05.jsonl
```

The commit's **author timestamp** is the moment `/track:stop` ran. The **committer timestamp** is the same unless you rewrote history.

For GPG-signed commits, `git log --show-signature -- entries/2026-05.jsonl` displays the signature verification status.

## How to filter a report

### By date

- Last 7 days (the default):
  ```
  /track:report
  ```
  or explicitly:
  ```
  /track:report --week
  ```

- A specific month:
  ```
  /track:report --month 2026-05
  ```
  Format is `YYYY-MM`. Other formats are rejected with `[track] --month requires YYYY-MM`.

### By client

```
/track:report --client acme
```

Combine with a date filter:
```
/track:report --month 2026-04 --client globex
```

### Pipe the output

`/track:report` emits markdown to stdout. To save it as an invoice draft:

```
/track:report --month 2026-05
```

Then copy the output from the chat and paste into your invoice template, or run the dispatcher directly:

```bash
bash ~/.claude/plugins/.../track/bin/track.sh report --month 2026-05 > invoices/2026-05-acme.md
```

(Use `which track.sh` or check `$CLAUDE_PLUGIN_ROOT` to find the installed path.)

## How to query the ledger directly with `jq`

`/track:report` is convenient but `jq` is more flexible.

### All sessions for one client this year
```bash
cat ~/.time-tracker/entries/2026-*.jsonl \
  | jq -s 'map(select(.client == "acme"))'
```

### Total hours per client across all time
```bash
cat ~/.time-tracker/entries/*.jsonl \
  | jq -s '
      group_by(.client)
      | map({client: .[0].client, hours: (map(.duration_min) | add / 60)})
    '
```

### Sessions with a note matching a substring
```bash
cat ~/.time-tracker/entries/*.jsonl \
  | jq -s 'map(select(.note | test("design review"; "i")))'
```

### CSV export
```bash
cat ~/.time-tracker/entries/2026-05.jsonl \
  | jq -r '[.start, .client, .duration_min, .note] | @csv' \
  > may-2026.csv
```

## How to uninstall without losing history

```
/plugin uninstall track
```

This removes the plugin. It does **not** touch `~/.time-tracker/`. Your ledger and git history stay on disk.

To remove the data:
```bash
rm -rf ~/.time-tracker
```

This is irrecoverable unless you have a backup. Confirm `git -C ~/.time-tracker log` shows what you expect first.

## Troubleshooting

### `[track] git user.email is not configured`

```bash
git config --global user.email "you@example.com"
git config --global user.name  "Your Name"
```

The dispatcher requires both. The error message includes the exact commands to run.

### `[track] jq is required` or `[track] jq >= 1.6 required`

```bash
# macOS
brew install jq         # or: brew upgrade jq

# Debian / Ubuntu
sudo apt install jq
```

The dispatcher uses `strflocaltime`, which requires jq ≥ 1.6.

### `[track] another track command is running (pid N)`

A previous `/track:*` did not release the lock. This is usually a stale lock from a killed process.

Check whether PID `N` is alive:
```bash
ps -p <N>
```

If the process is dead, the dispatcher should reap the lock on its own retry. If it persists:
```bash
rm -rf ~/.time-tracker/.lock
```

This is safe; the lock directory is not committed.

### `/track:report` shows an empty table for a month with sessions

The dispatcher buckets entries by the **start timestamp's local date**. A session you remember as "Friday night" might be in last month's file if it started at 23:30 and your local date had rolled over by the time you stopped. Check both months:

```bash
ls ~/.time-tracker/entries/
```

## Related

- [Reference: complete surface](reference.md)
- [Tutorial: from zero to first invoice](tutorial.md)
- [Explanation: design rationale](explanation.md)
