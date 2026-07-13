# Transactional Installer: `bin`과 `agents-links` vertical slice

## 상태

Pilot. `bin`과 `agents-links` 두 filesystem Module을 관리합니다.

## 목표

`bin` Module은 저장소의 사용자 명령을 `~/.local/bin`에 배치합니다. `agents-links` Module은 Claude Code와 Codex가 같은 전역 agent 지침을 읽도록 연결합니다. 사용자는 변경 전에 같은 계획을 확인하고, 적용 뒤에는 Transaction ID로 filesystem 변경을 되돌릴 수 있습니다.

두 번째 Module을 추가하면서 반복되는 Module lifecycle만 공통 Interface로 추출했습니다. Implementation은 symlink와 backup을 다루며, Module 선택은 명시적 `case`와 `bin agents-links` 고정 순서를 사용합니다. 범용 manifest나 dependency graph는 두지 않습니다.

## 관리 대상

`bin` Module은 다음 source와 target을 관리합니다.

```text
<repository>/bin/<tool> → $HOME/.local/bin/<tool>
```

첫 slice의 `<tool>` 집합은 다음과 같습니다.

```text
dotfiles
dotfiles-check
llm-instance
llm-wiki-git
llm-wiki-status
llm-wiki-commit
llm-wiki-lint
```

도구 목록은 Module Implementation이 한 번만 소유합니다. 계획, 적용, rollback, legacy `bin/init.sh`가 같은 목록을 사용합니다.

source와 target은 absolute path로 정규화합니다. target symlink의 문자열이 예상 absolute source와 같을 때만 `noop`으로 판정합니다.

`agents-links` Module은 다음 실제 디렉터리와 link를 관리합니다.

```text
$HOME/.claude/
$HOME/.claude/CLAUDE.md → <repository>/agents/AGENTS.md
$HOME/.codex/
$HOME/.codex/AGENTS.md → <repository>/agents/AGENTS.md
```

두 parent는 symlink-to-directory가 아닌 실제 디렉터리여야 합니다. Hermes의 `SOUL.md`와 OpenClaw workspace의 `AGENTS.md` append-once 동작은 사용자 소유 파일을 직접 수정하므로 Transaction receipt 밖의 legacy post-config로 유지합니다.

## Interface

```console
dotfiles plan [--only bin|agents-links] [--backup]
dotfiles apply [--only bin|agents-links] [--dry-run] [--backup]
dotfiles doctor --only bin|agents-links
dotfiles history
dotfiles rollback [--last|TX_ID] [--dry-run]
```

| 명령 | 동작 |
|---|---|
| `plan --only MODULE` | 현재 filesystem을 읽고 한 Module의 operation을 출력합니다. |
| `plan --only MODULE --backup` | 충돌 대상을 backup하는 계획을 출력합니다. |
| `apply --only MODULE --dry-run` | `plan`과 같은 operation을 출력합니다. |
| `apply --only MODULE` | 충돌이 없는 operation을 적용하고 receipt를 남깁니다. |
| `apply --only MODULE --backup` | 충돌 대상을 Transaction 내부로 옮긴 뒤 적용합니다. |
| `doctor --only MODULE` | 한 Module의 target, receipt 권한, 미완료 Transaction을 읽기 전용으로 검사합니다. |
| `history` | 기록된 Transaction ID와 상태를 표시합니다. |
| `rollback --last` | `started_at`이 가장 늦고 같은 초 후보가 하나인 Transaction을 되돌립니다. |
| `rollback TX_ID` | 지정한 receipt의 filesystem operation을 역순으로 되돌립니다. |
| `rollback … --dry-run` | rollback 대상과 drift를 확인하고 파일을 변경하지 않습니다. |

`--only`는 한 Module만 받습니다. 생략하면 `bin agents-links`를 고정 순서로 선택합니다.

rollback selector는 `--last` 또는 `TX_ID` 하나만 받습니다. 둘을 함께 쓰거나 selector를 두 번 쓰면 인자 순서와 관계없이 filesystem과 receipt를 변경하기 전에 실패합니다. 가장 늦은 `started_at`에 복구 가능한 Transaction이 둘 이상이면 random ID suffix로 순서를 추측하지 않고 명시적 `TX_ID`를 요구합니다.

`plan`과 `apply --dry-run`은 동일한 planner를 호출합니다. 두 경로는 state directory와 transaction ID도 만들지 않습니다. `rollback --dry-run`도 receipt와 현재 filesystem을 읽기만 합니다. 출력만 다른 별도 dry-run Implementation을 두지 않습니다.

## Plan operation

planner는 target 하나를 다음 operation 중 하나로 분류합니다.

| 현재 상태 | operation | 기본 적용 |
|---|---|---|
| target이 없음 | `link` | target symlink 생성 |
| source를 가리키는 symlink | `noop` | 변경 없음 |
| 일반 파일 | `conflict` | 중단 |
| 실제 디렉터리 | `conflict` | 중단 |
| 다른 곳을 가리키는 symlink | `conflict` | 중단 |
| 끊어진 symlink | `conflict` | 중단 |

`--backup`은 `conflict`를 `backup + link` operation으로 바꿉니다. planner는 target의 종류와 예상 source를 함께 출력합니다. 파일 내용과 secret 값은 출력하거나 receipt에 기록하지 않습니다.

## Apply 흐름

```text
resolve repository와 HOME
→ 선택한 모든 Module preflight
→ conflict 정책 확인
→ Writer Lock 획득
→ Module별 Transaction directory 생성
→ 고정 순서로 Module 적용
→ Module별 receipt 확정과 Transaction ID 출력
```

filesystem을 바꾸는 지점이 이 Module의 Seam입니다. symlink 생성, 디렉터리 생성, 충돌 대상 이동을 공통 filesystem primitive로 제한합니다. 공통 프레임워크 추출은 같은 Seam을 사용하는 두 번째 Module이 생긴 후속 slice에서 판단합니다.

`$HOME/.local/bin`이 없으면 apply가 생성합니다. rollback은 해당 Transaction이 만든 디렉터리만 추적하며, 비어 있을 때만 제거합니다.

선택한 모든 Module은 첫 write 전에 preflight를 통과해야 합니다. 이후 apply 전체가 Writer Lock을 잡고 각 Module을 다시 preflight합니다. 따라서 뒤쪽 `agents-links` 충돌이 앞쪽 `bin` 변경을 일부 남기지 않고, 다른 apply나 rollback이 관찰과 mutation 사이에 끼어들지 않습니다. 실제 적용은 Module마다 별도 Transaction을 사용합니다. 앞 Module 적용 뒤 예상 밖의 runtime 오류로 뒤 Module이 실패하면 앞 Transaction은 확정된 상태로 남으며, 출력된 각 Transaction ID로 독립적으로 복구합니다.

Module 계획 전체가 `noop`이면 해당 Module은 Transaction을 만들지 않습니다. operation 도중 실패하면 Implementation이 같은 receipt로 즉시 rollback을 시도합니다. 복구 성공은 `failed_rolled_back`, 복구 실패는 `rollback_failed` 상태로 기록하며, 후자는 확인할 Transaction 경로를 출력합니다.

프로세스가 종료되면 즉시 rollback을 실행할 수 없으므로 `applying` 또는 `rolling_back` receipt가 남을 수 있습니다. 이후 `rollback TX_ID`는 apply를 이어서 실행하지 않고 원래 filesystem 상태로 복구합니다. `rollback_failed`도 drift를 정리한 뒤 같은 명령으로 재시도할 수 있습니다.

## Transaction과 receipt

실제 apply는 다음 위치에 Transaction을 기록합니다.

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/transactions/<TX_ID>/
├── meta/
│   ├── schema_version
│   └── *
├── actions/
│   ├── 000001/
│   │   └── *
│   └── 000002/
│       └── *
└── backup/
```

Transaction directory 전체가 receipt 원본입니다. root는 `mktemp -d`로 원자적으로 생성해 기존 receipt를 재사용하지 않습니다. `meta/`는 schema version, Transaction ID와 Module 같은 공통 metadata를, `actions/NNNNNN/`은 적용 순서별 target·source·operation·backup 상대 경로·진행 phase를 보관합니다. `backup/`은 충돌 대상을 보관합니다. rollback은 operation, source, phase를 조합해 예상 상태를 판정합니다.

새 receipt는 `meta/schema_version=1`을 기록합니다. 이 field가 없는 기존 receipt는 legacy v1로 읽어 기존 Doctor와 rollback을 유지합니다. field가 있으면 readable regular file과 값 `1`을 요구하며 다른 version은 첫 mutation 전에 거부합니다.

### 상태

| 상태 | 의미 | Doctor |
|---|---|---|
| `applying` | apply가 시작됐고 완료되지 않았습니다. | 실패 |
| `applied` | apply가 완료됐습니다. | 통과 |
| `rolling_back` | rollback이 시작됐고 완료되지 않았습니다. | 실패 |
| `rolled_back` | 사용자가 요청한 rollback이 완료됐습니다. | 통과 |
| `failed_rolled_back` | apply 오류 뒤 자동 rollback이 완료됐습니다. | 통과 |
| `rollback_failed` | rollback을 완료하지 못했습니다. | 실패 |

Doctor는 위 완료 상태 세 개만 정상 receipt로 인정합니다. 지원하지 않는 schema version, 알 수 없는 상태, 필수 metadata 누락, 잘못된 action directory 이름, 알 수 없는 operation·phase·`before_type`, 안전하지 않은 backup 상대 경로도 실패합니다. 검사는 receipt를 수정하지 않습니다.

### Write-ahead action phase

각 filesystem mutation 전에 atomic metadata write로 다음 phase를 먼저 기록합니다.

```text
prepared
→ backup_move_pending → backup_moved
→ target_create_pending → applied
→ rollback_remove_pending → rollback_target_removed
→ rollback_restore_pending → rolled_back
```

backup이 없는 action은 backup phase를 건너뜁니다. 복원할 backup이 없는 action은 restore phase를 건너뜁니다. phase가 `*_pending`이면 mutation 직전과 직후 중 어느 지점에서 프로세스가 끝났을 수 있습니다.

rollback은 phase만 믿고 파일을 삭제하지 않습니다. 모든 action을 먼저 읽고 target과 backup의 실제 상태를 관찰합니다.

- link target은 receipt의 source를 정확히 가리킬 때만 Transaction이 만든 target으로 판정합니다.
- directory target은 같은 Transaction에 기록된 하위 target만 포함할 때만 제거 대상으로 판정합니다.
- backup은 receipt에 기록한 상대 경로에 있고 type이 `before_type`과 같아야 합니다.
- 원래 target이 남아 있고 backup이 없으면 backup 이동 전 또는 복원 완료 상태로 판정하며 target을 수정하지 않습니다.
- 이미 복구된 action은 건너뛰고 나머지 action만 역순으로 처리합니다.
- 어느 action에서든 설명되지 않는 target이나 backup이 발견되면 첫 mutation과 상태 변경 전에 전체 rollback을 거부합니다.

기존 receipt의 `prepared`, `backup_moved`, `applied` phase도 계속 읽습니다. 같은 관찰 규칙을 적용하므로 phase write 직전 종료로 backup이나 target이 이미 이동된 경우에도 복구할 수 있습니다.

권한은 다음과 같이 고정합니다.

| 경로 | mode |
|---|---:|
| `dotfiles/` state directory | `0700` |
| `write.lock/` | `0700` |
| `transactions/` | `0700` |
| `<TX_ID>/` | `0700` |
| `meta/`, `actions/`, `actions/NNNNNN/` | `0700` |
| `backup/` | `0700` |
| receipt metadata file | `0600` |

backup으로 이동한 기존 객체는 원래 type과 mode를 유지합니다. Transaction Implementation이 새로 만드는 directory는 `0700`, metadata regular file은 `0600`으로 생성합니다. rollback에 필요한 metadata만 저장합니다.

receipt는 적용을 재현하는 manifest 역할을 하지 않습니다. 외부 명령 출력, 환경변수 값, 파일 내용, pane scrollback을 담지 않습니다.

`history`는 receipt의 ID, Module, 상태를 표시합니다. 정상 적용은 `applied`, 정상 rollback은 `rolled_back` 상태로 남습니다. receipt는 rollback 이후에도 적용·복구 이력으로 유지합니다. 기본 apply가 같은 초에 여러 Transaction을 만들 수 있으며, 이 경우 `rollback --last`는 변경 없이 실패하므로 `history`에 나온 명시적 ID를 사용합니다.

## Writer Lock

실제 `apply`와 `rollback`은 `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/write.lock/`을 공유합니다. atomic `mkdir`에 성공한 한 process만 filesystem을 변경합니다. lock에는 PID, 명령, 시작 시각을 `0600` regular file로 기록합니다.

process가 정상 종료하면 EXIT trap과 명시적 release가 lock을 제거합니다. SIGKILL 뒤 lock이 남고 기록한 PID가 더 이상 존재하지 않으면 다음 writer가 stale directory를 옮긴 뒤 lock 획득을 한 번 재시도합니다. PID가 살아 있거나 소유자를 확인할 수 없으면 안전하게 중단합니다.

`plan`, `doctor`, `history`, `apply --dry-run`, `rollback --dry-run`은 lock을 만들지 않습니다.

## Rollback 경계

rollback은 receipt의 operation을 역순으로 처리합니다.

- `link`: Transaction이 만든 symlink를 제거합니다.
- `backup + link`: 적용한 symlink를 제거하고 backup 객체를 원래 target으로 이동합니다.
- 생성한 디렉터리: 비어 있으면 제거합니다.

복구 범위는 Transaction이 직접 관리한 filesystem 변경입니다. package 설치, shell 변경, 프로세스 상태, 네트워크 상태, 원격 host 상태는 rollback 대상에 포함하지 않습니다.

### Drift refusal

rollback 직전에 현재 target을 receipt의 적용 후 예상 상태와 비교합니다. 다음 상황에서는 전체 rollback을 시작하기 전에 중단합니다.

- target symlink가 삭제됨
- target이 일반 파일이나 디렉터리로 바뀜
- target symlink가 다른 source를 가리킴
- 복원해야 할 backup 객체가 없음
- Transaction directory가 없거나 receipt 형식을 검증할 수 없음

이 정책은 rollback이 apply 이후의 사용자 변경을 덮어쓰는 일을 막습니다. `--force` 우회 경로는 제공하지 않습니다. 사용자는 drift를 직접 정리한 뒤 rollback을 다시 실행합니다.

rollback 도중 오류가 나면 완료한 action은 `rolled_back` phase로 남고 Transaction은 `rollback_failed`가 됩니다. 재시도는 전체 receipt를 다시 preflight한 뒤 완료된 action을 건너뜁니다. 따라서 partial rollback을 처음부터 반복해 이미 복원한 backup을 다시 이동하지 않습니다.

## Legacy compatibility

`bash bin/init.sh`는 유지합니다. 이 script는 도구 목록과 링크 동작을 다시 구현하지 않고 `dotfiles apply --only bin` Interface에 위임합니다.

`bash agents/init.sh`는 먼저 `dotfiles apply --only agents-links`에 위임합니다. link apply가 성공한 뒤에만 Hermes와 OpenClaw legacy post-config를 실행합니다. `--dry-run`, `--help`, link preflight 실패에서는 legacy post-config에 진입하지 않습니다. 루트 runner는 `bin`과 `agents`를 각각 한 번 호출하며, `agents/init.sh`는 `bin/init.sh`를 다시 호출하지 않습니다.

기존에 올바르게 연결된 target은 `noop`으로 처리됩니다. 기존 파일·디렉터리·다른 symlink는 안전하게 중단하며, legacy entry point는 암묵적으로 `--backup`이나 `--force`를 사용하지 않습니다. 루트 `init.sh`에서 `bin/init.sh`를 호출하는 현재 경로도 이 동작을 그대로 받습니다.

## Architecture 판단

### Depth

작은 Interface 뒤에 계획 생성, 충돌 판정, receipt, backup, drift 검증, rollback 순서를 숨깁니다. caller는 `ln` option과 복구 순서를 알 필요가 없습니다.

### Leverage

한 planner를 `plan`, `apply --dry-run`, `apply`, 두 legacy entry point가 함께 사용합니다. Profile 적용도 같은 preflight를 사용합니다.

### Locality

`bin` 도구 목록과 agent harness link 규칙은 각각의 Module에 둡니다. 공통 lifecycle은 `df_module_run`, plan, preflight, apply, doctor 함수에만 모읍니다. Transaction 형식과 filesystem primitive는 Installer Implementation에 둡니다. platform별 package manager는 이 경계에 들어오지 않습니다.

### Adapter

이번 slice는 macOS와 Linux에서 같은 symlink Implementation을 사용합니다. platform Adapter 도입은 운영체제별 동작 차이가 실제 Seam으로 확인될 때 판단합니다.

## 후속 slice로 둔 범위

- package manager 설치와 package rollback
- `shell`, `tmux`, `.config` Module 전환
- Hermes와 OpenClaw 사용자 파일의 managed-block 전환
- `--force`
- `sudo`, `chsh`, service restart
- remote apply, wake, network probe
- 여러 Module을 묶는 원자적 Transaction

새 범위는 해당 동작의 rollback 계약과 테스트가 준비된 뒤 Interface에 추가합니다.
