# Select the SSH agent without treating every valid Unix socket as equivalent.
# Local macOS prefers Bitwarden, while an SSH session preserves forwarding.

_dotfiles_ssh_agent_policy() {
    local platform="$1"
    local is_remote="$2"
    local current_valid="$3"
    local bitwarden_available="${4:-yes}"

    if [[ "$platform" == darwin* && "$is_remote" == no && "$bitwarden_available" == yes ]]; then
        print -r -- prefer-bitwarden
    elif [[ "$current_valid" == yes ]]; then
        print -r -- preserve-current
    else
        print -r -- find-fallback
    fi
}

_dotfiles_configure_ssh_agent() {
    local is_remote=no
    local current_valid=no
    local bitwarden_available=no
    local policy
    local candidate
    local -a bitwarden_sockets

    [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_CLIENT:-}" ]] && is_remote=yes
    [[ -n "${SSH_AUTH_SOCK:-}" && -S "$SSH_AUTH_SOCK" ]] && current_valid=yes

    bitwarden_sockets=(
        "$HOME/.bitwarden-ssh-agent.sock"
        "$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
    )
    for candidate in "${bitwarden_sockets[@]}"; do
        if [[ -S "$candidate" ]]; then
            bitwarden_available=yes
            break
        fi
    done

    policy="$(_dotfiles_ssh_agent_policy "$OSTYPE" "$is_remote" "$current_valid" "$bitwarden_available")"
    [[ "$policy" == preserve-current ]] && return 0

    if grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL2: Windows Bitwarden Desktop -> npiperelay + socat bridge
        local agent_sock="$HOME/.ssh/agent.sock"
        local agent_live=0
        if [[ -S "$agent_sock" ]]; then
            if command -v ss &>/dev/null; then
                ss -xl 2>/dev/null | grep -F -- "$agent_sock" >/dev/null && agent_live=1
            else
                agent_live=1
            fi
        fi
        if (( ! agent_live )); then
            rm -f "$agent_sock"
            mkdir -p "$HOME/.ssh"
            setsid socat \
                UNIX-LISTEN:"$agent_sock",fork \
                EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork &>/dev/null &
        fi
        export SSH_AUTH_SOCK="$agent_sock"
    elif [[ "$bitwarden_available" == yes ]]; then
        export SSH_AUTH_SOCK="$candidate"
    fi
}

if [[ "${DOTFILES_SSH_AGENT_NO_AUTO:-0}" != 1 ]]; then
    _dotfiles_configure_ssh_agent
    unset -f _dotfiles_configure_ssh_agent _dotfiles_ssh_agent_policy
fi
