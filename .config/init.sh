#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# shellcheck source=../lib/dotfiles/legacy_links.sh
. "$SCRIPT_DIR/../lib/dotfiles/legacy_links.sh"

DIRS=(wezterm nvim fish neofetch ghostty)
if [[ "$(uname -s)" == "Darwin" ]]; then
  DIRS+=(karabiner)
fi

# ---- Starship config selection ----
# Override priority: hostname-specific > OS-specific > symlink (default)
HOSTNAME="$(hostname -s)"
OVERRIDE_SCRIPT=""
if [[ -f "$SCRIPT_DIR/starship.overrides.$HOSTNAME.sh" ]]; then
  OVERRIDE_SCRIPT="$SCRIPT_DIR/starship.overrides.$HOSTNAME.sh"
elif [[ "$OSTYPE" != "darwin"* && -f "$SCRIPT_DIR/starship.overrides.linux.sh" ]]; then
  OVERRIDE_SCRIPT="$SCRIPT_DIR/starship.overrides.linux.sh"
fi

STARSHIP_DESTINATION="$CONFIG_DIR/starship.toml"
STARSHIP_MARKER=""
if [[ -n "$OVERRIDE_SCRIPT" ]]; then
  STARSHIP_MARKER="# dotfiles-managed:starship-override=$(basename "$OVERRIDE_SCRIPT")"
fi

ZED_SOURCE="$SCRIPT_DIR/zed/settings.json"
ZED_DESTINATION="$CONFIG_DIR/zed/settings.json"
ZED_CONFLICT_GUIDANCE="Preserve the private Zed file and merge shared values from $ZED_SOURCE into it locally; this init will not replace it."

# ---- Directory symlinks (Stow-style) ----
# Existing files, directories, and links to a different source are conflicts.
preflight_directory() {
  df_legacy_preflight_exact_link "$1" "$2"
}

link_directory() {
  local source="$1"
  local destination="$2"
  df_legacy_link_exact "$source" "$destination" "$(basename "$destination")/"
}

starship_override_conflict() {
  printf '  ❌ Refusing to replace unmanaged Starship path: %s\n' "$STARSHIP_DESTINATION" >&2
  printf '     Expected first line: %s\n' "$STARSHIP_MARKER" >&2
  printf '     Preserve or back up the existing path, then remove it explicitly before retrying.\n' >&2
  return 1
}

preflight_starship_override() {
  local first_line=""

  if [[ -L "$STARSHIP_DESTINATION" ]]; then
    starship_override_conflict
    return 1
  fi

  if [[ -e "$STARSHIP_DESTINATION" ]]; then
    if [[ ! -f "$STARSHIP_DESTINATION" ]]; then
      starship_override_conflict
      return 1
    fi
    first_line="$(sed -n '1p' "$STARSHIP_DESTINATION")"
    if [[ "$first_line" != "$STARSHIP_MARKER" ]]; then
      starship_override_conflict
      return 1
    fi
  fi

  return 0
}

write_starship_override() {
  local temporary

  temporary="$(mktemp "$CONFIG_DIR/.starship.toml.XXXXXX")" || return 1
  if ! {
    printf '%s\n' "$STARSHIP_MARKER"
    cat "$SCRIPT_DIR/starship.toml"
  } >"$temporary"; then
    /bin/rm -f "$temporary"
    return 1
  fi

  if ! bash "$OVERRIDE_SCRIPT" "$temporary"; then
    /bin/rm -f "$temporary"
    printf '  ❌ Starship override failed: %s\n' "$OVERRIDE_SCRIPT" >&2
    return 1
  fi

  chmod 0644 "$temporary"
  if ! preflight_starship_override; then
    /bin/rm -f "$temporary"
    return 1
  fi
  if ! mv "$temporary" "$STARSHIP_DESTINATION"; then
    /bin/rm -f "$temporary"
    return 1
  fi

  echo "  ✅ Patched starship.toml ($(basename "$OVERRIDE_SCRIPT"))"
}

# ---- Read-only preflight ----
# Check every managed destination before package installation or link writes.
if [[ (-e "$CONFIG_DIR" || -L "$CONFIG_DIR") && ! -d "$CONFIG_DIR" ]]; then
  echo "  ❌ XDG config path is not a directory: $CONFIG_DIR" >&2
  exit 1
fi

for dir in "${DIRS[@]}"; do
  if [[ -d "$SCRIPT_DIR/$dir" ]]; then
    preflight_directory "$SCRIPT_DIR/$dir" "$CONFIG_DIR/$dir"
  fi
done

if [[ -n "$OVERRIDE_SCRIPT" ]]; then
  preflight_starship_override
else
  df_legacy_preflight_exact_link "$SCRIPT_DIR/starship.toml" "$STARSHIP_DESTINATION"
fi

if [[ -f "$ZED_SOURCE" ]]; then
  if [[ (-e "$CONFIG_DIR/zed" || -L "$CONFIG_DIR/zed") && ! -d "$CONFIG_DIR/zed" ]]; then
    echo "  ❌ Zed config parent is not a directory: $CONFIG_DIR/zed" >&2
    exit 1
  fi
  df_legacy_preflight_exact_link \
    "$ZED_SOURCE" "$ZED_DESTINATION" "$ZED_CONFLICT_GUIDANCE"
fi

echo "📦 Setting up .config..."

# ---- Install fonts (macOS only — WSL/Linux fonts are managed by the host terminal) ----
if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
  BREW_CASKS=(font-jetbrains-mono-nerd-font)
  for cask in "${BREW_CASKS[@]}"; do
    if ! brew list --cask "$cask" &>/dev/null; then
      echo "  ⬇️  Installing $cask..."
      brew install --cask "$cask"
    else
      echo "  ✅ $cask already installed"
    fi
  done
fi

mkdir -p "$CONFIG_DIR"

for dir in "${DIRS[@]}"; do
  if [[ -d "$SCRIPT_DIR/$dir" ]]; then
    link_directory "$SCRIPT_DIR/$dir" "$CONFIG_DIR/$dir"
  fi
done

# ---- Starship config ----
if [[ -n "$OVERRIDE_SCRIPT" ]]; then
  write_starship_override
else
  df_legacy_link_exact \
    "$SCRIPT_DIR/starship.toml" "$STARSHIP_DESTINATION" "starship.toml"
fi

# ---- Zed: settings.json only (avoid runtime file pollution) ----
if [[ -f "$ZED_SOURCE" ]]; then
  mkdir -p "$CONFIG_DIR/zed"
  df_legacy_link_exact \
    "$ZED_SOURCE" "$ZED_DESTINATION" "zed/settings.json" \
    "$ZED_CONFLICT_GUIDANCE"
fi

# ---- WSL: sync WezTerm config to Windows side ----
if grep -qi microsoft /proc/version 2>/dev/null; then
  WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
  WIN_WEZTERM_DIR="/mnt/c/Users/$WIN_USER/.config/wezterm"
  if [[ -n "$WIN_USER" && -d "/mnt/c/Users/$WIN_USER" ]]; then
    mkdir -p "$WIN_WEZTERM_DIR/machine"
    cp "$SCRIPT_DIR/wezterm/"*.lua "$WIN_WEZTERM_DIR/"
    cp "$SCRIPT_DIR/wezterm/machine/local.example.lua" \
      "$WIN_WEZTERM_DIR/machine/local.example.lua"
    echo "  ✅ Synced WezTerm config to Windows ($WIN_USER)"
    echo "     Preserved Windows-local machine/local.lua if present"
  fi
fi

echo "🎉 .config setup complete!"
