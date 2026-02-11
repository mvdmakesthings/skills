## ADDED Requirements

### Requirement: Plugin registered in marketplace catalog
The plugin SHALL have an entry in `.claude-plugin/marketplace.json` in the `plugins` array.

#### Scenario: Marketplace entry exists
- **WHEN** `.claude-plugin/marketplace.json` is read
- **THEN** the `plugins` array SHALL contain an entry for `human-voice-writer`

### Requirement: Marketplace source path is relative to pluginRoot
The `source` field in the marketplace entry SHALL be relative to the `pluginRoot` defined in `marketplace.json` metadata (which is `./plugins`).

#### Scenario: Source path resolves to plugin directory
- **WHEN** the marketplace entry has `"source": "human-voice-writer"`
- **THEN** combined with `pluginRoot: "./plugins"`, it SHALL resolve to `./plugins/human-voice-writer`
