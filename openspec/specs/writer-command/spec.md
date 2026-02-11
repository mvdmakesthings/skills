## ADDED Requirements

### Requirement: Command file exists
The plugin SHALL have a command file at `plugins/human-voice-writer/commands/human.md` with valid YAML frontmatter.

#### Scenario: Command file present
- **WHEN** the plugin directory is inspected
- **THEN** `commands/human.md` SHALL exist with `description` and `argument-hint` frontmatter fields

### Requirement: Command namespace resolves to /writer:human
The plugin `name` field in `plugin.json` SHALL be `writer` so that the command namespace resolves to `/writer:human`.

#### Scenario: Plugin name yields correct namespace
- **WHEN** `plugin.json` has `"name": "writer"`
- **THEN** the command file `commands/human.md` SHALL be invocable as `/writer:human`

### Requirement: Command accepts prompt argument
The command SHALL accept a `[prompt]` argument via `$ARGUMENTS` and pass it to the human-voice-writer skill.

#### Scenario: User provides prompt text
- **WHEN** user types `/writer:human Write me a blog post about testing`
- **THEN** `$ARGUMENTS` SHALL contain `Write me a blog post about testing` and the skill SHALL be invoked with that text

#### Scenario: User provides no argument
- **WHEN** user types `/writer:human` with no arguments
- **THEN** the command SHALL still invoke the skill (the skill handles the interaction from there)

### Requirement: Command invokes human-voice-writer skill
The command body SHALL instruct Claude to load and apply the `human-voice-writer` skill using the Skill tool.

#### Scenario: Skill is loaded
- **WHEN** the command executes
- **THEN** the Skill tool SHALL be called with `skill: "human-voice-writer"`

### Requirement: Marketplace entry reflects updated plugin name
The marketplace entry in `.claude-plugin/marketplace.json` SHALL use `"name": "writer"` to match the plugin manifest.

#### Scenario: Marketplace name matches plugin name
- **WHEN** `.claude-plugin/marketplace.json` is read
- **THEN** the plugin entry SHALL have `"name": "writer"`
