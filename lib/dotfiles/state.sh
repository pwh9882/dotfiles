#!/usr/bin/env bash

# Transaction-controlled filesystem primitives.
# Sourced by runtime.sh; do not execute directly.

df_info() {
  printf '%-8s %s\n' "$1" "$2"
}

df_error() {
  printf '%-8s %s\n' "FAIL" "$1" >&2
}

df_validate_path() {
  local path="$1"
  case "$path" in
    /*) ;;
    *) df_error "managed path must be absolute: $path"; return 1 ;;
  esac
  case "$path" in
    *$'\n'*|*$'\t'*) df_error "managed path contains a tab or newline"; return 1 ;;
  esac
}

df_path_type() {
  local path="$1"
  if [ -L "$path" ]; then
    printf '%s\n' symlink
  elif [ -f "$path" ]; then
    printf '%s\n' file
  elif [ -d "$path" ]; then
    printf '%s\n' directory
  elif [ -e "$path" ]; then
    printf '%s\n' other
  else
    printf '%s\n' absent
  fi
}

df_link_is_expected() {
  local source="$1"
  local target="$2"
  [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]
}

df_mode_of() {
  local path="$1"
  if stat -f '%Lp' "$path" >/dev/null 2>&1; then
    stat -f '%Lp' "$path"
  else
    stat -c '%a' "$path"
  fi
}

df_atomic_write() {
  local path="$1"
  local value="$2"
  local tmp="${path}.tmp.$$"
  umask 077
  printf '%s\n' "$value" > "$tmp" || return 1
  chmod 600 "$tmp" || return 1
  mv -f "$tmp" "$path"
}

df_state_init_paths() {
  DF_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
  DF_STATE_DIR="$DF_STATE_HOME/dotfiles"
  DF_TX_ROOT="$DF_STATE_DIR/transactions"
}

df_tx_begin() {
  local module="$1"
  local now
  local revision
  case "$module" in
    ''|*[!a-z0-9-]*|-*|*-|*--*)
      df_error "invalid transaction Module name: $module"
      return 1
      ;;
  esac
  now="$(date -u '+%Y%m%dT%H%M%SZ')"
  DF_TX_ID="${now}-$$-${RANDOM}"
  DF_TX_DIR="$DF_TX_ROOT/$DF_TX_ID"
  DF_ACTION_SEQ=0

  umask 077
  mkdir -p "$DF_TX_DIR/meta" "$DF_TX_DIR/actions" "$DF_TX_DIR/backup" || return 1
  chmod 700 "$DF_STATE_DIR" "$DF_TX_ROOT" "$DF_TX_DIR" \
    "$DF_TX_DIR/meta" "$DF_TX_DIR/actions" "$DF_TX_DIR/backup" || return 1

  revision="$(git -C "$DF_ROOT" rev-parse --verify HEAD 2>/dev/null || printf 'unknown')"
  df_atomic_write "$DF_TX_DIR/meta/id" "$DF_TX_ID" || return 1
  df_atomic_write "$DF_TX_DIR/meta/module" "$module" || return 1
  df_atomic_write "$DF_TX_DIR/meta/repo_revision" "$revision" || return 1
  df_atomic_write "$DF_TX_DIR/meta/started_at" "$now" || return 1
  df_atomic_write "$DF_TX_DIR/meta/status" "applying" || return 1
}

df_tx_set_status() {
  local tx_dir="$1"
  local status="$2"
  df_atomic_write "$tx_dir/meta/status" "$status"
}

df_tx_prepare_action() {
  local operation="$1"
  local target="$2"
  local source="$3"
  local before_type="$4"
  local backup_rel="$5"
  local seq

  DF_ACTION_SEQ=$((DF_ACTION_SEQ + 1))
  seq="$(printf '%06d' "$DF_ACTION_SEQ")"
  DF_CURRENT_ACTION_DIR="$DF_TX_DIR/actions/$seq"
  mkdir "$DF_CURRENT_ACTION_DIR" || return 1
  chmod 700 "$DF_CURRENT_ACTION_DIR" || return 1
  df_atomic_write "$DF_CURRENT_ACTION_DIR/operation" "$operation" || return 1
  df_atomic_write "$DF_CURRENT_ACTION_DIR/target" "$target" || return 1
  df_atomic_write "$DF_CURRENT_ACTION_DIR/source" "$source" || return 1
  df_atomic_write "$DF_CURRENT_ACTION_DIR/before_type" "$before_type" || return 1
  df_atomic_write "$DF_CURRENT_ACTION_DIR/backup_relpath" "$backup_rel" || return 1
  df_atomic_write "$DF_CURRENT_ACTION_DIR/phase" "prepared" || return 1
}

df_tx_set_phase() {
  local action_dir="$1"
  local phase="$2"
  df_atomic_write "$action_dir/phase" "$phase"
}

# Test-only crash seam. The production path is a no-op unless a test process
# explicitly exports DOTFILES_TEST_FAULT.
df_fault_inject() {
  [ "${DOTFILES_TEST_FAULT:-}" = "$1" ] || return 0
  exit 97
}

df_fault_inject_failure() {
  [ "${DOTFILES_TEST_FAULT:-}" = "$1" ] || return 0
  return 97
}

df_next_backup_relpath() {
  printf 'backup/%06d' "$((DF_ACTION_SEQ + 1))"
}

df_dir() {
  local target="$1"
  local mode="${2:-0755}"
  local before_type
  local backup_rel=""

  df_validate_path "$target" || return 1
  before_type="$(df_path_type "$target")"
  if [ "$before_type" = "directory" ]; then
    [ "$DF_MODE" = "plan" ] && df_info "NOOP" "$target"
    [ "$DF_MODE" = "doctor" ] && df_info "PASS" "$target is a directory"
    return 0
  fi

  if [ "$DF_MODE" = "doctor" ]; then
    df_error "$target: expected directory, found $before_type"
    return 1
  fi

  if [ "$before_type" != "absent" ] && [ "$DF_BACKUP" -ne 1 ]; then
    df_error "$target: directory conflict ($before_type); rerun with --backup"
    return 1
  fi

  DF_CHANGE_COUNT=$((DF_CHANGE_COUNT + 1))
  if [ "$DF_MODE" = "preflight" ]; then return 0; fi
  if [ "$DF_MODE" = "plan" ]; then
    if [ "$before_type" = "absent" ]; then
      df_info "CREATE" "$target/"
    else
      df_info "BACKUP" "$target ($before_type) -> create directory"
    fi
    return 0
  fi

  if [ "$before_type" != "absent" ]; then backup_rel="$(df_next_backup_relpath)"; fi
  df_tx_prepare_action "directory" "$target" "" "$before_type" "$backup_rel" || return 1
  if [ -n "$backup_rel" ]; then
    df_tx_set_phase "$DF_CURRENT_ACTION_DIR" "backup_move_pending" || return 1
    mv "$target" "$DF_TX_DIR/$backup_rel" || return 1
    df_fault_inject "after_backup_move"
    df_tx_set_phase "$DF_CURRENT_ACTION_DIR" "backup_moved" || return 1
  fi
  df_tx_set_phase "$DF_CURRENT_ACTION_DIR" "target_create_pending" || return 1
  mkdir -m "$mode" "$target" || return 1
  df_fault_inject "after_target_creation"
  df_tx_set_phase "$DF_CURRENT_ACTION_DIR" "applied" || return 1
  df_info "CREATE" "$target/"
}

df_link() {
  local source="$1"
  local target="$2"
  local before_type
  local backup_rel=""

  df_validate_path "$source" || return 1
  df_validate_path "$target" || return 1
  if [ ! -e "$source" ] && [ ! -L "$source" ]; then
    df_error "link source does not exist: $source"
    return 1
  fi

  if df_link_is_expected "$source" "$target"; then
    [ "$DF_MODE" = "plan" ] && df_info "NOOP" "$target"
    [ "$DF_MODE" = "doctor" ] && df_info "PASS" "$target -> $source"
    return 0
  fi

  before_type="$(df_path_type "$target")"
  if [ "$DF_MODE" = "doctor" ]; then
    df_error "$target: expected link to $source, found $before_type"
    return 1
  fi

  if [ "$before_type" != "absent" ] && [ "$DF_BACKUP" -ne 1 ]; then
    df_error "$target: link conflict ($before_type); rerun with --backup"
    return 1
  fi

  DF_CHANGE_COUNT=$((DF_CHANGE_COUNT + 1))
  if [ "$DF_MODE" = "preflight" ]; then return 0; fi
  if [ "$DF_MODE" = "plan" ]; then
    if [ "$before_type" = "absent" ]; then
      df_info "LINK" "$target -> $source"
    else
      df_info "BACKUP" "$target ($before_type) -> link to $source"
    fi
    return 0
  fi

  if [ "$before_type" != "absent" ]; then backup_rel="$(df_next_backup_relpath)"; fi
  df_tx_prepare_action "link" "$target" "$source" "$before_type" "$backup_rel" || return 1
  if [ -n "$backup_rel" ]; then
    df_tx_set_phase "$DF_CURRENT_ACTION_DIR" "backup_move_pending" || return 1
    mv "$target" "$DF_TX_DIR/$backup_rel" || return 1
    df_fault_inject "after_backup_move"
    df_tx_set_phase "$DF_CURRENT_ACTION_DIR" "backup_moved" || return 1
  fi
  df_tx_set_phase "$DF_CURRENT_ACTION_DIR" "target_create_pending" || return 1
  ln -s "$source" "$target" || return 1
  df_fault_inject "after_target_creation"
  df_tx_set_phase "$DF_CURRENT_ACTION_DIR" "applied" || return 1
  df_info "LINK" "$target -> $source"
}

df_action_dirs_reverse() {
  local tx_dir="$1"
  find "$tx_dir/actions" -mindepth 1 -maxdepth 1 -type d -name '[0-9][0-9][0-9][0-9][0-9][0-9]' -print | sort -r
}

df_dir_is_empty() {
  local path="$1"
  [ -d "$path" ] && [ -z "$(find "$path" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]
}

df_target_is_scheduled() {
  local tx_dir="$1"
  local wanted="$2"
  local action_dir target operation source
  while IFS= read -r action_dir; do
    [ -n "$action_dir" ] || continue
    target="$(cat "$action_dir/target")"
    [ "$target" = "$wanted" ] || continue
    operation="$(cat "$action_dir/operation")"
    source="$(cat "$action_dir/source")"
    if [ "$operation" = "link" ] && df_link_is_expected "$source" "$target"; then
      return 0
    fi
    if [ "$operation" = "directory" ] && [ -d "$target" ] && [ ! -L "$target" ]; then
      return 0
    fi
  done < <(df_action_dirs_reverse "$tx_dir")
  return 1
}

df_dir_contains_only_scheduled() {
  local tx_dir="$1"
  local directory="$2"
  local entry
  [ -d "$directory" ] && [ ! -L "$directory" ] || return 1
  while IFS= read -r -d '' entry; do
    df_target_is_scheduled "$tx_dir" "$entry" || return 1
  done < <(find "$directory" -mindepth 1 -maxdepth 1 -print0)
}

df_tx_rollback_check() {
  local tx_dir="$1"
  local action_dir operation target source phase before_type backup_rel backup_path
  local target_type backup_type target_expected
  local failed=0

  while IFS= read -r action_dir; do
    [ -n "$action_dir" ] || continue
    operation="$(cat "$action_dir/operation")"
    target="$(cat "$action_dir/target")"
    source="$(cat "$action_dir/source")"
    phase="$(cat "$action_dir/phase")"
    before_type="$(cat "$action_dir/before_type")"
    backup_rel="$(cat "$action_dir/backup_relpath")"

    case "$phase" in
      prepared|backup_move_pending|backup_moved|target_create_pending|applied|rollback_remove_pending|rollback_target_removed|rollback_restore_pending|rolled_back) ;;
      *) df_error "rollback refused: unknown phase in $action_dir"; failed=1; continue ;;
    esac
    case "$before_type" in
      absent|file|directory|symlink|other) ;;
      *) df_error "rollback refused: unknown before_type in $action_dir"; failed=1; continue ;;
    esac
    if [ "$operation" != "link" ] && [ "$operation" != "directory" ]; then
      df_error "rollback refused: unknown operation in $action_dir"
      failed=1
      continue
    fi

    target_type="$(df_path_type "$target")"
    target_expected=0
    if [ "$operation" = "link" ]; then
      if df_link_is_expected "$source" "$target"; then target_expected=1; fi
    elif df_dir_contains_only_scheduled "$tx_dir" "$target"; then
      target_expected=1
    fi

    if [ "$before_type" = "absent" ]; then
      if [ -n "$backup_rel" ]; then
        df_error "rollback refused: unexpected backup path for $target"
        failed=1
      elif [ "$phase" = "rolled_back" ] && [ "$target_type" != "absent" ]; then
        df_error "rollback refused: $target changed after this action was rolled back"
        failed=1
      elif [ "$target_type" != "absent" ] && [ "$target_expected" -ne 1 ]; then
        df_error "rollback refused: $target drifted after apply"
        failed=1
      fi
      continue
    fi

    case "$backup_rel" in
      backup/[0-9][0-9][0-9][0-9][0-9][0-9]) ;;
      *) df_error "rollback refused: invalid backup path for $target"; failed=1; continue ;;
    esac
    backup_path="$tx_dir/$backup_rel"
    backup_type="$(df_path_type "$backup_path")"
    if [ "$phase" = "rolled_back" ] && {
      [ "$backup_type" != "absent" ] ||
      [ "$target_type" != "$before_type" ] ||
      [ "$target_expected" -eq 1 ];
    }; then
      df_error "rollback refused: $target changed after this action was rolled back"
      failed=1
      continue
    fi
    if [ "$backup_type" != "absent" ]; then
      if [ "$backup_type" != "$before_type" ]; then
        df_error "rollback refused: backup type changed for $target"
        failed=1
      elif [ "$target_type" != "absent" ] && [ "$target_expected" -ne 1 ]; then
        df_error "rollback refused: $target changed after its backup moved"
        failed=1
      fi
    elif [ "$target_expected" -eq 1 ] || [ "$target_type" != "$before_type" ]; then
      df_error "rollback refused: backup missing for $target"
      failed=1
    fi
  done < <(df_action_dirs_reverse "$tx_dir")

  [ "$failed" -eq 0 ]
}

df_tx_rollback_apply() {
  local tx_dir="$1"
  local dry_run="$2"
  local action_dir operation target source before_type backup_rel backup_path
  local target_expected

  df_tx_rollback_check "$tx_dir" || return 1
  while IFS= read -r action_dir; do
    [ -n "$action_dir" ] || continue
    operation="$(cat "$action_dir/operation")"
    target="$(cat "$action_dir/target")"
    source="$(cat "$action_dir/source")"
    before_type="$(cat "$action_dir/before_type")"
    backup_rel="$(cat "$action_dir/backup_relpath")"

    if [ "$dry_run" -eq 1 ]; then
      df_info "RESTORE" "$target"
      continue
    fi

    target_expected=0
    if [ "$operation" = "link" ]; then
      if df_link_is_expected "$source" "$target"; then target_expected=1; fi
    elif df_dir_contains_only_scheduled "$tx_dir" "$target"; then
      target_expected=1
    fi

    if [ "$target_expected" -eq 1 ]; then
      df_tx_set_phase "$action_dir" "rollback_remove_pending" || return 1
      if [ "$operation" = "link" ]; then
        unlink "$target" || return 1
      else
        rmdir "$target" || return 1
      fi
      df_tx_set_phase "$action_dir" "rollback_target_removed" || return 1
    fi

    if [ "$before_type" != "absent" ]; then
      backup_path="$tx_dir/$backup_rel"
      if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
        df_tx_set_phase "$action_dir" "rollback_restore_pending" || return 1
        mv "$backup_path" "$target" || return 1
      fi
    fi
    df_tx_set_phase "$action_dir" "rolled_back" || return 1
    df_info "RESTORE" "$target"
    df_fault_inject_failure "during_partial_rollback" || return 1
  done < <(df_action_dirs_reverse "$tx_dir")
}

df_latest_applied_tx() {
  local tx_dir status started_at
  local latest_tx=""
  local latest_started_at=""
  local latest_is_ambiguous=0
  [ -d "$DF_TX_ROOT" ] || return 1
  while IFS= read -r tx_dir; do
    status="$(cat "$tx_dir/meta/status" 2>/dev/null || true)"
    case "$status" in
      applied|applying|rolling_back|rollback_failed) ;;
      *) continue ;;
    esac
    started_at="$(cat "$tx_dir/meta/started_at" 2>/dev/null || true)"
    case "$started_at" in
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
      *) df_error "cannot resolve --last: invalid started_at in $tx_dir"; return 2 ;;
    esac
    if [ -z "$latest_tx" ] || [ "$started_at" \> "$latest_started_at" ]; then
      latest_tx="$tx_dir"
      latest_started_at="$started_at"
      latest_is_ambiguous=0
    elif [ "$started_at" = "$latest_started_at" ]; then
      latest_is_ambiguous=1
    fi
  done < <(find "$DF_TX_ROOT" -mindepth 1 -maxdepth 1 -type d -print | sort -r)
  [ -n "$latest_tx" ] || return 1
  if [ "$latest_is_ambiguous" -eq 1 ]; then
    df_error "cannot resolve --last: multiple recoverable transactions started at $latest_started_at; use an explicit transaction ID"
    return 2
  fi
  printf '%s\n' "$latest_tx"
}

df_receipt_required_file() {
  local path="$1"
  if [ ! -f "$path" ] || [ -L "$path" ]; then
    df_error "malformed transaction receipt: missing regular file $path"
    return 1
  fi
}

df_validate_receipt_shape() {
  local tx_dir="$1"
  local action_entry action_dir name field operation target source before_type backup_rel phase
  local id module
  local failed=0

  for name in meta actions backup; do
    if [ ! -d "$tx_dir/$name" ] || [ -L "$tx_dir/$name" ]; then
      df_error "malformed transaction receipt: missing directory $tx_dir/$name"
      failed=1
    fi
  done
  [ "$failed" -eq 0 ] || return 1

  for field in id module repo_revision started_at status; do
    df_receipt_required_file "$tx_dir/meta/$field" || failed=1
  done
  [ "$failed" -eq 0 ] || return 1

  id="$(cat "$tx_dir/meta/id")"
  if [ "$id" != "$(basename "$tx_dir")" ]; then
    df_error "malformed transaction receipt: ID does not match directory $tx_dir"
    failed=1
  fi
  module="$(cat "$tx_dir/meta/module")"
  case "$module" in
    ''|*[!a-z0-9-]*|-*|*-|*--*)
      df_error "malformed transaction receipt: invalid Module in $tx_dir"
      failed=1
      ;;
  esac

  while IFS= read -r action_entry; do
    [ -n "$action_entry" ] || continue
    name="$(basename "$action_entry")"
    case "$name" in
      [0-9][0-9][0-9][0-9][0-9][0-9]) ;;
      *) df_error "malformed transaction receipt: invalid action entry $action_entry"; failed=1; continue ;;
    esac
    if [ ! -d "$action_entry" ] || [ -L "$action_entry" ]; then
      df_error "malformed transaction receipt: action is not a directory $action_entry"
      failed=1
      continue
    fi
    action_dir="$action_entry"
    for field in operation target source before_type backup_relpath phase; do
      df_receipt_required_file "$action_dir/$field" || failed=1
    done
    [ "$failed" -eq 0 ] || continue

    operation="$(cat "$action_dir/operation")"
    target="$(cat "$action_dir/target")"
    source="$(cat "$action_dir/source")"
    before_type="$(cat "$action_dir/before_type")"
    backup_rel="$(cat "$action_dir/backup_relpath")"
    phase="$(cat "$action_dir/phase")"

    case "$operation" in
      link)
        df_validate_path "$source" || failed=1
        ;;
      directory)
        if [ -n "$source" ]; then
          df_error "malformed transaction receipt: directory action has a source in $action_dir"
          failed=1
        fi
        ;;
      *) df_error "malformed transaction receipt: unknown operation in $action_dir"; failed=1 ;;
    esac
    df_validate_path "$target" || failed=1
    case "$before_type" in
      absent)
        if [ -n "$backup_rel" ]; then
          df_error "malformed transaction receipt: absent target has a backup path in $action_dir"
          failed=1
        fi
        ;;
      file|directory|symlink|other)
        case "$backup_rel" in
          backup/[0-9][0-9][0-9][0-9][0-9][0-9]) ;;
          *) df_error "malformed transaction receipt: invalid backup path in $action_dir"; failed=1 ;;
        esac
        ;;
      *) df_error "malformed transaction receipt: unknown before_type in $action_dir"; failed=1 ;;
    esac
    case "$phase" in
      prepared|backup_move_pending|backup_moved|target_create_pending|applied|rollback_remove_pending|rollback_target_removed|rollback_restore_pending|rolled_back) ;;
      *) df_error "malformed transaction receipt: unknown phase in $action_dir"; failed=1 ;;
    esac
  done < <(find "$tx_dir/actions" -mindepth 1 -maxdepth 1 -print)

  [ "$failed" -eq 0 ]
}

df_state_doctor() {
  local path mode status tx_dir
  local failed=0
  [ -e "$DF_STATE_DIR" ] || return 0

  while IFS= read -r path; do
    mode="$(df_mode_of "$path")"
    if [ "$mode" != "700" ]; then df_error "$path mode is $mode, expected 700"; failed=1; fi
  done < <(find "$DF_STATE_DIR" -path '*/backup/*' -prune -o -type d -print)
  while IFS= read -r path; do
    mode="$(df_mode_of "$path")"
    if [ "$mode" != "600" ]; then df_error "$path mode is $mode, expected 600"; failed=1; fi
  done < <(find "$DF_STATE_DIR" -path '*/backup/*' -prune -o -type f -print)
  while IFS= read -r tx_dir; do
    [ -n "$tx_dir" ] || continue
    df_validate_receipt_shape "$tx_dir" || failed=1
  done < <(find "$DF_TX_ROOT" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null)
  while IFS= read -r path; do
    status="$(cat "$path" 2>/dev/null || true)"
    case "$status" in
      applied|rolled_back|failed_rolled_back) ;;
      applying|rolling_back|rollback_failed|'')
        df_error "incomplete transaction ($status): $(dirname "$(dirname "$path")")"
        failed=1
        ;;
      *)
        df_error "unknown transaction status ($status): $(dirname "$(dirname "$path")")"
        failed=1
        ;;
    esac
  done < <(find "$DF_TX_ROOT" -path '*/meta/status' -type f -print 2>/dev/null)

  [ "$failed" -eq 0 ]
}
