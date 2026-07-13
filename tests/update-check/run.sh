#!/usr/bin/env bash

# Integration test for the Zsh update notifier. Uses local Git repositories;
# no external network is required.

set -u

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORIGINAL_TMPDIR="${TMPDIR:-/tmp}"
SUITE_ROOT="$(mktemp -d "$ORIGINAL_TMPDIR/dotfiles-update-check-tests.XXXXXX")" || exit 1

cleanup() {
  case "$SUITE_ROOT" in
    "$ORIGINAL_TMPDIR"/dotfiles-update-check-tests.*) /bin/rm -rf "$SUITE_ROOT" ;;
    *) printf 'Refusing to remove unexpected test path: %s\n' "$SUITE_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'not ok 1 - %s\n' "$1" >&2
  exit 1
}

command -v zsh >/dev/null 2>&1 || fail 'zsh is required'

remote="$SUITE_ROOT/remote.git"
seed="$SUITE_ROOT/seed"
checkout="$SUITE_ROOT/checkout"
cache="$SUITE_ROOT/cache"

git init --bare -q "$remote" || fail 'could not create remote'
git clone -q "$remote" "$seed" 2>/dev/null || fail 'could not create seed clone'
git -C "$seed" config user.name test
git -C "$seed" config user.email test@example.invalid
printf 'one\n' > "$seed/value"
git -C "$seed" add value
git -C "$seed" commit -qm initial
git -C "$seed" push -q origin HEAD || fail 'could not push initial commit'
git clone -q "$remote" "$checkout" || fail 'could not create test checkout'

before_head="$(git -C "$checkout" rev-parse HEAD)"
printf 'two\n' >> "$seed/value"
git -C "$seed" commit -qam update
git -C "$seed" push -q origin HEAD || fail 'could not push update'

# A killed fetch can leave this cache lock behind. Make it old enough to be
# reclaimed and verify that the first check still refreshes remote refs.
mkdir -p "$cache/dotfiles/update-check.lock"
printf 'abandoned\n' > "$cache/dotfiles/update-check.lock/token"

run_check() {
  DOTFILES_DIR="$checkout" \
  XDG_CACHE_HOME="$cache" \
  DOTFILES_TEST_UPDATE_CHECK_INTERVAL=0 \
  DOTFILES_TEST_UPDATE_CHECK_FOREGROUND=1 \
    zsh "$ROOT/zsh/update-check.zsh"
}

locked_output="$(run_check)" || fail 'fresh-lock update check failed'
[ -z "$locked_output" ] || fail 'fresh lock check produced an update notice'
[ -d "$cache/dotfiles/update-check.lock" ] || fail 'fresh update lock was removed'
[ "$(git -C "$checkout" rev-list --count HEAD..origin/HEAD)" = 0 ] || fail 'fresh lock did not suppress fetch'

touch -t 202001010000 "$cache/dotfiles/update-check.lock"
first_output="$(run_check)" || fail 'stale-lock update check failed'
[ -z "$first_output" ] || fail 'stale-lock check announced before fetch completed'
[ ! -e "$cache/dotfiles/update-check.lock" ] || fail 'stale update lock was not reclaimed'
[ "$(git -C "$checkout" rev-parse HEAD)" = "$before_head" ] || fail 'fetch changed HEAD'
[ "$(cat "$checkout/value")" = 'one' ] || fail 'fetch changed the worktree'

second_output="$(run_check)" || fail 'second update check failed'
case "$second_output" in
  *'업데이트 1개 있음'*'pull --ff-only'*) ;;
  *) fail 'second check did not announce one update' ;;
esac
[ "$(git -C "$checkout" rev-parse HEAD)" = "$before_head" ] || fail 'notification changed HEAD'
[ -z "$(git -C "$checkout" status --porcelain)" ] || fail 'notification dirtied the worktree'

if grep -Fq 'git -C "$repo" pull' "$ROOT/zsh/update-check.zsh"; then
  fail 'update checker contains an automatic pull'
fi

printf 'ok 1 - fetch refreshes update availability without changing checkout\n'
