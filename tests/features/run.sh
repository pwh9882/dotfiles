#!/usr/bin/env bash

# Dependency-free tests for the read-only Feature Registry Interface.
# Compatible with the Bash 3.2 shipped by macOS.

set -u

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DF_ROOT="$ROOT"
. "$ROOT/lib/dotfiles/features.sh"

ORIGINAL_TMPDIR="${TMPDIR:-/tmp}"
SUITE_ROOT="$(mktemp -d "$ORIGINAL_TMPDIR/dotfiles-feature-tests.XXXXXX")" || exit 1
TAB="$(printf '\t')"
HEADER="id${TAB}status${TAB}roles${TAB}platforms${TAB}privacy${TAB}first_run${TAB}verify${TAB}docs${TAB}summary"
VALID_ROW="fixture-feature${TAB}available${TAB}authoring-client${TAB}macos,linux${TAB}local read only${TAB}dotfiles doctor --quick${TAB}dotfiles doctor --full${TAB}docs/architecture/index.md${TAB}Fixture summary"

TEST_NUMBER=0
FAILURES=0

cleanup() {
  case "$SUITE_ROOT" in
    "$ORIGINAL_TMPDIR"/dotfiles-feature-tests.*) /bin/rm -rf "$SUITE_ROOT" ;;
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

assert_success() {
  [ "$COMMAND_STATUS" -eq 0 ] || fail "command exited $COMMAND_STATUS, expected success"
}

assert_failure() {
  [ "$COMMAND_STATUS" -ne 0 ] || fail 'command succeeded, expected failure'
}

assert_output_contains() {
  local contents
  contents="$(cat "$CASE_OUT")"
  case "$contents" in
    *"$1"*) return 0 ;;
    *) fail "stdout does not contain [$1]" ;;
  esac
}

new_case() {
  CASE_ROOT="$SUITE_ROOT/case-$TEST_NUMBER"
  CASE_HOME="$CASE_ROOT/home"
  CASE_OUT="$CASE_ROOT/stdout"
  CASE_ERR="$CASE_ROOT/stderr"
  CASE_REGISTRY="$CASE_ROOT/features.tsv"
  mkdir -p "$CASE_HOME"
  COMMAND_STATUS=0
}

write_fixture() {
  : >"$CASE_REGISTRY"
  while [ "$#" -gt 0 ]; do
    printf '%s\n' "$1" >>"$CASE_REGISTRY"
    shift
  done
}

run_features() {
  : >"$CASE_OUT"
  : >"$CASE_ERR"
  if (
    export HOME="$CASE_HOME"
    export XDG_CONFIG_HOME="$CASE_ROOT/xdg-config"
    export XDG_DATA_HOME="$CASE_ROOT/xdg-data"
    export XDG_STATE_HOME="$CASE_ROOT/xdg-state"
    export XDG_CACHE_HOME="$CASE_ROOT/xdg-cache"
    if [ -f "$CASE_REGISTRY" ]; then
      DF_FEATURES_REGISTRY="$CASE_REGISTRY"
    else
      unset DF_FEATURES_REGISTRY
    fi
    "$@"
  ) >"$CASE_OUT" 2>"$CASE_ERR"; then
    COMMAND_STATUS=0
  else
    COMMAND_STATUS=$?
  fi
}

assert_fixture_invalid() {
  write_fixture "$@"
  run_features df_features_validate
  assert_failure
}

test_parser_accepts_registry() {
  run_features df_features_validate
  assert_success
}

test_parser_rejects_invalid_file() {
  assert_fixture_invalid "bad${TAB}header" "$VALID_ROW" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}available${TAB}authoring-client${TAB}macos${TAB}privacy${TAB}first${TAB}verify${TAB}docs/architecture/index.md" || return 1
  assert_fixture_invalid "$HEADER" "bad_id${TAB}available${TAB}authoring-client${TAB}macos${TAB}privacy${TAB}first${TAB}verify${TAB}docs/architecture/index.md${TAB}summary" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}planned${TAB}authoring-client${TAB}macos${TAB}privacy${TAB}first${TAB}verify${TAB}docs/architecture/index.md${TAB}summary" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}available${TAB}authoring-client,${TAB}macos${TAB}privacy${TAB}first${TAB}verify${TAB}docs/architecture/index.md${TAB}summary" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}available${TAB}authoring-client${TAB}mac os${TAB}privacy${TAB}first${TAB}verify${TAB}docs/architecture/index.md${TAB}summary" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}available${TAB}authoring-client${TAB}macos${TAB}${TAB}first${TAB}verify${TAB}docs/architecture/index.md${TAB}summary" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}available${TAB}authoring-client${TAB}macos${TAB}privacy${TAB}${TAB}verify${TAB}docs/architecture/index.md${TAB}summary" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}available${TAB}authoring-client${TAB}macos${TAB}privacy${TAB}first${TAB}${TAB}docs/architecture/index.md${TAB}summary" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}available${TAB}authoring-client${TAB}macos${TAB}privacy${TAB}first${TAB}verify${TAB}docs/architecture/index.md${TAB}" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}available${TAB}authoring-client${TAB}macos${TAB}privacy${TAB}first${TAB}verify${TAB}/tmp/absolute.md${TAB}summary" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}available${TAB}authoring-client${TAB}macos${TAB}privacy${TAB}first${TAB}verify${TAB}docs/../README.md${TAB}summary" || return 1
  assert_fixture_invalid "$HEADER" "fixture-feature${TAB}available${TAB}authoring-client${TAB}macos${TAB}privacy${TAB}first${TAB}verify${TAB}docs/does-not-exist.md${TAB}summary" || return 1
  assert_fixture_invalid "$HEADER" "$VALID_ROW" "$VALID_ROW"
}

test_list() {
  run_features df_features_list
  assert_success || return 1
  assert_output_contains 'repository-health' || return 1
  assert_output_contains 'machine-profile' || return 1
  assert_output_contains 'safe-bin-apply' || return 1
  assert_output_contains 'shared-agent-instructions' || return 1
  assert_output_contains 'workspace-context' || return 1
  assert_output_contains 'wezterm-context-status' || return 1
  assert_output_contains 'wezterm-project-picker' || return 1
  assert_output_contains 'wezterm-session-restore' || return 1
  if grep -Fq 'planned' "$CASE_OUT"; then
    fail 'list exposed a planned feature'
  fi
}

test_wezterm_detail() {
  run_features df_features_detail wezterm-project-picker
  assert_success || return 1
  assert_output_contains 'roles:      authoring-client' || return 1
  assert_output_contains 'platforms:  macos' || return 1
  assert_output_contains 'first run:  WezTerm에서 Ctrl+A를 놓은 뒤 p' || return 1
  assert_output_contains 'verify:     lua .config/wezterm/projects_test.lua' || return 1
  assert_output_contains 'docs/runbooks/use-wezterm-workflows.md'
}

test_detail() {
  run_features df_features_detail safe-bin-apply
  assert_success || return 1
  assert_output_contains 'status:     pilot' || return 1
  assert_output_contains 'first run:  dotfiles plan --only bin' || return 1
  assert_output_contains 'verify:     dotfiles doctor --only bin' || return 1
  assert_output_contains 'docs/runbooks/manage-bin-module.md'
}

test_unknown_detail() {
  run_features df_features_detail does-not-exist
  assert_failure || return 1
  grep -Fq 'unknown feature: does-not-exist' "$CASE_ERR" || fail 'unknown feature error was not reported'
}

test_read_paths_are_zero_write() {
  run_features df_features_list
  assert_success || return 1
  run_features df_features_detail repository-health
  assert_success || return 1
  run_features df_features_doctor
  assert_success || return 1

  [ -z "$(find "$CASE_HOME" -mindepth 1 -print)" ] || fail 'Feature commands changed HOME'
  for path in xdg-config xdg-data xdg-state xdg-cache; do
    [ ! -e "$CASE_ROOT/$path" ] || fail "Feature commands wrote $path"
  done
}

test_evidence_id_allowlist() {
  df_features_evidence_known repository-health || fail 'repository-health evidence ID is missing'
  df_features_evidence_known machine-profile || fail 'machine-profile evidence ID is missing'
  df_features_evidence_known safe-bin-apply || fail 'safe-bin-apply evidence ID is missing'
  df_features_evidence_known shared-agent-instructions || fail 'shared-agent-instructions evidence ID is missing'
  df_features_evidence_known workspace-context || fail 'workspace-context evidence ID is missing'
  df_features_evidence_known wezterm-context-status || fail 'wezterm-context-status evidence ID is missing'
  df_features_evidence_known wezterm-project-picker || fail 'wezterm-project-picker evidence ID is missing'
  df_features_evidence_known wezterm-session-restore || fail 'wezterm-session-restore evidence ID is missing'
  if df_features_evidence_known planned-feature; then
    fail 'unknown evidence ID was accepted'
  fi
  df_features_evidence_present repository-health || fail 'repository-health evidence is incomplete'
  df_features_evidence_present machine-profile || fail 'machine-profile evidence is incomplete'
  df_features_evidence_present safe-bin-apply || fail 'safe-bin-apply evidence is incomplete'
  df_features_evidence_present shared-agent-instructions || fail 'shared-agent-instructions evidence is incomplete'
  df_features_evidence_present workspace-context || fail 'workspace-context evidence is incomplete'
  df_features_evidence_present wezterm-context-status || fail 'wezterm-context-status evidence is incomplete'
  df_features_evidence_present wezterm-project-picker || fail 'wezterm-project-picker evidence is incomplete'
  df_features_evidence_present wezterm-session-restore || fail 'wezterm-session-restore evidence is incomplete'

  run_features df_features_doctor
  assert_success || return 1
  assert_output_contains 'feature evidence: repository-health' || return 1
  assert_output_contains 'feature evidence: machine-profile' || return 1
  assert_output_contains 'feature evidence: safe-bin-apply'
  assert_output_contains 'feature evidence: shared-agent-instructions' || return 1
  assert_output_contains 'feature evidence: workspace-context' || return 1
  assert_output_contains 'feature evidence: wezterm-context-status' || return 1
  assert_output_contains 'feature evidence: wezterm-project-picker' || return 1
  assert_output_contains 'feature evidence: wezterm-session-restore'
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

run_test 'parser accepts the current strict registry' test_parser_accepts_registry
run_test 'parser rejects malformed registry data' test_parser_rejects_invalid_file
run_test 'list shows only usable features' test_list
run_test 'detail exposes onboarding and verification commands' test_detail
run_test 'WezTerm detail exposes the supported onboarding action' test_wezterm_detail
run_test 'detail rejects unknown IDs' test_unknown_detail
run_test 'list, detail, and doctor leave user state untouched' test_read_paths_are_zero_write
run_test 'evidence allowlist covers every registry ID' test_evidence_id_allowlist

printf '1..%d\n' "$TEST_NUMBER"
if [ "$FAILURES" -ne 0 ]; then
  printf '%d feature test(s) failed\n' "$FAILURES" >&2
  exit 1
fi
printf 'All %d feature tests passed\n' "$TEST_NUMBER"
