# Why `storyteller-guidance` is built the way it is

This document explains the design decisions behind the `storyteller-guidance` plugin. For what it does, see [reference.md](reference.md). For how to use it, see [how-to.md](how-to.md).

## The problem

People who need to tell a story don't think they need to tell a story.

A founder preparing a pitch thinks they are listing features. A leader preparing an all-hands thinks they are sharing news. An engineer preparing a talk thinks they are explaining architecture. In all three cases, the actual job is making an audience feel and do something specific, and the actual constraint is the audience's attention budget. Treating that as a feature list, a news bulletin, or a system diagram loses the room.

The standard advice ("tell a story") is useless because it doesn't name the moves. A storyteller's actual work has three parts:

1. **Diagnose** what the communication has to do (sell, convince, connect, explain, lead, impress, motivate). This determines almost everything that follows.
2. **Choose tactics** for each layer: the core idea, the arc, the characters, the style of delivery.
3. **Assemble and revise** without over-stacking or contradicting yourself.

Most people skip step 1 entirely and fail at step 2 by importing whatever moves they remember from the last memorable talk they saw. The result is communication that has shape but the wrong shape: a pitch built like a feature spec, an all-hands built like a press release, a talk built like a lecture.

`storyteller-guidance` is a plugin that fixes this by exposing the diagnostic and the tactics directly.

## The approach

The plugin runs a skill that:

1. Runs a diagnostic to find the gap.
2. Picks a recipe or assembles a custom tactic stack.
3. Confirms the shape before generating, allowing the user to redirect.
4. Produces the artifact in the right format.
5. Leaves a revision handle for the user to push back.

The skill operates in two modes (draft / coach), one of which is picked from the user's intent. Both modes use the same diagnostic and tactic catalog; they differ only in who does the writing.

```
User describes situation
         │
         ▼
   ┌─────────────┐
   │  Diagnostic │  ← seven questions, in order; first unanswered one names the gap
   └──────┬──────┘
          │
          ▼
   ┌─────────────────────────────────────┐
   │  Tactic selection:                  │
   │   recipe (if goal matches) OR       │
   │   custom stack (concept + structure │
   │   + style + character)              │
   └──────┬──────────────────────────────┘
          │
          ▼
   ┌──────────────┐
   │  Confirm     │  ← skill states the stack and asks "sound right?"
   └──────┬───────┘
          │
          ▼
   ┌─────────────────┐
   │  Draft (Mode A) │   OR   ┌──────────────────┐
   │                 │        │ Coach (Mode B)   │
   │  produce        │        │                  │
   │  artifact in    │        │  3 Socratic Qs   │
   │  asked format   │        │  per tactic      │
   └─────────────────┘        └──────────────────┘
```

The card-deck metaphor is the most important design choice and the rest of this document explains why.

## Why the card-deck metaphor

Storytelling theory is enormous. There are entire books on hooks, on arcs, on character work. The plugin compresses this into 54 cards plus 7 recipes for one specific reason:

**A card is a tactic at the granularity where decisions actually happen.**

When you write a pitch, you do not "use Aristotle's three-act structure." You make a specific choice: open with a hidden truth (*Secrets & Puzzles*) or open with a vivid moment (*Story Hooks*). The card resolves to a yes/no decision and a concrete framework. That's the right unit for an LLM to reason about and for a user to revise.

Larger units (entire frameworks, entire books) are too abstract to action. Smaller units (specific words, specific transitions) are too granular for the audience-feeling level. Cards sit at the right scale.

The seven categories (Concept, Explore, Character, Function, Structure, Style, Organise) come from the same logic: they map to the diagnostic questions. Each diagnostic question, if unanswered, sends you to one category. The category contains tactics that resolve that specific gap.

## Why the diagnostic is seven questions, not more

The diagnostic has exactly seven questions. Each maps to a category. Each is a yes/no question about whether the user has answered it:

| # | Question | Category if unanswered |
|---|---|---|
| 1 | Why does this need to be a story? | Concept |
| 2 | Where does the raw material come from? | Explore |
| 3 | Who are you in this story? | Character |
| 4 | What does this story have to make happen? | Function |
| 5 | What shape does the story take? | Structure |
| 6 | How will it be delivered? | Style |
| 7 | How does it survive after the telling? | Organise |

We rejected longer diagnostics (10+ questions) and shorter ones (3-question heuristics). The seven map cleanly to the seven tactic categories and the order is non-arbitrary: you cannot pick Structure before you know Function, you cannot pick Character before you know Concept, and so on. The first question the user cannot answer is the gap, and the gap names the category.

The skill does not have to surface all seven. Most situations imply four or five answers from context. The diagnostic is a routing table, not a checklist the user has to fill in.

## Why two modes (draft / coach)

A single mode would have been simpler. We picked two because users showed up with two genuinely different intents:

- **"Write this for me."** They have an upcoming moment, limited time, and want an artifact. Draft mode produces one.
- **"Help me think through this."** They have a situation and want to internalize the structure. Coach mode walks them through.

The modes are not "skill levels" (beginner / advanced). They are different jobs. A senior communicator who needs a 10-minute draft for a 1-hour pitch will use draft mode. The same person preparing a high-stakes layoff communication may use coach mode because they need to own every word.

The skill picks the mode from the user's request when it can ("write me a pitch" → draft; "coach me through" → coach). If unclear, it asks once.

Both modes use the same diagnostic and the same tactic catalog. The difference is who writes the final sentence. In draft mode, the skill writes; in coach mode, the user does.

## Why recipes exist alongside individual tactics

A recipe stacks tactics in a particular order for a common goal:

- **Stories that Connect** combines *Story Listening + Abstractions + Universal Stories + Story-ish Conversations + Circle of Life*.
- **Stories that Convince** stacks tactics for the case where you have expertise and need a less-informed audience to accept it.

Recipes exist because **most users have one of seven common goals**, and the right tactic combinations for those goals are well-understood. Forcing every user to assemble a custom stack from scratch wastes their attention.

The decision rule: if a recipe matches cleanly, use it. Custom stacks are for cases where no recipe maps. The SKILL.md is explicit: "Default to a recipe if the user's goal cleanly matches one. Recipes are pre-tuned tactic combinations; they save deliberation and rarely go wrong."

## Why "don't over-tactic" is a rule

The temptation when you have a 54-card deck is to use a lot of cards. We rejected this explicitly:

> A 15-minute talk needs 3-5 tactics, not 12. If you're stacking tactics to reassure yourself the story is "rich," you're hiding from the work of picking one good arc.

There are three reasons stacking too many tactics fails:

1. **Audiences cannot follow multiple structural arcs.** Pick *Man in a Hole* or pick *Rags to Riches*; not both.
2. **Tactic-stacking is a procrastination signal.** When users add more tactics, they usually do so because the diagnostic answer is unclear and they are hedging.
3. **The output gets paragraph-soupy.** A draft with 12 named tactics ends up with one paragraph per tactic and no through-line.

The plugin enforces "one Concept tactic for the core idea, one Structure tactic for the arc, one or two Style tactics for delivery, plus Character work to position the user" as the default custom stack. That's 4-5 tactics, which is the right ceiling.

## Why "audience as hero" is the default

For external communication, the skill defaults to *Hero & Guide*: the audience is the hero, you are the experienced guide who helps them get where they want to go.

This is the right default for almost every external pitch because:

- Audiences listen better to stories where they are the protagonist.
- The "I am the hero" frame (founder swagger, expert authority) consistently underperforms unless the audience is specifically there for the user's story.
- "Guide" gives the user permission to share expertise without sounding like they're performing it.

Override only when the story is genuinely about the user: founder origin, personal essay, apology. The SKILL.md makes this explicit and the override is one decision.

## Why Style stacks on Structure, not the other way

Once the arc is picked, style tactics layer on:

- *Story Hooks* for the opener
- *Three is the Magic Number* for memorable groupings
- *Movie Time* and *Rolls Royce Moment* for concreteness
- *Leave it Out!* to reduce
- *Show & Tell* if there are slides
- *Cut to the Chase* as a contingency

The order matters. Picking a *Story Hook* before the arc produces a hook that doesn't connect to the story. Picking *Three is the Magic Number* before the arc produces three things that don't add up to a structural beat. Arc first, style second.

## Trade-offs

### Tactic catalog vs. principles

We chose a 54-card catalog over a 5-principle framework. The trade-off:

| Approach | Strengths | Weaknesses |
|---|---|---|
| Cards (this skill) | Tactical, specific, picks-and-stacks well, no abstract decision-making at runtime | More to load; harder for first-time users to scan |
| Principles | Easier to memorize; fewer files | Forces the LLM to operationalize principles into tactics at runtime, which is less reliable |

We picked cards because the LLM does better with specific instructions than with principles it has to operationalize. The reference files are loaded lazily; the skill never reads all of them in one session.

### Diagnostic vs. fast path

We chose a diagnostic over a fast path ("just give me a pitch outline"). The trade-off:

- A fast path produces something faster but the output is generic.
- The diagnostic costs 2-3 turns at the start but the output is calibrated.

Users can short-circuit the diagnostic by stating the answers up front ("audience is VC partners, function is convince, structure should be *No Easy Way*"). When that happens, the skill skips straight to the draft.

### Two modes vs. one

We chose two modes (draft / coach) over one. The cost:

- More logic in the SKILL.md.
- One ambiguous case where the user's intent isn't clear, requiring a single clarifying question.

The value:

- Coaching mode is genuinely different work and produces genuinely different output.
- The mode split is what makes the plugin useful for high-stakes communications where the user has to own every word.

### Inspired-by attribution

The plugin is inspired by Pip Decks' *Storyteller Tactics* deck. We chose:

- Paraphrase the deck's principles in original language.
- Add original examples.
- Attribute prominently in the SKILL.md credits.
- Not reproduce the deck verbatim.

This is the right balance between honoring the source and producing a useful tool. The card categories, the diagnostic flow, and the recipe concept are borrowed; the specific language, examples, and integration with LLM workflows are original.

## Alternatives considered

### "Why not a slash command?"

We chose auto-trigger over a slash command. The reasoning:

- The skill description lists many trigger phrases ("pitch," "presentation," "memo," "launch announcement") because users describe the same task with different words.
- Requiring users to remember `/story` or `/pitch` would suppress activation.
- The skill explicitly does not trigger for technical documentation or transactional messages, so the auto-trigger has a clear off-switch.

If we observed users activating it without wanting it, we would add a slash command. We have not.

### "Why not a single output format?"

We chose six output formats (pitch, talk outline, slide outline, memo, story arc, coaching plan) over one. The reasoning:

- A pitch and a talk outline look different. Forcing them into one format would hide the structural difference.
- Each format has its own optimization (a memo leads with news; a talk outline leads with a hook).
- The skill picks the format from the situation, not from a flag. The cost is one occasional clarifying question.

### "Why not produce visual deliverables (actual slides, actual decks)?"

The skill produces *slide outlines*, not slides. We rejected slide generation because:

- The structural choice (slide-by-slide message, visual idea) is the high-value work.
- The visual production (templates, fonts, image picking) is a different problem with different tools.
- A handoff to a designer or a slide tool with a good outline is faster than a full-deck generation that gets restyled anyway.

The *Show & Tell* tactic explicitly says slide text and spoken text should not duplicate, which means a useful skill output is the spoken script with one-line visual hints, not full slide content.

## What this means for you

When you are using `storyteller-guidance`, the design above means:

- **You will be diagnosed before drafting.** The skill won't write until it knows your audience, your function, and your stage. If you don't want diagnosis, state the answers up front.
- **You can push back on every choice.** The skill states tactics before using them. "Use *No Easy Way* instead of *Rags to Riches*" works.
- **You get a tactic stack with the artifact.** Every output names the tactics it used so you can revise on the same scaffolding.
- **You always get a revision handle.** The skill ends with 1-2 questions only you can answer. Real specificity (a customer's quote, a specific number, a sensory detail) is what carries the difference between a fine draft and a memorable one. The skill can shape; only you can supply.

## Related

- [Reference: complete card catalog and recipes](reference.md)
- [How-to: common tasks](how-to.md)
- [Plugin SKILL.md](../../plugins/storyteller-guidance/skills/storyteller-guidance/SKILL.md)
