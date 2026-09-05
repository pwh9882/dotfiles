---
name: claude
description: Use when the user asks to run Claude Code CLI (claude -p, claude --continue/--resume) or references Anthropic Claude for code analysis, review, refactoring, or automated editing
---

# Claude Code Skill Guide

## Defaults (use immediately on load)
- **Model**: inherit the account default (Fable 5). Override only when the user explicitly picks one: `--model fable|opus|sonnet|haiku` (or a full id like `claude-fable-5`).
- **Reasoning effort**: inherit the default; override with `--effort <low|medium|high|xhigh|max>` only when the user explicitly chooses a level. Use `max` only when depth matters more than latency or usage.
- **Baseline command** — swap permission flags per task:
  ```
  claude -p "<prompt>"
  ```
  For long or multiline prompts, pipe via stdin instead of an argument:
  ```
  claude -p <<'EOF'
  <prompt>
  EOF
  ```

## Permission modes
| Task | Flags |
| --- | --- |
| Read-only review / analysis (default) | — (no extra flags) |
| Apply local edits | `--permission-mode acceptEdits` |
| Edits + specific commands | `--permission-mode acceptEdits --allowedTools "Bash(git *) Bash(npm *)"` |
| Full autonomy (edits + any command) | `--dangerously-skip-permissions` |

`-p` mode has no interactive permission prompt: tool calls outside the granted set are auto-denied and Claude adapts. Reading files (Read/Grep/Glob) never needs permission, so the bare baseline is safe for analysis. Before the first use of `--dangerously-skip-permissions`, confirm with the user unless already permitted. Note that `-p` also skips the workspace trust dialog — only run it in directories the user trusts.

## Resuming a session
- Continue the most recent session in the current directory: `claude -p -c "<prompt>"`.
- Resume a specific session: `claude -p -r <session-id> "<prompt>"`.
- To capture the session id for later resumes, add `--output-format json` and read the `session_id` field (the answer is in `result`).
- **No config flags on resume** — model and effort carry over from the original session. Add a flag only if the user explicitly asks to change one.

## Running & reporting
1. Run the command; stdout is the final answer only (no thinking tokens), so no stderr suppression is needed.
2. Summarize the outcome for the user.
3. Tell the user they can continue anytime by saying "claude resume", and confirm the next step before escalating permissions.

## Error handling
- First inspect the exit status, available diagnostics, saved session/output, and any partial changes. A failed or empty final response does not prove that no work ran.
- Retry a transient failure at most once only when the operation is read-only or known to be safe to repeat and remains within the user's authorization. A version query can be retried without restarting a task.
- For editing or external actions with uncertain effects, inspect the existing session and resulting state before resuming. Do not start a fresh task merely to obtain a different output format. Ask only when an unresolved choice, uncertain duplicate action, or additional permission requires the user.
- Stop repeated failures and report the concrete error and partial outcome; never hide failure behind a successful-looking summary.
