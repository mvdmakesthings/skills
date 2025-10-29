#!/usr/bin/env python3
"""
Validate Claude skills for CI/CD pipeline.

This script validates:
- SKILL.md YAML frontmatter in each skill directory
- Required fields: name, description, version
- Semantic versioning format
- marketplace.json structure
- Skill directory consistency with marketplace.json
"""

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install PyYAML")
    sys.exit(1)


class Colors:
    """ANSI color codes for terminal output."""
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def print_error(message: str) -> None:
    """Print error message in red."""
    print(f"{Colors.RED}✗ ERROR: {message}{Colors.RESET}")


def print_success(message: str) -> None:
    """Print success message in green."""
    print(f"{Colors.GREEN}✓ {message}{Colors.RESET}")


def print_info(message: str) -> None:
    """Print info message in blue."""
    print(f"{Colors.BLUE}ℹ {message}{Colors.RESET}")


def print_warning(message: str) -> None:
    """Print warning message in yellow."""
    print(f"{Colors.YELLOW}⚠ WARNING: {message}{Colors.RESET}")


def is_valid_semver(version: str) -> bool:
    """
    Validate semantic version format (e.g., 1.0.0, 2.1.3-beta, 1.0.0+build).

    Args:
        version: Version string to validate

    Returns:
        True if valid semver, False otherwise
    """
    semver_pattern = r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
    return bool(re.match(semver_pattern, version))


def is_valid_kebab_case(name: str) -> bool:
    """
    Validate kebab-case format (lowercase with hyphens).

    Args:
        name: Name string to validate

    Returns:
        True if valid kebab-case, False otherwise
    """
    kebab_pattern = r'^[a-z][a-z0-9]*(-[a-z0-9]+)*$'
    return bool(re.match(kebab_pattern, name))


def extract_frontmatter(content: str) -> Tuple[Dict, bool]:
    """
    Extract YAML frontmatter from markdown content.

    Args:
        content: Markdown file content

    Returns:
        Tuple of (frontmatter dict, success boolean)
    """
    # Match YAML frontmatter between --- delimiters
    pattern = r'^---\s*\n(.*?)\n---\s*\n'
    match = re.match(pattern, content, re.DOTALL)

    if not match:
        return {}, False

    try:
        frontmatter = yaml.safe_load(match.group(1))
        return frontmatter or {}, True
    except yaml.YAMLError as e:
        print_error(f"Invalid YAML syntax: {e}")
        return {}, False


def validate_skill_md(skill_path: Path) -> Tuple[bool, Dict]:
    """
    Validate a SKILL.md file.

    Args:
        skill_path: Path to the skill directory

    Returns:
        Tuple of (is_valid boolean, frontmatter dict)
    """
    skill_md = skill_path / "SKILL.md"

    if not skill_md.exists():
        print_error(f"{skill_path.name}/SKILL.md not found")
        return False, {}

    print_info(f"Validating {skill_path.name}/SKILL.md")

    try:
        content = skill_md.read_text(encoding='utf-8')
    except Exception as e:
        print_error(f"Failed to read {skill_md}: {e}")
        return False, {}

    # Extract frontmatter
    frontmatter, success = extract_frontmatter(content)
    if not success:
        print_error(f"{skill_path.name}/SKILL.md: No valid YAML frontmatter found")
        return False, {}

    # Validate required fields
    required_fields = ['name', 'description', 'version']
    missing_fields = [field for field in required_fields if field not in frontmatter]

    if missing_fields:
        print_error(f"{skill_path.name}/SKILL.md: Missing required fields: {', '.join(missing_fields)}")
        return False, frontmatter

    # Validate name format (kebab-case)
    name = frontmatter['name']
    if not is_valid_kebab_case(name):
        print_error(f"{skill_path.name}/SKILL.md: name '{name}' must be in kebab-case (e.g., 'my-skill-name')")
        return False, frontmatter

    # Validate name matches directory
    if name != skill_path.name:
        print_warning(f"{skill_path.name}/SKILL.md: name '{name}' does not match directory name '{skill_path.name}'")

    # Validate description is not empty
    description = frontmatter['description']
    if not description or not description.strip():
        print_error(f"{skill_path.name}/SKILL.md: description cannot be empty")
        return False, frontmatter

    # Validate version format (semantic versioning)
    version = str(frontmatter['version'])
    if not is_valid_semver(version):
        print_error(f"{skill_path.name}/SKILL.md: version '{version}' is not valid semantic version (e.g., '1.0.0')")
        return False, frontmatter

    print_success(f"{skill_path.name}/SKILL.md is valid (v{version})")
    return True, frontmatter


def validate_marketplace_json(repo_root: Path) -> Tuple[bool, Dict]:
    """
    Validate marketplace.json structure.

    Args:
        repo_root: Root directory of the repository

    Returns:
        Tuple of (is_valid boolean, marketplace data dict)
    """
    marketplace_file = repo_root / ".claude-plugin" / "marketplace.json"

    if not marketplace_file.exists():
        print_warning("No .claude-plugin/marketplace.json found (optional)")
        return True, {}

    print_info("Validating .claude-plugin/marketplace.json")

    try:
        data = json.loads(marketplace_file.read_text(encoding='utf-8'))
    except json.JSONDecodeError as e:
        print_error(f"Invalid JSON in marketplace.json: {e}")
        return False, {}
    except Exception as e:
        print_error(f"Failed to read marketplace.json: {e}")
        return False, {}

    # Validate structure
    if 'plugins' not in data:
        print_error("marketplace.json: missing 'plugins' array")
        return False, data

    if not isinstance(data['plugins'], list):
        print_error("marketplace.json: 'plugins' must be an array")
        return False, data

    # Validate each plugin entry
    for idx, plugin in enumerate(data['plugins']):
        if 'name' not in plugin:
            print_error(f"marketplace.json: plugin at index {idx} missing 'name'")
            return False, data

        if 'skills' not in plugin:
            print_error(f"marketplace.json: plugin '{plugin['name']}' missing 'skills' array")
            return False, data

        if not isinstance(plugin['skills'], list):
            print_error(f"marketplace.json: plugin '{plugin['name']}' 'skills' must be an array")
            return False, data

    print_success("marketplace.json is valid")
    return True, data


def find_skill_directories(repo_root: Path) -> List[Path]:
    """
    Find all skill directories (excluding template and hidden directories).

    Args:
        repo_root: Root directory of the repository

    Returns:
        List of skill directory paths
    """
    skills = []
    for item in repo_root.iterdir():
        if not item.is_dir():
            continue

        # Skip hidden directories, .github, template-skill
        if item.name.startswith('.') or item.name == 'template-skill':
            continue

        # Check if it has a SKILL.md file
        if (item / "SKILL.md").exists():
            skills.append(item)

    return skills


def validate_marketplace_consistency(repo_root: Path, skill_dirs: List[Path], marketplace_data: Dict) -> bool:
    """
    Validate that marketplace.json references match actual skill directories.

    Args:
        repo_root: Root directory of the repository
        skill_dirs: List of skill directory paths
        marketplace_data: Parsed marketplace.json data

    Returns:
        True if consistent, False otherwise
    """
    if not marketplace_data or 'plugins' not in marketplace_data:
        # No marketplace.json or no plugins, skip this check
        return True

    print_info("Validating marketplace.json consistency with skill directories")

    # Get all skill paths from marketplace.json
    marketplace_skills = set()
    for plugin in marketplace_data['plugins']:
        for skill_path in plugin.get('skills', []):
            # Normalize path (remove ./ prefix)
            normalized = skill_path.lstrip('./')
            marketplace_skills.add(normalized)

    # Get all actual skill directory names
    actual_skills = {skill.name for skill in skill_dirs}

    # Check for skills in marketplace but not in filesystem
    missing_skills = marketplace_skills - actual_skills
    if missing_skills:
        for skill in missing_skills:
            print_error(f"marketplace.json references skill '{skill}' but directory not found")
        return False

    # Check for skills in filesystem but not in marketplace
    unreferenced_skills = actual_skills - marketplace_skills
    if unreferenced_skills:
        for skill in unreferenced_skills:
            print_warning(f"Skill directory '{skill}' exists but not referenced in marketplace.json")

    print_success("marketplace.json is consistent with skill directories")
    return True


def main() -> int:
    """
    Main validation function.

    Returns:
        Exit code (0 for success, 1 for failure)
    """
    print(f"\n{Colors.BOLD}=== Claude Skills Validator ==={Colors.RESET}\n")

    # Get repository root (parent of .github)
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent.parent

    print_info(f"Repository root: {repo_root}")

    # Find all skill directories
    skill_dirs = find_skill_directories(repo_root)

    if not skill_dirs:
        print_warning("No skill directories found")
        return 0

    print_info(f"Found {len(skill_dirs)} skill(s) to validate: {', '.join(s.name for s in skill_dirs)}\n")

    # Validate each skill
    all_valid = True
    skill_metadata = {}

    for skill_dir in skill_dirs:
        is_valid, frontmatter = validate_skill_md(skill_dir)
        if not is_valid:
            all_valid = False
        else:
            skill_metadata[skill_dir.name] = frontmatter
        print()  # Blank line between skills

    # Validate marketplace.json
    marketplace_valid, marketplace_data = validate_marketplace_json(repo_root)
    if not marketplace_valid:
        all_valid = False
    print()

    # Validate consistency
    if marketplace_data:
        consistency_valid = validate_marketplace_consistency(repo_root, skill_dirs, marketplace_data)
        if not consistency_valid:
            all_valid = False
        print()

    # Summary
    print(f"{Colors.BOLD}=== Validation Summary ==={Colors.RESET}")
    if all_valid:
        print_success("All validations passed!")
        print_info(f"Validated {len(skill_dirs)} skill(s)")
        for skill_name, metadata in skill_metadata.items():
            print(f"  • {skill_name} v{metadata['version']}")
        return 0
    else:
        print_error("Validation failed - see errors above")
        return 1


if __name__ == "__main__":
    sys.exit(main())
