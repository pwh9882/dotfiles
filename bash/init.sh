#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
LOCAL_FILE="$LOCAL_CONFIG_DIR/bash.local"

# shellcheck source=../lib/dotfiles/legacy_links.sh
. "$SCRIPT_DIR/../lib/dotfiles/legacy_links.sh"

# Check the managed HOME destination before package installation or link writes.
df_legacy_preflight_exact_link "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"

# ---- Install packages ----
install_starship() {
    if ! command -v starship &>/dev/null; then
        echo "  Installing starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi
}

install_zoxide() {
    if ! command -v zoxide &>/dev/null; then
        echo "  Installing zoxide..."
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi
}

install_lsd() {
    if ! command -v lsd &>/dev/null; then
        echo "  Installing lsd..."
        if command -v apt &>/dev/null; then
            sudo apt install -y lsd 2>/dev/null || {
                # Ubuntu < 23.04: apt에 lsd 없을 수 있음
                echo "  lsd not in apt, installing via cargo..."
                command -v cargo &>/dev/null && cargo install lsd || echo "  ⚠ cargo not found, skipping lsd"
            }
        fi
    fi
}

install_starship
install_zoxide
install_lsd

# ---- Create or migrate the user-owned machine-local source file ----
mkdir -p "$LOCAL_CONFIG_DIR"
chmod 700 "$LOCAL_CONFIG_DIR"
umask 077
if [[ ! -e "$LOCAL_FILE" && ! -L "$LOCAL_FILE" ]]; then
    if [[ -r "$HOME/.bashrc.local" ]]; then
        cp "$HOME/.bashrc.local" "$LOCAL_FILE"
        echo "  Migrated ~/.bashrc.local -> $LOCAL_FILE"
    else
        printf '%s\n' '# Machine-local interactive bash configuration.' > "$LOCAL_FILE"
        echo "  Created $LOCAL_FILE"
    fi
    chmod 600 "$LOCAL_FILE"
fi

# ---- Link shell configuration ----
df_legacy_link_exact "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc" ".bashrc"
