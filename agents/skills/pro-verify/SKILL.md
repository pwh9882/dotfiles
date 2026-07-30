---
name: pro-verify
description: Digest and analyze a GPT-5.6 Pro review response. Understand what Pro analyzed, what directions it proposed, verify key facts, and produce an actionable strategy digest.
---

# GPT-5.6 Pro Review — Digest & Verify

You are analyzing a GPT-5.6 Pro review response. The goal is to **understand what Pro said, evaluate the direction it proposed, and produce an actionable strategy digest**.

## What This Skill Is Really For

The purpose of consulting Pro is to get **expert analysis, problem diagnosis, and strategic direction** from a powerful reasoning model. When we receive Pro's response, we need to:

1. **Understand the analysis** — What did Pro find? What patterns did it identify? What problems did it diagnose?
2. **Evaluate the direction** — Are the proposed directions sound? Do they align with our architecture? Are there risks?
3. **Verify key facts** — Spot-check important factual claims that underpin the analysis (but this is supporting work, not the main output)
4. **Produce actionable next steps** — What should we actually do based on this review?

**Common mistake to avoid**: Don't turn this into a fact-checking scorecard where the output is "X/Y claims CORRECT." That misses the point entirely. A review where Pro says 24 true things but gives bad direction is worse than one where Pro gets 2 facts wrong but provides brilliant strategic insight.

## Context Assessment — Ask vs Autonomous

- **Autonomous mode**: If you know the project, the review topic, and where the response file is — proceed directly.
- **Ask mode**: If the response file location is unclear or you lack project context, ask only what's missing.

## Workflow

### Step 1: Locate the Response

- If `$ARGUMENTS` is a file path, read that file directly.
- If `$ARGUMENTS` is a name/keyword, search `docs/reviews/response/` for matching files.
- If no arguments, find the most recently modified `.md` file in `docs/reviews/response/`.

### Step 2: Read and Understand the Full Response

Read the entire Pro response carefully. Identify:

1. **What questions were asked** (from the request document)
2. **What analysis Pro performed** — data exploration, pattern identification, root cause diagnosis
3. **Key findings** — the non-obvious insights that change how we think about the problem
4. **Strategic directions** — what Pro recommends and why
5. **Specific suggestions** — concrete implementation proposals

### Step 3: Fact-Check Key Claims (Supporting Work)

Verify the **important factual claims that Pro's analysis depends on**. Focus on:

- Claims that would change the direction if wrong (e.g., "metric_app.csv exists but is skipped" — if it doesn't exist, the suggestion to load it is moot)
- Quantitative claims used to prioritize (e.g., "27 cases have only datetime wrong" — if it's actually 5, the priority changes)
- Code/architecture claims that affect feasibility (e.g., "max_dur_ts is already computed" — if not, the effort estimate changes)

Don't exhaustively verify every statement. Focus on claims that **matter for decisions**.

### Step 4: Evaluate Directions Against Project Context

For each direction Pro proposes, assess:

1. **Alignment with architecture** — Does it fit our V7 principle (feature extraction OK, label emission forbidden)? Does it respect "overview는 건드리지 마라"?
2. **Past experience** — Have we tried something similar? What happened? (Check `docs/reviews/`, `docs/experiments/`, memory)
3. **Model-divergence risk** — Is this a prompt-level change? (Same prompt change = opposite effects across models, confirmed 5 times)
4. **Generality** — Would this work on an unseen domain, or is it benchmark-specific?
5. **Risk/reward** — What's the downside if it doesn't work? Can it make things worse?

### Step 5: Write the Review Digest

Create `docs/reviews/{topic}-{sequence_number}.md`:

```markdown
# GPT-5.6 Pro Review #{sequence}: {Title}

Date: {today}
Input: {archive or source description}

## What Pro Analyzed

[Summary of the analysis Pro performed — what data it looked at, what patterns it found, what questions it answered]

## Key Findings

[The most important non-obvious insights from Pro's analysis. These are the things that change how we think about the problem.]

### Finding 1: {title}
[What Pro found, why it matters, and whether our fact-check confirms it]

### Finding 2: {title}
...

## Strategic Direction

[What overall direction Pro recommends and our assessment of it]

### Direction 1: {title}
**Pro's reasoning**: [why Pro suggests this]
**Our assessment**: [agree/disagree/modify, with reasons]
**Risk**: [what could go wrong]

### Direction 2: {title}
...

## Fact-Check (Key Claims)

[Only claims that matter for decisions. Brief table format.]

| Claim | Verified? | Impact on Direction |
|-------|-----------|-------------------|
| {important claim} | Yes/No/Partial | {how it affects our plans} |
| ... | ... | ... |

## Action Plan

[Concrete prioritized list of what to do next, synthesizing Pro's input with our own judgment]

| Priority | Task | Rationale | Effort | Risk |
|----------|------|-----------|--------|------|
| 1 | ... | ... | ... | ... |
| 2 | ... | ... | ... | ... |

## Open Questions

[Things Pro raised that we need to think about more, or things Pro didn't address that we still need to figure out]
```

### Step 6: Present to User

After writing the report, present a **concise analytical summary** to the user:

- What were Pro's key insights? (top 2-3)
- What direction does Pro recommend and do we agree?
- What should we do first?
- What are we skeptical about and why?

**Tone**: Analytical and opinionated. Don't just relay what Pro said — add your own assessment. The user wants a thought partner, not a stenographer.

## Important Notes

- **File locations (fixed convention)**:
  - Pro responses: `docs/reviews/response/`
  - Review digests: `docs/reviews/{topic}-{seq}.md`
  - Request docs & archives: `docs/reviews/request/`
- **Sequence numbering**: Check existing files in `docs/reviews/` to determine the next sequence number.
- **Past lessons matter**: If a suggestion resembles something tried before, flag it with what happened.
- **Model-divergence warning**: If a suggestion involves prompt-level changes, warn about cross-model instability.
- **Be honest**: If you think Pro's direction is wrong, say so and explain why. "Accept unless baseless" means accept valid analysis, not blindly follow every suggestion.
- **Never skip fact-checking on decision-critical claims**: Even if a claim sounds right, verify it if the whole direction depends on it.
