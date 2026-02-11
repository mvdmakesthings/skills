## Requirements

### Requirement: Catalog location
The marketplace catalog SHALL be located at `.claude-plugin/marketplace.json` at the repository root.

#### Scenario: Catalog file exists
- **WHEN** the repository is inspected
- **THEN** `.claude-plugin/marketplace.json` SHALL exist

### Requirement: Top-level catalog fields
The catalog SHALL contain `name`, `owner`, `metadata`, and `plugins` fields at the top level.

#### Scenario: Required top-level fields
- **WHEN** `marketplace.json` is read
- **THEN** it SHALL contain a `name` string (the marketplace identifier), an `owner` object, a `metadata` object, and a `plugins` array

### Requirement: Plugin entry fields
Each entry in the `plugins` array SHALL contain `name`, `description`, and `source` fields.

#### Scenario: Valid plugin entry
- **WHEN** a plugin entry is inspected
- **THEN** it SHALL have a `name` string, a `description` string, and a `source` string

### Requirement: Source path format
The `source` field SHALL be a relative path from the repository root to the plugin directory.

#### Scenario: Source path resolves correctly
- **WHEN** a plugin entry has `"source": "./plugins/my-plugin"`
- **THEN** the path SHALL resolve to the `plugins/my-plugin/` directory from the repository root

### Requirement: Name consistency
The `name` field in a plugin entry SHALL match the `name` field in that plugin's `plugin.json` manifest.

#### Scenario: Matching names
- **WHEN** a marketplace entry has `"name": "writer"`
- **THEN** the corresponding `plugin.json` SHALL also have `"name": "writer"`
