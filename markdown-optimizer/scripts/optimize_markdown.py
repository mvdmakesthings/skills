#!/usr/bin/env python3
"""
Markdown Optimizer for LLM Consumption

Optimizes markdown files by:
- Adding YAML front-matter with metadata
- Creating TOC in front-matter
- Normalizing heading hierarchy
- Removing redundant content and noise
- Converting verbose prose to structured formats
- Identifying diagram opportunities
- Calculating token estimates
"""

import re
import sys
from pathlib import Path
from typing import List, Dict, Tuple
from collections import Counter


class MarkdownOptimizer:
    def __init__(self, content: str, source_path: str = ""):
        self.original_content = content
        self.source_path = source_path
        self.lines = content.split('\n')
        self.headings = []
        self.metadata = {}
        
    def extract_headings(self) -> List[Dict]:
        """Extract all headings with their levels and content."""
        headings = []
        for i, line in enumerate(self.lines):
            match = re.match(r'^(#{1,6})\s+(.+)$', line)
            if match:
                level = len(match.group(1))
                text = match.group(2).strip()
                headings.append({
                    'level': level,
                    'text': text,
                    'line': i
                })
        return headings
    
    def normalize_heading_hierarchy(self) -> str:
        """Ensure logical heading progression (no skipped levels)."""
        content = self.original_content
        headings = self.extract_headings()
        
        if not headings:
            return content
        
        # Start from H1
        expected_level = 1
        adjustments = {}
        
        for heading in headings:
            current_level = heading['level']
            
            # If we skip levels, normalize
            if current_level > expected_level + 1:
                adjustments[heading['line']] = expected_level + 1
                expected_level = expected_level + 1
            else:
                adjustments[heading['line']] = current_level
                expected_level = current_level
        
        # Apply adjustments
        lines = content.split('\n')
        for line_num, new_level in adjustments.items():
            old_line = lines[line_num]
            match = re.match(r'^(#{1,6})\s+(.+)$', old_line)
            if match:
                lines[line_num] = '#' * new_level + ' ' + match.group(2)
        
        return '\n'.join(lines)
    
    def generate_toc(self) -> List[Dict]:
        """Generate table of contents from headings."""
        headings = self.extract_headings()
        toc = []
        
        for heading in headings:
            # Create anchor-style reference
            anchor = heading['text'].lower()
            anchor = re.sub(r'[^\w\s-]', '', anchor)
            anchor = re.sub(r'[-\s]+', '-', anchor)
            
            toc.append({
                'level': heading['level'],
                'text': heading['text'],
                'anchor': anchor
            })
        
        return toc
    
    def extract_key_concepts(self) -> List[str]:
        """Extract key concepts/topics from the document."""
        # Remove markdown syntax and extract meaningful words
        text = re.sub(r'[#*`_\[\]()]', '', self.original_content)
        words = re.findall(r'\b[A-Z][a-z]+(?:[A-Z][a-z]+)*\b', text)  # CamelCase
        words += re.findall(r'\b[A-Z]{2,}\b', text)  # ACRONYMS
        
        # Count and return top concepts
        word_counts = Counter(words)
        return [word for word, _ in word_counts.most_common(10)]
    
    def estimate_tokens(self, text: str) -> int:
        """Rough token estimation (1 token ≈ 4 characters)."""
        return len(text) // 4
    
    def identify_diagram_opportunities(self) -> List[Dict]:
        """Identify sections that could benefit from Mermaid diagrams."""
        opportunities = []
        content_lower = self.original_content.lower()
        
        # Process flow indicators
        process_indicators = [
            'step 1', 'step 2', 'first', 'then', 'next', 'finally',
            'process:', 'workflow:', 'procedure:'
        ]
        
        # Relationship indicators
        relationship_indicators = [
            'depends on', 'related to', 'connects to', 'inherits from',
            'composed of', 'hierarchy', 'relationship between'
        ]
        
        # Architecture/structure indicators
        architecture_indicators = [
            'architecture', 'component', 'system design', 'structure',
            'module', 'layer', 'interface'
        ]
        
        headings = self.extract_headings()
        for heading in headings:
            section_start = heading['line']
            # Find next heading or end of document
            next_heading_line = None
            for next_h in headings:
                if next_h['line'] > section_start:
                    next_heading_line = next_h['line']
                    break
            
            section_end = next_heading_line if next_heading_line else len(self.lines)
            section_text = '\n'.join(self.lines[section_start:section_end]).lower()
            
            diagram_type = None
            if any(ind in section_text for ind in process_indicators):
                diagram_type = 'flowchart'
            elif any(ind in section_text for ind in relationship_indicators):
                diagram_type = 'graph'
            elif any(ind in section_text for ind in architecture_indicators):
                diagram_type = 'architecture'
            
            if diagram_type:
                opportunities.append({
                    'heading': heading['text'],
                    'type': diagram_type,
                    'line': section_start
                })
        
        return opportunities
    
    def remove_noise(self, content: str) -> str:
        """Remove common noise patterns in markdown."""
        lines = content.split('\n')
        cleaned = []
        
        # Patterns to remove
        noise_patterns = [
            r'^\s*---+\s*$',  # Horizontal rules (unless in front-matter)
            r'^\s*\*\*\*+\s*$',  # Alternative horizontal rules
        ]
        
        in_frontmatter = False
        frontmatter_count = 0
        
        for line in lines:
            # Track front-matter boundaries
            if line.strip() == '---':
                frontmatter_count += 1
                if frontmatter_count <= 2:
                    in_frontmatter = not in_frontmatter
                    cleaned.append(line)
                    continue
            
            # Skip noise patterns (but not in front-matter)
            if not in_frontmatter:
                is_noise = any(re.match(pattern, line) for pattern in noise_patterns)
                if is_noise:
                    continue
            
            # Remove excessive empty lines
            if not line.strip():
                if cleaned and not cleaned[-1].strip():
                    continue  # Skip consecutive empty lines
            
            cleaned.append(line)
        
        return '\n'.join(cleaned)
    
    def generate_frontmatter(self) -> str:
        """Generate YAML front-matter with metadata."""
        headings = self.extract_headings()
        toc = self.generate_toc()
        concepts = self.extract_key_concepts()
        diagrams = self.identify_diagram_opportunities()
        
        # Extract title (first H1 or filename)
        title = next((h['text'] for h in headings if h['level'] == 1), 
                     Path(self.source_path).stem if self.source_path else "Untitled")
        
        # Build front-matter
        fm_lines = ['---']
        fm_lines.append(f'title: "{title}"')
        
        # Token estimate
        token_count = self.estimate_tokens(self.original_content)
        fm_lines.append(f'tokens: {token_count}')
        
        # Optimized flag
        fm_lines.append('optimized_for_llm: true')
        
        # Key concepts
        if concepts:
            fm_lines.append('concepts:')
            for concept in concepts[:5]:  # Top 5
                fm_lines.append(f'  - {concept}')
        
        # TOC
        if toc:
            fm_lines.append('toc:')
            current_level = 1
            for item in toc:
                indent = '  ' * (item['level'] - 1)
                fm_lines.append(f'{indent}- {item["text"]}')
        
        # Diagram suggestions
        if diagrams:
            fm_lines.append('suggested_diagrams:')
            for diag in diagrams:
                fm_lines.append(f'  - section: "{diag["heading"]}"')
                fm_lines.append(f'    type: {diag["type"]}')
        
        fm_lines.append('---')
        
        return '\n'.join(fm_lines)
    
    def optimize(self) -> str:
        """Run full optimization pipeline."""
        # 1. Normalize heading hierarchy
        content = self.normalize_heading_hierarchy()
        
        # 2. Remove noise
        content = self.remove_noise(content)
        
        # 3. Remove existing front-matter if present
        if content.startswith('---'):
            parts = content.split('---', 2)
            if len(parts) >= 3:
                content = parts[2].lstrip('\n')
        
        # 4. Generate new front-matter
        self.original_content = content  # Update for metadata generation
        self.lines = content.split('\n')
        frontmatter = self.generate_frontmatter()
        
        # 5. Combine
        optimized = frontmatter + '\n\n' + content
        
        return optimized


def main():
    if len(sys.argv) < 2:
        print("Usage: optimize_markdown.py <input_file> [output_file]")
        print("\nOptimizes markdown files for LLM consumption.")
        print("If output_file is not specified, prints to stdout.")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    
    # Read input
    with open(input_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Optimize
    optimizer = MarkdownOptimizer(content, input_path)
    optimized = optimizer.optimize()
    
    # Output
    if output_path:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(optimized)
        print(f"✅ Optimized markdown written to: {output_path}")
        
        # Print stats
        original_tokens = optimizer.estimate_tokens(content)
        new_tokens = optimizer.estimate_tokens(optimized)
        print(f"\n📊 Statistics:")
        print(f"   Original: ~{original_tokens:,} tokens")
        print(f"   Optimized: ~{new_tokens:,} tokens")
        print(f"   Change: {new_tokens - original_tokens:+,} tokens")
    else:
        print(optimized)


if __name__ == '__main__':
    main()
