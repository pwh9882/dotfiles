#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
LOCAL_FILE="$LOCAL_CONFIG_DIR/zsh.local"
ZSHENV_LOCAL_FILE="$LOCAL_CONFIG_DIR/zshenv.local"

# shellcheck source=../lib/dotfiles/legacy_links.sh
. "$SCRIPT_DIR/../lib/dotfiles/legacy_links.sh"
# shellcheck source=../lib/dotfiles/local_adapter.sh
. "$SCRIPT_DIR/../lib/dotfiles/local_adapter.sh"

# Validate every managed HOME link before package installation or file writes.
# The legacy init is not transactional, so a conflict stops the whole link
# phase before an earlier destination is changed.
df_legacy_preflight_exact_link "$SCRIPT_DIR/.zshenv" "$HOME/.zshenv"
df_legacy_preflight_exact_link "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
df_local_adapter_preflight_dir "${LOCAL_CONFIG_DIR%/*}"
df_local_adapter_preflight_dir "$LOCAL_CONFIG_DIR"
df_local_adapter_preflight_file "$ZSHENV_LOCAL_FILE"
df_local_adapter_preflight_file "$LOCAL_FILE"

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

# ---- Create or migrate user-owned machine-local source files ----
mkdir -p "$LOCAL_CONFIG_DIR"
chmod 700 "$LOCAL_CONFIG_DIR"
umask 077
if [[ ! -e "$ZSHENV_LOCAL_FILE" && ! -L "$ZSHENV_LOCAL_FILE" ]]; then
    if [[ -r "$HOME/.zshenv.local" ]]; then
        cp "$HOME/.zshenv.local" "$ZSHENV_LOCAL_FILE"
        echo "  Migrated ~/.zshenv.local -> $ZSHENV_LOCAL_FILE"
    else
        printf '%s\n' '# Machine-local zsh environment. Keep this file minimal.' > "$ZSHENV_LOCAL_FILE"
        echo "  Created $ZSHENV_LOCAL_FILE"
    fi
    chmod 600 "$ZSHENV_LOCAL_FILE"
fi
if [[ ! -e "$LOCAL_FILE" && ! -L "$LOCAL_FILE" ]]; then
    if [[ -r "$HOME/.zshrc.local" ]]; then
        cp "$HOME/.zshrc.local" "$LOCAL_FILE"
        echo "  Migrated ~/.zshrc.local -> $LOCAL_FILE"
    else
        printf '%s\n' '# Machine-local interactive zsh configuration.' > "$LOCAL_FILE"
        echo "  Created $LOCAL_FILE"
    fi
    chmod 600 "$LOCAL_FILE"
fi

# ---- Link shell configuration (before chsh) ----
df_legacy_link_exact "$SCRIPT_DIR/.zshenv" "$HOME/.zshenv" ".zshenv"
df_legacy_link_exact "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc" ".zshrc"

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
