# ADR-0003: Fixed-Order Root Orchestration

## 상태

Accepted, 2026-07-10.

## 맥락

기존 루트 installer는 디렉터리를 glob 순서로 실행했습니다. 실행 순서가 파일 이름에 숨어 있어 package manager 준비 시점과 Module 간 중복 호출을 확인하기 어려웠습니다. 현재 각 `init.sh`는 package 설치, filesystem 연결, 외부 도구 설정을 함께 수행하며, Transaction Interface로 전환한 범위는 `bin`과 `agents-links`의 native link입니다.

현재 의존관계는 작고 고정되어 있습니다. 이 단계에서 범용 dependency graph를 도입하면 실제 rollback 계약보다 graph와 manifest 관리가 먼저 커집니다.

## 결정

- 루트 `init.sh`는 다음 고정 순서로 Module을 실행합니다.

  ```text
  bin → zsh → bash → agents → claude → ssh → tmux → .config
                                                    → karabiner (Darwin only)
  ```

- `bin`은 dotfiles CLI와 LLM-WIKI wrapper를 먼저 연결합니다.
- `zsh`는 현재 첫 package bootstrap Module입니다. macOS에서 Homebrew가 없으면 설치하므로, `claude`, `tmux`, `.config`가 Homebrew를 사용할 수 있는 상태를 먼저 만듭니다. package 책임을 별도 Module로 옮길 때까지 유지하는 과도기 배치입니다.
- 루트 runner가 Module 순서와 호출 횟수를 소유합니다. 각 Module은 자기 `init.sh`의 적용만 소유하고 다른 Module을 호출하지 않습니다. 한 번의 루트 실행에서 각 Module은 정확히 한 번 호출됩니다.
- Karabiner helper 컴파일은 Darwin에서만 마지막 Module로 추가합니다.
- 실행 전에 현재 플랫폼의 Module 파일을 모두 검증합니다. 실행 중 Module 하나가 실패하면 즉시 중단하고 해당 종료 코드를 반환합니다.
- 루트 실행 전체를 하나의 Transaction으로 취급하지 않습니다. rollback은 `bin`과 `agents-links`가 각 receipt에 기록한 filesystem 변경만 지원합니다. 다른 Module이 이미 수행한 package 설치, shell 변경, filesystem 변경은 루트 실패 시 자동 복구하지 않습니다.

상세 실행 계약은 [`docs/architecture/root-orchestration.md`](../architecture/root-orchestration.md)에 기록했습니다.

## 검토한 대안

### 디렉터리 glob 순회

새 디렉터리 이름이 실행 순서를 바꿀 수 있고, 플랫폼 조건과 bootstrap 의존관계가 코드에 드러나지 않습니다.

### 범용 dependency graph

현재 순서 제약은 Homebrew bootstrap과 Darwin 조건을 포함한 작은 고정 목록입니다. 두 번째 실제 의존관계와 선택적 Module 조합이 생기기 전에는 고정 배열이 더 직접적입니다.

### 루트 전체 자동 rollback

legacy Module은 package, `chsh`, 외부 repository, 사용자 파일을 함께 변경합니다. 각 변경의 receipt와 drift 검증이 없는 상태에서 자동 복구하면 apply 이후 변경을 덮어쓸 수 있습니다.

## 결과

- 루트 실행 순서와 플랫폼 분기가 한 파일에 명시됩니다.
- Module 간 재호출을 제거해 exact-once ownership을 유지합니다.
- fail-fast 이후 앞선 Module의 변경은 남을 수 있으므로, 실패한 Module을 수정한 뒤 멱등 실행을 다시 수행합니다.
- package bootstrap을 별도 Module로 추출하면 `zsh`의 Homebrew 책임과 현재 순서를 함께 조정합니다.
- Module별 rollback 계약이 준비된 범위만 Transaction runner에 편입합니다.
