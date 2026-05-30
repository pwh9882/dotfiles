#!/bin/bash
# Claude Code StatusLine — Starship-inspired, Catppuccin Mocha theme.
# Reads the status JSON from Claude Code on stdin. Deps: jq, git, gh (optional, PR status).
#
# ── Layout ────────────────────────────────────────────────────────────────────
#   L1  Claude:  <model> <1M badge> <effort> <✻thinking> <⚡fast> │ ctx <%> │
#                <rate limits…> │ v<version>
#   L2  Repo:    <branch> <git status> <#PR> │ <os> in <path>
#   L3  Session: ✎ <session name | uuid> │ ↑ <uptime> │ +<added>/-<removed this session>
#   L4  Prompt:  the last user prompt (dim), width-truncated
#
# ── Rate limits — needs decoding ──────────────────────────────────────────────
#   Each window renders as:   ⟳ <time-to-reset> <quota-remaining %>      e.g.  ⟳ 4h 95%
#   The old "5h"/"7d" text labels were dropped; the time-to-reset replaced them.
#   Three INDEPENDENT colors, each a separate signal:
#     ⟳     window identity:  sapphire = 5-hour window,  mauve = 7-day window.
#     time  burn pace (spend speed vs time left in the window):
#             green  quota will outlast the window — using it leisurely
#             yellow a bit ahead of pace
#             red    spending too fast — will run dry well before reset
#           pace(): green if  qrem×window ≥ 100×time_left ;  yellow if ≥ 50× ;  else red.
#     %     quota left (100 − used):  green plenty · yellow ~half · red almost gone.
#   Read together: "⟳ 5m 10%" = quota nearly spent (red %) BUT resets in 5m (green time),
#   so it's fine; "⟳ 7d 10%" (both red) = heavily spent with a whole week still to go.
#
# ── Other glyphs ──────────────────────────────────────────────────────────────
#   ✻ thinking on   ⚡ fast mode   ↑ uptime   ✎ session name
#   git status:  +N staged · !N modified · ?N untracked   ·   #N open PR

set -f  # Disable globbing for safety

# --- Input & Terminal ---
INPUT=$(cat)

# Claude Code (v2.1.153+) exports COLUMNS/LINES; fall back to stty.
TERM_WIDTH=${COLUMNS:-$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')}
TERM_WIDTH=${TERM_WIDTH:-80}
# Reserve ~35% right side for Claude Code notifications (updates, MCP errors, token warnings)
MAX_WIDTH=$(( TERM_WIDTH * 65 / 100 ))

# --- Parse JSON (single jq call) ---
eval "$(printf '%s' "$INPUT" | jq -r '
  "CWD=\(.cwd // "" | @sh)",
  "OUTPUT_STYLE=\(.output_style.name // "" | @sh)",
  "MODEL_NAME=\(.model.display_name // "" | @sh)",
  "VERSION=\(.version // "" | @sh)",
  "SESSION_ID=\(.session_id // "" | @sh)",
  "SESSION_NAME=\(.session_name // "" | @sh)",
  "TRANSCRIPT=\(.transcript_path // "" | @sh)",
  "EFFORT=\(.effort.level // "" | @sh)",
  "THINKING=\(.thinking.enabled // false)",
  "FAST=\(.fast_mode // false)",
  "CTX_USED=\(.context_window.used_percentage // 0)",
  "CTX_TOKENS=\(.context_window.total_input_tokens // 0)",
  "CTX_SIZE=\(.context_window.context_window_size // 0)",
  "COST=\(.cost.total_cost_usd // 0)",
  "DUR_MS=\(.cost.total_duration_ms // 0)",
  "LINES_ADD=\(.cost.total_lines_added // 0)",
  "LINES_DEL=\(.cost.total_lines_removed // 0)",
  "RL5_PCT=\(.rate_limits.five_hour.used_percentage // -1)",
  "RL5_RESET=\(.rate_limits.five_hour.resets_at // 0)",
  "RL7_PCT=\(.rate_limits.seven_day.used_percentage // -1)",
  "RL7_RESET=\(.rate_limits.seven_day.resets_at // 0)"
')"

# --- Colors (Catppuccin Mocha, 256-color) ---
MAUVE="\033[38;5;183m"
YELLOW="\033[38;5;222m"
SAPPHIRE="\033[38;5;116m"
GREEN="\033[38;5;151m"
RED="\033[38;5;210m"
LAVENDER="\033[38;5;189m"
OVERLAY="\033[38;5;245m"
RESET="\033[0m"
SEP="${OVERLAY}│${RESET}"

# --- Helpers ---
truncate() {
    local str="$1" max="$2"
    if [ "${#str}" -gt "$max" ]; then
        printf '%s' "${str:0:$((max - 1))}…"
    else
        printf '%s' "$str"
    fi
}

# Cross-platform file age in seconds (GNU/Linux first, then macOS BSD)
file_age() {
    local mtime
    mtime=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0)
    case "$mtime" in ''|*[!0-9]*) mtime=0 ;; esac
    echo $(( $(date +%s) - mtime ))
}

# Compact token count: 51022 -> 51k, 1000000 -> 1M
fmt_tok() {
    local n=${1:-0}
    if   [ "$n" -ge 1000000 ]; then printf '%dM' "$(( n / 1000000 ))"
    elif [ "$n" -ge 1000 ];    then printf '%dk' "$(( n / 1000 ))"
    else printf '%d' "$n"; fi
}

# Compact duration from ms: 45s / 7m / 1h5m
fmt_dur() {
    local s=$(( ${1:-0} / 1000 ))
    if   [ "$s" -lt 60 ];   then printf '%ds' "$s"
    elif [ "$s" -lt 3600 ]; then printf '%dm' "$(( s / 60 ))"
    else printf '%dh%dm' "$(( s / 3600 ))" "$(( (s % 3600) / 60 ))"; fi
}

# Coarse time remaining until an epoch (largest single unit): 45m / 4h / 7d
fmt_until() {
    local rem=$(( ${1:-0} - $(date +%s) ))
    [ "$rem" -lt 0 ] && rem=0
    if   [ "$rem" -lt 3600 ];  then printf '%dm' "$(( rem / 60 ))"
    elif [ "$rem" -lt 86400 ]; then printf '%dh' "$(( rem / 3600 ))"
    else printf '%dd' "$(( rem / 86400 ))"; fi
}

# Color by usage %: <50 green, <80 yellow, else red
pct_color() {
    local p=${1:-0}
    if   [ "$p" -ge 80 ]; then printf '%b' "$RED"
    elif [ "$p" -ge 50 ]; then printf '%b' "$YELLOW"
    else printf '%b' "$GREEN"; fi
}

# Burn-pace color: compare quota-remaining vs time-remaining in the window.
# Green when quota outlasts the time left (leisurely), red when spending too fast.
# Args: used% · resets_at(epoch) · window_duration(sec).  ratio = qrem*wdur / (100*trem).
pace_color() {
    local used=${1:-0} trem=$(( ${2:-0} - $(date +%s) )) wdur=${3:-1}
    [ "$trem" -lt 1 ] && trem=1   # about to reset → treat time as ~0 (no worries → green)
    local qrem=$(( 100 - used ))
    if   [ $(( qrem * wdur )) -ge $(( 100 * trem )) ]; then printf '%b' "$GREEN"
    elif [ $(( qrem * wdur )) -ge $(( 50 * trem )) ];  then printf '%b' "$YELLOW"
    else printf '%b' "$RED"; fi
}

# --- OS icon ---
case "$(uname -s)" in
    Linux*)
        if [ -f /etc/os-release ]; then
            _DISTRO=$(. /etc/os-release && printf '%s' "$ID")
        fi
        case "$_DISTRO" in
            ubuntu)  OS_ICON=$'\xef\x8c\x9b' ;;
            debian)  OS_ICON=$'\xef\x8c\x86' ;;
            fedora)  OS_ICON=$'\xef\x8c\x8a' ;;
            arch)    OS_ICON=$'\xef\x8c\x83' ;;
            *)       OS_ICON=$'\xef\x85\xbc' ;;
        esac
        ;;
    Darwin*) OS_ICON=$'\xf3\xb0\x80\xb5' ;;
    *)       OS_ICON=$'\xef\x84\x88' ;;
esac

# --- Model name (strip verbose "(1M context)" suffix; shown in ctx instead) ---
MODEL_NAME=${MODEL_NAME% (*context)}

# --- Directory ---
DIR="$CWD"
[[ "$DIR" == "$HOME"* ]] && DIR="󰋜${DIR#$HOME}"
[ "${#DIR}" -gt 50 ] && DIR="…${DIR: -47}"

# --- Git (cached, 5s TTL) ---
BRANCH="" STATUS_STR="" GIT_BRANCH="" GIT_STATUS="" PR_DISPLAY=""

if git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
    GIT_DIR=$(git -C "$CWD" rev-parse --git-dir 2>/dev/null)
    CACHE_DIR="${GIT_DIR}/statusline-cache"
    mkdir -p "$CACHE_DIR" 2>/dev/null

    GIT_CACHE="${CACHE_DIR}/git"
    PR_CACHE="${CACHE_DIR}/pr"

    # Git status cache (5s TTL)
    if [ ! -f "$GIT_CACHE" ] || [ "$(file_age "$GIT_CACHE")" -gt 5 ]; then
        BRANCH=$(git -C "$CWD" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || \
                 git -C "$CWD" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
        if [ -n "$BRANCH" ]; then
            STATUS=$(git -C "$CWD" --no-optional-locks status --porcelain 2>/dev/null)
            STAGED=$(printf '%s' "$STATUS" | grep -c '^[MADRC]')
            MODIFIED=$(printf '%s' "$STATUS" | grep -c '^ [MD]')
            UNTRACKED=$(printf '%s' "$STATUS" | grep -c '^??')
            printf '%s\n' "${BRANCH}|${STAGED}|${MODIFIED}|${UNTRACKED}" > "$GIT_CACHE"
        else
            printf '%s\n' "|||" > "$GIT_CACHE"
        fi
    fi
    IFS='|' read -r BRANCH STAGED MODIFIED UNTRACKED < "$GIT_CACHE"

    if [ -n "$BRANCH" ]; then
        GIT_BRANCH=" on ${GREEN}${BRANCH}${RESET}"

        STATUS_STR=""
        [ "${STAGED:-0}" -gt 0 ] && STATUS_STR="${STATUS_STR}+${STAGED}"
        [ "${MODIFIED:-0}" -gt 0 ] && STATUS_STR="${STATUS_STR} !${MODIFIED}"
        [ "${UNTRACKED:-0}" -gt 0 ] && STATUS_STR="${STATUS_STR} ?${UNTRACKED}"
        STATUS_STR="${STATUS_STR# }"   # drop leading space when staged (+) is absent
        [ -n "$STATUS_STR" ] && GIT_STATUS=" ${YELLOW}${STATUS_STR}${RESET}"

        # PR status cache (60s TTL) - only if gh is available
        if command -v gh > /dev/null 2>&1; then
            if [ ! -f "$PR_CACHE" ] || [ "$(file_age "$PR_CACHE")" -gt 60 ]; then
                PR_NUM=$(gh pr view --json number -q '.number' 2>/dev/null || echo "")
                if [ -n "$PR_NUM" ]; then
                    PR_STATE=$(gh pr checks --json name,state -q '[.[] | .state] | if all(. == "SUCCESS") then "ok" elif any(. == "FAILURE") then "fail" else "pending" end' 2>/dev/null || echo "")
                    printf '%s\n' "${PR_NUM}|${PR_STATE}" > "$PR_CACHE"
                else
                    printf '%s\n' "|" > "$PR_CACHE"
                fi
            fi
            IFS='|' read -r PR_NUM PR_STATE < "$PR_CACHE"

            if [ -n "$PR_NUM" ]; then
                case "$PR_STATE" in
                    ok)      PR_DISPLAY=" ${GREEN}#${PR_NUM}${RESET}" ;;
                    fail)    PR_DISPLAY=" ${RED}#${PR_NUM}${RESET}" ;;
                    pending) PR_DISPLAY=" ${YELLOW}#${PR_NUM}${RESET}" ;;
                    *)       PR_DISPLAY=" ${OVERLAY}#${PR_NUM}${RESET}" ;;
                esac
            fi
        fi
    fi
fi

# --- Output style ---
STYLE_INDICATOR=""
[ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ] && STYLE_INDICATOR=" [${OUTPUT_STYLE}]"

# --- Model indicators: 1M-context badge · effort · thinking · fast ---
# Window badge marks an above-default context window (e.g. 1M); hidden on the 200k default.
WIN_BADGE=""
[ "${CTX_SIZE:-0}" -gt 200000 ] && WIN_BADGE=" ${SAPPHIRE}$(fmt_tok "$CTX_SIZE")${RESET}"
IND=""
[ -n "$EFFORT" ] && IND=" ${OVERLAY}${EFFORT}${RESET}"
[ "$THINKING" = "true" ] && IND="${IND} ${MAUVE}✻${RESET}"
[ "$FAST" = "true" ] && IND="${IND} ${YELLOW}⚡${RESET}"
MODEL_SEG="${MODEL_NAME}${WIN_BADGE}${IND}"

# --- Context usage (color-coded); window size is shown as the model 1M badge ---
CTX_INT=${CTX_USED%.*}
CTX_COLOR=$(pct_color "${CTX_INT:-0}")
CTX_SEG="ctx ${CTX_COLOR}${CTX_USED}%${RESET}"

# --- Last user prompt (from transcript, tail for performance) ---
LAST_PROMPT=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    LAST_PROMPT=$(tail -200 "$TRANSCRIPT" | grep '"type":"user"' | jq -r '
        if .message.content | type == "string" then .message.content
        elif .message.content | type == "array" then
            [.message.content[] | select(.type=="text") | .text | select(startswith("<") | not)] | join(" ")
        else "" end
    ' 2>/dev/null | grep -v '^$' | tail -1)
fi

# === Line 1: Claude metadata — model/effort, ctx, rate limits, version ===
# Values hug their labels (tight); only the ⟳ countdown is back-padded so the
# 7d column doesn't jitter every minute as it ticks down.
L1_SEGS=("$CTX_SEG")
# Rate limits per window: <⟳ window-tint> <time-to-reset · pace-tint> <quota remaining % · usage-tint>.
#   ⟳    color identifies the window (sapphire = 5h, mauve = 7d) now that the labels are gone.
#   time color = burn pace: green if quota outlasts the time left, red if spending too fast.
#   %    color = quota left: red when little remains.
RL5_INT=${RL5_PCT%.*}
if [ "${RL5_INT:--1}" -ge 0 ]; then
    L1_SEGS+=("${SAPPHIRE}⟳${RESET} $(pace_color "$RL5_INT" "$RL5_RESET" 18000)$(fmt_until "$RL5_RESET")${RESET} $(pct_color "$RL5_INT")$(( 100 - RL5_INT ))%${RESET}")
fi
RL7_INT=${RL7_PCT%.*}
if [ "${RL7_INT:--1}" -ge 0 ]; then
    L1_SEGS+=("${MAUVE}⟳${RESET} $(pace_color "$RL7_INT" "$RL7_RESET" 604800)$(fmt_until "$RL7_RESET")${RESET} $(pct_color "$RL7_INT")$(( 100 - RL7_INT ))%${RESET}")
fi
[ -n "$VERSION" ] && L1_SEGS+=("${OVERLAY}v${VERSION}${RESET}")

L1="$MODEL_SEG"
for s in "${L1_SEGS[@]}"; do L1="${L1} ${SEP} ${s}"; done
printf '%b\n' "$L1"

# === Line 2: repository — branch/status/PR, path (churn lives on L3, it's per-session) ===
GIT_FORMATTED="${GREEN}${BRANCH}${RESET}${GIT_STATUS}${PR_DISPLAY}"
DIR_SEG="${LAVENDER}${OS_ICON}${RESET} in ${SAPPHIRE}${DIR}${RESET}${STYLE_INDICATOR}"
if [ -n "$BRANCH" ]; then
    printf '%b\n' "${GIT_FORMATTED} ${SEP} ${DIR_SEG}"
else
    printf '%b\n' "$DIR_SEG"
fi

# === Line 3: session — name, uptime, churn (this session's own edits) ===
# Falls back to the full UUID when unnamed — the only resume token in that case.
SESS="${OVERLAY}↑ $(fmt_dur "$DUR_MS")${RESET}"
if [ "${LINES_ADD:-0}" -gt 0 ] || [ "${LINES_DEL:-0}" -gt 0 ]; then
    SESS="${SESS} ${SEP} ${GREEN}+${LINES_ADD}${RESET}/${RED}-${LINES_DEL}${RESET}"
fi
if [ -n "$SESSION_NAME" ]; then
    printf '%b\n' "${LAVENDER}✎ $(truncate "$SESSION_NAME" "$((MAX_WIDTH - 22))")${RESET} ${SEP} ${SESS}"
else
    printf '%b\n' "${OVERLAY}${SESSION_ID}${RESET} ${SEP} ${SESS}"
fi

# === Line 4: last prompt (width-aware) ===
if [ -n "$LAST_PROMPT" ]; then
    LAST_PROMPT=$(truncate "$LAST_PROMPT" "$((MAX_WIDTH - 10))")
    printf '%b\n' "${MAUVE}${LAST_PROMPT}${RESET}"
fi
