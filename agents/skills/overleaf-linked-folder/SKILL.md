---
name: overleaf-linked-folder
description: Rules for editing a paper in a local folder that the Overleaf Workshop VS Code extension keeps in sync with an Overleaf project (the folder contains .overleaf/settings.json), including how edits become suggestions the user reviews, how to answer Overleaf review comments through drafts, how to explain edits, how to see which suggestions were accepted, and where compile errors are. Use when editing .tex or .bib files in such a folder, or when asked to check, answer, resolve or move Overleaf comments, explain changes, or fix LaTeX compile errors there ("코멘트 확인해줘", "코멘트에 답글", "컴파일 오류 고쳐줘").
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
  Overleaf tab and uploaded when the user saves it).
- Read a file again right before editing it. Co-author edits and accepted suggestions
  change the file at any time.
- Change only the paragraphs the task needs. Do not reflow, rewrap or reformat other
  text: every paragraph you touch becomes a suggestion the user must review.
- A rejected suggestion disappears from your file. If someone edits the same words on
  Overleaf first, your suggestion for that paragraph is withdrawn, the file shows their
  text, and your version is kept in `.overleaf/conflicts/`.
- New files, renames, deletions and images are not uploaded. Ask the user to create or
  rename files in Overleaf.
- Do not edit other files under `.overleaf/`, do not save Overleaf editor tabs in VS Code,
  and do not build the PDF in a shell; Overleaf compiles it.

## Explaining an edit

Write one JSON file per note into `.overleaf/review/notes/` (any name ending in `.json`):

```json
{"file": "sections/intro.tex", "quote": "a phrase from your new text", "note": "Why you changed it"}
```

`file` is the path in this folder. `quote` must appear in the new text of that suggestion
(spaces and line breaks are ignored). The user sees the note with the suggestion. When
they decide, the note moves to `.overleaf/review/done/`.

## Results of your suggestions

`.overleaf/review/suggestions.md` lists, newest first, whether each suggestion was
accepted, accepted automatically, rejected or withdrawn, with the text before, your text
and your note. Read it before proposing changes to the same passage again. Do not propose
a rejected change again unless the user asks.

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

## Compile errors

After each compile, `.overleaf/build/errors.md` lists the LaTeX errors and warnings by file
and line, and `.overleaf/build/output.log` holds the full log. Check the time at its top:
it describes the last compile, which the user starts (Cmd/Ctrl+S in an Overleaf tab).
Line numbers refer to the text Overleaf compiled, which differs from your file where
suggestions are not accepted yet. Fix errors in the source files; ask the user to compile
again to confirm.

## Git

If the folder is inside a Git repository, it should be ignored there. Do not run Git
commands that change files in it (checkout, switch, reset, restore, stash, pull, merge,
rebase, clean): the extension takes every change as your edit and shows it as
suggestions. `git status`, `git diff` and `git log` are safe. Never commit `.overleaf/`;
it holds Overleaf IDs, recovery copies and sync state.
