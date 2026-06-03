# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Code plugin marketplace** — a public catalog of plugins that users install via `/plugin marketplace add mvdmakesthings/skills`. It contains no application code; the repo is entirely plugin definitions (skills, agents, commands, hooks) and marketplace configuration.

## Plugins

The marketplace ships **three themed plugins**, each bundling several related skills:

| Plugin | Skills (command) | Purpose |
|--------|------------------|---------|
| `delivery` | `to-prd` (`/to-prd`), `to-issues` (`/to-issues`), `grill-with-docs` (`/grill-with-docs`), `plan-design` (`/plan-design`), `plan-qa` (`/plan-qa`), `qa` (`/qa`) | Linear-driven planning→QA flow: PRDs, issue slicing, plan grilling, design mockups, test planning, and QA execution. `plan-qa` attaches `<issue-id>-test-plan.md`; `qa` consumes it. |
| `writing` | `human-voice-writer` (`/writing:human`), `storyteller-guidance` (auto-triggers) | Humanize AI-sounding prose; storytelling coach for pitches, talks, and memos |
| `track` | `track` (`/track:start` \| `:stop` \| `:pause` \| `:resume` \| `:status` \| `:report`) | Billable hours tracker backed by a git-versioned ledger |

Skills auto-trigger — and their `/<skill>` short-commands resolve — from each skill's own `name:` frontmatter, independent of which plugin bundles them. A plugin *command*'s namespace (e.g. `/writing:human`, `/track:start`) derives from the plugin name.

## Architecture

```
.claude-plugin/marketplace.json   ← Marketplace catalog (lists the 3 plugins)
plugins/                          ← Installable plugins live here
  <plugin-name>/
    .claude-plugin/plugin.json     ← Plugin manifest (required)
    skills/                        ← One subdir per skill, each with a SKILL.md
      <skill-name>/SKILL.md
    commands/                      ← Slash command .md files (optional)
    bin/                           ← Executable helpers, e.g. track's dispatcher (optional)
    agents/ hooks/                 ← Other component types (optional)
_dev/                             ← Dev-only material; NOT shipped on install
  <plugin>/...                      docs, tests, eval workspaces, generators
```

A single plugin holds **many** skills under `skills/`. Source paths in the marketplace `plugins` array are repo-relative (e.g., `"source": "./plugins/delivery"`).

Everything a plugin needs at runtime lives inside its `plugins/<name>/` tree; everything else (tests, docs, eval artifacts) lives under `_dev/<plugin>/` so it stays out of the installed package. Within a skill, reference files sit in `skills/<skill>/references/` and are addressed relative to the SKILL.md; the `track` skill locates its dispatcher via `${CLAUDE_PLUGIN_ROOT}/bin/track.sh`.

## Key Files

- **`.claude-plugin/marketplace.json`** — The marketplace registry. Every plugin must have an entry here to be discoverable. The marketplace `name` (`mvdmakesthings`) is what users reference during install (`/plugin install <plugin>@mvdmakesthings`).
- **`plugins/<name>/.claude-plugin/plugin.json`** — Each plugin's manifest with name, description, and version.

## Adding a Skill or Plugin

**Add a skill to an existing bundle** (most common): create `plugins/<bundle>/skills/<skill-name>/SKILL.md`. No marketplace change is needed — it ships with the bundle on the next install. Put any dev-only fixtures under `_dev/<bundle>/`.

**Add a new bundle:** create `plugins/<name>/.claude-plugin/plugin.json`, add its components, and register it with an entry in the `plugins` array of `.claude-plugin/marketplace.json` (`"source": "./plugins/<name>"`).

## Validation

```bash
claude plugin validate .
```

Or from within Claude Code:

```
/plugin validate .
```

## Testing Locally

```
/plugin marketplace add ./path/to/claude-marketplace
/plugin install <plugin-name>@mvdmakesthings
```

## Git Commit Rules

- Never reference Claude Code or Anthropic as a co-author. All commits are attributed to the original author only.
