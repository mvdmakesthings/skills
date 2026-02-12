## Why

The current release workflow uses GitHub's auto-generated release notes, which are just a list of commit SHAs and messages. For a plugin marketplace, users need a human-readable summary that tells them what plugins or skills were added, changed, or updated — not raw commit history.

## What Changes

- Add a structured release body to the GitHub Release that summarizes what's included: plugins available, skills packaged, and notable changes since the last release.
- Generate the summary as a workflow step before creating the release, using commit history and repo contents to build the body.
- Keep `generate_release_notes: true` so the raw commit log is still appended for developers, but prepend it with the human-readable summary.

## Capabilities

### New Capabilities

_(none — this enhances the existing release pipeline)_

### Modified Capabilities

- `skill-release-pipeline`: The GitHub Release creation requirement changes to include a human-readable summary body alongside auto-generated notes.

## Impact

- **Modified file:** `.github/workflows/release-skills.yml` (new step to generate release body, updated release creation step)
- No changes to skill packaging, plugin structure, or README.
