# claude-marketplace

A curated collection of plugins, skills, and agents for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Install

> Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.33 or later.

Add the marketplace:

```
/plugin marketplace add mvdmakesthings/claude-marketplace
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

| Plugin | Command | Description | Example |
|--------|---------|-------------|---------|
| `writer` | `/writer:human [prompt]` | Write prose that sounds authentically human. | [Before & After](plugins/human-voice-writer/examples/before-after.md) |
| `track` | `/track:start <client>` | Console-native billable hours tracker. Git-versioned plaintext ledger under `~/.time-tracker/`. | [README](plugins/time-track/README.md) |

## Using Skills in Claude.ai / Claude Desktop

Skills from this marketplace can also be used in Claude.ai and Claude Desktop (no CLI required).

1. Go to the [Releases](../../releases) page
2. Download the `.skill` file for the skill you want (e.g., `human-voice-writer.skill`)
3. In Claude.ai or Claude Desktop, go to **Settings > Capabilities**
4. Upload the `.skill` file

Each release automatically packages every skill in the marketplace as a standalone `.skill` file.

## Adding a Plugin

Each plugin lives in its own directory under `plugins/`. Here's the structure:

```
plugins/
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

Add skills, agents, commands, or hooks to their respective directories. See the [Claude Code plugin docs](https://code.claude.com/docs/en/plugins) for details on each component type.

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

### 5. Test locally

```
/plugin marketplace add ./path/to/claude-marketplace
/plugin install your-plugin@mvdmakesthings
```

## Contributing

1. Fork this repository
2. Create your plugin under `plugins/`
3. Add the marketplace entry to `.claude-plugin/marketplace.json`
4. Test locally
5. Open a pull request

Please keep plugins focused — one clear purpose per plugin.

## License

MIT
