#!/usr/bin/env bash

# Read-only Feature Registry parser and evidence checks.
# Compatible with the Bash 3.2 shipped by macOS.

df_features_error() {
  printf 'features: %s\n' "$1" >&2
}

df_features_registry_path() {
  printf '%s\n' "${DF_FEATURES_REGISTRY:-$DF_ROOT/config/features.tsv}"
}

df_features_validate_structure() {
  local registry="$1"
  local tab

  [ -f "$registry" ] || {
    df_features_error "registry is not a regular file: $registry"
    return 1
  }

  tab="$(printf '\t')"
  awk -F "$tab" '
    function problem(message) {
      printf "features: line %d: %s\n", NR, message > "/dev/stderr"
      invalid = 1
    }

    function identifier(value) {
      return value ~ /^[a-z0-9]+(-[a-z0-9]+)*$/
    }

    function identifier_list(value,    count, item, parts) {
      count = split(value, parts, ",")
      if (count < 1) return 0
      for (item = 1; item <= count; item++) {
        if (!identifier(parts[item])) return 0
      }
      return 1
    }

    function blank(value) {
      return value == "" || value ~ /^[[:space:]]+$/
    }

    {
      if (index($0, "\r") != 0) problem("carriage returns are not allowed")
    }

    NR == 1 {
      if (NF != 9 ||
          $1 != "id" || $2 != "status" || $3 != "roles" ||
          $4 != "platforms" || $5 != "privacy" ||
          $6 != "first_run" || $7 != "verify" ||
          $8 != "docs" || $9 != "summary") {
        problem("expected the strict 9-field Feature Registry header")
      }
      next
    }

    NR > 1 {
      rows++
      if (NF != 9) {
        problem("expected exactly 9 tab-separated fields")
        next
      }
      if (!identifier($1)) problem("invalid feature id")
      if ($2 != "available" && $2 != "pilot") {
        problem("status must be available or pilot")
      }
      if (!identifier_list($3)) problem("invalid comma-separated roles")
      if (!identifier_list($4)) problem("invalid comma-separated platforms")
      if (blank($5)) problem("privacy must not be empty")
      if (blank($6)) problem("first_run must not be empty")
      if (blank($7)) problem("verify must not be empty")
      if (blank($8)) {
        problem("docs must not be empty")
      } else {
        if ($8 ~ /^\// || $8 ~ /(^|\/)\.\.($|\/)/) {
          problem("docs must be a repository-relative path without ..")
        }
        if ($8 !~ /^[A-Za-z0-9._\/-]+$/) {
          problem("docs contains unsupported path characters")
        }
      }
      if (blank($9)) problem("summary must not be empty")
      if (seen[$1]++) problem("duplicate feature id")
    }

    END {
      if (NR == 0) {
        printf "features: registry is empty\n" > "/dev/stderr"
        invalid = 1
      } else if (rows == 0) {
        printf "features: registry contains no feature rows\n" > "/dev/stderr"
        invalid = 1
      }
      exit invalid
    }
  ' "$registry"
}

df_features_validate_docs() {
  local registry="$1"
  local tab

  tab="$(printf '\t')"
  awk -F "$tab" 'NR > 1 { print $8 }' "$registry" |
    while IFS= read -r docs; do
      if [ ! -f "$DF_ROOT/$docs" ]; then
        df_features_error "docs path does not exist: $docs"
        return 1
      fi
    done
}

df_features_validate() {
  local registry

  registry="$(df_features_registry_path)"
  df_features_validate_structure "$registry" || return 1
  df_features_validate_docs "$registry"
}

df_features_evidence_known() {
  case "$1" in
    repository-health|machine-profile|safe-bin-apply|shared-agent-instructions|workspace-context|wezterm-context-status|wezterm-project-picker|wezterm-session-restore) return 0 ;;
    *) return 1 ;;
  esac
}

df_features_evidence_present() {
  case "$1" in
    repository-health)
      [ -x "$DF_ROOT/bin/dotfiles-check" ] &&
        [ -f "$DF_ROOT/.github/workflows/ci.yml" ]
      ;;
    machine-profile)
        [ -x "$DF_ROOT/bin/llm-instance" ] &&
        [ -f "$DF_ROOT/config/machine-profiles.tsv" ] &&
        [ -f "$DF_ROOT/lib/dotfiles/profile.sh" ] &&
        [ -f "$DF_ROOT/tests/profile/run.sh" ]
      ;;
    safe-bin-apply)
      [ -x "$DF_ROOT/bin/dotfiles" ] &&
        [ -f "$DF_ROOT/lib/dotfiles/runtime.sh" ] &&
        [ -f "$DF_ROOT/lib/dotfiles/state.sh" ] &&
        [ -f "$DF_ROOT/lib/dotfiles/modules/bin.sh" ] &&
        [ -x "$DF_ROOT/tests/dotfiles/run.sh" ]
      ;;
    shared-agent-instructions)
      [ -f "$DF_ROOT/agents/AGENTS.md" ] &&
        [ -f "$DF_ROOT/lib/dotfiles/modules/agents_links.sh" ] &&
        [ -f "$DF_ROOT/tests/dotfiles/agents-links.sh" ] &&
        [ -f "$DF_ROOT/docs/runbooks/manage-agents-links.md" ]
      ;;
    workspace-context)
      [ -f "$DF_ROOT/config/workspaces.tsv" ] &&
        [ -f "$DF_ROOT/config/workspaces.local.example.tsv" ] &&
        [ -f "$DF_ROOT/lib/dotfiles/workspaces.sh" ] &&
        [ -f "$DF_ROOT/lib/dotfiles/context.sh" ] &&
        [ -f "$DF_ROOT/tests/workspaces/run.sh" ] &&
        [ -f "$DF_ROOT/docs/architecture/workspace-context.md" ] &&
        [ -f "$DF_ROOT/docs/runbooks/register-workspace.md" ]
      ;;
    wezterm-context-status)
      [ -f "$DF_ROOT/.config/wezterm/theme.lua" ] &&
        [ -f "$DF_ROOT/.config/wezterm/theme_logic.lua" ] &&
        [ -f "$DF_ROOT/.config/wezterm/theme_test.lua" ] &&
        grep -Fq "wezterm.on('update-status'" "$DF_ROOT/.config/wezterm/theme.lua" &&
        [ -f "$DF_ROOT/docs/runbooks/use-wezterm-workflows.md" ]
      ;;
    wezterm-project-picker)
      [ -f "$DF_ROOT/.config/wezterm/keys.lua" ] &&
        [ -f "$DF_ROOT/.config/wezterm/projects.lua" ] &&
        [ -f "$DF_ROOT/.config/wezterm/projects_logic.lua" ] &&
        [ -f "$DF_ROOT/.config/wezterm/projects_test.lua" ] &&
        [ -f "$DF_ROOT/.config/wezterm/machine/local.example.lua" ] &&
        grep -Fq "key = 'p', mods = 'LEADER'" "$DF_ROOT/.config/wezterm/keys.lua" &&
        [ -f "$DF_ROOT/docs/runbooks/use-wezterm-workflows.md" ]
      ;;
    wezterm-session-restore)
      [ -f "$DF_ROOT/.config/wezterm/plugins.lua" ] &&
        [ -f "$DF_ROOT/.config/wezterm/README.md" ] &&
        grep -Fq 'set_max_nlines(0)' "$DF_ROOT/.config/wezterm/plugins.lua" &&
        ! grep -Eq 'restore_text[[:space:]]*=[[:space:]]*true' "$DF_ROOT/.config/wezterm/plugins.lua" &&
        [ -f "$DF_ROOT/docs/runbooks/use-wezterm-workflows.md" ]
      ;;
    *) return 2 ;;
  esac
}

df_features_list() {
  local registry
  local tab

  df_features_validate || return 1
  registry="$(df_features_registry_path)"
  tab="$(printf '\t')"
  awk -F "$tab" '
    BEGIN { printf "%-28s %-9s %s\n", "FEATURE", "STATUS", "SUMMARY" }
    NR > 1 { printf "%-28s %-9s %s\n", $1, $2, $9 }
  ' "$registry"
}

df_features_detail() {
  local feature_id="$1"
  local registry
  local tab

  case "$feature_id" in
    ''|*[!a-z0-9-]*|-*|*-|*--*)
      df_features_error "unknown feature: $feature_id"
      return 1
      ;;
  esac

  df_features_validate || return 1
  registry="$(df_features_registry_path)"
  tab="$(printf '\t')"
  if ! awk -F "$tab" -v wanted="$feature_id" '
    $1 == wanted {
      printf "id:         %s\n", $1
      printf "status:     %s\n", $2
      printf "roles:      %s\n", $3
      printf "platforms:  %s\n", $4
      printf "privacy:    %s\n", $5
      printf "first run:  %s\n", $6
      printf "verify:     %s\n", $7
      printf "docs:       %s\n", $8
      printf "summary:    %s\n", $9
      found = 1
    }
    END { if (!found) exit 1 }
  ' "$registry"; then
    df_features_error "unknown feature: $feature_id"
    return 1
  fi
}

df_features_doctor() {
  local registry
  local tab

  df_features_validate || return 1
  registry="$(df_features_registry_path)"
  tab="$(printf '\t')"

  awk -F "$tab" 'NR > 1 { print $1 }' "$registry" |
    while IFS= read -r feature_id; do
      if ! df_features_evidence_known "$feature_id"; then
        df_features_error "feature has no allowlisted evidence check: $feature_id"
        return 1
      fi
      if ! df_features_evidence_present "$feature_id"; then
        df_features_error "feature evidence is incomplete: $feature_id"
        return 1
      fi
      printf 'PASS  feature evidence: %s\n' "$feature_id"
    done
}
