---
name: codex
description: Use when the user asks to run Codex CLI (codex exec, codex resume) or references OpenAI Codex for code analysis, refactoring, or automated editing
---

# Codex Skill Guide

## Defaults (use immediately on load)
- **Model**: `gpt-6-astra` — the user's default for new Codex calls, including calls from Claude Code and review workflows. Preserve an explicit user model choice.
- **Reasoning effort**: `medium`. Pass it explicitly so a machine-local `high`, `xhigh`, or `ultra` setting cannot silently change the default. Override only when the user chooses another level; check availability for the selected model. Do not automatically increase effort or enable subagents for a review.
- **Fast mode**: Inherit `service_tier` from `~/.codex/config.toml`. It is independent of model and effort. For an explicit Fast override, use `-c 'service_tier="priority"'`; do not hard-code speed or usage multipliers.
- **Baseline command** — choose the sandbox for the authorized task:
  ```bash
  codex_diagnostics="$(mktemp "${TMPDIR:-/tmp}/codex-diagnostics.XXXXXX")"
  codex exec --skip-git-repo-check -m gpt-6-astra \
    -c 'model_reasoning_effort="medium"' \
    --sandbox read-only - 2>"$codex_diagnostics" <<'PROMPT'
  <prompt>
  PROMPT
  ```

  Use a quoted heredoc or an existing prompt file via stdin for multiline prompts. Replace the model/effort flags for an explicit override; do not append conflicting defaults.

## Sandbox modes
| Task | `--sandbox` | Extra flags |
| --- | --- | --- |
| Read-only review / analysis (default) | `read-only` | — |
| Apply local edits | `workspace-write` | — |
| Local edits with automatic approval review | `workspace-write` | `--approve-for-me` |
| Explicitly authorized unsandboxed execution | `danger-full-access` | — |

`--skip-git-repo-check` is always included. Default to `read-only` for analysis and `workspace-write` for authorized edits. Network access alone is not a reason to disable the sandbox. Keep execution within the parent session's permissions; do not use a child CLI to bypass a denial. Continue already-authorized work without asking again. Ask only if additional access is actually needed and not already authorized.

Command examples were checked against Codex CLI `0.153.4` on 2026-09-05. Use `codex exec --help` and `codex exec resume --help` when a target installation differs; current examples use `--approve-for-me` instead of the older `--full-auto` shorthand.

## Resuming a session
- Prefer a known session ID: `codex exec --skip-git-repo-check resume <session-id> - < followup.txt 2>"$codex_diagnostics"`. Create the private diagnostics file as above first.
- Use `resume --last -` only when the latest session in the working directory is the intended one.
- Do not reapply new-session model/effort defaults on resume. Preserve the existing session unless the user requests a change. For an intentional Astra/medium switch, use `codex exec --skip-git-repo-check resume <session-id> -m gpt-6-astra -c 'model_reasoning_effort="medium"' - < followup.txt`. Sandbox options belong before `resume`; inspect permissions before continuing an editing session.
- `codex resume` opens the interactive picker; `codex exec fork --help` describes non-interactive branching.

## Running & reporting
1. Keep progress/thinking output out of the user-facing result, while preserving stderr in the mode-0600 temporary file created by `mktemp`. On failure, inspect only the needed diagnostic lines and redact secrets; do not copy raw reasoning into the report. Remove the temporary log after diagnosis unless the user needs it for an unresolved failure. Never put it in the wiki or Git.
2. Run the command, then summarize the outcome.
3. Report the result and session continuation information when useful. Continue already-authorized work without a routine confirmation question.

## Error handling
- First inspect the exit status, available diagnostics, saved session/output, and any partial changes. A failed or empty final response does not prove that no work ran.
- Retry a transient failure at most once only when the operation is read-only or known to be safe to repeat and remains within the user's authorization. A version query can be retried without restarting a task.
- For editing or external actions with uncertain effects, inspect the existing session and resulting state before resuming. Do not start a fresh task merely to obtain a different output format. Ask only when an unresolved choice, uncertain duplicate action, or additional permission requires the user.
- Stop repeated failures and report the concrete error and partial outcome; never hide failure behind a successful-looking summary.
