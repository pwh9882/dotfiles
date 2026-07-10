#!/usr/bin/env bash

# Integration tests for Workspace Registry resolution and Execution Context.
# Compatible with the Bash 3.2 shipped by macOS.

set -u

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORIGINAL_TMPDIR="${TMPDIR:-/tmp}"
ORIGINAL_PATH="$PATH"
GIT_BIN="$(command -v git)"
SUITE_ROOT="$(mktemp -d "$ORIGINAL_TMPDIR/dotfiles-workspace-tests.XXXXXX")" || exit 1
TAB="$(printf '\t')"
HEADER="workspace_id${TAB}target_id${TAB}root"
TEST_NUMBER=0
FAILURES=0

cleanup() {
  case "$SUITE_ROOT" in
    "$ORIGINAL_TMPDIR"/dotfiles-workspace-tests.*) /bin/rm -rf "$SUITE_ROOT" ;;
    *) printf 'Refusing to remove unexpected test path: %s\n' "$SUITE_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf '  assertion failed: %s\n' "$1" >&2
  if [ -f "${CASE_OUT:-}" ]; then
    printf '  stdout:\n' >&2
    sed 's/^/    /' "$CASE_OUT" >&2
  fi
  if [ -f "${CASE_ERR:-}" ]; then
    printf '  stderr:\n' >&2
    sed 's/^/    /' "$CASE_ERR" >&2
  fi
  return 1
}

new_case() {
  CASE_ROOT="$SUITE_ROOT/case-$TEST_NUMBER"
  CASE_HOME="$CASE_ROOT/home"
  CASE_PUBLIC="$CASE_ROOT/workspaces.tsv"
  CASE_LOCAL="$CASE_ROOT/workspaces.local.tsv"
  CASE_OUT="$CASE_ROOT/stdout"
  CASE_ERR="$CASE_ROOT/stderr"
  CASE_CWD="$CASE_HOME/project"
  CASE_IDENTITY="$CASE_ROOT/llm-instance"
  CASE_IDENTITY_LOG="$CASE_ROOT/identity.log"
  CASE_FAKE_BIN="$CASE_ROOT/fake-bin"
  PATH="$ORIGINAL_PATH"
  unset SSH_CONNECTION SSH_CLIENT TMUX WSL_DISTRO_NAME
  mkdir -p "$CASE_HOME/project"
  printf '%s\nfixture\tlocal\t~/project' "$HEADER" >"$CASE_PUBLIC"
  printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$*" >> "$IDENTITY_LOG"' 'exit 1' >"$CASE_IDENTITY"
  chmod +x "$CASE_IDENTITY"
  export DF_CONTEXT_IDENTITY_COMMAND="$CASE_IDENTITY"
  export IDENTITY_LOG="$CASE_IDENTITY_LOG"
  COMMAND_STATUS=0
}

write_public() {
  : >"$CASE_PUBLIC"
  while [ "$#" -gt 0 ]; do
    printf '%s\n' "$1" >>"$CASE_PUBLIC"
    shift
  done
}

write_local() {
  : >"$CASE_LOCAL"
  while [ "$#" -gt 0 ]; do
    printf '%s\n' "$1" >>"$CASE_LOCAL"
    shift
  done
}

run_dotfiles() {
  : >"$CASE_OUT"
  : >"$CASE_ERR"
  if (
    export HOME="$CASE_HOME"
    export XDG_CONFIG_HOME="$CASE_ROOT/xdg-config"
    export XDG_DATA_HOME="$CASE_ROOT/xdg-data"
    export XDG_STATE_HOME="$CASE_ROOT/xdg-state"
    export XDG_CACHE_HOME="$CASE_ROOT/xdg-cache"
    export DF_WORKSPACES_REGISTRY="$CASE_PUBLIC"
    export DF_WORKSPACES_LOCAL_REGISTRY="$CASE_LOCAL"
    cd "$CASE_CWD" || exit 1
    "$ROOT/bin/dotfiles" "$@"
  ) >"$CASE_OUT" 2>"$CASE_ERR"; then
    COMMAND_STATUS=0
  else
    COMMAND_STATUS=$?
  fi
}

run_context() {
  run_dotfiles context "$@"
}

run_doctor() {
  run_dotfiles doctor --only workspaces
}

assert_success() {
  [ "$COMMAND_STATUS" -eq 0 ] || fail "command exited $COMMAND_STATUS, expected success"
}

assert_failure() {
  [ "$COMMAND_STATUS" -ne 0 ] || fail 'command succeeded, expected failure'
}

assert_stdout_line() {
  grep -Fqx "$1" "$CASE_OUT" || fail "stdout does not contain exact line [$1]"
}

assert_context_rejects_public() {
  write_public "$@"
  run_context
  assert_failure
}

make_identity_success() {
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$*" >> "$IDENTITY_LOG"' \
    'printf "%s\n" "instance_id=fixture-machine" "hostname=ignored-host" "instance_doc=/private/ignored.md" "role=authoring-client"' \
    >"$CASE_IDENTITY"
  chmod +x "$CASE_IDENTITY"
}

make_fake_uname() {
  mkdir -p "$CASE_FAKE_BIN"
  printf '%s\n' \
    '#!/bin/sh' \
    'case "$1" in' \
    '  -s) printf "%s\n" "$FAKE_UNAME_SYSTEM" ;;' \
    '  -r) printf "%s\n" "$FAKE_UNAME_RELEASE" ;;' \
    '  *) exit 1 ;;' \
    'esac' \
    >"$CASE_FAKE_BIN/uname"
  chmod +x "$CASE_FAKE_BIN/uname"
  PATH="$CASE_FAKE_BIN:$ORIGINAL_PATH"
  export PATH
}

test_context_resolves_registered_workspace() {
  run_context
  [ "$COMMAND_STATUS" -eq 0 ] || { fail "context exited $COMMAND_STATUS"; return 1; }
  grep -Fqx 'workspace_id=fixture' "$CASE_OUT" || { fail 'workspace was not resolved'; return 1; }
  grep -Fqx 'target_id=local' "$CASE_OUT" || fail 'target was not resolved'
}

test_strict_registry_schema_and_identifiers() {
  assert_context_rejects_public "workspace${TAB}target${TAB}path" "fixture${TAB}local${TAB}~/project" || return 1
  assert_context_rejects_public "$HEADER" "fixture${TAB}local" || return 1
  assert_context_rejects_public "$HEADER" "bad_id${TAB}local${TAB}~/project" || return 1
  assert_context_rejects_public "$HEADER" "fixture${TAB}bad target${TAB}~/project" || return 1
  assert_context_rejects_public "$HEADER" "fixture${TAB}local${TAB}~/project" "fixture${TAB}local${TAB}~/other"
}

test_registry_rejects_unsafe_root_syntax() {
  assert_context_rejects_public "$HEADER" "fixture${TAB}local${TAB}/absolute/project" || return 1
  assert_context_rejects_public "$HEADER" "fixture${TAB}local${TAB}~/\$HOME/project" || return 1
  assert_context_rejects_public "$HEADER" "fixture${TAB}local${TAB}~/project*" || return 1
  assert_context_rejects_public "$HEADER" "fixture${TAB}local${TAB}~/one/../project" || return 1
  write_public "$HEADER" "fixture${TAB}local${TAB}~/project"
  write_local "$HEADER" "other${TAB}local${TAB}relative/project"
  run_context
  assert_failure || return 1
  write_local "$HEADER" "fixture${TAB}local${TAB}$CASE_HOME/project"
  run_context
  assert_success
}

test_local_overlay_overrides_composite_key() {
  mkdir -p "$CASE_HOME/override"
  write_local "$HEADER" "fixture${TAB}local${TAB}$CASE_HOME/override"
  CASE_CWD="$CASE_HOME/override"
  run_context
  assert_success || return 1
  assert_stdout_line 'workspace_id=fixture' || return 1
  CASE_CWD="$CASE_HOME/project"
  run_context
  assert_success || return 1
  assert_stdout_line 'workspace_id=unknown'
}

test_all_sources_validate_before_merge() {
  write_local \
    "$HEADER" \
    "fixture${TAB}local${TAB}$CASE_HOME/project" \
    "broken${TAB}local${TAB}../relative"
  run_context
  assert_failure || return 1
  grep -Fq 'local line 3' "$CASE_ERR" || fail 'invalid trailing local row was not reported'
}

test_duplicate_physical_roots_are_ambiguous() {
  ln -s "$CASE_HOME/project" "$CASE_HOME/alias"
  write_public \
    "$HEADER" \
    "fixture${TAB}local${TAB}~/project" \
    "alias${TAB}local${TAB}~/alias"
  run_context
  assert_failure || return 1
  grep -Fq 'ambiguous root' "$CASE_ERR" || fail 'canonical root ambiguity was not reported'
}

test_context_uses_canonical_physical_paths() {
  ln -s "$CASE_HOME/project" "$CASE_HOME/alias"
  write_public "$HEADER" "fixture${TAB}local${TAB}~/alias"
  CASE_CWD="$CASE_HOME/alias"
  run_context
  assert_success || return 1
  assert_stdout_line 'workspace_id=fixture' || return 1
  physical="$(cd "$CASE_HOME/project" && pwd -P)"
  assert_stdout_line "cwd=$physical"
}

test_longest_segment_boundary_prefix_wins() {
  mkdir -p "$CASE_HOME/project/sub/deep" "$CASE_HOME/project-two"
  write_public \
    "$HEADER" \
    "broad${TAB}local${TAB}~/project" \
    "narrow${TAB}local${TAB}~/project/sub"
  CASE_CWD="$CASE_HOME/project/sub/deep"
  run_context
  assert_success || return 1
  assert_stdout_line 'workspace_id=narrow' || return 1
  CASE_CWD="$CASE_HOME/project-two"
  run_context
  assert_success || return 1
  assert_stdout_line 'workspace_id=unknown'
}

test_missing_roots_are_skipped_and_warned() {
  write_public \
    "$HEADER" \
    "missing${TAB}local${TAB}~/does-not-exist" \
    "fixture${TAB}local${TAB}~/project"
  run_context
  assert_success || return 1
  assert_stdout_line 'workspace_id=fixture' || return 1
  run_doctor
  assert_success || return 1
  grep -Fq 'WARN  workspace target root is missing: missing/local' "$CASE_OUT" || return 1
  grep -Fq 'INFO  optional local overlay is absent' "$CASE_OUT" || fail 'absent local overlay was not treated as normal'
}

test_identity_platform_transport_and_multiplexer_signals() {
  make_identity_success
  make_fake_uname
  export FAKE_UNAME_SYSTEM=Darwin FAKE_UNAME_RELEASE=fixture
  export TMUX=/tmp/tmux-fixture
  run_context
  assert_success || return 1
  assert_stdout_line 'execution_instance_id=fixture-machine' || return 1
  assert_stdout_line 'origin_instance_id=fixture-machine' || return 1
  assert_stdout_line 'role=authoring-client' || return 1
  assert_stdout_line 'platform=macos' || return 1
  assert_stdout_line 'transport=local' || return 1
  assert_stdout_line 'multiplexer=tmux' || return 1

  export FAKE_UNAME_SYSTEM=Linux FAKE_UNAME_RELEASE=6.8.0-generic
  unset TMUX
  run_context
  assert_stdout_line 'platform=linux' || return 1

  export FAKE_UNAME_RELEASE=5.15.90.1-microsoft-standard-WSL2
  export SSH_CONNECTION='client server'
  run_context
  assert_stdout_line 'platform=wsl' || return 1
  assert_stdout_line 'transport=ssh' || return 1
  assert_stdout_line 'origin_instance_id=unknown' || return 1
  assert_stdout_line 'multiplexer=none' || return 1
  [ "$(grep -c '^--details$' "$CASE_IDENTITY_LOG")" -eq 3 ] || fail 'identity was not read exclusively through llm-instance --details'
}

test_json_schema_git_state_and_escaping() {
  local quoted physical escaped expected
  quoted="$CASE_HOME/project \"quoted\""
  mkdir -p "$quoted"
  write_public "$HEADER" "quoted${TAB}local${TAB}~/project \"quoted\""
  CASE_CWD="$quoted"
  make_identity_success
  make_fake_uname
  export FAKE_UNAME_SYSTEM=Linux FAKE_UNAME_RELEASE=6.8.0

  "$GIT_BIN" -C "$quoted" init -q
  "$GIT_BIN" -C "$quoted" config user.name fixture
  "$GIT_BIN" -C "$quoted" config user.email fixture@example.invalid
  printf 'tracked\n' >"$quoted/tracked.txt"
  "$GIT_BIN" -C "$quoted" add tracked.txt
  "$GIT_BIN" -C "$quoted" commit -qm initial
  "$GIT_BIN" -C "$quoted" checkout -qb feature/context

  run_context --json
  assert_success || return 1
  physical="$(cd "$quoted" && pwd -P)"
  escaped="${physical//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  expected="{\"schema_version\":1,\"execution_instance_id\":\"fixture-machine\",\"origin_instance_id\":\"fixture-machine\",\"role\":\"authoring-client\",\"platform\":\"linux\",\"transport\":\"local\",\"multiplexer\":\"none\",\"workspace_id\":\"quoted\",\"target_id\":\"local\",\"persistence\":null,\"cwd\":\"$escaped\",\"repository_root\":\"$escaped\",\"git_branch\":\"feature/context\",\"git_dirty\":false}"
  [ "$(cat "$CASE_OUT")" = "$expected" ] || fail 'JSON schema, order, escaping, or clean bool changed'

  printf 'dirty\n' >"$quoted/untracked.txt"
  run_context --json
  grep -Fq '"git_dirty":true}' "$CASE_OUT" || fail 'dirty Git state was not a JSON boolean'
}

test_git_is_local_read_only_and_unknowns_succeed() {
  local git_log identity_before
  git_log="$CASE_ROOT/git.log"
  mkdir -p "$CASE_FAKE_BIN" "$CASE_HOME/outside"
  printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$*" >> "$FAKE_GIT_LOG"' \
    'case "$*" in' \
    '  *"rev-parse --show-toplevel") printf "%s\n" "$FAKE_GIT_ROOT" ;;' \
    '  *"symbolic-ref --quiet --short HEAD") printf "%s\n" "fixture-branch" ;;' \
    '  *"--no-optional-locks -C"*"status --porcelain --untracked-files=normal") : ;;' \
    '  *) exit 91 ;;' \
    'esac' \
    >"$CASE_FAKE_BIN/git"
  chmod +x "$CASE_FAKE_BIN/git"
  PATH="$CASE_FAKE_BIN:$ORIGINAL_PATH"
  export PATH FAKE_GIT_LOG="$git_log" FAKE_GIT_ROOT="$CASE_HOME/project"
  CASE_CWD="$CASE_HOME/outside"

  run_context
  assert_success || return 1
  assert_stdout_line 'execution_instance_id=unknown' || return 1
  assert_stdout_line 'origin_instance_id=unknown' || return 1
  assert_stdout_line 'role=unknown' || return 1
  assert_stdout_line 'workspace_id=unknown' || return 1
  [ "$(wc -l < "$git_log" | tr -d ' ')" -eq 3 ] || fail 'context executed an unexpected number of Git reads'
  grep -Fq -- '--no-optional-locks' "$git_log" || fail 'Git status did not disable optional index writes'
  if grep -Eq 'fetch|remote|ls-remote|submodule' "$git_log"; then
    fail 'context performed a remote or expansive Git probe'
    return 1
  fi
  [ ! -e "$CASE_ROOT/xdg-config" ] || fail 'context wrote XDG config state'
  [ ! -e "$CASE_ROOT/xdg-data" ] || fail 'context wrote XDG data state'
  [ ! -e "$CASE_ROOT/xdg-state" ] || fail 'context wrote XDG state'
  [ ! -e "$CASE_ROOT/xdg-cache" ] || fail 'context wrote XDG cache state'
  [ -z "$(find "$CASE_HOME" -type f -o -type l)" ] || fail 'context wrote HOME'

  identity_before="$(wc -l < "$CASE_IDENTITY_LOG" | tr -d ' ')"
  run_context --unsupported
  [ "$COMMAND_STATUS" -eq 2 ] || fail 'unknown option did not return usage status 2'
  [ "$(wc -l < "$CASE_IDENTITY_LOG" | tr -d ' ')" = "$identity_before" ] || fail 'option parsing invoked identity before failing'
}

run_test() {
  local name="$1"
  shift
  TEST_NUMBER=$((TEST_NUMBER + 1))
  new_case
  if "$@"; then
    printf 'ok %d - %s\n' "$TEST_NUMBER" "$name"
  else
    printf 'not ok %d - %s\n' "$TEST_NUMBER" "$name"
    FAILURES=$((FAILURES + 1))
  fi
}

run_test 'context resolves a registered workspace' test_context_resolves_registered_workspace
run_test 'registry enforces its strict schema and identifiers' test_strict_registry_schema_and_identifiers
run_test 'registry rejects unsafe root syntax' test_registry_rejects_unsafe_root_syntax
run_test 'local overlay overrides one composite key' test_local_overlay_overrides_composite_key
run_test 'all registry sources validate before merge' test_all_sources_validate_before_merge
run_test 'duplicate physical roots fail as ambiguous' test_duplicate_physical_roots_are_ambiguous
run_test 'context reports canonical physical paths' test_context_uses_canonical_physical_paths
run_test 'longest segment-boundary workspace prefix wins' test_longest_segment_boundary_prefix_wins
run_test 'missing roots are skipped and Doctor warns' test_missing_roots_are_skipped_and_warned
run_test 'identity and environment signals stay explicit' test_identity_platform_transport_and_multiplexer_signals
run_test 'JSON schema preserves Git types and escaping' test_json_schema_git_state_and_escaping
run_test 'Git reads stay local and unknown context succeeds without writes' test_git_is_local_read_only_and_unknowns_succeed

printf '1..%d\n' "$TEST_NUMBER"
if [ "$FAILURES" -ne 0 ]; then
  printf '%d workspace test(s) failed\n' "$FAILURES" >&2
  exit 1
fi
printf 'All %d workspace tests passed\n' "$TEST_NUMBER"
