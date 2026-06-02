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

| Plugin | Command | What it does | Requires |
|--------|---------|--------------|----------|
| `qa` | `/qa [issue-id]` | Reviews your current changes against a Linear issue: maps acceptance criteria to coverage, runs every test layer it finds, and screenshots the UI against design attachments. | Linear MCP, Playwright MCP |
| `plan-design` | `/plan-design <issue-id>` | Turns a Linear issue into design mockups. Interviews you on each UI surface, generates three layout options with OpenAI image generation, then builds the HTML/CSS for the one you pick and attaches it to the ticket. | Linear MCP, OpenAI API key |
| `grill-with-docs` | `/grill-with-docs` | Interrogates a plan against your CONTEXT.md and ADRs one question at a time, then writes the resolved decisions back into those docs. | CONTEXT.md / ADRs |
| `to-issues` | `/to-issues` | Slices a plan, spec, or PRD into Linear issues you can pick up independently. Each one is a thin end-to-end cut with its own acceptance criteria. | Linear MCP |
| `to-prd` | `/to-prd` | Synthesizes the current conversation into a PRD and publishes it to Linear. | Linear MCP |
| `writer` | `/writer:human [prompt]` | Rewrites prose so it reads like a person wrote it, stripping the vocabulary and sentence patterns that flag text as AI-generated. | none |
| `storyteller-guidance` | auto-triggers on pitch / talk / memo phrasing | A storytelling coach. Picks from a 54-card tactic deck to draft or coach you through pitches, talks, and memos. | none |
| `track` | `/track:start <client>` | Billable-hours timer backed by a git-versioned plaintext ledger under `~/.time-tracker/`. Rounded out by `stop`, `pause`, `resume`, `status`, and `report`. | jq, git |

"Requires" lists what each plugin reaches for beyond Claude Code itself. MCP servers (Linear, Playwright) are configured in your Claude Code settings; `plan-design` reads the OpenAI key from your environment for image generation.

## Adding a Plugin

Each plugin lives in its own directory under `skills/`. Here's the structure:

```
skills/
└── your-plugin/
    ├── .claude-plugin/
    │   └── plugin.json        # Plugin manifest (required)
    ├── skills/                # Skills (optional)
    │   └── your-skill/
    │       └── SKILL.md
    ├── agents/                # Agents (optional)
    │   └── your-agent.md
    ├── commands/              # Slash commands (optional)
    │   └── your-command.md
    └── hooks/                 # Hooks (optional)
```

### 1. Create the plugin directory

```bash
mkdir -p skills/your-plugin/.claude-plugin
```

### 2. Add a plugin manifest

Create `skills/your-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "your-plugin",
  "description": "What your plugin does",
  "version": "1.0.0"
}
```

### 3. Add your components

Add skills, agents, commands, or hooks to their respective directories. See the [Claude Code plugin docs](https://docs.anthropic.com/en/docs/claude-code/plugins) for details on each component type.

### 4. Register it in the marketplace

Add an entry to `.claude-plugin/marketplace.json`:

```json
{
  "plugins": [
    {
      "name": "your-plugin",
      "source": "./skills/your-plugin",
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
2. Create your plugin under `skills/`
3. Add the marketplace entry to `.claude-plugin/marketplace.json`
4. Validate with `claude plugin validate .`
5. Open a pull request

Please keep plugins focused: one clear purpose per plugin.

## License

MIT
