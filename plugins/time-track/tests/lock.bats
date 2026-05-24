#!/usr/bin/env bats

# acquire_lock behaviors: mkdir-based atomic lock, stale-PID reaping, live-PID honored, trap cleanup.

setup() {
  TMPHOME=$(mktemp -d)
  export HOME="$TMPHOME"
  export TRACK_DIR_OVERRIDE="$TMPHOME/.time-tracker"
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  SCRIPT="${BATS_TEST_DIRNAME}/../bin/track.sh"

  # Bootstrap the tracker so we don't trigger first-run on each test.
  bash "$SCRIPT" status > /dev/null
  echo '{"acme": {"rate": 100}}' > "$TRACK_DIR_OVERRIDE/clients.json"
}

teardown() {
  [ -n "${TMPHOME:-}" ] && rm -rf "$TMPHOME"
}

@test "lock: reaps stale lock with dead PID" {
  # Get a guaranteed-dead PID by spawning + waiting for it.
  ( sleep 0.01 ) &
  DEAD_PID=$!
  wait "$DEAD_PID" 2>/dev/null || true
  # Confirm the PID is actually dead before we proceed.
  ! kill -0 "$DEAD_PID" 2>/dev/null

  # Plant a stale lock owned by the dead PID.
  mkdir -p "$TRACK_DIR_OVERRIDE/.lock"
  echo "$DEAD_PID" > "$TRACK_DIR_OVERRIDE/.lock/pid"

  # Lock should be reaped and the command should succeed.
  run bash "$SCRIPT" start acme
  [ "$status" -eq 0 ]
  [ -f "$TRACK_DIR_OVERRIDE/active.json" ]
  [ ! -d "$TRACK_DIR_OVERRIDE/.lock" ]
}

@test "lock: rejects when owner PID is alive" {
  # Use the bats parent shell's PID — it's alive while the test runs.
  LIVE_PID=$$

  mkdir -p "$TRACK_DIR_OVERRIDE/.lock"
  echo "$LIVE_PID" > "$TRACK_DIR_OVERRIDE/.lock/pid"

  run bash "$SCRIPT" start acme
  [ "$status" -eq 1 ]
  [[ "$output" == *"another track command is running"* ]]
  [[ "$output" == *"(pid $LIVE_PID)"* ]]

  # Lock not reaped: still present with the same PID.
  [ -d "$TRACK_DIR_OVERRIDE/.lock" ]
  [ "$(cat "$TRACK_DIR_OVERRIDE/.lock/pid")" = "$LIVE_PID" ]

  # Clean up by hand for the next test.
  rm -rf "$TRACK_DIR_OVERRIDE/.lock"
}

@test "lock: is released after successful command (trap cleanup)" {
  run bash "$SCRIPT" start acme
  [ "$status" -eq 0 ]
  [ ! -d "$TRACK_DIR_OVERRIDE/.lock" ]
}

@test "lock: is released after errored command (trap cleanup)" {
  # Start a timer, then try to start another — second command errors but must release.
  bash "$SCRIPT" start acme > /dev/null
  run bash "$SCRIPT" start acme
  [ "$status" -eq 1 ]
  [[ "$output" == *"timer is already running"* ]]
  [ ! -d "$TRACK_DIR_OVERRIDE/.lock" ]
}
