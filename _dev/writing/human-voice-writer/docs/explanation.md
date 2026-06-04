# Why `writer` works the way it does

This document explains the design rationale behind the `writer` plugin. For what it does, see [reference.md](reference.md). For how to use it, see [how-to.md](how-to.md).

## The problem

LLM output reads as LLM output, and people can tell.

That sentence sounds obvious. The interesting part is *why*. The cause is not stylistic preference; it is a reproducible statistical signature created by Reinforcement Learning from Human Feedback (RLHF) and by the structure of the training corpus. During RLHF, human raters rewarded a particular kind of writing: confident, balanced, well-organized, vocabulary-rich, structurally tidy. Models learned to produce that voice as the default. The voice is also the voice of an essay-graded for vocabulary, which is why it shows up in the same shape every time:

- A predictable rhythm of sentence lengths in a narrow 15-25 word band.
- A preferred vocabulary that overlaps heavily across providers and prompts (`leverage`, `delve`, `nuanced`, `multifaceted`).
- Structural moves like "It's not just X, it's Y" and trailing participial phrases that show up at multiples of the human rate.
- Punctuation defaults (em dash, semicolon) that signal AI authorship in observable proportions.

This is not a vague aesthetic. AI-detection tools (GPTZero, Binoculars, Pangram Labs, DetectGPT) work by measuring exactly these features and outputting probabilities. The most damning research finding is the simplest one: low **burstiness**, the statistical name for sentence-length uniformity, is a single feature that distinguishes AI from human text with high reliability.

The cost is real. If your blog post, email, sales copy, or research summary reads as AI-generated, the reader updates on it. Trust drops. The signal that you wrote the thing yourself, with judgment and choices and a position, is gone.

`writer` is a plugin that fights this default.

## The approach

The plugin runs a skill that applies seven layered rules to any writing task. Each rule is a research-derived correction to a specific AI signature.

```
Layer 1: Word            →  Rule 1 (banned vocabulary), Rule 5 (assistant register)
Layer 2: Sentence        →  Rule 2 (burstiness), Rule 3 (no anaphora), Rule 6 (deep grammar)
Layer 3: Paragraph/doc   →  Rule 4 (break templates), Rule 7 (length calibration)
Layer 4: Tone            →  Rule 5 (assistant register), Rule 6 (active voice)
```

The four-layer model comes from a synthesis of Nielsen Norman Group research, Joseph Thacker's vocabulary-constraint approach, the AIMCLEAR quantifiable parameters method, Scale AI's "strategic inefficiencies" framework, and CMU/PNAS stylometric findings. Each layer corresponds to a different scale at which an AI signature manifests. Banning words alone (Layer 1) fixes 30% of the signal. Burstiness (Layer 2) fixes another large chunk. Structural break (Layer 3) handles document-level tells. Tone calibration (Layer 4) handles the deepest signature, which is the "helpful assistant" register.

The reference files split along the same axis. [`ai-tells.md`](../../plugins/human-voice-writer/skills/human-voice-writer/references/ai-tells.md) is the catalog of *what to remove*, organized by detection-significance tier. [`humanization-techniques.md`](../../plugins/human-voice-writer/skills/human-voice-writer/references/humanization-techniques.md) is the catalog of *how to write instead*, organized by layer.

## Why the banned words are the banned words

The vocabulary list is not an opinion. It is the intersection of:

1. **Wikipedia AI Cleanup project** — words that human editors removed in 24 documented patterns after flagging articles as AI-written.
2. **Pangram Labs detection guide** — the commercial detection list that surfaced in their product.
3. **A 2024 PNAS study** — words found at 50-150x higher LLM frequency than human frequency in the same genre.
4. **GPTZero / Binoculars methodology** — vocabulary features used in detection scoring.

Words on multiple lists make the Tier 1 ban. Words on one list are still flagged but with weaker confidence.

The specific bans look strange because the words look harmless. `delve`, `leverage`, `nuanced`, `multifaceted`, `pivotal` are all real English words. The point is not that they are bad; the point is that LLMs use them so much more often than humans do that their presence is a probabilistic signal. A single `delve` in a paragraph is not damning. Three are.

The plugin's stance is: if a word's main feature is "no specific reason to use it here," cut it. A specific reason ("the author writes scientific papers and `delve` is field-appropriate") overrides the ban.

## Why the punctuation bans are absolute

Em dashes, en dashes used as em dashes, and double hyphens are banned **unconditionally**. The reasoning is different from the vocabulary bans:

- The em dash is the single most visible AI tell that does not require careful reading to spot. Humans use em dashes occasionally; LLMs use them as a default connector between any two related thoughts.
- Em dashes survive copy-paste cleanly. Vocabulary edits can be reasoned about; punctuation edits are mechanical.
- Restructuring around an em dash almost always improves the sentence. The em dash exists because the writer did not commit to one of two sentence shapes (period + new sentence, or comma + dependent clause). Forcing the commitment yields better prose.

Tier 1 banned vocabulary has the carve-out "unless quoting someone or the user specifically requests them." Em dashes have no carve-out. The plugin will refuse to emit one, full stop.

## Why burstiness is the single most important rule

The detection literature is unusually clear on this. Burstiness (the standard deviation of sentence lengths in a passage) is:

- A simple, language-agnostic metric.
- Highly resistant to surface-level rewrites (you can swap every banned word and burstiness stays low).
- Used as the core input in most modern detection tools, including GPTZero and Binoculars.

A piece with full Tier 1 vocabulary scrubbing but still-uniform sentence lengths reads as AI to a tool *and* to a careful reader. A piece with mediocre vocabulary but real burstiness often passes.

The plugin's Rule 2 enforces specific numbers:

- Sentence length range from 3-8 word punches to 25-35 word compound sentences.
- No three consecutive sentences within 5 words of each other.
- Standard deviation of 8+ words per paragraph.
- 10-15% of sentences starting with "And" or "But."

These numbers come from samples of human prose analyzed against the same metrics. The plugin treats them as targets, not as quotas; the SKILL.md explicitly says "If you've already varied your openings well, you don't need to force an `And` in."

## Why deep grammar matters most for hard-to-fool readers

CMU and PNAS researchers found two specific grammatical patterns where LLMs diverge most sharply from humans:

| Pattern | Human rate | LLM rate |
|---|---|---|
| Trailing present-participial phrases (`..., improving efficiency`) | baseline | 2-5x |
| Nominalizations (`the implementation of` instead of `implementing`) | baseline | 1.5-2x |

These patterns are subtle. A reader who is not specifically looking for them will not flag them by name; they will just say "this feels off." Removing them is one of the highest-leverage interventions because it fixes the *feeling* without touching the visible content.

The plugin's Rule 6 targets both explicitly. Trailing participials get restructured into separate sentences or `which` clauses. Nominalizations get reverted to verbs. The output reads more active, more concrete, more like a person who knows what they are saying.

## Why the assistant register is the deepest signature

RLHF trained models to behave like helpful assistants. That register is the model's deepest default. It manifests as:

- "Great question!" openings.
- Sycophantic agreement before disagreement.
- Refusal to take positions ("considerations include...").
- Formulaic hedging ("It's important to note that...").
- Symmetric "on the one hand / on the other hand" structures that avoid commitment.
- Generic closings ("Embrace the power of...").

This is the register the model *wants* to write in. Every other rule pulls in this direction unless explicitly overridden. The plugin's Rule 5 makes the override explicit: take positions, express genuine uncertainty when present, match register to context, drop sycophancy.

The hardest cases are positions the model lacks confidence about. The honest move is the human one: "I'm not sure about this" beats "It's important to consider multiple perspectives." The plugin biases toward honesty over balance.

## Trade-offs

### Specificity vs. portability

A rule list is precise but brittle. As detection tools evolve and as model defaults change, some bans will become obsolete and new ones will emerge. The plugin is versioned (currently 1.0.0) and the SKILL.md is the source of truth; updates to the bans live there.

What we gave up: a future-proof rule set. There is no such thing. The plugin's research provenance is documented so users can audit which findings are still load-bearing.

### Cost of self-review

Rule 4 (break templates) and Rule 7 (length calibration) cost generation time. The skill writes a first draft, then runs a self-review pass against a long checklist, then fixes whatever the checklist flagged. This is roughly 2x the latency of a one-shot generation.

What we gained: fewer regressions. The self-review catches Tier 1 vocabulary and banned patterns that the first draft missed. Without it, the plugin would emit drafts that still read as AI a non-trivial fraction of the time.

### Rules sometimes pull against each other

The SKILL.md has a `## When Rules Conflict` section. Examples:

- Fragments are good for emphasis but bad for clarity.
- "And"/"But" starters at 10-15% are a target, not a quota.
- Avoiding banned patterns is good but not if it produces awkward sentences.

The plugin's resolution rule is the right one: "When two rules conflict, choose whichever option sounds more like something a human would actually write." This deliberately leaves judgment in the model, not in a rigid lookup table.

What we gave up: deterministic output. Two runs of the same prompt may produce different valid rewrites.

## Alternatives considered

### "Why not a detector?"

The plugin is a *writer*, not a *detector*. We rejected building a detection-and-rewrite loop for two reasons:

- Detection tools have false-positive and false-negative rates. Running a detector after generation would punish writing that is genuinely good but happens to score AI-like.
- The detection literature is publicly available. Building the bans directly from the literature is more transparent than wrapping a third-party detector.

### "Why not let the model do it freeform?"

A version-zero of this plugin tried "write this so it doesn't sound like AI" as the entire prompt. The output was unreliable: the model agreed in the abstract but produced the same default voice in the specific case. The rule list is what makes the behavior reproducible.

### "Why ban words instead of teaching style?"

Banning is enforceable; teaching style is not. "Vary sentence length" without a number is aspirational; "no three consecutive sentences within 5 words of each other" is measurable. The plugin biases toward measurable rules.

### "Why include eval cases?"

Three evals are not enough for a real benchmark, but they are enough to:

- Document what "good output" looks like for the three most common cases (blog post, humanize, Slack message).
- Give an external skill-evaluation harness something to score against.
- Let the plugin's author check for regressions when revising the SKILL.md.

A full benchmark would have 50+ cases. The three shipped are anchors, not coverage.

## What this means for you

When you are using `writer`, the design above means:

- **You get reproducible bans, not vibes.** The plugin will not arbitrarily decide one piece is "AI-sounding" and another is not. The rules are written down.
- **You can override.** The SKILL.md explicitly defers to the user when rules and clarity conflict. "Allow one em dash if removing it makes the sentence awkward" works.
- **You can audit.** Every ban traces to a citation. If you disagree with a specific ban, the source is in the reference file and the explanation file you are reading.
- **You will not be saved from a bad idea.** The plugin can fix the voice; it cannot fix a vague brief, an unspecified audience, or a missing position. Good writing starts with a clear thought.

## Related

- [Reference: complete rules and banned lists](reference.md)
- [How-to: invoke and use the skill](how-to.md)
- [Plugin SKILL.md](../../plugins/human-voice-writer/skills/human-voice-writer/SKILL.md)
- [Reference: AI tells catalog](../../plugins/human-voice-writer/skills/human-voice-writer/references/ai-tells.md)
- [Reference: humanization techniques](../../plugins/human-voice-writer/skills/human-voice-writer/references/humanization-techniques.md)
