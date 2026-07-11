# ============================================================
# Shared zsh configuration (common across all machines)
# Machine-specific settings go in .zshrc.local.<hostname>
# ============================================================

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # Prompt is managed by starship.

plugins=(
    git
    colored-man-pages
    command-not-found
    sudo
)

# Completion styles
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
[[ -n "$LS_COLORS" ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

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
alias j="cd"

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
else
    [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
        source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# nvm (Node Version Manager) — loads node/npm if ~/.nvm is present
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

# kiro
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# WezTerm: broadcast host info via user vars on every prompt
# Re-emitting on precmd ensures values reset after exiting SSH
_wezterm_host_b64="$(echo -n "$(hostname -s)" | base64)"
_wezterm_os_b64="$(echo -n "$(uname -s)" | base64)"

# OSC 1337 SetUserVar 방출. tmux는 모르는 OSC를 삼키므로 tmux 안에서는
# DCS passthrough(ESC Ptmux; …)로 감싸야 바깥 터미널까지 도달한다
# (tmux.conf.local의 allow-passthrough on과 세트. 원격 tmux에 직접 attach해도
#  원격 셸의 user var가 ssh 너머 WezTerm까지 전달되게 하는 핵심)
# BEL(\007) 종결이라 내용물의 ESC는 선두 1개뿐 → 그것만 이중화하면 된다
_wezterm_user_var() {
    local osc
    osc="$(printf '\033]1337;SetUserVar=%s=%s\007' "$1" "$2")"
    if [[ -n "$TMUX" ]]; then
        printf '\033Ptmux;\033%s\033\\' "$osc"
    else
        printf '%s' "$osc"
    fi
}

_wezterm_set_vars() {
    # SSH/tmux/TUI sessions can disconnect before disabling terminal mouse modes.
    # Reset them at the shell prompt so mouse movement/scroll does not leak as input.
    printf "\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?1015l"
    _wezterm_user_var WEZTERM_HOST "$_wezterm_host_b64"
    _wezterm_user_var WEZTERM_OS "$_wezterm_os_b64"
    _wezterm_user_var WEZTERM_CWD "$(printf '%s' "${PWD/#$HOME/~}" | base64)"
}
precmd_functions+=(_wezterm_set_vars)

alias fixmouse='printf "\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?1015l"'

# ssht [ssh-options] <host>: ssh 접속과 동시에 원격 tmux attach (없으면 생성)
ssht() {
    if (( $# == 0 )); then
        print -u2 "usage: ssht [ssh-options] <host>"
        return 2
    fi
    # WezTerm 상태바가 즉시 원격 host를 표시하도록 접속 전에 로컬에서 방출.
    # 원격이 stock tmux(set-titles off)면 title/user var 어느 쪽 신호도 없다.
    # stale한 로컬 OS/CWD가 원격 것으로 오인되지 않게 비우고, ssh 종료 후에는
    # precmd가 로컬 값을 재방출하며 원상복구된다.
    _wezterm_user_var WEZTERM_HOST "$(printf '%s' "${${@[-1]}##*@}" | base64)"
    _wezterm_user_var WEZTERM_OS ""
    _wezterm_user_var WEZTERM_CWD ""
    local remote_command=$'exec "${SHELL:-/bin/sh}" -lic \'if command -v tmux >/dev/null 2>&1; then tmux attach || tmux new; else echo "ssht: tmux not found on remote host" >&2; exit 127; fi\''
    command ssh -t "$@" "$remote_command"
}
compdef _ssh ssht 2>/dev/null

# cods <ssh-alias> [remote-path]
# cods [remote-path]
#   Uses DOTFILES_CODS_SSH_ALIAS when the first argument is an absolute path.
#
# Keep the alias (rather than a hostname) in ~/.zshenv.secrets. The URI is
# passed as one argument, so paths containing spaces are preserved.
cods() {
    local ssh_alias remote_path

    if (( $# > 2 )); then
        print -u2 "usage: cods [ssh-alias] [remote-path]"
        return 2
    fi

    ssh_alias="${DOTFILES_CODS_SSH_ALIAS:-}"
    remote_path="${DOTFILES_CODS_REMOTE_PATH:-/}"
    if (( $# == 1 )); then
        if [[ "$1" == /* ]]; then
            remote_path="$1"
        else
            ssh_alias="$1"
        fi
    elif (( $# == 2 )); then
        ssh_alias="$1"
        remote_path="$2"
    fi

    if [[ -z "$ssh_alias" ]]; then
        print -u2 "cods: pass an SSH alias or set DOTFILES_CODS_SSH_ALIAS in ~/.zshenv.secrets"
        return 2
    fi

    case "$ssh_alias" in
        *[!A-Za-z0-9._-]*)
            print -u2 "cods: SSH alias may contain only letters, digits, dot, underscore, and hyphen"
            return 2
            ;;
    esac
    if [[ "$remote_path" != /* ]]; then
        print -u2 "cods: remote path must be absolute: $remote_path"
        return 2
    fi
    if ! command -v code &>/dev/null; then
        print -u2 "cods: VS Code CLI 'code' was not found"
        return 127
    fi

    command code --folder-uri "vscode-remote://ssh-remote+${ssh_alias}${remote_path}"
}

# Open the only locally mounted Google Drive. A machine with multiple Drive
# accounts can select one explicitly with DOTFILES_GOOGLE_DRIVE_DIR.
gdrive() {
    local drive_root account
    local -a accounts

    if (( $# != 0 )); then
        print -u2 "usage: gd"
        return 2
    fi

    if [[ -n "${DOTFILES_GOOGLE_DRIVE_DIR:-}" ]]; then
        drive_root="$DOTFILES_GOOGLE_DRIVE_DIR"
    else
        accounts=("$HOME/Library/CloudStorage"/GoogleDrive-*(N/))
        case ${#accounts[@]} in
            0)
                print -u2 "gd: no Google Drive mount found under ~/Library/CloudStorage"
                return 1
                ;;
            1)
                account="${accounts[1]%/}"
                ;;
            *)
                print -u2 "gd: multiple Google Drive mounts found; set DOTFILES_GOOGLE_DRIVE_DIR"
                return 1
                ;;
        esac

        if [[ -d "$account/My Drive" ]]; then
            drive_root="$account/My Drive"
        elif [[ -d "$account/내 드라이브" ]]; then
            drive_root="$account/내 드라이브"
        else
            drive_root="$account"
        fi
    fi

    if [[ ! -d "$drive_root" ]]; then
        print -u2 "gd: directory does not exist: $drive_root"
        return 1
    fi
    builtin cd -- "$drive_root"
}

# Oh My Zsh's git plugin owns `gd` by default. macOS profiles have long used
# that name for Google Drive; replace it only where the Drive mount exists.
# Other platforms keep the plugin's `gd='git diff'` alias.
if [[ "$OSTYPE" == darwin* ]]; then
    alias gd='gdrive'
fi

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

# ---- Dotfiles update availability (background fetch, explicit pull) ----
DOTFILES_DIR="${${(%):-%x}:A:h:h}"
[[ -r "$DOTFILES_DIR/zsh/update-check.zsh" ]] && source "$DOTFILES_DIR/zsh/update-check.zsh"

# ---- Load machine-specific config ----
_dotfiles_zsh_local="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/zsh.local"
if [[ -r "$_dotfiles_zsh_local" ]]; then
    source "$_dotfiles_zsh_local"
elif [[ -r "$HOME/.zshrc.local" ]]; then
    # Migration fallback for machines that have not rerun zsh/init.sh yet.
    source "$HOME/.zshrc.local"
fi
unset _dotfiles_zsh_local

# ---- Tailscale CLI Alias (macOS only) ----
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

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
                ss -xl 2>/dev/null | grep -F -- "$_dotfiles_agent_sock" >/dev/null && _dotfiles_agent_live=1
            else
                _dotfiles_agent_live=1
            fi
        fi
        if (( ! _dotfiles_agent_live )); then
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

# zoxide replaces cd with its smart jump; j is an alias for the same thing.
command -v zoxide &>/dev/null && eval "$(zoxide init zsh --cmd cd)"

# zsh-syntax-highlighting should be sourced last.
if [[ -n "$BREW_PREFIX" && -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi


# OpenClaw Completion
[ -f "$HOME/.openclaw/completions/openclaw.zsh" ] && source "$HOME/.openclaw/completions/openclaw.zsh"
