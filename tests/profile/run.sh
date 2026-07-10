#!/usr/bin/env bash

# Dependency-free tests for Machine Profile identity and Module selection.
# Compatible with the Bash 3.2 shipped by macOS.

set -u

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOTFILES="$ROOT/bin/dotfiles"
LLM_INSTANCE="$ROOT/bin/llm-instance"
REAL_HOME="${HOME:-}"
ORIGINAL_TMPDIR="${TMPDIR:-/tmp}"

TEST_NUMBER=0
FAILURES=0
SUITE_ROOT="$(mktemp -d "$ORIGINAL_TMPDIR/dotfiles-profile-tests.XXXXXX")" || {
  printf 'not ok - could not create test directory\n' >&2
  exit 1
}

cleanup() {
  case "$SUITE_ROOT" in
    "$ORIGINAL_TMPDIR"/dotfiles-profile-tests.*) /bin/rm -rf "$SUITE_ROOT" ;;
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
  exit 1
}

assert_success() {
  [ "$COMMAND_STATUS" -eq 0 ] || fail "command exited $COMMAND_STATUS, expected success"
}

assert_failure() {
  [ "$COMMAND_STATUS" -ne 0 ] || fail 'command succeeded, expected failure'
}

assert_equal() {
  [ "$1" = "$2" ] || fail "expected [$1], got [$2]"
}

assert_output_contains() {
  local needle="$1"
  case "$(cat "$CASE_OUT")" in
    *"$needle"*) ;;
    *) fail "stdout does not contain [$needle]" ;;
  esac
}

assert_output_not_contains() {
  local needle="$1"
  case "$(cat "$CASE_OUT")" in
    *"$needle"*) fail "stdout unexpectedly contains [$needle]" ;;
    *) ;;
  esac
}

assert_output_equals() {
  assert_equal "$1" "$(cat "$CASE_OUT")"
}

new_case() {
  CASE_ROOT="$SUITE_ROOT/case-$TEST_NUMBER"
  CASE_HOME="$CASE_ROOT/home with spaces"
  CASE_WIKI="$CASE_ROOT/wiki with spaces"
  CASE_FAKE_BIN="$CASE_ROOT/fake bin"
  CASE_TMP="$CASE_ROOT/tmp with spaces"
  CASE_STATE="$CASE_ROOT/state with spaces"
  CASE_OUT="$CASE_ROOT/stdout"
  CASE_ERR="$CASE_ROOT/stderr"
  CASE_REGISTRY_OVERRIDE=""
  COMMAND_STATUS=0

  mkdir -p "$CASE_HOME" "$CASE_WIKI/instances" "$CASE_FAKE_BIN" "$CASE_TMP"
  printf '#!/bin/sh\nprintf "test-host\\n"\n' > "$CASE_FAKE_BIN/hostname"
  chmod 0755 "$CASE_FAKE_BIN/hostname"

  [ -n "$REAL_HOME" ] || fail 'real HOME was empty before the test'
  [ "$CASE_HOME" != "$REAL_HOME" ] || fail 'temporary HOME equals real HOME'
  case "$CASE_HOME" in
    "$SUITE_ROOT"/*) ;;
    *) fail 'temporary HOME escaped the suite root' ;;
  esac
}

write_instance() {
  local instance_id="$1"
  local role_line="$2"
  local instance_doc="$CASE_WIKI/instances/$instance_id.md"

  mkdir -p "$CASE_HOME/.config/llm-wiki"
  printf '%s\n' "$instance_id" > "$CASE_HOME/.config/llm-wiki/instance-id"
  {
    printf '%s\n' '---'
    printf 'instance_id: %s\n' "$instance_id"
    printf '%s\n' 'hostname: test-host'
    if [ "$role_line" != "__missing__" ]; then
      printf '%s\n' "$role_line"
    fi
    printf '%s\n' '---'
  } > "$instance_doc"
}

run_command() {
  local program="$1"
  shift
  : > "$CASE_OUT"
  : > "$CASE_ERR"

  if (
    export HOME="$CASE_HOME"
    export LLM_WIKI_DIR="$CASE_WIKI"
    export XDG_STATE_HOME="$CASE_STATE"
    export TMPDIR="$CASE_TMP"
    export PATH="$CASE_FAKE_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
    export LC_ALL=C
    unset LLM_INSTANCE_FILE
    if [ -n "$CASE_REGISTRY_OVERRIDE" ]; then
      export DOTFILES_PROFILE_REGISTRY="$CASE_REGISTRY_OVERRIDE"
    else
      unset DOTFILES_PROFILE_REGISTRY
    fi
    "$program" "$@"
  ) > "$CASE_OUT" 2> "$CASE_ERR"; then
    COMMAND_STATUS=0
  else
    COMMAND_STATUS=$?
  fi
}

run_cli() {
  run_command "$DOTFILES" "$@"
}

run_instance() {
  run_command "$LLM_INSTANCE" "$@"
}

assert_no_runtime_writes() {
  [ ! -e "$CASE_HOME/.local" ] || fail "runtime wrote $CASE_HOME/.local"
  [ ! -e "$CASE_STATE" ] || fail "runtime wrote $CASE_STATE"
  [ -z "$(find "$CASE_TMP" -mindepth 1 -print)" ] || fail "runtime left files in $CASE_TMP"
}

assert_managed_link() {
  local tool="$1"
  local target="$CASE_HOME/.local/bin/$tool"
  [ -L "$target" ] || fail "$target is not a symlink"
  assert_equal "$ROOT/bin/$tool" "$(readlink "$target")"
}

state_snapshot() {
  if [ ! -e "$CASE_STATE" ]; then
    printf '%s\n' absent
    return
  fi
  find "$CASE_STATE" -print | LC_ALL=C sort
  find "$CASE_STATE" -type f -exec cksum {} \; | LC_ALL=C sort
}

test_all_public_roles_resolve_profile_modules() {
  local role instance_id
  new_case

  for role in authoring-client service-host windows-workstation headless-agent-worker; do
    instance_id="test-$role"
    write_instance "$instance_id" "role: $role"

    run_cli profile
    assert_success
    assert_output_contains "instance_id=$instance_id"
    assert_output_contains "role=$role"
    assert_output_contains 'capability=core-tools'
    assert_output_contains 'capability=shared-agent-instructions'
    assert_output_contains 'module=bin'
    assert_output_contains 'module=agents-links'

    run_instance --details
    assert_success
    assert_output_contains "role=$role"
  done
  assert_no_runtime_writes
}

test_profile_output_excludes_topology() {
  local expected
  new_case
  write_instance test-private 'role: authoring-client'

  run_cli profile
  assert_success
  expected='instance_id=test-private
role=authoring-client
capability=core-tools
capability=shared-agent-instructions
module=bin
module=agents-links'
  assert_output_equals "$expected"
  assert_output_not_contains 'hostname='
  assert_output_not_contains 'instance_doc='
  assert_output_not_contains "$CASE_HOME"
  assert_output_not_contains "$CASE_WIKI"
  assert_no_runtime_writes
}

test_plan_without_only_uses_profile_and_writes_nothing() {
  new_case
  write_instance test-plan 'role: service-host'

  run_cli plan
  assert_success
  assert_output_contains "$CASE_HOME/.local/bin/dotfiles"
  assert_output_contains "$CASE_HOME/.local/bin/llm-instance"
  assert_output_contains "$CASE_HOME/.claude/CLAUDE.md"
  assert_output_contains "$CASE_HOME/.codex/AGENTS.md"
  assert_no_runtime_writes
}

test_explicit_only_bin_bootstraps_without_identity() {
  new_case

  run_cli plan --only bin
  assert_success
  assert_no_runtime_writes

  run_cli apply --only bin
  assert_success
  assert_managed_link dotfiles
  assert_managed_link llm-instance
}

test_profile_doctor_is_read_only_and_detects_missing_link() {
  local before after
  new_case
  write_instance test-doctor 'role: headless-agent-worker'

  run_cli apply
  assert_success
  before="$(state_snapshot)"

  run_cli doctor --profile
  assert_success
  after="$(state_snapshot)"
  assert_equal "$before" "$after"

  /bin/rm "$CASE_HOME/.codex/AGENTS.md"
  before="$(state_snapshot)"
  run_cli doctor --profile
  assert_failure
  after="$(state_snapshot)"
  assert_equal "$before" "$after"
}

test_identity_and_role_errors_stop_before_apply() {
  new_case

  write_instance test-unknown 'role: experimental-client'
  run_cli apply
  assert_failure
  assert_no_runtime_writes

  write_instance test-invalid 'role: authoring_client'
  run_cli apply
  assert_failure
  assert_no_runtime_writes

  /bin/rm "$CASE_HOME/.config/llm-wiki/instance-id"
  run_cli apply
  assert_failure
  assert_no_runtime_writes
}

test_registry_rejects_malformed_unknown_and_duplicate_rows() {
  new_case
  write_instance test-registry 'role: authoring-client'
  CASE_REGISTRY_OVERRIDE="$CASE_ROOT/machine-profiles.tsv"

  printf 'authoring-client\tcore-tools\textra\n' > "$CASE_REGISTRY_OVERRIDE"
  run_cli profile
  assert_failure

  printf 'authoring-client\tcore-tools\nauthoring_client\tcore-tools\n' > "$CASE_REGISTRY_OVERRIDE"
  run_cli profile
  assert_failure

  printf 'authoring-client\tcore-tools\nexperimental-client\tcore-tools\n' > "$CASE_REGISTRY_OVERRIDE"
  run_cli profile
  assert_failure

  printf 'authoring-client\tcore-tools\nservice-host\textra-tools\n' > "$CASE_REGISTRY_OVERRIDE"
  run_cli profile
  assert_failure

  printf 'authoring-client\tcore-tools\nauthoring-client\tcore-tools\n' > "$CASE_REGISTRY_OVERRIDE"
  run_cli profile
  assert_failure
  assert_no_runtime_writes
}

test_llm_instance_id_remains_exact_without_role() {
  new_case
  write_instance test-no-role __missing__

  run_instance --id
  assert_success
  assert_output_equals 'test-no-role'

  run_instance
  assert_success
  assert_output_equals 'test-no-role'

  run_instance --details
  assert_failure
  assert_no_runtime_writes
}

test_llm_instance_requires_one_hostname_token() {
  local instance_doc mode
  new_case
  write_instance test-hostname 'role: authoring-client'
  instance_doc="$CASE_WIKI/instances/test-hostname.md"

  for mode in default --id --details; do
    printf '%s\n' '---' 'instance_id: test-hostname' 'role: authoring-client' '---' > "$instance_doc"
    if [ "$mode" = default ]; then run_instance; else run_instance "$mode"; fi
    assert_failure

    printf '%s\n' '---' 'instance_id: test-hostname' 'hostname:' 'role: authoring-client' '---' > "$instance_doc"
    if [ "$mode" = default ]; then run_instance; else run_instance "$mode"; fi
    assert_failure

    printf '%s\n' '---' 'instance_id: test-hostname' 'hostname: test-host extra' 'role: authoring-client' '---' > "$instance_doc"
    if [ "$mode" = default ]; then run_instance; else run_instance "$mode"; fi
    assert_failure

    printf '%s\n' '---' 'instance_id: test-hostname' 'hostname: test-host' 'hostname: test-host' 'role: authoring-client' '---' > "$instance_doc"
    if [ "$mode" = default ]; then run_instance; else run_instance "$mode"; fi
    assert_failure
  done
  assert_no_runtime_writes
}

test_llm_instance_hostname_match_is_case_insensitive() {
  local instance_doc
  new_case
  write_instance test-hostname-case 'role: authoring-client'
  instance_doc="$CASE_WIKI/instances/test-hostname-case.md"
  sed 's/hostname: test-host/hostname: TEST-HOST/' "$instance_doc" > "$instance_doc.tmp"
  mv "$instance_doc.tmp" "$instance_doc"

  run_instance
  assert_success
  assert_output_equals 'test-hostname-case'

  run_instance --id
  assert_success
  assert_output_equals 'test-hostname-case'

  run_instance --details
  assert_success
  assert_output_contains 'role=authoring-client'
  assert_no_runtime_writes
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

printf '1..10\n'
run_test 'all public roles resolve the fixed transactional Modules' test_all_public_roles_resolve_profile_modules
run_test 'profile output includes contract fields and excludes topology' test_profile_output_excludes_topology
run_test 'plan without --only uses profile and writes nothing' test_plan_without_only_uses_profile_and_writes_nothing
run_test 'explicit --only bin bootstraps without identity' test_explicit_only_bin_bootstraps_without_identity
run_test 'doctor --profile is read-only and detects a missing link' test_profile_doctor_is_read_only_and_detects_missing_link
run_test 'unknown, invalid, and missing identity stop before apply' test_identity_and_role_errors_stop_before_apply
run_test 'registry rejects malformed, unknown, and duplicate rows' test_registry_rejects_malformed_unknown_and_duplicate_rows
run_test 'llm-instance --id remains exact without role' test_llm_instance_id_remains_exact_without_role
run_test 'llm-instance requires exactly one hostname field and token' test_llm_instance_requires_one_hostname_token
run_test 'llm-instance hostname comparison remains case-insensitive' test_llm_instance_hostname_match_is_case_insensitive

if [ "$FAILURES" -ne 0 ]; then
  printf '%d test(s) failed\n' "$FAILURES" >&2
  exit 1
fi

printf 'All Machine Profile tests passed.\n'
