#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOSTNAME="$(hostname -s)"
LOCAL_FILE="$SCRIPT_DIR/.bashrc.local.$HOSTNAME"

# shellcheck source=../lib/dotfiles/legacy_links.sh
. "$SCRIPT_DIR/../lib/dotfiles/legacy_links.sh"

# Check both HOME destinations before package installation or link writes.
df_legacy_preflight_exact_link "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
df_legacy_preflight_exact_link "$LOCAL_FILE" "$HOME/.bashrc.local"

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

# ---- Create the machine-specific source file when missing ----
if [[ ! -f "$LOCAL_FILE" ]]; then
    echo "  Creating .bashrc.local.$HOSTNAME..."
    cat > "$LOCAL_FILE" <<TMPL
# ============================================================
# Machine-specific config for: $HOSTNAME
# ============================================================

# ---- Linuxbrew (if installed) ----
# if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
#     eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# fi
TMPL
fi

# ---- Link shell configuration ----
df_legacy_link_exact "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc" ".bashrc"
df_legacy_link_exact \
    "$LOCAL_FILE" "$HOME/.bashrc.local" \
    ".bashrc.local -> .bashrc.local.$HOSTNAME"
