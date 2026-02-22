#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOSTNAME="$(hostname -s)"
LOCAL_FILE="$SCRIPT_DIR/.zshrc.local.$HOSTNAME"

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

    BREW_PACKAGES=(zsh-autosuggestions zsh-syntax-highlighting starship zoxide lsd)
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
