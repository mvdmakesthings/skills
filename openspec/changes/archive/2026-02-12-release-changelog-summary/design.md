## Context

The release workflow (`.github/workflows/release-skills.yml`) currently packages skills and creates a GitHub Release with `generate_release_notes: true`. This produces a raw commit list as the release body. Users browsing the Releases page see commit messages like "Move writer example into plugin directory" rather than a clear summary of what plugins and skills are available in the release.

## Goals / Non-Goals

**Goals:**
- Prepend a human-readable summary to the release body that lists available plugins, packaged skills, and notable changes since the last tag
- Keep auto-generated commit notes for developer reference
- Generate the summary purely from repo contents and git history — no external dependencies

**Non-Goals:**
- AI-generated or LLM-summarized changelogs
- Per-plugin or per-skill changelogs
- Modifying skill packaging or any other workflow step

## Decisions

### Generate the summary in a shell step using repo data
**Choice:** Add a workflow step that builds a markdown summary from the marketplace catalog (`marketplace.json`), discovered skill files, and `git log` between the previous tag and current tag.
**Rationale:** Everything needed is already in the repo. No external tools or APIs required. Shell + `jq` is available on `ubuntu-latest` by default.
**Alternative considered:** A custom GitHub Action or script — rejected as over-engineering for a simple text generation task.

### Use `body_path` with `generate_release_notes: true`
**Choice:** Write the summary to a file, pass it via `body_path` to `softprops/action-gh-release@v2`, and keep `generate_release_notes: true` so GitHub appends the commit list after the custom body.
**Rationale:** This combines both: a curated summary up top and the full commit log below. The `body_path` parameter is supported alongside `generate_release_notes`.
**Alternative considered:** Using `body` inline — rejected because multi-line markdown is awkward to pass inline in YAML.

### Derive changes from git log between tags
**Choice:** Use `git log <previous-tag>..HEAD --oneline` to identify what changed, then summarize by category (plugins added/updated, skills added/updated).
**Rationale:** Tag-to-tag diff gives the exact set of changes in this release. Parsing commit subjects for key paths (`plugins/`, `skills/`) provides enough signal without complexity.
**Alternative considered:** Diffing file trees between tags — more accurate but harder to summarize in human terms.

### Summary structure
**Choice:** The summary will have three sections: a header with the tag version, a "What's Included" section listing plugins and their packaged skills, and a "What Changed" section with a brief list of notable changes derived from commits.
**Rationale:** Users care about two things: what can I download, and what's new. This structure answers both.

## Risks / Trade-offs

- **[No previous tag]** → First release has no tag-to-tag diff. → Mitigation: detect this case and show "Initial release" instead of a changes list.
- **[Commit messages are vague]** → The "What Changed" section is only as good as commit messages. → Acceptable trade-off; this is a convention-based repo with clear commit messages.
- **[jq dependency]** → `jq` is pre-installed on `ubuntu-latest` GitHub runners. → If GitHub changes runner images, this could break. Low risk — `jq` has been included for years.
