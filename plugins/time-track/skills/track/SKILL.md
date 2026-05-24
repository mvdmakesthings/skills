---
name: track
description: Console-native billable hours tracker. Routes /track:start, /track:stop, /track:status, /track:report to a bash dispatcher that maintains a git-versioned JSONL ledger under ~/.time-tracker/. Use whenever the user invokes one of those slash commands. The skill itself does no time arithmetic, file I/O, or git work — the dispatcher does all of that. The skill's job is to construct the correct Bash invocation, especially for /track:stop where the user's note must be piped through stdin rather than passed as an argument (so shell metacharacters in the note cannot be interpreted).
---

# track skill

This skill is the safe-invocation wrapper around `bin/track.sh`. Its sole job is to translate one of the four `/track:*` slash commands into a `Bash` tool invocation that runs the dispatcher correctly. All ledger logic, locking, atomic writes, git commits, jq math, and error messages live in `bin/track.sh` — do not reimplement any of that here.

## Locating the dispatcher

The dispatcher lives at `${CLAUDE_PLUGIN_ROOT}/bin/track.sh`. If `$CLAUDE_PLUGIN_ROOT` is unset, fall back to the absolute path inferred from the SKILL.md location: `<plugin root>/bin/track.sh` where the plugin root is the parent of `skills/track/`. Either path resolves to the same script.

## Invocation patterns

For each subcommand, run the Bash tool with the exact command shape below. Do NOT add extra flags, do NOT pre-process arguments, do NOT interpret the output — print whatever the dispatcher prints, verbatim.

### /track:start

User invocation: `/track:start <client>` (with `$ARGUMENTS` containing the client name)

Bash invocation:
```
bash "${CLAUDE_PLUGIN_ROOT}/bin/track.sh" start <client>
```

The `<client>` argument is constrained by the dispatcher to alphanumeric + dash + underscore characters; it is safe to pass positionally.

### /track:stop

User invocation: `/track:stop [note...]` (with `$ARGUMENTS` containing the optional note)

**Critical: the note is piped through stdin, never passed as an argument.** This is a security boundary — the note is the only user-controlled input string in the system, and stdin-piping eliminates any possibility of shell metacharacter interpretation.

- If `$ARGUMENTS` is empty (no note provided):
  ```
  bash "${CLAUDE_PLUGIN_ROOT}/bin/track.sh" stop
  ```
- If `$ARGUMENTS` is non-empty (note provided):
  ```
  printf '%s' "<NOTE>" | bash "${CLAUDE_PLUGIN_ROOT}/bin/track.sh" stop
  ```
  where `<NOTE>` is the literal text of `$ARGUMENTS` quoted as a shell string. The `printf '%s'` (not `echo`) avoids any escape-sequence interpretation of the note content.

The dispatcher's `cmd_stop` checks `[ ! -t 0 ]` and reads stdin when present.

### /track:status

User invocation: `/track:status` (no arguments)

Bash invocation:
```
bash "${CLAUDE_PLUGIN_ROOT}/bin/track.sh" status
```

### /track:report

User invocation: `/track:report [--week | --month YYYY-MM] [--client <name>]` (with `$ARGUMENTS` containing the optional flags)

Bash invocation:
```
bash "${CLAUDE_PLUGIN_ROOT}/bin/track.sh" report $ARGUMENTS
```

Flag values are constrained by the dispatcher (regex check on `--month YYYY-MM` and the client name) and are safe to pass positionally.

## Output handling

Print the dispatcher's stdout and stderr verbatim. Do not summarize, do not reformat, do not add commentary. The dispatcher's output is designed to be the user-facing surface; wrapping it in chat prose adds noise.

If the dispatcher exits non-zero, surface that to the user — the error message is already user-facing and includes recovery instructions where applicable.
