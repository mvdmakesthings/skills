#!/usr/bin/env python3
"""
Extract version from SKILL.md frontmatter.

Usage:
    python extract-version.py <path-to-SKILL.md>

Outputs:
    Version string (e.g., "1.0.0") to stdout
    Exits with code 0 on success, 1 on failure
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("0.0.0", file=sys.stderr)
    sys.exit(1)


def extract_version(skill_md_path: Path) -> str:
    """
    Extract version from SKILL.md YAML frontmatter.

    Args:
        skill_md_path: Path to SKILL.md file

    Returns:
        Version string, or "0.0.0" if not found
    """
    try:
        content = skill_md_path.read_text(encoding='utf-8')
    except Exception as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        return "0.0.0"

    # Extract YAML frontmatter between --- delimiters
    pattern = r'^---\s*\n(.*?)\n---\s*\n'
    match = re.match(pattern, content, re.DOTALL)

    if not match:
        print("No YAML frontmatter found", file=sys.stderr)
        return "0.0.0"

    try:
        frontmatter = yaml.safe_load(match.group(1))
        if not frontmatter:
            return "0.0.0"

        version = frontmatter.get('version', '0.0.0')
        return str(version)
    except yaml.YAMLError as e:
        print(f"YAML parsing error: {e}", file=sys.stderr)
        return "0.0.0"


def main():
    """Main entry point."""
    if len(sys.argv) != 2:
        print("Usage: extract-version.py <path-to-SKILL.md>", file=sys.stderr)
        sys.exit(1)

    skill_md_path = Path(sys.argv[1])

    if not skill_md_path.exists():
        print(f"File not found: {skill_md_path}", file=sys.stderr)
        sys.exit(1)

    version = extract_version(skill_md_path)
    print(version)
    sys.exit(0)


if __name__ == "__main__":
    main()
