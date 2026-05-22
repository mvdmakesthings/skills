#!/usr/bin/env python3
import json
from pathlib import Path

BATCH_FILES = [
    "/tmp/storyteller-essence-1.json",
    "/tmp/storyteller-essence-2.json",
    "/tmp/storyteller-essence-3.json",
]
OUT = Path(__file__).parent / "cards.json"


def load_all():
    cards = []
    for f in BATCH_FILES:
        cards.extend(json.loads(Path(f).read_text()))
    return cards


def merge_split_cards(cards):
    by_key = {}
    for c in cards:
        k = c["title_key"]
        if k not in by_key:
            by_key[k] = c
            continue

        existing = by_key[k]
        merged_images = list(dict.fromkeys(existing["images"] + c["images"]))
        merged = dict(existing)
        merged["images"] = merged_images

        for field in ("essence", "when_to_use", "principle"):
            if not existing.get(field) or existing.get(field, "").startswith("Front-side"):
                merged[field] = c.get(field) or existing.get(field)

        existing_fw = existing.get("framework_approach", []) or []
        new_fw = c.get("framework_approach", []) or []
        looks_placeholder = (
            len(existing_fw) <= 1
            and existing_fw
            and ("only" in existing_fw[0].lower() or "side" in existing_fw[0].lower())
        )
        if looks_placeholder or (len(new_fw) > len(existing_fw)):
            merged["framework_approach"] = new_fw

        if c.get("category") and c["category"] not in ("unknown",):
            if existing.get("category") in (None, "", "unknown"):
                merged["category"] = c["category"]

        merged["notes"] = ""
        by_key[k] = merged
    return list(by_key.values())


def reassign_ids(cards):
    order = {"system": 0, "recipe": 1, "Concept": 2, "Explore": 3,
             "Character": 4, "Function": 5, "Structure": 6, "Style": 7, "Organise": 8}
    cards.sort(key=lambda c: (order.get(c["category"], 99), c["title_display"]))
    for i, c in enumerate(cards, start=1):
        c["id"] = i
    return cards


def main():
    cards = load_all()
    merged = merge_split_cards(cards)
    merged = reassign_ids(merged)

    by_cat = {}
    for c in merged:
        by_cat.setdefault(c["category"], []).append(c["title_display"])
    print(f"Total unique cards: {len(merged)}")
    for cat, titles in by_cat.items():
        print(f"  {cat} ({len(titles)}): {', '.join(titles)}")

    OUT.write_text(json.dumps(merged, indent=2))
    print(f"\nWrote {OUT}")


if __name__ == "__main__":
    main()
