# ============================================================
# Shared bash configuration (common across all Linux machines)
# Machine-specific settings go in .bashrc.local.<hostname>
# ============================================================

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ---- History ----
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend

# ---- Shell Options ----
shopt -s checkwinsize
shopt -s globstar 2>/dev/null

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

# starship prompt
command -v starship &>/dev/null && eval "$(starship init bash)"

# zoxide
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

# uv / cargo env
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# True color support
export COLORTERM=truecolor

# ---- Secrets (gitignored, 기기별 민감 환경변수) ----
[[ -f "$HOME/.bashenv.secrets" ]] && source "$HOME/.bashenv.secrets"

# ---- Load machine-specific config ----
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"

# ---- SSH_AUTH_SOCK for Bitwarden SSH Agent ----
if grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL2: Windows Bitwarden Desktop → npiperelay + socat 브릿지
    export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    if ! ss -a 2>/dev/null | grep -q "$SSH_AUTH_SOCK"; then
        rm -f "$SSH_AUTH_SOCK"
        mkdir -p "$HOME/.ssh"
        setsid socat \
            UNIX-LISTEN:"$SSH_AUTH_SOCK",fork \
            EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork &>/dev/null &
    fi
else
    # Native Linux: Bitwarden Desktop 앱의 SSH Agent 소켓
    export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
fi
