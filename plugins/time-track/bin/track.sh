#!/usr/bin/env bash
# track.sh — billable-hours dispatcher for the `track` Claude Code plugin.
#
# Authoritative spec:
#   ~/.gstack/projects/mvdmakesthings-claude-marketplace/michaelvandyke-main-design-20260524-174009.md
#
# Subcommands: start | stop | status | report
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
  local client="${1:-}"
  if [ -z "$client" ]; then
    echo "[track] usage: /track:start <client>" >&2
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

  local now_utc
  now_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Atomic write: tmp + mv.
  jq -nc --arg c "$client" --arg s "$now_utc" '{client: $c, start: $s}' > "$TRACKER_DIR/active.json.tmp"
  mv "$TRACKER_DIR/active.json.tmp" "$TRACKER_DIR/active.json"

  release_lock

  local hhmm
  hhmm=$(date +"%H:%M")
  echo "[track] started: $client @ $hhmm"
}

cmd_stop() {
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

  local client start now_utc duration_min bucket
  client=$(jq -r '.client' "$TRACKER_DIR/active.json")
  start=$(jq -r '.start' "$TRACKER_DIR/active.json")
  now_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  duration_min=$(jq -nr --arg s "$start" --arg e "$now_utc" '(($e | fromdate) - ($s | fromdate)) / 60 | floor')
  bucket=$(jq -nr --arg s "$start" '$s | fromdate | strflocaltime("%Y-%m")')

  local entries_file="$TRACKER_DIR/entries/${bucket}.jsonl"

  # Append JSONL entry.
  jq -nc \
    --arg c "$client" \
    --arg s "$start" \
    --arg e "$now_utc" \
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

  local today_min today_human session_human
  today_min=$(today_total_for_client "$client")
  today_human=$(format_duration "$today_min")
  session_human=$(format_duration "$duration_min")
  echo "[track] stopped: $client · $session_human · today's $client total: $today_human"
}

cmd_status() {
  preflight

  if [ -f "$TRACKER_DIR/active.json" ]; then
    local client start_utc running_min start_hhmm running_human now_utc
    client=$(jq -r '.client' "$TRACKER_DIR/active.json")
    start_utc=$(jq -r '.start' "$TRACKER_DIR/active.json")
    now_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    running_min=$(jq -nr --arg s "$start_utc" --arg e "$now_utc" '(($e | fromdate) - ($s | fromdate)) / 60 | floor')
    start_hhmm=$(jq -nr --arg s "$start_utc" '$s | fromdate | strflocaltime("%H:%M")')
    running_human=$(format_duration "$running_min")
    echo "[track] active: $client · running for $running_human · started $start_hhmm local"
    if [ "$running_min" -gt 720 ]; then
      echo "[track] heads-up: timer has been running for $running_human. Did you forget to /track:stop?"
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

# ---------- main ----------

main() {
  local sub="${1:-}"
  if [ -z "$sub" ]; then
    cat >&2 <<'EOF'
usage: track.sh {start|stop|status|report} [args...]

  start <client>                      Start a timer for the named client.
  stop                                Stop the active timer; reads note from stdin.
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
    status) cmd_status "$@" ;;
    report) cmd_report "$@" ;;
    *)
      echo "[track] unknown subcommand: '$sub' (use start|stop|status|report)" >&2
      exit 2
      ;;
  esac
}

main "$@"
