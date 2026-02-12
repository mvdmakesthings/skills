## Requirements

### Requirement: Workflow trigger on version tags
The release workflow SHALL trigger on Git tag pushes matching the pattern `v*`.

#### Scenario: Tag push triggers workflow
- **WHEN** a tag matching `v*` (e.g., `v1.0.1`) is pushed to the repository
- **THEN** the release-skills workflow SHALL execute

#### Scenario: Non-tag push does not trigger
- **WHEN** a commit is pushed to any branch without a `v*` tag
- **THEN** the release-skills workflow SHALL NOT execute

### Requirement: Automatic skill discovery
The workflow SHALL discover all skills by globbing for `plugins/*/skills/*/SKILL.md` across the repository.

#### Scenario: Single skill exists
- **WHEN** the repository contains `plugins/human-voice-writer/skills/human-voice-writer/SKILL.md`
- **THEN** the workflow SHALL find and package the `human-voice-writer` skill

#### Scenario: Multiple skills across plugins
- **WHEN** the repository contains skills in multiple plugin directories
- **THEN** the workflow SHALL find and package each skill independently

#### Scenario: No skills exist
- **WHEN** no files match `plugins/*/skills/*/SKILL.md`
- **THEN** the workflow SHALL proceed without error and create a release with no `.skill` attachments

### Requirement: Skill packaging format
Each discovered skill SHALL be packaged as a ZIP file with the `.skill` extension, containing the skill directory as the root entry.

#### Scenario: Correct ZIP structure
- **WHEN** the skill `human-voice-writer` is packaged
- **THEN** the resulting `human-voice-writer.skill` file SHALL be a ZIP archive containing `human-voice-writer/` as the root, with `SKILL.md` and all sibling files (e.g., `references/`) inside it

#### Scenario: No plugin metadata included
- **WHEN** a skill is packaged
- **THEN** the `.skill` file SHALL NOT contain `plugin.json`, command files, or any files outside the skill directory

### Requirement: GitHub Release creation
The workflow SHALL create a GitHub Release for the pushed tag with auto-generated release notes and all `.skill` files attached.

#### Scenario: Release with skill attachments
- **WHEN** the workflow packages one or more skills
- **THEN** a GitHub Release SHALL be created for the tag with auto-generated release notes and all `.skill` files attached as release assets

### Requirement: README documents skill download
The README SHALL include instructions for downloading `.skill` files from the Releases page and uploading them to Claude.ai or Claude Desktop.

#### Scenario: Download instructions present
- **WHEN** a user reads the README
- **THEN** they SHALL find a section explaining how to download `.skill` files from Releases and upload them via Settings > Capabilities in Claude.ai or Claude Desktop
