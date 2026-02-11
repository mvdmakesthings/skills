## Why

The human-voice-writer skill currently relies on Claude auto-detecting when to invoke it. A `/writer:human` slash command gives users a direct, memorable way to invoke it on demand with a prompt argument.

## What Changes

- Add a `commands/` directory to the `human-voice-writer` plugin
- Create a `human.md` command file that accepts a `[prompt]` argument and invokes the human-voice-writer skill

## Capabilities

### New Capabilities
- `writer-command`: A slash command (`/writer:human`) that invokes the human-voice-writer skill with user-provided prompt text

### Modified Capabilities

(none)

## Impact

- New file: `plugins/human-voice-writer/commands/human.md`
- No changes to existing skill files or plugin manifest
