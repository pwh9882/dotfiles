# ssh-agent에 SSH config의 키를 등록
# 노트북 세션 동안 passphrase 재입력 없이 재접속 가능
# 사용법: source ~/dotfiles/ssh/ssh-agent-add.sh <host>

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "source로 실행하세요: source $0 <host>"
    exit 1
fi

if [[ -z "$1" ]]; then
    echo "사용법: source $0 <ssh-host>"
    return 1
fi

_SAA_HOST="$1"
_SAA_ENV="$HOME/.ssh/agent.env"
_SAA_KEY=$(awk -v host="$_SAA_HOST" '$1=="Host" && $2==host{found=1} found && /IdentityFile/{print $2; exit}' ~/.ssh/config)
_SAA_KEY="${_SAA_KEY/#\~/$HOME}"

# ssh-agent 재사용 또는 새로 시작
if [[ -f "$_SAA_ENV" ]]; then
    . "$_SAA_ENV" > /dev/null
    kill -0 "$SSH_AGENT_PID" 2>/dev/null || {
        eval "$(ssh-agent -s)" > /dev/null
        echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > "$_SAA_ENV"
        echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> "$_SAA_ENV"
        echo "ssh-agent started (PID: $SSH_AGENT_PID)"
    }
else
    eval "$(ssh-agent -s)" > /dev/null
    echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > "$_SAA_ENV"
    echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> "$_SAA_ENV"
    echo "ssh-agent started (PID: $SSH_AGENT_PID)"
fi

# 키가 있으면 agent에 등록, 없으면 ControlMaster로 연결 유지
if [[ -n "$_SAA_KEY" && -f "$_SAA_KEY" ]]; then
    _SAA_FP=$(ssh-keygen -lf "$_SAA_KEY" 2>/dev/null | awk '{print $2}')
    if [[ -z "$_SAA_FP" ]] || ! ssh-add -l 2>/dev/null | grep -q "$_SAA_FP"; then
        echo "Adding key: $_SAA_KEY"
        ssh-add "$_SAA_KEY"
    fi
else
    mkdir -p "$HOME/.ssh/sockets"
    if ssh -O check "$_SAA_HOST" 2>/dev/null; then
        echo "ControlMaster already active for: $_SAA_HOST"
    else
        echo "Starting ControlMaster for: $_SAA_HOST"
        ssh -fNM "$_SAA_HOST"
    fi
fi

unset _SAA_HOST _SAA_ENV _SAA_KEY _SAA_FP
