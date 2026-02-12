## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Release summary generation step
The workflow SHALL include a step that generates a markdown summary file from repository contents and git history before creating the release.

#### Scenario: Summary file is generated
- **WHEN** the summary generation step runs
- **THEN** it SHALL produce a markdown file containing the release version, available plugins, packaged skills, and notable changes

#### Scenario: Summary is passed to release creation
- **WHEN** the release is created
- **THEN** the summary file SHALL be passed via `body_path` to the release action so it appears as the release body above the auto-generated notes
