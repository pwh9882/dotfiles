#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

echo "📦 Setting up .config..."

# ---- Install fonts (macOS only — WSL/Linux fonts are managed by the host terminal) ----
if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
  BREW_CASKS=(font-jetbrains-mono-nerd-font)
  for cask in "${BREW_CASKS[@]}"; do
    if ! brew list --cask "$cask" &>/dev/null; then
      echo "  ⬇️  Installing $cask..."
      brew install --cask "$cask"
    else
      echo "  ✅ $cask already installed"
    fi
  done
fi

mkdir -p "$CONFIG_DIR"

# ---- Directory symlinks (Stow-style) ----
# -n flag: treat existing symlink-to-dir as file to replace (idempotent)
DIRS=(wezterm nvim fish neofetch)

for dir in "${DIRS[@]}"; do
  if [[ -d "$SCRIPT_DIR/$dir" ]]; then
    ln -sfn "$SCRIPT_DIR/$dir" "$CONFIG_DIR/$dir"
    echo "  ✅ Linked $dir/"
  fi
done

# ---- Starship config ----
HOSTNAME="$(hostname -s)"
OVERRIDE_SCRIPT="$SCRIPT_DIR/starship.overrides.$HOSTNAME.sh"

if [[ -f "$OVERRIDE_SCRIPT" ]]; then
  # Machine with overrides: remove symlink first, then copy + patch
  rm -f "$CONFIG_DIR/starship.toml"
  cp "$SCRIPT_DIR/starship.toml" "$CONFIG_DIR/starship.toml"
  bash "$OVERRIDE_SCRIPT" "$CONFIG_DIR/starship.toml"
  echo "  ✅ Patched starship.toml for $HOSTNAME"
else
  # Default: symlink for instant updates
  ln -sf "$SCRIPT_DIR/starship.toml" "$CONFIG_DIR/starship.toml"
  echo "  ✅ Linked starship.toml"
fi

# ---- Zed: settings.json only (avoid runtime file pollution) ----
if [[ -f "$SCRIPT_DIR/zed/settings.json" ]]; then
  mkdir -p "$CONFIG_DIR/zed"
  ln -sf "$SCRIPT_DIR/zed/settings.json" "$CONFIG_DIR/zed/settings.json"
  echo "  ✅ Linked zed/settings.json"
fi

echo "🎉 .config setup complete!"
