# Changelog

## v0.1.1 — 2026-06-04
**Sessions:** 1 (2026-06-04T22-31)
**Changes:**
- Phase 2: add alternative evidence source fallback — when session log directory is empty but user referenced a file in conversation, read from that path instead of stopping
- Phase 3: add CHANGELOG-free dedup rule — when no changelog exists, read the current SKILL.md directly to filter already-addressed proposals
- Phase 6: clarify that "accept all" approves proposals, not version category — always ask the minor-bump question separately even after "accept all"
- What to skip: scope session log preservation rule to standard `~/.claude/skill-sessions/` logs; non-standard evidence sources follow user instructions

## v0.1.0 — (initial release)
Initial version.
