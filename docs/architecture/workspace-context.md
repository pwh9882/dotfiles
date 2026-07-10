# Workspace Registry와 Execution Context

## 상태

Pilot. 현재 slice는 Workspace를 등록하고 현재 디렉터리의 context를 읽는 기능까지 제공합니다. launcher, recents, WezTerm top bar, daemon은 아직 연결하지 않았습니다.

## Registry 경계

공개 Registry는 [`config/workspaces.tsv`](../../config/workspaces.tsv)에 둡니다. 머신에 종속된 경로는 `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/workspaces.local.tsv`에 둡니다. local overlay가 없어도 정상 상태입니다.

두 파일은 header를 포함한 strict 3-field TSV입니다.

```text
workspace_id  target_id  root
```

실제 구분자는 tab입니다.

| Field | 계약 |
|---|---|
| `workspace_id` | 머신 경로와 독립적인 소문자·숫자·하이픈 ID |
| `target_id` | 같은 Workspace 안에서 위치를 구분하는 소문자·숫자·하이픈 ID |
| `root` | 공개 파일에서는 `~` 또는 `~/...`, local overlay에서는 absolute path도 허용 |

root는 환경 변수, command substitution, glob, `..` segment를 허용하지 않습니다. parser는 경로를 shell 명령으로 평가하지 않고 `~`만 `$HOME`으로 직접 확장합니다.

공개 Registry와 local overlay를 모두 끝까지 검증한 뒤 merge합니다. local row의 `(workspace_id, target_id)`가 같으면 공개 row를 교체합니다. merge 뒤 서로 다른 target이 같은 physical root를 가리키면 어느 target인지 결정할 수 없으므로 실패합니다.

## 현재 디렉터리 해석

root가 존재하면 `cd -P`와 `pwd -P`로 physical path를 구합니다. 현재 디렉터리도 physical path로 읽습니다. Resolver는 path segment 경계에서 일치하는 root만 고르고 가장 긴 prefix를 선택합니다.

```text
~/development           → broad/local
~/development/project   → project/local
```

`~/development/project/src`에서는 `project/local`을 선택합니다. `~/development-two`는 `~/development`와 일치하지 않습니다.

존재하지 않는 root는 `context`에서 건너뜁니다. `dotfiles doctor --only workspaces`는 같은 target을 `WARN`으로 보여주며 Registry 자체가 유효하면 성공합니다. 새 머신에서 아직 checkout하지 않은 Workspace를 공개 Registry에 두어도 다른 context 해석을 방해하지 않습니다.

## `dotfiles context` Interface

Text 출력은 다음 key 순서를 유지하며 확인하지 못한 string을 `unknown`으로 표시합니다.

```text
execution_instance_id
origin_instance_id
role
platform
transport
multiplexer
workspace_id
target_id
persistence
cwd
repository_root
git_branch
git_dirty
```

`dotfiles context --json`은 같은 순서 앞에 `schema_version`을 추가한 flat object를 출력합니다. 현재 schema version은 `1`입니다. 확인하지 못한 string과 dirty 상태는 `null`, 확인한 dirty 상태는 JSON boolean을 사용합니다.

```json
{"schema_version":1,"execution_instance_id":null,"origin_instance_id":null,"role":null,"platform":"macos","transport":"local","multiplexer":"none","workspace_id":"dotfiles","target_id":"local","persistence":null,"cwd":"/physical/path/to/dotfiles","repository_root":"/physical/path/to/dotfiles","git_branch":"main","git_dirty":false}
```

## 신호와 개인정보 경계

- Instance와 Role은 `llm-instance --details`가 성공한 경우에만 사용합니다. 실패하거나 출력이 잘못되면 둘 다 unknown으로 둡니다. hostname, username, 홈 경로로 identity를 추론하지 않습니다.
- platform은 `macos`, `linux`, `wsl` 중 확인한 값을 사용합니다.
- SSH 환경 변수가 있으면 transport는 `ssh`, 없으면 `local`입니다.
- local transport의 origin Instance는 execution Instance와 같습니다. SSH transport의 origin은 확인할 근거가 없어 unknown입니다.
- `TMUX`가 있으면 multiplexer는 `tmux`, 없으면 `none`입니다.
- persistence는 아직 Adapter가 제공하지 않아 unknown입니다.
- Git은 현재 checkout에서 `rev-parse`, `symbolic-ref`, `git --no-optional-locks ... status --porcelain`만 실행합니다. status가 index를 refresh하지 않도록 optional lock을 끄며 remote, fetch, submodule, network probe를 실행하지 않습니다.

Registry validation, Doctor, context는 HOME, XDG directory, checkout에 파일을 쓰지 않습니다. JSON encoding도 `jq`나 Python에 의존하지 않습니다.

## 현재 제외 범위

Workspace 목록·launcher, `--path` override, daemon, OSC metadata, WezTerm top bar, `projects.lua` 교체는 다음 vertical slice에서 검토합니다. 지금 Interface는 Registry와 현재 위치 해석을 먼저 안정화합니다.
