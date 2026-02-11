# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Code plugin marketplace** — a public catalog of plugins that users install via `/plugin marketplace add mvdmakesthings/claude-marketplace`. It contains no application code; the repo is entirely plugin definitions (skills, agents, commands, hooks) and marketplace configuration.

## Architecture

```
.claude-plugin/marketplace.json   ← Marketplace catalog (the registry)
plugins/                           ← All plugins live here
  <plugin-name>/
    .claude-plugin/plugin.json     ← Plugin manifest (required)
    skills/                        ← SKILL.md files
    agents/                        ← Agent definition .md files
    commands/                      ← Slash command .md files
    hooks/                         ← Hook configurations
```

Plugin source paths in the `plugins` array use relative paths from the repository root (e.g., `"source": "./plugins/my-plugin"`).

## Key Files

- **`.claude-plugin/marketplace.json`** — The marketplace registry. Every plugin must have an entry here to be discoverable. The `name` field (`mvdmakesthings`) is what users reference during install (`/plugin install <plugin>@mvdmakesthings`).
- **`plugins/<name>/.claude-plugin/plugin.json`** — Each plugin's manifest with name, description, and version.

## Adding a Plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` with the manifest
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
