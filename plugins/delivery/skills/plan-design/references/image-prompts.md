# Image Prompt Templates

Use these templates when building chatgpt-image-latest prompts in Phase 2. Fill every placeholder with real values from DESIGN.md and the alignment interview.

## General formula

```
A clean, modern web application UI mockup screenshot, [screen context from Linear issue],
[archetype-specific description below],
color palette: primary [primary-hex], accent [accent-hex], background [bg-hex], text [text-hex],
typography: [font-family] typeface,
[1-2 tone adjectives from CONTEXT.md],
high-fidelity UI design, desktop resolution, placeholder content, no readable text,
UI/UX professional design
```

**Why these specific words matter:**
- "UI mockup screenshot" — tells chatgpt-image-latest this is interface design, not illustration
- "high-fidelity" — produces crisper, more realistic output than "wireframe"
- "no readable text" — prevents garbled text artifacts in the output
- "placeholder content" — avoids hallucinated real company names or data

## Archetype-specific additions

### Option A — Sidebar Nav
Append inside the formula after the archetype position:
```
persistent left sidebar navigation panel with [primary-hex] background color and white icons and labels,
main content area on the right with [bg-hex] background,
top header bar within the content area, organized content sections below
```

Best for: apps with many navigation sections, admin tools, content-heavy interfaces.

### Option B — Top Nav + Card Grid
Append:
```
horizontal navigation bar fixed to the top with [primary-hex] background,
responsive card grid layout in the main content area below,
each card has a white background with subtle shadow and a [accent-hex] call-to-action button,
search bar and filter controls visible near the top of the content area
```

Best for: marketplaces, dashboards with discrete items, product or resource listings.

### Option C — Full-Width Scroll
Append:
```
full-width layout with no persistent sidebar or top navigation bar,
content divided into clearly separated scroll sections with large bold [font-family] section headers,
[primary-hex] used as accent color for key interactive elements,
generous whitespace between sections, editorial and content-focused feel
```

Best for: onboarding flows, landing pages, document or article reading experiences.

## Prompt quality tips

- **Include the feature name** from the Linear issue to anchor the content (e.g. "a payment settings screen", "a user profile editor", "a project activity dashboard")
- **Add tone adjectives** from CONTEXT.md — "professional and focused" produces very different output than "playful and colorful"
- **If the user named a reference app** in the alignment interview, describe its aesthetic quality (e.g. "similar visual weight and density to Linear", "minimal like Notion", "data-dense like Grafana")
- **Avoid:** "wireframe", "sketch", "low-fidelity", "hand-drawn" — these produce lower-quality, less useful outputs
- **One call per archetype** — chatgpt-image-latest n=1 produces more coherent results than n=3 at once
