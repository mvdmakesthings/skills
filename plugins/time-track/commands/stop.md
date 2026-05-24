---
description: Stop the active timer, optionally with a note that describes the session.
argument-hint: "[note...]"
---

# Track: Stop

Use the Skill tool to invoke the `track` skill with the subcommand `stop` and arguments `$ARGUMENTS`.

The arguments (if any) are the session note. The skill will pipe the note to the dispatcher through stdin so shell metacharacters in the note never get evaluated.
