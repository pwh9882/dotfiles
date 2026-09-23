#!/usr/bin/env bash
# tmux-resurrect post-save hook.
# Two saves in the same second write the same file; the second one sees it as
# identical to `last` and deletes it, leaving `last` dangling so auto-restore
# finds nothing. Repoint a dangling `last` to the newest remaining save.

dir="$(tmux show-option -gqv @resurrect-dir)"
if [ -z "$dir" ]; then
  if [ -d "$HOME/.tmux/resurrect" ]; then
    dir="$HOME/.tmux/resurrect"
  else
    dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
  fi
fi
dir="$(printf '%s' "$dir" | sed "s,\$HOME,$HOME,g; s,~,$HOME,g")"

last="$dir/last"
[ -L "$last" ] && [ ! -e "$last" ] || exit 0

newest="$(ls -t "$dir"/tmux_resurrect_*.txt 2>/dev/null | head -n 1)"
[ -n "$newest" ] && ln -sfn "$(basename "$newest")" "$last"
