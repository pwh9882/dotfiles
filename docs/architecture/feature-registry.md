# Feature Registry

## 상태

Pilot. 현재 사용할 수 있는 기능만 `config/features.tsv`에 등록합니다.

## 범위

Feature Registry는 사용자가 이미 구현된 기능을 발견하고 첫 명령이나 GUI 조작을 실행할 수 있도록 다음 정보를 한곳에 둡니다.

- 기능 ID와 상태
- 지원 Role과 platform
- 개인정보·filesystem 변경 범위
- 첫 실행 명령·GUI 조작과 검증 명령
- 관련 문서와 한 줄 설명

현재 등록한 기능은 다음 여덟 개입니다.

| ID | 상태 | 설명 |
|---|---|---|
| `repository-health` | `available` | 저장소의 문법, 정책, 회귀 테스트를 읽기 전용으로 검사합니다. |
| `machine-profile` | `available` | 검증된 Instance의 Role에서 Capability와 Module을 선택합니다. |
| `safe-bin-apply` | `pilot` | `bin` 링크의 plan, transaction apply, rollback을 제공합니다. |
| `shared-agent-instructions` | `pilot` | Claude와 Codex의 전역 지침 링크를 Transaction으로 관리합니다. |
| `workspace-context` | `pilot` | 현재 위치의 Workspace, 실행 머신, transport, 로컬 Git 상태를 읽기 전용으로 보여줍니다. |
| `wezterm-context-status` | `available` | 현재 CWD, workspace, host, OS, 입력 mode를 상태 바와 탭 색으로 보여줍니다. |
| `wezterm-project-picker` | `pilot` | macOS에서 프로젝트 경로와 SSH host를 하나의 fuzzy picker로 엽니다. |
| `wezterm-session-restore` | `pilot` | macOS workspace의 layout과 process metadata를 저장하고 복원합니다. |

아직 실행할 수 없는 기능은 Registry에 넣지 않습니다. 계획은 architecture 문서와 issue tracker에서 관리합니다.

## TSV 계약

Registry는 header를 포함한 9-field TSV입니다.

```text
id  status  roles  platforms  privacy  first_run  verify  docs  summary
```

실제 구분자는 tab입니다. field 안에는 tab과 줄바꿈을 넣지 않습니다.

| Field | 계약 |
|---|---|
| `id` | 소문자·숫자·하이픈으로 구성한 고유 ID |
| `status` | `available` 또는 `pilot` |
| `roles` | 쉼표로 구분한 Role ID |
| `platforms` | 쉼표로 구분한 platform ID |
| `privacy` | 읽는 데이터와 변경 범위를 설명한 비어 있지 않은 문장 |
| `first_run` | 사용자가 처음 실행할 명령 또는 GUI 조작 |
| `verify` | 사용자가 기능 상태를 확인할 명령 |
| `docs` | 존재하는 저장소 상대 문서 경로 |
| `summary` | 기능을 설명한 비어 있지 않은 문장 |

parser는 한 row만 읽고 넘어가지 않습니다. header, 모든 row의 field 수와 값, 중복 ID, 문서 경로를 한 번에 검사합니다. `docs`는 absolute path와 `..` segment를 허용하지 않으며 실제 regular file이어야 합니다.

## 읽기 전용 Interface

`lib/dotfiles/features.sh`는 root CLI가 연결할 세 함수를 제공합니다.

```text
df_features_list
df_features_detail FEATURE_ID
df_features_doctor
```

CLI 연결 뒤 사용자 Interface는 다음 형태가 됩니다.

```console
dotfiles tour
dotfiles tour safe-bin-apply
dotfiles tour wezterm-project-picker
dotfiles doctor --only features
```

`tour`는 Registry를 검증한 뒤 `first_run`과 `verify`를 그대로 출력합니다. Registry에 기록된 명령을 실행하지 않으며 `eval`, `sh -c`, command substitution에 전달하지 않습니다.

Feature Doctor도 `verify` field를 실행하지 않습니다. 고정된 feature ID allowlist로 구현 파일의 존재를 읽기 전용으로 확인합니다. 이 evidence check는 Registry row가 아직 사용할 수 없는 기능을 약속하는 일을 막습니다.

| Feature ID | 확인하는 evidence |
|---|---|
| `repository-health` | `bin/dotfiles-check`, GitHub Actions workflow |
| `machine-profile` | `llm-instance`, 공개 Role Registry, Profile Module과 회귀 테스트 |
| `safe-bin-apply` | `bin/dotfiles`, transaction runtime/state, `bin` Module, 회귀 테스트 |
| `shared-agent-instructions` | 공통 agent source, `agents-links` Module, runbook, 회귀 테스트 |
| `workspace-context` | 공개 Registry와 local 예시, Workspace/Context Module, 문서, 12개 회귀 테스트 |
| `wezterm-context-status` | 상태 바 renderer, 순수 판별 logic, 51개 회귀 테스트, 온보딩 runbook |
| `wezterm-project-picker` | macOS key binding, picker와 순수 path logic, local overlay 예시, 7개 회귀 테스트, 온보딩 runbook |
| `wezterm-session-restore` | macOS session plugin 설정, pane text 비저장 정책, 설정 문서와 온보딩 runbook |

새 기능을 등록할 때는 Registry row, 관련 문서, 고정 evidence check, 회귀 테스트를 같은 변경에 포함합니다.

## 보안과 개인정보 경계

Registry는 공개 설정입니다. token, username, IP, identity file, 개인 절대경로를 기록하지 않습니다. `privacy`에는 값 자체를 넣지 않고 기능이 읽거나 변경하는 범위를 설명합니다.

list, detail, Doctor는 HOME, XDG state, Git checkout을 변경하지 않습니다. network probe와 외부 update도 실행하지 않습니다. 이 zero-write 계약은 `tests/features/run.sh`에서 임시 HOME과 XDG 경로를 사용해 검증합니다.
