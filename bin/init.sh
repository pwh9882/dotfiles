#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.local/bin"

mkdir -p "$TARGET_DIR"

for tool in llm-wiki-git llm-wiki-status llm-wiki-commit; do
  ln -sf "$SCRIPT_DIR/$tool" "$TARGET_DIR/$tool"
  echo "  Linked $TARGET_DIR/$tool"
done
