# ============================================================
# Shared zsh configuration (common across all machines)
# Machine-specific settings go in .zshrc.local.<hostname>
# ============================================================

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"

plugins=(git)

source $ZSH/oh-my-zsh.sh

# ---- Common Aliases ----
alias v="nvim"
command -v lsd &>/dev/null && alias ls="lsd"
alias l="ls -F"
alias la="ls -A"
alias ll="ls -alhF"
alias tf="terraform"
alias cld="claude"
alias bwu='export BW_SESSION=$(bw unlock --raw)'
alias j="z"

# ---- Common PATH ----
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$HOME/.local/bin:$PATH"

# ---- Shell Integrations ----
# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# zsh plugins (homebrew or system paths)
if command -v brew &>/dev/null; then
    BREW_PREFIX="$(brew --prefix)"
    [[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
        source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    [[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
        source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
else
    [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
        source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
        source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# kiro
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# WezTerm: broadcast host info via user vars on every prompt
# Re-emitting on precmd ensures values reset after exiting SSH
_wezterm_host_b64="$(echo -n "$(hostname -s)" | base64)"
_wezterm_os_b64="$(echo -n "$(uname -s)" | base64)"
_wezterm_set_vars() {
    printf "\033]1337;SetUserVar=%s=%s\007" WEZTERM_HOST "$_wezterm_host_b64"
    printf "\033]1337;SetUserVar=%s=%s\007" WEZTERM_OS "$_wezterm_os_b64"
    printf "\033]1337;SetUserVar=%s=%s\007" WEZTERM_CWD "$(printf '%s' "${PWD/#$HOME/~}" | base64)"
}
precmd_functions+=(_wezterm_set_vars)

# starship prompt
command -v starship &>/dev/null && eval "$(starship init zsh)"

# uv / cargo env
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# True color support
export COLORTERM=truecolor

# Claude Code: use Sonnet instead of Haiku for subagent calls
export ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-sonnet-4-6

# Claude Code: tmux 안에서 24-bit truecolor 강제 활성화
#
# v2.1.78에서 도입된 회귀 — $TMUX 감지 시 chalk.level을 무조건 2(256색)로
# 강제 다운그레이드하는 defensive clamp가 src/ink/colorize.ts의
# clampChalkLevelForTmux()에 추가됨. VS Code/Cursor 등 truecolor 미선언
# 빌트인 터미널의 washed-out 픽스가, 정상 셋업된 WezTerm/Ghostty + tmux
# 사용자까지 전부 다운그레이드시키는 부작용 (mascot이 pink로 보이는 등).
# 이 env가 셋팅돼 있으면 그 clamp 비활성화 → wezterm native와 동일 렌더링.
#
# 미문서화이지만 코드에 명시적으로 존재. 회귀는 #35806에서 OPEN 유지 중,
# 문서화 요청 #46146은 closed 후 docs 미반영. 향후 fix 정식 적용되면 제거.
#   - https://github.com/anthropics/claude-code/issues/35806
#   - https://github.com/anthropics/claude-code/issues/46146
export CLAUDE_CODE_TMUX_TRUECOLOR=1

# ---- Secrets (gitignored, 기기별 민감 환경변수) ----
[[ -f "$HOME/.zshenv.secrets" ]] && source "$HOME/.zshenv.secrets"

# ---- Dotfiles auto-sync (background pull) ----
DOTFILES_DIR="${${(%):-%x}:A:h:h}"
if [[ -d "$DOTFILES_DIR/.git" ]]; then
    git -C "$DOTFILES_DIR" pull --quiet &>/dev/null &!
fi

# ---- Load machine-specific config ----
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# ---- Tailscale CLI Alias (macOS only) ----
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

# ---- SSH_AUTH_SOCK for Bitwarden SSH Agent ----
if grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL2: Windows Bitwarden Desktop → npiperelay + socat bridge
    export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    if ! ss -a 2>/dev/null | grep -q "$SSH_AUTH_SOCK"; then
        rm -f "$SSH_AUTH_SOCK"
        mkdir -p "$HOME/.ssh"
        setsid socat \
            UNIX-LISTEN:"$SSH_AUTH_SOCK",fork \
            EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork &>/dev/null &
    fi
else
    # macOS / Native Linux: Bitwarden Desktop 앱의 SSH Agent 소켓
    export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
fi

# zoxide (must be at the end of .zshrc)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh --cmd cd)"
