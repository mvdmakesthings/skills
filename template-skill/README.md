# Template Skill

This is a template for creating new skills for the mvd-agent-skills marketplace.

## How to Use This Template

1. **Copy this directory:**
   ```bash
   cp -r template-skill/ your-skill-name/
   cd your-skill-name/
   ```

2. **Edit SKILL.md:**
   - Update the YAML frontmatter with your skill name and description
   - Replace template content with your skill's instructions
   - Add examples and usage patterns
   - Include any necessary code samples or commands

3. **Add supporting files (optional):**
   ```
   your-skill-name/
   ├── SKILL.md              # Required: Main skill instructions
   ├── README.md             # Optional: Human-readable documentation
   ├── references/           # Optional: Reference documents
   │   └── guide.md
   └── scripts/              # Optional: Helper scripts
       └── script.py
   ```

4. **Update marketplace.json:**
   Add your skill to the marketplace configuration:
   ```json
   {
     "plugins": [
       {
         "name": "your-plugin-name",
         "description": "Your plugin description",
         "source": "./",
         "strict": false,
         "skills": [
           "./your-skill-name"
         ]
       }
     ]
   }
   ```

## YAML Frontmatter Requirements

The SKILL.md file must start with YAML frontmatter:

```yaml
---
name: your-skill-name
description: Clear description of functionality and use cases
---
```

**name:** Unique identifier in kebab-case (lowercase with hyphens)
**description:** Concise explanation of what the skill does and when to use it

## Writing Effective Skills

### Structure Your Instructions Clearly

- Use headings to organize different aspects of the skill
- Provide concrete examples and code samples
- Include both basic and advanced usage patterns
- Document any prerequisites or dependencies

### Be Specific About When to Use

Make it clear when Claude should activate your skill:
- List specific trigger phrases or contexts
- Describe the problem domain
- Specify use cases and anti-use cases

### Include Examples

Show expected interactions:
```
User: "Request that triggers this skill"
Claude: [How Claude should respond using this skill]
```

### Add Reference Materials

If your skill needs reference documents:
- Place them in a `references/` subdirectory
- Reference them in SKILL.md
- Keep them optimized for LLM consumption

### Test Your Skill

Before submitting:
1. Install the skill locally
2. Test with various prompts
3. Verify Claude follows instructions correctly
4. Ensure examples work as documented

## Directory Structure Examples

### Minimal Skill
```
my-skill/
└── SKILL.md
```

### Skill with References
```
my-skill/
├── SKILL.md
└── references/
    ├── api-reference.md
    └── examples.md
```

### Skill with Scripts
```
my-skill/
├── SKILL.md
├── README.md
├── references/
│   └── guide.md
└── scripts/
    ├── process.py
    └── validate.sh
```

## Contributing Your Skill

Once your skill is ready:
1. Test it thoroughly
2. Ensure SKILL.md has proper frontmatter
3. Add documentation in README.md (optional but recommended)
4. Submit a pull request to add it to the marketplace

## Need Help?

- See existing skills in this marketplace for examples
- Check the markdown-optimizer skill for a complete reference
- Review Claude Code documentation on skills

## License

Skills submitted to this marketplace inherit the repository's MIT license unless otherwise specified.
