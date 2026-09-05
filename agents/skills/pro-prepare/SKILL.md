---
name: pro-prepare
description: Prepare a review request for GPT-5.6 Pro. Creates a request document and packages a comprehensive (~100MB) archive for ChatGPT Web upload.
---

# GPT-5.6 Pro Review — Prepare

You are preparing a review request package for GPT-5.6 Pro, a large reasoning model accessible only through ChatGPT Web.

## Context Assessment — Ask vs Autonomous

**Before starting, assess how much context you already have from the current conversation.**

- **Autonomous mode** (sufficient context): If the conversation already established what to review, what questions to ask, and what files are relevant — proceed directly. Write the request document and package the archive without asking. You know the project, recent changes, and what needs Pro's input.
- **Ask mode** (insufficient context): If invoked cold (no prior conversation, or topic is ambiguous), use `AskUserQuestion` to gather what's needed.

**Rule of thumb**: If you can write the "Specific Questions" section of the request document right now from conversation context, go autonomous. If you'd be guessing, ask.

### What to ask (only when needed)
1. **Review topic/name** (use `$ARGUMENTS` if provided)
2. **Specific questions** — What should Pro focus on?
3. **Files to include** — Code, results, dashboards, docs
4. **Previous review lessons** — Any past Pro feedback that's relevant?

## Workflow

### Step 1: Write the Request Document

Create `docs/reviews/request/{topic}-review-request.md` with this structure:

```markdown
# Review Request: {Title}

## Context
[Project background — what it does, current state, key metrics]

## Specific Questions
[Numbered list of what Pro should focus on]

## Current State
[Relevant code structure, recent changes, experiment results]

## Previous Review Lessons (if any)
[What worked/didn't from past Pro feedback]

## Files in Archive
[List of included files with brief descriptions]
```

**Guidelines**:
- Include enough context for Pro to understand the project without prior knowledge
- Be specific about what you want reviewed — vague requests get vague answers
- Include relevant data/results, not just code
- Summarize large files in the request for orientation, while including the underlying raw evidence in the archive for independent inspection

### Step 2: Package tar.gz — COMPREHENSIVE (raw evidence included)

The archive must be **self-contained and research-grade**. This rule prevents a recurring failure: sending only agent-written summaries when Pro should inspect the actual raw data, code, and results. Do not replace those materials with a narrative digest. Pro should be able to understand and analyze the project from the archive alone, without needing any external context. Text data compresses extremely well, so err on the side of including more.

**What to always include:**

1. **Complete codebase** — all source code directories (not just "relevant" files)
2. **All results/logs** — eval results, predictions, scored outputs, log files
3. **All previous Pro reviews** — `docs/reviews/response/` and `docs/reviews/` verification reports
4. **Architecture docs** — `DESIGN.md`, `AGENTS.md`, `CLAUDE.md`, any README
5. **Raw data samples** — include actual data from the dataset so Pro can see what the tools process:
   - For each domain/split: 1-2 representative date directories with full telemetry
   - Ground truth / query files (all of them, they're small)
   - Generated prompts (the actual model inputs)
6. **Analysis docs** — anything in `docs/analysis/`, `docs/experiments/`
7. **The request document itself** — must be inside the archive AND standalone

**What to exclude:**
- `.git/`, `__pycache__/`, `.cache/`, `node_modules/`
- API keys, credentials, `.env` files
- Large binaries unrelated to the review; if a large binary is necessary evidence, include it or provide a clearly mapped companion archive
- Redundant copies of the same data

**Size as a coverage signal**: Research packages may reasonably reach 30-100MB compressed; do not cut relevant raw data just to make a small upload. If under 10MB, explicitly check for omitted input data, execution results, code, and reproduction information. A small source project can still be complete: judge the evidence, not a minimum byte count. Include a manifest mapping the review questions to the actual included files, with any material exclusions and their reasons.

```bash
tar -czf docs/reviews/request/{topic}-review.tar.gz \
  --exclude='.git' --exclude='__pycache__' --exclude='.cache' \
  --exclude='node_modules' --exclude='.env' \
  {comprehensive file list}
```

**After creating the archive, verify the size:**
```bash
ls -lh docs/reviews/request/{topic}-review.tar.gz
```

Inspect the archive listing as well as its size. Confirm that the request, code, raw samples, results, and reproduction information are actually inside. For large packages, remove redundant material or split into clearly mapped archives without silently dropping evidence needed for review.

### Step 3: Output Instructions

After packaging, print:

```
## Ready for Pro Review

Archive: docs/reviews/request/{topic}-review.tar.gz ({size}MB)
Request: docs/reviews/request/{topic}-review-request.md

### Upload Steps
1. Go to ChatGPT Web (chat.openai.com)
2. Select GPT-5.6 Pro model
3. Upload the tar.gz file
4. Copy-paste the request document content as your message
5. Wait for Pro's response (large reasoning — may take a few minutes)

### After Review
1. Save Pro's response to: docs/reviews/response/{suggested-filename}.md
2. Run: /pro-verify {suggested-filename}
```

## File Locations (Fixed Convention)

All projects use the same directory structure:
- **Request docs**: `docs/reviews/request/{topic}-review-request.md`
- **Archives**: `docs/reviews/request/{topic}-review.tar.gz`
- **Pro responses**: `docs/reviews/response/{name}.md`
- **Review digests**: `docs/reviews/{name}-{seq}.md`

Create `docs/reviews/request/` and `docs/reviews/response/` if they don't exist.

**IMPORTANT**: The request document must exist BOTH as a standalone `.md` file AND inside the tar.gz archive. Never put it only in the tar — standalone files are needed for git history and quick reference.

## Important Notes
- Never include API keys, credentials, or `.env` files in the archive.
- If the project has a `DESIGN.md` or equivalent architecture doc, always include it.
- If there are previous Pro review response files, always include all of them for continuity.
- When in doubt about whether to include something, include it. Disk space is cheap; missing context is expensive.
