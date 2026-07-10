# Machine Profile: `core-tools`와 `shared-agent-instructions`

## 상태

Pilot. 현재 Profile은 네 Role을 `bin`, `agents-links` 두 Transactional Module에 연결합니다.

## 해석 경로

```text
llm-instance --details
→ role
→ config/machine-profiles.tsv
→ core-tools + shared-agent-instructions
→ bin + agents-links
```

`llm-instance`는 mode와 관계없이 identity file, 현재 Instance 문서, hostname을 먼저 검증합니다. Instance 문서에는 값 하나만 가진 `hostname:` 필드가 정확히 하나 있어야 하며, 현재 hostname과 대소문자를 구분하지 않고 비교합니다. `--details`는 이 검증을 통과한 뒤 `role:` 필드도 정확히 하나의 lowercase token으로 확인합니다. 기존 `llm-instance --id` 출력은 Instance ID 한 줄을 유지하며, Instance 문서에 Role이 없어도 동작합니다.

공개 Registry는 다음 두 column만 사용합니다.

```text
role<TAB>capability
```

현재 계약은 다음과 같습니다.

| Role | Capabilities | Modules |
|---|---|---|
| `authoring-client` | `core-tools`, `shared-agent-instructions` | `bin`, `agents-links` |
| `service-host` | `core-tools`, `shared-agent-instructions` | `bin`, `agents-links` |
| `windows-workstation` | `core-tools`, `shared-agent-instructions` | `bin`, `agents-links` |
| `headless-agent-worker` | `core-tools`, `shared-agent-instructions` | `bin`, `agents-links` |

Capability 매핑은 `lib/dotfiles/profile.sh`의 명시적 `case` 하나로 구현했습니다. Registry row 순서와 관계없이 Transactional Module 실행 순서는 `bin agents-links`로 고정합니다. 두 Module 사이에는 범용 graph나 dependency closure를 추가하지 않습니다.

## Interface

```console
dotfiles profile
dotfiles plan
dotfiles apply
dotfiles doctor --profile
```

`dotfiles profile`은 다음처럼 topology를 제거한 값만 출력합니다.

```text
instance_id=authoring-laptop
role=authoring-client
capability=core-tools
capability=shared-agent-instructions
module=bin
module=agents-links
```

`plan`과 `apply`에서 `--only`를 생략하면 Profile을 읽고 두 Module을 고정 순서로 선택합니다. apply는 두 Module을 모두 preflight한 뒤 Module마다 별도 Transaction을 생성합니다. `doctor --profile`도 같은 해석 경로를 거친 뒤 두 Doctor를 모두 실행합니다. Profile 해석, plan, Doctor는 읽기 전용이며 state directory와 Transaction을 만들지 않습니다.

## Privacy

`config/machine-profiles.tsv`에는 Role과 Capability token만 둡니다. Instance ID, hostname, username, IP, port, 홈 경로, 프로젝트 경로를 기록하지 않습니다. 전체 Registry parser가 정확한 두 column, 허용된 이름, 알려진 Role과 Capability, 중복 pair를 검사하므로 topology column을 추가하면 validation이 실패합니다.

`dotfiles profile`은 내부에서 `llm-instance --details`를 호출하지만 hostname과 Instance 문서 경로를 다시 출력하지 않습니다. 성공 출력은 Instance ID, Role, Capability, Module로 제한합니다.

## Bootstrap

새 머신은 아직 identity와 `llm-instance` link가 없을 수 있습니다. 이때 다음 명령만 identity 검증을 우회합니다.

```console
dotfiles apply --only bin
```

명시적 `--only bin`은 Profile 선택이 필요 없는 initial bootstrap 경로입니다. `agents-links`도 명시적 `--only`로 단독 계획·적용·검증할 수 있습니다. `--only`를 생략한 자동 선택은 identity 검증을 항상 요구합니다.

## Fail-closed 동작

다음 상태에서는 Profile 해석이 실패하며 apply가 filesystem preflight와 Transaction 생성에 들어가기 전에 끝납니다.

- identity file 또는 Instance 문서가 없음
- Instance ID 검증 실패
- `hostname:` 필드가 없거나, 중복되거나, 값이 없거나, 값이 둘 이상이거나, 현재 hostname과 일치하지 않음
- Role이 없거나 token 형식이 잘못됨
- Role이 공개 Registry에 등록되지 않음
- Registry row의 column 수나 이름 형식이 잘못됨
- 알려지지 않은 Role 또는 Capability가 있음
- 같은 Role과 Capability pair가 중복됨
- Capability가 지원되는 Module로 해석되지 않음

parser는 선택한 Role을 찾은 뒤에도 파일 끝까지 읽습니다. 다른 Role row의 오류도 현재 Profile을 실패시킵니다. Registry 일부만 유효한 상태로 apply하는 경로는 제공하지 않습니다.

## 현재 경계

현재 Profile의 transactional 범위는 `bin`과 native agent instruction link입니다. Hermes/OpenClaw post-config, 기존 `zsh/.zshrc.local.<hostname>` overlay와 `zsh/init.sh`의 hostname 선택은 그대로 유지합니다. hostname overlay migration은 shell Module을 transactional Installer로 옮길 때 별도 계획과 회귀 테스트를 준비한 뒤 진행합니다.
