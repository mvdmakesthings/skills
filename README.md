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

| Plugin | Command | Description |
|--------|---------|-------------|
| `qa` | `/qa [issue-id]` | Software QA: reviews current changes against a Linear issue, runs tests, screenshots the UI with Playwright, and posts a pass/fail report with screenshots as a Linear comment. |
| `plan-design` | `/plan-design <issue-id>` | Design planning: reads your DESIGN.md and a Linear issue, interviews you on key decisions, generates three layout mockups via DALL-E, lets you pick one, then produces an HTML/CSS implementation and attaches all assets to Linear. |
| `grill-with-docs` | `/grill-with-docs` | Stress-tests a plan against your project's domain model. Challenges terminology, resolves design decisions one at a time, and updates CONTEXT.md and ADRs inline as decisions crystallise. |
| `to-issues` | `/to-issues` | Breaks a plan, spec, or PRD into independently-grabbable Linear issues using tracer-bullet vertical slices. |
| `to-prd` | `/to-prd` | Turns the current conversation context into a PRD and publishes it to Linear. |
| `writer` | `/writer:human [prompt]` | Writes prose that sounds authentically human rather than AI-generated. |
| `storyteller-guidance` | auto-triggers on pitch / talk / memo phrasing | Storytelling coach. Diagnoses your goal, picks tactics from a 54-card system, drafts or coaches. |
| `track` | `/track:start <client>` | Console-native billable hours tracker. Git-versioned plaintext ledger under `~/.time-tracker/`. |

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

Please keep plugins focused — one clear purpose per plugin.

## License

MIT
