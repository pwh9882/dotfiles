#!/usr/bin/env bash

# Desired state for the first migrated Module.

DF_BIN_TOOLS="dotfiles dotfiles-check llm-instance llm-wiki-git llm-wiki-status llm-wiki-commit llm-wiki-lint"

df_module_bin() {
  local tool
  local failed=0
  if [ "$DF_MODE" = "doctor" ]; then
    df_dir "$HOME/.local" 0755 || failed=1
    df_dir "$HOME/.local/bin" 0755 || failed=1
    for tool in $DF_BIN_TOOLS; do
      df_link "$DF_ROOT/bin/$tool" "$HOME/.local/bin/$tool" || failed=1
    done
    [ "$failed" -eq 0 ]
    return
  fi

  df_dir "$HOME/.local" 0755 || return 1
  df_dir "$HOME/.local/bin" 0755 || return 1
  for tool in $DF_BIN_TOOLS; do
    df_link "$DF_ROOT/bin/$tool" "$HOME/.local/bin/$tool" || return 1
  done
}
