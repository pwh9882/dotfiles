#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./init.sh [--list]

Runs the dotfiles modules once in their supported order.
--list prints the resolved module paths without executing them.
EOF
}

MODULES=(
  "$SCRIPT_DIR/bin/init.sh"
  "$SCRIPT_DIR/zsh/init.sh"
  "$SCRIPT_DIR/bash/init.sh"
  "$SCRIPT_DIR/agents/init.sh"
  "$SCRIPT_DIR/claude/init.sh"
  "$SCRIPT_DIR/ssh/init.sh"
  "$SCRIPT_DIR/tmux/init.sh"
  "$SCRIPT_DIR/.config/init.sh"
)

if [[ "$(uname -s)" == "Darwin" ]]; then
  MODULES+=("$SCRIPT_DIR/.config/karabiner/init.sh")
fi

case "${1:-}" in
  "") ;;
  --list) ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ "$#" -gt 1 ]]; then
  usage >&2
  exit 2
fi

# Validate the complete platform plan before making any changes.
for module in "${MODULES[@]}"; do
  if [[ ! -f "$module" ]]; then
    echo "❌ Required dotfiles module is missing: $module" >&2
    exit 1
  fi
done

if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' "${MODULES[@]}"
  exit 0
fi

echo "🚀 Initializing all dotfiles..."

for module in "${MODULES[@]}"; do
  echo "👉 Running $module"
  if bash "$module"; then
    :
  else
    status=$?
    echo "❌ Module failed ($status): $module" >&2
    exit "$status"
  fi
done

echo "✅ All done!"
