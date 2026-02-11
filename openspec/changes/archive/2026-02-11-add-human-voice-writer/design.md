## Context

The marketplace repo is freshly scaffolded with an empty `plugins` array in `marketplace.json` and no plugin directories yet. A pre-built skill (`human-voice-writer`) exists as a `.skill` archive containing a SKILL.md and two reference files. It needs to be packaged as a plugin and registered in the catalog.

## Goals / Non-Goals

**Goals:**
- Package the human-voice-writer skill as a valid marketplace plugin
- Register it in marketplace.json so it's discoverable
- Establish the pattern future plugins will follow

**Non-Goals:**
- Modifying the skill content itself (ship as-is)
- Adding commands, agents, or hooks to this plugin
- Building any tooling or automation around plugin creation

## Decisions

**1. Plugin name matches skill name: `human-voice-writer`**
Rationale: The skill is the sole component of this plugin. Using the same name avoids confusion. If more writing skills were added later, we'd create a separate umbrella plugin rather than rename this one.

**2. Directory layout follows CLAUDE.md conventions exactly**
```
plugins/human-voice-writer/
  .claude-plugin/plugin.json
  skills/human-voice-writer/
    SKILL.md
    references/
      ai-tells.md
      humanization-techniques.md
```
Rationale: The CLAUDE.md specifies the structure. The skill's `references/` directory sits alongside SKILL.md so relative paths (`references/ai-tells.md`) resolve without changes.

**3. Copy files from extracted archive, don't modify content**
Rationale: The skill is well-built and tested. No reason to alter it during packaging.

**4. Marketplace entry uses minimal required fields**
Rationale: Match the existing marketplace.json structure. The `source` field uses a path relative to `pluginRoot` (which is `./plugins`), so the value is just `human-voice-writer`.

## Risks / Trade-offs

**[Relative path resolution]** The SKILL.md references `references/ai-tells.md` and `references/humanization-techniques.md`. These paths are relative to the skill file location. Placing references alongside SKILL.md under `skills/human-voice-writer/` preserves this. No mitigation needed beyond correct placement.
