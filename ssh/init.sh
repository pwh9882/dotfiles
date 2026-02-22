#!/bin/bash
# SSH 설정 초기화
# - ~/.ssh/sockets 디렉토리 생성
# - config.common을 ~/.ssh/config에 Include
# - WSL2: Bitwarden SSH agent 브릿지 의존성 설치 (socat, npiperelay)

set -euo pipefail

DOTFILES_SSH="$(cd "$(dirname "$0")" && pwd)"
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
INCLUDE_LINE="Include $DOTFILES_SSH/config.common"

mkdir -p "$SSH_DIR/sockets"
chmod 700 "$SSH_DIR"

# ---- SSH config Include ----
if [[ ! -f "$SSH_CONFIG" ]]; then
    echo "$INCLUDE_LINE" > "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    echo "Created $SSH_CONFIG with Include"
elif ! grep -qF "$INCLUDE_LINE" "$SSH_CONFIG" 2>/dev/null; then
    tmpfile=$(mktemp)
    echo "$INCLUDE_LINE" > "$tmpfile"
    echo "" >> "$tmpfile"
    cat "$SSH_CONFIG" >> "$tmpfile"
    mv "$tmpfile" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    echo "Added Include to $SSH_CONFIG"
else
    echo "SSH config.common already included"
fi

# ---- WSL2: Bitwarden SSH agent bridge deps ----
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "  WSL detected — setting up SSH agent bridge deps"

    if ! command -v socat &>/dev/null; then
        echo "  Installing socat..."
        sudo apt-get install -y socat
    fi

    if ! command -v npiperelay.exe &>/dev/null; then
        echo "  Installing npiperelay..."
        if command -v go &>/dev/null; then
            go install github.com/jstarks/npiperelay@latest
        else
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
