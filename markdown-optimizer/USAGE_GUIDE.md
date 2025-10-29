# Markdown Optimizer Skill - Usage Guide

## What This Skill Does

The markdown-optimizer skill transforms markdown documents to maximize their utility as LLM reference material by:

1. **Adding structured metadata** - YAML front-matter with title, token count, key concepts, TOC, and diagram suggestions
2. **Normalizing structure** - Ensures logical heading hierarchy
3. **Identifying optimization opportunities** - Flags sections that could benefit from diagrams or restructuring
4. **Removing noise** - Strips redundant formatting and empty lines
5. **Enabling manual optimization** - Provides patterns for converting verbose prose to structured formats

## Installation

The skill includes everything needed:
- `scripts/optimize_markdown.py` - Automated optimization script
- `references/optimization-patterns.md` - Manual optimization patterns and best practices
- `SKILL.md` - Complete usage instructions

## Quick Start

```bash
# Run automated optimization
python scripts/optimize_markdown.py input.md output.md

# Review the output front-matter for optimization suggestions
# Apply manual optimizations using patterns from references/
```

## Real-World Example

### Original Document Stats
- **Tokens**: ~701
- **Redundant examples**: 3 similar code blocks
- **Verbose prose**: Multiple sequential steps described in paragraphs
- **Missing structure**: No metadata or navigation aids
- **Unclear relationships**: Component architecture described in prose

### After Automated Optimization
- **Tokens**: ~946 (metadata adds ~245 tokens initially)
- **Added**: Complete front-matter with TOC and key concepts
- **Identified**: 6 sections flagged for potential diagrams
- **Normalized**: Heading hierarchy corrected
- **Cleaned**: Noise patterns removed

### After Manual Optimization (Using Skill Patterns)
- **Tokens**: ~420 (**40% reduction** from original)
- **Improvements**:
  - Consolidated 3 redundant examples into 1 comprehensive example
  - Converted verbose step lists to definition lists
  - Replaced prose architecture description with Mermaid diagram
  - Created table for command reference
  - Removed filler phrases ("it's very important", "make sure to")
  - Added workflow diagram for setup process

## Optimization Results Comparison

| Metric | Original | Auto-Optimized | Fully Optimized |
|--------|----------|----------------|-----------------|
| Tokens | 701 | 946 | 420 |
| Has Metadata | No | Yes | Yes |
| Has TOC | No | Yes | Yes |
| Diagrams | 0 | 0 (suggested 6) | 2 (implemented) |
| Structure | Prose-heavy | Same content | Tables + Lists |
| Redundancy | High | High | Eliminated |

**Key Insight**: The automated optimizer adds metadata (~35% token increase) but identifies the opportunities that, when manually applied, yield a net 40% reduction.

## Typical Workflow

1. **Run automated optimizer** to add metadata and identify opportunities
2. **Review `suggested_diagrams`** in front-matter - these often reveal unclear sections
3. **Apply manual optimizations** using patterns from `references/optimization-patterns.md`:
   - Convert verbose lists to tables or definition lists
   - Consolidate redundant examples
   - Create diagrams for flagged sections
   - Remove filler phrases and excessive emphasis
4. **Verify quality** - ensure all key information preserved
5. **Update token count** in front-matter if desired

## When to Use This Skill

**Ideal for**:
- Technical documentation being used as skill references
- Knowledge base articles for LLM ingestion
- API documentation
- Process guides and workflows
- Research notes for prompt construction

**Not recommended for**:
- Creative writing (stories, poetry)
- Legal documents (precision required)
- Already-concise technical specifications
- Marketing content (different optimization goals)

## Integration with Other Skills

Optimized markdown works particularly well as:

1. **Reference material in custom skills** - Place in `references/` directory
2. **Knowledge base entries** - Structured metadata aids retrieval
3. **Prompt components** - Reduced token count allows more context
4. **Documentation libraries** - Cross-linking via front-matter relationships

Example front-matter for skill integration:
```yaml
---
title: "API Authentication Guide"
related_docs:
  - api-reference.md
  - security-best-practices.md
dependencies:
  - python>=3.8
  - requests
---
```

## Advanced Patterns

See `references/optimization-patterns.md` for detailed guidance on:
- Converting prose to structured formats (tables, definition lists)
- Diagram patterns for different content types (flowcharts, graphs, architecture)
- Content compression techniques
- When NOT to optimize
- Quality verification checklists

## Example Files

The skill includes example files showing the transformation:

- `example_before.md` - Original verbose document (701 tokens)
- `example_after.md` - Auto-optimized with metadata (946 tokens)
- `example_fully_optimized.md` - Manual optimizations applied (420 tokens, 40% reduction)

## Tips

1. **Always run automated optimization first** - it establishes the baseline and identifies opportunities
2. **Pay attention to suggested diagrams** - they often highlight sections that are hard to understand
3. **Test iteratively** - optimize one section at a time and verify clarity
4. **Preserve semantics** - never sacrifice accuracy for brevity
5. **Update front-matter** - add `related_docs` and `dependencies` for context

## Support

For questions or issues with the skill, refer to:
- `SKILL.md` - Complete usage instructions
- `references/optimization-patterns.md` - Detailed optimization patterns
- Example files - Real-world before/after demonstrations
