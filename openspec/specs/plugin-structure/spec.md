## Requirements

### Requirement: Plugin directory location
Each plugin SHALL reside in its own directory under `plugins/` at the repository root.

#### Scenario: Standard plugin location
- **WHEN** a plugin named `my-plugin` exists
- **THEN** its root directory SHALL be `plugins/my-plugin/`

### Requirement: Plugin manifest required
Every plugin SHALL contain a `.claude-plugin/plugin.json` manifest at its root.

#### Scenario: Manifest present
- **WHEN** a plugin directory is inspected
- **THEN** `.claude-plugin/plugin.json` SHALL exist

### Requirement: Manifest fields
The `plugin.json` manifest SHALL include `name`, `description`, and `version` fields. The `version` SHALL be a valid semver string.

#### Scenario: Valid manifest contents
- **WHEN** `plugin.json` is read
- **THEN** it SHALL contain a `name` string, a `description` string, and a `version` string in semver format (e.g., `"1.0.0"`)

### Requirement: Directory naming convention
Plugin directory names SHALL use kebab-case.

#### Scenario: Kebab-case directory
- **WHEN** a plugin directory is created
- **THEN** its name SHALL consist of lowercase letters, numbers, and hyphens only (e.g., `human-voice-writer`)

### Requirement: Component directories
A plugin MAY contain any combination of `skills/`, `commands/`, `agents/`, and `hooks/` directories for its components.

#### Scenario: Optional component directories
- **WHEN** a plugin provides skills and commands but not agents or hooks
- **THEN** it SHALL have `skills/` and `commands/` directories, and MAY omit `agents/` and `hooks/`

### Requirement: At least one component
A plugin SHALL contain at least one component (a skill, command, agent, or hook).

#### Scenario: Minimum viable plugin
- **WHEN** a plugin directory is validated
- **THEN** at least one of `skills/`, `commands/`, `agents/`, or `hooks/` SHALL exist and contain at least one file
