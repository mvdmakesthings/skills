# Skills Marketplace for Claude Code

A curated set of Claude Code plugins that add structured workflows to your AI sessions — from Linear planning and QA, to billable hour tracking, to prose rewriting. Each plugin bundles several related skills you install once and use across every project.

> Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.33 or later.

## Prerequisites

Some plugins reach outside Claude Code itself. Check what you need before installing:

| Plugin | External dependencies |
|--------|-----------------------|
| `delivery` | [Linear MCP](https://linear.app/docs/mcp) (all skills); [Playwright MCP](https://github.com/microsoft/playwright-mcp) (`/qa` visual verification); `OPENAI_API_KEY` env var (`/plan-design` image generation) |
| `meta` | None — runs entirely inside Claude Code |
| `track` | `jq`, `git` (both must be on your `PATH`) |
| `writing` | None |

## Install

### Quick install

If you already know which plugin you want:

```
/plugin install delivery@mvdmakesthings
/plugin install writing@mvdmakesthings
/plugin install track@mvdmakesthings
/plugin install meta@mvdmakesthings
```

### Browse and install

Add the marketplace first, then explore from the Discover tab:

```
/plugin marketplace add mvdmakesthings/skills
```

Then open the plugin browser:

```
/plugin
```

Navigate to the **Discover** tab and install what you need.

## Plugins

| Plugin | What it does |
|--------|--------------|
| [`delivery`](#delivery) | Linear-driven planning → QA flow: PRDs, issue slicing, plan grilling, design mockups, test planning, and QA execution |
| [`writing`](#writing) | Humanize AI-sounding prose; storytelling coach for pitches, talks, and memos |
| [`track`](#track) | Billable hours timer backed by a git-versioned plaintext ledger |
| [`meta`](#meta) | Improve your own skills: capture session friction, then evolve SKILL.md files with your approval |

---

### `delivery`

`/plugin install delivery@mvdmakesthings`

A full planning-to-QA pipeline built around Linear. Skills chain together — `/to-prd` → `/to-issues` → `/plan-design` + `/plan-qa` → `/qa` — but each one works independently.

| Command | What it does | Requires |
|---------|--------------|----------|
| `/to-prd` | Synthesizes the current conversation into a PRD and publishes it to Linear | Linear MCP |
| `/to-issues` | Slices a plan, spec, or PRD into independently-grabbable Linear issues — each a thin vertical slice with its own acceptance criteria | Linear MCP |
| `/grill-with-docs` | Challenges a plan against your `CONTEXT.md` and ADRs one question at a time, resolves terminology conflicts, and writes decisions back into those docs inline | `CONTEXT.md` / ADRs |
| `/plan-design <issue-id>` | Reads a Linear issue, interviews you per UI surface, generates three layout mockups via OpenAI image generation, builds HTML/CSS for the one you pick, and attaches it to the ticket | Linear MCP, `OPENAI_API_KEY` |
| `/plan-qa <issue-id>` | Drafts a layer-aware test plan from a ticket's acceptance criteria and attaches it as `<issue-id>-test-plan.md` for `/qa` to execute | Linear MCP |
| `/qa [issue-id]` | Maps acceptance criteria to coverage, runs every test layer, executes the attached test plan, and screenshots the UI against design attachments | Linear MCP, Playwright MCP |

---

### `writing`

`/plugin install writing@mvdmakesthings`

| Command | What it does | Requires |
|---------|--------------|----------|
| `/writing:human [prompt]` | Rewrites prose so it reads like a person wrote it — strips the vocabulary and sentence patterns that flag text as AI-generated | None |
| `storyteller-guidance` | A storytelling coach for pitches, talks, and memos. Auto-triggers on pitch / talk / memo phrasing. Draws from a 54-card tactic deck | None |

---

### `track`

`/plugin install track@mvdmakesthings`

| Command | What it does |
|---------|--------------|
| `/track:start <client>` | Start a billable timer for a named client |
| `/track:stop [note]` | Stop the active timer with an optional session note |
| `/track:pause` | Pause the active timer |
| `/track:resume` | Resume a paused timer |
| `/track:status` | Show the active timer and today's totals per client |
| `/track:report` | Print an invoice-ready rollup with hours and dollar totals |

Sessions are recorded to a git-versioned JSONL ledger under `~/.time-tracker/`. Requires `jq` and `git` on your `PATH`.

---

### `meta`

`/plugin install meta@mvdmakesthings`

Two skills that form a continuous improvement loop for any skill in this marketplace:

```
Any project                    Skills repo
───────────                    ───────────
Run a skill
     ↓
/skill-reflect  ──── logs ───→ ~/.claude/skill-sessions/
                                         ↓
                               /skill-improve  ──→  SKILL.md updated
                                         ↓
                               HITL approval gate
```

| Command | Where to run | What it does |
|---------|--------------|--------------|
| `/skill-reflect <skill>` | Any project, immediately after a skill session | Mines the conversation for friction — improvised steps, user corrections, missed edge cases — and writes a structured log to `~/.claude/skill-sessions/<plugin>/sessions/<skill-name>/` |
| `/skill-improve <skill>` | Skills repo checkout only | Reads accumulated session logs, proposes numbered SKILL.md changes with evidence, waits for your approval on each, then applies accepted changes, bumps the patch version, and writes a `CHANGELOG.md` entry |

Reflect after sessions anywhere → logs accumulate in `~/.claude/skill-sessions/` → improve from this repo when you're ready.

---

## Repository structure

```
.claude-plugin/
└── marketplace.json          ← Marketplace catalog (lists all plugins)

plugins/
├── delivery/
│   ├── .claude-plugin/
│   │   └── plugin.json       ← Plugin manifest
│   └── skills/
│       ├── to-prd/SKILL.md
│       ├── to-issues/SKILL.md
│       ├── grill-with-docs/SKILL.md
│       ├── plan-design/SKILL.md
│       ├── plan-qa/SKILL.md
│       └── qa/SKILL.md
├── writing/
│   └── skills/
│       ├── human-voice-writer/SKILL.md
│       └── storyteller-guidance/SKILL.md
├── track/
│   ├── bin/track.sh          ← Bash dispatcher (all ledger logic lives here)
│   └── skills/
│       └── track/SKILL.md
└── meta/
    └── skills/
        ├── skill-reflect/SKILL.md
        └── skill-improve/SKILL.md

_dev/                         ← Dev-only: tests, evals, scratch docs. Not shipped on install.
```

---

## Local development

Test a plugin locally without publishing:

```bash
# Add your local clone as a marketplace source
/plugin marketplace add ./path/to/skills

# Install the plugin you're working on
/plugin install delivery@mvdmakesthings

# Validate the full marketplace
claude plugin validate .
```

---

## Contributing

### Add a skill to an existing plugin

Create a `SKILL.md` under the relevant plugin — no marketplace change needed:

```
plugins/
└── delivery/
    └── skills/
        └── your-skill/
            └── SKILL.md
```

Put dev-only fixtures (tests, eval data) under `_dev/<plugin>/` so they don't ship on install.

### Add a new plugin

1. Create the plugin directory and manifest:

```bash
mkdir -p plugins/your-plugin/.claude-plugin
```

```json
// plugins/your-plugin/.claude-plugin/plugin.json
{
  "name": "your-plugin",
  "description": "What your plugin does",
  "version": "1.0.0"
}
```

2. Add skills under `plugins/your-plugin/skills/<skill-name>/SKILL.md`.

3. Register it in `.claude-plugin/marketplace.json`:

```json
{
  "plugins": [
    {
      "name": "your-plugin",
      "source": "./plugins/your-plugin",
      "description": "What your plugin does"
    }
  ]
}
```

4. Validate: `claude plugin validate .`

5. Open a pull request. Bundles group related skills under one install — keep each plugin thematically coherent.

See the [Claude Code plugin docs](https://docs.anthropic.com/en/docs/claude-code/plugins) for details on skill manifests, agents, hooks, and other component types.

---

## License

MIT
