## Why

The marketplace has zero plugins. Adding the first plugin (human-voice-writer) establishes the pattern for how skills get packaged and listed, and gives users something to install immediately.

## What Changes

- Add a new `human-voice-writer` plugin under `plugins/` with the standard plugin structure
- Create `plugin.json` manifest for the plugin
- Place the existing skill (SKILL.md + two reference files) into the plugin's `skills/` directory
- Register the plugin in `.claude-plugin/marketplace.json`

## Capabilities

### New Capabilities
- `plugin-packaging`: How a standalone skill gets structured as a marketplace plugin (directory layout, manifest, skill placement with references)
- `marketplace-registration`: How a plugin entry is added to the marketplace catalog

### Modified Capabilities

(none)

## Impact

- New directory tree: `plugins/human-voice-writer/`
- Modified file: `.claude-plugin/marketplace.json` (new entry in `plugins` array)
- No code changes, no dependency changes
