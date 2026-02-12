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
The workflow SHALL create a GitHub Release for the pushed tag with a human-readable summary body, auto-generated release notes, and all `.skill` files attached.

#### Scenario: Release with skill attachments
- **WHEN** the workflow packages one or more skills
- **THEN** a GitHub Release SHALL be created for the tag with a human-readable summary, auto-generated release notes, and all `.skill` files attached as release assets

#### Scenario: Release summary lists available plugins and skills
- **WHEN** the release summary is generated
- **THEN** it SHALL include a "What's Included" section listing each plugin from `marketplace.json` and each packaged `.skill` file

#### Scenario: Release summary lists changes since last tag
- **WHEN** a previous `v*` tag exists
- **THEN** the release summary SHALL include a "What Changed" section with notable changes derived from commits between the previous tag and the current tag

#### Scenario: First release has no previous tag
- **WHEN** no previous `v*` tag exists
- **THEN** the release summary SHALL indicate this is the initial release and omit the "What Changed" section

### Requirement: Release summary generation step
The workflow SHALL include a step that generates a markdown summary file from repository contents and git history before creating the release.

#### Scenario: Summary file is generated
- **WHEN** the summary generation step runs
- **THEN** it SHALL produce a markdown file containing the release version, available plugins, packaged skills, and notable changes

#### Scenario: Summary is passed to release creation
- **WHEN** the release is created
- **THEN** the summary file SHALL be passed via `body_path` to the release action so it appears as the release body above the auto-generated notes

### Requirement: README documents skill download
The README SHALL include instructions for downloading `.skill` files from the Releases page and uploading them to Claude.ai or Claude Desktop.

#### Scenario: Download instructions present
- **WHEN** a user reads the README
- **THEN** they SHALL find a section explaining how to download `.skill` files from Releases and upload them via Settings > Capabilities in Claude.ai or Claude Desktop
