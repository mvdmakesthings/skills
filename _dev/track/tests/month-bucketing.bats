#!/usr/bin/env bats

# Sessions that cross a month boundary bucket by the START timestamp's local date.

setup() {
  TMPHOME=$(mktemp -d)
  export HOME="$TMPHOME"
  export TRACK_DIR_OVERRIDE="$TMPHOME/.time-tracker"
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  SCRIPT="${TRACK_SH:-${BATS_TEST_DIRNAME}/../../../plugins/track/bin/track.sh}"

  # Pin timezone so "local date of UTC timestamp" is deterministic across machines.
  export TZ="America/Los_Angeles"   # UTC-7 (PDT) during summer

  bash "$SCRIPT" status > /dev/null
  echo '{"acme": {"rate": 100}}' > "$TRACK_DIR_OVERRIDE/clients.json"
}

teardown() {
  [ -n "${TMPHOME:-}" ] && rm -rf "$TMPHOME"
}

@test "bucketing: session starting 23:30 last-day-of-month PDT goes in start's-month JSONL, not stop's-month" {
  # Pick a start whose UTC value is in one month but whose LOCAL date is in the prior month.
  # UTC 2026-02-01T06:30:00Z == local 2026-01-31T22:30:00 PST (UTC-8).
  # Use a past date so stop (which defaults to "now") doesn't trigger end<start validation.
  cat > "$TRACK_DIR_OVERRIDE/active.json" <<EOF
{"client":"acme","start":"2026-02-01T06:30:00Z"}
EOF

  run bash "$SCRIPT" stop
  [ "$status" -eq 0 ]

  # Entry must land in 2026-01.jsonl (start's local month), NOT 2026-02.jsonl (start's UTC month or stop's month).
  [ -f "$TRACK_DIR_OVERRIDE/entries/2026-01.jsonl" ]
  [ ! -f "$TRACK_DIR_OVERRIDE/entries/2026-02.jsonl" ]

  # Spot-check the entry's start timestamp survived unchanged.
  run jq -r '.start' "$TRACK_DIR_OVERRIDE/entries/2026-01.jsonl"
  [ "$output" = "2026-02-01T06:30:00Z" ]
}

@test "bucketing: same-day session in the middle of a month buckets cleanly" {
  # UTC 2026-05-15T17:00:00Z == local 2026-05-15T10:00:00 PDT — well inside May.
  cat > "$TRACK_DIR_OVERRIDE/active.json" <<EOF
{"client":"acme","start":"2026-05-15T17:00:00Z"}
EOF

  run bash "$SCRIPT" stop
  [ "$status" -eq 0 ]
  [ -f "$TRACK_DIR_OVERRIDE/entries/2026-05.jsonl" ]
}
