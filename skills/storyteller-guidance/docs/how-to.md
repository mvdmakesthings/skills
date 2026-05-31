# `storyteller-guidance` how-to

Task-oriented guides for the most common communications the skill handles. For the complete card catalog and recipes, see [reference.md](reference.md).

## How to get a first-draft pitch

Use when: you have a meeting, a fundraising call, or a sales conversation coming up and need a story-shaped pitch.

### Steps

1. Open the conversation with the situation:
   ```
   I'm pitching our developer tools company to a VC next Tuesday. 12 minutes, 4 partners in the room,
   they're seed-stage focused, our stage is Series A. Help me build the pitch.
   ```

2. The skill will run the diagnostic. If it can infer your audience (skeptical insiders, partner committee) and your goal (raise capital), it will skip those questions. If anything is unclear, it asks one question at a time.

3. The skill confirms the tactic stack in one or two sentences before drafting:
   > "I'm going to build this as a *Rags to Riches* arc with a *Secrets & Puzzles* hook, because your audience is skeptical insiders and they'll respect a hidden-truth opening more than a chest-thumping one. Sound right?"

4. Push back if the shape is wrong. The skill will reassemble. Common pushback:
   - "The VCs already know our space. Skip the explainer."
   - "We've had a setback last quarter. *Rags to Riches* won't read as honest. Try *No Easy Way*."

5. After confirmation, the skill produces:
   - A 1-3 sentence short version (the "elevator").
   - A longer version with problem-promise-path-payoff structure.
   - A named tactic stack at the end so you can revise on the same scaffolding.

6. The skill ends with 1-2 questions only you can answer. Examples: "What was the specific moment a customer told you this was the right thing? That moment is the *Rolls Royce Moment* I want, but I need the detail from you."

### Verification

A good pitch from the skill should:
- Open with a hook that creates a curiosity gap, not a problem statement.
- Have a clear protagonist (usually the customer or the company, not the product).
- Resolve with a specific change, not a generic outcome.
- Be the length the user asked for, not 3x longer.

## How to outline a talk

Use when: you're giving a conference talk, an all-hands, a kickoff, or any time-bound spoken presentation.

### Steps

1. Open with the situation and the constraints:
   ```
   I'm giving a 30-minute conference talk on durable execution at a backend engineering conference.
   500 senior engineers in the room. Most have heard of the concept but haven't built one. Help me
   outline it.
   ```

2. The skill diagnoses: who the audience is, what they should believe afterward, what shape will hold a 30-minute talk.

3. The skill produces a scene list:
   - Opening hook (1-2 minutes)
   - 3-5 beats (the body), each with a tactic
   - Closing landing (1-2 minutes)
   - Time estimate per beat

4. For each beat, you get:
   - One line on what happens (concrete: "I show the diagram of a workflow that crashes mid-step")
   - One line on why it's there ("This is where I plant the *Secrets & Puzzles* hook for the next beat")

### Verification

A good outline should be implementable. Read it as if you were the speaker:
- Does each beat have a concrete prop, slide, or moment? Or is it abstract?
- Can you imagine saying the opening hook out loud? Or does it read as essay prose?
- Do the beats add up to the time budget?

If anything is too abstract, ask the skill to convert it to a *Movie Time* tactic ("turn this beat into a concrete scene the audience can play in their head").

## How to write a memo

Use when: you have news to share, a position to take, or a recommendation to land. Memos work for layoffs, policy changes, product pivots, post-mortems, founder updates.

### Steps

1. Tell the skill what's at stake:
   ```
   I have to write a memo to the team announcing we're shutting down our consumer product line and
   focusing on enterprise. Half the team built the consumer product. Help me.
   ```

2. The skill will diagnose: audience (the team), function (deliver hard news without losing trust), structure (likely *No Easy Way* or *Pride & Fall*, depending on whether the consumer product was a mistake or just a sequencing decision).

3. The skill produces a memo with this shape:
   - **Lead with the news in the first line.** No pre-amble.
   - Context (why this, why now).
   - The arc (how we got here, what we tried, what we learned).
   - The asks (what changes for whom, what stays the same).
   - The call to action (what the reader does next).

### Verification

The first sentence must be the news. If the skill produced "I want to share something difficult with you all today" as the first sentence, push back: "Replace the opening with the actual news. The first sentence should land the decision."

## How to write a launch announcement

Use when: you're shipping a feature, opening a product to GA, or announcing availability.

### Steps

1. Tell the skill what you're launching and to whom:
   ```
   I'm announcing the launch of our new SOC 2 compliance dashboard. Audience is existing customers
   plus the security-conscious prospect list. Help me write this.
   ```

2. The skill picks tactics for an announcement:
   - *Simple Sales Stories* if there's a named customer the dashboard helped.
   - *Rolls Royce Moment* for one vivid detail that makes the quality real (specific UI moment, specific metric).
   - *Three is the Magic Number* for the three things the dashboard now does.
   - *Story Hooks* for the opener.

3. The skill produces the announcement with the same shape as a memo: news first, story arc second, asks last.

### Verification

A launch announcement should NOT:
- Open with "We're excited to announce..."
- List features without context
- Use the word "transformative" (or any of the [writer plugin's banned vocabulary](../writer/reference.md#banned-vocabulary-tier-1))

It SHOULD:
- Open with a hook that creates curiosity
- Have a specific concrete moment (the *Rolls Royce Moment*)
- Resolve with what the reader does next (try it, schedule a demo, read the docs)

## How to get coaching instead of a draft

Use when: you want to *learn* to tell the story, not just receive one. Useful for high-stakes communications where the user needs to internalize the structure.

### Steps

1. Be explicit:
   ```
   Coach me through writing my own pitch instead of drafting it for me.
   ```

2. The skill switches to Mode B. It will:
   - Walk the diagnostic out loud, one question at a time
   - Pull 1-3 tactics that fit your situation
   - For each tactic, ask 3 Socratic questions you answer

3. You answer the questions. The skill collects your answers.

4. End with: "Tell me your answers and I'll help you draft." At that point you can either draft yourself with the structure clear, or switch to Mode A and have the skill produce the artifact.

### When NOT to use coaching mode

- You're under time pressure. Coaching is slower.
- You've already drafted something. Use "review this draft" instead.
- You don't know what you want to say yet. Coaching assumes the user has raw material; the skill helps shape it. If you have no raw material, start with Mode A and the skill will help you find it.

## How to get feedback on a draft you wrote

Use when: you've drafted something and want a tactic-aware review.

### Steps

1. Paste the draft with explicit instructions:
   ```
   Review this draft. I'm pitching a Series B to growth investors. 10 minutes. Tell me what tactics
   are working, what's missing, and what to cut.

   <your draft>
   ```

2. The skill will:
   - Identify the tactic stack you used (often implicitly)
   - Flag where the diagnostic answers seem unclear from the draft
   - Suggest 1-3 specific tactics that would tighten it
   - Be specific about which paragraph or sentence needs work

3. Push back when the skill is wrong. It's a deck, not an oracle.

### Verification

A useful review will:
- Name the tactics you used (so you can think with the same vocabulary on the next revision)
- Be specific about location ("the third paragraph is doing too much")
- Recommend cuts as often as additions

## How to switch the recommended arc

The skill picks an arc based on the diagnostic. Sometimes the pick is wrong for reasons the skill couldn't see.

### Common overrides

- **You picked *Rags to Riches*; I have a more skeptical audience than you think. Use *No Easy Way*.**
  - *Rags to Riches* sounds aspirational; *No Easy Way* sounds honest. Sophisticated audiences trust the second more.
- **You picked *Man in a Hole*; my audience is the ones who put me in the hole. Use *Voyage & Return*.**
  - When the audience caused the setback, "we fell and recovered" reads as accusatory. *Voyage & Return* frames the experience as a journey that taught us something.
- **You picked *Hero & Guide*; this is a founder origin story. The audience isn't the hero, I am.**
  - The default for external communication is to cast the audience as hero. Override only when the story is genuinely about the user.

The skill will reassemble with the new arc. State the override explicitly and the skill obeys.

## How to handle ethical limits

The skill declines to produce content for misleading or manipulative communication. Persuasion is fair game; deception is not.

Examples the skill will decline:

- Pitches that misrepresent traction, customer counts, or financials
- Memos that frame a decision in a way that hides material information from the team
- Launch announcements for features that don't exist yet, framed as if they ship today
- "Storytelling" used as cover for omitting the parts the audience needs to know

If you ask for one of these, the skill will say so politely and either:
- Offer to write the honest version
- Hand off if the request is structurally adversarial

## How to give the skill better input

The skill's output is bottlenecked by the input. Things that consistently improve drafts:

- **A specific audience.** "Skeptical engineers" beats "developers."
- **A specific desired action.** "I want them to schedule a follow-up call this week" beats "I want them interested."
- **A specific moment or detail.** The *Rolls Royce Moment* tactic needs a real sensory anchor; only you have those.
- **A constraint.** Length, register, format, what to avoid. "12 minutes, no slides, no jargon" produces better output than "tell me a story."

## Troubleshooting

### The output feels generic

The skill defaults to safe tactics (*Hero & Guide*, *Story Hooks*, *Three is the Magic Number*) when the diagnostic is under-answered. Push specificity into the input:

- Add the audience's prior beliefs.
- Add the moment that made this worth telling.
- Add a constraint (length, register, what's at stake).

### The skill stacks too many tactics

If the output names 6+ tactics, ask: "Cut to 3-4 tactics. Pick the most load-bearing ones." The SKILL.md heuristic is 3-5 tactics for a 15-minute talk; 6+ is hiding from the work of picking.

### The skill drafted when I wanted coaching

Be explicit: "I asked for coaching. Don't draft. Walk me through the diagnostic and pull 1-3 tactics with Socratic questions."

### The skill is asking too many diagnostic questions

If you have a tight timeline, say so: "Skip the diagnostic. Use *Hero & Guide* + *Man in a Hole* + *Story Hooks*. Draft directly."

## Related

- [Reference: complete card catalog and recipes](reference.md)
- [Explanation: how the diagnostic, modes, and card metaphor work together](explanation.md)
- [Plugin SKILL.md](../../plugins/storyteller-guidance/skills/storyteller-guidance/SKILL.md)
- [Card index](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/index.md)
- [Recipes](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/recipes.md)
