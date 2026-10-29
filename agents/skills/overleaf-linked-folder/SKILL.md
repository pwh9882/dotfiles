---
name: overleaf-linked-folder
description: Rules for editing a paper in a local folder that the Overleaf Workshop VS Code extension keeps in sync with an Overleaf project (the folder contains .overleaf/settings.json), including how edits become suggestions the user reviews, how to answer Overleaf review comments through drafts, how to explain edits, how to see which suggestions were accepted, and where compile errors are. Use when editing .tex or .bib files in such a folder, or when asked to check, answer, resolve or move Overleaf comments, explain changes, fix LaTeX compile errors or layout problems, address the user's feedback on suggestions, or work on what the user is looking at or has selected there ("코멘트 확인해줘", "코멘트에 답글", "피드백 반영해줘", "컴파일 오류 고쳐줘", "지금 보는 문단", "선택한 문장").
---

# Overleaf linked folder

The folder is a working copy of an Overleaf project. Overleaf holds the original and its
history; co-authors edit it at the same time. Find the folder's root by the
`.overleaf/settings.json` file in it. The extension writes the files under `.overleaf/`
for you; `.overleaf/review/README.md` describes their current formats, and wins if it
differs from this skill.

## Editing the paper

- Edit existing `.tex` and `.bib` files in place. Nothing you write reaches Overleaf by
  itself: each paragraph you change is shown to the user as a suggestion, and only the
  ones they accept are applied (in explicit mode, they are merged into the user's unsaved
  Overleaf tab and uploaded when the user saves it). If the user enabled
  `agentEdits.autoAccept`, suggestions may be accepted automatically.
- Read a file again right before editing it. Co-author edits and accepted suggestions
  change the file at any time.
- Change only the paragraphs the task needs. Do not reflow, rewrap or reformat other
  text: every paragraph you touch becomes a suggestion the user must review.
- A rejected suggestion disappears from your file. If someone edits the same words on
  Overleaf first, your suggestion for that paragraph is withdrawn, the file shows their
  text, and your version is kept in `.overleaf/conflicts/`.
- New files, renames, deletions and images are not uploaded. Ask the user to create or
  rename files in Overleaf.
- A read-only file, such as a .bib linked from another Overleaf project, is a copy of a
  file Overleaf keeps as a file rather than a document. Read it (for example for citation
  keys), but do not edit it: the extension restores it. To change one, edit it in its
  source project and ask the user to refresh it (Refresh Linked Files).
- Do not edit other files under `.overleaf/`, do not save Overleaf editor tabs in VS Code,
  and do not build the PDF in a shell. Overleaf compiles accepted text; the extension
  can separately render the version with pending suggestions.

## What the user is looking at

Read `.overleaf/editor.md` when the user refers to "this paragraph", "here" or a
selection. It records the document, visible lines, cursor and selected text, with lines
mapped to this folder's files. Check the source view (Overleaf text, agent comparison or
local file), observation time, and whether the selection matches the current local text.
Overleaf text can differ from your file because your suggestions are not accepted yet.
If the text differs or moved, reread the local passage before editing; mapped lines are
approximate. If the user is in another view, this is their last observed document.

The observation time stays unchanged when only the local file changes. These files are
last observations, not connection heartbeats; they can stay old while the extension is
stopped. Older extension versions may omit these fields; do not infer freshness from
absence of a mismatch warning.

## Explaining an edit

When an explanation helps, write a JSON file into `.overleaf/review/notes/`
(any name ending in `.json`):

```json
{"file": "sections/intro.tex", "quote": "a phrase from your new text", "note": "Why you changed it"}
```

`file` is the path in this folder. `quote` must appear in the new text of that suggestion
(spaces and line breaks are ignored). The user reads the note as your reason when pointing
at the suggestion. Reuse the same filename when revising the same passage, updating both
`quote` and `note`. The latest observed explanation is shown; prior observed versions go
to `.overleaf/review/done/` with status `superseded`. Files that unambiguously match the
same current suggestion also keep the newest explanation. Use a specific quote when
several suggestions share the same words. `.overleaf/review/note-history/` is an
extension-owned checkpoint; do not edit it. When the user decides, the current note
also moves to `done/`.

## The user's feedback on your suggestions

The user can comment on any text in the comparison's agent version and can edit it
before accepting, so your file may contain their changes. `.overleaf/review/feedback.md`
lists open comments by file and line, distinguishing suggestions from other text.
Address a comment by revising the suggestion, or by editing the commented text to create
a suggestion. Update its note when useful. A comment closes when the user resolves it
or decides the suggestion it belongs to; a comment on other text closes with the
suggestion that changes that text. Results link to the recorded feedback.

## Results of your suggestions

Read `.overleaf/review/suggestions.md` first. It lists the latest 40 decisions with short
change excerpts and links to individual `results/*.json` files. Open only details
relevant to the current task; do not read the whole archive by default. Detail files
retain full before/after text, notes and feedback after their summaries leave the index.
Legacy records contain only previously saved excerpts; missing text is not recoverable.

- `accepted` / `accepted automatically`: the recorded proposal was applied. The after
  text is the proposal at decision time, including user edits; it does not separately
  identify your original proposal and the user's revision.
- `rejected`: the user removed it. Rejection alone provides no reason; do not invent one
  or treat a separate comment as an explicit rejection reason. Read the relevant detail
  before proposing changes to that passage again; do not repeat a rejected change unless
  the user asks.
- `withdrawn`: the change overlapped newer Overleaf edits. Reread the file before editing;
  the displaced version is retained in `.overleaf/conflicts/`.

## Overleaf review comments

`.overleaf/review/comments.md` lists the open threads by file and line of this folder's
files, with each thread's id, quoted text and messages. To act on a thread or start one,
write one JSON draft per action into `.overleaf/review/drafts/`:

```json
{"action": "reply",   "thread": "<thread id>", "text": "Your reply"}
{"action": "resolve", "thread": "<thread id>", "text": "Optional reply posted first"}
{"action": "comment", "file": "main.tex", "quote": "exact text in the file", "text": "Your comment"}
{"action": "move",    "thread": "<thread id>", "quote": "exact text in the thread's file"}
```

- `quote` must match the file's text exactly. If it occurs more than once, add
  `"line": N`, the line of this folder's file where it starts.
- Text inside one of your suggestions that the user has not accepted cannot carry a
  comment yet.
- The user edits each draft and posts or discards it; nothing is posted without them.
  The result (`posted`, `discarded`, or `invalid` with the reason) appears in
  `.overleaf/review/done/`.

To address a comment by changing the text, edit the file (it becomes a suggestion), add a
note, and draft a reply that says what you changed.

## Compile errors and the PDF

After an Overleaf compile, `.overleaf/build/errors.md` lists errors, warnings and layout
problems by file and line; `.overleaf/build/output.pdf` is its PDF and `output.log` its
full log. Check the time at the top of `errors.md`. Overleaf may compile automatically,
or the user can trigger it with Cmd/Ctrl+S. Its lines and PDF refer to accepted Overleaf
text, which can differ from your file. Fix source files and confirm with a later compile.

The extension can separately render pending suggestions to
`.overleaf/render/output-with-suggestions.pdf`. Before using it to judge your latest
edit, read `.overleaf/render/status.json`:

- `current`: the PDF's recorded inputs match current inputs.
- `rendering`: a build is running; the existing PDF may still be an older one.
- `stale`: inputs differ from the PDF's inputs, including an edit made during rendering.
- `failed`: the last render failed or TeX reported errors; inspect `error` and the render
  log. Even if `pdfMatchesInputs` is true, an error PDF can be incomplete.
- `not-rendered` / `unknown`: no rendered PDF, or freshness cannot be established.

`renderedAt` is the last PDF generation and `checkedAt` the last status observation.
Hashes cover linked document contents, read-only copies, compiler/root and remote asset
versions. Timestamps alone do not prove freshness. Status cannot follow edits while the
extension is stopped; an abrupt disconnect can leave an old `current` status. If the
status file is absent, do not assume the PDF is current. Use the extension's **Render PDF
with Suggestions** action when a new render is needed; do not compile independently.

## Git

If the folder is inside a Git repository, it should be ignored there. Do not run Git
commands that change files in it (checkout, switch, reset, restore, stash, pull, merge,
rebase, clean): the extension takes every change as your edit and shows it as
suggestions. `git status`, `git diff` and `git log` are safe. Never commit `.overleaf/`;
it holds Overleaf IDs, recovery copies and sync state.
