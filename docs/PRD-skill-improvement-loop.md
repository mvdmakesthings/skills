# PRD: Self-Improving Skills with HITL Approval

## Problem Statement

Skills like `qa`, `human-voice-writer`, and `track` accumulate real-world friction over time — edge cases their SKILL.md didn't anticipate, steps Claude had to improvise, corrections the user had to make mid-session. Currently none of that signal is captured anywhere. Every session that surfaces a skill gap is wasted learning. As skills are used more, they should get better; right now they stay frozen at the version they were written.

There is also no versioning story for skill evolution: when a SKILL.md changes, there's no record of what changed, why, or what sessions informed the decision. A future maintainer (or a future evolver run) has no history to reason from.

## Solution

Two new skills in a new `meta` plugin:

- **`/skill-reflect <skill-name>`** — run immediately after a skill session to write a structured friction log capturing what the skill had to improvise, what the user corrected, what edge cases weren't anticipated, and what changes would help. Logs are written to `_dev/<plugin>/sessions/<skill-name>/`.

- **`/skill-improve <skill-name>`** — run on-demand when enough logs have accumulated. Reads all session logs for the skill, synthesizes numbered proposals with rationale and session evidence, waits for conversational HITL approval (accept/reject/edit each proposal), applies accepted changes, bumps the patch version in the SKILL.md frontmatter, and writes a new entry to a per-skill `CHANGELOG.md`.

Skills now improve through use rather than staying frozen. Every accepted change is traceable to the sessions that motivated it.

## User Stories

1. As a skill author, I want to capture friction from a skill session immediately after it ends, so that the signal isn't lost before I forget the details.
2. As a skill author, I want the reflection prompt to ask specific questions (improvised steps, corrections, edge cases, proposed changes), so that the log is structured enough for the evolver to reason from.
3. As a skill author, I want session logs stored in `_dev/<plugin>/sessions/<skill-name>/`, so that they stay local, version-controlled, and organized by skill.
4. As a skill author, I want to run `/skill-reflect qa` without specifying the plugin name, so that I don't need to remember which plugin owns each skill.
5. As a skill author, I want the reflect skill to resolve the owning plugin automatically by scanning the `plugins/*/skills/` tree, so that the command stays simple.
6. As a skill author, I want each session log to include a one-line `session_summary` in its frontmatter, so that I can scan the log directory and understand what each session was about at a glance.
7. As a skill author, I want to run `/skill-improve qa` on demand when I have enough signal, so that I control when improvement proposals are generated.
8. As a skill author, I want the evolver to read all accumulated session logs for the target skill, so that proposals reflect patterns across multiple sessions rather than one-off noise.
9. As a skill author, I want the evolver to read the existing CHANGELOG.md before proposing changes, so that it doesn't re-propose improvements that have already been made.
10. As a skill author, I want proposals presented as numbered items with a rationale and citation to specific session log evidence, so that I can evaluate each one independently.
11. As a skill author, I want to accept, reject, or edit each proposal in natural language ("accept 1 and 3, change 2 to say X instead"), so that I stay in control of exactly what gets written.
12. As a skill author, I want no changes written to the SKILL.md until I have explicitly approved them, so that the HITL gate is real and not advisory.
13. As a skill author, I want the SKILL.md patch version bumped automatically after accepted changes are applied, so that I don't have to remember to update it manually.
14. As a skill author, I want to be prompted before a minor version bump (behavioral change) rather than a patch bump (refinement), so that version semantics stay meaningful.
15. As a skill author, I want a `CHANGELOG.md` created next to the SKILL.md on first improvement, so that the evolution history is co-located with the skill itself.
16. As a skill author, I want each changelog entry to list the version, date, session count, and accepted changes, so that the history is readable without digging through git log.
17. As a skill author, I want the changelog seeded with an entry for the original version when first created, so that the version history starts from the beginning.
18. As a skill author, I want the new `meta` plugin to validate cleanly against `claude plugin validate .`, so that it can be shipped as part of the marketplace.
19. As a marketplace user, I want to install the `meta` plugin via `/plugin install meta@mvdmakesthings`, so that I can use both skills in any project.
20. As a skill author, I want session logs to remain in `_dev/` and excluded from the installed plugin package, so that local improvement history doesn't ship to end users.

## Implementation Decisions

- **New plugin:** `plugins/meta/` with a `plugin.json` manifest. Registered in `.claude-plugin/marketplace.json`. Skills: `skill-reflect` and `skill-improve`, each with a `SKILL.md`.

- **Skill resolution:** Both skills resolve `<skill-name>` to its owning plugin by scanning `plugins/*/skills/<skill-name>/`. If a collision exists (same skill name in two plugins), the skill asks the user to qualify: `<plugin>/<skill-name>`. Currently no collisions exist across the 9 shipped skills.

- **Session log format:** A markdown file with YAML frontmatter (`skill`, `plugin`, `date`, `session_summary`) and four body sections matching the four reflection questions. Filename: `YYYY-MM-DDTHH-MM.md`. Directory created lazily on first write.

- **Improvement cycle inputs:** The evolver reads (1) all session logs in `_dev/<plugin>/sessions/<skill-name>/`, (2) the current SKILL.md, and (3) the existing CHANGELOG.md if present. These three inputs together prevent regression and re-proposal.

- **HITL gate:** Proposals are presented conversationally. No write occurs until the user gives explicit acceptance. Partial acceptance (accept some, reject others) is handled in a single reply. Edits to individual proposals are applied inline before writing.

- **Versioning:** Semver patch bump (`0.3.0 → 0.3.1`) for refinements. The evolver prompts the user before applying a minor bump (`0.3.0 → 0.4.0`) for behavioral or structural changes. Version lives in SKILL.md frontmatter `version:` field (already present in all existing SKILL.md files).

- **Changelog location:** `plugins/<plugin>/skills/<skill-name>/CHANGELOG.md` — co-located with the SKILL.md it describes. Created on first improvement run. Entries are prepended (newest first).

- **No auto-commit:** The evolver does not commit. The author commits when ready, following existing repo commit conventions.

- **Dev materials isolation:** Session logs live in `_dev/` and are never included in the installed plugin package. The `meta` plugin itself ships no `_dev/` content.

## Testing Decisions

A good test for this feature verifies external behavior — what files exist, what they contain, and what changed — not which internal functions were called or how the SKILL.md was parsed.

**What makes a good test here:**
- Seed realistic session log fixtures and verify the evolver produces sensible proposals
- Verify the session log written by `skill-reflect` has the correct structure and location
- Verify the SKILL.md diff after an improvement run matches the accepted proposals
- Verify the CHANGELOG.md entry format and version bump correctness

**Modules to test:**

1. **`skill-reflect` end-to-end** — invoke the skill, verify a correctly-structured log file is written to `_dev/<plugin>/sessions/<skill-name>/<timestamp>.md` with all four sections and valid frontmatter.

2. **`skill-improve` end-to-end** — seed 2–3 session log fixtures in `_dev/delivery/sessions/qa/`, invoke the skill, accept a subset of proposals, verify: (a) SKILL.md changed only in accepted areas, (b) version bumped by one patch, (c) CHANGELOG.md created with correct entry citing session dates.

3. **Plugin validation** — `claude plugin validate .` passes with zero errors on the new `meta` plugin.

**Prior art:** The `track` skill has BATS integration tests in `_dev/track/tests/` that test the bash dispatcher end-to-end (start/stop, pause/resume, locking). The skill-level tests here follow a similar pattern: set up state, invoke, assert on file system output. No unit tests for skill logic — behavior is the contract.

## Out of Scope

- **Automatic triggering** — no post-stop hooks or threshold-based nudges. Both skills are invoked manually.
- **Cross-project session aggregation** — session logs are repo-local. No central store across projects.
- **Scheduled evolver runs** — no cron or scheduled improvement cycles.
- **Automated eval scoring** — proposals are evaluated by the author, not by a metric. No automated quality gates.
- **Rollback command** — git history serves as rollback. No dedicated `/skill-rollback` command.
- **Multi-skill improvement** — `/skill-improve` targets one skill at a time. No bulk improvement mode.
- **Shipping session logs** — logs stay in `_dev/` and are never included in installed plugin packages.

## Further Notes

- The design follows the **SkillClaw** architecture (arXiv:2604.08377) in spirit: session trajectory capture → evolver pipeline → optional HITL gate. The key difference is that the HITL gate is mandatory here (not opt-in), and the "trajectory" is a structured friction log rather than a raw API intercept.
- The **EMNLP 2025 annotation flywheel** study (production RAG system, +11.7% recall) validates that structured human signal during live work is the highest-quality improvement input — more valuable than scalar metrics. The four reflection questions in `skill-reflect` are designed to elicit the same four signal types that study identified.
- A `CONTEXT.md` has been created at the repo root establishing canonical terms for this system: **session log**, **evolver**, **improvement cycle**, **HITL gate**, **bundle**, **dev materials**.
- Future extension point: a `/skill-audit` meta-skill that reads changelogs and session logs across all skills and surfaces which skills have accumulated the most unaddressed friction, as a prioritization signal.
