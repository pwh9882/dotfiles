#!/bin/bash
# SSH 공통 설정 초기화
# - ~/.ssh/sockets 디렉토리 생성
# - config.common을 ~/.ssh/config에 Include

set -euo pipefail

DOTFILES_SSH="$(cd "$(dirname "$0")" && pwd)"
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
INCLUDE_LINE="Include $DOTFILES_SSH/config.common"

mkdir -p "$SSH_DIR/sockets"
chmod 700 "$SSH_DIR"

# ~/.ssh/config가 없으면 생성
if [[ ! -f "$SSH_CONFIG" ]]; then
    echo "$INCLUDE_LINE" > "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    echo "Created $SSH_CONFIG with Include"
    exit 0
fi

# 이미 Include 되어있으면 스킵
if grep -qF "$INCLUDE_LINE" "$SSH_CONFIG" 2>/dev/null; then
    echo "SSH config.common already included"
    exit 0
fi

# config 최상단에 Include 추가 (Include는 맨 위에 있어야 함)
tmpfile=$(mktemp)
echo "$INCLUDE_LINE" > "$tmpfile"
echo "" >> "$tmpfile"
cat "$SSH_CONFIG" >> "$tmpfile"
mv "$tmpfile" "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"
echo "Added Include to $SSH_CONFIG"
