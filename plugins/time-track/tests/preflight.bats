#!/usr/bin/env bats

# preflight() behaviors: auto-init, git config validation, jq version check, clients.json bootstrap.

setup() {
  TMPHOME=$(mktemp -d)
  export HOME="$TMPHOME"
  export TRACK_DIR_OVERRIDE="$TMPHOME/.time-tracker"
  SCRIPT="${BATS_TEST_DIRNAME}/../bin/track.sh"
}

teardown() {
  [ -n "${TMPHOME:-}" ] && rm -rf "$TMPHOME"
}

@test "preflight: errors with hint when git user.email is missing" {
  # HOME is fresh, no global git config
  run bash "$SCRIPT" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"git user.email is not configured"* ]]
  [[ "$output" == *'git config --global user.email'* ]]
}

@test "preflight: errors with hint when git user.name is missing but email is set" {
  git config --global user.email "test@example.com"
  # user.name still missing
  run bash "$SCRIPT" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"git user.name is not configured"* ]]
}

@test "preflight: auto-creates ~/.time-tracker/ with .git dir" {
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  [ ! -d "$TRACK_DIR_OVERRIDE" ]
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  [ -d "$TRACK_DIR_OVERRIDE/.git" ]
}

@test "preflight: auto-creates clients.json as {} on first run" {
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  [ -f "$TRACK_DIR_OVERRIDE/clients.json" ]
  run jq -r '. | type' "$TRACK_DIR_OVERRIDE/clients.json"
  [ "$output" = "object" ]
}

@test "preflight: bootstraps .gitignore with active.json and .lock/ on first run" {
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  [ -f "$TRACK_DIR_OVERRIDE/.gitignore" ]
  grep -q "active.json" "$TRACK_DIR_OVERRIDE/.gitignore"
  grep -q ".lock/" "$TRACK_DIR_OVERRIDE/.gitignore"
}

@test "preflight: errors with install hint when jq is unavailable" {
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  # Build a PATH that excludes jq.
  mkdir -p "$TMPHOME/no-jq-bin"
  # Symlink all common tools we need but NOT jq
  for tool in bash git mktemp date mkdir cat rm mv echo cp ls find xargs sed printf; do
    real=$(command -v "$tool" 2>/dev/null || true)
    [ -n "$real" ] && ln -s "$real" "$TMPHOME/no-jq-bin/$tool"
  done
  PATH="$TMPHOME/no-jq-bin" run bash "$SCRIPT" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required"* ]]
  [[ "$output" == *"brew install jq"* ]]
}
