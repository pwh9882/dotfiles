#!/bin/bash
# Claude Code StatusLine - Starship-inspired with Catppuccin Mocha theme
# Receives JSON from Claude Code via stdin
# Dependencies: jq, git, gh (optional, for PR status)

set -f  # Disable globbing for safety

# --- Input & Terminal ---
INPUT=$(cat)

TERM_WIDTH=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
TERM_WIDTH=${TERM_WIDTH:-80}
# Reserve ~35% right side for Claude Code notifications (updates, MCP errors, token warnings)
MAX_WIDTH=$(( TERM_WIDTH * 65 / 100 ))

# --- Parse JSON (single jq call) ---
eval $(printf '%s' "$INPUT" | jq -r '
  "CWD=\(.cwd // "" | @sh)",
  "OUTPUT_STYLE=\(.output_style.name // "" | @sh)",
  "MODEL_NAME=\(.model.display_name // "" | @sh)",
  "CTX_USED=\(.context_window.used_percentage // 0)",
  "LINES_ADDED=\(.cost.total_lines_added // 0)",
  "LINES_REMOVED=\(.cost.total_lines_removed // 0)",
  "SESSION_ID=\(.session_id // "" | @sh)",
  "TRANSCRIPT=\(.transcript_path // "" | @sh)"
')

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

# Cross-platform file age in seconds (macOS + Linux)
file_age() {
    local mtime
    mtime=$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0)
    echo $(( $(date +%s) - mtime ))
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

# --- Context usage (color-coded) ---
CTX_INT=${CTX_USED%.*}
if [ "${CTX_INT:-0}" -ge 90 ] 2>/dev/null; then CTX_COLOR="$RED"
elif [ "${CTX_INT:-0}" -ge 70 ] 2>/dev/null; then CTX_COLOR="$YELLOW"
else CTX_COLOR="$GREEN"; fi

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

# === Line 1: model, ctx, diff, path (65% width-aware) ===
DIFF_PART="${GREEN}+${LINES_ADDED}${RESET} ${RED}-${LINES_REMOVED}${RESET}"

L1_CORE="${MODEL_NAME} | ctx ${CTX_USED}% | +${LINES_ADDED} -${LINES_REMOVED}"
L1_WITH_DIR="${L1_CORE} | X in ${DIR}"

if [ "${#L1_WITH_DIR}" -le "$MAX_WIDTH" ]; then
    printf '%b\n' "${MODEL_NAME} ${SEP} ctx ${CTX_COLOR}${CTX_USED}%${RESET} ${SEP} ${DIFF_PART} ${SEP} ${LAVENDER}${OS_ICON}${RESET} in ${SAPPHIRE}${DIR}${RESET}${STYLE_INDICATOR}"
else
    printf '%b\n' "${MODEL_NAME} ${SEP} ctx ${CTX_COLOR}${CTX_USED}%${RESET} ${SEP} ${DIFF_PART}"
fi

# === Line 2: session ID + git/PR ===
GIT_FORMATTED="${GREEN}${BRANCH}${RESET}${GIT_STATUS}${PR_DISPLAY}"
GIT_PLAIN="${BRANCH}${STATUS_STR}${PR_NUM:+ #$PR_NUM}"

if [ -n "$GIT_PLAIN" ]; then
    printf '%b\n' "${OVERLAY}${SESSION_ID}${RESET} ${SEP} ${GIT_FORMATTED}"
else
    printf '%b\n' "${OVERLAY}${SESSION_ID}${RESET}"
fi

# === Line 3: last prompt (width-aware) ===
if [ -n "$LAST_PROMPT" ]; then
    LAST_PROMPT=$(truncate "$LAST_PROMPT" "$MAX_WIDTH")
    printf '%b\n' "${MAUVE}${LAST_PROMPT}${RESET}"
fi
