# Shared Fish configuration. Machine-specific runtime initialization belongs in
# config.local.fish, which is intentionally ignored by Git.

contains -- "$HOME/.local/bin" $PATH; or set -gx PATH "$HOME/.local/bin" $PATH

set -l dotfiles_fish_local (status dirname)/config.local.fish
test -f "$dotfiles_fish_local"; and source "$dotfiles_fish_local"

command -q starship; and starship init fish | source

if command -q zoxide
    zoxide init fish | source
    alias j z
end

if test "$TERM_PROGRAM" = "kiro"; and command -q kiro
    source (kiro --locate-shell-integration-path fish)
end
