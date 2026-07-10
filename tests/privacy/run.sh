#!/usr/bin/env bash

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_NUMBER=0
FAILURES=0

pass() {
  TEST_NUMBER=$((TEST_NUMBER + 1))
  printf 'ok %d - %s\n' "$TEST_NUMBER" "$1"
}

fail() {
  TEST_NUMBER=$((TEST_NUMBER + 1))
  FAILURES=$((FAILURES + 1))
  printf 'not ok %d - %s\n' "$TEST_NUMBER" "$1"
}

tracked_match() {
  local pattern="$1"
  shift
  git -C "$ROOT" grep -I -q -E "$pattern" -- "$@"
}

test_profiles_exclude_private_literals() {
  if tracked_match \
    '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}|/Users/[^/[:space:]]+/|vscode-remote://ssh-remote\+[[:alnum:]]|^[[:space:]]*(export[[:space:]]+)?(AWS_PROFILE|DEFAULT_USER)=' \
    'zsh/.zshrc.local.*' '.config/starship.toml'; then
    return 1
  fi
}

test_shared_functions_own_generic_workflows() {
  if tracked_match \
    '^[[:space:]]*(function[[:space:]]+)?(cods|gd)[[:space:]]*\(\)' \
    'zsh/.zshrc.local.*'; then
    return 1
  fi

  grep -Fq 'DOTFILES_CODS_SSH_ALIAS' "$ROOT/zsh/.zshrc" || return 1
  grep -Fq 'DOTFILES_CODS_REMOTE_PATH' "$ROOT/zsh/.zshrc" || return 1
  grep -Fq 'ssh-remote+${ssh_alias}${remote_path}' "$ROOT/zsh/.zshrc" || return 1
  grep -Fq 'DOTFILES_GOOGLE_DRIVE_DIR' "$ROOT/zsh/.zshrc" || return 1
  grep -Fq 'GoogleDrive-*(N/)' "$ROOT/zsh/.zshrc"
}

test_local_values_have_public_onboarding() {
  local doc="$ROOT/docs/runbooks/configure-zsh-local-values.md"
  [ -f "$doc" ] || return 1
  grep -Fq 'DOTFILES_CODS_SSH_ALIAS' "$doc" || return 1
  grep -Fq 'DOTFILES_GOOGLE_DRIVE_DIR' "$doc" || return 1
  grep -Fq 'AWS_PROFILE' "$doc" || return 1
  grep -Fq '~/.zshenv.secrets' "$doc" || return 1
  ! grep -Eq \
    '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}|/Users/[^/[:space:]]+/' \
    "$doc"
}

test_google_drive_command_survives_oh_my_zsh_git_alias() {
  local snippet status

  command -v zsh >/dev/null 2>&1 || return 1
  snippet="$(mktemp "${TMPDIR:-/tmp}/dotfiles-gd-function.XXXXXX")" || return 1
  awk '
    /^# Open the only locally mounted Google Drive/ { capture = 1 }
    /^# starship prompt/ { capture = 0 }
    capture { print }
  ' "$ROOT/zsh/.zshrc" >"$snippet"

  if zsh -fc '
    alias gd="git diff"
    source "$1"
    (( ${+functions[gdrive]} == 1 )) || exit 1
    if [[ "$OSTYPE" == darwin* ]]; then
      [[ "${aliases[gd]-}" == gdrive ]]
    else
      [[ "${aliases[gd]-}" == "git diff" ]]
    fi
  ' _ "$snippet"; then
    status=0
  else
    status=$?
  fi
  /bin/rm -f "$snippet"
  return "$status"
}

printf '1..4\n'

if test_profiles_exclude_private_literals; then
  pass 'tracked Zsh profiles contain no private endpoint or account literals'
else
  fail 'tracked Zsh profiles contain no private endpoint or account literals'
fi

if test_shared_functions_own_generic_workflows; then
  pass 'shared cods and Google Drive workflows use explicit machine-local contracts'
else
  fail 'shared cods and Google Drive workflows use explicit machine-local contracts'
fi

if test_local_values_have_public_onboarding; then
  pass 'machine-local values have public onboarding without private examples'
else
  fail 'machine-local values have public onboarding without private examples'
fi

if test_google_drive_command_survives_oh_my_zsh_git_alias; then
  pass 'Google Drive command handles the Oh My Zsh git alias safely'
else
  fail 'Google Drive command handles the Oh My Zsh git alias safely'
fi

[ "$FAILURES" -eq 0 ]
