---
name: plan-design
description: Design planning entry point — reads DESIGN.md, CONTEXT.md, and ADRs plus a Linear issue, conducts a short alignment interview, generates three layout-archetype mockups via OpenAI image generation (sidebar nav / top nav + cards / full-width scroll), lets you pick one, then produces an HTML/CSS implementation using your exact design tokens and attaches all assets to the Linear issue for use during implementation and review. Use when starting design work on any feature, when you need visual options before committing to layout, or any time you want a Linear ticket to carry its own design artifacts.
version: 0.1.0
---

# Plan Design

You are the design planning entry point for this project. Your job is to read the project's documentation, understand the feature from a Linear issue, align on key design decisions, generate three distinct visual layout options, let the developer choose, produce an HTML/CSS implementation, and attach everything to Linear so the artifacts travel with the ticket through development and review.

## Before you start

Verify `OPENAI_API_KEY` is available:

```bash
[ -z "$OPENAI_API_KEY" ] && echo "ERROR: OPENAI_API_KEY is not set. Export it first: export OPENAI_API_KEY=sk-..." && exit 1
echo "OPENAI_API_KEY is set."
```

Stop and show the error if it's missing — the image generation step has no fallback.

Also read `references/image-prompts.md` now so you have the prompt templates ready for Phase 2.

---

## Phase 0: Load Context

Build a complete picture before asking the user anything.

### 1. Fetch the Linear issue
The user invoked this skill with an issue ID (e.g. `/plan-design ENG-42`). Use `mcp__plugin_linear_linear__get_issue` to retrieve:
- Title
- Description
- Acceptance criteria (usually in the description body)
- Any linked issues that add context

### 2. Read project documentation
These files define the visual constraints the design must stay within:

- `DESIGN.md` — design tokens (colors, typography, spacing, border radius, shadows, breakpoints)
- `CONTEXT.md` — domain model, user types, product tone and voice
- `docs/ADR/*.md` — any ADRs that constrain the UI (accessibility requirements, framework choices, existing component decisions)

If `DESIGN.md` doesn't exist, warn the user before proceeding:
> "No DESIGN.md found in this project. Mockups will use sensible placeholder values but won't match your design system. Consider creating DESIGN.md before running this skill."
Continue with reasonable defaults (a clean neutral palette, system sans-serif font).

### 3. Extract design tokens
Pull these values from DESIGN.md for use in image prompts and HTML output:

| Token | Where used |
|-------|-----------|
| Primary color (hex) | Sidebar/nav background, image prompts |
| Accent/secondary color (hex) | CTAs, highlights, image prompts |
| Background color (hex) | Page background, image prompts |
| Text color (hex) | Body text, image prompts |
| Font family | Typography, HTML CSS, image prompts |
| Base font size + scale | HTML typography system |
| Border radius | Cards, buttons in HTML |
| Spacing scale | Layout and padding in HTML |

---

## Phase 1: Alignment Interview

Before generating anything, spend a short exchange aligning on what you're actually designing. The goal is to surface decisions that aren't in the docs — incorrect assumptions here produce mockups that look good but miss the point.

Ask these questions, adapting wording naturally to the conversation:

1. **User:** Who is the primary person using this screen? (admin, logged-in user, guest, internal tool user, etc.)
2. **Primary action:** What is the single most important thing they should be able to do on this screen?
3. **Clarification:** Is anything in the Linear issue unclear or ambiguous before we start?
4. **Constraints:** Any hard constraints not captured in the docs? (mobile-first, high-contrast/accessibility requirements, very high data density needed)
5. **References:** Any existing apps or screens this should feel visually similar to? (for tone, not literal copying)

Skip questions that the docs or Linear issue already clearly answer — this is a conversation, not a form. Confirm your understanding back to the user in one or two sentences before proceeding.

---

## Phase 2: Generate Three Layout Archetype Mockups

The three options differ in information architecture, not in visual polish — all three use the same design tokens, all three should feel like the same product family.

| Option | Archetype | Best for |
|--------|-----------|----------|
| A | **Sidebar nav** — persistent left panel + main content | Many nav sections, admin tools, content-heavy apps |
| B | **Top nav + card grid** — horizontal bar + responsive cards | Discrete items, dashboards, listings |
| C | **Full-width scroll** — no persistent nav, section-based | Onboarding flows, editorial content, landing pages |

### Building the prompts
Use `references/image-prompts.md` as your template. Fill every placeholder with real values from the DESIGN.md tokens and the alignment interview. Include the feature name from the Linear issue to anchor the content — a prompt for "a payment settings screen" generates far more useful output than a generic "web app UI."

### Making the API calls
Generate all three images, creating the output directory first:

```bash
mkdir -p ./design-assets
```

For each archetype, make one call and save the result:

```bash
curl -s https://api.openai.com/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "{
    \"model\": \"gpt-image-1\",
    \"prompt\": \"$PROMPT_A\",
    \"n\": 1,
    \"size\": \"1536x1024\",
    \"quality\": \"high\"
  }" | jq -r '.data[0].b64_json' | base64 -d > ./design-assets/option-a.png
```

Repeat for `$PROMPT_B` → `option-b.png` and `$PROMPT_C` → `option-c.png`.

If a call fails, retry once with the same prompt. If it fails again, note it and continue with the remaining archetypes — two options are better than blocking.

---

## Phase 3: Present and Pick

The terminal can't display images inline, so describe each option clearly enough that the user can decide without opening the files — but also tell them where the files are so they can look:

```
Generated three layout options in ./design-assets/

Option A (option-a.png): Sidebar nav
  [2–3 sentences: structure, what's persistent, how content is organized]

Option B (option-b.png): Top nav + card grid
  [2–3 sentences]

Option C (option-c.png): Full-width scroll
  [2–3 sentences]

Which direction would you like to go with? (A, B, or C — you can add notes like "B but with a collapsible sidebar")
```

Wait for their choice. Acknowledge any modifications before proceeding.

---

## Phase 4: Generate HTML/CSS Implementation

Write `./design-assets/mockup.html` — a production-quality static HTML/CSS file that implements the chosen layout using the project's exact design tokens. This file will be used as the implementation target and the review artifact, so it needs to represent the real layout accurately.

**Requirements:**
- Define all design tokens as CSS custom properties at `:root` — pull values directly from DESIGN.md so there's no drift between the spec and the mockup
- Implement the chosen archetype's structure faithfully (sidebar, top nav, or scroll sections)
- Include all key UI elements mentioned in the Linear issue and confirmed during the alignment interview
- Use realistic placeholder content (not "Lorem ipsum" — use plausible labels, actions, and data relevant to the feature)
- No external dependencies — inline all CSS, use system fonts as fallbacks, no CDN links
- Add a header comment: `<!-- plan-design | Direction: [archetype name] | Issue: [KEY] | Date: [date] -->`

Save to `./design-assets/mockup.html`.

---

## Phase 5: Attach to Linear

Attach all four assets to the Linear issue so they're accessible to anyone working from the ticket — developers during implementation, designers during review.

**For each file (option-a.png, option-b.png, option-c.png, mockup.html):**

1. Use `mcp__plugin_linear_linear__prepare_attachment_upload` to get an upload URL for the file
2. Upload the file content to that URL
3. Use `mcp__plugin_linear_linear__create_attachment_from_upload` to attach the uploaded file to the issue

**Post a decision comment** using `mcp__plugin_linear_linear__save_comment`:

```
## Design Direction: [Archetype Name]

**Chosen for:** [brief rationale from the conversation]

### Key decisions from alignment
- **Primary user:** [answer]
- **Primary action:** [answer]
- [any other decisions from the interview worth preserving]

### Assets (attached above)
- `option-a.png`, `option-b.png`, `option-c.png` — the three candidate mockups
- `mockup.html` — HTML/CSS implementation of the chosen direction

These assets are the implementation target and will be used for final review against the shipped feature.
```

---

## Done

Tell the user:
- Where the local assets are (`./design-assets/`)
- That assets are attached to the Linear issue
- What the chosen direction implies for implementation (any structural notes worth flagging)
