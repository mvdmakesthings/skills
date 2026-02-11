## Context

The `human-voice-writer` plugin currently contains only a skill. The plugin name is `human-voice-writer`, which means commands in its `commands/` directory are namespaced as `/human-voice-writer:<command>`. The user wants the command invoked as `/writer:human`.

Claude Code derives the command namespace from the plugin `name` field in `plugin.json`. To get `/writer:human`, the plugin name needs to be `writer` and the command file needs to be `human.md`.

## Goals / Non-Goals

**Goals:**
- Add a `/writer:human [prompt]` command that invokes the human-voice-writer skill
- Make the command namespace clean and intuitive (`/writer:human`)

**Non-Goals:**
- Changing the skill content
- Adding other commands to this plugin yet

## Decisions

**1. Rename plugin to `writer` in plugin.json**
The command namespace comes from the plugin name. To get `/writer:human`, the plugin `name` field must be `writer`. This also changes how users install the plugin (`/plugin install writer@mvdmakesthings` instead of `human-voice-writer@mvdmakesthings`).

Alternative considered: Keep `human-voice-writer` as the plugin name, yielding `/human-voice-writer:human`. Rejected because it's verbose and the user explicitly wants `/writer:human`.

**2. Command file at `commands/human.md`**
The command name comes from the filename. `human.md` yields `:human` in the namespace.

**3. Command invokes the skill via the Skill tool**
The command body instructs Claude to load the `human-voice-writer` skill using the Skill tool, then apply it to `$ARGUMENTS`.

**4. Update marketplace.json to match the new plugin name**
The `name` field in the marketplace entry must match the plugin name for consistency.

## Risks / Trade-offs

**[Plugin rename]** Changing the plugin name from `human-voice-writer` to `writer` is broader (could accommodate future writing commands like `/writer:technical`, `/writer:copy`). But if the user only ever ships one writing skill, the name is slightly less descriptive. This trade-off favors the user's explicit request for `/writer:human`.
