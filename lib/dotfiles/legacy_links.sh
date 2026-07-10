#!/usr/bin/env bash

# Fail-closed helpers for legacy init scripts that have not migrated to the
# transactional Installer. These helpers never remove or replace a conflict.

df_legacy_link_conflict() {
  local source="$1"
  local destination="$2"
  local guidance="${3:-Move or back up the existing path, then retry.}"
  local current=""

  if [[ -L "$destination" ]]; then
    current="$(readlink "$destination" 2>/dev/null || true)"
    printf '  ❌ Refusing to replace symlink: %s -> %s\n' "$destination" "$current" >&2
  else
    printf '  ❌ Refusing to replace existing path: %s\n' "$destination" >&2
  fi
  printf '     Expected symlink target: %s\n' "$source" >&2
  printf '     %s\n' "$guidance" >&2
  return 1
}

df_legacy_preflight_exact_link() {
  local source="$1"
  local destination="$2"
  local guidance="${3:-Move or back up the existing path, then retry.}"
  local current

  if [[ -L "$destination" ]]; then
    current="$(readlink "$destination" 2>/dev/null || true)"
    if [[ "$current" == "$source" ]]; then
      return 0
    fi
    df_legacy_link_conflict "$source" "$destination" "$guidance"
    return 1
  fi

  if [[ -e "$destination" ]]; then
    df_legacy_link_conflict "$source" "$destination" "$guidance"
    return 1
  fi

  return 0
}

df_legacy_link_exact() {
  local source="$1"
  local destination="$2"
  local label="${3:-$destination}"
  local guidance="${4:-Move or back up the existing path, then retry.}"

  df_legacy_preflight_exact_link "$source" "$destination" "$guidance" || return 1

  if [[ -L "$destination" ]]; then
    printf '  ✅ Already linked %s\n' "$label"
    return 0
  fi

  if [[ ! -e "$source" && ! -L "$source" ]]; then
    printf '  ❌ Link source does not exist: %s\n' "$source" >&2
    return 1
  fi

  ln -s "$source" "$destination"
  printf '  ✅ Linked %s\n' "$label"
}
