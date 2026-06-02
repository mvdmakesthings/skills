# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Code plugin marketplace** — a public catalog of plugins that users install via `/plugin marketplace add mvdmakesthings/skills`. It contains no application code; the repo is entirely plugin definitions (skills, agents, commands, hooks) and marketplace configuration.

## Current Plugins

| Name | Skill command | Purpose |
|------|--------------|---------|
| `qa` | `/qa [issue-id]` | QA against a Linear issue; runs tests, screenshots UI, posts to Linear; executes the ticket's test plan when one is attached |
| `plan-qa` | `/plan-qa <issue-id>` | Drafts a layer-aware test plan from a Linear issue's ACs and attaches it as `<issue-id>-test-plan.md`; consumed by `/qa` |
| `plan-design` | `/plan-design <issue-id>` | Design mockups via DALL-E + HTML implementation, attached to Linear |
| `grill-with-docs` | `/grill-with-docs` | Stress-test a plan against domain model; updates CONTEXT.md + ADRs |
| `to-issues` | `/to-issues` | Break a plan into Linear issues as vertical slices |
| `to-prd` | `/to-prd` | Convert conversation context into a PRD and publish to Linear |
| `writer` | `/writer:human` | Human-sounding prose |
| `storyteller-guidance` | auto-triggers | Storytelling coach for pitches and talks |
| `track` | `/track:start <client>` | Billable hours tracker |

## Architecture

```
.claude-plugin/marketplace.json   ← Marketplace catalog (the registry)
skills/                            ← All plugins live here
  <plugin-name>/
    .claude-plugin/plugin.json     ← Plugin manifest (required)
    skills/                        ← SKILL.md files
    agents/                        ← Agent definition .md files
    commands/                      ← Slash command .md files
    hooks/                         ← Hook configurations
```

Plugin source paths in the `plugins` array use relative paths from the repository root (e.g., `"source": "./skills/my-plugin"`).

**Why the double `skills/` nesting?** The outer `skills/<plugin-name>/` is the plugin package root (contains `plugin.json`). The inner `skills/` holds the actual SKILL.md components. A plugin can also have `agents/`, `commands/`, and `hooks/` siblings at the same level. So `skills/qa/skills/qa/SKILL.md` reads as: plugin `qa` → skill component named `qa`.

## Key Files

- **`.claude-plugin/marketplace.json`** — The marketplace registry. Every plugin must have an entry here to be discoverable. The `name` field (`mvdmakesthings`) is what users reference during install (`/plugin install <plugin>@mvdmakesthings`).
- **`skills/<name>/.claude-plugin/plugin.json`** — Each plugin's manifest with name, description, and version.

## Adding a Plugin

1. Create `skills/<name>/.claude-plugin/plugin.json` with the manifest
2. Add component directories (skills/, agents/, commands/, hooks/) as needed
3. Add an entry to the `plugins` array in `.claude-plugin/marketplace.json`

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
