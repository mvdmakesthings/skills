#!/usr/bin/env bats

# T6: when `git commit` fails (typically GPG agent locked), the dispatcher
# must surface a friendly recovery message AND preserve active.json so the
# user can retry after fixing the underlying problem.

setup() {
  TMPHOME=$(mktemp -d)
  export HOME="$TMPHOME"
  export TRACK_DIR_OVERRIDE="$TMPHOME/.time-tracker"
  git config --global user.email "test@example.com"
  git config --global user.name  "Test User"
  SCRIPT="${TRACK_SH:-${BATS_TEST_DIRNAME}/../../../plugins/track/bin/track.sh}"

  bash "$SCRIPT" status > /dev/null
  echo '{"acme": {"rate": 100}}' > "$TRACK_DIR_OVERRIDE/clients.json"
  bash "$SCRIPT" start acme > /dev/null

  # Install a git shim that fails ONLY on `git -C <dir> commit ...`.
  REAL_GIT=$(command -v git)
  mkdir -p "$TMPHOME/shim-bin"
  cat > "$TMPHOME/shim-bin/git" <<EOF
#!/usr/bin/env bash
# Intercept only the dispatcher's commit pattern: git -C <dir> commit ...
if [[ "\$1" == "-C" && "\$3" == "commit" ]]; then
  echo "error: gpg failed to sign the data" >&2
  echo "fatal: failed to write commit object" >&2
  exit 1
fi
exec "$REAL_GIT" "\$@"
EOF
  chmod +x "$TMPHOME/shim-bin/git"
  export PATH="$TMPHOME/shim-bin:$PATH"
}

teardown() {
  [ -n "${TMPHOME:-}" ] && rm -rf "$TMPHOME"
}

@test "commit-failure: prints recovery hint when git commit fails" {
  run bash "$SCRIPT" stop
  [ "$status" -eq 1 ]
  [[ "$output" == *"commit failed"* ]]
  [[ "$output" == *"gpg failed to sign"* ]]
  [[ "$output" == *"is NOT committed"* ]]
  [[ "$output" == *"active timer is preserved"* ]]
  [[ "$output" == *"manual recovery"* ]]
  [[ "$output" == *"GPG agent"* ]]
}

@test "commit-failure: active.json is preserved so /track:stop can be retried" {
  run bash "$SCRIPT" stop
  [ "$status" -eq 1 ]
  [ -f "$TRACK_DIR_OVERRIDE/active.json" ]
  run jq -r '.client' "$TRACK_DIR_OVERRIDE/active.json"
  [ "$output" = "acme" ]
}

@test "commit-failure: appended JSONL entry remains in the entries file (user can recover)" {
  run bash "$SCRIPT" stop
  [ "$status" -eq 1 ]
  shopt -s nullglob
  entries=("$TRACK_DIR_OVERRIDE"/entries/*.jsonl)
  shopt -u nullglob
  [ "${#entries[@]}" -eq 1 ]
  # macOS `wc -l` pads its output with spaces; strip whitespace before compare.
  run bash -c "wc -l < '${entries[0]}' | tr -d ' '"
  [ "$output" = "1" ]
}

@test "commit-failure: lock is released so the next command can run" {
  bash "$SCRIPT" stop 2>/dev/null || true
  [ ! -d "$TRACK_DIR_OVERRIDE/.lock" ]
}
