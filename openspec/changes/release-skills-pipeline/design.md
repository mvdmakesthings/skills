## Context

The marketplace repo contains plugins with skills distributed via Claude Code CLI. Skills can also be consumed by Claude.ai and Claude Desktop through `.skill` file upload (Settings > Capabilities). Currently there is no automated way to produce these `.skill` files. The repo has one skill today (`human-voice-writer`) but the pipeline must scale to any number of plugins and skills.

## Goals / Non-Goals

**Goals:**
- Automatically package every skill in the repo as a standalone `.skill` file on each tagged release
- Attach `.skill` files to GitHub Releases so users can download them directly
- Document the download-and-upload workflow for Claude.ai/Desktop users in the README

**Non-Goals:**
- Hosting a CDN or download server — GitHub Releases is sufficient
- Modifying plugin structure or skill content
- Supporting non-skill plugin components (commands, agents, hooks) in `.skill` files
- Versioning individual skills separately from the repo tag

## Decisions

### Use GitHub Actions with tag-based triggers
**Choice:** Trigger on `v*` tag pushes rather than branch pushes or manual dispatch.
**Rationale:** Tags are the standard release mechanism. Tag-based triggers mean releases are created intentionally, not on every commit. The `v*` pattern is conventional and familiar.
**Alternative considered:** Manual workflow_dispatch — rejected because it adds friction and is easy to forget.

### Use `softprops/action-gh-release@v2` for release creation
**Choice:** Use the widely-adopted community action rather than raw `gh release create`.
**Rationale:** It handles release creation and asset upload in one step, supports glob patterns for files, and auto-generates release notes. It's the most popular GitHub Release action with active maintenance.
**Alternative considered:** `gh release create` via shell — works but requires more boilerplate for asset attachment and error handling.

### Package skills by globbing `plugins/*/skills/*/SKILL.md`
**Choice:** Discover skills dynamically via filesystem glob rather than maintaining a manifest of skills to package.
**Rationale:** Zero maintenance as plugins/skills are added or removed. The convention-based path (`plugins/<plugin>/skills/<skill>/SKILL.md`) is already established by the plugin structure spec.
**Alternative considered:** Explicit list in a config file — rejected because it creates a maintenance burden and risks drift.

### ZIP structure: skill directory at root
**Choice:** The `.skill` ZIP contains the skill directory as its root entry (e.g., `human-voice-writer/SKILL.md`), not a nested path.
**Rationale:** This matches the Agent Skills spec requirement. The `cd` into the parent directory before zipping ensures the correct structure.

## Risks / Trade-offs

- **[No skills found]** → The glob produces no matches and no `.skill` files are created. The release is created with just release notes. This is acceptable — an empty release is harmless and self-documenting.
- **[Skill name collision]** → Two plugins could have skills with the same directory name, causing one `.skill` file to overwrite the other. → Mitigation: naming convention enforcement at review time. Could add a uniqueness check in the workflow later if needed.
- **[Large skill files]** → Skills with many reference files could produce large ZIPs. → GitHub Releases supports files up to 2 GB, so this is unlikely to be a practical issue.
