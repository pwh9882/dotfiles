---
name: codex
description: Use when the user asks to run Codex CLI (codex exec, codex resume) or references OpenAI Codex for code analysis, refactoring, or automated editing
---

# Codex Skill Guide

## Defaults (use immediately on load)
- **Model**: `gpt-5.6-sol` — the default Codex CLI model for this account.
- **Reasoning effort**: Inherit `model_reasoning_effort` from `~/.codex/config.toml` by default; do not override it unless the user explicitly chooses a level. Supported levels are `low` (fast, light), `medium` (balanced), `high` (deep), `xhigh` (extra high), `max` (maximum single-agent reasoning for the hardest problems), and `ultra` (maximum reasoning with automatic task delegation to subagents). Use `max` only when depth matters more than latency or usage. Use `ultra` only when the work can split into meaningful independent parts; most tasks need neither.
- **Fast mode**: Inherit `service_tier` from `~/.codex/config.toml` by default. `priority` selects the Fast tier (about 1.5x speed with increased usage); the legacy config value `fast` maps to the same request value. Fast is independent of reasoning effort and can be combined with any level above. When an explicit portable override is needed, pass `--config service_tier="priority"`.
- **Baseline command** — swap `--sandbox` / add `--full-auto` per task:
  ```
  codex_diagnostics="$(mktemp "${TMPDIR:-/tmp}/codex-diagnostics.XXXXXX")"
  echo "<prompt>" | codex exec --skip-git-repo-check -m gpt-5.6-sol \
    --sandbox read-only 2>"$codex_diagnostics"
  ```

  To override the inherited defaults, add `--config model_reasoning_effort="<level>"` and/or `--config service_tier="priority"` before `--sandbox`.

## Sandbox modes
| Task | `--sandbox` | Extra flags |
| --- | --- | --- |
| Read-only review / analysis (default) | `read-only` | — |
| Apply local edits | `workspace-write` | `--full-auto` |
| Network or broad access | `danger-full-access` | `--full-auto` |

`--skip-git-repo-check` is always included. Default to `read-only` unless edits or network are needed. Before the first use of `--full-auto` or `--sandbox danger-full-access`, confirm with `AskUserQuestion` unless already permitted.

## Resuming a session
- Continue the most recent session: create a private diagnostics file as above, then run `echo "<prompt>" | codex exec --skip-git-repo-check resume --last 2>"$codex_diagnostics"`.
- **No config flags on resume** — model, effort, and sandbox are inherited from the original session. Add a flag only if the user explicitly asks to change one; when passed, flags go between `exec` and `resume`.
- Manage saved sessions with `codex resume` (picker), `codex fork` (branch), and `archive` / `unarchive` / `delete`.

## Running & reporting
1. Keep progress/thinking output out of the user-facing result, while preserving stderr in the mode-0600 temporary file created by `mktemp`. On failure, inspect only the needed diagnostic lines and redact secrets; do not copy raw reasoning into the report. Remove the temporary log after diagnosis unless the user needs it for an unresolved failure. Never put it in the wiki or Git.
2. Run the command, then summarize the outcome.
3. Report the result and session continuation information when useful. Continue already-authorized work without a routine confirmation question.

## Error handling
- First inspect the exit status, available diagnostics, saved session/output, and any partial changes. A failed or empty final response does not prove that no work ran.
- Retry a transient failure at most once only when the operation is read-only or known to be safe to repeat and remains within the user's authorization. A version query can be retried without restarting a task.
- For editing or external actions with uncertain effects, inspect the existing session and resulting state before resuming. Do not start a fresh task merely to obtain a different output format. Ask only when an unresolved choice, uncertain duplicate action, or additional permission requires the user.
- Stop repeated failures and report the concrete error and partial outcome; never hide failure behind a successful-looking summary.
