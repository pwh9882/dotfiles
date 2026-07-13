# ADR-0002: Transactional Filesystem Apply

## 상태

Accepted, 2026-07-10.

## 맥락

기존 installer는 Module별로 `ln -sf`를 실행해 적용 전 변경 내용을 확인하기 어렵고, 기존 target과 충돌해도 일관된 보존·복구 절차가 없었습니다. dry-run과 실제 적용이 별도 로직을 사용하면 두 결과가 달라질 수 있으며, apply 이후 사용자가 target을 수정한 상태에서 자동 rollback하면 새 변경을 덮어쓸 수 있습니다.

filesystem 적용의 계약을 먼저 작은 Module에서 검증할 필요가 있습니다. `bin` Module은 package manager나 service 상태에 의존하지 않아 첫 vertical slice로 선택했습니다.

## 결정

- `plan`, `apply --dry-run`, `apply`가 같은 planner와 Execution Plan을 사용합니다.
- 실제 변경마다 `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/transactions/<TX_ID>/`에 receipt를 남깁니다.
- 기존 파일·디렉터리·다른 symlink는 기본적으로 충돌로 처리하고 적용을 중단합니다.
- 기존 target 보존은 사용자가 `--backup`을 명시한 경우에만 수행합니다.
- rollback은 receipt에 기록된 filesystem 변경만 역순으로 복구합니다.
- rollback 전에 모든 target과 backup의 drift를 검사하고, 하나라도 예상 상태와 다르면 전체 rollback을 중단합니다.
- filesystem mutation 전에 action phase를 먼저 기록합니다. rollback은 phase와 현재 target·backup 관찰 결과를 함께 사용합니다.
- 중단된 `applying`, `rolling_back`, `rollback_failed` Transaction은 같은 receipt로 rollback을 재시도할 수 있습니다.
- Doctor는 완료 상태와 receipt 구조를 allowlist로 검사합니다. 복구가 필요한 상태와 알 수 없는 metadata는 실패합니다.
- `--force` 우회 경로는 제공하지 않습니다.
- 첫 적용 범위는 `bin` Module로 제한합니다. 공통 프레임워크 추출은 같은 Seam을 사용하는 두 번째 Module이 생긴 뒤 판단합니다.

상세 구조는 [`docs/architecture/transactional-installer.md`](../architecture/transactional-installer.md), 운영 절차는 [`docs/runbooks/manage-bin-module.md`](../runbooks/manage-bin-module.md)에 기록했습니다.

## 검토한 대안

### 기존 `ln -sf` 방식 유지

구현은 짧지만 실행 전에 충돌과 변경 범위를 확인할 Interface가 없습니다. 기존 target 보존과 실패 후 복구도 Module마다 다시 구현해야 합니다.

### 충돌 대상을 항상 자동 backup

명령 실행만으로 사용자가 관리하던 파일이나 디렉터리가 이동합니다. 기본 동작은 중단으로 두고, 보존 이동은 `--backup`으로 명시합니다.

### drift가 있어도 강제 rollback

apply 이후 생긴 사용자 변경을 삭제하거나 덮어쓸 수 있습니다. drift를 먼저 정리한 뒤 rollback을 다시 실행하도록 합니다.

### 처음부터 모든 Module을 위한 범용 Transaction 프레임워크 구현

package, shell, service는 rollback 경계가 서로 다릅니다. `bin`의 filesystem 계약과 테스트를 먼저 확정하고, 두 번째 Module에서 반복되는 부분만 추출합니다.

## 결과

- 사용자는 적용 전에 실제 operation을 확인하고, Transaction ID로 변경 이력을 찾을 수 있습니다.
- 충돌과 drift가 있으면 기존 데이터를 자동으로 덮어쓰지 않습니다.
- receipt는 filesystem 복구에 필요한 metadata만 보관하며 package·process·remote 상태는 복구하지 않습니다.
- 전체 계획이 `noop`이면 Transaction을 만들지 않습니다.
- 다른 Module은 rollback 계약과 테스트가 준비된 뒤 이 Interface로 전환합니다.

## 후속 결과

두 번째 filesystem Module로 `agents-links`를 추가했습니다. Claude/Codex global instruction link는 같은 Transaction primitive를 사용하며, Profile 적용은 `bin agents-links` 전체를 write 전에 preflight합니다. 반복이 실제로 확인된 Module dispatch와 lifecycle만 공통화했고, manifest DSL과 dependency graph는 추가하지 않았습니다. Hermes/OpenClaw의 사용자 소유 파일 후처리는 receipt 밖에 유지합니다.

프로세스 중단 복구를 추가하면서 directory와 link primitive에 write-ahead phase를 적용했습니다. 별도 journal framework나 apply 재개 기능은 추가하지 않았습니다. 복구 명령은 항상 원래 filesystem 상태로 rollback하며, 기존 `prepared`, `backup_moved`, `applied` receipt도 관찰 기반 preflight로 처리합니다.

Writer Lock 적용 뒤에도 같은 process에서 생성한 receipt ID가 충돌하면 `mkdir -p`가 기존 directory를 재사용할 수 있었습니다. Transaction root를 `mktemp -d`로 원자적으로 생성하고 새 receipt에 `schema_version=1`을 기록했습니다. schema field가 없는 기존 receipt는 legacy v1로 계속 읽습니다.
