#!/usr/bin/env bats

# cmd_start and cmd_stop happy path + common error paths.

setup() {
  TMPHOME=$(mktemp -d)
  export HOME="$TMPHOME"
  export TRACK_DIR_OVERRIDE="$TMPHOME/.time-tracker"
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  SCRIPT="${BATS_TEST_DIRNAME}/../bin/track.sh"

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
