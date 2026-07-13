# Root Orchestration

## Interface

```bash
./init.sh --list
./init.sh
```

`--list`는 현재 플랫폼에서 실행할 Module의 절대 경로를 순서대로 출력하고 파일을 변경하지 않습니다. 인자 없는 실행은 같은 목록을 검증한 뒤 순서대로 적용합니다. `--help`는 사용법을 출력하며, 지원하지 않는 인자나 두 개 이상의 인자는 종료 코드 `2`를 반환합니다.

## 실행 계획

공통 순서는 다음과 같습니다.

| 순서 | Module | 현재 역할 |
|---:|---|---|
| 1 | `bin/init.sh` | dotfiles CLI와 LLM-WIKI wrapper를 트랜잭션 방식으로 연결합니다. |
| 2 | `zsh/init.sh` | Zsh 설정과 공통 shell 도구를 적용합니다. macOS에서는 Homebrew를 먼저 준비합니다. |
| 3 | `bash/init.sh` | Bash 설정과 필요한 shell 도구를 적용합니다. |
| 4 | `agents/init.sh` | Claude/Codex link를 Transaction으로 적용한 뒤 Hermes/OpenClaw legacy post-config를 실행합니다. |
| 5 | `claude/init.sh` | Claude Code statusline과 `jq` 의존성을 적용합니다. |
| 6 | `ssh/init.sh` | 공통 SSH 설정과 WSL bridge 의존성을 적용합니다. |
| 7 | `tmux/init.sh` | tmux와 Oh My Tmux 설정을 적용합니다. |
| 8 | `.config/init.sh` | XDG 설정과 플랫폼별 terminal/editor 설정을 연결합니다. |
| 9 | `.config/karabiner/init.sh` | Darwin에서만 Karabiner helper를 컴파일합니다. |

`zsh`가 package bootstrap을 임시로 맡고 있어 Homebrew를 사용하는 Module보다 앞에 있습니다. 별도 package Module을 만들면 Homebrew 설치와 공통 package 소유권을 그 Module로 이동하고 순서를 다시 확정합니다.

## 실행 계약

루트 runner는 다음 규칙을 적용합니다.

1. 현재 플랫폼의 전체 Module 목록을 구성합니다.
2. 모든 `init.sh` 파일이 존재하는지 확인합니다.
3. 각 Module을 `bash`로 정확히 한 번 실행합니다.
4. Module이 0이 아닌 종료 코드를 반환하면 다음 Module을 실행하지 않고 같은 코드를 반환합니다.

Module 목록 검증은 첫 변경 전에 끝납니다. 실행 단계의 fail-fast는 이미 완료된 Module의 변경을 되돌리지 않습니다. 실패한 Module의 원인을 수정한 뒤 `./init.sh`를 다시 실행하며, 각 `init.sh`는 재실행 가능한 멱등 동작을 유지해야 합니다.

루트 runner는 순서와 호출을 소유합니다. Module은 자기 설정과 의존성만 적용하며 다른 Module의 `init.sh`를 호출하지 않습니다. 새 Module을 추가할 때는 루트 목록 한 곳에만 등록합니다.

## Transaction 경계

현재 `bin/init.sh`와 `agents/init.sh`의 Claude/Codex link 단계는 Transactional Installer에 위임하고 plan, receipt, drift 검증, rollback을 지원합니다. Hermes/OpenClaw 후처리와 나머지 Module은 기존 installer 방식으로 동작합니다. Zsh와 Bash는 package 작업 전에 Local Adapter를 검사합니다. Zsh, Bash, Claude statusline, tmux, `.config`의 legacy link는 공통 exact-link preflight를 사용해 기존 경로를 덮어쓰지 않습니다. Starship override와 Claude settings 생성은 임시 파일을 거쳐 교체합니다. package 설치, `chsh`, 외부 repository clone, legacy post-config는 루트 단위 rollback 대상에 포함되지 않습니다.

따라서 `./init.sh` 성공을 하나의 원자적 Transaction으로 해석하지 않습니다. `bin`과 `agents-links`는 출력된 각 Transaction ID로 복구하고, 다른 변경은 출력과 현재 상태를 확인해 개별적으로 복구합니다. 운영 절차는 [`bin` runbook](../runbooks/manage-bin-module.md)과 [`agents-links` runbook](../runbooks/manage-agents-links.md)에 기록합니다.

## 다음 추출 단계

1. Homebrew와 공통 package 목록을 별도 package Module로 옮기고 `zsh`, `claude`, `tmux`, `.config`의 설치 책임을 줄입니다.
2. filesystem 변경이 많은 Module부터 plan과 rollback 계약을 정의하고 Transaction Interface로 전환합니다.
3. 선택적 Module 조합이나 실제 Module 간 의존관계가 늘어나면 작은 선언형 manifest를 검토합니다. 현재 고정 배열로 표현되는 순서에는 dependency graph를 추가하지 않습니다.
4. 모든 포함 Module이 receipt와 복구 계약을 제공한 뒤에만 루트 실행 receipt 또는 복합 rollback을 검토합니다.

설계 결정은 [`ADR-0003`](../adr/0003-fixed-order-root-orchestration.md)에 기록했습니다.
