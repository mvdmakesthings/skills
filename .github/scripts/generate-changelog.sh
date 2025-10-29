#!/bin/bash
#
# Generate changelog for release
#
# This script:
# - Generates a changelog from git commits since the previous release
# - Adds a list of skills included in this release
# - Outputs markdown-formatted changelog to stdout
#
# Usage:
#   ./generate-changelog.sh <current-tag> <skills-json>
#
# Arguments:
#   current-tag: The current release tag (e.g., "v1.0.0")
#   skills-json: JSON array of skills (from build-skills.sh output)
#
# Example:
#   ./generate-changelog.sh v1.0.0 '[{"name":"skill1","version":"1.0.0","file":"skill1-v1.0.0.skill"}]'

set -euo pipefail

# Check arguments
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <current-tag> <skills-json>" >&2
  exit 1
fi

CURRENT_TAG="$1"
SKILLS_JSON="$2"

echo "::group::Generating changelog" >&2

# Get previous release tag
if git rev-parse "$CURRENT_TAG" >/dev/null 2>&1; then
  PREV_TAG=$(git describe --tags --abbrev=0 "$CURRENT_TAG^" 2>/dev/null)
else
  # If CURRENT_TAG doesn't exist yet, fallback to previous tag from HEAD
  PREV_TAG=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || git rev-list --max-parents=0 HEAD)
fi

echo "Previous tag: $PREV_TAG" >&2
echo "Current tag: $CURRENT_TAG" >&2

# Start building changelog
CHANGELOG="## What's Changed"
CHANGELOG+=$'\n\n'

# Get commits since last release
COMMITS=$(git log "$PREV_TAG..$CURRENT_TAG" --pretty=format:"- %s (%h)" --reverse 2>/dev/null || echo "")

if [[ -n "$COMMITS" ]]; then
  CHANGELOG+="$COMMITS"
  CHANGELOG+=$'\n\n'
else
  CHANGELOG+="- Initial release"
  CHANGELOG+=$'\n\n'
fi

# Add skills section
CHANGELOG+="## Skills in this Release"
CHANGELOG+=$'\n\n'

# Parse skills JSON and add to changelog
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r line; do
    CHANGELOG+="$line"
    CHANGELOG+=$'\n'
  done < <(echo "$SKILLS_JSON" | jq -r '.[] | "- **\(.name)** v\(.version) (`\(.file)`)"')
else
  # Fallback if jq is not available
  echo "Warning: jq not found, skills list will be basic" >&2
  CHANGELOG+="Skills built successfully"
  CHANGELOG+=$'\n'
fi

echo "::endgroup::" >&2

# Output changelog to stdout
echo "$CHANGELOG"
