## ADDED Requirements

### Requirement: Plugin directory structure
The plugin SHALL have a `.claude-plugin/plugin.json` manifest at its root and a `skills/` directory containing the skill and its reference materials.

#### Scenario: Valid plugin directory
- **WHEN** the plugin directory `plugins/human-voice-writer/` is created
- **THEN** it SHALL contain `.claude-plugin/plugin.json`, `skills/human-voice-writer/SKILL.md`, `skills/human-voice-writer/references/ai-tells.md`, and `skills/human-voice-writer/references/humanization-techniques.md`

### Requirement: Plugin manifest contents
The `plugin.json` manifest SHALL include `name`, `description`, and `version` fields. The `name` MUST be `human-voice-writer`.

#### Scenario: Valid manifest
- **WHEN** `plugins/human-voice-writer/.claude-plugin/plugin.json` is read
- **THEN** it SHALL contain a `name` field set to `"human-voice-writer"`, a `description` field describing the skill's purpose, and a `version` field with a semver value

### Requirement: Skill content preserved verbatim
The SKILL.md and both reference files SHALL be copied from the source archive without modification.

#### Scenario: Unmodified skill content
- **WHEN** the skill files are placed in the plugin
- **THEN** their content SHALL match the original files from the `.skill` archive exactly

### Requirement: Relative reference paths resolve correctly
The SKILL.md references `references/ai-tells.md` and `references/humanization-techniques.md` using relative paths. The `references/` directory MUST be a sibling of SKILL.md so these paths resolve.

#### Scenario: Reference path resolution
- **WHEN** SKILL.md is at `skills/human-voice-writer/SKILL.md`
- **THEN** `references/ai-tells.md` SHALL resolve to `skills/human-voice-writer/references/ai-tells.md`
