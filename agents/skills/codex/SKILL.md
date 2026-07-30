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
  echo "<prompt>" | codex exec --skip-git-repo-check -m gpt-5.6-sol \
    --sandbox read-only 2>/dev/null
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
- Continue the most recent session: `echo "<prompt>" | codex exec --skip-git-repo-check resume --last 2>/dev/null`.
- **No config flags on resume** — model, effort, and sandbox are inherited from the original session. Add a flag only if the user explicitly asks to change one; when passed, flags go between `exec` and `resume`.
- Manage saved sessions with `codex resume` (picker), `codex fork` (branch), and `archive` / `unarchive` / `delete`.

## Running & reporting
1. Every `codex exec` ends with `2>/dev/null` to suppress thinking tokens; show stderr only when the user asks or you're debugging.
2. Run the command, then summarize the outcome.
3. Tell the user they can continue anytime by saying "codex resume", and use `AskUserQuestion` to confirm the next step.

## Error handling
- If `codex --version` or a `codex exec` exits non-zero, stop and report; ask before retrying.
- Summarize any warnings or partial results and ask how to adjust.
