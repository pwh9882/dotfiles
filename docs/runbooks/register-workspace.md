# Workspace 등록과 현재 context 확인

## 공개 Workspace 등록

모든 머신에서 같은 논리 ID와 같은 HOME 상대 경로를 사용할 수 있으면 [`config/workspaces.tsv`](../../config/workspaces.tsv)에 row를 추가합니다.

```text
workspace_id	target_id	root
dotfiles	local	~/dotfiles
notes	local	~/Documents/notes
```

구분자는 space가 아니라 tab입니다. 공개 파일에는 absolute path, username, 사설 주소를 넣지 않습니다.

## 머신별 경로 등록

머신마다 checkout 위치가 다르거나 공개하기 어려운 경로는 local overlay에 둡니다.

```console
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
cp config/workspaces.local.example.tsv \
  "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/workspaces.local.tsv"
```

예시를 실제 absolute path로 바꿉니다.

```text
workspace_id	target_id	root
research	local	/absolute/path/to/research
```

같은 `workspace_id`와 `target_id`를 공개 파일과 local overlay에 모두 쓰면 local row가 해당 target만 교체합니다.

## 검증

```console
dotfiles doctor --only workspaces
dotfiles context
dotfiles context --json
```

Doctor의 `WARN workspace target root is missing`은 Registry가 유효하지만 현재 머신에 해당 directory가 없다는 뜻입니다. 아직 사용하지 않는 Workspace면 그대로 둘 수 있습니다. 사용해야 하는 Workspace면 checkout 경로를 만들거나 local overlay root를 수정합니다.

다음 오류는 Registry를 수정한 뒤 다시 검증합니다.

- strict header 또는 field 수가 다름
- ID에 대문자, underscore, space가 들어감
- 공개 root가 `~` 또는 `~/...` 형식이 아님
- root에 `$`, backtick, glob, `..` segment가 들어감
- 같은 파일에서 `(workspace_id, target_id)`가 중복됨
- 서로 다른 target이 같은 physical root를 가리킴

`context`에서 Workspace가 `unknown`이면 `pwd -P` 결과가 등록된 root와 같거나 그 하위인지 확인합니다. root가 존재하지 않으면 context는 해당 row를 건너뜁니다.
