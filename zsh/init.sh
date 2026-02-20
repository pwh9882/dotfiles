#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOSTNAME="$(hostname -s)"
LOCAL_FILE="$SCRIPT_DIR/.zshrc.local.$HOSTNAME"

# ---- Install Homebrew if missing ----
if ! command -v brew &>/dev/null; then
    echo "  Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ---- Install Oh My Zsh if missing ----
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "  Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# ---- Install Homebrew packages ----
BREW_PACKAGES=(zsh-autosuggestions zsh-syntax-highlighting starship zoxide lsd)

for pkg in "${BREW_PACKAGES[@]}"; do
    if ! brew list "$pkg" &>/dev/null; then
        echo "  Installing $pkg..."
        brew install "$pkg"
    fi
done

# ---- Symlink shared .zshrc ----
ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
echo "  Linked .zshrc"

# ---- Symlink machine-specific local config ----
if [[ -f "$LOCAL_FILE" ]]; then
    ln -sf "$LOCAL_FILE" "$HOME/.zshrc.local"
    echo "  Linked .zshrc.local -> .zshrc.local.$HOSTNAME"
else
    echo "  ⚠ No local config found for hostname '$HOSTNAME'"
    echo "  Create one at: $SCRIPT_DIR/.zshrc.local.$HOSTNAME"
fi
