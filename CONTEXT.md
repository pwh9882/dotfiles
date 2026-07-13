# Dotfiles Context

## System

이 저장소는 여러 머신에 공통 작업 환경을 배포하고 검증합니다. 셸·terminal·SSH·tmux·editor·agent harness 설정을 관리하며, 공개 설정과 머신별 local 설정을 분리합니다.

## Glossary

### Instance

`llm-instance`가 검증한 하나의 머신 identity입니다. 에이전트와 인프라 작업에서 hostname, username, IP, 홈 경로로 추론하지 않습니다. dotfiles Module 선택에는 Instance나 Role을 사용하지 않습니다.

### Module

작은 Interface 뒤에 설치·검증·복구 동작을 숨기는 관리 단위입니다. Transaction Interface를 사용하는 Module은 현재 `bin`, `agents-links`입니다.

### Local Adapter

공개 설정을 한 머신의 환경에 연결하는 사용자 소유 파일입니다. Zsh와 Bash는 `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/` 아래 local 파일을 읽고, WezTerm은 gitignored `machine/local.lua`를 읽습니다.

### Transaction

dotfiles 적용 한 번의 계획, 변경, backup, 검증 결과를 묶은 기록입니다. rollback은 Transaction이 관리한 filesystem 변경만 되돌립니다.

### Writer Lock

filesystem을 변경하는 `apply`와 `rollback`을 직렬화하는 state directory lock입니다. `plan`, `doctor`, `history`, dry-run은 lock을 사용하지 않습니다.

### Health Check

`dotfiles doctor`와 `dotfiles-check`가 수행하는 읽기 전용 검사입니다. 저장소 문법, 정책, 회귀 테스트, 설치된 Module 상태를 확인합니다.

## System Map

```text
fixed Module order ──> plan ──> Writer Lock ──> Transaction ──> rollback
                           │                         │
                           └──────── doctor <────────┘

shared shell config ──> Local Adapter
WezTerm config      ──> machine/local.lua
```

## Invariants

1. 에이전트와 인프라 작업의 Instance identity는 `llm-instance` 결과만 사용합니다.
2. 공개 파일에는 token, username, IP, MAC, identity file, 개인 절대경로를 넣지 않습니다.
3. `plan`, `apply --dry-run`, `rollback --dry-run`, `doctor`, `history`는 filesystem 관리 대상을 변경하지 않습니다.
4. Transaction Module은 공통 filesystem primitive를 통해서만 관리 대상 파일을 변경합니다.
5. 기존 파일·디렉터리·다른 symlink 충돌은 기본적으로 중단합니다. `--backup`을 명시한 경우에만 Transaction 안으로 이동합니다.
6. 실제 `apply`와 `rollback`은 같은 Writer Lock을 사용합니다.
7. 새 Transaction directory는 원자적으로 생성하고 schema version을 기록합니다. version이 없는 기존 receipt는 legacy v1로 읽습니다.
8. Zsh 시작 시 background `git fetch`로 업데이트 존재 여부만 확인합니다. HEAD와 worktree는 사용자가 `git pull --ff-only`를 실행할 때만 바뀝니다.
9. runtime state는 XDG state/cache directory에 두고 Git checkout에 쓰지 않습니다.
10. secret 값과 pane scrollback은 Transaction, runlog, LLM-WIKI에 기록하지 않습니다.
11. 머신별 shell 설정은 checkout 밖의 Local Adapter에 둡니다. Installer는 package 작업 전에 Adapter type과 접근 권한을 검사합니다.

## Main Flows

### Apply

```text
fixed Module selection → 전체 preflight → Writer Lock
→ Module별 Transaction → filesystem 변경 → receipt 확정
```

### Update discovery

```text
Zsh start → fetched ref에서 ahead 확인 → 사용자에게 알림
→ background fetch → 사용자가 git pull --ff-only 실행
```

### Machine-local shell configuration

```text
shared zsh/bash config → XDG Local Adapter
→ migration 전 머신만 legacy ~/.zshrc.local 또는 ~/.bashrc.local
```

## Documentation Map

- [Architecture](docs/architecture/index.md): Module Interface와 구현 구조
- [ADRs](docs/adr/): 장기 설계 결정
- [Runbooks](docs/runbooks/index.md): 사용·적용·검증·복구 절차
- [Agent domain rules](docs/agents/domain.md): 문서 탐색 규칙
