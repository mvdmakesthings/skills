#!/usr/bin/env python3
"""Generate reference markdown files for the storyteller-tactics skill from cards.json.

Reads `_source/cards.json` (the canonical, paraphrased card distillation) and writes:
  references/index.md            — full alphabetical and by-category catalog
  references/recipes.md          — the 7 multi-tactic recipe cards
  references/concept.md          — Concept-family tactics
  references/explore.md          — Explore-family tactics
  references/character.md        — Character-family tactics
  references/function.md         — Function-family tactics
  references/structure.md        — Structure-family tactics
  references/style.md            — Style-family tactics
  references/organise.md         — Organise-family tactics
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CARDS = ROOT / "_source" / "cards.json"
REF_DIR = ROOT / "skills" / "storyteller-tactics" / "references"

CATEGORY_FILES = {
    "Concept": "concept.md",
    "Explore": "explore.md",
    "Character": "character.md",
    "Function": "function.md",
    "Structure": "structure.md",
    "Style": "style.md",
    "Organise": "organise.md",
}

CATEGORY_TAGLINES = {
    "Concept": "Why a story is needed and what shape its core idea should take.",
    "Explore": "How to find raw story material in your work, your research, and your customers.",
    "Character": "Who is in the story — including the storyteller — and how to position each role.",
    "Function": "What job the story has to do: pitch, sell, explain, warm up a room, surface a hidden insight.",
    "Structure": "The arc the story follows — fall-and-recover, rise, downfall, voyage, and other shapes.",
    "Style": "How to deliver the story: hooks, threes, vivid moments, withheld details, slide rhythm.",
    "Organise": "How to manage stories across audiences and over time so the right one is ready when needed.",
}


def slug(s):
    return (
        s.lower()
        .replace("&", "and")
        .replace(",", "")
        .replace("!", "")
        .replace("?", "")
        .replace("'", "")
        .replace(" ", "-")
    )


def render_tactic(c):
    lines = [f"## {c['title_display']} {{#{slug(c['title_display'])}}}"]
    lines.append("")
    lines.append(f"**Essence.** {c['essence']}")
    lines.append("")
    lines.append(f"**When to reach for it.** {c['when_to_use']}")
    lines.append("")
    lines.append(f"**Why it works.** {c['principle']}")
    lines.append("")
    lines.append("**How to apply.**")
    for step in c.get("framework_approach", []):
        lines.append(f"- {step}")
    lines.append("")
    return "\n".join(lines)


def render_recipe(c):
    lines = [f"## {c['title_display']} {{#{slug(c['title_display'])}}}"]
    lines.append("")
    lines.append(f"**Essence.** {c['essence']}")
    lines.append("")
    lines.append(f"**When to use this recipe.** {c['when_to_use']}")
    lines.append("")
    lines.append(f"**Why this combination.** {c['principle']}")
    lines.append("")
    lines.append("**Build the story in this order.**")
    for step in c.get("framework_approach", []):
        lines.append(f"- {step}")
    lines.append("")
    if c.get("constituent_tactics"):
        lines.append("**Tactics this recipe combines.**")
        for t in c["constituent_tactics"]:
            lines.append(f"- *{t}*")
        lines.append("")
    return "\n".join(lines)


def write_category(cards, category, taglines):
    title_block = f"# {category} tactics\n\n{taglines[category]}\n\n"
    body = "\n".join(render_tactic(c) for c in cards if c["category"] == category)
    out = REF_DIR / CATEGORY_FILES[category]
    out.write_text(title_block + body)
    return out


def write_recipes(cards):
    title_block = (
        "# Recipes\n\n"
        "Recipe cards stack multiple tactics in a particular order to reach a goal. "
        "Each recipe lists which tactics it draws on; load the relevant category reference for the framework on any one of them.\n\n"
    )
    body = "\n".join(render_recipe(c) for c in cards if c["card_type"] == "recipe")
    out = REF_DIR / "recipes.md"
    out.write_text(title_block + body)
    return out


def write_index(cards):
    by_cat = {}
    for c in cards:
        by_cat.setdefault(c["category"], []).append(c)

    lines = [
        "# Card index",
        "",
        "Every card in the deck with a one-line essence. Use this to find a specific tactic by name or to scan a category quickly. Each entry links to the full framework in its category file.",
        "",
        "## By category",
        "",
    ]

    category_order = ["system", "recipe", "Concept", "Explore", "Character",
                      "Function", "Structure", "Style", "Organise"]
    file_for = {
        "system": None,
        "recipe": "recipes.md",
        **{k: v for k, v in CATEGORY_FILES.items()},
    }

    for cat in category_order:
        cards_in_cat = sorted(by_cat.get(cat, []), key=lambda c: c["title_display"])
        if not cards_in_cat:
            continue
        lines.append(f"### {cat}")
        lines.append("")
        for c in cards_in_cat:
            ref_file = file_for.get(c["category"])
            anchor = slug(c["title_display"])
            link = f"[{c['title_display']}]({ref_file}#{anchor})" if ref_file else f"**{c['title_display']}**"
            lines.append(f"- {link} — {c['essence']}")
        lines.append("")

    lines.append("## Alphabetical")
    lines.append("")
    for c in sorted(cards, key=lambda c: c["title_display"].lower()):
        ref_file = file_for.get(c["category"])
        anchor = slug(c["title_display"])
        link = f"[{c['title_display']}]({ref_file}#{anchor})" if ref_file else f"**{c['title_display']}**"
        lines.append(f"- {link} *({c['category']})* — {c['essence']}")

    out = REF_DIR / "index.md"
    out.write_text("\n".join(lines) + "\n")
    return out


def main():
    REF_DIR.mkdir(parents=True, exist_ok=True)
    cards = json.loads(CARDS.read_text())

    written = []
    written.append(write_recipes(cards))
    for cat in CATEGORY_FILES:
        written.append(write_category(cards, cat, CATEGORY_TAGLINES))
    written.append(write_index(cards))

    for p in written:
        print(f"wrote {p.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
