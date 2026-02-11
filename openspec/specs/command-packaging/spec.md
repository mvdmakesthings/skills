## Requirements

### Requirement: Command file location
Commands SHALL live in `commands/<name>.md` within the plugin directory.

#### Scenario: Standard command location
- **WHEN** a plugin has a command named `human`
- **THEN** the command file SHALL be at `commands/human.md`

### Requirement: YAML frontmatter
Each command file SHALL contain YAML frontmatter with a `description` field (required) and MAY include an `argument-hint` field (optional).

#### Scenario: Valid frontmatter
- **WHEN** a command file is read
- **THEN** it SHALL have YAML frontmatter containing a `description` string

#### Scenario: Frontmatter with argument hint
- **WHEN** a command accepts arguments
- **THEN** it MAY include an `argument-hint` field (e.g., `"[prompt]"`) describing expected input

### Requirement: Command namespace
The command namespace SHALL be `/<plugin-name>:<filename>` where `plugin-name` comes from the plugin's `plugin.json` `name` field and `filename` is the command file name without the `.md` extension.

#### Scenario: Namespace resolution
- **WHEN** `plugin.json` has `"name": "writer"` and the command file is `commands/human.md`
- **THEN** the command SHALL be invocable as `/writer:human`

### Requirement: Argument passing
Commands SHALL receive user-provided arguments via the `$ARGUMENTS` variable.

#### Scenario: User provides arguments
- **WHEN** a user types `/writer:human Write a blog post`
- **THEN** `$ARGUMENTS` SHALL contain `Write a blog post`

#### Scenario: No arguments provided
- **WHEN** a user types `/writer:human` with no arguments
- **THEN** `$ARGUMENTS` SHALL be empty and the command SHALL still execute

### Requirement: Skill invocation
When a command delegates to a skill, it SHALL invoke the skill using the Skill tool.

#### Scenario: Command invokes skill
- **WHEN** a command body instructs Claude to use a skill
- **THEN** it SHALL use the Skill tool with the skill name (e.g., `skill: "human-voice-writer"`)
