#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMUX_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux"
OH_MY_TMUX_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/oh-my-tmux"

echo "📦 Setting up tmux with Oh my tmux!..."

# Install tmux if not present
if ! command -v tmux &>/dev/null; then
  echo "⬇️  Installing tmux..."
  if command -v brew &>/dev/null; then
    brew install tmux
  elif command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y tmux
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm tmux
  else
    echo "❌ Could not detect package manager. Please install tmux manually."
    exit 1
  fi
fi

echo "✅ tmux $(tmux -V | cut -d' ' -f2) found"

# Install Oh my tmux!
if [[ ! -d "$OH_MY_TMUX_DIR" ]]; then
  echo "⬇️  Cloning Oh my tmux!..."
  mkdir -p "$(dirname "$OH_MY_TMUX_DIR")"
  git clone https://github.com/gpakosz/.tmux.git "$OH_MY_TMUX_DIR"
else
  echo "✅ Oh my tmux! already installed, pulling latest..."
  git -C "$OH_MY_TMUX_DIR" pull --ff-only || true
fi

# Create config directory
mkdir -p "$TMUX_CONFIG_DIR"

# Symlink tmux.conf -> Oh my tmux!
ln -sf "$OH_MY_TMUX_DIR/.tmux.conf" "$TMUX_CONFIG_DIR/tmux.conf"
echo "✅ Symlinked tmux.conf"

# Symlink tmux.conf.local -> dotfiles
ln -sf "$SCRIPT_DIR/tmux.conf.local" "$TMUX_CONFIG_DIR/tmux.conf.local"
echo "✅ Symlinked tmux.conf.local"

# Kill existing tmux server to avoid version mismatch
if tmux list-sessions &>/dev/null 2>&1; then
  echo "⚠️  Existing tmux sessions found. Run 'tmux kill-server' manually to apply changes."
else
  echo "✅ No existing tmux sessions."
fi

echo "🎉 tmux setup complete!"
