## 1. Plugin Rename

- [x] 1.1 Update `name` field in `plugins/human-voice-writer/.claude-plugin/plugin.json` from `"human-voice-writer"` to `"writer"`
- [x] 1.2 Update `name` field in `.claude-plugin/marketplace.json` plugin entry from `"human-voice-writer"` to `"writer"`

## 2. Command File

- [x] 2.1 Create `plugins/human-voice-writer/commands/` directory
- [x] 2.2 Create `plugins/human-voice-writer/commands/human.md` with frontmatter (`description`, `argument-hint`) and body that invokes the human-voice-writer skill via the Skill tool with `$ARGUMENTS`
