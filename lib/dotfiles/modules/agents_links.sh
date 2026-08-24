#!/usr/bin/env bash

# Desired shared-instruction links for agent harnesses with native global files.

# Skills authored here and shared across machines. Every link points straight at
# this repository, so `git pull` is the whole update path and the two harnesses
# always read the same file. `~/.agents/skills/<name>` gets a link as well, which
# keeps that directory the full view of centrally managed skills alongside the
# installed third-party ones. Each harness links only the skills it should load.
# Anything not listed (installed third-party skills, machine-local skills like
# the MacBook's rename-thread or ddps-srv-2's codex-usage-guard) stays a real
# directory under the harness and is left alone.
DF_SKILLS_BOTH="pro-prepare pro-verify"
DF_SKILLS_CLAUDE_ONLY="codex weekly-report"
DF_SKILLS_CODEX_ONLY="claude"

df_agents_skill_links() {
  local name

  df_dir "$HOME/.agents" 0755 || return 1
  df_dir "$HOME/.agents/skills" 0755 || return 1
  df_dir "$HOME/.claude/skills" 0755 || return 1
  df_dir "$HOME/.codex/skills" 0755 || return 1

  for name in $DF_SKILLS_BOTH $DF_SKILLS_CLAUDE_ONLY $DF_SKILLS_CODEX_ONLY; do
    df_link "$DF_ROOT/agents/skills/$name" "$HOME/.agents/skills/$name" || return 1
  done

  for name in $DF_SKILLS_BOTH $DF_SKILLS_CLAUDE_ONLY; do
    df_link "$DF_ROOT/agents/skills/$name" "$HOME/.claude/skills/$name" || return 1
  done

  for name in $DF_SKILLS_BOTH $DF_SKILLS_CODEX_ONLY; do
    df_link "$DF_ROOT/agents/skills/$name" "$HOME/.codex/skills/$name" || return 1
  done
}

df_module_agents_links() {
  local failed=0

  if [ "$DF_MODE" = "doctor" ]; then
    df_dir "$HOME/.claude" 0755 || failed=1
    df_link "$DF_ROOT/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md" || failed=1
    df_dir "$HOME/.codex" 0755 || failed=1
    df_link "$DF_ROOT/agents/AGENTS.md" "$HOME/.codex/AGENTS.md" || failed=1
    df_agents_skill_links || failed=1
    [ "$failed" -eq 0 ]
    return
  fi

  df_dir "$HOME/.claude" 0755 || return 1
  df_link "$DF_ROOT/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md" || return 1
  df_dir "$HOME/.codex" 0755 || return 1
  df_link "$DF_ROOT/agents/AGENTS.md" "$HOME/.codex/AGENTS.md" || return 1
  df_agents_skill_links || return 1
}
