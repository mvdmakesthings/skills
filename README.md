# claude-marketplace

A curated collection of plugins, skills, and agents for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Install

> Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.33 or later.

Add the marketplace:

```
/plugin marketplace add mvdmakesthings/skills
```

Browse available plugins:

```
/plugin
```

Then navigate to the **Discover** tab and install what you need.

You can also install plugins directly:

```
/plugin install <plugin-name>@mvdmakesthings
```

## Available Plugins

Three themed bundles — each a single install that brings several related skills.

### `delivery` — Linear planning→QA flow

`/plugin install delivery@mvdmakesthings`

| Skill / command | What it does | Requires |
|-----------------|--------------|----------|
| `/to-prd` | Synthesizes the current conversation into a PRD and publishes it to Linear. | Linear MCP |
| `/to-issues` | Slices a plan, spec, or PRD into Linear issues you can pick up independently — each a thin end-to-end cut with its own acceptance criteria. | Linear MCP |
| `/grill-with-docs` | Interrogates a plan against your CONTEXT.md and ADRs one question at a time, then writes the resolved decisions back into those docs. | CONTEXT.md / ADRs |
| `/plan-design <issue-id>` | Turns a Linear issue into design mockups: interviews you per UI surface, generates three layout options via OpenAI image generation, builds the HTML/CSS for the one you pick, and attaches it to the ticket. | Linear MCP, OpenAI API key |
| `/plan-qa <issue-id>` | Drafts a layer-aware test plan from a ticket's acceptance criteria and attaches it as `<issue-id>-test-plan.md` for `/qa` to execute. | Linear MCP |
| `/qa [issue-id]` | Reviews current changes against a Linear issue: maps acceptance criteria to coverage, runs every test layer, executes the attached test plan, and screenshots the UI against design attachments. | Linear MCP, Playwright MCP |

### `writing` — prose & narrative

`/plugin install writing@mvdmakesthings`

| Skill / command | What it does | Requires |
|-----------------|--------------|----------|
| `/writing:human [prompt]` | Rewrites prose so it reads like a person wrote it, stripping the vocabulary and sentence patterns that flag text as AI-generated. | none |
| storyteller-guidance — auto-triggers on pitch / talk / memo phrasing | A storytelling coach. Picks from a 54-card tactic deck to draft or coach you through pitches, talks, and memos. | none |

### `track` — billable hours

`/plugin install track@mvdmakesthings`

| Command | What it does | Requires |
|---------|--------------|----------|
| `/track:start <client>` (+ `:stop`, `:pause`, `:resume`, `:status`, `:report`) | Billable-hours timer backed by a git-versioned plaintext ledger under `~/.time-tracker/`. | jq, git |

"Requires" lists what each skill reaches for beyond Claude Code itself. MCP servers (Linear, Playwright) are configured in your Claude Code settings; `plan-design` reads the OpenAI key from your environment for image generation.

## Adding a Skill or Plugin

Most additions are a **new skill in an existing bundle** — no marketplace change needed:

```
plugins/
└── delivery/                     # an existing bundle
    └── skills/
        └── your-skill/
            └── SKILL.md           # the skill (auto-triggers on its description)
```

Keep dev-only fixtures (tests, eval data, scratch docs) under `_dev/<bundle>/` so they don't ship on install.

To add a **new bundle**, create a plugin package and register it:

```
plugins/
└── your-plugin/
    ├── .claude-plugin/
    │   └── plugin.json        # Plugin manifest (required)
    ├── skills/                # one subdir per skill
    │   └── your-skill/SKILL.md
    ├── commands/              # slash commands (optional)
    ├── bin/                   # executable helpers (optional)
    └── agents/  hooks/        # other components (optional)
```

### 1. Create the plugin directory

```bash
mkdir -p plugins/your-plugin/.claude-plugin
```

### 2. Add a plugin manifest

Create `plugins/your-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "your-plugin",
  "description": "What your plugin does",
  "version": "1.0.0"
}
```

### 3. Add your components

Add skills, commands, agents, or hooks under the plugin. See the [Claude Code plugin docs](https://docs.anthropic.com/en/docs/claude-code/plugins) for details on each component type.

### 4. Register it in the marketplace

Add an entry to `.claude-plugin/marketplace.json`:

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

### 5. Validate and test locally

```
claude plugin validate .
/plugin marketplace add ./path/to/skills
/plugin install your-plugin@mvdmakesthings
```

## Contributing

1. Fork this repository
2. Add a skill under an existing `plugins/<bundle>/skills/`, or create a new bundle under `plugins/`
3. If you added a new bundle, register it in `.claude-plugin/marketplace.json`
4. Validate with `claude plugin validate .`
5. Open a pull request

Bundles group related skills under one install — keep each bundle thematically coherent.

## License

MIT
