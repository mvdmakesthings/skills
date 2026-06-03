# `writer` reference

Complete reference for the `writer` plugin: the slash command, the skill, the seven core rules, the banned vocabulary list, the reference files, and the eval suite.

## Slash command

### `/writer:human [prompt]`

Activates the `human-voice-writer` skill, then applies it to the user's request. The skill is also auto-triggered by phrases like "write this naturally," "make it sound human," "don't sound like AI," or "write like a real person" without the slash command.

| Argument | Type | Required |
|---|---|---|
| `[prompt]` | string | yes when called via the slash command; the prompt describes what to write or what existing text to humanize |

The slash command is defined at `plugins/human-voice-writer/commands/human.md` and routes to `skills/human-voice-writer/SKILL.md`.

## Skill triggers

The skill activates on:

- Explicit slash command: `/writer:human ...`
- Phrases in the user's message: "write this naturally," "make it sound human," "don't sound like AI," "write like a real person"
- Editing tasks: "humanize this," "de-AI this text"
- Any writing task where authenticity matters (long-form content, emails, articles, reports, documentation, blog posts, creative writing, social media copy, proposals, memos)

The skill does **not** apply to:
- Code
- Data tables
- Structured technical output (API schemas, configs, SQL)

## The seven core rules

The skill applies seven layered rules to every piece of writing. They are listed in the order they apply during a write.

### Rule 1: Ban the AI vocabulary

Words, phrases, and punctuation that AI detectors flag at high signal strength.

#### Banned vocabulary (Tier 1)

These appear on every AI-detection list:

`delve`, `tapestry` (metaphorical), `landscape` (metaphorical, especially "digital landscape"), `navigate` (metaphorical), `leverage`, `foster`, `robust`, `utilize`, `nuanced`, `multifaceted`, `pivotal`, `underscores`, `aforementioned`, `commendable`, `noteworthy`, `intricate`, `beacon`, `realm`, `embark`, `spearheading`, `holistic`, `synergy`, `paradigm`, `transformative`, `groundbreaking`, `cutting-edge`, `game-changer`, `unlock` (metaphorical), `harness`, `streamline`, `cornerstone`, `underpinning`, `overarching`, `encompasses`, `facilitates`, `catalyze`, `bolster`, `augment`, `elucidate`, `meticulous`, `discerning`, `burgeoning`, `bustling`, `moreover`, `furthermore`, `nevertheless`, `notwithstanding`, `hitherto`, `myriad`, `plethora`, `juxtaposition`, `dichotomy`, `crucible`, `straightforward`, `ensures` / `ensures that`, `respective` / `respectively`, `at the forefront`, `at the heart of`, `in the realm of`, `at its core`, `at the end of the day`, `serves as a testament to`, `it's important/worth noting that`, `the importance of X cannot be overstated`

The complete list with research provenance is in [`plugins/human-voice-writer/skills/human-voice-writer/references/ai-tells.md`](../../plugins/human-voice-writer/skills/human-voice-writer/references/ai-tells.md). For why these specific words are flagged, see [explanation.md](explanation.md#why-the-banned-words-are-the-banned-words).

#### Banned punctuation

| Character | Constraint |
|---|---|
| Em dash (—) | Never. Restructure with periods, commas, colons, or parentheses. |
| En dash used as em dash (–) | Never. Same fix. |
| Double hyphen (`--`) | Never. Same fix. |

#### Banned rhetorical patterns

| Pattern | Example |
|---|---|
| False-revelation | "It's not just X, it's Y" |
| Parallel padding | "Not only X, but also Y" |
| Negation-assertion (short) | "That's not speculation." |
| Negation-assertion (pair) | "They aren't junior employees. They're senior engineers." |
| Negation-assertion (X-then-Y) | "Remote work stopped being a perk. It's infrastructure now." |
| False-choice framing | "Whether you're a beginner or a seasoned pro..." |
| Over-signposting | "Let's break this down," "Here's the thing," "Let me explain" |
| Recap opener | "As we discussed earlier..." |
| Imagine opener | "Imagine a world where...," "Picture this:" |
| Realm opener | "In today's rapidly evolving...," "In the realm of..." |
| Hedging filler | "It's important to note that...," "It's worth mentioning..." |
| Tidy trinity | "Three things matter: clarity, consistency, and communication." |
| Question-then-answer (overused) | "What makes this different? It's the approach." |
| "From X to Y" sweep | "From onboarding to offboarding" |
| Paired synonym | "clear and concise," "robust and scalable" |
| Hollow intensifier | "truly," "really," "incredibly," "absolutely," "extremely" |
| "By [gerund]" chain | "By implementing this framework..." |
| "Allows/enables/empowers you to" | "The dashboard allows you to monitor..." |
| Weasel quantifier (no number) | "significant," "substantial," "considerable" |
| `key` as adjective | "key takeaways," "key insights" |
| `respective` / `respectively` | almost always cuttable |
| Transition word overuse | "additionally," "however," "consequently," "therefore," "thus" |

Once per piece is fine for the question-then-answer pattern and for the hollow intensifiers. More than that is a tell.

### Rule 2: Vary sentence length (burstiness)

The highest-impact humanization technique. AI detectors use sentence-length uniformity as a core metric.

| Constraint | Target |
|---|---|
| Sentence length range | Mix 3-8 word punches with 25-35 word compound sentences |
| Consecutive same-length sentences | No three within 5 words of each other |
| Standard deviation across a paragraph | 8+ words |
| "And" / "But" sentence starters | 10-15% of sentences |
| Same-word starters in sequence | Never 3+ in a row |
| Fragments | Allowed and encouraged for emphasis |

### Rule 3: Eliminate repetitive sentence patterns

| Banned | Example |
|---|---|
| Anaphora chains | "It means faster deployments. It means fewer bugs. It means happier engineers." |
| Vague "This" opener | "This underscores the importance of..." |
| Colon-to-tidy-list | "Three things matter: clarity, consistency, and communication." |
| Semicolon overuse | Use periods instead. |

### Rule 4: Break structural templates

| Constraint | Detail |
|---|---|
| Topic-elaboration-summary pattern | Do not apply to every paragraph |
| Paragraph length | Vary; mix 1-sentence with 5-6 sentence paragraphs |
| Summary paragraphs | Never restate what was already said |
| Point placement | Allow the point to arrive at the end sometimes |
| Paragraph openings | Vary across claims, questions, fragments, dependent clauses |

### Rule 5: Kill the assistant register

| Constraint | Detail |
|---|---|
| Position-taking | Take positions instead of defaulting to "both sides" |
| Uncertainty | Express genuine uncertainty ("I'm not sure," not "considerations include") |
| Contractions | Mandatory in informal and semi-formal registers |
| Sycophantic openings | Banned ("Great question!" etc.) |
| Generic closings | Banned |
| Register match | Casual when casual is called for, formal when formal is called for |

### Rule 6: Eliminate deep grammatical AI signatures

From CMU/PNAS stylometric research. The hardest patterns to detect, most statistically significant.

| Pattern | Human rate | AI rate |
|---|---|---|
| Trailing participial phrases ("...improving efficiency") | 1x | 2-5x |
| Nominalizations ("the implementation of") | 1x | 1.5-2x |
| Passive voice | varies | overused as a hedging mechanism |

Fix: restructure trailing participials into separate sentences or `which` clauses. Use active voice and concrete verbs by default.

### Rule 7: Calibrate length to format

AI over-writes. Fight it.

| Format | Target length |
|---|---|
| Slack message | A few sentences. Not three paragraphs. |
| Short email | 3-5 sentences. Not a page. |
| One-paragraph answer | One paragraph. Don't expand it to four. |
| When the user asks for "quick" or "short" | Actually short. |

## The three workflows

The skill has three operating modes, picked from the user's request.

### Workflow A: Write new content

1. Determine register (casual / professional / formal / technical) and format from the request.
2. Consult `references/ai-tells.md` for any uncertain words or patterns.
3. Write the first draft applying all seven rules.
4. Self-review pass against the full checklist (see SKILL.md for the complete list).
5. Fix issues before delivering.

### Workflow B: Edit existing text

1. Read `references/ai-tells.md` to identify Tier 1 and Tier 2 patterns present in the source.
2. Read `references/humanization-techniques.md` for the full technique library.
3. Identify every specific problem.
4. Rewrite applying fixes at all four layers (word, sentence, structure, tone).
5. Preserve the original meaning and information. Change *how* it is said, not *what* is said.

### Workflow C: Match a specific voice

1. Read `references/humanization-techniques.md` for the 16-dimension voice framework.
2. Analyze the user's samples across all 16 dimensions, producing measurable observations (not adjectives).
3. Preserve the sample's structure. Rhythm is part of voice; do not flatten paragraph breaks, sentence lengths, or formatting patterns from samples.
4. Generate writing rules from the analysis.
5. Apply the rules plus the seven core rules.

## The 16-dimension voice framework

When matching a specific voice, the skill analyzes samples across these dimensions:

| # | Dimension | Captured as |
|---|---|---|
| 1 | Formality level | contraction frequency, register, colloquialism count |
| 2 | Vocabulary preferences | simple vs. complex, jargon frequency, signature words, banned words |
| 3 | Sentence structure | average length, burstiness range, fragment use, active/passive ratio |
| 4 | Punctuation habits | ellipses, semicolons, exclamation marks, parentheses, colon usage |
| 5 | Humor style | dry, self-deprecating, witty, absurdist, absent |
| 6 | Paragraph architecture | short punchy vs. long blocks, one-sentence paragraph frequency |
| 7 | Stance and certainty | hedging frequency, bold claim willingness, boosters vs. qualifiers |
| 8 | Transition style | explicit connectors, implicit flow, abrupt topic shifts |
| 9 | Opening patterns | how they start pieces, sections, paragraphs |
| 10 | Closing patterns | how they end pieces, sections, paragraphs |
| 11 | Metaphor and imagery | frequency, source domains, originality |
| 12 | Perspective and pronouns | first-person frequency, "we" vs. "I," direct address |
| 13 | Emotional expression | restrained vs. expressive, where emotion surfaces |
| 14 | Cultural references | what they reference (pop culture, literature, sports, tech) |
| 15 | Rhythm and cadence | how sentences flow read aloud, pacing |
| 16 | Complexity handling | how they break down hard ideas (analogies, examples, building blocks) |

Em dashes and en dashes are banned regardless of voice target.

**Critical finding (Nielsen Norman Group):** actual writing samples outperform tone descriptors, which outperform author/celebrity name references. Always prefer sample analysis over abstract style descriptions.

## Reference files

The skill ships two reference files plus a before/after example.

| File | Purpose | When to read |
|---|---|---|
| `skills/human-voice-writer/references/ai-tells.md` | Complete banned vocabulary, banned patterns, and statistical deep patterns organized by tier. | When uncertain whether a word or pattern is an AI tell, or when editing text. |
| `skills/human-voice-writer/references/humanization-techniques.md` | Four-layer technique library (word, sentence, structure, tone) and the 16-dimension voice framework. | When deep-editing, matching a person's voice, or for high-stakes output. |
| `examples/before-after.md` | A worked example of the skill's effect on a paragraph about pizza, with annotations explaining each transformation. | When teaching the plugin to someone new. |

## Eval suite

The plugin ships an eval suite at `skills/human-voice-writer/evals/evals.json` with three test cases:

| ID | Prompt | What's checked |
|---|---|---|
| 1 | Write a 3-paragraph blog post about why remote work is here to stay (HR audience). | No Tier 1 banned vocab; no em/en dashes or `--`; sentence-length std dev ≥ 8; no false-revelation; exactly 3 paragraphs; no banned openings; no negation-assertion patterns. |
| 2 | Humanize a paragraph dense with AI tells. | No Tier 1 banned vocab; no banned punctuation; original meaning preserved; specific patterns removed; no trailing participials; `ensures` removed. |
| 3 | Write a brief Slack message about a database migration. | Under 50 words; no markdown headers or bullets; ≥1 contraction; no Tier 1 banned vocab; no sycophantic openers or signposting; no banned punctuation. |

There is no test runner shipped with the plugin; the evals are designed to be consumed by external skill-evaluation harnesses.

## Research provenance

The plugin's bans are sourced from:

- **Wikipedia AI Cleanup project** — 24 documented patterns from editors removing AI-generated content
- **Pangram Labs** — commercial AI detection guide
- **CMU / PNAS** — stylometric research on present-participial and nominalization rates
- **GPTZero / Binoculars** — detection methodology, including burstiness and perplexity metrics
- **Nielsen Norman Group** — style research, including the finding that samples outperform descriptions
- **Stanford DetectGPT** — probability-curvature finding

## Related

- [How-to: invoke the skill](how-to.md)
- [Explanation: why these rules exist](explanation.md)
- [Plugin SKILL.md](../../plugins/human-voice-writer/skills/human-voice-writer/SKILL.md)
- [Before & after example](../../plugins/human-voice-writer/examples/before-after.md)
