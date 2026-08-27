#!/usr/bin/env zsh

set -eu

ROOT="${0:A:h:h:h}"
source "$ROOT/zsh/ssht.zsh"

fail() {
    print -u2 -- "not ok - $1"
    exit 1
}

assert_contains() {
    [[ "$1" == *"$2"* ]] || fail "expected [$1] to contain [$2]"
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/ssht-test.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/bin"

cat > "$tmpdir/bin/tmux" <<'FAKE_TMUX'
#!/bin/sh
case "$1" in
    list-sessions) printf '%s\n' ADRS backend molyday research research-old titans ;;
    attach-session)
        if [ "${SSHT_ATTACH_FAIL:-}" = 1 ]; then exit 1; fi
        printf '%s\n' "$*" > "$SSHT_TMUX_LOG"
        ;;
    *) printf '%s\n' "$*" > "$SSHT_TMUX_LOG" ;;
esac
FAKE_TMUX
chmod +x "$tmpdir/bin/tmux"

remote_script="$(_ssht_remote_script)"

rm -f "$tmpdir/log"
SSHT_TMUX_LOG="$tmpdir/log" PATH="$tmpdir/bin:$PATH" zsh -c "$remote_script" ssht find ADRS
[[ "$(<"$tmpdir/log")" == 'attach-session -t =ADRS' ]] || fail 'Zsh exact session attach'
print 'ok - remote script works under a Zsh login shell'

SSHT_TMUX_LOG="$tmpdir/log" SSHT_ATTACH_FAIL=1 PATH="$tmpdir/bin:$PATH" /bin/sh -c "$remote_script" ssht default ''
[[ "$(<"$tmpdir/log")" == 'new-session' ]] || fail 'default new-session fallback'
print 'ok - default mode creates a session when none exists'

SSHT_TMUX_LOG="$tmpdir/log" PATH="$tmpdir/bin:$PATH" /bin/sh -c "$remote_script" ssht find ADRS
[[ "$(<"$tmpdir/log")" == 'attach-session -t =ADRS' ]] || fail 'exact session attach'
print 'ok - exact session name attaches'

SSHT_TMUX_LOG="$tmpdir/log" PATH="$tmpdir/bin:$PATH" /bin/sh -c "$remote_script" ssht find ARDS 2>"$tmpdir/stderr"
[[ "$(<"$tmpdir/log")" == 'attach-session -t =ADRS' ]] || fail 'fuzzy session attach'
assert_contains "$(<"$tmpdir/stderr")" 'matched tmux session ARDS -> ADRS'
print 'ok - one-edit typo selects the unique nearest session'

SSHT_TMUX_LOG="$tmpdir/log" PATH="$tmpdir/bin:$PATH" /bin/sh -c "$remote_script" ssht find ttns 2>"$tmpdir/stderr"
[[ "$(<"$tmpdir/log")" == 'attach-session -t =titans' ]] || fail 'two-edit fuzzy session attach'
assert_contains "$(<"$tmpdir/stderr")" 'matched tmux session ttns -> titans'
print 'ok - two-edit typo selects a close longer session'

SSHT_TMUX_LOG="$tmpdir/log" PATH="$tmpdir/bin:$PATH" /bin/sh -c "$remote_script" ssht find moly 2>"$tmpdir/stderr"
[[ "$(<"$tmpdir/log")" == 'attach-session -t =molyday' ]] || fail 'unique prefix session attach'
assert_contains "$(<"$tmpdir/stderr")" 'matched tmux session moly -> molyday'
print 'ok - unique prefix selects the matching session before fuzzy lookup'

if SSHT_TMUX_LOG="$tmpdir/log" PATH="$tmpdir/bin:$PATH" /bin/sh -c "$remote_script" ssht find rese 2>"$tmpdir/stderr"; then
    fail 'ambiguous prefix should stop'
fi
assert_contains "$(<"$tmpdir/stderr")" 'ambiguous tmux session rese: research, research-old'
print 'ok - ambiguous prefix stops instead of choosing a fuzzy candidate'

if SSHT_TMUX_LOG="$tmpdir/log" PATH="$tmpdir/bin:$PATH" /bin/sh -c "$remote_script" ssht find brand-new 2>"$tmpdir/stderr"; then
    fail 'distant session query should stop'
fi
assert_contains "$(<"$tmpdir/stderr")" 'tmux session not found: brand-new'
assert_contains "$(<"$tmpdir/stderr")" 'available tmux sessions:'
assert_contains "$(<"$tmpdir/stderr")" $'  - ADRS\n  - backend\n  - molyday\n  - research\n  - research-old\n  - titans'
assert_contains "$(<"$tmpdir/stderr")" 'ssht <host> -n brand-new'
print 'ok - distant session query lists sessions and explains explicit creation'

CLICOLOR_FORCE=1 SSHT_TMUX_LOG="$tmpdir/log" PATH="$tmpdir/bin:$PATH" /bin/sh -c "$remote_script" ssht find brand-new 2>"$tmpdir/stderr" || true
assert_contains "$(<"$tmpdir/stderr")" $'  - \e[1;36mADRS\e[0m'
print 'ok - interactive session names are highlighted without merging entries'

SSHT_TMUX_LOG="$tmpdir/log" PATH="$tmpdir/bin:$PATH" /bin/sh -c "$remote_script" ssht new ADRS
[[ "$(<"$tmpdir/log")" == 'new-session -s ADRS' ]] || fail 'forced named session'
print 'ok - new mode always asks tmux to create the named session'

mkdir -p "$tmpdir/ssh-bin"
cat > "$tmpdir/ssh-bin/ssh" <<'FAKE_SSH'
#!/bin/sh
printf '%s\n' "$@" > "$SSHT_SSH_LOG"
FAKE_SSH
chmod +x "$tmpdir/ssh-bin/ssh"

SSHT_SSH_LOG="$tmpdir/ssh-log" PATH="$tmpdir/ssh-bin:$PATH" ssht -p 33022 ts-ddps -n ADRS
mapfile=("${(f)$(<"$tmpdir/ssh-log")}")
[[ ${mapfile[1]} == -t && ${mapfile[2]} == -p && ${mapfile[3]} == 33022 && ${mapfile[4]} == ts-ddps ]] || fail 'ssh arguments preserved'
assert_contains "${mapfile[5]}" ' ssht new ADRS'
print 'ok - SSH options remain before host and ssht options remain after host'
