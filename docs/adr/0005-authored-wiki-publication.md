# ADR-0005: Authored live wiki edits and isolated publication

Accepted, 2026-09-20.

LiveSync transfers wiki file contents without Git metadata. Independent main
commits then duplicate changes; requiring a clean pull before every commit also
blocks unrelated work. The operator requires near-real-time information sharing,
attribution to the actual working instance/session, and immediate commits.

Managed clients use `llm-wiki-commit --changes` to validate exact replacements,
create a durable source commit, and apply the edit to the existing live wiki.
The source commit has a private preimage parent: its diff contains just the
requested edit even when the file already includes somebody else's uncommitted
LiveSync changes. Preimages and source commits live outside the vault.

Each client submits immutable `wiki-submit/<id>` branches to the existing wiki
remote. One configured publisher cherry-picks the source commits onto current
main in a disposable worktree, preserves author/message/trailers, and removes
submission branches only after main contains the submission ID. A rejected push
refetches and retries. Published IDs prevent duplicate commits after interruption.
Conflicts retain the original source commit and do not block independent work.
Pure insertions at the same location can be combined; competing replacements
are never resolved by choosing the latest timestamp.

The live wiki remains exclusively materialised by edits and LiveSync. Publication
never stashes, checks out, resets, or rebases that directory. Its old `.git` is
retained for recovery; managed wrappers read the separate history cache.

Immediate background attempts and a 30-second OS timer provide retries. Commit
creation does not need the network or the publisher lock. Publication delay is
visible and is distinct from durable local recording. A transaction interruption
can recover only matching preimages/postimages; unexpected live content is kept
and marked for recovery. A filesystem edit and LiveSync's independent writer
cannot form a distributed transaction; LiveSync content conflicts still require
its normal resolution, and Git conflicts are reported separately.

Direct edits bypass provenance capture. `capture` explicitly imports selected
existing content and labels it as an import by the recorder; it never claims to
infer the historical writer. One job may have multiple commits joined by a task
ID, preserving prompt sharing rather than isolating unpublished drafts.

This adds a wiki-specific runtime; it does not change the dotfiles installer's
Module interface or shell update policy. Configuration and credentials stay in
local adapters and the existing Git authentication setup.
