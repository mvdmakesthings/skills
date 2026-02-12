## 1. Summary Generation Step

- [x] 1.1 Add a workflow step that determines the previous `v*` tag (or detects first release)
- [x] 1.2 Generate a "What's Included" section listing plugins from `marketplace.json` and packaged `.skill` files
- [x] 1.3 Generate a "What Changed" section from `git log` between the previous tag and current tag (or "Initial release" if no previous tag)
- [x] 1.4 Write the combined markdown summary to a file (e.g., `dist/release-body.md`)

## 2. Release Creation Update

- [x] 2.1 Update the `softprops/action-gh-release` step to pass the summary file via `body_path` while keeping `generate_release_notes: true`
