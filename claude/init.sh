#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
STATUSLINE_SOURCE="$SCRIPT_DIR/statusline-command.sh"
STATUSLINE_DESTINATION="$CLAUDE_DIR/statusline-command.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# shellcheck source=../lib/dotfiles/legacy_links.sh
. "$SCRIPT_DIR/../lib/dotfiles/legacy_links.sh"

# Refuse link and settings conflicts before package installation or writes.
if [[ (-e "$CLAUDE_DIR" || -L "$CLAUDE_DIR") && ! -d "$CLAUDE_DIR" ]]; then
  echo "❌ Claude config path is not a directory: $CLAUDE_DIR" >&2
  exit 1
fi
df_legacy_preflight_exact_link "$STATUSLINE_SOURCE" "$STATUSLINE_DESTINATION"
if [[ -L "$SETTINGS_FILE" || (-e "$SETTINGS_FILE" && ! -f "$SETTINGS_FILE") ]]; then
  echo "❌ Refusing to replace non-regular Claude settings: $SETTINGS_FILE" >&2
  exit 1
fi

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
df_legacy_link_exact \
  "$STATUSLINE_SOURCE" "$STATUSLINE_DESTINATION" "statusline-command.sh"

# Ensure statusline config in settings.json
STATUSLINE_CMD="$STATUSLINE_DESTINATION"
SETTINGS_TMP="$(mktemp "$CLAUDE_DIR/.settings.json.XXXXXX")"
trap '/bin/rm -f "$SETTINGS_TMP"' EXIT HUP INT TERM

if [ -f "$SETTINGS_FILE" ]; then
  # Update existing settings.json without exposing a truncate-in-place window.
  jq --arg cmd "$STATUSLINE_CMD" \
    '.statusLine = {"type":"command","command":$cmd,"padding":0}' \
    "$SETTINGS_FILE" >"$SETTINGS_TMP"
  SETTINGS_RESULT="Updated"
else
  # Create new settings.json
  jq -n --arg cmd "$STATUSLINE_CMD" \
    '{"statusLine":{"type":"command","command":$cmd,"padding":0}}' \
    >"$SETTINGS_TMP"
  SETTINGS_RESULT="Created"
fi
chmod 0600 "$SETTINGS_TMP"
mv "$SETTINGS_TMP" "$SETTINGS_FILE"
trap - EXIT HUP INT TERM
echo "✅ $SETTINGS_RESULT settings.json"

echo "🎉 Claude Code statusline setup complete!"
