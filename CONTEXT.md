# Dotfiles Context

## System

이 저장소는 여러 머신에서 공통 작업 경험을 배포하고 검증하는 개인 운영 시스템입니다. 셸·terminal·SSH·tmux·editor·agent harness 설정을 관리하며, 머신별 차이는 Role과 Capability로 표현합니다.

## Glossary

### Instance

`llm-instance`가 검증한 하나의 머신 identity입니다. hostname, username, IP, 홈 경로로 추론하지 않습니다.

### Role

Instance가 수행하는 운영 역할입니다. 예시는 `authoring-client`, `service-host`, `windows-workstation`, `headless-agent-worker`입니다.

### Capability

Role 또는 Instance에서 제공해야 하는 사용자 경험입니다. `core-terminal`, `workspace-picker`, `agent-harness`, `windows-wezterm-sync`처럼 검증 가능한 이름을 사용합니다.

### Machine Profile

Instance를 Role과 Capability 집합에 연결하는 공개 설정입니다. 비밀값, 사설 주소, 사용자별 절대경로를 담지 않습니다.

### Module

작은 Interface 뒤에 설치·검증·복구 동작을 숨기는 관리 단위입니다. 예시는 `bin`, `shell`, `tmux`, `agents`입니다.

### Adapter

같은 Interface를 특정 환경에 연결하는 구현입니다. shell, WezTerm, tmux, WSL, SSH Adapter가 동일한 Execution Plan을 소비할 수 있습니다.

### Workspace

논리적 project ID와 하나 이상의 Target을 연결한 작업 진입 단위입니다. Workspace ID는 머신 경로나 hostname이 바뀌어도 유지합니다.

### Target

Workspace가 실행될 수 있는 구체적인 위치입니다. transport, execution Instance, 경로, persistence 정책을 가집니다.

### Execution Plan

Workspace Resolver가 Registry와 현재 Instance를 바탕으로 만든 정규화된 실행 계획입니다. Adapter는 Registry 원본 대신 Execution Plan을 소비합니다.

### Execution Context

현재 프로세스가 실행되는 Instance, origin Instance, Workspace, Target, transport, persistence, repository 상태를 명시적으로 표현한 값입니다. 확인할 수 없는 필드는 추측하지 않고 비워 둡니다.

### Transaction

dotfiles 적용 한 번의 계획, 변경, backup, 검증 결과를 묶은 기록입니다. rollback은 Transaction이 관리한 filesystem 변경만 되돌립니다.

### Health Snapshot

`dotfiles doctor`가 만든 읽기 전용 검사 결과입니다. terminal status renderer는 외부 명령을 실행하지 않고 cached Health Snapshot만 읽습니다.

### Feature Registry

기능의 상태, 지원 Role·platform, 개인정보 정책, 첫 실행 명령, 검증 방법을 선언한 목록입니다. 온보딩 문서와 `dotfiles tour`가 이 목록을 소비합니다.

## System Map

```text
Machine Profile ──> Module Selection ──> Installer ──> Transaction
       │                                      │             │
       └──────────────> Doctor <──────────────┘             └─> rollback

Workspace Registry ──> Workspace Resolver ──> Execution Plan
                                                    │
                         ┌──────────┬──────────┬─────┴─────┐
                         ▼          ▼          ▼           ▼
                       shell     WezTerm      tmux       agent
                      Adapter    Adapter     Adapter     Adapter
                                                    │
                                                    ▼
                                            Execution Context
```

## Invariants

1. Instance identity는 `llm-instance` 결과만 사용합니다.
2. 공개 Registry에는 token, username, IP, MAC, identity file, 개인 절대경로를 넣지 않습니다.
3. `plan`과 `apply --dry-run`은 state directory를 포함해 아무 파일도 쓰지 않습니다.
4. Installer Module은 공통 filesystem primitive를 통해서만 관리 대상 파일을 변경합니다.
5. 기존 파일·디렉터리·다른 symlink 충돌은 기본적으로 중단합니다. `--backup`이 있을 때만 Transaction 안으로 이동합니다.
6. `doctor`와 `context`는 읽기 전용입니다. Git fetch와 remote probe를 암묵적으로 실행하지 않습니다.
7. runtime state와 recents는 XDG state/data directory에 두고 Git checkout에 쓰지 않습니다.
8. status renderer는 cached state를 읽으며 network probe나 subprocess를 hot path에서 실행하지 않습니다.
9. wake, restart, update, backup, remote apply는 allowlist된 Action을 사용자가 명시적으로 실행할 때만 수행합니다.
10. secret 값과 pane scrollback은 Transaction, handoff, runlog, LLM-WIKI에 기록하지 않습니다.
11. 모든 머신에 같은 파일을 강제하지 않습니다. 같은 Role의 Capability 계약을 검증합니다.
12. Adapter는 정규화된 Execution Plan을 소비하며 target 선택 규칙을 다시 구현하지 않습니다.

## Main Flows

### Apply

```text
Instance → Machine Profile → explicit Module selection → plan
→ Transaction 준비 → filesystem 변경 → doctor → receipt 확정
```

### Workspace entry

```text
Instance + Workspace ID → Registry merge → Target resolve
→ Execution Plan → platform Adapter → Execution Context
```

### Onboarding

```text
Feature Registry → available/pilot 상태 → 첫 실행 명령
→ 사용자 확인 → Instance별 acknowledged state
```

## Documentation Map

- [Architecture](docs/architecture/index.md): Module별 Interface와 구현 구조
- [ADRs](docs/adr/): 장기 설계 결정
- [Runbooks](docs/runbooks/index.md): 적용·검증·복구 절차
- [Agent domain rules](docs/agents/domain.md): engineering skill의 문서 소비 규칙
