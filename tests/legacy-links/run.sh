#!/usr/bin/env bash

# Focused integration tests for fail-closed legacy init links. Every script is
# copied into a fixture repository, and every write stays under a temporary
# HOME. Package and platform commands are replaced with local stubs.

set -u

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORIGINAL_TMPDIR="${TMPDIR:-/tmp}"
TMP_BASE="${ORIGINAL_TMPDIR%/}"
REAL_HOME="${HOME:-}"
TEST_NUMBER=0
FAILURES=0

SUITE_ROOT="$(mktemp -d "$TMP_BASE/dotfiles-legacy-link-tests.XXXXXX")" || exit 1
SUITE_ROOT="$(cd "$SUITE_ROOT" && pwd)"

cleanup() {
  case "$SUITE_ROOT" in
    "$TMP_BASE"/dotfiles-legacy-link-tests.*) /bin/rm -rf "$SUITE_ROOT" ;;
    *) printf 'Refusing to remove unexpected test path: %s\n' "$SUITE_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf '  assertion failed: %s\n' "$1" >&2
  if [[ -f "${CASE_OUT:-}" ]]; then
    printf '  stdout:\n' >&2
    sed 's/^/    /' "$CASE_OUT" >&2
  fi
  if [[ -f "${CASE_ERR:-}" ]]; then
    printf '  stderr:\n' >&2
    sed 's/^/    /' "$CASE_ERR" >&2
  fi
  exit 1
}

assert_success() {
  [[ "$COMMAND_STATUS" -eq 0 ]] || fail "command exited $COMMAND_STATUS, expected success"
}

assert_failure() {
  [[ "$COMMAND_STATUS" -ne 0 ]] || fail 'command succeeded, expected failure'
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "path unexpectedly exists: $1"
}

assert_symlink() {
  local destination="$1"
  local source="$2"
  [[ -L "$destination" ]] || fail "not a symlink: $destination"
  [[ "$(readlink "$destination")" == "$source" ]] || {
    fail "unexpected target for $destination: $(readlink "$destination")"
  }
}

assert_regular_file() {
  [[ -f "$1" && ! -L "$1" ]] || fail "not a regular file: $1"
}

assert_error_contains() {
  case "$(cat "$CASE_ERR")" in
    *"$1"*) ;;
    *) fail "stderr does not contain [$1]" ;;
  esac
}

assert_file_line() {
  local expected="$1"
  local path="$2"
  [[ "$(sed -n '1p' "$path")" == "$expected" ]] || {
    fail "unexpected first line in $path"
  }
}

write_stub() {
  local name="$1"
  shift
  {
    printf '%s\n' '#!/bin/sh'
    printf '%s\n' "$@"
  } >"$CASE_FAKE_BIN/$name"
  chmod 0755 "$CASE_FAKE_BIN/$name"
}

new_case() {
  local dir

  CASE_ROOT="$SUITE_ROOT/case-$TEST_NUMBER"
  CASE_HOME="$CASE_ROOT/home with spaces"
  CASE_REPO="$CASE_ROOT/repo with spaces"
  CASE_CONFIG="$CASE_HOME/config with spaces"
  CASE_DATA="$CASE_HOME/data with spaces"
  CASE_FAKE_BIN="$CASE_ROOT/fake bin"
  CASE_TMP="$CASE_ROOT/tmp with spaces"
  CASE_OUT="$CASE_ROOT/stdout"
  CASE_ERR="$CASE_ROOT/stderr"
  COMMAND_STATUS=0

  mkdir -p \
    "$CASE_HOME/.oh-my-zsh" "$CASE_FAKE_BIN" "$CASE_TMP" \
    "$CASE_REPO/zsh" "$CASE_REPO/bash" "$CASE_REPO/tmux" "$CASE_REPO/claude" \
    "$CASE_REPO/.config/zed" "$CASE_REPO/lib/dotfiles"

  cp "$ROOT/zsh/init.sh" "$CASE_REPO/zsh/init.sh"
  cp "$ROOT/zsh/.zshenv" "$CASE_REPO/zsh/.zshenv"
  cp "$ROOT/zsh/.zshrc" "$CASE_REPO/zsh/.zshrc"
  cp "$ROOT/bash/init.sh" "$CASE_REPO/bash/init.sh"
  cp "$ROOT/bash/.bashrc" "$CASE_REPO/bash/.bashrc"
  cp "$ROOT/tmux/init.sh" "$CASE_REPO/tmux/init.sh"
  cp "$ROOT/tmux/tmux.conf.local" "$CASE_REPO/tmux/tmux.conf.local"
  cp "$ROOT/claude/init.sh" "$CASE_REPO/claude/init.sh"
  cp "$ROOT/claude/statusline-command.sh" "$CASE_REPO/claude/statusline-command.sh"
  cp "$ROOT/.config/init.sh" "$CASE_REPO/.config/init.sh"
  cp "$ROOT/lib/dotfiles/legacy_links.sh" "$CASE_REPO/lib/dotfiles/legacy_links.sh"
  cp "$ROOT/lib/dotfiles/local_adapter.sh" "$CASE_REPO/lib/dotfiles/local_adapter.sh"

  for dir in wezterm nvim fish neofetch ghostty; do
    mkdir -p "$CASE_REPO/.config/$dir"
  done
  printf '%s\n' 'scan_timeout = 30' >"$CASE_REPO/.config/starship.toml"
  printf '%s\n' '{ "theme": "fixture" }' >"$CASE_REPO/.config/zed/settings.json"
  {
    printf '%s\n' '#!/bin/bash'
    printf '%s\n' "printf '\\noverride = true\\n' >> \"\$1\""
  } >"$CASE_REPO/.config/starship.overrides.linux.sh"

  write_stub hostname 'printf "%s\n" fixture'
  write_stub uname 'printf "%s\n" Linux'
  write_stub zsh 'exit 0'
  write_stub starship 'exit 0'
  write_stub zoxide 'exit 0'
  write_stub lsd 'exit 0'
  write_stub fzf 'exit 0'
  write_stub apt-get 'exit 0'
  write_stub dpkg 'exit 0'
  write_stub brew 'exit 0'

  [[ -n "$REAL_HOME" ]] || fail 'real HOME is empty'
  [[ "$CASE_HOME" != "$REAL_HOME" ]] || fail 'temporary HOME equals real HOME'
  case "$CASE_HOME" in
    "$SUITE_ROOT"/*) ;;
    *) fail 'temporary HOME escaped the suite root' ;;
  esac
}

run_init() {
  local module="$1"
  local ostype="$2"
  local script

  case "$module" in
    zsh) script="$CASE_REPO/zsh/init.sh" ;;
    bash) script="$CASE_REPO/bash/init.sh" ;;
    config) script="$CASE_REPO/.config/init.sh" ;;
    tmux) script="$CASE_REPO/tmux/init.sh" ;;
    claude) script="$CASE_REPO/claude/init.sh" ;;
    *) fail "unknown fixture module: $module" ;;
  esac

  : >"$CASE_OUT"
  : >"$CASE_ERR"
  if (
    export HOME="$CASE_HOME"
    export XDG_CONFIG_HOME="$CASE_CONFIG"
    export XDG_DATA_HOME="$CASE_DATA"
    export TMPDIR="$CASE_TMP"
    export PATH="$CASE_FAKE_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
    export OSTYPE="$ostype"
    export SHELL="$CASE_FAKE_BIN/zsh"
    export USER=fixture
    export LC_ALL=C
    /bin/bash "$script"
  ) >"$CASE_OUT" 2>"$CASE_ERR"; then
    COMMAND_STATUS=0
  else
    COMMAND_STATUS=$?
  fi
}

test_zsh_absent_and_expected_links_are_idempotent() {
  new_case
  run_init zsh linux-gnu
  assert_success
  assert_symlink "$CASE_HOME/.zshenv" "$CASE_REPO/zsh/.zshenv"
  assert_symlink "$CASE_HOME/.zshrc" "$CASE_REPO/zsh/.zshrc"
  assert_regular_file "$CASE_CONFIG/dotfiles/zshenv.local"
  assert_regular_file "$CASE_CONFIG/dotfiles/zsh.local"
  assert_absent "$CASE_HOME/.zshenv.local"
  assert_absent "$CASE_HOME/.zshrc.local"

  run_init zsh linux-gnu
  assert_success
  assert_symlink "$CASE_HOME/.zshrc" "$CASE_REPO/zsh/.zshrc"
}

test_zsh_regular_conflict_stops_before_any_link_or_source_write() {
  new_case
  printf '%s\n' 'private zshrc' >"$CASE_HOME/.zshrc"

  run_init zsh linux-gnu
  assert_failure
  assert_file_line 'private zshrc' "$CASE_HOME/.zshrc"
  assert_absent "$CASE_HOME/.zshenv"
  assert_absent "$CASE_HOME/.zshenv.local"
  assert_absent "$CASE_HOME/.zshrc.local"
  assert_absent "$CASE_CONFIG/dotfiles"
}

test_bash_absent_and_expected_links_are_idempotent() {
  new_case
  run_init bash linux-gnu
  assert_success
  assert_symlink "$CASE_HOME/.bashrc" "$CASE_REPO/bash/.bashrc"
  assert_regular_file "$CASE_CONFIG/dotfiles/bash.local"
  assert_absent "$CASE_HOME/.bashrc.local"

  run_init bash linux-gnu
  assert_success
  assert_regular_file "$CASE_CONFIG/dotfiles/bash.local"
}

test_bash_legacy_local_is_migrated_without_replacing_it() {
  local other
  new_case
  other="$CASE_HOME/other bashrc"
  printf '%s\n' 'private target' >"$other"
  ln -s "$other" "$CASE_HOME/.bashrc.local"

  run_init bash linux-gnu
  assert_success
  assert_symlink "$CASE_HOME/.bashrc" "$CASE_REPO/bash/.bashrc"
  assert_symlink "$CASE_HOME/.bashrc.local" "$other"
  assert_file_line 'private target' "$other"
  assert_file_line 'private target' "$CASE_CONFIG/dotfiles/bash.local"
}

test_zsh_invalid_local_adapter_stops_before_shared_links() {
  new_case
  mkdir -p "$CASE_CONFIG/dotfiles/zsh.local"

  run_init zsh linux-gnu
  assert_failure
  assert_error_contains 'Local Adapter must be a readable regular file'
  assert_absent "$CASE_HOME/.zshenv"
  assert_absent "$CASE_HOME/.zshrc"
}

test_bash_broken_local_adapter_symlink_stops_before_shared_link() {
  new_case
  mkdir -p "$CASE_CONFIG/dotfiles"
  ln -s "$CASE_ROOT/missing-local-file" "$CASE_CONFIG/dotfiles/bash.local"

  run_init bash linux-gnu
  assert_failure
  assert_error_contains 'Local Adapter symlink must resolve to a readable regular file'
  assert_absent "$CASE_HOME/.bashrc"
}

test_zsh_invalid_xdg_config_parent_stops_before_shared_links() {
  new_case
  printf 'not a directory\n' > "$CASE_CONFIG"

  run_init zsh linux-gnu
  assert_failure
  assert_error_contains 'Local Adapter directory is invalid'
  assert_absent "$CASE_HOME/.zshenv"
  assert_absent "$CASE_HOME/.zshrc"
}

test_config_default_links_are_exact_and_idempotent() {
  new_case
  run_init config darwin23
  assert_success
  assert_symlink "$CASE_CONFIG/wezterm" "$CASE_REPO/.config/wezterm"
  assert_symlink "$CASE_CONFIG/starship.toml" "$CASE_REPO/.config/starship.toml"
  assert_symlink "$CASE_CONFIG/zed/settings.json" "$CASE_REPO/.config/zed/settings.json"

  run_init config darwin23
  assert_success
  assert_symlink "$CASE_CONFIG/starship.toml" "$CASE_REPO/.config/starship.toml"
}

test_zed_private_settings_are_preserved_before_other_config_writes() {
  new_case
  mkdir -p "$CASE_CONFIG/zed"
  printf '%s\n' '{ "private": true }' >"$CASE_CONFIG/zed/settings.json"

  run_init config darwin23
  assert_failure
  assert_file_line '{ "private": true }' "$CASE_CONFIG/zed/settings.json"
  assert_absent "$CASE_CONFIG/wezterm"
  assert_absent "$CASE_CONFIG/starship.toml"
  assert_error_contains 'merge shared values'
  assert_error_contains 'this init will not replace it'
}

test_default_starship_conflict_is_preserved_before_other_config_writes() {
  new_case
  mkdir -p "$CASE_CONFIG"
  printf '%s\n' 'private starship' >"$CASE_CONFIG/starship.toml"

  run_init config darwin23
  assert_failure
  assert_file_line 'private starship' "$CASE_CONFIG/starship.toml"
  assert_absent "$CASE_CONFIG/wezterm"
  assert_absent "$CASE_CONFIG/zed"
}

test_starship_override_marker_is_idempotent_and_failure_is_atomic() {
  new_case
  run_init config linux-gnu
  assert_success
  [[ -f "$CASE_CONFIG/starship.toml" && ! -L "$CASE_CONFIG/starship.toml" ]] || {
    fail 'override result is not a regular file'
  }
  assert_file_line \
    '# dotfiles-managed:starship-override=starship.overrides.linux.sh' \
    "$CASE_CONFIG/starship.toml"
  grep -Fq 'override = true' "$CASE_CONFIG/starship.toml" || fail 'override was not applied'
  cp "$CASE_CONFIG/starship.toml" "$CASE_ROOT/starship-before"

  run_init config linux-gnu
  assert_success
  cmp -s "$CASE_ROOT/starship-before" "$CASE_CONFIG/starship.toml" || {
    fail 'idempotent override changed output bytes'
  }

  {
    printf '%s\n' '#!/bin/bash'
    printf '%s\n' 'printf "partial\n" >> "$1"'
    printf '%s\n' 'exit 17'
  } >"$CASE_REPO/.config/starship.overrides.linux.sh"
  run_init config linux-gnu
  assert_failure
  cmp -s "$CASE_ROOT/starship-before" "$CASE_CONFIG/starship.toml" || {
    fail 'failed override replaced the previous managed file'
  }
}

test_unmarked_starship_override_conflict_is_preserved() {
  new_case
  mkdir -p "$CASE_CONFIG"
  printf '%s\n' '# user-managed starship' >"$CASE_CONFIG/starship.toml"

  run_init config linux-gnu
  assert_failure
  assert_file_line '# user-managed starship' "$CASE_CONFIG/starship.toml"
  assert_absent "$CASE_CONFIG/wezterm"
  assert_error_contains 'Expected first line'
}

test_tmux_conflict_stops_before_clone_or_other_link() {
  new_case
  mkdir -p "$CASE_CONFIG/tmux"
  printf '%s\n' 'private tmux config' >"$CASE_CONFIG/tmux/tmux.conf"

  run_init tmux linux-gnu
  assert_failure
  assert_file_line 'private tmux config' "$CASE_CONFIG/tmux/tmux.conf"
  assert_absent "$CASE_CONFIG/tmux/tmux.conf.local"
  assert_absent "$CASE_DATA/tmux/oh-my-tmux"
}

test_claude_conflict_stops_before_settings_write() {
  new_case
  mkdir -p "$CASE_HOME/.claude"
  printf '%s\n' 'private statusline' >"$CASE_HOME/.claude/statusline-command.sh"
  printf '%s\n' '{ "private": true }' >"$CASE_HOME/.claude/settings.json"

  run_init claude linux-gnu
  assert_failure
  assert_file_line 'private statusline' "$CASE_HOME/.claude/statusline-command.sh"
  assert_file_line '{ "private": true }' "$CASE_HOME/.claude/settings.json"
}

test_claude_failed_generation_preserves_settings_atomically() {
  new_case
  mkdir -p "$CASE_HOME/.claude"
  printf '%s\n' '{ "private": true }' >"$CASE_HOME/.claude/settings.json"
  write_stub jq 'printf "%s\\n" "partial output"' 'exit 17'

  run_init claude linux-gnu
  assert_failure
  assert_file_line '{ "private": true }' "$CASE_HOME/.claude/settings.json"
  assert_symlink \
    "$CASE_HOME/.claude/statusline-command.sh" \
    "$CASE_REPO/claude/statusline-command.sh"
  if find "$CASE_HOME/.claude" -maxdepth 1 -name '.settings.json.*' -print -quit | grep -q .; then
    fail 'failed Claude settings generation left a temporary file'
  fi
}

run_test() {
  local name="$1"
  local function_name="$2"
  TEST_NUMBER=$((TEST_NUMBER + 1))
  if ( "$function_name" ); then
    printf 'ok %d - %s\n' "$TEST_NUMBER" "$name"
  else
    printf 'not ok %d - %s\n' "$TEST_NUMBER" "$name"
    FAILURES=$((FAILURES + 1))
  fi
}

printf '1..15\n'
run_test 'Zsh creates exact links and repeats as a no-op' test_zsh_absent_and_expected_links_are_idempotent
run_test 'Zsh regular conflict stops before any link or source write' test_zsh_regular_conflict_stops_before_any_link_or_source_write
run_test 'Bash creates exact links and repeats as a no-op' test_bash_absent_and_expected_links_are_idempotent
run_test 'Bash legacy local is migrated without replacing it' test_bash_legacy_local_is_migrated_without_replacing_it
run_test 'Zsh invalid Local Adapter stops before shared links' test_zsh_invalid_local_adapter_stops_before_shared_links
run_test 'Bash broken Local Adapter symlink stops before shared link' test_bash_broken_local_adapter_symlink_stops_before_shared_link
run_test 'Zsh invalid XDG config parent stops before shared links' test_zsh_invalid_xdg_config_parent_stops_before_shared_links
run_test '.config default links are exact and idempotent' test_config_default_links_are_exact_and_idempotent
run_test 'private Zed settings stop all config writes and remain intact' test_zed_private_settings_are_preserved_before_other_config_writes
run_test 'default Starship conflict stops all config writes and remains intact' test_default_starship_conflict_is_preserved_before_other_config_writes
run_test 'Starship override marker is idempotent and failed generation is atomic' test_starship_override_marker_is_idempotent_and_failure_is_atomic
run_test 'unmarked Starship override conflict remains intact' test_unmarked_starship_override_conflict_is_preserved
run_test 'tmux conflict stops before clone and other link writes' test_tmux_conflict_stops_before_clone_or_other_link
run_test 'Claude statusline conflict stops before settings writes' test_claude_conflict_stops_before_settings_write
run_test 'Claude failed settings generation preserves the prior file' test_claude_failed_generation_preserves_settings_atomically

if [[ "$FAILURES" -ne 0 ]]; then
  printf '%d test(s) failed\n' "$FAILURES" >&2
  exit 1
fi

printf 'All fail-closed legacy link tests passed.\n'
