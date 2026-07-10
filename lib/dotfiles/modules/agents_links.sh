#!/usr/bin/env bash

# Desired shared-instruction links for agent harnesses with native global files.

df_module_agents_links() {
  local failed=0

  if [ "$DF_MODE" = "doctor" ]; then
    df_dir "$HOME/.claude" 0755 || failed=1
    df_link "$DF_ROOT/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md" || failed=1
    df_dir "$HOME/.codex" 0755 || failed=1
    df_link "$DF_ROOT/agents/AGENTS.md" "$HOME/.codex/AGENTS.md" || failed=1
    [ "$failed" -eq 0 ]
    return
  fi

  df_dir "$HOME/.claude" 0755 || return 1
  df_link "$DF_ROOT/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md" || return 1
  df_dir "$HOME/.codex" 0755 || return 1
  df_link "$DF_ROOT/agents/AGENTS.md" "$HOME/.codex/AGENTS.md" || return 1
}
