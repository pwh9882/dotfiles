# `agents-links` Module 적용과 복구

## 적용 범위

이 절차는 공통 [`agents/AGENTS.md`](../../agents/AGENTS.md)를 Claude Code와 Codex의 전역 지침 경로에 연결합니다.

```text
~/.claude/CLAUDE.md → <repository>/agents/AGENTS.md
~/.codex/AGENTS.md → <repository>/agents/AGENTS.md
```

`~/.claude`와 `~/.codex`는 실제 디렉터리여야 합니다. Hermes `SOUL.md`와 OpenClaw workspace 파일은 이 Transaction에 포함되지 않습니다.

## 계획과 적용

저장소 root에서 읽기 전용 계획을 확인합니다.

```console
./bin/dotfiles plan --only agents-links
./bin/dotfiles apply --only agents-links --dry-run
```

충돌이 없으면 적용하고 출력된 Transaction ID를 기록합니다.

```console
./bin/dotfiles apply --only agents-links
./bin/dotfiles doctor --only agents-links
```

Machine Profile 전체를 적용할 때는 `--only`를 생략합니다.

```console
./bin/dotfiles plan
./bin/dotfiles apply
./bin/dotfiles doctor --profile
```

Profile apply는 `bin`, `agents-links`를 모두 preflight한 뒤 고정 순서로 적용합니다. 각 Module은 별도 Transaction ID를 출력합니다. 같은 초에 두 receipt가 생성될 수 있으므로 복구할 때는 `--last`보다 출력된 명시적 ID를 사용합니다.

## 충돌 보존

기존 target이 일반 파일·디렉터리·다른 symlink이면 기본 적용은 중단합니다. 내용을 확인한 뒤 Transaction backup으로 이동해도 되는 경우에만 다음 순서로 실행합니다.

```console
./bin/dotfiles plan --only agents-links --backup
./bin/dotfiles apply --only agents-links --backup
```

parent 자체가 symlink-to-directory인 경우도 충돌입니다. `--backup`은 parent 전체를 receipt 안으로 이동하고 실제 디렉터리를 새로 만드는 동작이므로 계획을 확인한 뒤 사용합니다.

## Rollback

```console
./bin/dotfiles rollback TX_ID --dry-run
./bin/dotfiles rollback TX_ID
```

clean apply를 되돌리면 두 link와 Transaction이 만든 빈 parent를 제거합니다. 기존 target을 backup한 apply는 원래 type, bytes, mode를 복원합니다.

apply 이후 `~/.claude`나 `~/.codex`에 다른 도구가 unmanaged 파일을 만들면 parent 제거가 안전하지 않으므로 rollback 전체를 시작하기 전에 거부합니다. 새 파일을 보존하고 receipt의 적용 후 상태와 차이를 확인한 뒤 다시 dry-run합니다. `--force` 경로는 제공하지 않습니다.

## Legacy entry point

```console
bash agents/init.sh
```

이 entry point는 먼저 `agents-links`를 Transaction으로 적용합니다. 성공한 경우에만 Hermes와 OpenClaw의 append-once post-config를 실행합니다. `--dry-run`, `--help`, link 적용 실패에서는 legacy post-config를 실행하지 않습니다.

```console
bash agents/init.sh --dry-run
bash agents/init.sh --backup
```

Hermes/OpenClaw 변경은 receipt와 rollback 대상이 아닙니다. 해당 파일을 직접 확인해 복구합니다.
