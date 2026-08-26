#!/usr/bin/env bash

# Classify executable-style source files without assuming every extensionless
# file under bin/ is a shell script. A recognized shebang wins; extensions are
# only a fallback for source files without one.

df_script_language() {
  local path="$1"
  local first_line=""
  local shebang

  IFS= read -r first_line <"$path" || true
  case "$first_line" in
    '#!'*)
      shebang=" ${first_line#\#!} "
      case "$shebang" in
        *[[:space:]/]bash[[:space:]]*) printf 'bash\n'; return 0 ;;
        *[[:space:]/]python[[:space:]]*|*[[:space:]/]python[0-9]*[[:space:]]*)
          printf 'python\n'
          return 0
          ;;
      esac
      ;;
  esac

  case "$path" in
    *.sh) printf 'bash\n' ;;
    *.py) printf 'python\n' ;;
    *) printf 'unknown\n' ;;
  esac
}
