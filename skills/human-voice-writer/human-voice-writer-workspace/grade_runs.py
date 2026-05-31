#!/usr/bin/env python3
"""Programmatic grader for human-voice-writer eval assertions."""

import json
import re
import os
import statistics

BANNED_WORDS = [
    "delve", "tapestry", "landscape", "navigate", "leverage", "foster",
    "robust", "utilize", "nuanced", "multifaceted", "pivotal", "underscores",
    "holistic", "synergy", "paradigm", "transformative", "groundbreaking",
    "cutting-edge", "harness", "streamline", "cornerstone", "encompasses",
    "facilitates", "moreover", "furthermore", "nevertheless", "myriad",
    "plethora", "ensures", "ensure", "respective", "respectively",
]

BANNED_WORDS_EXTENDED = BANNED_WORDS + ["empowers", "empower", "unlock", "unlocking"]

BANNED_OPENINGS = [
    r"^in today's rapidly evolving",
    r"^in the realm of",
    r"^in an era where",
    r"^in a world where",
    r"^when it comes to",
    r"^imagine a world",
    r"^picture this",
    r"^great question",
    r"^that's an excellent",
    r"^what a great question",
]


def get_sentences(text):
    """Split text into sentences."""
    text = re.sub(r'\n+', ' ', text)
    text = re.sub(r'#.*?\n', '', text)
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    return [s for s in sentences if len(s.strip()) > 0]


def word_count(text):
    return len(text.split())


def sentence_word_counts(text):
    sentences = get_sentences(text)
    return [word_count(s) for s in sentences]


def has_banned_words(text, word_list=None):
    if word_list is None:
        word_list = BANNED_WORDS
    text_lower = text.lower()
    found = []
    for word in word_list:
        pattern = r'\b' + re.escape(word.lower()) + r'\b'
        if re.search(pattern, text_lower):
            found.append(word)
    return found


def has_em_dashes(text):
    """Check for em dashes, en dashes used as em dashes, or double hyphens."""
    patterns = []
    if '\u2014' in text:  # em dash —
        patterns.append('—')
    if '\u2013' in text:  # en dash –
        patterns.append('–')
    if '--' in text:
        patterns.append('--')
    return patterns


def has_false_revelation(text):
    patterns = [
        r"it'?s not just .+?, it'?s",
        r"this isn'?t just .+?, it'?s",
        r"that'?s not .+?, it'?s",
        r"it'?s not about .+?, it'?s about",
        r"it'?s more than just .+?, it'?s",
        r"not only .+?, but also",
        r"are not just .+? \u2014 they are",
        r"not just .+? — they",
    ]
    for p in patterns:
        if re.search(p, text, re.IGNORECASE):
            return True
    return False


def has_false_choice(text):
    pattern = r"whether you'?re .+? or .+?"
    return bool(re.search(pattern, text, re.IGNORECASE))


def has_trailing_participial(text):
    """Check for sentences ending with comma + gerund phrase."""
    pattern = r',\s+\w+ing\s+[\w\s]+[.!?]'
    matches = re.findall(pattern, text)
    real_matches = []
    for m in matches:
        # Filter out short ones that might be false positives
        gerund_part = m.strip().rstrip('.!?')
        if len(gerund_part.split()) >= 3:
            real_matches.append(m.strip())
    return real_matches


def count_paragraphs(text):
    """Count non-empty paragraphs (ignoring title lines starting with #)."""
    lines = text.strip().split('\n')
    # Remove title lines
    lines = [l for l in lines if not l.startswith('#')]
    text_no_titles = '\n'.join(lines)
    paragraphs = [p.strip() for p in text_no_titles.split('\n\n') if p.strip()]
    return len(paragraphs)


def has_contractions(text):
    contraction_pattern = r"\b\w+'(re|t|s|ve|ll|d|m)\b"
    return bool(re.search(contraction_pattern, text))


def has_headers_or_bullets(text):
    lines = text.strip().split('\n')
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('#'):
            return True
        if re.match(r'^[-*]\s', stripped):
            return True
    return False


def has_sycophantic_or_signpost(text):
    patterns = [
        r"great question",
        r"excellent point",
        r"let'?s break this down",
        r"here'?s the thing",
        r"let me explain",
        r"let'?s dive in",
        r"let'?s unpack this",
    ]
    text_lower = text.lower()
    for p in patterns:
        if re.search(p, text_lower):
            return True
    return False


def has_negation_assertion(text):
    """Check for negation-assertion patterns that are AI tells.

    Three sub-patterns:
    1. Short dramatic negations as punchlines: "That's not speculation." "That's not a coincidence."
    2. Negation-correction pairs across sentences: "They aren't X. They're Y." "This wasn't luck. It was strategy."
    3. Saying what something *isn't* before what it *is*: "Remote work stopped being a perk. It's infrastructure now."
    """
    found = []

    # 1. Short dramatic negations (standalone short sentences with negation)
    sentences = get_sentences(text)
    for s in sentences:
        s_stripped = s.strip().rstrip('.!?')
        words = s_stripped.split()
        # Short sentence (2-6 words) that's a negation used as a punchline
        if 2 <= len(words) <= 6:
            if re.search(r"\b(that'?s not|this isn'?t|it'?s not|it wasn'?t|that wasn'?t)\b", s_stripped, re.IGNORECASE):
                found.append(f"Dramatic negation: \"{s.strip()}\"")

    # 2. Negation-correction pairs (negation sentence followed by correction)
    for i in range(len(sentences) - 1):
        s1 = sentences[i].strip()
        s2 = sentences[i+1].strip()
        # First sentence has negation
        neg_patterns = [
            r"\b(aren'?t|isn'?t|wasn'?t|weren'?t|don'?t|didn'?t|won'?t|can'?t|couldn'?t)\b",
            r"\b(not|never|no longer)\b",
        ]
        has_neg = any(re.search(p, s1, re.IGNORECASE) for p in neg_patterns)
        # Second sentence is a correction/assertion (starts with they're, it's, he's, she's, etc.)
        correction_start = re.match(r"^(they'?re|it'?s|he'?s|she'?s|it was|they were|it is|they are)\b", s2, re.IGNORECASE)

        if has_neg and correction_start and len(s1.split()) <= 15:
            found.append(f"Negation-correction pair: \"{s1}\" → \"{s2[:50]}...\"")

    # 3. "stopped being X / It's Y now" pattern
    for i in range(len(sentences) - 1):
        s1 = sentences[i].strip()
        s2 = sentences[i+1].strip()
        if re.search(r"stopped being|is no longer|ceased to be", s1, re.IGNORECASE):
            if re.search(r"^(it'?s|it is|it became)", s2, re.IGNORECASE):
                found.append(f"What-it-isn't-then-what-it-is: \"{s1}\" → \"{s2[:50]}\"")

    return found


def has_banned_opening(text):
    # Get first real line of text (skip blank lines and titles)
    lines = text.strip().split('\n')
    first_line = ''
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith('#'):
            first_line = stripped
            break
    first_lower = first_line.lower()
    for pattern in BANNED_OPENINGS:
        if re.search(pattern, first_lower):
            return True
    return False


def grade_eval1(text, config):
    """Grade blog post eval."""
    results = []

    # 1. No banned vocabulary
    found = has_banned_words(text)
    results.append({
        "text": "Output contains none of the Tier 1 banned AI vocabulary",
        "passed": len(found) == 0,
        "evidence": f"No banned words found" if not found else f"Found banned words: {', '.join(found)}"
    })

    # 2. No em dashes
    dashes = has_em_dashes(text)
    results.append({
        "text": "Output contains no em dashes, en dashes, or double hyphens",
        "passed": len(dashes) == 0,
        "evidence": "No dashes found" if not dashes else f"Found dash types: {', '.join(dashes)}"
    })

    # 3. Burstiness
    counts = sentence_word_counts(text)
    if len(counts) >= 2:
        sd = statistics.stdev(counts)
        results.append({
            "text": "Sentence length standard deviation is 7 or more words",
            "passed": sd >= 7.0,
            "evidence": f"Sentence lengths: {counts}, SD = {sd:.1f}"
        })
    else:
        results.append({
            "text": "Sentence length standard deviation is 8 or more words",
            "passed": False,
            "evidence": "Not enough sentences to measure"
        })

    # 4. No false revelation
    has_fr = has_false_revelation(text)
    results.append({
        "text": "Output contains no false-revelation pattern",
        "passed": not has_fr,
        "evidence": "No false-revelation patterns found" if not has_fr else "Found false-revelation pattern"
    })

    # 5. Paragraph count
    pcount = count_paragraphs(text)
    results.append({
        "text": "Output has exactly 3 paragraphs as requested",
        "passed": pcount == 3,
        "evidence": f"Found {pcount} paragraphs"
    })

    # 6. No banned opening
    has_bo = has_banned_opening(text)
    results.append({
        "text": "Output does not open with a banned opening",
        "passed": not has_bo,
        "evidence": "Opening is clean" if not has_bo else "Found banned opening pattern"
    })

    # 7. No negation-assertion patterns
    neg_assert = has_negation_assertion(text)
    results.append({
        "text": "Output contains no negation-assertion patterns",
        "passed": len(neg_assert) == 0,
        "evidence": "No negation-assertion patterns found" if not neg_assert else f"Found: {'; '.join(neg_assert)}"
    })

    return results


def grade_eval2(text, config):
    """Grade de-AI marketing copy eval."""
    results = []

    # 1. No banned vocab (extended list)
    found = has_banned_words(text, BANNED_WORDS_EXTENDED)
    results.append({
        "text": "Output contains none of the Tier 1 banned AI vocabulary (extended)",
        "passed": len(found) == 0,
        "evidence": f"No banned words found" if not found else f"Found banned words: {', '.join(found)}"
    })

    # 2. No em dashes
    dashes = has_em_dashes(text)
    results.append({
        "text": "Output contains no em dashes, en dashes, or double hyphens",
        "passed": len(dashes) == 0,
        "evidence": "No dashes found" if not dashes else f"Found dash types: {', '.join(dashes)}"
    })

    # 3. Preserves meaning
    keywords = ["collaborat", "team", "ai", "workflow", "productiv"]
    found_kw = [kw for kw in keywords if kw in text.lower()]
    results.append({
        "text": "Output preserves the original meaning (collaboration, teams, AI workflows, productivity)",
        "passed": len(found_kw) >= 3,
        "evidence": f"Found {len(found_kw)}/5 key concepts: {', '.join(found_kw)}"
    })

    # 4. False-revelation removed
    has_fr = has_false_revelation(text)
    results.append({
        "text": "The false-revelation pattern has been removed",
        "passed": not has_fr,
        "evidence": "No false-revelation patterns found" if not has_fr else "Found false-revelation pattern"
    })

    # 5. False-choice removed
    has_fc = has_false_choice(text)
    results.append({
        "text": "The false-choice framing has been removed",
        "passed": not has_fc,
        "evidence": "No false-choice framing found" if not has_fc else "Found false-choice pattern"
    })

    # 6. No trailing participials
    tp = has_trailing_participial(text)
    results.append({
        "text": "No trailing participial phrases",
        "passed": len(tp) == 0,
        "evidence": "No trailing participials found" if not tp else f"Found: {tp}"
    })

    # 7. "ensures" removed
    has_ensures = bool(re.search(r'\bensures?\b', text, re.IGNORECASE))
    results.append({
        "text": "The word 'ensures' has been replaced or removed",
        "passed": not has_ensures,
        "evidence": "'ensures' not found in output" if not has_ensures else "Found 'ensures' in output"
    })

    return results


def grade_eval3(text, config):
    """Grade Slack message eval."""
    results = []

    # 1. Under 50 words
    # Strip emoji shortcodes for word count
    clean = re.sub(r':\w+:', '', text)
    wc = word_count(clean.strip())
    results.append({
        "text": "Output is under 50 words total",
        "passed": wc < 50,
        "evidence": f"Word count: {wc}"
    })

    # 2. No headers or bullets
    has_hb = has_headers_or_bullets(text)
    results.append({
        "text": "Output contains no headers or bullet points",
        "passed": not has_hb,
        "evidence": "No headers or bullets found" if not has_hb else "Found headers or bullet points"
    })

    # 3. Uses contractions
    has_c = has_contractions(text)
    results.append({
        "text": "Output uses at least one contraction",
        "passed": has_c,
        "evidence": "Contractions found" if has_c else "No contractions found"
    })

    # 4. No banned vocab
    found = has_banned_words(text)
    results.append({
        "text": "Output contains none of the Tier 1 banned AI vocabulary",
        "passed": len(found) == 0,
        "evidence": f"No banned words found" if not found else f"Found banned words: {', '.join(found)}"
    })

    # 5. No sycophantic/signposting
    has_ss = has_sycophantic_or_signpost(text)
    results.append({
        "text": "No sycophantic openers or signposting phrases",
        "passed": not has_ss,
        "evidence": "No sycophantic/signposting patterns found" if not has_ss else "Found sycophantic/signposting"
    })

    # 6. No em dashes
    dashes = has_em_dashes(text)
    results.append({
        "text": "Output contains no em dashes, en dashes, or double hyphens",
        "passed": len(dashes) == 0,
        "evidence": "No dashes found" if not dashes else f"Found dash types: {', '.join(dashes)}"
    })

    return results


def grade_run(eval_id, text, config):
    if eval_id == 1:
        return grade_eval1(text, config)
    elif eval_id == 2:
        return grade_eval2(text, config)
    elif eval_id == 3:
        return grade_eval3(text, config)


def write_grading(eval_dir, eval_id, config):
    output_path = os.path.join(eval_dir, config, 'outputs', 'output.md')
    with open(output_path) as f:
        text = f.read()

    results = grade_run(eval_id, text, config)
    passed = sum(1 for r in results if r['passed'])
    total = len(results)

    grading = {
        "expectations": results,
        "summary": {
            "passed": passed,
            "failed": total - passed,
            "total": total,
            "pass_rate": round(passed / total, 2) if total > 0 else 0
        }
    }

    # Load timing if available
    timing_path = os.path.join(eval_dir, config, 'timing.json')
    if os.path.exists(timing_path):
        with open(timing_path) as f:
            grading['timing'] = json.load(f)

    grading_path = os.path.join(eval_dir, config, 'grading.json')
    with open(grading_path, 'w') as f:
        json.dump(grading, f, indent=2)

    return grading


if __name__ == '__main__':
    import sys
    iteration = sys.argv[1] if len(sys.argv) > 1 else 'iteration-1'
    base = f'/Users/michaelvandyke/Dev/claude-marketplace/plugins/human-voice-writer/human-voice-writer-workspace/{iteration}'

    evals = [
        ('blog-post-remote-work', 1),
        ('de-ai-marketing-copy', 2),
        ('slack-deploy-update', 3),
    ]

    print("=" * 60)
    print("GRADING RESULTS")
    print("=" * 60)

    for eval_name, eval_id in evals:
        eval_dir = os.path.join(base, eval_name)
        for config in ['with_skill', 'without_skill']:
            grading = write_grading(eval_dir, eval_id, config)
            s = grading['summary']
            print(f"\n{eval_name} / {config}: {s['passed']}/{s['total']} passed ({s['pass_rate']*100:.0f}%)")
            for exp in grading['expectations']:
                status = 'PASS' if exp['passed'] else 'FAIL'
                print(f"  [{status}] {exp['text']}")
                print(f"         {exp['evidence']}")

    print("\n" + "=" * 60)
    print("Grading complete. Results saved to grading.json files.")
