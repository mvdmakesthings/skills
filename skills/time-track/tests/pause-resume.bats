#!/usr/bin/env bats

# cmd_pause and cmd_resume happy paths + error cases.
# Verifies that paused time is subtracted from the final session duration
# in the JSONL entry written by /track:stop.

setup() {
  TMPHOME=$(mktemp -d)
  export HOME="$TMPHOME"
  export TRACK_DIR_OVERRIDE="$TMPHOME/.time-tracker"
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  SCRIPT="${BATS_TEST_DIRNAME}/../bin/track.sh"

  bash "$SCRIPT" status > /dev/null
  echo '{"acme": {"rate": 150}}' > "$TRACK_DIR_OVERRIDE/clients.json"
}

teardown() {
  [ -n "${TMPHOME:-}" ] && rm -rf "$TMPHOME"
}

# Read the single JSONL entry's duration_min. Asserts exactly one entry exists.
_entry_duration() {
  shopt -s nullglob
  local entries=("$TRACK_DIR_OVERRIDE"/entries/*.jsonl)
  shopt -u nullglob
  [ "${#entries[@]}" -eq 1 ] || { echo "expected 1 entry, got ${#entries[@]}" >&2; return 1; }
  jq -r '.duration_min' "${entries[0]}"
}

# ---------- pause: error cases ----------

@test "pause: errors when no active timer" {
  run bash "$SCRIPT" pause
  [ "$status" -eq 1 ]
  [[ "$output" == *"no active timer"* ]]
}

@test "pause: errors when already paused" {
  bash "$SCRIPT" start --ago 30m acme > /dev/null
  bash "$SCRIPT" pause > /dev/null
  run bash "$SCRIPT" pause
  [ "$status" -eq 1 ]
  [[ "$output" == *"already paused"* ]]
}

@test "pause: rejects positional args" {
  bash "$SCRIPT" start acme > /dev/null
  run bash "$SCRIPT" pause "some-note"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no positional args"* ]]
}

@test "pause: --at before start time is rejected" {
  # Start --ago 1m, then pause --ago 10m → pause is 9m before start.
  bash "$SCRIPT" start --ago 1m acme > /dev/null
  run bash "$SCRIPT" pause --ago 10m
  [ "$status" -eq 2 ]
  [[ "$output" == *"before start time"* ]]
  # active.json should remain unchanged (not paused).
  run jq -r '.paused_at // "none"' "$TRACK_DIR_OVERRIDE/active.json"
  [ "$output" = "none" ]
}

# ---------- resume: error cases ----------

@test "resume: errors when no active timer" {
  run bash "$SCRIPT" resume
  [ "$status" -eq 1 ]
  [[ "$output" == *"no active timer"* ]]
}

@test "resume: errors when timer is not paused" {
  bash "$SCRIPT" start acme > /dev/null
  run bash "$SCRIPT" resume
  [ "$status" -eq 1 ]
  [[ "$output" == *"not paused"* ]]
}

@test "resume: rejects positional args" {
  bash "$SCRIPT" start --ago 30m acme > /dev/null
  bash "$SCRIPT" pause > /dev/null
  run bash "$SCRIPT" resume "some-note"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no positional args"* ]]
}

@test "resume: --at before pause time is rejected" {
  # Start --ago 2h, pause --ago 30m → pause was 30m ago.
  # Then resume --ago 1h → resume is 1h ago, i.e. 30m BEFORE pause. Reject.
  bash "$SCRIPT" start --ago 2h acme > /dev/null
  bash "$SCRIPT" pause --ago 30m > /dev/null
  run bash "$SCRIPT" resume --ago 1h
  [ "$status" -eq 2 ]
  [[ "$output" == *"before pause time"* ]]
  # Timer should still be paused.
  run jq -r '.paused_at // "none"' "$TRACK_DIR_OVERRIDE/active.json"
  [[ "$output" != "none" ]]
}

# ---------- happy paths ----------

@test "pause then resume then stop: ONE entry, paused interval excluded" {
  # Start 60m ago. Pause 40m ago. Resume 20m ago. Stop now.
  # Worked: 60 - 20(paused) = 40m. Entry duration ≈ 40m.
  bash "$SCRIPT" start --ago 60m acme > /dev/null
  bash "$SCRIPT" pause --ago 40m > /dev/null
  bash "$SCRIPT" resume --ago 20m > /dev/null
  run bash "$SCRIPT" stop
  [ "$status" -eq 0 ]
  local dur
  dur=$(_entry_duration)
  [ "$dur" -ge 38 ] && [ "$dur" -le 42 ]
  # Success line mentions break time.
  [[ "$output" == *"excl."* ]]
  [[ "$output" == *"breaks"* ]]
}

@test "stop --at/--ago while paused is refused (active timer preserved)" {
  # Open pause windows must not be silently billed as worked time. The user
  # has to /track:resume first to make the boundary explicit.
  bash "$SCRIPT" start --ago 60m acme > /dev/null
  bash "$SCRIPT" pause --ago 30m > /dev/null
  run bash "$SCRIPT" stop --ago 10m
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot /track:stop with --at/--ago while paused"* ]]
  # Active timer still there and still paused.
  [ -f "$TRACK_DIR_OVERRIDE/active.json" ]
  run jq -r '.paused_at // "none"' "$TRACK_DIR_OVERRIDE/active.json"
  [[ "$output" != "none" ]]
  # No entry written.
  shopt -s nullglob
  local entries=("$TRACK_DIR_OVERRIDE"/entries/*.jsonl)
  shopt -u nullglob
  [ "${#entries[@]}" -eq 0 ]
}

@test "stop --at/--ago after resume works as normal (regression check)" {
  # The refusal applies ONLY while paused. After resume, --at/--ago must
  # still work and produce a correctly-discounted duration.
  bash "$SCRIPT" start --ago 60m acme > /dev/null
  bash "$SCRIPT" pause --ago 40m > /dev/null
  bash "$SCRIPT" resume --ago 20m > /dev/null
  run bash "$SCRIPT" stop --ago 5m
  [ "$status" -eq 0 ]
  local dur
  dur=$(_entry_duration)
  # Worked = (60m - 5m) - 20m paused = 35m
  [ "$dur" -ge 33 ] && [ "$dur" -le 37 ]
}

@test "pause then stop: end = paused_at, paused interval not counted" {
  # Start 30m ago. Pause 10m ago. Stop now (without resuming).
  # End should be the pause point → duration ≈ 30 - 10 = 20m.
  bash "$SCRIPT" start --ago 30m acme > /dev/null
  bash "$SCRIPT" pause --ago 10m > /dev/null
  run bash "$SCRIPT" stop
  [ "$status" -eq 0 ]
  local dur
  dur=$(_entry_duration)
  [ "$dur" -ge 18 ] && [ "$dur" -le 22 ]
  # active.json removed after stop.
  [ ! -f "$TRACK_DIR_OVERRIDE/active.json" ]
}

@test "two pause cycles: both intervals subtracted from final duration" {
  # Start 120m ago.
  # Pause 100m ago, resume 90m ago → 10m break.
  # Pause 30m ago, resume 20m ago → 10m break.
  # Stop now. Worked: 120 - 20 = 100m.
  bash "$SCRIPT" start --ago 120m acme > /dev/null
  bash "$SCRIPT" pause --ago 100m > /dev/null
  bash "$SCRIPT" resume --ago 90m > /dev/null
  bash "$SCRIPT" pause --ago 30m > /dev/null
  bash "$SCRIPT" resume --ago 20m > /dev/null
  run bash "$SCRIPT" stop
  [ "$status" -eq 0 ]
  local dur
  dur=$(_entry_duration)
  [ "$dur" -ge 98 ] && [ "$dur" -le 102 ]
}

@test "pause without backdating writes paused_at to active.json" {
  bash "$SCRIPT" start --ago 30m acme > /dev/null
  run bash "$SCRIPT" pause
  [ "$status" -eq 0 ]
  run jq -r '.paused_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$TRACK_DIR_OVERRIDE/active.json"
  [ "$output" = "true" ]
}

@test "resume clears paused_at and accumulates into paused_sec_total" {
  bash "$SCRIPT" start --ago 60m acme > /dev/null
  bash "$SCRIPT" pause --ago 30m > /dev/null
  bash "$SCRIPT" resume --ago 20m > /dev/null
  # paused_at must be gone.
  run jq -r '.paused_at // "none"' "$TRACK_DIR_OVERRIDE/active.json"
  [ "$output" = "none" ]
  # paused_sec_total ≈ 600s (10m), allow ±10s for test timing.
  local pst
  pst=$(jq -r '.paused_sec_total' "$TRACK_DIR_OVERRIDE/active.json")
  [ "$pst" -ge 590 ] && [ "$pst" -le 610 ]
}

# ---------- status while paused ----------

@test "status: shows 'paused' line with worked time when paused" {
  bash "$SCRIPT" start --ago 30m acme > /dev/null
  bash "$SCRIPT" pause --ago 10m > /dev/null
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"paused: acme"* ]]
  [[ "$output" == *"worked"* ]]
  [[ "$output" == *"paused for"* ]]
}

@test "status: shows 'excl. breaks' when running with prior pauses" {
  bash "$SCRIPT" start --ago 30m acme > /dev/null
  bash "$SCRIPT" pause --ago 20m > /dev/null
  bash "$SCRIPT" resume --ago 10m > /dev/null
  run bash "$SCRIPT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active: acme"* ]]
  [[ "$output" == *"excl."* ]]
  [[ "$output" == *"breaks"* ]]
}
