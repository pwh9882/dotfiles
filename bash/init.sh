#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOSTNAME="$(hostname -s)"
LOCAL_FILE="$SCRIPT_DIR/.bashrc.local.$HOSTNAME"

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

install_wsl_deps() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "  WSL detected"
        if ! command -v socat &>/dev/null; then
            echo "  Installing socat..."
            sudo apt install -y socat
        fi
        if ! command -v npiperelay.exe &>/dev/null; then
            echo "  Installing npiperelay..."
            if command -v go &>/dev/null; then
                go install github.com/jstarks/npiperelay@latest
            else
                # Download prebuilt binary from GitHub releases
                local tmpdir
                tmpdir=$(mktemp -d)
                echo "  Downloading npiperelay from GitHub releases..."
                curl -sL "https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip" -o "$tmpdir/npiperelay.zip"
                if command -v unzip &>/dev/null; then
                    unzip -q "$tmpdir/npiperelay.zip" -d "$tmpdir"
                    mkdir -p "$HOME/.local/bin"
                    mv "$tmpdir/npiperelay.exe" "$HOME/.local/bin/npiperelay.exe"
                    chmod +x "$HOME/.local/bin/npiperelay.exe"
                    echo "  ✅ npiperelay.exe installed to ~/.local/bin/"
                else
                    echo "  ⚠ unzip not found. Install unzip and retry."
                fi
                rm -rf "$tmpdir"
            fi
        fi
    fi
}

install_starship
install_zoxide
install_lsd
install_wsl_deps

# ---- Symlink shared .bashrc ----
ln -sf "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
echo "  Linked .bashrc"

# ---- Symlink machine-specific local config ----
if [[ -f "$LOCAL_FILE" ]]; then
    ln -sf "$LOCAL_FILE" "$HOME/.bashrc.local"
    echo "  Linked .bashrc.local -> .bashrc.local.$HOSTNAME"
else
    echo "  ⚠ No local config found for hostname '$HOSTNAME'"
    echo "  Create one at: $SCRIPT_DIR/.bashrc.local.$HOSTNAME"
fi
