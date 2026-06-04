# Changelog

## v0.2.0 — 2026-06-04
**Sessions:** 2 (2026-06-04T21-48, 2026-06-04T21-55)
**Changes:**
- Add deferred-write fallback: when plan mode is active or a decision describes unbuilt behavior, hold CONTEXT.md/ADR writes and defer to implementation time with an explicit user reminder
- Soften the "totally devoid of implementation details" rule to allow mechanism names the team uses out loud; add one-line test (noun the team says = in; code path = out)
- Add downstream consistency sweep step: after decisions crystallise, check for contradictions in PRD, open tickets, README, and sibling ADRs, and surface each conflict
- Add ADR amendment guidance: prefer in-place dated amendment when core decision stands; supersede only when core decision flips

## v0.1.0 — (initial release)
Initial version.
