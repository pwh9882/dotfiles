#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOSTNAME="$(hostname -s)"
LOCAL_FILE="$SCRIPT_DIR/.zshrc.local.$HOSTNAME"

# Symlink shared .zshrc
ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
echo "  Linked .zshrc"

# Symlink machine-specific local config
if [[ -f "$LOCAL_FILE" ]]; then
    ln -sf "$LOCAL_FILE" "$HOME/.zshrc.local"
    echo "  Linked .zshrc.local -> .zshrc.local.$HOSTNAME"
else
    echo "  ⚠ No local config found for hostname '$HOSTNAME'"
    echo "  Create one at: $SCRIPT_DIR/.zshrc.local.$HOSTNAME"
fi
