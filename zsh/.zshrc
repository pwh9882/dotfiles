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

# WezTerm: broadcast hostname as user var for tab badge coloring
if [[ -n "$WEZTERM_EXECUTABLE" ]]; then
    printf "\033]1337;SetUserVar=%s=%s\007" WEZTERM_HOST "$(echo -n "$(hostname -s)" | base64)"
fi

# starship prompt
command -v starship &>/dev/null && eval "$(starship init zsh)"

# zoxide
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# uv / cargo env
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# True color support
export COLORTERM=truecolor

# ---- Secrets (gitignored, 기기별 민감 환경변수) ----
[[ -f "$HOME/.zshenv.secrets" ]] && source "$HOME/.zshenv.secrets"

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
