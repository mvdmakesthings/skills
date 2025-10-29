#!/bin/bash
#
# Build Claude skills into .skill archives
#
# This script:
# - Finds all skill directories (excluding template-skill and hidden dirs)
# - Extracts version from each SKILL.md
# - Creates versioned .skill archives (zip files)
# - Outputs JSON array of built skills to stdout
#
# Usage:
#   ./build-skills.sh
#
# Output format (JSON):
#   [
#     {"name": "skill-name", "version": "1.0.0", "file": "skill-name-v1.0.0.skill"},
#     ...
#   ]

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Path to extract-version.py
EXTRACT_VERSION="$SCRIPT_DIR/extract-version.py"

# Build directory
BUILD_DIR="$REPO_ROOT/dist"
mkdir -p "$BUILD_DIR"

# Initialize JSON array
SKILLS_JSON="[]"

echo "::group::Building skill archives" >&2
echo "Repository: $REPO_ROOT" >&2
echo "Build directory: $BUILD_DIR" >&2
echo "" >&2

# Change to repository root
cd "$REPO_ROOT"

# Find all skill directories
for skill_dir in */; do
  skill_name="${skill_dir%/}"

  # Skip template-skill, .github, .claude-plugin, and hidden directories
  if [[ "$skill_name" == "template-skill" ]] || \
     [[ "$skill_name" == ".github" ]] || \
     [[ "$skill_name" == ".claude-plugin" ]] || \
     [[ "$skill_name" == dist ]] || \
     [[ "$skill_name" == .* ]]; then
    echo "Skipping: $skill_name" >&2
    continue
  fi

  # Check if SKILL.md exists
  if [[ ! -f "$skill_name/SKILL.md" ]]; then
    echo "Skipping: $skill_name (no SKILL.md)" >&2
    continue
  fi

  echo "Processing skill: $skill_name" >&2

  # Extract version using Python script
  version=$(python3 "$EXTRACT_VERSION" "$skill_name/SKILL.md" 2>/dev/null || echo "0.0.0")

  if [[ -z "$version" ]] || [[ "$version" == "0.0.0" ]]; then
    echo "  Warning: Failed to extract version, using 0.0.0" >&2
    version="0.0.0"
  fi

  echo "  Version: $version" >&2

  # Create versioned filename
  archive_name="${skill_name}-v${version}.skill"
  archive_path="$BUILD_DIR/$archive_name"

  # Create zip archive with all files in the skill directory
  # Exclude any existing .skill files to avoid nesting
  echo "  Creating archive: $archive_name" >&2
  (
    cd "$skill_name"
    zip -r "$archive_path" . -x "*.skill" >/dev/null
  )

  # Verify archive was created
  if [[ -f "$archive_path" ]]; then
    size=$(ls -lh "$archive_path" | awk '{print $5}')
    echo "  ✓ Created $archive_name ($size)" >&2

    # Add to skills JSON array using jq
    SKILLS_JSON=$(echo "$SKILLS_JSON" | jq \
      --arg name "$skill_name" \
      --arg version "$version" \
      --arg file "$archive_name" \
      '. += [{name: $name, version: $version, file: $file}]')
  else
    echo "  ✗ Failed to create $archive_name" >&2
    exit 1
  fi

  echo "" >&2
done

# Count and display summary
skill_count=$(echo "$SKILLS_JSON" | jq length)
echo "::notice::Built $skill_count skill archive(s)" >&2
echo "::endgroup::" >&2

# Output JSON to stdout (for GitHub Actions to capture)
echo "$SKILLS_JSON"
