# Changelog

## v0.1.1 — 2026-06-04
**Sessions:** 1 (2026-06-04T22-37)
**Changes:**
- Phase 1: fix scan command to use `ls -d` so it returns the directory path rather than contents, making plugin name extraction possible
- Phase 1 "No match": check `git branch --show-current` and switch branches before asking the user — handles the case where the skill's plugin is on an unmerged branch
- Phase 4: fix "relative to repo root" wording to "full path" — the log lives in `~/.claude/`, which is outside the repo

## v0.1.0 — (initial release)
Initial version.
