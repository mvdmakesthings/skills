Good brief — and the constraint you've named ("don't be another lazy contrarian") is the real shape of the talk. Let me work through what I'm hearing before I draft.

## What I'm picking and why

Your audience is mid-senior engineers who have already heard the "microservices are bad" sermon and have antibodies to it. A straight-line "we did the smart thing, you should too" arc will get you dismissed in the first 60 seconds. So the structural choice isn't a clean recovery story — it has to be a story where you're partly the antagonist.

Here's the tactic stack I want to use:

- **Three Great Conflicts → internal struggle.** The fight at the center of the talk isn't monolith vs. microservices. It's *engineers who chose microservices for the wrong reasons* — including you — vs. the version of themselves that should have known better. This is the only framing that earns you the right to talk about ripping them out without sounding like a contrarian.
- **No Easy Way arc.** Not Man-in-a-Hole (too clean), not Rags-to-Riches (too triumphant). *No Easy Way* is the up-and-down arc with real setbacks, including post-monolith setbacks. Your audience trusts a story with scars. A smooth recovery story sounds like marketing.
- **Secrets & Puzzles hook.** Open with a puzzle the audience already half-feels but hasn't admitted out loud. Something like a specific contradiction in their own org. This is the antidote to "another lazy contrarian take" — you're not telling them what to think, you're naming something they already suspect.
- **Hero & Guide, inverted carefully.** Normally the audience is the hero. Here you need to be the *witness*, not the guide — someone reporting back from the other side rather than prescribing. Guides who haven't earned it sound preachy. Witnesses get listened to.

If that framing feels wrong — for example, if your team's microservices were genuinely the right call for the time and the rip-out was about a real change in circumstances rather than a re-examination — tell me and I'll re-shape. The rest of this assumes "we were doing it for the wrong reasons" is at least partly true.

## The 15-minute outline

Five beats. Times are rough; trim wherever your specifics are thinnest.

### Beat 1 — The puzzle (90 seconds)

Open on a concrete moment from your team's microservices era that, in retrospect, doesn't add up. Not a horror story. A *quiet* contradiction — the kind of thing that gets normalized.

Examples of the shape (yours will be better and specific): the four-engineer team with seventeen services. The on-call rotation that spent more time finding the right repo than fixing the bug. The architecture diagram nobody updated because nobody could.

End the beat with one line that names what you didn't realize at the time. Something like: "We thought we had a microservices problem. We had a *we picked microservices* problem."

*Why this beat is here:* Secrets & Puzzles. You're surfacing a contradiction the audience has seen in their own org. They lean in because they want to know if you're going to name it honestly.

### Beat 2 — Why we actually picked them (3 minutes)

This is the move that separates you from the lazy contrarians. Don't say "we picked microservices because they were trendy." Be specific about the actual decision and the actual incentives, including the embarrassing ones.

Some candidate honest reasons (use whichever were really yours):

- We were a small team trying to feel like a big-team engineering org.
- A senior person had been burned by a monolith at their last company and the trauma was running the architecture review.
- Our hiring pipeline assumed "microservices experience" was a signal of seniority, so we built an org that needed them.
- We confused Conway's Law with strategy — we let the org chart we *wanted* drive the system design.
- We mistook "decoupled deploys" for "decoupled teams."

Pick the one or two that were actually true for you. Name them out loud. This is your credibility move — you can't critique an architecture choice you won't admit you made for non-architectural reasons.

*Why this beat is here:* Three Great Conflicts, internal. The fight is between the engineers you were and the engineers you should have been. Naming the bad reason is what makes the audience believe you'll be honest about everything else.

### Beat 3 — The rip-out, including what we got wrong about it (4 minutes)

Here's where most contrarian talks cheat. They skip from "microservices bad" to "monolith good" and the middle is hand-waved.

Don't do that. Take the audience through the actual rip-out, including:

- One thing that was genuinely harder in the monolith than you'd expected. (A scaling bottleneck? A team-boundary problem you'd accidentally been solving with service boundaries? Deploy coupling that bit you?)
- One thing that broke in a way you didn't predict. A near-disaster moment. The point in the migration where someone in the room said "did we just make this worse?"
- The cost of the migration itself — engineer-months, the features you didn't ship while you were doing it, the morale dip.

This is the "let it get genuinely bad" beat of the No Easy Way arc. If this beat is missing or sanitized, the talk reverts to lazy contrarianism. The dark middle is what earns the recovery.

*Why this beat is here:* No Easy Way structure. Audience credibility comes from showing the scars, not just the trophy.

### Beat 4 — What actually got better, and why it wasn't the monolith (4 minutes)

The twist your audience needs: the win wasn't the monolith. The win was the *decision process that produced the monolith*.

Stories that walk away from microservices and toward a monolith are still bad stories if the lesson is "monoliths are better." The real lesson, if you're honest about Beat 2, is something like:

- We picked the architecture that fit the team we actually had, not the team we wanted to look like.
- We made the call based on the workload we actually run, not the workload someone might run at our scale plus 100x.
- We accepted that the next architectural shift will probably mean undoing this decision too, and that's fine.

Make it concrete. The team metrics that actually moved (deploy frequency? incident MTTR? feature lead time? developer satisfaction?). The one number you'd hand to a skeptic in the room.

*Why this beat is here:* Three Great Conflicts again, resolved. The internal fight ends not with "we beat the bad architecture" but with "we beat the bad decision-making."

### Beat 5 — The handle for them (2.5 minutes)

This is the beat that makes the audience rethink their own architecture instead of just nodding along.

Don't tell them what to do. Tell them what to *ask*. Three questions they should walk out and run on their own org — drawn directly from the bad reasons in Beat 2.

Candidate shape, again you'll make it specific:

- *Why is your architecture the shape it is? Write down the actual reason, not the architectural justification.*
- *Which of your service boundaries are solving an engineering problem, and which are solving an org-chart problem?*
- *If you had to defend this architecture to someone who'd never heard of microservices, what would the case sound like?*

Close on a line that names the real lesson without preaching it. Something like: "We didn't escape microservices. We escaped the version of ourselves that picked them for the wrong reasons. Whatever you're running right now — make sure you didn't pick it for the same reasons we did."

*Why this beat is here:* This is the closing transformation. The audience doesn't leave with a new architecture; they leave with a new question. That's the actual rethink you said you wanted to produce.

## A few delivery notes

- **Resist a "lessons learned" slide.** It will undo Beat 4. Lessons-learned slides are how lazy contrarian talks signal humility while staying preachy. Let Beat 5's questions do that work instead.
- **Tell on yourself early and often.** The line between "thoughtful re-examination" and "smug contrarian" is whether you implicate yourself in Beat 2. If you're tempted to make the bad reasons sound noble, you've drifted toward the lazy version.
- **One story-shaped data point beats five bullet points.** When you reach for metrics in Beat 4, pick one and tell its little arc — what it was, what it is now, what changed in between. Don't dashboard the audience.
- **Have a "cut to the chase" version of every beat.** If a beat is running long or the room glazes, you should be able to land that beat in one sentence and keep moving. Especially Beat 3 — engineers will want to dwell there and you cannot let them.

## What I need from you to tighten this

Three things only you can supply, and they're what will make the talk yours instead of mine:

1. **The puzzle in Beat 1.** What's the specific moment from your team's microservices era that you'd put on stage? Not the worst moment — the *quietest* one that, looking back, you can't believe was normalized.
2. **The honest reason in Beat 2.** Which of the embarrassing decision-drivers I listed was actually yours? Or is there a worse, truer one I missed?
3. **The "did we just make this worse" moment in Beat 3.** What was the lowest point of the migration? The one where you weren't sure you'd done the right thing?

Give me those three, and I'll write the actual scripted version of each beat — opening line, transition, landing — with your specifics in place of my placeholders.

---

*Tactics used: Three Great Conflicts (internal fight), No Easy Way arc, Secrets & Puzzles opener, Hero & Guide inverted to witness role. Recipe-adjacent to Stories that Motivate, but tuned for a skeptical-insider audience rather than a change-resistant one.*
