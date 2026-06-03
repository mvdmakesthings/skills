#!/usr/bin/env bats

# cmd_start and cmd_stop happy path + common error paths.

setup() {
  TMPHOME=$(mktemp -d)
  export HOME="$TMPHOME"
  export TRACK_DIR_OVERRIDE="$TMPHOME/.time-tracker"
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  SCRIPT="${TRACK_SH:-${BATS_TEST_DIRNAME}/../../../plugins/track/bin/track.sh}"

  bash "$SCRIPT" status > /dev/null
  echo '{"acme": {"rate": 150}, "globex": {"rate": 200}}' > "$TRACK_DIR_OVERRIDE/clients.json"
}

teardown() {
  [ -n "${TMPHOME:-}" ] && rm -rf "$TMPHOME"
}

@test "start: usage error when no client given" {
  run bash "$SCRIPT" start
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: /track:start"* ]]
}

@test "start: errors with paste hint for unregistered client" {
  run bash "$SCRIPT" start unknown-co
  [ "$status" -eq 1 ]
  [[ "$output" == *"client 'unknown-co' is not registered"* ]]
  [[ "$output" == *"echo '{\"unknown-co\": {\"rate\": 150}}'"* ]]
}

@test "start: rejects invalid characters in client name" {
  run bash "$SCRIPT" start "bad;name"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid client name"* ]]
}

@test "start: writes active.json atomically" {
  run bash "$SCRIPT" start acme
  [ "$status" -eq 0 ]
  [ -f "$TRACK_DIR_OVERRIDE/active.json" ]
  [ ! -f "$TRACK_DIR_OVERRIDE/active.json.tmp" ]
  run jq -r '.client' "$TRACK_DIR_OVERRIDE/active.json"
  [ "$output" = "acme" ]
  run jq -r '.start | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$TRACK_DIR_OVERRIDE/active.json"
  [ "$output" = "true" ]
}

@test "start: refuses to start a second timer while one is running" {
  bash "$SCRIPT" start acme > /dev/null
  run bash "$SCRIPT" start globex
  [ "$status" -eq 1 ]
  [[ "$output" == *"timer is already running for 'acme'"* ]]
  # active.json must remain acme, untouched.
  run jq -r '.client' "$TRACK_DIR_OVERRIDE/active.json"
  [ "$output" = "acme" ]
}

@test "stop: errors when no active timer" {
  run bash "$SCRIPT" stop
  [ "$status" -eq 1 ]
  [[ "$output" == *"no active timer"* ]]
}

@test "stop: appends JSONL entry and commits, then removes active.json" {
  bash "$SCRIPT" start acme > /dev/null
  run bash "$SCRIPT" stop
  [ "$status" -eq 0 ]
  [ ! -f "$TRACK_DIR_OVERRIDE/active.json" ]

  # Exactly one entry file should exist.
  shopt -s nullglob
  entries=("$TRACK_DIR_OVERRIDE"/entries/*.jsonl)
  shopt -u nullglob
  [ "${#entries[@]}" -eq 1 ]

  # The entry has the expected shape.
  run jq -r '.client' "${entries[0]}"
  [ "$output" = "acme" ]

  # Commit landed.
  run git -C "$TRACK_DIR_OVERRIDE" log --oneline
  [[ "$output" == *"track: acme"* ]]
}

@test "stop: only stages the entries file we just wrote, not other dirty files" {
  bash "$SCRIPT" start acme > /dev/null
  # Plant a dirty file the dispatcher must NOT auto-commit.
  echo "unrelated change" > "$TRACK_DIR_OVERRIDE/clients.json.scratch"
  git -C "$TRACK_DIR_OVERRIDE" add -N "$TRACK_DIR_OVERRIDE/clients.json.scratch"

  run bash "$SCRIPT" stop
  [ "$status" -eq 0 ]

  # The scratch file is untracked / not staged in the new commit.
  run git -C "$TRACK_DIR_OVERRIDE" log -1 --name-only --format=
  [[ "$output" != *"clients.json.scratch"* ]]
}

# ---------- backdating: --at and --ago ----------

@test "start: --at HH:MM stores today's local HH:MM (round-trips via jq strflocaltime)" {
  run bash "$SCRIPT" start --at 09:00 acme
  [ "$status" -eq 0 ]
  # Read back the stored UTC and convert to local; must equal 09:00.
  run jq -r '.start | fromdate | strflocaltime("%H:%M")' "$TRACK_DIR_OVERRIDE/active.json"
  [ "$output" = "09:00" ]
}

@test "start: --ago 30m stores a start ~30 min before now (±5s)" {
  local before
  before=$(date +%s)
  run bash "$SCRIPT" start --ago 30m acme
  [ "$status" -eq 0 ]
  local stored diff
  stored=$(jq -r '.start | fromdate' "$TRACK_DIR_OVERRIDE/active.json")
  diff=$((before - stored))
  [ "$diff" -ge 1795 ] && [ "$diff" -le 1805 ]
}

@test "start: --at and --ago together is rejected" {
  run bash "$SCRIPT" start --at 10:00 --ago 30m acme
  [ "$status" -eq 2 ]
  [[ "$output" == *"mutually exclusive"* ]]
  [ ! -f "$TRACK_DIR_OVERRIDE/active.json" ]
}

@test "start: malformed --at exits 2 (cases: 25:00, 14:99, abc)" {
  for bad_v in "25:00" "14:99" "abc"; do
    run bash "$SCRIPT" start --at "$bad_v" acme
    [ "$status" -eq 2 ]
    [ ! -f "$TRACK_DIR_OVERRIDE/active.json" ]
  done
}

@test "start: malformed --ago exits 2 (cases: 30x, abc, 0m, empty)" {
  # parse_ago must reject these; subshell exit must propagate through resolve_timestamp.
  for bad_v in "30x" "abc" "0m" ""; do
    run bash "$SCRIPT" start --ago "$bad_v" acme
    [ "$status" -eq 2 ]
    [ ! -f "$TRACK_DIR_OVERRIDE/active.json" ]
  done
}

@test "stop: --at HH:MM sets the entry's end and computes duration from it" {
  # Start 2h ago; stop --at = 1h ago. Expected duration ~60m.
  bash "$SCRIPT" start --ago 2h acme > /dev/null
  local one_h_ago
  one_h_ago=$(date -v-1H +%H:%M 2>/dev/null || date -d "1 hour ago" +%H:%M)
  run bash "$SCRIPT" stop --at "$one_h_ago"
  [ "$status" -eq 0 ]
  shopt -s nullglob
  local entries=("$TRACK_DIR_OVERRIDE"/entries/*.jsonl)
  shopt -u nullglob
  [ "${#entries[@]}" -eq 1 ]
  local dur
  dur=$(jq -r '.duration_min' "${entries[0]}")
  [ "$dur" -ge 58 ] && [ "$dur" -le 62 ]
}

@test "stop: end before start is refused; active timer preserved; no entry written" {
  bash "$SCRIPT" start --ago 1m acme > /dev/null
  run bash "$SCRIPT" stop --ago 10m
  [ "$status" -eq 1 ]
  [[ "$output" == *"before start time"* ]]
  [ -f "$TRACK_DIR_OVERRIDE/active.json" ]
  shopt -s nullglob
  local entries=("$TRACK_DIR_OVERRIDE"/entries/*.jsonl)
  shopt -u nullglob
  [ "${#entries[@]}" -eq 0 ]
}

@test "stop: zero-minute session (end == start within rounding) is accepted" {
  # Start --ago 30m; immediately stop --ago 30m. Floor of tiny positive delta = 0.
  bash "$SCRIPT" start --ago 30m acme > /dev/null
  run bash "$SCRIPT" stop --ago 30m
  [ "$status" -eq 0 ]
  shopt -s nullglob
  local entries=("$TRACK_DIR_OVERRIDE"/entries/*.jsonl)
  shopt -u nullglob
  [ "${#entries[@]}" -eq 1 ]
  local dur
  dur=$(jq -r '.duration_min' "${entries[0]}")
  [ "$dur" -eq 0 ]
}

@test "stop: unknown positional arg is rejected (note belongs on stdin, not argv)" {
  bash "$SCRIPT" start acme > /dev/null
  run bash "$SCRIPT" stop "spurious-arg"
  [ "$status" -eq 2 ]
  [[ "$output" == *"note must come via stdin"* ]]
}
