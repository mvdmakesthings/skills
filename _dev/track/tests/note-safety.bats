#!/usr/bin/env bats

# /track:stop reads the note from stdin. Shell metacharacters in the note
# must NEVER be interpreted as code by the dispatcher.

setup() {
  TMPHOME=$(mktemp -d)
  export HOME="$TMPHOME"
  export TRACK_DIR_OVERRIDE="$TMPHOME/.time-tracker"
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  SCRIPT="${BATS_TEST_DIRNAME}/../../../plugins/track/bin/track.sh"

  bash "$SCRIPT" status > /dev/null
  echo '{"acme": {"rate": 100}}' > "$TRACK_DIR_OVERRIDE/clients.json"
}

teardown() {
  [ -n "${TMPHOME:-}" ] && rm -rf "$TMPHOME"
}

# Helper: start a timer, then stop with the given note (piped through stdin).
# Returns the note value recorded in the latest entry.
recorded_note() {
  bash "$SCRIPT" start acme > /dev/null
  printf '%s' "$1" | bash "$SCRIPT" stop > /dev/null

  # Pick the most-recently-modified entries file. Avoid bash 4+ negative indices
  # so this runs on macOS's stock bash 3.2.
  local latest
  latest=$(ls -t "$TRACK_DIR_OVERRIDE"/entries/*.jsonl 2>/dev/null | head -n1)
  tail -n1 "$latest" | jq -r '.note'
}

@test "note-safety: semicolons are stored verbatim, not chained" {
  result=$(recorded_note 'wrote design; rm -rf /tmp/should-not-exist')
  [ "$result" = "wrote design; rm -rf /tmp/should-not-exist" ]
  # Confirm the destructive command did not run (the path exists because we never had it,
  # but the real test is the note round-trips verbatim).
}

@test "note-safety: command substitution \$(...) is stored verbatim, not executed" {
  result=$(recorded_note 'ran $(whoami) and $(date +%Y)')
  [ "$result" = 'ran $(whoami) and $(date +%Y)' ]
}

@test "note-safety: backticks are stored verbatim, not executed" {
  result=$(recorded_note 'ran `whoami` and `ls /`')
  [ "$result" = 'ran `whoami` and `ls /`' ]
}

@test "note-safety: empty note is stored as empty string when no stdin" {
  bash "$SCRIPT" start acme > /dev/null
  # No stdin pipe — note should be empty.
  bash "$SCRIPT" stop < /dev/null > /dev/null
  local latest
  latest=$(ls -t "$TRACK_DIR_OVERRIDE"/entries/*.jsonl 2>/dev/null | head -n1)
  # Only one entry in this file; tail+jq the single line.
  result=$(tail -n1 "$latest" | jq -r '.note')
  [ "$result" = "" ]
}

@test "note-safety: multi-line note preserves newlines" {
  result=$(recorded_note $'line one\nline two\nline three')
  [ "$result" = $'line one\nline two\nline three' ]
}
