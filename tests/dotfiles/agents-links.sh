#!/usr/bin/env bash

# Focused integration tests for the transactional agents-links Module.
# Compatible with the Bash 3.2 shipped by macOS. Every write stays in a
# temporary HOME; agents/init.sh legacy post-config is exercised there too.

set -u

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOTFILES="$ROOT/bin/dotfiles"
AGENTS_INIT="$ROOT/agents/init.sh"
REAL_HOME="${HOME:-}"
ORIGINAL_TMPDIR="${TMPDIR:-/tmp}"

TEST_NUMBER=0
FAILURES=0
SUITE_ROOT="$(mktemp -d "$ORIGINAL_TMPDIR/dotfiles-agents-links-tests.XXXXXX")" || {
  printf 'not ok - could not create test directory\n' >&2
  exit 1
}

cleanup() {
  case "$SUITE_ROOT" in
    "$ORIGINAL_TMPDIR"/dotfiles-agents-links-tests.*) /bin/rm -rf "$SUITE_ROOT" ;;
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
  case "$(cat "$CASE_OUT")" in
    *"$1"*) ;;
    *) fail "stdout does not contain [$1]" ;;
  esac
}

assert_error_contains() {
  case "$(cat "$CASE_ERR")" in
    *"$1"*) ;;
    *) fail "stderr does not contain [$1]" ;;
  esac
}

new_case() {
  CASE_ROOT="$SUITE_ROOT/case-$TEST_NUMBER"
  CASE_HOME="$CASE_ROOT/home with spaces"
  CASE_TMP="$CASE_ROOT/tmp with spaces"
  CASE_STATE="$CASE_ROOT/state with spaces"
  CASE_OUT="$CASE_ROOT/stdout"
  CASE_ERR="$CASE_ROOT/stderr"
  COMMAND_STATUS=0
  TX_COUNT=0
  TX_DIR=''
  TX_ID=''

  mkdir -p "$CASE_HOME" "$CASE_TMP"

  [ -n "$REAL_HOME" ] || fail 'real HOME was empty before the test'
  [ "$CASE_HOME" != "$REAL_HOME" ] || fail 'temporary HOME equals real HOME'
  case "$CASE_HOME" in
    "$SUITE_ROOT"/*) ;;
    *) fail 'temporary HOME escaped the suite root' ;;
  esac
}

run_program() {
  local program="$1"
  shift
  : > "$CASE_OUT"
  : > "$CASE_ERR"

  if (
    export HOME="$CASE_HOME"
    export XDG_STATE_HOME="$CASE_STATE"
    export TMPDIR="$CASE_TMP"
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
    export LC_ALL=C
    "$program" "$@"
  ) > "$CASE_OUT" 2> "$CASE_ERR"; then
    COMMAND_STATUS=0
  else
    COMMAND_STATUS=$?
  fi
}

run_cli() {
  run_program "$DOTFILES" "$@"
}

run_agents_init() {
  run_program /bin/bash "$AGENTS_INIT" "$@"
}

assert_no_transaction_state() {
  [ ! -e "$CASE_STATE/dotfiles" ] || fail "transaction state was written at $CASE_STATE/dotfiles"
}

assert_agent_link() {
  local target="$1"
  [ -L "$target" ] || fail "$target is not a symlink"
  assert_equal "$ROOT/agents/AGENTS.md" "$(readlink "$target")"
}

assert_agent_links() {
  [ -d "$CASE_HOME/.claude" ] && [ ! -L "$CASE_HOME/.claude" ] || fail '.claude is not a real directory'
  [ -d "$CASE_HOME/.codex" ] && [ ! -L "$CASE_HOME/.codex" ] || fail '.codex is not a real directory'
  assert_agent_link "$CASE_HOME/.claude/CLAUDE.md"
  assert_agent_link "$CASE_HOME/.codex/AGENTS.md"
}

assert_agent_paths_absent() {
  [ ! -e "$CASE_HOME/.claude" ] && [ ! -L "$CASE_HOME/.claude" ] || fail '.claude still exists'
  [ ! -e "$CASE_HOME/.codex" ] && [ ! -L "$CASE_HOME/.codex" ] || fail '.codex still exists'
}

find_transactions() {
  local candidate
  TX_COUNT=0
  TX_DIR=''
  TX_ID=''
  if [ -d "$CASE_STATE/dotfiles/transactions" ]; then
    for candidate in "$CASE_STATE/dotfiles/transactions"/*; do
      [ -d "$candidate" ] || continue
      TX_COUNT=$((TX_COUNT + 1))
      TX_DIR="$candidate"
    done
  fi
  if [ "$TX_COUNT" -eq 1 ]; then
    TX_ID="${TX_DIR##*/}"
  fi
}

find_transaction_for_module() {
  local wanted="$1"
  local candidate module
  TX_DIR=''
  TX_ID=''
  for candidate in "$CASE_STATE/dotfiles/transactions"/*; do
    [ -d "$candidate" ] || continue
    module="$(cat "$candidate/meta/module")"
    if [ "$module" = "$wanted" ]; then
      [ -z "$TX_DIR" ] || fail "more than one $wanted transaction found"
      TX_DIR="$candidate"
      TX_ID="${candidate##*/}"
    fi
  done
  [ -n "$TX_DIR" ] || fail "no $wanted transaction found"
}

mode_of() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

assert_mode() {
  local actual
  [ -e "$1" ] || fail "mode target is missing: $1"
  actual="$(mode_of "$1")"
  assert_equal "$2" "$actual"
}

assert_secure_receipt() {
  local path action_dir metadata
  for path in \
    "$CASE_STATE/dotfiles" \
    "$CASE_STATE/dotfiles/transactions" \
    "$TX_DIR" "$TX_DIR/meta" "$TX_DIR/actions" "$TX_DIR/backup"; do
    assert_mode "$path" 700
  done
  for action_dir in "$TX_DIR/actions"/*; do
    [ -d "$action_dir" ] || continue
    assert_mode "$action_dir" 700
  done
  metadata="$(find "$TX_DIR" -path "$TX_DIR/backup" -prune -o -type f ! -perm 0600 -print)"
  [ -z "$metadata" ] || fail "receipt metadata mode is not 0600: $metadata"
}

make_legacy_files() {
  mkdir -p "$CASE_HOME/.hermes" "$CASE_HOME/.openclaw/workspace-main"
  printf 'hermes user content\n' > "$CASE_HOME/.hermes/SOUL.md"
  printf 'openclaw user content\n' > "$CASE_HOME/.openclaw/workspace-main/AGENTS.md"
  cp "$CASE_HOME/.hermes/SOUL.md" "$CASE_ROOT/hermes-before"
  cp "$CASE_HOME/.openclaw/workspace-main/AGENTS.md" "$CASE_ROOT/openclaw-before"
}

assert_legacy_unchanged() {
  cmp -s "$CASE_ROOT/hermes-before" "$CASE_HOME/.hermes/SOUL.md" || fail 'Hermes post-config changed'
  cmp -s "$CASE_ROOT/openclaw-before" "$CASE_HOME/.openclaw/workspace-main/AGENTS.md" || fail 'OpenClaw post-config changed'
}

test_plan_and_dry_run_write_nothing() {
  new_case
  run_cli plan --only agents-links
  assert_success
  assert_output_contains "$CASE_HOME/.claude/CLAUDE.md"
  assert_output_contains "$CASE_HOME/.codex/AGENTS.md"
  assert_agent_paths_absent
  assert_no_transaction_state

  run_cli apply --only agents-links --dry-run
  assert_success
  assert_agent_paths_absent
  assert_no_transaction_state
}

test_clean_apply_creates_exact_parents_and_links() {
  new_case
  run_cli apply --only agents-links
  assert_success
  assert_agent_links
}

test_receipt_module_permissions_and_idempotence() {
  local first_tx
  new_case
  run_cli apply --only agents-links
  assert_success
  find_transactions
  [ "$TX_COUNT" -eq 1 ] || fail "found $TX_COUNT transactions, expected 1"
  first_tx="$TX_DIR"
  assert_equal agents-links "$(cat "$TX_DIR/meta/module")"
  assert_secure_receipt

  run_cli apply --only agents-links
  assert_success
  find_transactions
  [ "$TX_COUNT" -eq 1 ] || fail 'idempotent apply created a second transaction'
  assert_equal "$first_tx" "$TX_DIR"
}

test_second_target_conflict_preflights_before_first_change() {
  new_case
  mkdir -p "$CASE_HOME/.codex"
  printf 'user codex instructions\n' > "$CASE_HOME/.codex/AGENTS.md"

  run_cli apply --only agents-links
  assert_failure
  [ ! -e "$CASE_HOME/.claude" ] || fail 'first target changed before second-target conflict'
  assert_equal 'user codex instructions' "$(sed -n '1p' "$CASE_HOME/.codex/AGENTS.md")"
  assert_no_transaction_state
}

test_parent_symlink_to_directory_is_conflict() {
  local external
  new_case
  external="$CASE_ROOT/external claude"
  mkdir -p "$external"
  ln -s "$external" "$CASE_HOME/.claude"

  run_cli apply --only agents-links
  assert_failure
  [ -L "$CASE_HOME/.claude" ] || fail 'parent symlink changed type'
  assert_equal "$external" "$(readlink "$CASE_HOME/.claude")"
  [ ! -e "$CASE_HOME/.codex" ] || fail 'later target changed after parent conflict'
  assert_no_transaction_state
}

test_backup_and_rollback_restore_bytes_types_and_modes() {
  new_case
  mkdir -p "$CASE_HOME/.claude" "$CASE_HOME/.codex/AGENTS.md/nested"
  printf 'claude user bytes\n' > "$CASE_HOME/.claude/CLAUDE.md"
  printf 'codex directory bytes\n' > "$CASE_HOME/.codex/AGENTS.md/nested/payload"
  cp "$CASE_HOME/.claude/CLAUDE.md" "$CASE_ROOT/claude-before"
  cp "$CASE_HOME/.codex/AGENTS.md/nested/payload" "$CASE_ROOT/codex-before"
  chmod 0640 "$CASE_HOME/.claude/CLAUDE.md"
  chmod 0750 "$CASE_HOME/.codex/AGENTS.md"
  chmod 0604 "$CASE_HOME/.codex/AGENTS.md/nested/payload"

  run_cli apply --only agents-links --backup
  assert_success
  assert_agent_links
  find_transactions
  TX_ID="${TX_DIR##*/}"

  run_cli rollback "$TX_ID"
  assert_success
  cmp -s "$CASE_ROOT/claude-before" "$CASE_HOME/.claude/CLAUDE.md" || fail 'Claude bytes were not restored'
  cmp -s "$CASE_ROOT/codex-before" "$CASE_HOME/.codex/AGENTS.md/nested/payload" || fail 'Codex directory bytes were not restored'
  assert_mode "$CASE_HOME/.claude/CLAUDE.md" 640
  assert_mode "$CASE_HOME/.codex/AGENTS.md" 750
  assert_mode "$CASE_HOME/.codex/AGENTS.md/nested/payload" 604
}

test_clean_rollback_removes_links_and_empty_parents() {
  new_case
  run_cli apply --only agents-links
  assert_success
  find_transactions
  TX_ID="${TX_DIR##*/}"

  run_cli rollback "$TX_ID"
  assert_success
  assert_agent_paths_absent
}

test_parent_drift_refuses_rollback_without_partial_change() {
  new_case
  run_cli apply --only agents-links
  assert_success
  find_transactions
  TX_ID="${TX_DIR##*/}"
  printf 'unmanaged\n' > "$CASE_HOME/.claude/unmanaged.txt"

  run_cli rollback "$TX_ID"
  assert_failure
  assert_agent_links
  [ -f "$CASE_HOME/.claude/unmanaged.txt" ] || fail 'unmanaged drift file was removed'
}

test_doctor_aggregates_all_agents_link_errors() {
  new_case
  run_cli doctor --only agents-links
  assert_failure
  assert_error_contains "$CASE_HOME/.claude/CLAUDE.md"
  assert_error_contains "$CASE_HOME/.codex/AGENTS.md"
  assert_agent_paths_absent
  assert_no_transaction_state
}

test_default_apply_uses_fixed_order_and_separate_receipts() {
  new_case
  run_cli apply
  assert_success
  find_transactions
  [ "$TX_COUNT" -eq 2 ] || fail "default apply created $TX_COUNT transactions, expected 2"
  find_transaction_for_module bin
  find_transaction_for_module agents-links
  assert_agent_links

  run_cli doctor --only bin
  assert_success
  run_cli doctor --only agents-links
  assert_success
}

test_default_preflight_stops_bin_before_agents_conflict() {
  new_case
  mkdir -p "$CASE_HOME/.codex"
  printf 'user conflict\n' > "$CASE_HOME/.codex/AGENTS.md"

  run_cli apply
  assert_failure
  [ ! -e "$CASE_HOME/.local" ] || fail 'bin Module wrote before agents-links preflight failed'
  [ ! -e "$CASE_HOME/.claude" ] || fail 'agents-links wrote before complete preflight'
  assert_equal 'user conflict' "$(sed -n '1p' "$CASE_HOME/.codex/AGENTS.md")"
  assert_no_transaction_state
}

test_standalone_dry_run_and_help_skip_legacy_post_config() {
  new_case
  make_legacy_files

  run_agents_init --dry-run
  assert_success
  assert_legacy_unchanged
  assert_agent_paths_absent
  assert_no_transaction_state

  run_agents_init --help
  assert_success
  assert_legacy_unchanged
  assert_agent_paths_absent
  assert_no_transaction_state
}

test_standalone_link_conflict_skips_legacy_post_config() {
  new_case
  make_legacy_files
  mkdir -p "$CASE_HOME/.codex"
  printf 'user conflict\n' > "$CASE_HOME/.codex/AGENTS.md"

  run_agents_init
  assert_failure
  assert_legacy_unchanged
  [ ! -e "$CASE_HOME/.claude" ] || fail 'link preflight failure still created .claude'
  assert_equal 'user conflict' "$(sed -n '1p' "$CASE_HOME/.codex/AGENTS.md")"
  assert_no_transaction_state
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

printf '1..13\n'
run_test 'plan and dry-run write nothing' test_plan_and_dry_run_write_nothing
run_test 'clean apply creates exact real parents and links' test_clean_apply_creates_exact_parents_and_links
run_test 'receipt records Module securely and apply is idempotent' test_receipt_module_permissions_and_idempotence
run_test 'second target conflict aborts before first target changes' test_second_target_conflict_preflights_before_first_change
run_test 'parent symlink-to-directory is a conflict' test_parent_symlink_to_directory_is_conflict
run_test 'backup rollback restores bytes, types, and modes' test_backup_and_rollback_restore_bytes_types_and_modes
run_test 'clean rollback removes links and empty parents' test_clean_rollback_removes_links_and_empty_parents
run_test 'parent drift refuses rollback without partial change' test_parent_drift_refuses_rollback_without_partial_change
run_test 'Doctor aggregates both agents link errors' test_doctor_aggregates_all_agents_link_errors
run_test 'default apply uses fixed Modules and separate receipts' test_default_apply_uses_fixed_order_and_separate_receipts
run_test 'default preflight stops bin before an agents conflict' test_default_preflight_stops_bin_before_agents_conflict
run_test 'standalone dry-run and help skip legacy post-config' test_standalone_dry_run_and_help_skip_legacy_post_config
run_test 'standalone link conflict skips legacy post-config' test_standalone_link_conflict_skips_legacy_post_config

if [ "$FAILURES" -ne 0 ]; then
  printf '%d test(s) failed\n' "$FAILURES" >&2
  exit 1
fi

printf 'All transactional agents-links Module tests passed.\n'
