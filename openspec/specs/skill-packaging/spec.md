## Requirements

### Requirement: Skill file location
Skills SHALL live in `skills/<skill-name>/SKILL.md` within the plugin directory.

#### Scenario: Standard skill location
- **WHEN** a plugin has a skill named `human-voice-writer`
- **THEN** the skill file SHALL be at `skills/human-voice-writer/SKILL.md`

### Requirement: YAML frontmatter
Each SKILL.md SHALL contain YAML frontmatter with at least `name` and `description` fields.

#### Scenario: Valid frontmatter
- **WHEN** a SKILL.md file is read
- **THEN** it SHALL have YAML frontmatter containing a `name` string and a `description` string

### Requirement: Directory naming convention
Skill directory names SHALL use kebab-case and SHOULD match the `name` field in the SKILL.md frontmatter.

#### Scenario: Consistent naming
- **WHEN** a skill directory is named `human-voice-writer`
- **THEN** the SKILL.md frontmatter `name` SHOULD be `human-voice-writer`

### Requirement: Reference files
Reference files used by a skill SHALL be stored as siblings (e.g., in a `references/` directory) and referenced using relative paths from SKILL.md.

#### Scenario: Relative reference paths
- **WHEN** SKILL.md references `references/ai-tells.md`
- **THEN** the file SHALL exist at `skills/<skill-name>/references/ai-tells.md` and the path SHALL resolve relative to SKILL.md's location
