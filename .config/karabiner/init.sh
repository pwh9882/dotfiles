#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.config/karabiner/bin"

mkdir -p "$BIN_DIR"

# Compile set-capslock-led
if [ -f "$SCRIPT_DIR/set-capslock-led.c" ]; then
    echo "Compiling set-capslock-led..."
    cc -framework IOKit -o "$BIN_DIR/set-capslock-led" "$SCRIPT_DIR/set-capslock-led.c"
    echo "  -> $BIN_DIR/set-capslock-led"
fi

# Ensure bin/ is gitignored
GITIGNORE="$SCRIPT_DIR/.gitignore"
if ! grep -qx "bin/" "$GITIGNORE" 2>/dev/null; then
    echo "bin/" >> "$GITIGNORE"
fi
