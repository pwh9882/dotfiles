#!/usr/bin/env zsh

set -eu

ROOT="${0:A:h:h:h}"
DOTFILES_SSH_AGENT_NO_AUTO=1 source "$ROOT/zsh/ssh-agent.zsh"

assert_equal() {
    [[ "$1" == "$2" ]] || {
        print -u2 "expected [$1], got [$2]"
        return 1
    }
}

assert_equal prefer-bitwarden "$(_dotfiles_ssh_agent_policy darwin25.0 no yes)"
print 'ok - local macOS prefers Bitwarden over a valid inherited agent'

assert_equal preserve-current "$(_dotfiles_ssh_agent_policy darwin25.0 yes yes)"
print 'ok - remote macOS preserves a valid forwarded agent'

assert_equal preserve-current "$(_dotfiles_ssh_agent_policy darwin25.0 no yes no)"
print 'ok - local macOS preserves its current agent when Bitwarden is absent'

assert_equal find-fallback "$(_dotfiles_ssh_agent_policy linux-gnu no no)"
print 'ok - a missing or stale agent uses the platform fallback'
