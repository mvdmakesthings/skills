# MVD Agent Skills Marketplace

A Claude Code plugin marketplace featuring skills that extend Claude's capabilities for specialized tasks.

## Quick Start

### Install the Marketplace

Register this marketplace with Claude Code:

```bash
/plugin marketplace add mvdmakesthings/skills
```

### Browse Available Skills

View all available skills in the marketplace:

```bash
/plugin
```

### Install Skills

Install individual skills or the entire plugin:

```bash
# Install the markdown-optimizer skill
/plugin install markdown-optimizer@mvd-agent-skills
```

## Available Skills

### markdown-optimizer

Optimize markdown documents for LLM consumption by adding structured metadata, normalizing formatting, and reducing token usage.

**Use cases:**
- Technical documentation for LLM ingestion
- Knowledge base articles
- API documentation
- Process guides and workflows
- Research notes for prompt construction

**Features:**
- Automated YAML front-matter generation
- Heading hierarchy normalization
- Token usage optimization
- Mermaid diagram suggestions
- Structured metadata for better LLM parsing

[View markdown-optimizer documentation →](markdown-optimizer/USAGE_GUIDE.md)

## Creating New Skills

Want to contribute a skill? Use the template provided:

1. **Copy the template:**
   ```bash
   cp -r template-skill/ your-skill-name/
   ```

2. **Customize SKILL.md:**
   - Update YAML frontmatter with name and description
   - Add your skill's instructions and examples
   - Include usage patterns and best practices

3. **Add to marketplace.json:**
   - Update `.claude-plugin/marketplace.json` with your skill

4. **Test your skill:**
   - Install locally and verify functionality
   - Ensure Claude follows instructions correctly

[Read the template documentation →](template-skill/README.md)

## Repository Structure

```
skills/
├── .claude-plugin/
│   └── marketplace.json      # Marketplace configuration
├── LICENSE                    # MIT License
├── README.md                  # This file
├── markdown-optimizer/        # Markdown optimization skill
│   ├── SKILL.md              # Skill instructions
│   ├── USAGE_GUIDE.md        # User documentation
│   ├── references/           # Reference materials
│   └── scripts/              # Helper scripts
└── template-skill/           # Template for new skills
    ├── SKILL.md             # Template skill file
    └── README.md            # Template documentation
```

## How Skills Work

Skills are specialized instruction sets that Claude Code loads when relevant. Each skill:

1. Lives in its own directory
2. Contains a `SKILL.md` file with YAML frontmatter
3. May include supporting files (scripts, references, documentation)
4. Gets activated based on the description in frontmatter

When you invoke a skill, Claude follows the instructions in `SKILL.md` to help with specific tasks.

## Contributing

Contributions are welcome! To add a skill to this marketplace:

1. Fork this repository
2. Create your skill using the template
3. Test it thoroughly
4. Submit a pull request with:
   - Your skill directory
   - Updated marketplace.json
   - Documentation

### Contribution Guidelines

- **Quality:** Skills should be well-documented and tested
- **Naming:** Use kebab-case for skill names (e.g., `my-skill-name`)
- **Frontmatter:** Always include valid YAML frontmatter in SKILL.md
- **Documentation:** Provide clear examples and use cases
- **License:** Contributions inherit the repository's MIT license

## Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Check existing skills for examples
- Review the template-skill documentation

## License

MIT License - see [LICENSE](LICENSE) for details.

## About

Maintained by Michael VanDyke. This marketplace follows the Claude Code plugin marketplace specification and is inspired by [Anthropic's skills repository](https://github.com/anthropics/skills).
