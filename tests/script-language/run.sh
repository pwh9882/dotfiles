#!/usr/bin/env bash

set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/lib/dotfiles/script_language.sh"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_language() {
  local expected="$1"
  local path="$2"
  local actual
  actual="$(df_script_language "$path")"
  [ "$actual" = "$expected" ] || fail "$path: expected $expected, got ${actual:-unknown}"
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/script-language-test.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

printf '#!/usr/bin/env bash\nprintf ok\n' >"$tmpdir/bash-tool"
printf '#!/bin/bash -e\nprintf ok\n' >"$tmpdir/direct-bash"
printf '#!/usr/bin/env python3\nprint("ok")\n' >"$tmpdir/python-tool"
printf '#!/usr/bin/env -S python3 -I\nprint("ok")\n' >"$tmpdir/env-s-python"
printf 'printf ok\n' >"$tmpdir/fallback.sh"
printf 'print("ok")\n' >"$tmpdir/fallback.py"
printf 'plain text\n' >"$tmpdir/unknown"

assert_language bash "$tmpdir/bash-tool"
assert_language bash "$tmpdir/direct-bash"
assert_language python "$tmpdir/python-tool"
assert_language python "$tmpdir/env-s-python"
assert_language bash "$tmpdir/fallback.sh"
assert_language python "$tmpdir/fallback.py"
assert_language unknown "$tmpdir/unknown"

printf 'ok - script language follows shebang with extension fallback\n'
