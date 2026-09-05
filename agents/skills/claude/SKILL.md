---
name: claude
description: Use when the user asks to run Claude Code CLI (claude -p, claude --continue/--resume) or references Anthropic Claude for code analysis, review, refactoring, or automated editing
---

# Claude Code Skill Guide

## Defaults (use immediately on load)
- **Model**: inherit the configured Claude model; do not assume a particular account default. Override only when the user explicitly picks one, using an alias or full ID supported by `claude --help`. The Astra/medium default applies to Codex calls, not Anthropic models.
- **Reasoning effort**: inherit the default; override with `--effort <low|medium|high|xhigh|max>` only when the user explicitly chooses a level. Use `max` only when depth matters more than latency or usage.
- **Baseline command for file review** — choose tools and permission flags per task:
  ```
  claude -p --permission-mode plan --permission-prompts none --tools 'Read,Grep,Glob' "<prompt>"
  ```
  For long or multiline prompts, pipe via stdin instead of an argument:
  ```
  claude -p --permission-mode plan --permission-prompts none --tools 'Read,Grep,Glob' <<'EOF'
  <prompt>
  EOF
  ```

## Permission modes
| Task | Flags |
| --- | --- |
| File review / analysis (default) | `--permission-mode plan --permission-prompts none --tools 'Read,Grep,Glob'` |
| Apply local edits | `--permission-mode acceptEdits --permission-prompts none` |
| Edits + specific commands | `--permission-mode acceptEdits --permission-prompts none --allowedTools 'Bash(git diff *)' 'Bash(npm test *)'` (adjust to the task) |
| Full autonomy (edits + any command) | `--dangerously-skip-permissions` |

Bare `-p` inherits permission settings and allowlists; it is not a read-only boundary. `--tools` restricts built-in tool availability, while `--allowedTools` grants permissions rather than restricting all available tools. Add only the commands or MCP tools needed by the authorized task. `--permission-prompts none` denies actions that would need a prompt; it does not revoke existing grants. This baseline limits model tools, not configured hooks or plugins.

Continue authorized edits without routine confirmation. Use `--dangerously-skip-permissions` only when that execution scope is already authorized; never use a child CLI to bypass parent restrictions. `-p` skips the workspace trust dialog, so run only in trusted project directories. These flags were checked against Claude Code `2.1.261` on 2026-09-05; consult `claude --help` on other installations.

## Resuming a session
- Continue the most recent session in the current directory: `claude -p -c "<prompt>"`.
- Resume a specific session: `claude -p -r <session-id> "<prompt>"`.
- To capture the session id for later resumes, add `--output-format json` and read the `session_id` field (the answer is in `result`).
- Preserve the intended session's model and effort; do not impose new-session defaults on resume. Reapply the task's tool and permission restrictions when continuing a review.

## Running & reporting
1. Run the command and inspect its exit status. Default text output is for the answer; JSON uses `result`, `session_id`, and error metadata. Inspect diagnostics on failure without exposing secrets or raw reasoning.
2. Summarize the outcome for the user.
3. Report continuation information when useful, and continue work already authorized by the user.

## Error handling
- First inspect the exit status, available diagnostics, saved session/output, and any partial changes. A failed or empty final response does not prove that no work ran.
- Retry a transient failure at most once only when the operation is read-only or known to be safe to repeat and remains within the user's authorization. A version query can be retried without restarting a task.
- For editing or external actions with uncertain effects, inspect the existing session and resulting state before resuming. Do not start a fresh task merely to obtain a different output format. Ask only when an unresolved choice, uncertain duplicate action, or additional permission requires the user.
- Stop repeated failures and report the concrete error and partial outcome; never hide failure behind a successful-looking summary.
