#!/usr/bin/env bash

# Read-only Workspace Registry validation, overlay merge, and path resolution.
# Compatible with the Bash 3.2 shipped by macOS.

df_workspaces_error() {
  printf 'workspaces: %s\n' "$1" >&2
}

df_workspaces_public_path() {
  printf '%s\n' "${DF_WORKSPACES_REGISTRY:-$DF_ROOT/config/workspaces.tsv}"
}

df_workspaces_local_path() {
  printf '%s\n' "${DF_WORKSPACES_LOCAL_REGISTRY:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/workspaces.local.tsv}"
}

df_workspaces_validate_registry() {
  local registry="$1"
  local scope="$2"
  local require_rows="$3"
  local tab

  [ -f "$registry" ] || {
    df_workspaces_error "$scope registry is not a regular file: $registry"
    return 1
  }

  tab="$(printf '\t')"
  awk -F "$tab" -v scope="$scope" -v require_rows="$require_rows" '
    function problem(message) {
      printf "workspaces: %s line %d: %s\n", scope, NR, message > "/dev/stderr"
      invalid = 1
    }

    function identifier(value) {
      return value ~ /^[a-z0-9]+(-[a-z0-9]+)*$/
    }

    function unsafe_path(value) {
      return index(value, "$") || index(value, "`") ||
        index(value, "*") || index(value, "?") ||
        index(value, "[") || index(value, "]") ||
        index(value, "{") || index(value, "}")
    }

    {
      if (index($0, "\r") != 0) problem("carriage returns are not allowed")
    }

    NR == 1 {
      if (NF != 3 || $1 != "workspace_id" || $2 != "target_id" || $3 != "root") {
        problem("expected the strict workspace_id, target_id, root header")
      }
      next
    }

    NR > 1 {
      rows++
      if (NF != 3) {
        problem("expected exactly 3 tab-separated fields")
        next
      }
      if (!identifier($1)) problem("invalid workspace_id")
      if (!identifier($2)) problem("invalid target_id")
      if ($3 == "") problem("root must not be empty")
      if (scope == "public") {
        if ($3 != "~" && $3 !~ /^~\//) {
          problem("public root must be ~ or start with ~/")
        }
      } else if ($3 != "~" && $3 !~ /^~\// && $3 !~ /^\//) {
        problem("local root must be absolute, ~, or start with ~/")
      }
      if ($3 ~ /(^|\/)\.\.($|\/)/) problem("root must not contain a .. segment")
      if (unsafe_path($3)) problem("root contains environment, command, or glob syntax")
      key = $1 SUBSEP $2
      if (seen[key]++) problem("duplicate workspace_id and target_id")
    }

    END {
      if (NR == 0) {
        printf "workspaces: %s registry is empty\n", scope > "/dev/stderr"
        invalid = 1
      } else if (require_rows == 1 && rows == 0) {
        printf "workspaces: %s registry contains no workspace rows\n", scope > "/dev/stderr"
        invalid = 1
      }
      exit invalid
    }
  ' "$registry"
}

df_workspaces_append_raw_row() {
  local row="$1"
  if [ -n "$DF_WORKSPACES_RAW_ROWS" ]; then
    DF_WORKSPACES_RAW_ROWS="${DF_WORKSPACES_RAW_ROWS}
${row}"
  else
    DF_WORKSPACES_RAW_ROWS="$row"
  fi
}

df_workspaces_remove_raw_key() {
  local wanted_workspace="$1"
  local wanted_target="$2"
  local workspace target root
  local retained=""

  while IFS=$'\t' read -r workspace target root || [ -n "$workspace$target$root" ]; do
    [ -n "$workspace" ] || continue
    if [ "$workspace" = "$wanted_workspace" ] && [ "$target" = "$wanted_target" ]; then
      continue
    fi
    if [ -n "$retained" ]; then
      retained="${retained}
${workspace}"$'\t'"${target}"$'\t'"${root}"
    else
      retained="${workspace}"$'\t'"${target}"$'\t'"${root}"
    fi
  done <<EOF
$DF_WORKSPACES_RAW_ROWS
EOF
  DF_WORKSPACES_RAW_ROWS="$retained"
}

df_workspaces_read_rows() {
  local registry="$1"
  local overlay="$2"
  local workspace target root

  while IFS=$'\t' read -r workspace target root || [ -n "$workspace$target$root" ]; do
    [ "$workspace" = "workspace_id" ] && continue
    [ -n "$workspace" ] || continue
    if [ "$overlay" -eq 1 ]; then
      df_workspaces_remove_raw_key "$workspace" "$target"
    fi
    df_workspaces_append_raw_row "${workspace}"$'\t'"${target}"$'\t'"${root}"
  done < "$registry"
}

df_workspaces_expand_root() {
  local root="$1"
  local expanded

  case "$root" in
    '~') expanded="$HOME" ;;
    '~/'*) expanded="$HOME/${root#\~/}" ;;
    /*) expanded="$root" ;;
    *) df_workspaces_error "validated root has an unsupported form: $root"; return 1 ;;
  esac

  while [ "$expanded" != "/" ] && [ "${expanded%/}" != "$expanded" ]; do
    expanded="${expanded%/}"
  done
  printf '%s\n' "$expanded"
}

df_workspaces_physical_dir() {
  local path="$1"
  (cd -P -- "$path" 2>/dev/null && pwd -P)
}

df_workspaces_seen_root() {
  local wanted="$1"
  local root key
  while IFS=$'\t' read -r root key; do
    [ -n "$root" ] || continue
    if [ "$root" = "$wanted" ]; then
      printf '%s\n' "$key"
      return 0
    fi
  done <<EOF
$DF_WORKSPACES_ROOT_KEYS
EOF
  return 1
}

df_workspaces_record_root() {
  local root="$1"
  local key="$2"
  local prior

  if prior="$(df_workspaces_seen_root "$root")"; then
    df_workspaces_error "ambiguous root is registered by both $prior and $key: $root"
    return 1
  fi
  if [ -n "$DF_WORKSPACES_ROOT_KEYS" ]; then
    DF_WORKSPACES_ROOT_KEYS="${DF_WORKSPACES_ROOT_KEYS}
${root}"$'\t'"${key}"
  else
    DF_WORKSPACES_ROOT_KEYS="${root}"$'\t'"${key}"
  fi
}

df_workspaces_append_resolved_row() {
  local row="$1"
  if [ -n "$DF_WORKSPACES_RESOLVED_ROWS" ]; then
    DF_WORKSPACES_RESOLVED_ROWS="${DF_WORKSPACES_RESOLVED_ROWS}
${row}"
  else
    DF_WORKSPACES_RESOLVED_ROWS="$row"
  fi
}

df_workspaces_resolve_rows() {
  local workspace target root expanded canonical status key unique_root

  DF_WORKSPACES_RESOLVED_ROWS=""
  DF_WORKSPACES_ROOT_KEYS=""
  while IFS=$'\t' read -r workspace target root; do
    [ -n "$workspace" ] || continue
    expanded="$(df_workspaces_expand_root "$root")" || return 1
    if canonical="$(df_workspaces_physical_dir "$expanded")"; then
      status="ready"
      unique_root="$canonical"
    else
      status="missing"
      canonical=""
      unique_root="$expanded"
    fi
    key="$workspace/$target"
    df_workspaces_record_root "$unique_root" "$key" || return 1
    df_workspaces_append_resolved_row "${workspace}"$'\t'"${target}"$'\t'"${expanded}"$'\t'"${canonical}"$'\t'"${status}"
  done <<EOF
$DF_WORKSPACES_RAW_ROWS
EOF
}

df_workspaces_load() {
  local public_registry local_registry

  public_registry="$(df_workspaces_public_path)"
  local_registry="$(df_workspaces_local_path)"
  df_workspaces_validate_registry "$public_registry" public 1 || return 1
  if [ -e "$local_registry" ] || [ -L "$local_registry" ]; then
    df_workspaces_validate_registry "$local_registry" local 0 || return 1
  elif [ -n "${DF_WORKSPACES_LOCAL_REGISTRY:-}" ]; then
    # An explicit test/operator override still follows the normal optional
    # overlay contract: absence is not an error.
    :
  fi

  # Validation completes for both sources before any row participates in the
  # overlay. A malformed trailing row cannot be hidden by an earlier match.
  DF_WORKSPACES_RAW_ROWS=""
  df_workspaces_read_rows "$public_registry" 0
  if [ -f "$local_registry" ]; then
    df_workspaces_read_rows "$local_registry" 1
  fi
  df_workspaces_resolve_rows
}

df_workspaces_match() {
  local cwd="$1"
  local workspace target expanded canonical status
  local best_length=-1
  local length

  DF_WORKSPACE_ID=""
  DF_TARGET_ID=""
  DF_WORKSPACE_ROOT=""
  while IFS=$'\t' read -r workspace target expanded canonical status; do
    [ "$status" = "ready" ] || continue
    if [ "$canonical" != "/" ]; then
      case "$cwd" in
        "$canonical"|"$canonical"/*) ;;
        *) continue ;;
      esac
    else
      case "$cwd" in
        /*) ;;
        *) continue ;;
      esac
    fi
    length=${#canonical}
    if [ "$length" -gt "$best_length" ]; then
      best_length="$length"
      DF_WORKSPACE_ID="$workspace"
      DF_TARGET_ID="$target"
      DF_WORKSPACE_ROOT="$canonical"
    fi
  done <<EOF
$DF_WORKSPACES_RESOLVED_ROWS
EOF
}

df_workspaces_doctor() {
  local workspace target expanded canonical status
  local local_registry

  df_workspaces_load || return 1
  printf 'PASS  Workspace Registry is valid\n'
  local_registry="$(df_workspaces_local_path)"
  if [ ! -e "$local_registry" ]; then
    printf 'INFO  optional local overlay is absent\n'
  fi
  while IFS=$'\t' read -r workspace target expanded canonical status; do
    [ -n "$workspace" ] || continue
    if [ "$status" = "ready" ]; then
      printf 'PASS  workspace target: %s/%s -> %s\n' "$workspace" "$target" "$canonical"
    else
      printf 'WARN  workspace target root is missing: %s/%s -> %s\n' "$workspace" "$target" "$expanded"
    fi
  done <<EOF
$DF_WORKSPACES_RESOLVED_ROWS
EOF
}
