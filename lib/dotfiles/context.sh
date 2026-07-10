#!/usr/bin/env bash

# Read-only Execution Context snapshot assembled from explicit local signals.
# Compatible with the Bash 3.2 shipped by macOS.

df_context_read_identity() {
  local command_path details status line key value
  local seen_instance=0
  local seen_role=0

  DF_CONTEXT_EXECUTION_INSTANCE_ID=""
  DF_CONTEXT_ROLE=""
  command_path="${DF_CONTEXT_IDENTITY_COMMAND:-$DF_ROOT/bin/llm-instance}"
  details="$("$command_path" --details 2>/dev/null)"
  status=$?
  [ "$status" -eq 0 ] || return 0

  while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      instance_id)
        [ "$seen_instance" -eq 0 ] || { seen_instance=2; continue; }
        DF_CONTEXT_EXECUTION_INSTANCE_ID="$value"
        seen_instance=1
        ;;
      role)
        [ "$seen_role" -eq 0 ] || { seen_role=2; continue; }
        DF_CONTEXT_ROLE="$value"
        seen_role=1
        ;;
    esac
  done <<EOF
$details
EOF

  if [ "$seen_instance" -ne 1 ] || ! [[ "$DF_CONTEXT_EXECUTION_INSTANCE_ID" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    DF_CONTEXT_EXECUTION_INSTANCE_ID=""
    DF_CONTEXT_ROLE=""
    return 0
  fi
  if [ "$seen_role" -ne 1 ] || ! [[ "$DF_CONTEXT_ROLE" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    DF_CONTEXT_EXECUTION_INSTANCE_ID=""
    DF_CONTEXT_ROLE=""
  fi
}

df_context_detect_platform() {
  local system release normalized_release
  system="$(uname -s 2>/dev/null || true)"
  release="$(uname -r 2>/dev/null || true)"
  normalized_release="$(printf '%s' "$release" | tr '[:upper:]' '[:lower:]')"
  case "$system" in
    Darwin) DF_CONTEXT_PLATFORM="macos" ;;
    Linux)
      if [ -n "${WSL_DISTRO_NAME:-}" ]; then
        DF_CONTEXT_PLATFORM="wsl"
      else
        case "$normalized_release" in
          *microsoft*) DF_CONTEXT_PLATFORM="wsl" ;;
          *) DF_CONTEXT_PLATFORM="linux" ;;
        esac
      fi
      ;;
    *) DF_CONTEXT_PLATFORM="" ;;
  esac
}

df_context_detect_transport() {
  if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ]; then
    DF_CONTEXT_TRANSPORT="ssh"
  else
    DF_CONTEXT_TRANSPORT="local"
  fi
}

df_context_detect_multiplexer() {
  if [ -n "${TMUX:-}" ]; then
    DF_CONTEXT_MULTIPLEXER="tmux"
  else
    DF_CONTEXT_MULTIPLEXER="none"
  fi
}

df_context_read_git() {
  local cwd="$1"
  local root dirty_output

  DF_CONTEXT_REPOSITORY_ROOT=""
  DF_CONTEXT_GIT_BRANCH=""
  DF_CONTEXT_GIT_DIRTY=""
  command -v git >/dev/null 2>&1 || return 0
  root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || return 0
  root="$(df_workspaces_physical_dir "$root")" || return 0
  DF_CONTEXT_REPOSITORY_ROOT="$root"
  DF_CONTEXT_GIT_BRANCH="$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if dirty_output="$(git --no-optional-locks -C "$cwd" status --porcelain --untracked-files=normal 2>/dev/null)"; then
    if [ -n "$dirty_output" ]; then
      DF_CONTEXT_GIT_DIRTY="true"
    else
      DF_CONTEXT_GIT_DIRTY="false"
    fi
  fi
}

df_context_collect() {
  DF_CONTEXT_CWD="$(pwd -P 2>/dev/null || true)"
  df_workspaces_load || return 1
  df_workspaces_match "$DF_CONTEXT_CWD"
  df_context_read_identity
  df_context_detect_platform
  df_context_detect_transport
  df_context_detect_multiplexer
  if [ "$DF_CONTEXT_TRANSPORT" = "local" ]; then
    DF_CONTEXT_ORIGIN_INSTANCE_ID="$DF_CONTEXT_EXECUTION_INSTANCE_ID"
  else
    DF_CONTEXT_ORIGIN_INSTANCE_ID=""
  fi
  DF_CONTEXT_PERSISTENCE=""
  df_context_read_git "$DF_CONTEXT_CWD"
}

df_context_text_value() {
  if [ -n "$1" ]; then
    printf '%s' "$1"
  else
    printf 'unknown'
  fi
}

df_context_print_text() {
  printf 'execution_instance_id=%s\n' "$(df_context_text_value "$DF_CONTEXT_EXECUTION_INSTANCE_ID")"
  printf 'origin_instance_id=%s\n' "$(df_context_text_value "$DF_CONTEXT_ORIGIN_INSTANCE_ID")"
  printf 'role=%s\n' "$(df_context_text_value "$DF_CONTEXT_ROLE")"
  printf 'platform=%s\n' "$(df_context_text_value "$DF_CONTEXT_PLATFORM")"
  printf 'transport=%s\n' "$(df_context_text_value "$DF_CONTEXT_TRANSPORT")"
  printf 'multiplexer=%s\n' "$(df_context_text_value "$DF_CONTEXT_MULTIPLEXER")"
  printf 'workspace_id=%s\n' "$(df_context_text_value "$DF_WORKSPACE_ID")"
  printf 'target_id=%s\n' "$(df_context_text_value "$DF_TARGET_ID")"
  printf 'persistence=%s\n' "$(df_context_text_value "$DF_CONTEXT_PERSISTENCE")"
  printf 'cwd=%s\n' "$(df_context_text_value "$DF_CONTEXT_CWD")"
  printf 'repository_root=%s\n' "$(df_context_text_value "$DF_CONTEXT_REPOSITORY_ROOT")"
  printf 'git_branch=%s\n' "$(df_context_text_value "$DF_CONTEXT_GIT_BRANCH")"
  printf 'git_dirty=%s\n' "$(df_context_text_value "$DF_CONTEXT_GIT_DIRTY")"
}

df_context_json_string() {
  local value="$1"
  local i octal control escaped

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  i=1
  while [ "$i" -le 31 ]; do
    octal="$(printf '%03o' "$i")"
    printf -v control "\\$octal"
    printf -v escaped '\\u%04x' "$i"
    value="${value//$control/$escaped}"
    i=$((i + 1))
  done
  printf '"%s"' "$value"
}

df_context_json_nullable() {
  if [ -n "$1" ]; then
    df_context_json_string "$1"
  else
    printf 'null'
  fi
}

df_context_json_dirty() {
  case "$1" in
    true|false) printf '%s' "$1" ;;
    *) printf 'null' ;;
  esac
}

df_context_print_json() {
  printf '{"schema_version":1,"execution_instance_id":%s,"origin_instance_id":%s,"role":%s,"platform":%s,"transport":%s,"multiplexer":%s,"workspace_id":%s,"target_id":%s,"persistence":%s,"cwd":%s,"repository_root":%s,"git_branch":%s,"git_dirty":%s}\n' \
    "$(df_context_json_nullable "$DF_CONTEXT_EXECUTION_INSTANCE_ID")" \
    "$(df_context_json_nullable "$DF_CONTEXT_ORIGIN_INSTANCE_ID")" \
    "$(df_context_json_nullable "$DF_CONTEXT_ROLE")" \
    "$(df_context_json_nullable "$DF_CONTEXT_PLATFORM")" \
    "$(df_context_json_nullable "$DF_CONTEXT_TRANSPORT")" \
    "$(df_context_json_nullable "$DF_CONTEXT_MULTIPLEXER")" \
    "$(df_context_json_nullable "$DF_WORKSPACE_ID")" \
    "$(df_context_json_nullable "$DF_TARGET_ID")" \
    "$(df_context_json_nullable "$DF_CONTEXT_PERSISTENCE")" \
    "$(df_context_json_nullable "$DF_CONTEXT_CWD")" \
    "$(df_context_json_nullable "$DF_CONTEXT_REPOSITORY_ROOT")" \
    "$(df_context_json_nullable "$DF_CONTEXT_GIT_BRANCH")" \
    "$(df_context_json_dirty "$DF_CONTEXT_GIT_DIRTY")"
}

df_context_run() {
  local output="text"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --json) output="json"; shift ;;
      -h|--help)
        printf 'Usage: dotfiles context [--json]\n'
        return 0
        ;;
      *) df_error "unknown context option: $1"; return 2 ;;
    esac
  done
  df_context_collect || return 1
  if [ "$output" = "json" ]; then
    df_context_print_json
  else
    df_context_print_text
  fi
}
