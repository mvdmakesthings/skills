#!/usr/bin/env bash
# track.sh — billable-hours dispatcher for the `track` Claude Code plugin.
#
# Authoritative spec:
#   ~/.gstack/projects/mvdmakesthings-claude-marketplace/michaelvandyke-main-design-20260524-174009.md
#
# Subcommands: start | stop | status | report | pause | resume
# Storage:     ~/.time-tracker/ (git repo). Lock: ~/.time-tracker/.lock/ (mkdir-based).
# Note input:  /track:stop reads the session note from stdin (never argv).

set -euo pipefail

TRACKER_DIR="${TRACK_DIR_OVERRIDE:-${HOME}/.time-tracker}"
LOCK_DIR="${TRACKER_DIR}/.lock"
LOCK_PID_FILE="${LOCK_DIR}/pid"
JQ_MIN_MAJOR=1
JQ_MIN_MINOR=6

# ---------- preflight ----------

check_jq_version() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "[track] jq is required but not installed." >&2
    echo "        Install: brew install jq   (macOS)   |   sudo apt install jq   (Debian/Ubuntu)" >&2
    exit 1
  fi
  local ver major minor
  ver=$(jq --version 2>/dev/null | sed -E 's/^jq-([0-9]+\.[0-9]+).*/\1/')
  major="${ver%.*}"
  minor="${ver#*.}"
  if [ "$major" -lt "$JQ_MIN_MAJOR" ] || { [ "$major" -eq "$JQ_MIN_MAJOR" ] && [ "$minor" -lt "$JQ_MIN_MINOR" ]; }; then
    echo "[track] jq >= ${JQ_MIN_MAJOR}.${JQ_MIN_MINOR} required for date math (strflocaltime). Found jq-${ver}." >&2
    echo "        Upgrade: brew upgrade jq   |   sudo apt install jq" >&2
    exit 1
  fi
}

# Single preflight function called from every command path. DRY by construction.
preflight() {
  mkdir -p "$TRACKER_DIR"
  if [ ! -d "$TRACKER_DIR/.git" ]; then
    git -C "$TRACKER_DIR" init -q
  fi
  # Validate git config (needed for the commit in cmd_stop). Fail early, not mid-stopwatch.
  if ! git -C "$TRACKER_DIR" config user.email >/dev/null 2>&1; then
    cat >&2 <<'EOF'
[track] git user.email is not configured.
Set it with:
  git config --global user.email "you@example.com"
  git config --global user.name  "Your Name"
EOF
    exit 1
  fi
  if ! git -C "$TRACKER_DIR" config user.name >/dev/null 2>&1; then
    cat >&2 <<'EOF'
[track] git user.name is not configured.
Set it with:
  git config --global user.name "Your Name"
EOF
    exit 1
  fi
  check_jq_version
  # Bootstrap .gitignore on first valid run.
  if [ ! -f "$TRACKER_DIR/.gitignore" ]; then
    cat > "$TRACKER_DIR/.gitignore" <<EOF
active.json
active.json.tmp
.lock/
EOF
    git -C "$TRACKER_DIR" add .gitignore >/dev/null
    git -C "$TRACKER_DIR" commit -q -m "track: init ledger" >/dev/null 2>&1 || true
  fi
  if [ ! -f "$TRACKER_DIR/clients.json" ]; then
    echo '{}' > "$TRACKER_DIR/clients.json"
  fi
  mkdir -p "$TRACKER_DIR/entries"
}

# ---------- lock ----------

acquire_lock() {
  local tries=0 owner_pid
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if [ -f "$LOCK_PID_FILE" ]; then
      owner_pid=$(cat "$LOCK_PID_FILE" 2>/dev/null || echo "")
      if [ -n "$owner_pid" ] && ! kill -0 "$owner_pid" 2>/dev/null; then
        # Stale lock — owner is dead. Reap and retry.
        rm -rf "$LOCK_DIR" 2>/dev/null || true
        continue
      elif [ -n "$owner_pid" ]; then
        echo "[track] another track command is running (pid $owner_pid). Try again in a moment." >&2
        exit 1
      fi
    fi
    # pid file is missing — lock was just created, owner hasn't written it yet. Back off briefly.
    tries=$((tries + 1))
    if [ "$tries" -ge 3 ]; then
      echo "[track] lock contention; try again." >&2
      exit 1
    fi
    sleep 0.1
  done
  # Atomic PID write (tmp + mv) so a racing reader never sees a partial PID.
  echo "$$" > "$LOCK_DIR/pid.tmp"
  mv "$LOCK_DIR/pid.tmp" "$LOCK_DIR/pid"
  trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM
}

release_lock() {
  rm -rf "$LOCK_DIR" 2>/dev/null || true
  trap - EXIT INT TERM
}

# ---------- helpers ----------

# format_duration MINUTES -> "Xh Ym" or "Ym"
format_duration() {
  local total_min="$1"
  local h=$((total_min / 60))
  local m=$((total_min % 60))
  if [ "$h" -gt 0 ]; then
    printf '%dh %dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

# parse_ago "30m" | "2h" | "1h30m" | "90s" -> seconds (positive integer) on stdout.
# Exits 2 on malformed or non-positive input.
parse_ago() {
  local input="$1"
  if [ -z "$input" ]; then
    echo "[track] --ago requires a value (e.g., 30m, 2h, 1h30m)" >&2
    exit 2
  fi
  if ! [[ "$input" =~ ^([0-9]+h)?([0-9]+m)?([0-9]+s)?$ ]]; then
    echo "[track] --ago format: <Nh><Nm><Ns> (e.g., 30m, 2h, 1h30m, 90s) — got: '$input'" >&2
    exit 2
  fi
  local total=0
  [[ "$input" =~ ([0-9]+)h ]] && total=$((total + 10#${BASH_REMATCH[1]} * 3600))
  [[ "$input" =~ ([0-9]+)m ]] && total=$((total + 10#${BASH_REMATCH[1]} * 60))
  [[ "$input" =~ ([0-9]+)s ]] && total=$((total + 10#${BASH_REMATCH[1]}))
  if [ "$total" -le 0 ]; then
    echo "[track] --ago must be a positive duration (got: '$input')" >&2
    exit 2
  fi
  echo "$total"
}

# parse_at_today "14:30" -> UTC ISO timestamp "YYYY-MM-DDTHH:MM:SSZ" on stdout.
# Combines today's local date with HH:MM, converts to UTC.
# Exits 2 on malformed input.
parse_at_today() {
  local hhmm="$1"
  if ! [[ "$hhmm" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
    echo "[track] --at format: HH:MM (24-hour local time) — got: '$hhmm'" >&2
    exit 2
  fi
  local h="${BASH_REMATCH[1]}" m="${BASH_REMATCH[2]}"
  # Force base-10 to avoid octal interpretation of leading-zero values.
  h=$((10#$h)); m=$((10#$m))
  if [ "$h" -gt 23 ] || [ "$m" -gt 59 ]; then
    echo "[track] --at hour must be 0-23, minute 0-59 (got: '$hhmm')" >&2
    exit 2
  fi
  local today_local hhmmss epoch
  today_local=$(date +%Y-%m-%d)
  # Force seconds to 00 for deterministic parsing — BSD date would otherwise
  # fill missing SS with the current wall-clock seconds.
  hhmmss=$(printf '%02d:%02d:00' "$h" "$m")
  # Two-step: parse as LOCAL to epoch, then format epoch as UTC ISO. BSD `date -u -j`
  # would interpret the input as UTC, which is wrong — the user typed local HH:MM.
  epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$today_local $hhmmss" +%s 2>/dev/null) \
    || epoch=$(date -d "$today_local $hhmmss" +%s)
  date -u -r "$epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u -d "@$epoch" +"%Y-%m-%dT%H:%M:%SZ"
}

# resolve_timestamp "<at_val>" "<ago_val>" -> UTC ISO timestamp on stdout.
# Both empty -> now. Both set -> error (mutually exclusive). Otherwise dispatch.
resolve_timestamp() {
  local at_val="$1" ago_val="$2"
  if [ -n "$at_val" ] && [ -n "$ago_val" ]; then
    echo "[track] --at and --ago are mutually exclusive" >&2
    exit 2
  fi
  if [ -n "$at_val" ]; then
    parse_at_today "$at_val"
    return
  fi
  if [ -n "$ago_val" ]; then
    local secs target_epoch
    # Subshells don't inherit set -e by default, so propagate explicitly:
    # parse_ago's exit 2 only kills its own subshell, not this one.
    secs=$(parse_ago "$ago_val") || exit $?
    target_epoch=$(( $(date +%s) - secs ))
    date -u -r "$target_epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
      || date -u -d "@$target_epoch" +"%Y-%m-%dT%H:%M:%SZ"
    return
  fi
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# validate_client NAME -> exits 1 with hint if invalid or unregistered
validate_client() {
  local client="$1"
  if ! [[ "$client" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "[track] invalid client name: '$client' (letters, digits, dash, underscore only)" >&2
    exit 1
  fi
  if ! jq -e --arg c "$client" '.[$c]' "$TRACKER_DIR/clients.json" >/dev/null 2>&1; then
    cat >&2 <<EOF
[track] client '$client' is not registered.

Edit ~/.time-tracker/clients.json and add an entry, e.g.:
  {"$client": {"rate": 150}}

Quickstart (single line):
  echo '{"$client": {"rate": 150}}' > ~/.time-tracker/clients.json
EOF
    exit 1
  fi
}

# today_total_for_client CLIENT -> minutes (integer)
today_total_for_client() {
  local client="$1" today total
  today=$(date +"%Y-%m-%d")
  total=$(find "$TRACKER_DIR/entries" -maxdepth 1 -name '*.jsonl' -print0 2>/dev/null \
    | xargs -0 cat 2>/dev/null \
    | jq -s --arg today "$today" --arg client "$client" \
        'map(select((.start | fromdate | strflocaltime("%Y-%m-%d")) == $today and .client == $client))
         | map(.duration_min) | add // 0' \
    2>/dev/null || echo 0)
  echo "${total:-0}"
}

# ---------- commands ----------

cmd_start() {
  local client="" at_val="" ago_val=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --at)
        at_val="${2:-}"
        if [ -z "$at_val" ]; then
          echo "[track] --at requires a value (HH:MM)" >&2
          exit 2
        fi
        shift 2
        ;;
      --ago)
        ago_val="${2:-}"
        if [ -z "$ago_val" ]; then
          echo "[track] --ago requires a value (e.g., 30m)" >&2
          exit 2
        fi
        shift 2
        ;;
      *)
        if [ -n "$client" ]; then
          echo "[track] /track:start takes one client name (got extra arg: '$1')" >&2
          exit 2
        fi
        client="$1"
        shift
        ;;
    esac
  done
  if [ -z "$client" ]; then
    echo "[track] usage: /track:start <client> [--at HH:MM | --ago <duration>]" >&2
    exit 2
  fi
  preflight
  acquire_lock

  if [ -f "$TRACKER_DIR/active.json" ]; then
    local active_client active_hhmm
    active_client=$(jq -r '.client' "$TRACKER_DIR/active.json")
    active_hhmm=$(jq -r '.start | fromdate | strflocaltime("%H:%M")' "$TRACKER_DIR/active.json")
    release_lock
    cat >&2 <<EOF
[track] a timer is already running for '$active_client' since $active_hhmm.
Run /track:stop first, or remove ~/.time-tracker/active.json by hand to discard.
EOF
    exit 1
  fi

  validate_client "$client"

  local start_utc
  start_utc=$(resolve_timestamp "$at_val" "$ago_val")

  # Atomic write: tmp + mv.
  jq -nc --arg c "$client" --arg s "$start_utc" '{client: $c, start: $s}' > "$TRACKER_DIR/active.json.tmp"
  mv "$TRACKER_DIR/active.json.tmp" "$TRACKER_DIR/active.json"

  release_lock

  local hhmm
  hhmm=$(jq -nr --arg s "$start_utc" '$s | fromdate | strflocaltime("%H:%M")')
  echo "[track] started: $client @ $hhmm"
}

cmd_stop() {
  local at_val="" ago_val=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --at)
        at_val="${2:-}"
        if [ -z "$at_val" ]; then
          echo "[track] --at requires a value (HH:MM)" >&2
          exit 2
        fi
        shift 2
        ;;
      --ago)
        ago_val="${2:-}"
        if [ -z "$ago_val" ]; then
          echo "[track] --ago requires a value (e.g., 30m)" >&2
          exit 2
        fi
        shift 2
        ;;
      *)
        echo "[track] /track:stop unknown arg: '$1' (the note must come via stdin, not argv)" >&2
        exit 2
        ;;
    esac
  done

  preflight
  acquire_lock

  if [ ! -f "$TRACKER_DIR/active.json" ]; then
    release_lock
    echo "[track] no active timer." >&2
    exit 1
  fi

  # Note from stdin only (never argv) — eliminates shell metacharacter injection.
  local note=""
  if [ ! -t 0 ]; then
    note=$(cat)
  fi

  local client start end_utc duration_min bucket paused_at paused_sec_total
  client=$(jq -r '.client' "$TRACKER_DIR/active.json")
  start=$(jq -r '.start' "$TRACKER_DIR/active.json")
  paused_at=$(jq -r '.paused_at // ""' "$TRACKER_DIR/active.json")
  paused_sec_total=$(jq -r '.paused_sec_total // 0' "$TRACKER_DIR/active.json")

  # Refuse stop --at/--ago while paused: the open pause window would silently
  # be billed as worked time. Force the user to /track:resume first (which
  # also accepts --at/--ago) so the boundary between paused and worked is
  # explicit in the ledger.
  if [ -n "$paused_at" ] && { [ -n "$at_val" ] || [ -n "$ago_val" ]; }; then
    release_lock
    echo "[track] cannot /track:stop with --at/--ago while paused." >&2
    echo "[track] /track:resume first (also accepts --at/--ago), then /track:stop." >&2
    exit 1
  fi

  # If the timer is paused and the user did not supply an explicit end time,
  # use the pause point as the end so further idle time isn't counted.
  if [ -n "$paused_at" ]; then
    end_utc="$paused_at"
  else
    end_utc=$(resolve_timestamp "$at_val" "$ago_val")
  fi

  duration_min=$(jq -nr --arg s "$start" --arg e "$end_utc" --argjson p "$paused_sec_total" \
    '((($e | fromdate) - ($s | fromdate)) - $p) / 60 | floor')

  # Reject end < start BEFORE writing or committing, so active.json stays intact.
  if [ "$duration_min" -lt 0 ]; then
    local start_hhmm end_hhmm
    start_hhmm=$(jq -nr --arg s "$start" '$s | fromdate | strflocaltime("%H:%M")')
    end_hhmm=$(jq -nr --arg e "$end_utc" '$e | fromdate | strflocaltime("%H:%M")')
    release_lock
    echo "[track] end time $end_hhmm is before start time $start_hhmm (after subtracting $((paused_sec_total / 60))m of paused time); refusing." >&2
    echo "[track] active timer preserved — re-run /track:stop with a valid --at/--ago." >&2
    exit 1
  fi

  bucket=$(jq -nr --arg s "$start" '$s | fromdate | strflocaltime("%Y-%m")')

  local entries_file="$TRACKER_DIR/entries/${bucket}.jsonl"

  # Append JSONL entry.
  jq -nc \
    --arg c "$client" \
    --arg s "$start" \
    --arg e "$end_utc" \
    --arg n "$note" \
    --argjson d "$duration_min" \
    '{client:$c, start:$s, end:$e, duration_min:$d, note:$n}' \
    >> "$entries_file"

  # Stage only the file we just wrote — hand-edits to other entry files stay uncommitted.
  git -C "$TRACKER_DIR" add "entries/${bucket}.jsonl"

  # Commit with failure wrapper. On failure, preserve active.json so the user can re-stop after fixing.
  local commit_err
  commit_err=$(mktemp)
  if ! git -C "$TRACKER_DIR" commit -q -m "track: $client ${duration_min}m" 2>"$commit_err"; then
    local err_content
    err_content=$(cat "$commit_err")
    rm -f "$commit_err"
    release_lock
    cat >&2 <<EOF
[track] commit failed:
$err_content

Your session was appended to entries/${bucket}.jsonl but is NOT committed.
The active timer is preserved — fix the underlying issue and re-run /track:stop.

To recover by hand:
  cd ~/.time-tracker && git add entries/ && git commit -m 'manual recovery'

If the message above mentions "gpg failed to sign", your GPG agent needs to be unlocked.
Try:  gpg --sign /dev/null </dev/null   then re-run /track:stop.
EOF
    exit 1
  fi
  rm -f "$commit_err"

  rm -f "$TRACKER_DIR/active.json"
  release_lock

  local today_min today_human session_human break_min break_note=""
  today_min=$(today_total_for_client "$client")
  today_human=$(format_duration "$today_min")
  session_human=$(format_duration "$duration_min")
  break_min=$((paused_sec_total / 60))
  if [ "$break_min" -gt 0 ]; then
    break_note=" (excl. $(format_duration "$break_min") breaks)"
  fi
  echo "[track] stopped: $client · ${session_human}${break_note} · today's $client total: $today_human"
}

cmd_status() {
  preflight

  if [ -f "$TRACKER_DIR/active.json" ]; then
    local client start_utc paused_at paused_sec_total now_utc start_hhmm
    client=$(jq -r '.client' "$TRACKER_DIR/active.json")
    start_utc=$(jq -r '.start' "$TRACKER_DIR/active.json")
    paused_at=$(jq -r '.paused_at // ""' "$TRACKER_DIR/active.json")
    paused_sec_total=$(jq -r '.paused_sec_total // 0' "$TRACKER_DIR/active.json")
    now_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    start_hhmm=$(jq -nr --arg s "$start_utc" '$s | fromdate | strflocaltime("%H:%M")')

    if [ -n "$paused_at" ]; then
      # Paused: worked time excludes ALL breaks (including the open one's start point).
      local worked_min pause_now_min pause_hhmm worked_human pause_human
      worked_min=$(jq -nr --arg s "$start_utc" --arg e "$paused_at" --argjson p "$paused_sec_total" \
        '((($e | fromdate) - ($s | fromdate)) - $p) / 60 | floor')
      pause_now_min=$(jq -nr --arg p "$paused_at" --arg e "$now_utc" \
        '(($e | fromdate) - ($p | fromdate)) / 60 | floor')
      pause_hhmm=$(jq -nr --arg p "$paused_at" '$p | fromdate | strflocaltime("%H:%M")')
      worked_human=$(format_duration "$worked_min")
      pause_human=$(format_duration "$pause_now_min")
      echo "[track] paused: $client · worked $worked_human · paused for $pause_human (since $pause_hhmm local)"
    else
      local running_min running_human break_min break_note=""
      running_min=$(jq -nr --arg s "$start_utc" --arg e "$now_utc" --argjson p "$paused_sec_total" \
        '((($e | fromdate) - ($s | fromdate)) - $p) / 60 | floor')
      running_human=$(format_duration "$running_min")
      break_min=$((paused_sec_total / 60))
      if [ "$break_min" -gt 0 ]; then
        break_note=" (excl. $(format_duration "$break_min") breaks)"
      fi
      echo "[track] active: $client · running for ${running_human}${break_note} · started $start_hhmm local"
      if [ "$running_min" -gt 720 ]; then
        echo "[track] heads-up: timer has been running for $running_human. Did you forget to /track:stop?"
      fi
    fi
  else
    echo "[track] no active timer."
  fi

  # Today's completed totals per client.
  local today totals
  today=$(date +"%Y-%m-%d")
  totals=$(find "$TRACKER_DIR/entries" -maxdepth 1 -name '*.jsonl' -print0 2>/dev/null \
    | xargs -0 cat 2>/dev/null \
    | jq -s -r --arg today "$today" \
        'map(select((.start | fromdate | strflocaltime("%Y-%m-%d")) == $today))
         | group_by(.client)
         | map({client: .[0].client, total_min: (map(.duration_min) | add)})
         | .[]
         | "  \(.client): \(.total_min)m"' \
    2>/dev/null || true)

  if [ -n "$totals" ]; then
    echo "today completed sessions:"
    echo "$totals"
  else
    echo "today completed sessions: (none)"
  fi
}

cmd_report() {
  preflight

  local period="week" month="" filter_client=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --week)
        period="week"
        shift
        ;;
      --month)
        period="month"
        month="${2:-}"
        if ! [[ "$month" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
          echo "[track] --month requires YYYY-MM (got: '$month')" >&2
          exit 2
        fi
        shift 2
        ;;
      --client)
        filter_client="${2:-}"
        if ! [[ "$filter_client" =~ ^[a-zA-Z0-9_-]+$ ]]; then
          echo "[track] --client requires a name (letters, digits, dash, underscore)" >&2
          exit 2
        fi
        shift 2
        ;;
      *)
        echo "[track] unknown report flag: '$1'. Use --week | --month YYYY-MM | --client <name>" >&2
        exit 2
        ;;
    esac
  done

  local today week_start
  today=$(date +"%Y-%m-%d")
  # Portable date math: BSD (-v) first, GNU (-d) fallback.
  week_start=$(date -v-6d +"%Y-%m-%d" 2>/dev/null || date -d "6 days ago" +"%Y-%m-%d")

  find "$TRACKER_DIR/entries" -maxdepth 1 -name '*.jsonl' -print0 2>/dev/null \
    | xargs -0 cat 2>/dev/null \
    | jq -s -r \
        --slurpfile clients_arr "$TRACKER_DIR/clients.json" \
        --arg period "$period" \
        --arg month "$month" \
        --arg week_start "$week_start" \
        --arg today "$today" \
        --arg filter_client "$filter_client" \
      '
      def format_duration_str(m):
        (m / 60 | floor) as $h
        | (m - ($h * 60)) as $r
        | if $h > 0 then "\($h)h \($r)m" else "\($r)m" end;
      def in_period:
        if $period == "month" then
          (.start | fromdate | strflocaltime("%Y-%m")) == $month
        else
          ((.start | fromdate | strflocaltime("%Y-%m-%d")) >= $week_start)
          and ((.start | fromdate | strflocaltime("%Y-%m-%d")) <= $today)
        end;
      def matches_client:
        $filter_client == "" or .client == $filter_client;
      def round2:
        . * 100 | round / 100;

      $clients_arr[0] as $rates
      | map(select(in_period and matches_client))
      | sort_by(.start) as $rows
      | if ($rows | length) == 0 then
          if $period == "month" then "(no entries for \($month))" else "(no entries in the last 7 days)" end
        else
          ($rows | map((.duration_min / 60) * ($rates[.client].rate // 0)) | add) as $total_dollars
          | ($rows | map(.duration_min) | add) as $total_min
          | ([
              "| Date       | Client | Duration | Rate     | Amount   | Note |",
              "|------------|--------|----------|----------|----------|------|"
            ] + ($rows | map(
                . as $e
                | ($rates[$e.client].rate // 0) as $rate
                | (($e.duration_min / 60) * $rate) as $amount
                | "| \($e.start | fromdate | strflocaltime("%Y-%m-%d")) | \($e.client) | \(format_duration_str($e.duration_min)) | $\($rate)/hr | $\($amount | round2) | \($e.note // "" | gsub("\n"; " \\u23ce ")) |"
              )) + [
              "",
              "**Total: $\($total_dollars | round2) USD** — \($total_min)m total (\(($total_min / 60) | round2)h)"
            ])
          | .[]
        end
      '
}

cmd_pause() {
  local at_val="" ago_val=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --at)
        at_val="${2:-}"
        if [ -z "$at_val" ]; then
          echo "[track] --at requires a value (HH:MM)" >&2
          exit 2
        fi
        shift 2
        ;;
      --ago)
        ago_val="${2:-}"
        if [ -z "$ago_val" ]; then
          echo "[track] --ago requires a value (e.g., 30m)" >&2
          exit 2
        fi
        shift 2
        ;;
      *)
        echo "[track] /track:pause takes no positional args (got: '$1')" >&2
        exit 2
        ;;
    esac
  done

  preflight
  acquire_lock

  if [ ! -f "$TRACKER_DIR/active.json" ]; then
    release_lock
    echo "[track] no active timer." >&2
    exit 1
  fi

  local client start_utc existing_pause paused_sec_total
  client=$(jq -r '.client' "$TRACKER_DIR/active.json")
  start_utc=$(jq -r '.start' "$TRACKER_DIR/active.json")
  existing_pause=$(jq -r '.paused_at // ""' "$TRACKER_DIR/active.json")
  paused_sec_total=$(jq -r '.paused_sec_total // 0' "$TRACKER_DIR/active.json")

  if [ -n "$existing_pause" ]; then
    local pause_hhmm
    pause_hhmm=$(jq -nr --arg p "$existing_pause" '$p | fromdate | strflocaltime("%H:%M")')
    release_lock
    echo "[track] timer is already paused since $pause_hhmm." >&2
    exit 1
  fi

  local pause_ts delta
  pause_ts=$(resolve_timestamp "$at_val" "$ago_val")
  delta=$(jq -nr --arg s "$start_utc" --arg p "$pause_ts" '($p | fromdate) - ($s | fromdate)')
  if [ "$delta" -lt 0 ]; then
    local start_hhmm pause_hhmm
    start_hhmm=$(jq -nr --arg s "$start_utc" '$s | fromdate | strflocaltime("%H:%M")')
    pause_hhmm=$(jq -nr --arg p "$pause_ts" '$p | fromdate | strflocaltime("%H:%M")')
    release_lock
    echo "[track] pause time $pause_hhmm is before start time $start_hhmm; refusing." >&2
    exit 2
  fi

  jq -nc \
    --arg c "$client" \
    --arg s "$start_utc" \
    --arg p "$pause_ts" \
    --argjson pt "$paused_sec_total" \
    '{client:$c, start:$s, paused_at:$p, paused_sec_total:$pt}' \
    > "$TRACKER_DIR/active.json.tmp"
  mv "$TRACKER_DIR/active.json.tmp" "$TRACKER_DIR/active.json"

  release_lock

  local worked_min worked_human pause_hhmm
  worked_min=$(jq -nr --arg s "$start_utc" --arg p "$pause_ts" --argjson pt "$paused_sec_total" \
    '((($p | fromdate) - ($s | fromdate)) - $pt) / 60 | floor')
  worked_human=$(format_duration "$worked_min")
  pause_hhmm=$(jq -nr --arg p "$pause_ts" '$p | fromdate | strflocaltime("%H:%M")')
  echo "[track] paused: $client · worked $worked_human so far · paused at $pause_hhmm"
}

cmd_resume() {
  local at_val="" ago_val=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --at)
        at_val="${2:-}"
        if [ -z "$at_val" ]; then
          echo "[track] --at requires a value (HH:MM)" >&2
          exit 2
        fi
        shift 2
        ;;
      --ago)
        ago_val="${2:-}"
        if [ -z "$ago_val" ]; then
          echo "[track] --ago requires a value (e.g., 30m)" >&2
          exit 2
        fi
        shift 2
        ;;
      *)
        echo "[track] /track:resume takes no positional args (got: '$1')" >&2
        exit 2
        ;;
    esac
  done

  preflight
  acquire_lock

  if [ ! -f "$TRACKER_DIR/active.json" ]; then
    release_lock
    echo "[track] no active timer." >&2
    exit 1
  fi

  local client start_utc paused_at paused_sec_total
  client=$(jq -r '.client' "$TRACKER_DIR/active.json")
  start_utc=$(jq -r '.start' "$TRACKER_DIR/active.json")
  paused_at=$(jq -r '.paused_at // ""' "$TRACKER_DIR/active.json")
  paused_sec_total=$(jq -r '.paused_sec_total // 0' "$TRACKER_DIR/active.json")

  if [ -z "$paused_at" ]; then
    release_lock
    echo "[track] timer is not paused." >&2
    exit 1
  fi

  local resume_ts delta new_total
  resume_ts=$(resolve_timestamp "$at_val" "$ago_val")
  delta=$(jq -nr --arg p "$paused_at" --arg r "$resume_ts" '($r | fromdate) - ($p | fromdate)')
  if [ "$delta" -lt 0 ]; then
    local pause_hhmm resume_hhmm
    pause_hhmm=$(jq -nr --arg p "$paused_at" '$p | fromdate | strflocaltime("%H:%M")')
    resume_hhmm=$(jq -nr --arg r "$resume_ts" '$r | fromdate | strflocaltime("%H:%M")')
    release_lock
    echo "[track] resume time $resume_hhmm is before pause time $pause_hhmm; refusing." >&2
    exit 2
  fi
  new_total=$((paused_sec_total + delta))

  jq -nc \
    --arg c "$client" \
    --arg s "$start_utc" \
    --argjson pt "$new_total" \
    '{client:$c, start:$s, paused_sec_total:$pt}' \
    > "$TRACKER_DIR/active.json.tmp"
  mv "$TRACKER_DIR/active.json.tmp" "$TRACKER_DIR/active.json"

  release_lock

  local segment_min segment_human total_human
  segment_min=$((delta / 60))
  segment_human=$(format_duration "$segment_min")
  total_human=$(format_duration "$((new_total / 60))")
  echo "[track] resumed: $client · paused for $segment_human · total paused $total_human"
}

# ---------- main ----------

main() {
  local sub="${1:-}"
  if [ -z "$sub" ]; then
    cat >&2 <<'EOF'
usage: track.sh {start|stop|pause|resume|status|report} [args...]

  start <client> [--at HH:MM | --ago <dur>]
                                      Start a timer for the named client.
                                      --at backdates to today's HH:MM (local).
                                      --ago backdates by a duration (e.g., 30m, 2h, 1h30m).
  stop [--at HH:MM | --ago <dur>]     Stop the active timer; reads note from stdin.
                                      --at/--ago set the end time the same way as start.
                                      If paused, end defaults to the pause point.
                                      Refuses end < start.
  pause [--at HH:MM | --ago <dur>]    Pause the active timer; paused time is excluded
                                      from the final session duration.
  resume [--at HH:MM | --ago <dur>]   Resume a paused timer.
  status                              Show active timer + today's totals.
  report [--week|--month YYYY-MM] [--client <name>]
                                      Print invoice-ready markdown rollup.
EOF
    exit 2
  fi
  shift
  case "$sub" in
    start)  cmd_start  "$@" ;;
    stop)   cmd_stop   "$@" ;;
    pause)  cmd_pause  "$@" ;;
    resume) cmd_resume "$@" ;;
    status) cmd_status "$@" ;;
    report) cmd_report "$@" ;;
    *)
      echo "[track] unknown subcommand: '$sub' (use start|stop|pause|resume|status|report)" >&2
      exit 2
      ;;
  esac
}

main "$@"
