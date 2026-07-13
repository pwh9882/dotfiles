#!/usr/bin/env bash

# Preflight for user-owned shell Local Adapter paths. Sourced by legacy shell
# installers before any package, network, or filesystem side effect.

df_local_adapter_preflight_dir() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    if [[ ! -d "$path" ]]; then
      printf 'Local Adapter directory is invalid: %s\n' "$path" >&2
      return 1
    fi
    if [[ ! -w "$path" || ! -x "$path" ]]; then
      printf 'Local Adapter directory is not writable: %s\n' "$path" >&2
      return 1
    fi
  fi
}

df_local_adapter_preflight_file() {
  local path="$1"
  if [[ -L "$path" ]]; then
    if [[ ! -f "$path" || ! -r "$path" ]]; then
      printf 'Local Adapter symlink must resolve to a readable regular file: %s\n' "$path" >&2
      return 1
    fi
  elif [[ -e "$path" ]]; then
    if [[ ! -f "$path" || ! -r "$path" ]]; then
      printf 'Local Adapter must be a readable regular file: %s\n' "$path" >&2
      return 1
    fi
  fi
}
