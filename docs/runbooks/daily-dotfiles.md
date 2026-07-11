# Dotfiles 사용 안내

## 평소에는 자동으로 동작합니다

셸, WezTerm, tmux, editor 설정은 저장소 파일에 연결되어 있습니다. 새 셸은 6시간 간격으로 background `git fetch`를 실행합니다. 새 커밋이 있으면 다음 셸에서 다음과 같이 알려줍니다.

```text
dotfiles: 업데이트 3개 있음 — git -C /path/to/dotfiles pull --ff-only
```

알림이 나오면 작업 중인 설정 변경을 확인한 뒤 표시된 명령을 실행합니다. background 작업은 HEAD와 worktree를 변경하지 않습니다.

## 기억할 명령

```console
dotfiles doctor --quick
```

저장소 문법, 설정 정책, 빠른 회귀 검사를 확인합니다. 평소 상태 확인은 이 명령 하나면 충분합니다.

```console
dotfiles plan
dotfiles apply
```

`~/.local/bin` 도구와 Claude/Codex 공통 지침 link를 새 머신에 배치하거나 복구할 때 사용합니다. `plan`은 파일을 바꾸지 않습니다. 충돌이 있으면 `apply`도 변경 전에 중단합니다.

```console
dotfiles history
dotfiles rollback TX_ID --dry-run
dotfiles rollback TX_ID
```

Transaction으로 적용한 link를 되돌릴 때 사용합니다. package 설치와 전체 `init.sh`는 rollback 범위에 포함되지 않습니다.

## 유용한 기능

### WezTerm

| 키 | 동작 |
|---|---|
| `Ctrl+A`, `p` | 프로젝트와 SSH host picker |
| `Ctrl+A`, `s` 또는 `f` | workspace 전환 |
| `Ctrl+A`, `S` | 직전 workspace |
| `Alt+s` | session layout 저장 |
| `Alt+o` | session layout 복원 |

상태 바는 현재 CWD, workspace, host, OS, 입력 mode를 보여줍니다. 자세한 사용법은 [WezTerm 작업 흐름](use-wezterm-workflows.md)에 있습니다.

### Shell

- `j <이름>`: zoxide로 최근 디렉터리 이동
- `v`: Neovim
- `ll`, `la`: 파일 목록
- `gd`: macOS에서 로컬 Google Drive 열기

머신별 값은 다음 위치에 둡니다.

```text
~/.config/dotfiles/zsh.local
~/.config/dotfiles/zshenv.local
~/.config/dotfiles/bash.local
~/.zshenv.secrets
```

## 새 머신에서만 실행

```console
git clone https://github.com/pwh9882/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bin/dotfiles plan
./bin/dotfiles apply
./init.sh --list
./init.sh
dotfiles doctor --full
```

`./init.sh`는 package 설치, 외부 download, `sudo`, `chsh`를 포함할 수 있습니다. `--list`로 실행 순서를 먼저 확인합니다.
