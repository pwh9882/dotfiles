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
# Preserve a valid forwarded or user-provided agent. Fall back to a local
# Bitwarden socket only when the current socket is absent or stale.
if [[ -z "${SSH_AUTH_SOCK:-}" || ! -S "$SSH_AUTH_SOCK" ]]; then
    if grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL2: Windows Bitwarden Desktop → npiperelay + socat bridge
        _dotfiles_agent_sock="$HOME/.ssh/agent.sock"
        _dotfiles_agent_live=0
        if [[ -S "$_dotfiles_agent_sock" ]]; then
            if command -v ss &>/dev/null; then
                if ss -xl 2>/dev/null | grep -F -- "$_dotfiles_agent_sock" >/dev/null; then
                    _dotfiles_agent_live=1
                fi
            else
                _dotfiles_agent_live=1
            fi
        fi
        if [[ "$_dotfiles_agent_live" -ne 1 ]]; then
            rm -f "$_dotfiles_agent_sock"
            mkdir -p "$HOME/.ssh"
            setsid socat \
                UNIX-LISTEN:"$_dotfiles_agent_sock",fork \
                EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork &>/dev/null &
        fi
        export SSH_AUTH_SOCK="$_dotfiles_agent_sock"
    else
        for _dotfiles_agent_sock in \
            "$HOME/.bitwarden-ssh-agent.sock" \
            "$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
        do
            if [[ -S "$_dotfiles_agent_sock" ]]; then
                export SSH_AUTH_SOCK="$_dotfiles_agent_sock"
                break
            fi
        done
    fi
fi
unset _dotfiles_agent_sock _dotfiles_agent_live
