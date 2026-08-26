# ssht: SSH directly into a remote tmux session.

_ssht_usage() {
    print -u2 "usage: ssht [ssh-options] <host> [session]"
    print -u2 "       ssht [ssh-options] <host> (-n|--new) <session>"
}

_ssht_remote_script() {
    cat <<'REMOTE_SCRIPT'
if ! command -v tmux >/dev/null 2>&1; then
    echo "ssht: tmux not found on remote host" >&2
    exit 127
fi

mode=$1
query=$2

if [ "$mode" = default ]; then
    tmux attach-session 2>/dev/null || exec tmux new-session
    exit $?
fi

if [ "$mode" = new ]; then
    exec tmux new-session -s "$query"
fi

sessions=$(tmux list-sessions -F '#S' 2>/dev/null) || sessions=

result=$(
    printf '%s' "$sessions" |
    awk -v query="$query" '
        function min3(a, b, c) {
            m = a < b ? a : b
            return m < c ? m : c
        }
        function distance(a, b,    i, j, cost, value, matrix) {
            delete matrix
            for (i = 0; i <= length(a); i++) matrix[i, 0] = i
            for (j = 0; j <= length(b); j++) matrix[0, j] = j
            for (i = 1; i <= length(a); i++) {
                for (j = 1; j <= length(b); j++) {
                    cost = substr(a, i, 1) == substr(b, j, 1) ? 0 : 1
                    value = min3(matrix[i - 1, j] + 1,
                                 matrix[i, j - 1] + 1,
                                 matrix[i - 1, j - 1] + cost)
                    if (i > 1 && j > 1 &&
                        substr(a, i, 1) == substr(b, j - 1, 1) &&
                        substr(a, i - 1, 1) == substr(b, j, 1) &&
                        matrix[i - 2, j - 2] + 1 < value)
                        value = matrix[i - 2, j - 2] + 1
                    matrix[i, j] = value
                }
            }
            return matrix[length(a), length(b)]
        }
        BEGIN {
            normalized_query = tolower(query)
            gsub(/[-_. ]/, "", normalized_query)
            best = 1000000
            count = 0
        }
        {
            original = $0
            normalized = tolower(original)
            gsub(/[-_. ]/, "", normalized)
            score = distance(normalized_query, normalized)
            if (tolower(original) == tolower(query)) score = -1
            if (score < best) {
                best = score
                count = 1
                names = original
                best_length = length(normalized)
            } else if (score == best) {
                count++
                names = names ", " original
                if (length(normalized) > best_length)
                    best_length = length(normalized)
            }
        }
        END {
            comparison_length = length(normalized_query)
            if (best_length > comparison_length)
                comparison_length = best_length
            threshold = int((comparison_length + 2) / 3)
            if (threshold < 1) threshold = 1
            if (count == 1 && best <= threshold)
                print "match\t" names
            else if (count > 1 && best <= threshold)
                print "ambiguous\t" names
            else
                print "missing\t" query
        }
    '
)

match_outcome=${result%%	*}
value=${result#*	}
show_sessions() {
    if [ -n "$sessions" ]; then
        printf 'ssht: available tmux sessions:\n' >&2
        printf '%s\n' "$sessions" | sed 's/^/  /' >&2
    else
        printf 'ssht: available tmux sessions: (none)\n' >&2
    fi
}

case "$match_outcome" in
    match)
        if [ "$value" != "$query" ]; then
            printf 'ssht: matched tmux session %s -> %s\n' "$query" "$value" >&2
        fi
        exec tmux attach-session -t "=$value"
        ;;
    ambiguous)
        printf 'ssht: ambiguous tmux session %s: %s\n' "$query" "$value" >&2
        show_sessions
        exit 2
        ;;
    missing)
        printf 'ssht: tmux session not found: %s\n' "$query" >&2
        show_sessions
        printf 'ssht: create one with: ssht <host> -n %s\n' "$query" >&2
        exit 2
        ;;
esac
REMOTE_SCRIPT
}

ssht() {
    if (( $# == 0 )); then
        _ssht_usage
        return 2
    fi

    local host="" mode=default session=""
    local remote_script remote_command
    local -a ssh_args trailing
    local argument
    integer option_needs_value=0

    ssh_args=("$@")
    for argument in "$@"; do
        if (( option_needs_value )); then
            option_needs_value=0
            continue
        fi
        if [[ -z "$host" ]]; then
            case "$argument" in
                --) continue ;;
                -[BbCcDEeFIiJLlmOoPpQRSWw]) option_needs_value=1; continue ;;
                -[BbCcDEeFIiJLlmOoPpQRSWw]?*) continue ;;
                -*) continue ;;
                *) host="$argument"; continue ;;
            esac
        fi
        trailing+=("$argument")
    done

    if [[ -z "$host" || $option_needs_value -ne 0 ]]; then
        _ssht_usage
        return 2
    fi

    case ${#trailing[@]} in
        0) ;;
        1)
            mode=find
            session=${trailing[1]}
            ;;
        2)
            if [[ ${trailing[1]} != -n && ${trailing[1]} != --new ]]; then
                _ssht_usage
                return 2
            fi
            mode=new
            session=${trailing[2]}
            ;;
        *)
            _ssht_usage
            return 2
            ;;
    esac

    if [[ -n "$session" ]]; then
        ssh_args=("${ssh_args[@]:0:${#ssh_args[@]}-${#trailing[@]}}")
    fi

    # Make WezTerm show the destination immediately. precmd restores local vars.
    if (( $+functions[_wezterm_user_var] )); then
        _wezterm_user_var WEZTERM_HOST "$(printf '%s' "${host##*@}" | base64)"
        _wezterm_user_var WEZTERM_OS ""
        _wezterm_user_var WEZTERM_CWD ""
    fi

    remote_script="$(_ssht_remote_script)"
    remote_command="exec \"\${SHELL:-/bin/sh}\" -lic ${(q)remote_script} ssht ${(q)mode} ${(q)session}"
    command ssh -t "${ssh_args[@]}" "$remote_command"
}

if (( $+functions[compdef] )); then
    compdef _ssh ssht
fi
