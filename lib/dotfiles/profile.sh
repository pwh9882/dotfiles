#!/usr/bin/env bash

# Read-only Machine Profile resolution.
# Sourced after state.sh so validation errors use the common CLI formatter.

df_profile_role_is_known() {
  case "$1" in
    authoring-client|service-host|windows-workstation|headless-agent-worker|lab-tailnet-proxy) return 0 ;;
    *) return 1 ;;
  esac
}

df_profile_capability_is_known() {
  case "$1" in
    core-tools|shared-agent-instructions) return 0 ;;
    *) return 1 ;;
  esac
}

df_profile_module_for_capability() {
  case "$1" in
    core-tools) printf '%s\n' bin ;;
    shared-agent-instructions) printf '%s\n' agents-links ;;
    *) df_error "Capability has no Module mapping: $1"; return 1 ;;
  esac
}

df_profile_read_identity() {
  local details status line key value
  local seen_instance=0
  local seen_role=0

  details="$("$DF_ROOT/bin/llm-instance" --details)"
  status=$?
  [ "$status" -eq 0 ] || return "$status"

  DF_PROFILE_INSTANCE_ID=""
  DF_PROFILE_ROLE=""
  while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      instance_id)
        [ "$seen_instance" -eq 0 ] || { df_error "llm-instance returned duplicate instance_id"; return 1; }
        DF_PROFILE_INSTANCE_ID="$value"
        seen_instance=1
        ;;
      role)
        [ "$seen_role" -eq 0 ] || { df_error "llm-instance returned duplicate role"; return 1; }
        DF_PROFILE_ROLE="$value"
        seen_role=1
        ;;
    esac
  done <<EOF
$details
EOF

  if [ "$seen_instance" -ne 1 ] || ! [[ "$DF_PROFILE_INSTANCE_ID" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    df_error "llm-instance returned an invalid instance_id"
    return 1
  fi
  if [ "$seen_role" -ne 1 ] || ! [[ "$DF_PROFILE_ROLE" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    df_error "llm-instance returned an invalid role"
    return 1
  fi
}

df_profile_load_registry() {
  local selected_role="$1"
  local registry="${DOTFILES_PROFILE_REGISTRY:-$DF_ROOT/config/machine-profiles.tsv}"
  local line line_number=0 role capability pair module
  local seen_pairs="|"
  local selected_capabilities=""
  local selected_modules=""
  local ordered_modules=""
  local row_count=0

  [ -f "$registry" ] || { df_error "Machine Profile Registry not found: $registry"; return 1; }
  [ -r "$registry" ] || { df_error "Machine Profile Registry is not readable: $registry"; return 1; }

  while IFS= read -r line || [ -n "$line" ]; do
    line_number=$((line_number + 1))
    case "$line" in
      *$'\t'*$'\t'*)
        df_error "Machine Profile Registry line $line_number must contain exactly two tab-separated fields"
        return 1
        ;;
      *$'\t'*) ;;
      *)
        df_error "Machine Profile Registry line $line_number must contain exactly two tab-separated fields"
        return 1
        ;;
    esac

    role="${line%%$'\t'*}"
    capability="${line#*$'\t'}"
    if ! [[ "$role" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      df_error "Machine Profile Registry line $line_number has an invalid role name"
      return 1
    fi
    if ! [[ "$capability" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      df_error "Machine Profile Registry line $line_number has an invalid capability name"
      return 1
    fi
    if ! df_profile_role_is_known "$role"; then
      df_error "Machine Profile Registry line $line_number has an unknown role: $role"
      return 1
    fi
    if ! df_profile_capability_is_known "$capability"; then
      df_error "Machine Profile Registry line $line_number has an unknown capability: $capability"
      return 1
    fi

    pair="$role:$capability"
    case "$seen_pairs" in
      *"|$pair|"*)
        df_error "Machine Profile Registry line $line_number duplicates $role -> $capability"
        return 1
        ;;
    esac
    seen_pairs="${seen_pairs}${pair}|"
    row_count=$((row_count + 1))

    if [ "$role" = "$selected_role" ]; then
      if [ -n "$selected_capabilities" ]; then
        selected_capabilities="$selected_capabilities $capability"
      else
        selected_capabilities="$capability"
      fi
    fi
  done < "$registry"

  [ "$row_count" -gt 0 ] || { df_error "Machine Profile Registry is empty"; return 1; }
  if [ -z "$selected_capabilities" ]; then
    df_error "Role is not registered in the Machine Profile Registry: $selected_role"
    return 1
  fi

  for capability in $selected_capabilities; do
    module="$(df_profile_module_for_capability "$capability")" || return 1
    case " $selected_modules " in
      *" $module "*) ;;
      *)
        if [ -n "$selected_modules" ]; then
          selected_modules="$selected_modules $module"
        else
          selected_modules="$module"
        fi
        ;;
    esac
  done

  for module in $DF_TRANSACTIONAL_MODULES; do
    case " $selected_modules " in
      *" $module "*)
        if [ -n "$ordered_modules" ]; then
          ordered_modules="$ordered_modules $module"
        else
          ordered_modules="$module"
        fi
        ;;
    esac
  done

  DF_PROFILE_CAPABILITIES="$selected_capabilities"
  DF_PROFILE_MODULES="$ordered_modules"
}

df_profile_load() {
  df_profile_read_identity || return $?
  df_profile_load_registry "$DF_PROFILE_ROLE"
}

df_profile_select_modules() {
  df_profile_load || return $?
  [ "$DF_PROFILE_MODULES" = "$DF_TRANSACTIONAL_MODULES" ] || {
    df_error "Profile resolves unsupported Module set: $DF_PROFILE_MODULES"
    return 1
  }
  DF_MODULES="$DF_PROFILE_MODULES"
}

df_profile_print() {
  local capability module
  df_profile_load || return $?
  printf 'instance_id=%s\n' "$DF_PROFILE_INSTANCE_ID"
  printf 'role=%s\n' "$DF_PROFILE_ROLE"
  for capability in $DF_PROFILE_CAPABILITIES; do
    printf 'capability=%s\n' "$capability"
  done
  for module in $DF_PROFILE_MODULES; do
    printf 'module=%s\n' "$module"
  done
}
