# `bin` Module 적용과 복구

## 적용 범위

이 절차는 저장소의 사용자 명령을 `$HOME/.local/bin`에 연결하는 `bin` Module에만 사용합니다. package 설치와 다른 dotfiles Module은 변경하지 않습니다.

저장소 root에서 명령을 실행합니다.

```console
cd ~/dotfiles
```

## 1. 계획 확인

```console
./bin/dotfiles plan --only bin
```

계획에는 target별로 `link`, `noop`, `conflict`가 표시됩니다. 이 명령은 filesystem과 state directory를 변경하지 않습니다.

apply 형태로 같은 계획을 확인할 수도 있습니다.

```console
./bin/dotfiles apply --only bin --dry-run
```

두 명령은 같은 planner를 사용합니다. dry-run 중에는 transaction ID와 receipt가 생성되지 않습니다.

## 2. 충돌 없는 계획 적용

```console
./bin/dotfiles apply --only bin
```

변경할 operation이 있으면 정상 적용 뒤 Transaction ID가 출력됩니다. rollback에 사용할 수 있도록 ID를 확인합니다. 전체 계획이 `noop`이면 새 Transaction을 만들지 않고 성공으로 끝납니다. 최근 기록은 다음 명령으로 다시 찾을 수 있습니다.

```console
./bin/dotfiles history
```

receipt 기본 위치는 다음과 같습니다.

```text
~/.local/state/dotfiles/transactions/<TX_ID>/
├── meta/
├── actions/
└── backup/
```

Transaction directory 전체가 receipt입니다. `XDG_STATE_HOME`을 설정한 환경에서는 `$XDG_STATE_HOME/dotfiles/transactions/`를 사용합니다. directory는 원자적으로 생성하며 새 receipt의 `meta/schema_version`은 `1`입니다. schema field가 없는 기존 receipt는 legacy v1로 계속 읽습니다. state·transaction·control directory와 backup root는 `0700`, receipt metadata regular file은 `0600`으로 생성됩니다. backup payload는 기존 type과 mode를 유지합니다.

적용 뒤 읽기 전용 검사를 실행합니다.

```console
./bin/dotfiles doctor --only bin
```

## 3. 기존 target backup 후 적용

계획에 `conflict`가 있으면 target의 내용을 먼저 확인합니다. 보존할 기존 target을 Transaction backup으로 이동해도 되는 경우 dry-run을 다시 실행합니다.

```console
./bin/dotfiles plan --only bin --backup
```

계획에서 `backup + link` 대상이 의도한 파일·디렉터리·symlink인지 확인한 뒤 적용합니다.

```console
./bin/dotfiles apply --only bin --backup
```

기존 target은 다음 Transaction directory 아래에 보관됩니다.

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/transactions/<TX_ID>/backup/
```

backup 객체의 type과 mode는 유지됩니다. 적용이 정상이고 rollback 필요가 없어도 Transaction directory를 임의로 삭제하지 않습니다.

## 4. Transaction rollback

```console
./bin/dotfiles rollback TX_ID --dry-run
```

dry-run 결과에서 복구 operation과 drift 여부를 확인한 뒤 실제 rollback을 실행합니다.

```console
./bin/dotfiles rollback TX_ID
```

가장 최근 `started_at`에 복구 가능한 Transaction이 하나면 ID 대신 `--last`로 선택할 수 있습니다.

```console
./bin/dotfiles rollback --last --dry-run
./bin/dotfiles rollback --last
```

`--last`와 `TX_ID`는 함께 쓰지 않습니다. selector가 둘이면 rollback은 변경 없이 실패합니다. 같은 초에 시작한 최신 Transaction이 둘 이상이면 `--last`도 변경 없이 실패합니다. `./bin/dotfiles history`에서 의도한 Module의 `TX_ID`를 골라 명시적으로 실행합니다.

rollback은 해당 Transaction이 수행한 filesystem operation만 역순으로 되돌립니다.

- 생성한 symlink 제거
- backup한 기존 target 복원
- Transaction이 만든 빈 디렉터리 제거

package, shell 설정, 실행 중인 process, remote host는 변경하지 않습니다.

rollback 뒤 Transaction 상태와 현재 적용 계획을 확인합니다.

```console
./bin/dotfiles history
./bin/dotfiles plan --only bin
```

rollback은 이전 filesystem 상태를 복원합니다. 첫 설치 Transaction을 되돌리면 managed link가 제거되므로 `doctor --only bin`은 의도적으로 실패합니다. desired link를 적용한 상태에서만 Doctor 통과를 기대합니다.

## Drift로 rollback이 거부될 때

apply 이후 managed target을 직접 수정하면 rollback이 중단됩니다. 예시는 다음과 같습니다.

- symlink를 지우거나 일반 파일로 교체함
- symlink가 다른 source를 가리키도록 바꿈
- Transaction의 backup 객체를 이동하거나 삭제함
- Transaction directory의 receipt metadata를 수정함

오류에 표시된 target과 receipt를 확인하고, 현재 데이터를 별도 위치에 보존합니다. target을 receipt의 적용 후 상태로 되돌린 뒤 dry-run부터 다시 실행합니다.

```console
./bin/dotfiles rollback TX_ID --dry-run
./bin/dotfiles rollback TX_ID
```

이 Interface는 `--force`를 제공하지 않습니다. drift가 생긴 파일을 자동 삭제하거나 덮어쓰지 않습니다.

## 중단된 Transaction 복구

`history`에 다음 상태가 보이면 rollback이 필요합니다.

- `applying`: apply 중 프로세스가 종료됨
- `rolling_back`: rollback 중 프로세스가 종료됨
- `rollback_failed`: rollback을 완료하지 못함

Doctor는 세 상태를 모두 실패로 표시합니다. receipt를 직접 수정하지 않고 Transaction ID로 dry-run을 실행합니다.

```console
./bin/dotfiles rollback TX_ID --dry-run
```

dry-run은 모든 action의 target과 backup을 먼저 검사합니다. 출력된 대상이 의도한 Transaction과 일치하면 rollback을 실행합니다.

```console
./bin/dotfiles rollback TX_ID
```

복구는 apply를 이어서 실행하지 않습니다. 이미 적용한 link와 directory를 제거하고 backup을 원래 위치로 되돌립니다. partial rollback에서 완료된 action은 건너뛰므로 `rollback_failed` 상태에도 같은 명령을 사용합니다.

rollback이 다시 drift를 보고하면 오류에 나온 현재 target과 backup을 확인합니다. 사용자 변경을 별도 위치에 보존하고 receipt가 설명하는 상태로 정리한 뒤 dry-run부터 반복합니다. 원래 target이 이미 제자리에 있고 backup이 없으면 복구 명령이 해당 target을 덮어쓰지 않습니다.

복구 뒤 상태를 확인합니다.

```console
./bin/dotfiles history
./bin/dotfiles doctor --only bin
```

첫 설치를 rollback한 경우 managed link가 없으므로 Module Doctor는 계속 실패할 수 있습니다. `history`에서 Transaction이 `rolled_back` 또는 `failed_rolled_back`인지 함께 확인합니다.

## Legacy entry point

기존 명령도 같은 `bin` Module apply를 실행합니다.

```console
bash bin/init.sh
```

올바른 symlink는 `noop`으로 유지됩니다. 충돌 대상은 자동 backup하지 않고 중단합니다. 충돌을 보존해 적용하려면 계획을 확인한 뒤 `./bin/dotfiles apply --only bin --backup`을 직접 실행합니다.

## 이 절차에서 다루지 않는 작업

- package 설치와 제거
- 다른 Transaction Module 적용
- 루트 `./init.sh` 전체 적용 방식 변경
- 다른 Module 적용
- 강제 덮어쓰기
- 원격 머신 변경
