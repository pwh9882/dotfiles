#!/bin/bash
# Claude Code StatusLine - Starship-inspired with Catppuccin Mocha theme
# Receives JSON from Claude Code with session information

# Parse JSON input
INPUT=$(cat)

# Get real terminal width via /dev/tty (tput returns 80 default in pipe context)
TERM_WIDTH=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
TERM_WIDTH=${TERM_WIDTH:-80}
# Reserve ~40% for Claude Code's built-in right status
MAX_WIDTH=$(( TERM_WIDTH * 60 / 100 ))

# Extract all values from JSON in a single jq call
eval $(echo "$INPUT" | jq -r '
  "CWD=\(.cwd // "" | @sh)",
  "OUTPUT_STYLE=\(.output_style.name // "" | @sh)",
  "MODEL_NAME=\(.model.display_name // "" | @sh)",
  "CTX_USED=\(.context_window.used_percentage // 0)",
  "LINES_ADDED=\(.cost.total_lines_added // 0)",
  "LINES_REMOVED=\(.cost.total_lines_removed // 0)",
  "SESSION_ID=\(.session_id // "" | @sh)",
  "TRANSCRIPT=\(.transcript_path // "" | @sh)"
')

# Catppuccin Mocha colors (dimmed for status line)
MAUVE="\033[38;5;183m"
YELLOW="\033[38;5;222m"
SAPPHIRE="\033[38;5;116m"
GREEN="\033[38;5;151m"
RED="\033[38;5;210m"
LAVENDER="\033[38;5;189m"
OVERLAY="\033[38;5;245m"
RESET="\033[0m"

# OS icon
OS_ICON="󰀵"

# Format directory (replace home with icon, truncate if too long)
DIR="$CWD"
if [[ "$DIR" == "$HOME"* ]]; then
    DIR="󰋜${DIR#$HOME}"
fi

# Truncate long paths
if [[ ${#DIR} -gt 50 ]]; then
    DIR="…${DIR: -47}"
fi

# Git info (use --no-optional-locks for performance)
GIT_BRANCH=""
GIT_STATUS=""
if git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
    # Get branch or commit
    BRANCH=$(git -C "$CWD" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || \
             git -C "$CWD" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

    if [ -n "$BRANCH" ]; then
        GIT_BRANCH=" on ${GREEN}${BRANCH}${RESET}"

        # Get status counts
        STATUS=$(git -C "$CWD" --no-optional-locks status --porcelain 2>/dev/null)
        STAGED=$(echo "$STATUS" | grep -c '^[MADRC]')
        MODIFIED=$(echo "$STATUS" | grep -c '^ [MD]')
        UNTRACKED=$(echo "$STATUS" | grep -c '^??')

        STATUS_STR=""
        [ "$STAGED" -gt 0 ] && STATUS_STR="${STATUS_STR}+${STAGED}"
        [ "$MODIFIED" -gt 0 ] && STATUS_STR="${STATUS_STR} !${MODIFIED}"
        [ "$UNTRACKED" -gt 0 ] && STATUS_STR="${STATUS_STR} ?${UNTRACKED}"

        if [ -n "$STATUS_STR" ]; then
            GIT_STATUS=" ${YELLOW}${STATUS_STR}${RESET}"
        fi
    fi
fi

# Output style indicator
STYLE_INDICATOR=""
if [ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ]; then
    STYLE_INDICATOR=" [${OUTPUT_STYLE}]"
fi

# Model name (already clean from display_name)
MODEL_SHORT="$MODEL_NAME"

# Context usage with color coding
CTX_INT=${CTX_USED%.*}
if [ "$CTX_INT" -ge 90 ] 2>/dev/null; then
    CTX_COLOR="$RED"
elif [ "$CTX_INT" -ge 70 ] 2>/dev/null; then
    CTX_COLOR="$YELLOW"
else
    CTX_COLOR="$GREEN"
fi
CTX_DISPLAY="${CTX_COLOR}${CTX_USED}%${RESET}"

# Lines added/removed
LINES_DISPLAY="${GREEN}+${LINES_ADDED}${RESET} ${RED}-${LINES_REMOVED}${RESET}"

# Session ID (shortened to first 7 chars)
SESSION_SHORT=""
if [ -n "$SESSION_ID" ]; then
    SESSION_SHORT="${OVERLAY}${SESSION_ID:0:7}${RESET}"
fi

# Last user prompt from transcript
LAST_PROMPT=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    LAST_PROMPT=$(tail -200 "$TRANSCRIPT" | grep '"type":"user"' | jq -r '
        if .message.content | type == "string" then .message.content
        elif .message.content | type == "array" then
            [.message.content[] | select(.type=="text") | .text | select(startswith("<") | not)] | join(" ")
        else "" end
    ' 2>/dev/null | grep -v '^$' | tail -1)
fi

# Helper: truncate a string with visible-length awareness (plain text, no ANSI)
truncate() {
    local str="$1" max="$2"
    if [ ${#str} -gt "$max" ]; then
        echo "${str:0:$((max - 3))}..."
    else
        echo "$str"
    fi
}

# Line 1: status info - build plain text to measure, then truncate components if needed
LINE1_PLAIN="${MODEL_SHORT} │ ctx ${CTX_USED}% │ +${LINES_ADDED} -${LINES_REMOVED} │ ${SESSION_ID:0:7}"
if [ ${#LINE1_PLAIN} -gt "$MAX_WIDTH" ]; then
    # Line 1 is mostly fixed-width, just output as-is (unlikely to overflow)
    :
fi
echo -e "${MODEL_SHORT} ${OVERLAY}│${RESET} ctx ${CTX_DISPLAY} ${OVERLAY}│${RESET} ${LINES_DISPLAY} ${OVERLAY}│${RESET} ${SESSION_SHORT}"

# Line 2: location & git + last prompt - dynamically allocate space
# Measure path+git portion
LINE2_BASE_PLAIN="X in ${DIR}"
[ -n "$BRANCH" ] && LINE2_BASE_PLAIN="${LINE2_BASE_PLAIN} on ${BRANCH}${STATUS_STR:+ $STATUS_STR}"
LINE2_BASE_LEN=${#LINE2_BASE_PLAIN}

# Remaining space for prompt (minus separator " │ ")
PROMPT_MAX=$(( MAX_WIDTH - LINE2_BASE_LEN - 3 ))
if [ "$PROMPT_MAX" -lt 10 ]; then
    # Not enough space, skip prompt
    LAST_PROMPT=""
elif [ -n "$LAST_PROMPT" ]; then
    LAST_PROMPT=$(truncate "$LAST_PROMPT" "$PROMPT_MAX")
fi

if [ -n "$LAST_PROMPT" ]; then
    echo -e "${LAVENDER}${OS_ICON}${RESET} in ${SAPPHIRE}${DIR}${RESET}${GIT_BRANCH}${GIT_STATUS}${STYLE_INDICATOR} ${OVERLAY}│ ${MAUVE}${LAST_PROMPT}${RESET}"
else
    echo -e "${LAVENDER}${OS_ICON}${RESET} in ${SAPPHIRE}${DIR}${RESET}${GIT_BRANCH}${GIT_STATUS}${STYLE_INDICATOR}"
fi