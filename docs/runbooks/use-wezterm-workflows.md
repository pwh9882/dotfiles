# WezTerm 작업 흐름 온보딩

## 지원 범위

현재 바로 사용할 수 있는 WezTerm 기능은 세 가지입니다.

| Feature | Role | Platform | 상태 |
|---|---|---|---|
| `wezterm-context-status` | `authoring-client`, `windows-workstation` | macOS, Windows-side WezTerm | available |
| `wezterm-project-picker` | `authoring-client` | macOS | pilot |
| `wezterm-session-restore` | `authoring-client` | macOS | pilot |

WSL의 dotfiles는 Windows 쪽 WezTerm 설정으로 동기화됩니다. custom 프로젝트 picker와 session plugin은 현재 macOS에서만 활성화됩니다.

## 5분 온보딩

### 1. 상태 바 읽기

WezTerm을 열면 우측 상태 바가 다음 순서로 표시됩니다.

```text
[입력 mode] [현재 CWD 또는 workspace] [시각] [OS 아이콘 + host]
```

- `^A`는 WezTerm leader가 활성화된 상태입니다.
- `RESIZE`는 pane 크기 조절 mode입니다.
- 로컬 pane은 현재 CWD와 로컬 host를 표시하며, CWD 신호가 없을 때만 workspace를 대신 사용합니다.
- SSH pane은 감지한 원격 CWD와 host를 표시하고 탭 번호의 accent 색도 바뀝니다.
- tmux 안에서 pane title이 바뀌어도 마지막으로 확인한 원격 host와 CWD를 메모리에서 유지합니다.

상태 바는 pane title, WezTerm domain, `WEZTERM_HOST`, `WEZTERM_OS`, `WEZTERM_CWD`를 사용합니다. 이 값은 화면 표시를 위해 현재 WezTerm process 안에서만 cache합니다.

### 2. 프로젝트와 SSH host 열기

macOS WezTerm에서 `Ctrl+A`를 놓은 뒤 `p`를 누릅니다.

picker는 다음 항목을 한 목록에 표시합니다.

- `~/development/*`, `~/development/20*/*`, `~/dotfiles`
- `machine/local.lua`의 `project_globs`, `project_paths`
- `~/.ssh/config`의 wildcard가 없는 `Host` alias
- 최근에 사용한 유효 항목

프로젝트를 선택하면 해당 경로를 CWD로 가진 workspace를 엽니다. SSH 항목은 `ssh <alias>`를 실행한 workspace를 엽니다. 같은 basename을 가진 프로젝트도 전체 HOME 상대경로를 workspace ID에 포함하므로 서로 다른 session으로 유지됩니다.

최근 기록은 다음 runtime state에 저장합니다.

```text
${XDG_STATE_HOME:-$HOME/.local/state}/wezterm/project_history.txt
```

개인 경로, SSH 주소, 사용자명, identity file은 공개 Lua에 추가하지 않습니다. 필요하면 예시를 복사해 gitignored overlay에 기록합니다.

```console
mkdir -p ~/.config/wezterm/machine
cp ~/.config/wezterm/machine/local.example.lua \
  ~/.config/wezterm/machine/local.lua
```

### 3. workspace 저장과 복원

macOS에서는 다음 키부터 기억하면 됩니다.

| 키 | 동작 |
|---|---|
| `Ctrl+A`, `s` 또는 `f` | zoxide 기반 workspace 전환 |
| `Ctrl+A`, `S` | 직전 workspace로 이동 |
| `Alt+s` | 현재 workspace와 window 저장 |
| `Alt+o` | 저장된 workspace, window, tab 복원 |
| `Alt+d` | 저장된 state 삭제 |

layout과 실행 process metadata는 15분마다 저장하며 WezTerm 시작과 workspace 전환 시 복원합니다. pane text와 scrollback은 저장하거나 복원하지 않습니다. 처음 plugin을 불러오는 머신에서는 WezTerm이 GitHub의 `resurrect.wezterm`, `smart_workspace_switcher.wezterm` 저장소를 내려받을 수 있습니다.

`Alt+o`는 로컬에 저장한 layout을 다시 구성합니다. 원격 shell process까지 계속 실행하려면 서버에 `wezterm-mux-server`를 운영해야 합니다. 이 선택형 절차는 [WezTerm 원격 mux 가이드](../wezterm-mux.md)에서 다룹니다.

## 검증

저장소 root에서 다음 명령을 실행합니다.

```console
wezterm show-keys --lua
lua .config/wezterm/theme_test.lua
lua .config/wezterm/projects_test.lua
dotfiles doctor --quick
```

정상 결과는 다음을 의미합니다.

- `show-keys`가 설정 전체와 macOS plugin key binding을 로드했습니다.
- theme logic의 로컬·SSH·tmux·WSL 판별 회귀 테스트가 통과했습니다.
- project history 경로와 충돌 없는 workspace ID 테스트가 통과했습니다.
- 공통 설정의 문법과 개인정보 정책 검사가 통과했습니다.

상세 key binding과 원격 host 감지 우선순위는 [WezTerm 설정 문서](../../.config/wezterm/README.md)에서 확인합니다.
