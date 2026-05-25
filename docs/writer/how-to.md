# `writer` how-to

Task-oriented guides for common writer-plugin workflows. For the complete rules and banned-vocabulary list, see [reference.md](reference.md).

## How to invoke the skill

The skill runs three ways. Pick whichever matches your situation.

### Option A: Slash command with a prompt

```
/writer:human write a 3-paragraph blog post about why remote work is here to stay, audience is HR professionals
```

The slash command activates the skill, then applies it to the prompt that follows.

### Option B: Natural language

The skill auto-triggers on phrases like:

- "write this naturally"
- "make it sound human"
- "don't sound like AI"
- "write like a real person"
- "humanize this:"
- "de-AI this text:"

```
Write me a Slack message telling the team the migration finished. Make it sound human.
```

### Option C: Inline editing

Paste existing text and ask for a humanization pass:

```
Humanize this:

"In today's rapidly evolving digital landscape, organizations must leverage cutting-edge
technologies to foster robust collaboration..."
```

The skill identifies which Tier 1 and Tier 2 patterns are present, then rewrites preserving the original meaning.

## How to humanize an existing piece of AI-generated text

The skill's Workflow B (Edit existing text) is built for this.

### Prerequisites

- A piece of text you suspect reads as AI-generated.
- The text is not code, a data table, or structured technical output.

### Steps

1. Paste the text into the chat with a clear instruction:
   ```
   Humanize this. Keep the meaning, change the voice:

   <your text here>
   ```

2. The skill will:
   - Read `references/ai-tells.md` to identify which patterns are present.
   - Read `references/humanization-techniques.md` for the technique library.
   - Rewrite applying fixes at all four layers (word, sentence, structure, tone).

3. Review the output. Two things to check:
   - **Meaning preserved.** Every claim from the original should still be there.
   - **Length appropriate.** If the original was a Slack message, the rewrite should still be a Slack message. If it grew, ask for a shorter version.

### Verification

Use the eval criteria as a checklist. Scan the rewrite for:

- Any of the Tier 1 banned vocabulary (the complete list is in [reference.md](reference.md#banned-vocabulary-tier-1)).
- Em dashes (—), en dashes used as em dashes (–), or double hyphens (`--`).
- "It's not just X, it's Y" or "not only X, but also Y" patterns.
- Negation-assertion patterns ("That's not speculation.", "They aren't X. They're Y.").
- Trailing participial phrases (`..., improving efficiency`).
- Three or more consecutive sentences of similar length.

If any survive, ask for a second pass: "Run the self-review checklist on this draft."

## How to match a specific person's voice

Workflow C handles this. The skill uses a 16-dimension framework, but the key input is **samples** of the voice you want to match.

### Prerequisites

- 2-3 actual writing samples from the target voice. The skill works better with samples than descriptions.
- The samples should be the same type of writing you want produced (blog post samples for a blog post task, etc.).

### Steps

1. Paste the samples into the chat with the writing task:
   ```
   Write a launch announcement for our new feature.

   Match this voice — here are three samples:

   Sample 1:
   <sample text>

   Sample 2:
   <sample text>

   Sample 3:
   <sample text>
   ```

2. The skill will analyze the samples across all 16 dimensions (formality, vocabulary, sentence structure, punctuation, humor, paragraph architecture, stance, transitions, openings, closings, metaphor, perspective, emotion, cultural references, rhythm, complexity handling).

3. The skill will produce writing rules from the analysis, then generate the announcement using those rules plus the seven core rules.

### Why samples beat descriptions

The Nielsen Norman Group finding: actual writing samples outperform tone descriptors, which outperform author / celebrity name references. "Write like Paul Graham" is the weakest input. "Write in a punchy, contrarian, blog-style voice" is better. Three real Paul Graham essays are best.

Em dashes are banned regardless of voice target. If your samples contain em dashes, the skill will preserve the *rhythm* the em dash creates but use periods, commas, colons, or parentheses instead.

### Verification

Read the output aloud. Does it sound like the same person who wrote the samples? If not, surface the gap:

- "The output is more formal than the samples. Loosen it up."
- "The samples have one-sentence paragraphs. The output is too dense."
- "The samples use a specific term, [X]. The output is missing it."

The skill will run another pass with the correction.

## How to handle the skill over-writing

Default AI behavior is to produce too many words. The skill's Rule 7 explicitly fights this, but it can still over-deliver on long-form prompts.

### Symptom

You asked for "a quick Slack update." You got three paragraphs.

### Fix

Be explicit about length:

```
A 1-sentence Slack update. Just the result, no context, no framing.
```

Or:

```
Three sentences, max 50 words total. Casual register.
```

The skill respects explicit length constraints. Vague ones ("brief," "short," "quick") leave more room for interpretation.

## How to handle the skill being too aggressive

The skill can occasionally cut too much: a clear technical sentence sounds awkward after banned-word removal, or a deliberately rhetorical move ("It's not the X. It's the Y.") gets flattened because it matches a banned pattern.

### Symptom

The rewrite is unclear or feels mechanical.

### Fix

The SKILL.md has an explicit conflict-resolution section:

> When two rules conflict, choose whichever option sounds more like something a human would actually write. Read it out loud. If it sounds weird, it is weird.

Push back with that framing:

```
Try again. The previous version cut too much. The original "[specific sentence]" was actually clear; the
problem was elsewhere in the paragraph.
```

Or:

```
Allow one em dash if removing it makes the sentence awkward. Just one.
```

The skill obeys explicit user overrides. The bans are defaults, not absolutes.

## How to use the skill on documentation

Documentation is a special case. Many of the seven rules apply, but some friction is real.

### What still applies

- Banned punctuation (em dashes, en dashes, double hyphens). Docs should not have them.
- Banned vocabulary (`leverage`, `utilize`, `delve`, etc.). Always use plain words.
- Sycophantic / assistant register. Documentation is not chat.
- Length calibration. Reference entries should be short; explanations can be long.

### What needs adjustment

- **Burstiness.** Reference docs often have parallel structure across rows (every API entry has the same shape). That is fine; do not force burstiness into a table.
- **Anaphora chains.** Same as above. A list of "How to X" headings is not anaphora abuse.
- **Topic sentences.** Reference docs benefit from clear topic sentences for scanning. Break the rule here.

### Prompt template

```
Write the API reference section for [feature]. Apply the writer plugin's word/punctuation rules. Skip
the burstiness rule for table rows. Keep topic sentences clear for scanning.
```

## How to humanize without the skill (manual checklist)

If you want to humanize a draft yourself and use the skill only for review:

1. Run the text through the [banned-vocabulary list](reference.md#banned-vocabulary-tier-1) with `grep`:
   ```bash
   echo "$YOUR_TEXT" | grep -iE 'delve|leverage|utilize|robust|nuanced|foster|streamline|holistic|harness'
   ```
2. Search for em dashes: `grep -F '—'`
3. Search for trailing participials: `grep -E ', [a-z]+ing'` (this catches most but has false positives).
4. Read aloud. Anything that sounds like a press release, rewrite.

Then ask the skill to review:

```
Review this draft against the writer plugin's rules. Flag any tells I missed.
```

## How to evaluate the skill's output

The plugin ships an eval suite at `plugins/human-voice-writer/skills/human-voice-writer/evals/evals.json` with three test cases. The full list of expected behaviors is in [reference.md](reference.md#eval-suite).

You can use the eval prompts as your own informal test: pick one, run it through `/writer:human`, and check the output against the eval's `expectations` list.

There is no shipped test runner. The evals are intended for external skill-evaluation harnesses.

## Troubleshooting

### The output still uses banned words

The skill self-reviews, but words occasionally slip through. Ask for a second pass:

```
Run the Tier 1 vocabulary check. Anything banned in this draft should be replaced.
```

### The output is the wrong length for the format

Be explicit. "Short" is ambiguous. "Two sentences" is not.

### The output ignored my voice samples

Two common causes:

- The samples were too short or too few. Try with 2-3 full pieces, not 2-3 paragraphs.
- The samples were paraphrased or summarized. The skill needs the raw text; rhythm and structure carry voice.

### The skill activated when I didn't want it to

If you are writing code, configs, or a data table and the skill is restructuring your output, say so:

```
This is technical reference output. Skip the humanization rules.
```

The skill explicitly does not apply to code, data, or structured technical output.

## Related

- [Reference: complete rules and banned lists](reference.md)
- [Explanation: why these rules](explanation.md)
- [Plugin SKILL.md](../../plugins/human-voice-writer/skills/human-voice-writer/SKILL.md)
- [Before & after worked example](../../plugins/human-voice-writer/examples/before-after.md)
