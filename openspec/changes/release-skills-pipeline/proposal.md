## Why

The marketplace distributes plugins via Claude Code CLI, but skills can also be used in Claude.ai and Claude Desktop by uploading a `.skill` ZIP file via Settings > Capabilities. There is no automated way to package and distribute skills for these non-CLI audiences. A release pipeline that extracts skills and attaches them to GitHub Releases lets both audiences be served from the same repo.

## What Changes

- Add a GitHub Actions workflow that triggers on `v*` tag pushes, finds all skills across all plugins, packages each as a `.skill` file (ZIP with skill folder at root), and attaches them to a GitHub Release with auto-generated notes.
- Update README.md with download and install instructions for Claude.ai/Desktop users.

## Capabilities

### New Capabilities
- `skill-release-pipeline`: GitHub Actions workflow that packages skills as `.skill` files and attaches them to GitHub Releases on tag push.

### Modified Capabilities

_(none)_

## Impact

- **New file:** `.github/workflows/release-skills.yml`
- **Modified file:** `README.md` (new section for Claude.ai/Desktop download instructions)
- No changes to existing plugin structure, marketplace catalog, or skill content.
