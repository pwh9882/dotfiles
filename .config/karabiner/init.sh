#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.config/karabiner/bin"
SOURCE="$SCRIPT_DIR/set-capslock-led.c"
OUTPUT="$BIN_DIR/set-capslock-led"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "⏭️  Skipping Karabiner helper: macOS is required."
    exit 0
fi

if ! command -v cc >/dev/null 2>&1; then
    echo "❌ Cannot compile Karabiner helper: cc is not installed." >&2
    exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
    echo "❌ Karabiner helper source is missing: $SOURCE" >&2
    exit 1
fi

mkdir -p "$BIN_DIR"

temporary="$BIN_DIR/.set-capslock-led.$$"
trap 'rm -f "$temporary"' EXIT

echo "Compiling set-capslock-led..."
cc -framework IOKit -o "$temporary" "$SOURCE"
mv "$temporary" "$OUTPUT"
trap - EXIT
echo "  -> $OUTPUT"
