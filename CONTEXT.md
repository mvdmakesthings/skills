# Skills Marketplace

A public catalog of Claude Code plugins that users install via the plugin marketplace. Each plugin bundles related skills — reusable Claude Code behaviors defined as SKILL.md files.

## Language

**Plugin**:
A named, installable unit in the marketplace. Contains one or more skills, optional commands, agents, hooks, and executables.
_Avoid_: Package, module, extension

**Skill**:
A reusable Claude Code behavior defined in a SKILL.md file. Triggers automatically or via a slash command.
_Avoid_: Tool, prompt, command (when referring to the behavior itself)

**Skill manifest (SKILL.md)**:
The file that defines a skill's trigger conditions, workflow, and reference materials.
_Avoid_: Skill file, prompt file

**Session log**:
A friction-log file written by `/skill-reflect` after a skill invocation. Captures what the skill had to improvise, user corrections, unanticipated edge cases, and proposed improvements. Stored in `~/.claude/skill-sessions/<plugin>/sessions/<skill-name>/` so logs accumulate across any project, not just the skills repo.
_Avoid_: Session transcript, run log

**Evolver**:
The `/skill-improve` skill. Reads accumulated session logs for a skill, identifies patterns, and proposes numbered changes to the SKILL.md.
_Avoid_: Optimizer, trainer, updater

**Improvement cycle**:
The full loop from session friction to SKILL.md update: reflect → accumulate session logs → improve → HITL approval → version bump + changelog.
_Avoid_: Training loop, optimization run

**HITL gate**:
The conversational approval step in `/skill-improve` where the user accepts, rejects, or edits each proposed change before anything is written.
_Avoid_: Review step, approval flow

**Bundle**:
The set of skills shipped together inside a single plugin. A plugin is the installable unit; a bundle is the collection of skills it contains.
_Avoid_: Collection, group

**Dev materials**:
Local-only files under `_dev/<plugin>/` — tests, docs, evals, session logs. Not shipped on install.
_Avoid_: Dev artifacts, local files
