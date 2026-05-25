# `storyteller-guidance` reference

Complete reference for the `storyteller-guidance` plugin: the skill, the diagnostic, the two operating modes, the 54-card catalog, and the seven recipes.

## Skill

The plugin ships a single skill, `storyteller-guidance`, with no slash command. The skill auto-triggers when the user is preparing communication that needs an audience to feel or do something. There are no flags or arguments; the skill diagnoses the situation, picks tactics, and produces an artifact or coaches the user through writing one.

### Skill triggers

Phrases the skill auto-fires on:

- Pitching: "pitch this," "fundraising pitch," "sales pitch"
- Presenting: "talk," "keynote," "demo," "all-hands"
- Announcing: "launch announcement," "kickoff," "town hall"
- Memos: "write a memo," "post-mortem," "founder update"
- Layoff or hard news communication
- Any "tell a story" or "frame this" request

The skill explicitly does NOT trigger for:

- Raw technical writing (API docs, architecture RFCs, code comments)
- Routine transactional messages ("are we still on for 2pm?")

When the audience-feeling component is absent, the skill hands off to plain writing.

## The two operating modes

The skill operates in exactly one of two modes per session. The choice is based on what the user asked for.

### Mode A: Draft from scratch

The user wants a produced artifact (deck outline, pitch script, memo, talk). They have described an upcoming moment.

| Step | What happens |
|---|---|
| 1. Diagnose | Run the seven-question diagnostic |
| 2. Pick a recipe or assemble custom tactics | Match the user's goal to one of the seven recipes, or stack tactics from across categories |
| 3. Confirm the shape | State the tactic stack in one or two sentences before generating; allow the user to redirect |
| 4. Draft the artifact | Produce the requested format (see [Output formats](#output-formats)) |
| 5. Leave a revision handle | End with one or two specific questions only the user can answer |

### Mode B: Interactive coaching

The user is the writer; the skill is the deck on their desk. They have a situation but haven't asked for a draft, or they've drafted something and want feedback.

| Step | What happens |
|---|---|
| 1. Diagnose together | Walk the diagnostic out loud, one question at a time |
| 2. Pull 1-3 cards | Three tactics maximum per conversation; explain why each fits |
| 3. Ask Socratic questions | Convert each tactic's framework steps into questions the user answers |
| 4. Do NOT draft | Coaching builds the user's muscle. If they want a draft, they switch to Mode A |

If the user's intent is unclear, the skill asks: "Want me to draft a first cut, or coach you through writing it yourself?"

## The diagnostic

Before picking any tactic, the skill walks (or infers) these seven questions in order. The first one the user cannot answer tells the skill which category to work in.

| # | Question | Gap → Category |
|---|---|---|
| 1 | Why does this need to be a story at all? | If unclear → **Concept** |
| 2 | Where does the raw material come from? | If no real moments → **Explore** |
| 3 | Who are you in this story? | If unclear (hero / guide / witness / expert / foil) → **Character** |
| 4 | What does this story have to make happen? | If unclear → **Function** (and check recipes) |
| 5 | What shape does the story take? | If unclear → **Structure** |
| 6 | How will it be delivered? | If medium isn't dictating choices → **Style** |
| 7 | How does it get to the audience and survive after? | If multi-audience or multi-telling → **Organise** |

The skill does not have to surface every question. Often four or five are inferable from context; only ask about the gaps.

## The 54 cards

The deck is organized into seven tactic categories plus seven recipes plus one system card. Reference files live under `plugins/storyteller-guidance/skills/storyteller-guidance/references/`. The skill loads only the files it needs.

### Concept (10 tactics)

Why a story is needed and what idea sits at its core. Reference: [`concept.md`](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/concept.md).

| Tactic | One-line essence |
|---|---|
| Circle of Life | Tell your story through universal life-stage archetypes (child, adult, parent) |
| Curious Tales | Surface the small things that genuinely fascinate someone to reveal what really drives them |
| Good & Evil | Anchor your story to a moral conflict (right vs. wrong, or competing rights) |
| Order & Chaos | Show your work either tames chaos or shakes loose rigidity |
| Rules, Cheats & Rebels | Name a rule, then show someone breaking it |
| Secrets & Puzzles | Open with a hidden thing the audience wants revealed |
| Shock of the Old | Mine objects and practices that have survived generations for the insights they encode |
| The Dragon & the City | Recast your project as a city threatened by a dragon |
| Three Great Conflicts | Pick the right fight: hero against nature, other people, or themselves |
| Universal Stories | Build on the human traits everyone shares across cultures |

### Explore (7 tactics)

How to find raw story material in your work, research, customers. Reference: [`explore.md`](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/explore.md).

| Tactic | One-line essence |
|---|---|
| Abstractions | Watch what people actually do rather than what they say they do |
| Data Detectives | Wrap your data in story so people actually remember it |
| Emotional Dashboard | Track strong emotions as the surest signal of where a real story is waiting |
| Social Proof | Borrow trust by showing credible others moving in your direction |
| Story Listening | Treat listening to other people's stories as a discipline in its own right |
| That's Funny | Hunt for small moments that made you laugh or do a double-take |
| Thoughtful Failures | Treat your considered failures as material worth talking about openly |

### Character (6 tactics)

Who is in the story (including the storyteller) and how to position each role. Reference: [`character.md`](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/character.md).

| Tactic | One-line essence |
|---|---|
| Cut to the Chase | When your audience is drifting, jump straight to the moment that matters most |
| Drive Stories | Build motivating culture by collecting real autonomy / mastery / purpose stories |
| Hero & Guide | Cast the audience as the hero; you are the experienced guide |
| Trust Me, I'm an Expert | Earn trust by telling a story in which your values showed up in action |
| What's My Motivation? | Step into the inner life of every key person in your story |
| What's it About? | Force yourself to answer what your work is really about |

### Function (4 tactics)

What job the story has to do. Reference: [`function.md`](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/function.md).

| Tactic | One-line essence |
|---|---|
| Icebreaker Stories | Build a team's storytelling muscle through low-stakes invented exercises |
| Pitch Perfect | Boil your idea down to a tightly shaped verbal pitch with an emotional arc |
| Simple Sales Stories | Convince new buyers by telling short, relatable stories about existing customers |
| Story-ish Conversations | Pull narrative elements out of everyday meetings and chats |

### Structure (10 tactics)

The arc the story follows. Reference: [`structure.md`](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/structure.md).

| Tactic | One-line essence |
|---|---|
| Downfall | Tell the story of a once-mighty figure brought down by a hidden internal flaw |
| Epic Fail | Choose deliberately which type of failure story you tell |
| Five Ts | Keep a checklist of story ingredients to assemble one on the spot |
| Happy Ever Afters | Give your story a satisfying resolution that shows meaningful change |
| Innovation Curve | Calibrate the story to where each listener sits on the adoption curve |
| Man in a Hole | The classic fall-and-recover arc |
| No Easy Way | Extended up-and-down arc with early wins, setbacks, and hard-won recoveries |
| Pride & Fall | Cautionary descent arc (confident rise, ignored warnings, ends worse than it began) |
| Rags to Riches | Optimistic ascent arc where a hero with hidden value rises from a bad situation |
| Voyage & Return | Round trip into an unfamiliar world; the traveller is changed |

### Style (6 tactics)

How to deliver the story. Reference: [`style.md`](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/style.md).

| Tactic | One-line essence |
|---|---|
| Leave it Out! | Trust the audience to fill in the gaps; the withheld part is often more powerful |
| Movie Time | For every abstract idea, give the audience a concrete scene to play in their head |
| Rolls Royce Moment | One tiny vivid sensory detail that stands in for everything you want believed |
| Show & Tell | Make slides and words pull in different but complementary directions |
| Story Hooks | Open with a sharp, curiosity-baiting hook |
| Three is the Magic Number | Group the most important parts into threes |

### Organise (3 tactics)

How to manage stories across audiences and over time. Reference: [`organise.md`](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/organise.md).

| Tactic | One-line essence |
|---|---|
| Audience Profile | Invest real time understanding who your audience is before deciding the story |
| Big, Small, Inside, Outside | Sort stories along two axes: how rehearsed, and who they are for |
| Story Bank | Keep a living collection of your best stories with the context that protects against misuse |

### System (1 card)

| Tactic | One-line essence |
|---|---|
| Story Building System | A diagnostic table of contents that routes you to the right category by asking yes/no questions |

## The seven recipes

Recipes pre-combine tactics for common goals. They save deliberation and rarely go wrong. Reference: [`recipes.md`](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/recipes.md).

| Recipe | Use when | Tactics it stacks |
|---|---|---|
| Stories that Connect | You suspect you don't understand the other side's experience | Story Listening, Abstractions, Universal Stories, Story-ish Conversations, Circle of Life |
| Stories that Convince | You have deep knowledge that a less-informed audience needs to accept | (load `recipes.md` for full stack) |
| Stories that Explain | A strategy document is a story trying to escape | (load `recipes.md` for full stack) |
| Stories that Impress | Presentations defaulting to corporate-deck conventions | (load `recipes.md` for full stack) |
| Stories that Lead | A team's culture is the sum of the stories it tells itself | (load `recipes.md` for full stack) |
| Stories that Motivate | To get people to follow you somewhere new | (load `recipes.md` for full stack) |
| Stories that Sell | Selling is a trust transaction, not a feature list | (load `recipes.md` for full stack) |

When a recipe matches the user's goal, the skill loads `recipes.md`, picks the matching recipe, and loads the constituent tactics' frameworks from their category file.

## Output formats

The skill picks the format from the user's situation. If it isn't obvious, the skill asks once.

| Format | Shape |
|---|---|
| Pitch (verbal or written) | A short version (1-3 sentences) plus a longer version with problem-promise-path-payoff. Tactic stack named at the end. |
| Talk outline | A scene list: opening hook, 3-5 beats, closing landing. Each beat: one line on what happens, one line on why. Time estimates if duration is given. |
| Slide outline | Slide-by-slide: title, one-line message, visual idea. Slide text and spoken text do not duplicate (per *Show & Tell*). |
| Memo | Lead with the news in the first line. Then context, narrative arc, asks. End with the call to action. |
| Story arc | A 5-7 bullet sequence: opening state → trigger → struggle → turning point → resolution. Used as scaffolding the user fills in. |
| Coaching plan (Mode B) | 2-3 tactics, each with a one-paragraph "why" and 3 Socratic questions. Ends with "tell me your answers and I'll help you draft." |

Default formatting: plain markdown with light headings. The skill resists over-formatting; long stories live in prose, not bullets.

## Picking-tactic heuristics

When no recipe matches cleanly, the skill assembles. The SKILL.md spells out the heuristics it uses:

- **For Structure, pick one arc and commit.** Audiences can't follow two arcs in a 10-minute talk.
  - *Man in a Hole* for resilience and recovery
  - *Rags to Riches* for aspirational ascent
  - *No Easy Way* when the audience is sophisticated and a simple optimistic story would seem fake
  - *Pride & Fall* or *Downfall* when you need to acknowledge risk or critique a competitor
  - *Voyage & Return* when you want the audience to feel the journey
  - *Happy Ever Afters* when the closing transformation matters more than the body
- **Style tactics stack on Structure**, not the other way around. Once you have an arc, layer *Story Hooks* for the opener, *Three is the Magic Number* for memorable groupings, *Movie Time* and *Rolls Royce Moment* for concreteness, *Leave it Out!* to reduce, *Show & Tell* if there are slides, *Cut to the Chase* as a contingency for when the room loses interest.
- **Character work is usually a single decision.** *Hero & Guide* is the right start for almost every external pitch. Override only when the story is genuinely about the user (founder origin, personal essay, apology).
- **Concept tactics shape the core idea.** *Order & Chaos*, *Three Great Conflicts*, *The Dragon & the City*, *Good & Evil* find the real fight at the center. *Secrets & Puzzles* and *Rules, Cheats & Rebels* are powerful openers when attention is scarce.
- **Don't over-tactic.** A 15-minute talk needs 3-5 tactics, not 12. Stacking more tactics is hiding from the work of picking one good arc.

## File layout

```
plugins/storyteller-guidance/
├── .claude-plugin/plugin.json
├── _source/                                  # source data for regenerating references
│   ├── cards.json
│   ├── generate_references.py
│   └── merge_cards.py
├── evals/evals.json
└── skills/storyteller-guidance/
    ├── SKILL.md
    └── references/
        ├── character.md
        ├── concept.md
        ├── explore.md
        ├── function.md
        ├── index.md              # alphabetical + by-category card index
        ├── organise.md
        ├── recipes.md
        ├── structure.md
        └── style.md
```

Each `references/<category>.md` file follows the same per-tactic template: **Essence**, **When to reach for it**, **Why it works**, **How to apply**.

## What the skill does not do

- It does not pretend the user's audience cares about what the user finds interesting. The first move is always to invert the perspective.
- It does not produce content for misleading or manipulative communication. Persuasion is fair game; deception is not.
- It does not assume the user wants a single-shot answer. It always leaves a revision handle.

## Credits

Tactics, categories, recipes, and the diagnostic flow are inspired by Pip Decks' *Storyteller Tactics* card deck. The skill paraphrases the deck's principles in original language and adds its own examples; it is not a reproduction. Full deck: pipdecks.com.

## Related

- [How-to: common tasks](how-to.md)
- [Explanation: the diagnostic, the two modes, the card-deck heuristic](explanation.md)
- [Plugin SKILL.md](../../plugins/storyteller-guidance/skills/storyteller-guidance/SKILL.md)
- [Card index](../../plugins/storyteller-guidance/skills/storyteller-guidance/references/index.md)
