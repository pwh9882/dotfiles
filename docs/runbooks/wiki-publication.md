# Authored wiki publication

The live wiki is edited and propagated by LiveSync. A separate Git store records
authored changes and publishes them without requiring a clean live working tree.

## Setup

Install the repository's `bin/llm-wiki-*` wrappers and `lib/wiki_publish.py` together.
Verify machine identity with `llm-instance`, then select exactly one integration
machine as publisher. The existing wiki origin supplies transport and credentials.

```bash
llm-wiki-git setup --role source --install-service
# On the selected integration machine, use --role publisher instead.
```

Setup fetches main before enabling managed mode. Local configuration defaults to
`~/.config/llm-wiki/publish.json`; state defaults to
`~/.local/state/llm-wiki/`. `LLM_WIKI_PUBLISH_CONFIG` and `LLM_WIKI_STATE_DIR`
override these paths. Neither belongs inside the LiveSync vault. The OS job is
`io.llm-wiki.publish` on macOS or `llm-wiki-publish.timer` on Linux. It runs every
30 seconds in addition to the immediate background attempt after each edit.

## Edit and commit in one operation

Prepare a JSON array outside the vault, then submit it:

```json
[
  {"path":"projects/example/index.md", "old":"Status: pending", "new":"Status: verified"},
  {"path":"projects/example/result.md", "create":"# Result\n\nVerified outcome.\n"}
]
```

```bash
llm-wiki-commit "record example verification" --changes /tmp/wiki-edits.json --task example-verification
llm-wiki-status
```

`old` must match exactly once. Multiple replacements in one file run in array
order. For full-file replacement or deletion, use `before` and `after` with exact
contents; `after: null` deletes the file. New files use `create`. Paths must be
relative and cannot traverse symlinks or internal dot directories. UTF-8 and line
endings are preserved. Conflict markers are rejected.

The response gives the local source commit, submission ID, and current state.
The edit is immediately visible in the live wiki; GitHub confirmation is separate.
The source commit's private parent captures the affected files before this edit,
so already-received LiveSync changes are not reassigned to this author.

Instance identity always comes from `llm-instance`. The author uses the existing
Git identity. Commit trailers preserve `Wiki-Instance`, `Wiki-Agent`,
`Wiki-Session`, `Wiki-Task`, and `Wiki-Submission`. Set `LLM_WIKI_ACTOR` when the
harness does not expose its name. Session comes from `CODEX_THREAD_ID`,
`CLAUDE_SESSION_ID`, or `LLM_WIKI_SESSION`; otherwise a fresh submission ID is
used instead of guessing. `--task` groups checkpoints from one job. For a retry
after an uncertain command result, reuse `--id <32-hex-ID>` with the exact same
request; changed requests cannot reuse an ID.

Managed clients must use this edit boundary for attribution. Ordinary filesystem
edits or old `git add` flows cannot reliably identify the original writer after
concurrent changes have mixed. Do not add a pre-edit pull or stash step.

## Publication and diagnostics

```bash
llm-wiki-git publish       # attempt now; the OS timer also retries
llm-wiki-status            # local pending IDs/ages, blocked IDs on publisher
llm-wiki-git log -5        # confirmed main history cached from origin
llm-wiki-git diff          # live files versus cached published history
```

`live_files_differing_from_published_history` includes pending edits, received
LiveSync changes, and unrecorded direct edits; it is not a claim of authorship.
Review this list along with pending IDs. Old raw `git status` inside the vault
uses the deliberately preserved old `.git`; managed wrappers are authoritative
for publication status. `pull`/`push origin main` in managed mode attempt managed
publication and never rewrite live files. Direct shared-index `add` is refused.

Network failure retains local source commits and records a health error. Check
`publish.log` and `health.json` in the state directory. A `submitted` item is on
the remote submission branch, not necessarily in main. A `published` receipt
requires finding its ID in confirmed origin/main. Only the configured publisher
advances main. Submission branches are deleted with an expected-object lease
after confirmation; original local source refs remain recoverable.

Competing replacements remain on their submission branches and appear under
`blocked` on the publisher. Independent submissions continue. Resolve content
from the original source commit and current main in the isolated Git store;
never choose an entire side of the live vault or stash somebody else's work.
If a live edit is `needs-recovery`, its event JSON contains preimages/postimages
and its source ref preserves the original change. Compare the current files
before restoring or completing anything; automatic recovery only accepts exact
known versions. No background process silently overwrites a third version.

## Import existing uncommitted work

Existing single-parent local commits can be submitted with their original author,
author date, and message intact:

```bash
llm-wiki-git adopt <reviewed-unpublished-commit>
```

This does not modify live files or the old branch. Adoption is idempotent and
records the original hash. Submit a stack in its original order.

After inspecting ownership and content, an explicit import records complete
selected files relative to the published baseline:

```bash
llm-wiki-git capture --summary "import existing reviewed notes" projects/example/index.md
```

This is an import by the current instance (`Wiki-Capture: existing`), not evidence
that it authored all selected text. Keep existing writer names in the notes and
summary. It is for initial migration and deliberate imports, not routine edits.
Specify `--base <ref>` only when that is the verified baseline for those files.

## Recovery and rollback

Preserve the state directory, the live vault, and the old `.git` before rollback.
Stop/unload the OS retry job, then move the config file aside to return wrappers
to legacy mode. Pending submission branches and local `refs/wiki/local/*` remain
recoverable. Do not resume legacy multi-writer main pushes without reconciling
the histories and reviewing pending submissions. No automatic force push, stash,
reset, or live-vault rollback is provided.

For LiveSync CLI clients, exclude `**/.wiki-write-*` temporary files; GUI hidden
file sync remains disabled. Shared files continue to follow LiveSync's own
concurrency and connectivity behavior. Git publication does not resolve its
database revision conflicts or promise instantaneous remote visibility.
