#!/usr/bin/env bash

# Dependency-free integration tests for the transactional bin Module.
# Compatible with the Bash 3.2 shipped by macOS.

set -u

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOTFILES="$ROOT/bin/dotfiles"
REAL_HOME="${HOME:-}"
ORIGINAL_TMPDIR="${TMPDIR:-/tmp}"

MANAGED_TOOLS='dotfiles
dotfiles-check
llm-instance
llm-wiki-git
llm-wiki-status
llm-wiki-commit
llm-wiki-lint
sn550-temp'

TEST_NUMBER=0
FAILURES=0

SUITE_ROOT="$(mktemp -d "$ORIGINAL_TMPDIR/dotfiles-transaction-tests.XXXXXX")" || {
  printf 'not ok - could not create test directory\n' >&2
  exit 1
}

cleanup() {
  case "$SUITE_ROOT" in
    "$ORIGINAL_TMPDIR"/dotfiles-transaction-tests.*)
      /bin/rm -rf "$SUITE_ROOT"
      ;;
    *)
      printf 'Refusing to remove unexpected test path: %s\n' "$SUITE_ROOT" >&2
      ;;
  esac
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf '  assertion failed: %s\n' "$1" >&2
  if [ -n "${CASE_OUT:-}" ] && [ -f "$CASE_OUT" ]; then
    printf '  stdout:\n' >&2
    sed 's/^/    /' "$CASE_OUT" >&2
  fi
  if [ -n "${CASE_ERR:-}" ] && [ -f "$CASE_ERR" ]; then
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
  local contents
  local needle
  needle="$1"
  contents="$(cat "$CASE_OUT")"
  case "$contents" in
    *"$needle"*) ;;
    *) fail "stdout does not contain [$needle]" ;;
  esac
}

assert_error_contains() {
  local contents
  local needle
  needle="$1"
  contents="$(cat "$CASE_ERR")"
  case "$contents" in
    *"$needle"*) ;;
    *) fail "stderr does not contain [$needle]" ;;
  esac
}

new_case() {
  CASE_ROOT="$SUITE_ROOT/case-$TEST_NUMBER"
  CASE_HOME="$CASE_ROOT/home with spaces"
  CASE_TMP="$CASE_ROOT/tmp with spaces"
  CASE_XDG_STATE="$CASE_ROOT/state with spaces"
  CASE_OUT="$CASE_ROOT/stdout"
  CASE_ERR="$CASE_ROOT/stderr"
  CASE_STATE_MODE=xdg
  CASE_STATE_BASE="$CASE_XDG_STATE"
  CASE_DOTFILES_STATE="$CASE_STATE_BASE/dotfiles"
  CASE_TRANSACTIONS="$CASE_DOTFILES_STATE/transactions"
  COMMAND_STATUS=0
  TX_COUNT=0
  TX_DIR=''
  TX_ID=''
  CASE_FAULT=''

  mkdir -p "$CASE_HOME" "$CASE_TMP"

  [ -n "$REAL_HOME" ] || fail 'the real HOME was empty before the test'
  [ "$CASE_HOME" != "$REAL_HOME" ] || fail 'temporary HOME equals the real HOME'
  case "$CASE_HOME" in
    "$SUITE_ROOT"/*) ;;
    *) fail 'temporary HOME escaped the test root' ;;
  esac
}

use_default_state_location() {
  CASE_STATE_MODE=default
  CASE_STATE_BASE="$CASE_HOME/.local/state"
  CASE_DOTFILES_STATE="$CASE_STATE_BASE/dotfiles"
  CASE_TRANSACTIONS="$CASE_DOTFILES_STATE/transactions"
}

run_cli() {
  : >"$CASE_OUT"
  : >"$CASE_ERR"

  if (
    export HOME="$CASE_HOME"
    export XDG_CONFIG_HOME="$CASE_ROOT/config with spaces"
    export XDG_DATA_HOME="$CASE_ROOT/data with spaces"
    export XDG_CACHE_HOME="$CASE_ROOT/cache with spaces"
    export TMPDIR="$CASE_TMP"
    export LC_ALL=C
    unset LLM_WIKI_DIR
    if [ -n "$CASE_FAULT" ]; then
      export DOTFILES_TEST_FAULT="$CASE_FAULT"
    else
      unset DOTFILES_TEST_FAULT
    fi
    if [ "$CASE_STATE_MODE" = xdg ]; then
      export XDG_STATE_HOME="$CASE_XDG_STATE"
    else
      unset XDG_STATE_HOME
    fi
    "$DOTFILES" "$@"
  ) >"$CASE_OUT" 2>"$CASE_ERR"; then
    COMMAND_STATUS=0
  else
    COMMAND_STATUS=$?
  fi
}

assert_home_empty() {
  local entries
  entries="$(find "$CASE_HOME" -mindepth 1 -print)"
  [ -z "$entries" ] || fail "temporary HOME was modified: $entries"
}

assert_state_absent() {
  [ ! -e "$CASE_DOTFILES_STATE" ] || fail "state was written at $CASE_DOTFILES_STATE"
}

assert_read_only_locations_untouched() {
  local path
  local temporary_entries

  for path in \
    "$CASE_XDG_STATE" \
    "$CASE_ROOT/config with spaces" \
    "$CASE_ROOT/data with spaces" \
    "$CASE_ROOT/cache with spaces"; do
    [ ! -e "$path" ] || fail "read-only command wrote $path"
  done

  temporary_entries="$(find "$CASE_TMP" -mindepth 1 -print)"
  [ -z "$temporary_entries" ] || fail "read-only command left temporary files: $temporary_entries"
}

assert_managed_link() {
  local tool
  local destination
  local expected
  local actual
  tool="$1"
  destination="$CASE_HOME/.local/bin/$tool"
  expected="$ROOT/bin/$tool"

  [ -L "$destination" ] || fail "$destination is not a symlink"
  actual="$(readlink "$destination")"
  assert_equal "$expected" "$actual"
}

assert_all_managed_links() {
  local tool
  local count
  local entry
  count=0

  for tool in $MANAGED_TOOLS; do
    assert_managed_link "$tool"
  done

  for entry in "$CASE_HOME/.local/bin"/*; do
    if [ -e "$entry" ] || [ -L "$entry" ]; then
      count=$((count + 1))
    fi
  done
  [ "$count" -eq 8 ] || fail "managed bin directory contains $count entries, expected 8"
}

assert_no_managed_entries() {
  local tool
  local destination
  for tool in $MANAGED_TOOLS; do
    destination="$CASE_HOME/.local/bin/$tool"
    if [ -e "$destination" ] || [ -L "$destination" ]; then
      fail "$destination still exists"
    fi
  done
}

find_transactions() {
  local candidate
  TX_COUNT=0
  TX_DIR=''
  TX_ID=''

  if [ -d "$CASE_TRANSACTIONS" ]; then
    for candidate in "$CASE_TRANSACTIONS"/*; do
      [ -d "$candidate" ] || continue
      TX_COUNT=$((TX_COUNT + 1))
      TX_DIR="$candidate"
    done
  fi

  if [ "$TX_COUNT" -eq 1 ]; then
    TX_ID="${TX_DIR##*/}"
  fi
}

assert_one_transaction() {
  find_transactions
  [ "$TX_COUNT" -eq 1 ] || fail "found $TX_COUNT transactions, expected 1"
  [ -n "$TX_ID" ] || fail 'transaction has no discoverable ID'
}

mode_of() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

assert_mode() {
  local path
  local expected
  local actual
  path="$1"
  expected="$2"
  [ -e "$path" ] || fail "mode check target is missing: $path"
  actual="$(mode_of "$path")"
  assert_equal "$expected" "$actual"
}

assert_secure_transaction_state() {
  local action_dir
  local insecure_metadata
  local insecure_dirs
  local metadata_files

  for insecure_dirs in \
    "$CASE_DOTFILES_STATE" \
    "$CASE_TRANSACTIONS" \
    "$TX_DIR" \
    "$TX_DIR/meta" \
    "$TX_DIR/actions" \
    "$TX_DIR/backup"; do
    assert_mode "$insecure_dirs" 700
  done

  for action_dir in "$TX_DIR/actions"/*; do
    [ -d "$action_dir" ] || continue
    assert_mode "$action_dir" 700
  done

  insecure_metadata="$(find "$TX_DIR" -path "$TX_DIR/backup" -prune -o -type f ! -perm 0600 -print)"
  [ -z "$insecure_metadata" ] || fail "transaction metadata is not mode 0600: $insecure_metadata"

  metadata_files="$(find "$TX_DIR" -path "$TX_DIR/backup" -prune -o -type f -print)"
  [ -n "$metadata_files" ] || fail 'transaction contains no regular metadata files'
  assert_equal 1 "$(cat "$TX_DIR/meta/schema_version")"
}

make_conflicts() {
  mkdir -p "$CASE_HOME/.local/bin/dotfiles-check/nested"
  printf 'user file bytes\nsecond line without expansion\n' >"$CASE_HOME/.local/bin/dotfiles"
  cp "$CASE_HOME/.local/bin/dotfiles" "$CASE_ROOT/original user file"
  printf 'directory payload\n' >"$CASE_HOME/.local/bin/dotfiles-check/nested/payload"
  cp "$CASE_HOME/.local/bin/dotfiles-check/nested/payload" "$CASE_ROOT/original directory payload"
  printf 'unrelated symlink target\n' >"$CASE_ROOT/user target"
  ln -s "$CASE_ROOT/user target" "$CASE_HOME/.local/bin/llm-instance"
  chmod 0640 "$CASE_HOME/.local/bin/dotfiles"
  chmod 0750 "$CASE_HOME/.local/bin/dotfiles-check"
  chmod 0710 "$CASE_HOME/.local/bin/dotfiles-check/nested"
  chmod 0604 "$CASE_HOME/.local/bin/dotfiles-check/nested/payload"
}

assert_conflicts_unchanged() {
  local actual_target
  [ -f "$CASE_HOME/.local/bin/dotfiles" ] || fail 'regular-file conflict changed type'
  [ ! -L "$CASE_HOME/.local/bin/dotfiles" ] || fail 'regular-file conflict became a symlink'
  cmp -s "$CASE_ROOT/original user file" "$CASE_HOME/.local/bin/dotfiles" || fail 'regular-file conflict bytes changed'
  assert_mode "$CASE_HOME/.local/bin/dotfiles" 640

  [ -d "$CASE_HOME/.local/bin/dotfiles-check" ] || fail 'directory conflict changed type'
  [ ! -L "$CASE_HOME/.local/bin/dotfiles-check" ] || fail 'directory conflict became a symlink'
  cmp -s "$CASE_ROOT/original directory payload" "$CASE_HOME/.local/bin/dotfiles-check/nested/payload" || fail 'directory conflict bytes changed'
  assert_mode "$CASE_HOME/.local/bin/dotfiles-check" 750
  assert_mode "$CASE_HOME/.local/bin/dotfiles-check/nested" 710
  assert_mode "$CASE_HOME/.local/bin/dotfiles-check/nested/payload" 604

  [ -L "$CASE_HOME/.local/bin/llm-instance" ] || fail 'symlink conflict changed type'
  actual_target="$(readlink "$CASE_HOME/.local/bin/llm-instance")"
  assert_equal "$CASE_ROOT/user target" "$actual_target"
}

assert_nonconflicting_links_absent() {
  local tool
  local destination
  for tool in llm-wiki-git llm-wiki-status llm-wiki-commit llm-wiki-lint; do
    destination="$CASE_HOME/.local/bin/$tool"
    if [ -e "$destination" ] || [ -L "$destination" ]; then
      fail "$destination was created despite a preflight conflict"
    fi
  done
}

test_plan_and_apply_dry_run_write_nothing() {
  local tool
  new_case

  run_cli plan --only bin
  assert_success
  for tool in $MANAGED_TOOLS; do
    assert_output_contains "$CASE_HOME/.local/bin/$tool"
  done
  assert_home_empty
  assert_state_absent
  assert_read_only_locations_untouched

  run_cli apply --only bin --dry-run
  assert_success
  for tool in $MANAGED_TOOLS; do
    assert_output_contains "$CASE_HOME/.local/bin/$tool"
  done
  assert_home_empty
  assert_state_absent
  assert_read_only_locations_untouched
}

test_backup_plan_and_dry_run_preserve_conflicts() {
  new_case
  make_conflicts

  run_cli plan --only bin --backup
  assert_success
  assert_conflicts_unchanged
  assert_nonconflicting_links_absent
  assert_state_absent
  assert_read_only_locations_untouched

  run_cli apply --only bin --backup --dry-run
  assert_success
  assert_conflicts_unchanged
  assert_nonconflicting_links_absent
  assert_state_absent
  assert_read_only_locations_untouched
}

test_apply_creates_exact_links_and_secure_receipt() {
  local first_tx_id
  new_case
  use_default_state_location

  run_cli apply --only bin
  assert_success
  assert_all_managed_links
  assert_one_transaction
  first_tx_id="$TX_ID"
  assert_secure_transaction_state

  run_cli history
  assert_success
  assert_output_contains "$first_tx_id"

  run_cli doctor --only bin
  assert_success

  run_cli apply --only bin
  assert_success
  assert_all_managed_links
  find_transactions
  [ "$TX_COUNT" -eq 1 ] || fail "idempotent apply created $TX_COUNT transactions"
  assert_equal "$first_tx_id" "$TX_ID"
}

test_doctor_is_read_only_and_detects_missing_links() {
  local history_before
  local history_after
  new_case

  run_cli doctor --only bin
  assert_failure
  assert_home_empty
  assert_state_absent
  assert_read_only_locations_untouched

  run_cli apply --only bin
  assert_success

  run_cli history
  assert_success
  history_before="$(cat "$CASE_OUT")"

  run_cli doctor --only bin
  assert_success
  assert_all_managed_links

  run_cli history
  assert_success
  history_after="$(cat "$CASE_OUT")"
  assert_equal "$history_before" "$history_after"
}

test_conflicts_abort_before_any_change() {
  new_case
  make_conflicts

  run_cli apply --only bin
  assert_failure
  assert_conflicts_unchanged
  assert_nonconflicting_links_absent
  assert_state_absent
  assert_read_only_locations_untouched
}

test_symlink_to_directory_is_a_conflict() {
  local external
  local actual
  new_case
  external="$CASE_ROOT/user local directory"
  mkdir -p "$external"
  ln -s "$external" "$CASE_HOME/.local"

  run_cli plan --only bin
  assert_failure
  [ -L "$CASE_HOME/.local" ] || fail 'directory symlink changed type during plan'
  actual="$(readlink "$CASE_HOME/.local")"
  assert_equal "$external" "$actual"
  assert_state_absent

  run_cli apply --only bin
  assert_failure
  [ -L "$CASE_HOME/.local" ] || fail 'directory symlink changed type during apply preflight'
  actual="$(readlink "$CASE_HOME/.local")"
  assert_equal "$external" "$actual"
  assert_state_absent

  run_cli plan --only bin --backup
  assert_success
  assert_output_contains "BACKUP"
  [ -L "$CASE_HOME/.local" ] || fail 'backup plan changed directory symlink'
  assert_state_absent
}

test_backup_and_explicit_rollback_restore_bytes_types_and_modes() {
  local applied_tx_id
  local tool
  new_case
  make_conflicts

  run_cli apply --only bin --backup
  assert_success
  assert_all_managed_links
  assert_one_transaction
  applied_tx_id="$TX_ID"
  assert_secure_transaction_state

  run_cli rollback "$applied_tx_id"
  assert_success
  assert_conflicts_unchanged
  for tool in llm-wiki-git llm-wiki-status llm-wiki-commit llm-wiki-lint; do
    if [ -e "$CASE_HOME/.local/bin/$tool" ] || [ -L "$CASE_HOME/.local/bin/$tool" ]; then
      fail "$tool was not removed by rollback"
    fi
  done
}

test_rollback_dry_run_writes_nothing() {
  local applied_tx_id
  local history_before
  local history_after
  new_case

  run_cli apply --only bin
  assert_success
  assert_one_transaction
  applied_tx_id="$TX_ID"

  run_cli history
  assert_success
  history_before="$(cat "$CASE_OUT")"

  run_cli rollback "$applied_tx_id" --dry-run
  assert_success
  assert_all_managed_links
  find_transactions
  [ "$TX_COUNT" -eq 1 ] || fail 'rollback dry-run changed transaction count'

  run_cli history
  assert_success
  history_after="$(cat "$CASE_OUT")"
  assert_equal "$history_before" "$history_after"
}

test_rollback_last_removes_created_links() {
  new_case

  run_cli apply --only bin
  assert_success
  assert_all_managed_links

  run_cli rollback --last
  assert_success
  assert_no_managed_entries
}

test_rollback_rejects_ambiguous_selector_without_changes() {
  local applied_tx_id
  local history_before
  local history_after
  new_case

  run_cli apply --only bin
  assert_success
  assert_one_transaction
  applied_tx_id="$TX_ID"

  run_cli history
  assert_success
  history_before="$(cat "$CASE_OUT")"

  run_cli rollback "$applied_tx_id" --last
  assert_failure
  assert_all_managed_links

  run_cli rollback --last "$applied_tx_id"
  assert_failure
  assert_all_managed_links

  run_cli history
  assert_success
  history_after="$(cat "$CASE_OUT")"
  assert_equal "$history_before" "$history_after"
}

test_recover_interrupted_apply_after_backup_move() {
  local interrupted_tx_id
  new_case
  make_conflicts

  CASE_FAULT=after_backup_move
  run_cli apply --only bin --backup
  assert_failure
  CASE_FAULT=''
  assert_one_transaction
  interrupted_tx_id="$TX_ID"

  run_cli rollback "$interrupted_tx_id"
  assert_success
  assert_conflicts_unchanged
  assert_nonconflicting_links_absent
}

test_recover_interrupted_apply_after_target_creation() {
  local interrupted_tx_id
  new_case

  CASE_FAULT=after_target_creation
  run_cli apply --only bin
  assert_failure
  CASE_FAULT=''
  assert_one_transaction
  interrupted_tx_id="$TX_ID"

  run_cli rollback "$interrupted_tx_id"
  assert_success
  assert_home_empty
}

test_retry_partial_rollback_from_rollback_failed() {
  local applied_tx_id
  new_case

  run_cli apply --only bin
  assert_success
  assert_one_transaction
  applied_tx_id="$TX_ID"

  CASE_FAULT=during_partial_rollback
  run_cli rollback "$applied_tx_id"
  assert_failure
  CASE_FAULT=''

  run_cli history
  assert_success
  assert_output_contains "rollback_failed"

  run_cli rollback "$applied_tx_id"
  assert_success
  assert_no_managed_entries
}

test_doctor_enforces_transaction_status_allowlist() {
  local status
  new_case

  run_cli apply --only bin
  assert_success
  assert_one_transaction

  for status in applying rolling_back rollback_failed unknown_status; do
    printf '%s\n' "$status" >"$TX_DIR/meta/status"
    run_cli doctor --only bin
    assert_failure
    assert_equal "$status" "$(cat "$TX_DIR/meta/status")"
  done

  for status in applied rolled_back failed_rolled_back; do
    printf '%s\n' "$status" >"$TX_DIR/meta/status"
    run_cli doctor --only bin
    assert_success
    assert_equal "$status" "$(cat "$TX_DIR/meta/status")"
  done
}

test_doctor_rejects_malformed_transaction_receipts() {
  local action_dir
  local original_module
  local original_operation
  local original_phase
  new_case

  run_cli apply --only bin
  assert_success
  assert_one_transaction
  action_dir="$(find "$TX_DIR/actions" -mindepth 1 -maxdepth 1 -type d -print | sort | head -n 1)"
  [ -n "$action_dir" ] || fail 'transaction has no action to corrupt'

  original_phase="$(cat "$action_dir/phase")"
  printf 'unknown_phase\n' >"$action_dir/phase"
  run_cli doctor --only bin
  assert_failure
  printf '%s\n' "$original_phase" >"$action_dir/phase"

  original_operation="$(cat "$action_dir/operation")"
  printf 'unknown_operation\n' >"$action_dir/operation"
  run_cli doctor --only bin
  assert_failure
  printf '%s\n' "$original_operation" >"$action_dir/operation"

  original_module="$(cat "$TX_DIR/meta/module")"
  /bin/rm "$TX_DIR/meta/module"
  run_cli doctor --only bin
  assert_failure
  printf '%s\n' "$original_module" >"$TX_DIR/meta/module"
  chmod 0600 "$TX_DIR/meta/module"

  printf '2\n' >"$TX_DIR/meta/schema_version"
  run_cli doctor --only bin
  assert_failure
  printf '1\n' >"$TX_DIR/meta/schema_version"

  mkdir "$TX_DIR/actions/not-an-action"
  chmod 0700 "$TX_DIR/actions/not-an-action"
  run_cli doctor --only bin
  assert_failure
  assert_all_managed_links
}

test_legacy_receipt_without_schema_remains_usable() {
  local applied_tx_id
  new_case

  run_cli apply --only bin
  assert_success
  assert_one_transaction
  applied_tx_id="$TX_ID"
  /bin/rm "$TX_DIR/meta/schema_version"

  run_cli doctor --only bin
  assert_success
  run_cli rollback "$applied_tx_id"
  assert_success
  assert_no_managed_entries
}

test_interrupted_apply_recovery_refuses_drift() {
  local interrupted_tx_id
  local history_before
  local history_after
  new_case
  mkdir -p "$CASE_HOME/.local/bin"

  CASE_FAULT=after_target_creation
  run_cli apply --only bin
  assert_failure
  CASE_FAULT=''
  assert_one_transaction
  interrupted_tx_id="$TX_ID"

  /bin/rm "$CASE_HOME/.local/bin/dotfiles"
  printf 'user replacement after interrupted apply\n' >"$CASE_HOME/.local/bin/dotfiles"
  run_cli history
  assert_success
  history_before="$(cat "$CASE_OUT")"

  run_cli rollback "$interrupted_tx_id"
  assert_failure
  [ -f "$CASE_HOME/.local/bin/dotfiles" ] || fail 'drifted interrupted target changed type'
  assert_equal 'user replacement after interrupted apply' "$(cat "$CASE_HOME/.local/bin/dotfiles")"

  run_cli history
  assert_success
  history_after="$(cat "$CASE_OUT")"
  assert_equal "$history_before" "$history_after"
}

test_partial_rollback_retry_refuses_drift_on_completed_action() {
  local applied_tx_id
  local restored_target
  new_case

  run_cli apply --only bin
  assert_success
  assert_one_transaction
  applied_tx_id="$TX_ID"

  CASE_FAULT=during_partial_rollback
  run_cli rollback "$applied_tx_id"
  assert_failure
  CASE_FAULT=''

  restored_target="$CASE_HOME/.local/bin/sn550-temp"
  [ ! -e "$restored_target" ] && [ ! -L "$restored_target" ] || fail 'fault did not finish the expected first rollback action'
  ln -s "$ROOT/bin/sn550-temp" "$restored_target"

  run_cli rollback "$applied_tx_id"
  assert_failure
  assert_all_managed_links

  run_cli history
  assert_success
  assert_output_contains "rollback_failed"
}

test_rollback_last_refuses_same_second_ambiguity() {
  local history_before
  local history_after
  local tx_dir
  new_case

  run_cli apply --only bin
  assert_success
  run_cli apply --only agents-links
  assert_success
  find_transactions
  [ "$TX_COUNT" -eq 2 ] || fail "found $TX_COUNT transactions, expected 2"

  for tx_dir in "$CASE_TRANSACTIONS"/*; do
    [ -d "$tx_dir" ] || continue
    printf '20260710T000000Z\n' >"$tx_dir/meta/started_at"
  done
  run_cli history
  assert_success
  history_before="$(cat "$CASE_OUT")"

  run_cli rollback --last
  assert_failure
  assert_all_managed_links
  [ -L "$CASE_HOME/.claude/CLAUDE.md" ] || fail 'ambiguous --last changed Claude link'
  [ -L "$CASE_HOME/.codex/AGENTS.md" ] || fail 'ambiguous --last changed Codex link'

  run_cli history
  assert_success
  history_after="$(cat "$CASE_OUT")"
  assert_equal "$history_before" "$history_after"
}

test_rollback_refuses_drift_without_partial_changes() {
  local applied_tx_id
  local tool
  local history_before
  local history_after
  new_case

  run_cli apply --only bin
  assert_success
  assert_one_transaction
  applied_tx_id="$TX_ID"

  run_cli history
  assert_success
  history_before="$(cat "$CASE_OUT")"

  /bin/rm "$CASE_HOME/.local/bin/dotfiles"
  printf 'user changed this after apply\n' >"$CASE_HOME/.local/bin/dotfiles"

  run_cli rollback "$applied_tx_id"
  assert_failure
  [ -f "$CASE_HOME/.local/bin/dotfiles" ] || fail 'drifted path changed type'
  [ ! -L "$CASE_HOME/.local/bin/dotfiles" ] || fail 'drifted path was overwritten'
  assert_equal 'user changed this after apply' "$(sed -n '1p' "$CASE_HOME/.local/bin/dotfiles")"

  for tool in dotfiles-check llm-instance llm-wiki-git llm-wiki-status llm-wiki-commit llm-wiki-lint sn550-temp; do
    assert_managed_link "$tool"
  done

  run_cli history
  assert_success
  history_after="$(cat "$CASE_OUT")"
  assert_equal "$history_before" "$history_after"
}

test_parallel_apply_is_serialized() {
  local first_out first_err first_pid attempts
  new_case
  first_out="$CASE_ROOT/first-stdout"
  first_err="$CASE_ROOT/first-stderr"

  (
    export HOME="$CASE_HOME"
    export XDG_CONFIG_HOME="$CASE_ROOT/config with spaces"
    export XDG_DATA_HOME="$CASE_ROOT/data with spaces"
    export XDG_CACHE_HOME="$CASE_ROOT/cache with spaces"
    export XDG_STATE_HOME="$CASE_XDG_STATE"
    export TMPDIR="$CASE_TMP"
    export LC_ALL=C
    export DOTFILES_TEST_WRITER_LOCK_HOLD=2
    unset LLM_WIKI_DIR
    "$DOTFILES" apply --only bin
  ) >"$first_out" 2>"$first_err" &
  first_pid=$!

  attempts=0
  while [ ! -f "$CASE_DOTFILES_STATE/write.lock/pid" ]; do
    if ! kill -0 "$first_pid" 2>/dev/null; then
      fail "first apply exited before acquiring writer lock: $(cat "$first_err")"
    fi
    attempts=$((attempts + 1))
    [ "$attempts" -lt 100 ] || fail 'timed out waiting for writer lock'
    sleep 0.05
  done

  run_cli apply --only bin
  assert_failure
  assert_error_contains 'another dotfiles writer is active'

  if ! wait "$first_pid"; then
    fail "first apply failed: $(cat "$first_err")"
  fi
  assert_all_managed_links
  find_transactions
  [ "$TX_COUNT" -eq 1 ] || fail "parallel apply created $TX_COUNT transactions"
  [ ! -e "$CASE_DOTFILES_STATE/write.lock" ] || fail 'writer lock remained after apply'
}

test_active_writer_blocks_rollback() {
  new_case
  run_cli apply --only bin
  assert_success
  assert_one_transaction

  mkdir "$CASE_DOTFILES_STATE/write.lock"
  printf '%s\n' "$$" > "$CASE_DOTFILES_STATE/write.lock/pid"
  printf '%s\n' apply > "$CASE_DOTFILES_STATE/write.lock/command"
  printf '%s\n' 20260711T000000Z > "$CASE_DOTFILES_STATE/write.lock/started_at"
  chmod 700 "$CASE_DOTFILES_STATE/write.lock"
  chmod 600 "$CASE_DOTFILES_STATE/write.lock/"*

  run_cli rollback "$TX_ID"
  assert_failure
  assert_error_contains 'another dotfiles writer is active'
  assert_all_managed_links
  assert_equal applied "$(cat "$TX_DIR/meta/status")"

  command rm -f "$CASE_DOTFILES_STATE/write.lock/pid" \
    "$CASE_DOTFILES_STATE/write.lock/command" \
    "$CASE_DOTFILES_STATE/write.lock/started_at"
  rmdir "$CASE_DOTFILES_STATE/write.lock"
}

test_sn550_temp_resolves_and_formats_report() {
  local fake_bin
  local fake_volume
  new_case
  fake_bin="$CASE_ROOT/fake-bin"
  fake_volume="$CASE_ROOT/SN550"
  mkdir -p "$fake_bin" "$fake_volume"

  printf '%s\n' \
    '#!/bin/sh' \
    'case "$2" in' \
    '  */SN550) printf "   APFS Physical Store:       disk4s3\\n" ;;' \
    '  /dev/disk4s3) printf "   Part of Whole:             disk4\\n" ;;' \
    '  /dev/disk4) printf "   Device / Media Name:       WDC WDS100T2B0C-00PXH0\\n" ;;' \
    '  *) exit 1 ;;' \
    'esac' >"$fake_bin/diskutil"
  printf '%s\n' \
    '#!/bin/sh' \
    'cat <<EOF' \
    'SMART overall-health self-assessment test result: PASSED' \
    'Temperature:                        52 Celsius' \
    'Warning  Comp. Temperature Time:    10' \
    'Critical Comp. Temperature Time:    0' \
    'EOF' >"$fake_bin/smartctl"
  printf '%s\n' '#!/bin/sh' 'echo "sudo should not run" >&2' 'exit 99' >"$fake_bin/sudo"
  chmod 0755 "$fake_bin/diskutil" "$fake_bin/smartctl" "$fake_bin/sudo"

  : >"$CASE_OUT"
  : >"$CASE_ERR"
  if (
    export DISKUTIL_BIN="$fake_bin/diskutil"
    export SMARTCTL_BIN="$fake_bin/smartctl"
    export SUDO_BIN="$fake_bin/sudo"
    "$ROOT/bin/sn550-temp" --volume "$fake_volume"
  ) >"$CASE_OUT" 2>"$CASE_ERR"; then
    COMMAND_STATUS=0
  else
    COMMAND_STATUS=$?
  fi

  assert_success
  assert_output_contains 'SN550 (/dev/disk4, WDC WDS100T2B0C-00PXH0)'
  assert_output_contains 'Temperature: 52 Celsius'
  assert_output_contains 'SMART health: PASSED'
  assert_output_contains 'Warning-temperature time: 10 min'
  assert_output_contains 'Critical-temperature time: 0 min'
}

test_sn550_temp_retries_with_sudo_after_permission_failure() {
  local fake_bin
  local fake_volume
  new_case
  fake_bin="$CASE_ROOT/fake-bin"
  fake_volume="$CASE_ROOT/SN550"
  mkdir -p "$fake_bin" "$fake_volume"

  printf '%s\n' \
    '#!/bin/sh' \
    'case "$2" in' \
    '  */SN550) printf "   APFS Physical Store:       disk4s3\\n" ;;' \
    '  /dev/disk4s3) printf "   Part of Whole:             disk4\\n" ;;' \
    '  /dev/disk4) printf "   Device / Media Name:       WDC WDS100T2B0C-00PXH0\\n" ;;' \
    '  *) exit 1 ;;' \
    'esac' >"$fake_bin/diskutil"
  printf '%s\n' \
    '#!/bin/sh' \
    'if [ "${SN550_TEST_SUDO:-}" != 1 ]; then' \
    '  echo "smartctl: Permission denied" >&2' \
    '  exit 2' \
    'fi' \
    'printf "Temperature:                        53 Celsius\\n"' >"$fake_bin/smartctl"
  printf '%s\n' \
    '#!/bin/sh' \
    'export SN550_TEST_SUDO=1' \
    'exec "$@"' >"$fake_bin/sudo"
  chmod 0755 "$fake_bin/diskutil" "$fake_bin/smartctl" "$fake_bin/sudo"

  : >"$CASE_OUT"
  : >"$CASE_ERR"
  if (
    export DISKUTIL_BIN="$fake_bin/diskutil"
    export SMARTCTL_BIN="$fake_bin/smartctl"
    export SUDO_BIN="$fake_bin/sudo"
    "$ROOT/bin/sn550-temp" --volume "$fake_volume"
  ) >"$CASE_OUT" 2>"$CASE_ERR"; then
    COMMAND_STATUS=0
  else
    COMMAND_STATUS=$?
  fi

  assert_success
  assert_output_contains 'Temperature: 53 Celsius'
}

test_sn550_temp_refuses_an_unexpected_device() {
  local fake_bin
  new_case
  fake_bin="$CASE_ROOT/fake-bin"
  mkdir -p "$fake_bin"

  printf '%s\n' \
    '#!/bin/sh' \
    'printf "   Device / Media Name:       Unknown NVMe\\n"' >"$fake_bin/diskutil"
  printf '%s\n' '#!/bin/sh' 'exit 99' >"$fake_bin/smartctl"
  chmod 0755 "$fake_bin/diskutil" "$fake_bin/smartctl"

  : >"$CASE_OUT"
  : >"$CASE_ERR"
  if (
    export DISKUTIL_BIN="$fake_bin/diskutil"
    export SMARTCTL_BIN="$fake_bin/smartctl"
    "$ROOT/bin/sn550-temp" --device /dev/disk9
  ) >"$CASE_OUT" 2>"$CASE_ERR"; then
    COMMAND_STATUS=0
  else
    COMMAND_STATUS=$?
  fi

  assert_failure
  assert_equal 65 "$COMMAND_STATUS"
  assert_error_contains 'refusing unexpected device /dev/disk9 (Unknown NVMe)'
}

run_test() {
  local name
  local function_name
  name="$1"
  function_name="$2"
  TEST_NUMBER=$((TEST_NUMBER + 1))

  if ( "$function_name" ); then
    printf 'ok %d - %s\n' "$TEST_NUMBER" "$name"
  else
    printf 'not ok %d - %s\n' "$TEST_NUMBER" "$name"
    FAILURES=$((FAILURES + 1))
  fi
}

if [ ! -x "$DOTFILES" ]; then
  printf 'not ok - dotfiles CLI is not executable: %s\n' "$DOTFILES" >&2
  exit 1
fi

printf '1..25\n'
run_test 'plan and apply dry-run write nothing' test_plan_and_apply_dry_run_write_nothing
run_test 'backup plan and dry-run preserve conflicts' test_backup_plan_and_dry_run_preserve_conflicts
run_test 'apply creates exact links and secure receipt' test_apply_creates_exact_links_and_secure_receipt
run_test 'doctor is read-only and detects missing links' test_doctor_is_read_only_and_detects_missing_links
run_test 'conflicts abort before any change' test_conflicts_abort_before_any_change
run_test 'symlink-to-directory is a conflict, not a managed directory' test_symlink_to_directory_is_a_conflict
run_test 'backup and explicit rollback restore bytes, types, and modes' test_backup_and_explicit_rollback_restore_bytes_types_and_modes
run_test 'rollback dry-run writes nothing' test_rollback_dry_run_writes_nothing
run_test 'rollback --last removes created links' test_rollback_last_removes_created_links
run_test 'rollback rejects ambiguous selectors without changes' test_rollback_rejects_ambiguous_selector_without_changes
run_test 'rollback recovers an apply interrupted after backup move' test_recover_interrupted_apply_after_backup_move
run_test 'rollback recovers an apply interrupted after target creation' test_recover_interrupted_apply_after_target_creation
run_test 'rollback retries a partially completed rollback' test_retry_partial_rollback_from_rollback_failed
run_test 'doctor enforces the transaction status allowlist' test_doctor_enforces_transaction_status_allowlist
run_test 'doctor rejects malformed transaction receipts' test_doctor_rejects_malformed_transaction_receipts
run_test 'legacy receipts without schema remain usable' test_legacy_receipt_without_schema_remains_usable
run_test 'interrupted apply recovery refuses drift' test_interrupted_apply_recovery_refuses_drift
run_test 'partial rollback retry refuses drift on a completed action' test_partial_rollback_retry_refuses_drift_on_completed_action
run_test 'rollback --last refuses same-second ambiguity' test_rollback_last_refuses_same_second_ambiguity
run_test 'rollback refuses drift without partial changes' test_rollback_refuses_drift_without_partial_changes
run_test 'parallel apply is serialized by the writer lock' test_parallel_apply_is_serialized
run_test 'an active writer blocks rollback before mutation' test_active_writer_blocks_rollback
run_test 'sn550-temp resolves the physical disk and formats SMART data' test_sn550_temp_resolves_and_formats_report
run_test 'sn550-temp retries with sudo after a permission failure' test_sn550_temp_retries_with_sudo_after_permission_failure
run_test 'sn550-temp refuses an unexpected physical device' test_sn550_temp_refuses_an_unexpected_device

if [ "$FAILURES" -ne 0 ]; then
  printf '%d test(s) failed\n' "$FAILURES" >&2
  exit 1
fi

printf 'All transactional bin Module tests passed.\n'
