# Changelog

## v0.4.0 — 2026-06-04
**Sessions:** 1 (_dev/delivery/qa/ENHANCEMENTS.md — manual friction log from VYT-15 run)
**Changes:**
- Phase 4a: fetch Linear design attachments via MCP (not curl, which 401s); add canonical selection when multiple attachments exist; render HTML mockups in browser before screenshotting
- Phase 4: add new read-only precondition step (4b) before visual QA — verify required migrations and fixture rows exist before navigating; surface missing preconditions and ask before any mutation
- Phase 4d: prefer read-only UI states for screenshots; disclose any writes in the report
- Phase 4d: require Node/Playwright helper scripts to run from inside the project repo; use pnpm exec / npx; clean up temp scripts
- Phase 5a: process Linear uploads one at a time (signed URLs expire in ~60s); send uploadRequest.headers verbatim; embed finalized asset URLs in comment
- Phase 2: mark N/A for non-applicable AC table cells; flag non-automatable "judgment" ACs and grade by inspection rather than implying a test ran

## v0.3.0 — (prior release)
Initial tracked version. Included: uncommitted/untracked diff fallback, full test-layer discovery, pre-existing red triage, storageState auth chain, publish authorization gate.
