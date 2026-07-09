#!/bin/bash
# Wire the shared global agents file (the LLM-WIKI pointer) into every harness.
# Canonical source: ~/dotfiles/agents/AGENTS.md — one file, four consumers.
# Idempotent; safe to re-run.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/AGENTS.md"

# Install the shared helper commands, including llm-instance.
"$SCRIPT_DIR/../bin/init.sh"

# --- Claude Code -------------------------------------------------------------
# Claude Code reads CLAUDE.md, not AGENTS.md; a symlink is the documented
# interop pattern (https://code.claude.com/docs/en/memory).
mkdir -p "$HOME/.claude"
ln -sf "$SRC" "$HOME/.claude/CLAUDE.md"
echo "✅ ~/.claude/CLAUDE.md -> agents/AGENTS.md"

# --- Codex CLI ---------------------------------------------------------------
# ~/.codex/AGENTS.md is Codex's global instructions file.
mkdir -p "$HOME/.codex"
ln -sf "$SRC" "$HOME/.codex/AGENTS.md"
echo "✅ ~/.codex/AGENTS.md -> agents/AGENTS.md"

# --- Hermes ------------------------------------------------------------------
# Hermes auto-injects cwd AGENTS.md but has no global AGENTS.md; the global
# pointer rides ~/.hermes/SOUL.md (loaded fresh every message). Append once.
if [ -f "$HOME/.hermes/SOUL.md" ]; then
  if ! grep -q "LLM-WIKI" "$HOME/.hermes/SOUL.md"; then
    cat >> "$HOME/.hermes/SOUL.md" <<'EOF'

<!-- Operational context (not persona): LLM-WIKI pointer. Managed alongside
     dotfiles/agents/AGENTS.md; Hermes has no global AGENTS.md, so it rides here. -->

## LLM-WIKI — durable shared memory

A shared LLM wiki lives at `~/Documents/Obsidian Vault/LLM-WIKI` (symlink `~/llm-wiki`). Before machine, infra, or project work, read its `index.md` and `AGENTS.md`; machine paths live in `instances/`, procedures in `runbooks/`, project state in `projects/`, past decisions in `decisions/`. Update it when durable knowledge changes; commit with `llm-wiki-git` / `llm-wiki-commit`, message prefix = current instance id. Sibling vault layers: `sources/` (raw source files) and `human-inbox/` (human-owned working area — write only where asked).
EOF
    echo "✅ appended LLM-WIKI section to ~/.hermes/SOUL.md"
  fi
  if ! grep -q "llm-instance" "$HOME/.hermes/SOUL.md"; then
    cat >> "$HOME/.hermes/SOUL.md" <<'EOF'

## Machine identity

Before machine-, infra-, or project-related work, run `llm-instance` once and treat its one-line result as authoritative. Never infer the current machine from paths, usernames, or prior context. If it fails, stop machine-specific changes and repair `~/.config/llm-wiki/instance-id`.
EOF
    echo "✅ appended machine identity section to ~/.hermes/SOUL.md"
  fi
fi

# --- OpenClaw ----------------------------------------------------------------
# Per-workspace AGENTS.md is auto-loaded at session start. Filesystem tools are
# typically workspace-only, so the section states that and routes via exec/user.
for ws in "$HOME/.openclaw"/workspace*; do
  [ -f "$ws/AGENTS.md" ] || continue
  if ! grep -q "LLM-WIKI" "$ws/AGENTS.md"; then
    cat >> "$ws/AGENTS.md" <<'EOF'

## LLM-WIKI — durable shared memory (machine-wide)

A shared LLM wiki lives outside this workspace at `~/Documents/Obsidian Vault/LLM-WIKI` (Git-managed, synced across machines). It is the durable source of truth for infrastructure, machines, projects, and decisions — including how this OpenClaw instance is set up (`harnesses/openclaw.md`).

- Filesystem tools here are workspace-only, so you cannot open it directly; use approved `exec` access or ask the user to bring the relevant document into the workspace.
- When you learn something durable that outlives this workspace (infra facts, cross-machine knowledge, decisions), surface it to the user so it gets promoted into the wiki rather than living only in workspace memory.
EOF
    echo "✅ appended LLM-WIKI section to $ws/AGENTS.md"
  fi
  if ! grep -q "llm-instance" "$ws/AGENTS.md"; then
    cat >> "$ws/AGENTS.md" <<'EOF'

## Machine identity

Before machine-, infra-, or project-related work, run `llm-instance` through approved exec once and treat its one-line result as authoritative. Never infer the current machine from paths, usernames, or prior context. If it fails, stop machine-specific changes and repair `~/.config/llm-wiki/instance-id`.
EOF
    echo "✅ appended machine identity section to $ws/AGENTS.md"
  fi
done

echo "🎉 agents wiring complete"
