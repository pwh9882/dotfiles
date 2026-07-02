#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "📦 Setting up Claude Code statusline..."

# Check jq dependency
if ! command -v jq &>/dev/null; then
  echo "⬇️  Installing jq..."
  if command -v brew &>/dev/null; then
    brew install jq
  elif command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y jq
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm jq
  else
    echo "❌ Could not detect package manager. Please install jq manually."
    exit 1
  fi
fi

echo "✅ jq found"

# Create claude config directory
mkdir -p "$CLAUDE_DIR"

# Symlink statusline script
ln -sf "$SCRIPT_DIR/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
echo "✅ Symlinked statusline-command.sh"

# Global agents file (LLM-WIKI pointer) for all harnesses — see agents/init.sh
"$SCRIPT_DIR/../agents/init.sh"

# Ensure statusline config in settings.json
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
STATUSLINE_CMD="$CLAUDE_DIR/statusline-command.sh"

if [ -f "$SETTINGS_FILE" ]; then
  # Update existing settings.json with statusLine config
  TMP=$(jq --arg cmd "$STATUSLINE_CMD" '.statusLine = {"type":"command","command":$cmd,"padding":0}' "$SETTINGS_FILE")
  echo "$TMP" > "$SETTINGS_FILE"
  echo "✅ Updated settings.json"
else
  # Create new settings.json
  jq -n --arg cmd "$STATUSLINE_CMD" '{"statusLine":{"type":"command","command":$cmd,"padding":0}}' > "$SETTINGS_FILE"
  echo "✅ Created settings.json"
fi

echo "🎉 Claude Code statusline setup complete!"
