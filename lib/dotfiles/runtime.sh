#!/usr/bin/env bash

# User-facing command dispatch and transactional Module lifecycle.
# Sourced by bin/dotfiles after DF_ROOT is resolved.

source "$DF_ROOT/lib/dotfiles/state.sh"
source "$DF_ROOT/lib/dotfiles/modules/bin.sh"
source "$DF_ROOT/lib/dotfiles/modules/agents_links.sh"
source "$DF_ROOT/lib/dotfiles/profile.sh"
source "$DF_ROOT/lib/dotfiles/features.sh"
source "$DF_ROOT/lib/dotfiles/workspaces.sh"
source "$DF_ROOT/lib/dotfiles/context.sh"

DF_TRANSACTIONAL_MODULES="bin agents-links"

df_usage() {
  cat <<'EOF'
Usage: dotfiles <command> [options]

Commands:
  profile
      Show the validated Instance, Role, Capability, and selected Module.

  tour [FEATURE_ID]
      List usable features or show one feature's first-run and privacy details.

  context [--json]
      Print the current read-only Execution Context snapshot.

  plan [--only bin|agents-links] [--backup]
      Show desired changes. Without --only, select from the Machine Profile.

  apply [--only bin|agents-links] [--dry-run] [--backup]
      Apply selected changes. Without --only, select from the Machine Profile.
      Explicit --only bypasses identity and selects one Module.

  doctor [--quick|--full]
      Run read-only repository verification.

  doctor --only bin|agents-links
      Verify one installed Module and transaction state.

  doctor --profile
      Resolve the Machine Profile and verify all selected Modules.

  doctor --only features|workspaces
      Validate a read-only Registry and its implementation evidence.

  history
      List recorded Module transactions.

  rollback [--last|TRANSACTION_ID] [--dry-run]
      Revert one applied transaction when managed targets have not drifted.

  help
      Show this help.

The bin and agents-links Modules use the transactional Installer. Package
installation and remaining legacy init behavior are intentionally unchanged.
EOF
}

df_reset_run() {
  DF_MODE="$1"
  DF_BACKUP="${2:-0}"
  DF_CHANGE_COUNT=0
  DF_ACTION_SEQ=0
  DF_CURRENT_ACTION_DIR=""
}

df_parse_module_options() {
  DF_BACKUP=0
  DF_DRY_RUN=0
  DF_ONLY=""
  DF_MODULES=""
  DF_ONLY_EXPLICIT=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --only)
        [ "$#" -ge 2 ] || { df_error "--only requires a Module name"; return 2; }
        DF_ONLY="$2"
        DF_ONLY_EXPLICIT=1
        shift 2
        ;;
      --backup) DF_BACKUP=1; shift ;;
      --dry-run) DF_DRY_RUN=1; shift ;;
      -h|--help) df_usage; return 10 ;;
      *) df_error "unknown option: $1"; return 2 ;;
    esac
  done
  if [ "$DF_ONLY_EXPLICIT" -eq 0 ]; then
    df_profile_select_modules || return $?
  elif ! df_module_is_known "$DF_ONLY"; then
    df_error "Module has not migrated to the transactional Installer: $DF_ONLY"
    return 2
  else
    DF_MODULES="$DF_ONLY"
  fi
}

df_module_is_known() {
  case "$1" in
    bin|agents-links) return 0 ;;
    *) return 1 ;;
  esac
}

df_module_run() {
  case "$1" in
    bin) df_module_bin ;;
    agents-links) df_module_agents_links ;;
    *) df_error "unknown transactional Module: $1"; return 2 ;;
  esac
}

df_plan_module() {
  local module="$1"
  local backup="$2"
  df_reset_run plan "$backup"
  df_module_run "$module"
}

df_plan_modules() {
  local modules="$1"
  local backup="$2"
  local module
  for module in $modules; do
    df_plan_module "$module" "$backup" || return 1
  done
}

df_preflight_module() {
  local module="$1"
  local backup="$2"
  df_reset_run preflight "$backup"
  df_module_run "$module"
}

df_preflight_modules() {
  local modules="$1"
  local backup="$2"
  local module
  for module in $modules; do
    df_preflight_module "$module" "$backup" || return 1
  done
}

df_apply_module() {
  local module="$1"
  local backup="$2"
  local preflight_changes

  df_preflight_module "$module" "$backup" || return 1
  preflight_changes="$DF_CHANGE_COUNT"
  if [ "$preflight_changes" -eq 0 ]; then
    df_info "NOOP" "$module Module already matches desired state"
    return 0
  fi

  df_state_init_paths
  if ! df_tx_begin "$module"; then
    df_error "could not create transaction receipt"
    return 1
  fi

  df_reset_run apply "$backup"
  if df_module_run "$module" && df_tx_set_status "$DF_TX_DIR" "applied"; then
    df_info "DONE" "transaction $DF_TX_ID"
    return 0
  fi

  df_error "apply failed; rolling back transaction $DF_TX_ID"
  df_tx_set_status "$DF_TX_DIR" "rolling_back" || true
  if df_tx_rollback_apply "$DF_TX_DIR" 0; then
    df_tx_set_status "$DF_TX_DIR" "failed_rolled_back" || true
  else
    df_tx_set_status "$DF_TX_DIR" "rollback_failed" || true
    df_error "automatic rollback failed; inspect $DF_TX_DIR"
  fi
  return 1
}

df_apply_modules() {
  local modules="$1"
  local backup="$2"
  local module

  # Every selected Module must pass a read-only preflight before the first
  # Transaction writes either HOME or the state directory.
  df_preflight_modules "$modules" "$backup" || return 1
  for module in $modules; do
    df_apply_module "$module" "$backup" || return 1
  done
}

df_doctor_module() {
  local module="$1"
  df_reset_run doctor 0
  df_module_run "$module"
}

df_doctor_modules() {
  local modules="$1"
  local module
  local failed=0

  for module in $modules; do
    df_doctor_module "$module" || failed=1
  done
  df_state_init_paths
  if df_state_doctor; then
    df_info "PASS" "transaction state permissions and status"
  else
    failed=1
  fi
  [ "$failed" -eq 0 ]
}

df_history() {
  local tx_dir id module status
  df_state_init_paths
  if [ ! -d "$DF_TX_ROOT" ]; then
    df_info "INFO" "no transactions"
    return 0
  fi
  while IFS= read -r tx_dir; do
    [ -n "$tx_dir" ] || continue
    id="$(cat "$tx_dir/meta/id" 2>/dev/null || basename "$tx_dir")"
    module="$(cat "$tx_dir/meta/module" 2>/dev/null || printf '?')"
    status="$(cat "$tx_dir/meta/status" 2>/dev/null || printf 'unknown')"
    printf '%s\t%s\t%s\n' "$id" "$module" "$status"
  done < <(find "$DF_TX_ROOT" -mindepth 1 -maxdepth 1 -type d -print | sort -r)
}

df_resolve_tx() {
  local selector="$1"
  local candidate
  local resolve_status
  df_state_init_paths
  if [ "$selector" = "--last" ] || [ -z "$selector" ]; then
    candidate="$(df_latest_applied_tx)"
    resolve_status=$?
    if [ "$resolve_status" -eq 1 ]; then
      df_error "no applied transaction found"
      return 1
    elif [ "$resolve_status" -ne 0 ]; then
      return "$resolve_status"
    fi
  else
    case "$selector" in
      */*|*..*) df_error "invalid transaction id: $selector"; return 2 ;;
    esac
    candidate="$DF_TX_ROOT/$selector"
    [ -d "$candidate" ] || { df_error "transaction not found: $selector"; return 1; }
  fi
  printf '%s\n' "$candidate"
}

df_rollback() {
  local selector="--last"
  local selector_seen=0
  local dry_run=0
  local tx_dir status
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --last)
        [ "$selector_seen" -eq 0 ] || { df_error "multiple transaction selectors"; return 2; }
        selector="--last"
        selector_seen=1
        shift
        ;;
      --dry-run) dry_run=1; shift ;;
      -h|--help) df_usage; return 0 ;;
      -*) df_error "unknown rollback option: $1"; return 2 ;;
      *)
        [ "$selector_seen" -eq 0 ] || { df_error "multiple transaction selectors"; return 2; }
        selector="$1"
        selector_seen=1
        shift
        ;;
    esac
  done

  tx_dir="$(df_resolve_tx "$selector")" || return $?
  df_validate_receipt_shape "$tx_dir" || return 1
  status="$(cat "$tx_dir/meta/status" 2>/dev/null || true)"
  case "$status" in
    applied|applying|rolling_back|rollback_failed) ;;
    *) df_error "transaction cannot be rolled back from status: ${status:-unknown}"; return 1 ;;
  esac

  # Keep drift refusal read-only: validate every action before changing either
  # the filesystem or the transaction status.
  df_tx_rollback_check "$tx_dir" || return 1
  if [ "$dry_run" -eq 1 ]; then
    df_tx_rollback_apply "$tx_dir" 1
    return $?
  fi

  df_tx_set_status "$tx_dir" "rolling_back" || return 1
  if df_tx_rollback_apply "$tx_dir" 0; then
    df_tx_set_status "$tx_dir" "rolled_back" || return 1
    df_info "DONE" "rolled back $(basename "$tx_dir")"
    return 0
  fi
  df_tx_set_status "$tx_dir" "rollback_failed" || true
  df_error "rollback failed; retry with transaction $(basename "$tx_dir") after resolving drift"
  return 1
}

df_main() {
  local command_name="${1:-help}"
  local parse_status
  case "$command_name" in
    profile)
      shift
      [ "$#" -eq 0 ] || { df_error "profile accepts no options"; return 2; }
      df_profile_print
      ;;
    tour)
      shift
      [ "$#" -le 1 ] || { df_error "tour accepts at most one Feature ID"; return 2; }
      if [ "$#" -eq 1 ]; then
        df_features_detail "$1"
      else
        df_features_list
      fi
      ;;
    context)
      shift
      df_context_run "$@"
      ;;
    plan)
      shift
      df_parse_module_options "$@"; parse_status=$?
      [ "$parse_status" -eq 10 ] && return 0
      [ "$parse_status" -eq 0 ] || return "$parse_status"
      [ "$DF_DRY_RUN" -eq 0 ] || { df_error "plan is already read-only; omit --dry-run"; return 2; }
      df_plan_modules "$DF_MODULES" "$DF_BACKUP"
      ;;
    apply)
      shift
      df_parse_module_options "$@"; parse_status=$?
      [ "$parse_status" -eq 10 ] && return 0
      [ "$parse_status" -eq 0 ] || return "$parse_status"
      if [ "$DF_DRY_RUN" -eq 1 ]; then
        df_plan_modules "$DF_MODULES" "$DF_BACKUP"
      else
        df_apply_modules "$DF_MODULES" "$DF_BACKUP"
      fi
      ;;
    doctor)
      shift
      if [ "${1:-}" = "--profile" ]; then
        [ "$#" -eq 1 ] || { df_error "doctor --profile accepts no additional options"; return 2; }
        df_profile_select_modules || return $?
        df_doctor_modules "$DF_MODULES"
      elif [ "${1:-}" = "--only" ]; then
        [ "$#" -eq 2 ] || { df_error "unexpected doctor options"; return 2; }
        case "${2:-}" in
          bin|agents-links) df_doctor_modules "$2" ;;
          features) df_features_doctor ;;
          workspaces) df_workspaces_doctor ;;
          *) df_error "unknown Doctor target: ${2:-missing}"; return 2 ;;
        esac
      else
        [ "$#" -le 1 ] || { df_error "doctor accepts --quick, --full, --profile, or --only TARGET"; return 2; }
        "$DF_ROOT/bin/dotfiles-check" "${1:---quick}"
      fi
      ;;
    history)
      shift
      [ "$#" -eq 0 ] || { df_error "history accepts no options"; return 2; }
      df_history
      ;;
    rollback)
      shift
      df_rollback "$@"
      ;;
    help|-h|--help)
      df_usage
      ;;
    *)
      df_error "unknown command: $command_name"
      printf '\n' >&2
      df_usage >&2
      return 2
      ;;
  esac
}
