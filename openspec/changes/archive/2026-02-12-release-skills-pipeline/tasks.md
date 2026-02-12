## 1. GitHub Actions Workflow

- [x] 1.1 Create `.github/workflows/release-skills.yml` with `v*` tag trigger and `contents: write` permission
- [x] 1.2 Add checkout step using `actions/checkout@v4`
- [x] 1.3 Add skill discovery and packaging step that globs `plugins/*/skills/*/SKILL.md`, zips each skill directory into `dist/<skill-name>.skill`
- [x] 1.4 Add release creation step using `softprops/action-gh-release@v2` with `generate_release_notes: true` and `files: dist/*.skill`

## 2. README Update

- [x] 2.1 Add "Using Skills in Claude.ai / Claude Desktop" section to README.md with download and upload instructions
