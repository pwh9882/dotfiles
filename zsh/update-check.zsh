# Read fetched remote refs synchronously, then refresh them in the background.
# This file never changes HEAD or the worktree.

_dotfiles_update_check() {
    local repo="${DOTFILES_DIR:-}"
    local cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
    local stamp_file="$cache_root/update-check.last"
    local lock_dir="$cache_root/update-check.lock"
    local interval="${DOTFILES_TEST_UPDATE_CHECK_INTERVAL:-21600}"
    local stale_after=600
    local upstream ahead now last quoted_repo update_lock_token current_token

    [[ -n "$repo" ]] || return
    git -C "$repo" rev-parse --is-inside-work-tree &>/dev/null || return

    upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"
    if [[ -n "$upstream" ]]; then
        ahead="$(git -C "$repo" rev-list --count "HEAD..$upstream" 2>/dev/null)"
        if [[ "$ahead" == <-> ]] && (( ahead > 0 )); then
            quoted_repo="${(q)repo}"
            print -r -- "dotfiles: 업데이트 ${ahead}개 있음 — git -C $quoted_repo pull --ff-only"
        fi
    fi

    mkdir -p "$cache_root" 2>/dev/null || return
    now="$(date +%s)"
    if [[ -r "$stamp_file" ]]; then
        last="$(<"$stamp_file")"
    else
        last=0
    fi
    [[ "$last" == <-> ]] || last=0
    (( now - last >= interval )) || return

    _dotfiles_fetch_remote() {
        local lock_mtime stale_dir

        update_lock_token="${now}-$$-${RANDOM}"
        if ! mkdir "$lock_dir" 2>/dev/null; then
            if /usr/bin/stat -f '%m' "$lock_dir" &>/dev/null; then
                lock_mtime="$(/usr/bin/stat -f '%m' "$lock_dir" 2>/dev/null)"
            else
                lock_mtime="$(/usr/bin/stat -c '%Y' "$lock_dir" 2>/dev/null)"
            fi
            [[ "$lock_mtime" == <-> ]] || return 0
            (( now - lock_mtime >= stale_after )) || return 0

            stale_dir="${lock_dir}.stale.${update_lock_token}"
            mv "$lock_dir" "$stale_dir" 2>/dev/null || return 0
            if ! mkdir "$lock_dir" 2>/dev/null; then
                mv "$stale_dir" "$lock_dir" 2>/dev/null || true
                return 0
            fi
            command rm -f "$stale_dir/token" 2>/dev/null
            rmdir "$stale_dir" 2>/dev/null || true
        fi
        print -r -- "$update_lock_token" >| "$lock_dir/token"
        trap '
            current_token="$(<"$lock_dir/token" 2>/dev/null)"
            if [[ "$current_token" == "$update_lock_token" ]]; then
                command rm -f "$lock_dir/token" 2>/dev/null
                rmdir "$lock_dir" 2>/dev/null
            fi
        ' EXIT HUP INT TERM

        # Record the attempt before the network call so an offline machine does
        # not retry from every newly opened shell.
        print -r -- "$now" >| "$stamp_file"
        git -C "$repo" fetch --quiet --prune >/dev/null 2>&1
    }

    if [[ "${DOTFILES_TEST_UPDATE_CHECK_FOREGROUND:-0}" == 1 ]]; then
        _dotfiles_fetch_remote
    else
        _dotfiles_fetch_remote &!
    fi
    unfunction _dotfiles_fetch_remote 2>/dev/null || true
}

_dotfiles_update_check
unfunction _dotfiles_update_check 2>/dev/null || true
