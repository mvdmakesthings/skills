# Shaping Your "Back to the Monolith" Talk

Great instinct to resist the lazy-contrarian trap. The room you're walking into has heard "microservices are overrated" since at least 2018. If you just stack up the usual receipts (Istio is a nightmare, distributed transactions are hard, your startup isn't Netflix), you'll get nods and zero behavior change. Mid-senior engineers don't need more validation — they need a sharper lens.

Here's how I'd shape it.

## The core problem with most "we went back to the monolith" talks

They frame it as a verdict: monoliths win, microservices lose. That's the wrong unit of analysis, and your audience knows it. The interesting question isn't "which architecture is better" — it's **"what did we learn about how we make architecture decisions?"**

That reframe is your wedge. It turns the talk from a war story into a mirror.

## A thesis that earns the room's attention

Try something like:

> "We didn't migrate to microservices because they were the right architecture. We migrated because the decision felt unfalsifiable at the time. Going back to a monolith wasn't the lesson — figuring out *why we couldn't have known we were wrong* was the lesson."

Or sharper:

> "Our microservices weren't a technical mistake. They were an epistemic one. And most of yours probably are too."

That's a claim that makes engineers lean forward, because it implicates *how they think*, not just *what they built*.

## The structure I'd use (15 minutes is tight — be ruthless)

**Minutes 0–2: Open with a concrete, specific failure.**
Not "we had complexity." A real moment. "It was 2:14 AM. Our checkout flow was down. Seven engineers were in a Zoom. The bug was in the way Service A retried a call to Service B during a Kafka rebalance. We had built this system. None of us could explain it." Make them feel the scene. No abstractions yet.

**Minutes 2–5: The conventional story (and why it's incomplete).**
Acknowledge the take they've already heard: "You're expecting me to say microservices were overkill for our scale. That's true. It's also boring. Here's what's more interesting." This is where you earn the right to keep talking. You name the cliché, agree with the surface of it, then say *but that's not the actual lesson*.

**Minutes 5–10: The real lesson — the decision-making pathology.**
This is the meat. You're not selling monoliths. You're exposing the *failure mode of architecture decisions in ambitious teams*. Some angles you could mine:

- **The unfalsifiable bet.** Microservices promise benefits that only materialize in some imagined future state (scale, team autonomy, polyglot freedom). You can't disprove them in year one, so you can't course-correct. What does it look like to design architecture decisions that can be *falsified within a quarter*?
- **Conway's Law as a forcing function, not a side effect.** Your service boundaries weren't drawn around domain seams — they were drawn around the org chart you had on the day you whiteboarded it. The architecture froze a transient organizational state.
- **Status as a hidden input.** Be honest if it's true: microservices were partly a recruiting story, a resume story, a "we're a real engineering org now" story. Engineers love when speakers admit this because everyone has lived it and nobody talks about it.
- **The reversibility test.** Jeff Bezos's one-way vs. two-way doors. Microservices were sold as flexible, but the migration itself was a one-way door. Why didn't anyone treat it that way?

Pick two of these, not all four. Depth beats breadth.

**Minutes 10–13: What you do differently now.**
This is where you stop being contrarian and start being useful. Don't say "use a monolith." Say: "Here are the three questions we now ask before any architecture decision, and here's what would have happened if we'd asked them in 2021." Make it portable. Make it tools they can use Monday morning, regardless of whether they're on a monolith or a mesh of forty services.

**Minutes 13–15: The uncomfortable close.**
Don't end with a bow. End with a question that haunts them on the train home. Something like: "The architecture decision you're most confident about right now — what evidence would change your mind, and when will you have it? If you can't answer that, you haven't made a decision. You've made a bet you can't lose, which means you've made a bet you can't learn from."

## Specific moves that will make this talk land

1. **Name the audience's defense before they raise it.** "I know what you're thinking — 'we're different, we actually do need this.' Maybe. Here's the test." Pre-empting the objection signals you've actually thought about them.

2. **Use one extended case, not five vignettes.** Mid-senior engineers tune out at the third "and another time…" Pick the single most damning, specific incident and let it carry the talk. Specificity is credibility.

3. **Quantify something nobody quantifies.** Not p99 latency. Something like: "We spent 31% of senior engineering time in 2022 on cross-service coordination work that wouldn't have existed in a monolith. Here's how we measured it." Numbers on the *hidden costs* are more persuasive than numbers on the obvious ones.

4. **Steelman the other side late in the talk.** Around minute 11, briefly: "Here's when I think we'd make the same choice again." This is the move that separates you from the lazy contrarians. It signals you have a real model, not a grievance.

5. **Avoid the phrases that mark this genre.** "Distributed monolith," "you're not Google," "premature optimization," "boring technology." Your audience has heard all of these. If you must invoke them, do it with a twist that shows you know they're clichés.

6. **Give them one transferable artifact.** A checklist, a decision framework, a single diagram. Something they can screenshot. Talks without an artifact evaporate by Friday.

## A gut-check question for your draft

After you write it, ask: **"Could I give this exact talk if we'd stayed on microservices and they'd worked out?"** If the lessons only make sense because the migration failed, you've written a war story. If the lessons hold regardless of outcome, you've written something that will change how people think.

That's the bar. Aim for the second one.

## One last thing

The best version of this talk probably isn't titled "Why We Went Back to the Monolith." It's titled something like "The Architecture Decision We Couldn't Unmake" or "What Our Microservices Migration Taught Us About How We Decide." The title sets the frame. If the title sounds like a 2019 blog post, the talk will feel like one no matter how good it is.

Want me to drill into any of these — sharpening the thesis, building out the case study scaffold, or pressure-testing the closing question?
