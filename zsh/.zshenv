# Always loaded by zsh, including non-interactive SSH commands.
# Keep this file minimal: PATH and environment only, no output.
path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) export PATH="$1:$PATH" ;;
    esac
}

path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.npm-global/bin"
unfunction path_prepend

# Silence zoxide doctor false-positive in shells that source .zshrc but don't
# persist chpwd_functions (e.g. Claude Code's command shell).
export _ZO_DOCTOR=0

[[ -f "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"
