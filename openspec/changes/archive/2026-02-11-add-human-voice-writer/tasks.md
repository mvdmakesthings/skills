## 1. Plugin Directory Structure

- [x] 1.1 Create directory tree: `plugins/human-voice-writer/.claude-plugin/`, `plugins/human-voice-writer/skills/human-voice-writer/references/`
- [x] 1.2 Create `plugins/human-voice-writer/.claude-plugin/plugin.json` with name, description, and version fields

## 2. Skill Files

- [x] 2.1 Copy `SKILL.md` from extracted archive to `plugins/human-voice-writer/skills/human-voice-writer/SKILL.md`
- [x] 2.2 Copy `references/ai-tells.md` to `plugins/human-voice-writer/skills/human-voice-writer/references/ai-tells.md`
- [x] 2.3 Copy `references/humanization-techniques.md` to `plugins/human-voice-writer/skills/human-voice-writer/references/humanization-techniques.md`

## 3. Marketplace Registration

- [x] 3.1 Add plugin entry to `.claude-plugin/marketplace.json` `plugins` array with `source: "human-voice-writer"`
