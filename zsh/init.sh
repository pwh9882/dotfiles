#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOSTNAME="$(hostname -s)"
LOCAL_FILE="$SCRIPT_DIR/.zshrc.local.$HOSTNAME"
ZSHENV_LOCAL_FILE="$SCRIPT_DIR/.zshenv.local.$HOSTNAME"

# ---- Helper: detect and activate Homebrew ----
setup_brew() {
    command -v brew &>/dev/null && return 0
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    command -v brew &>/dev/null
}

# ---- Install zsh if missing ----
if ! command -v zsh &>/dev/null; then
    echo "  Installing zsh..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y zsh
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm zsh
    else
        echo "  ⚠ Could not install zsh automatically. Please install it manually."
        exit 1
    fi
fi

# ---- Install Oh My Zsh if missing ----
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "  Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# ---- Install packages (platform-specific) ----
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: use Homebrew for everything
    if ! setup_brew; then
        echo "  Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        setup_brew
    fi

    BREW_PACKAGES=(zsh-autosuggestions zsh-syntax-highlighting starship zoxide lsd fzf)
    for pkg in "${BREW_PACKAGES[@]}"; do
        if ! brew list "$pkg" &>/dev/null; then
            echo "  Installing $pkg..."
            brew install "$pkg"
        fi
    done
else
    # Linux: use system package manager + direct installers
    if command -v apt-get &>/dev/null; then
        for pkg in zsh-autosuggestions zsh-syntax-highlighting; do
            if ! dpkg -s "$pkg" &>/dev/null 2>&1; then
                echo "  Installing $pkg..."
                sudo apt-get install -y "$pkg"
            fi
        done
    elif command -v pacman &>/dev/null; then
        for pkg in zsh-autosuggestions zsh-syntax-highlighting; do
            if ! pacman -Qi "$pkg" &>/dev/null 2>&1; then
                echo "  Installing $pkg..."
                sudo pacman -S --noconfirm "$pkg"
            fi
        done
    fi

    # starship (direct installer)
    if ! command -v starship &>/dev/null; then
        echo "  Installing starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi

    # zoxide (direct installer)
    if ! command -v zoxide &>/dev/null; then
        echo "  Installing zoxide..."
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi

    # fzf (required for zoxide interactive mode)
    if ! command -v fzf &>/dev/null; then
        echo "  Installing fzf..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get install -y fzf 2>/dev/null || echo "  ⚠ fzf not available via apt"
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm fzf
        fi
    fi

    # lsd
    if ! command -v lsd &>/dev/null; then
        echo "  Installing lsd..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get install -y lsd 2>/dev/null || echo "  ⚠ lsd not available via apt"
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm lsd
        fi
    fi
fi

# ---- Symlink shared .zshenv (loaded by every zsh invocation) ----
ln -sf "$SCRIPT_DIR/.zshenv" "$HOME/.zshenv"
echo "  Linked .zshenv"

# ---- Symlink machine-specific zsh environment ----
if [[ ! -f "$ZSHENV_LOCAL_FILE" ]]; then
    echo "  Creating .zshenv.local.$HOSTNAME..."
    cat > "$ZSHENV_LOCAL_FILE" <<TMPL
# ============================================================
# Machine-specific zsh environment for: $HOSTNAME
# Loaded by every zsh invocation. Keep this file minimal.
# ============================================================

TMPL
fi
ln -sf "$ZSHENV_LOCAL_FILE" "$HOME/.zshenv.local"
echo "  Linked .zshenv.local -> .zshenv.local.$HOSTNAME"

# ---- Symlink shared .zshrc (before chsh so zsh startup works immediately) ----
ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
echo "  Linked .zshrc"

# ---- Symlink machine-specific local config ----
if [[ ! -f "$LOCAL_FILE" ]]; then
    echo "  Creating .zshrc.local.$HOSTNAME..."
    cat > "$LOCAL_FILE" <<TMPL
# ============================================================
# Machine-specific config for: $HOSTNAME
# ============================================================

DEFAULT_USER=$USER

# ---- Linuxbrew (if installed) ----
# if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
#     eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# fi
TMPL
fi
ln -sf "$LOCAL_FILE" "$HOME/.zshrc.local"
echo "  Linked .zshrc.local -> .zshrc.local.$HOSTNAME"

# ---- Set zsh as default shell (last: chsh may prompt for password) ----
ZSH_PATH="$(which zsh)"
CURRENT_SHELL="$(basename "$SHELL")"
if [[ "$CURRENT_SHELL" != "zsh" ]]; then
    # Ensure zsh is in /etc/shells (required by chsh)
    if ! grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
        echo "  Adding $ZSH_PATH to /etc/shells..."
        echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    fi
    echo "  Changing default shell to zsh..."
    if chsh -s "$ZSH_PATH"; then
        echo "  ✅ Default shell changed to zsh (restart session to apply)"
    elif sudo chsh -s "$ZSH_PATH" "$USER"; then
        # chsh prompts for a password the account may not have (e.g. cloud
        # images where login is key-based). Fall back to sudo, which works
        # whenever the user has passwordless sudo.
        echo "  ✅ Default shell changed to zsh via sudo (restart session to apply)"
    else
        echo "  ⚠ chsh failed. Run manually: sudo chsh -s $ZSH_PATH $USER"
    fi
else
    echo "  ✅ Default shell is already zsh"
fi
