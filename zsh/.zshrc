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
alias ls="lsd"
alias ll="ls -alhF"
alias tf="terraform"
alias cld="claude"
alias ytd='yt-dlp --cookies-from-browser safari -f "bv*[height<=1080][vcodec^=avc1][ext=mp4]+ba[ext=m4a]/mp4" -o "%(title)s.%(ext)s"'
alias j="z"

# ---- Common PATH ----
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$HOME/.local/bin:$PATH"

# ---- Shell Integrations ----
# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# zsh plugins via homebrew
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# iterm2
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# kiro
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# starship prompt
eval "$(starship init zsh)"

# zoxide
eval "$(zoxide init zsh)"

# uv / cargo env
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# True color support
export COLORTERM=truecolor

# ---- Secrets (gitignored, 기기별 민감 환경변수) ----
[[ -f "$HOME/.zshenv.secrets" ]] && source "$HOME/.zshenv.secrets"

# ---- Load machine-specific config ----
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# ---- Tailscale CLI Alias ----
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# ---- SSH_AUTH_SOCK for Bitwarden SSH Agent ----
# Bitwarden Desktop 앱의 SSH Agent 소켓 (dmg 설치 기준)
# App Store 설치: $HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
