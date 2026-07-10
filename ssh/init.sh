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

    if ! command -v cmd.exe >/dev/null 2>&1; then
        echo "  ERROR: cmd.exe is unavailable; cannot discover the Windows user profile." >&2
        exit 1
    fi
    if ! command -v wslpath >/dev/null 2>&1; then
        echo "  ERROR: wslpath is unavailable; cannot resolve the Windows user profile mount." >&2
        exit 1
    fi
    if [[ ! -d /mnt/c ]]; then
        echo "  ERROR: Windows C: mount is unavailable at /mnt/c." >&2
        exit 1
    fi

    windows_bin_windows=""
    if ! windows_bin_windows="$(cmd.exe /D /C 'echo %USERPROFILE%\bin' 2>/dev/null | tr -d '\r\n')"; then
        echo "  ERROR: cmd.exe could not report %USERPROFILE%\bin." >&2
        exit 1
    fi
    if [[ -z "$windows_bin_windows" || "$windows_bin_windows" == *'%USERPROFILE%'* ]]; then
        echo "  ERROR: Windows user profile discovery returned an invalid path." >&2
        exit 1
    fi

    windows_bin=""
    if ! windows_bin="$(wslpath -u "$windows_bin_windows" 2>/dev/null)"; then
        echo "  ERROR: could not map $windows_bin_windows into WSL." >&2
        exit 1
    fi
    case "$windows_bin" in
        /mnt/c/*) ;;
        *)
            echo "  ERROR: expected the Windows user profile under /mnt/c; resolved $windows_bin." >&2
            exit 1
            ;;
    esac

    npiperelay_target="$windows_bin/npiperelay.exe"
    npiperelay_link="$HOME/.local/bin/npiperelay.exe"

    # Preserve an existing command instead of replacing an unexpected link or
    # regular file. A managed installation always uses this exact link target.
    if [[ -L "$npiperelay_link" ]]; then
        if [[ "$(readlink "$npiperelay_link")" != "$npiperelay_target" ]]; then
            echo "  ERROR: $npiperelay_link points elsewhere; preserving the existing command." >&2
            exit 1
        fi
    elif [[ -e "$npiperelay_link" ]]; then
        echo "  ERROR: $npiperelay_link is not a symlink; preserving the existing command." >&2
        exit 1
    fi

    if [[ ! -f "$npiperelay_target" || -L "$npiperelay_target" || ! -s "$npiperelay_target" ]]; then
        if ! mkdir -p "$windows_bin"; then
            echo "  ERROR: Windows bin directory is unavailable: $windows_bin" >&2
            exit 1
        fi

        echo "  Installing npiperelay v0.1.0 into $windows_bin..."
        if command -v go >/dev/null 2>&1; then
            if ! env GOOS=windows GOARCH=amd64 GOBIN="$windows_bin" \
                go install github.com/jstarks/npiperelay@v0.1.0; then
                echo "  ERROR: failed to cross-compile npiperelay v0.1.0." >&2
                exit 1
            fi
        else
            if ! command -v curl >/dev/null 2>&1; then
                echo "  ERROR: curl is required to download npiperelay v0.1.0." >&2
                exit 1
            fi
            if ! command -v unzip >/dev/null 2>&1; then
                echo "  ERROR: unzip is required to install npiperelay v0.1.0." >&2
                exit 1
            fi
            if ! command -v sha256sum >/dev/null 2>&1; then
                echo "  ERROR: sha256sum is required to verify npiperelay v0.1.0." >&2
                exit 1
            fi

            tmpdir="$(mktemp -d)"
            trap 'rm -rf "$tmpdir"' EXIT
            echo "  Downloading npiperelay v0.1.0 from GitHub releases..."
            if ! curl -fsSL \
                "https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip" \
                -o "$tmpdir/npiperelay.zip"; then
                echo "  ERROR: failed to download npiperelay v0.1.0." >&2
                exit 1
            fi
            npiperelay_sha256="6b9ef61ffd17c03507a9a3d54d815dceb3dae669ac67fc3bf4225d1e764ce5f6"
            if ! printf '%s  %s\n' "$npiperelay_sha256" "$tmpdir/npiperelay.zip" | \
                sha256sum -c - >/dev/null; then
                echo "  ERROR: npiperelay v0.1.0 checksum verification failed." >&2
                exit 1
            fi
            if ! unzip -qo "$tmpdir/npiperelay.zip" -d "$windows_bin"; then
                echo "  ERROR: failed to extract npiperelay into $windows_bin." >&2
                exit 1
            fi
            rm -rf "$tmpdir"
            trap - EXIT
        fi
    else
        echo "  npiperelay.exe already present at $npiperelay_target"
    fi

    if [[ ! -f "$npiperelay_target" || -L "$npiperelay_target" || ! -s "$npiperelay_target" ]]; then
        echo "  ERROR: npiperelay.exe was not created at $npiperelay_target." >&2
        exit 1
    fi

    mkdir -p "$HOME/.local/bin"
    if [[ ! -L "$npiperelay_link" ]]; then
        ln -s "$npiperelay_target" "$npiperelay_link"
    fi
    echo "  ✅ npiperelay.exe available at $npiperelay_link -> $npiperelay_target"
fi
