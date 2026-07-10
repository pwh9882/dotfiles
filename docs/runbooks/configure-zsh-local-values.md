# Zsh local 값 설정

tracked `zsh/.zshrc.local.<hostname>` 파일에는 Conda, Homebrew, Flutter처럼 공개해도 되는 도구 초기화만 두고 있습니다. SSH 별칭, 원격 경로, AWS profile, 개인 CloudStorage 경로는 기기의 `~/.zshenv.secrets`에 둡니다. 이 파일은 `zsh/.zshrc`가 있을 때만 불러오며 `*.secrets` 규칙으로 Git에서 제외됩니다.

## 최초 1회 설정

기존 `~/.zshenv.secrets`를 에디터로 열어 필요한 항목만 추가합니다. Installer는 이 파일을 생성하거나 변경하지 않습니다.

```zsh
# ~/.zshenv.secrets
export DOTFILES_CODS_SSH_ALIAS='remote-dev'
export DOTFILES_CODS_REMOTE_PATH='/home/developer/'
export AWS_PROFILE='default-profile'

# Google Drive 계정이 여러 개이거나 자동 탐색이 맞지 않을 때만 설정
# export DOTFILES_GOOGLE_DRIVE_DIR="$HOME/Library/CloudStorage/<local-drive-directory>"
```

```bash
chmod 600 ~/.zshenv.secrets
exec zsh
```

| 변수 | 용도 | 필수 여부 |
|---|---|---|
| `DOTFILES_CODS_SSH_ALIAS` | `~/.ssh/config`의 Host 별칭 | 기본 원격 호스트를 쓸 때 필요 |
| `DOTFILES_CODS_REMOTE_PATH` | VS Code가 열 기본 원격 절대 경로 | 선택, 기본값은 `/` |
| `DOTFILES_GOOGLE_DRIVE_DIR` | `gd`가 이동할 로컬 디렉토리 | 여러 계정이 mount된 경우만 권장 |
| `AWS_PROFILE` | AWS CLI 기본 profile | AWS를 사용하는 기기에서만 선택 |

`DEFAULT_USER`는 더 이상 설정하지 않습니다. 공통 설정은 필요한 경우 `$HOME`과 `$USER`를 사용합니다.

## 사용

`DOTFILES_CODS_SSH_ALIAS`를 설정했으면 원격 경로만 넘깁니다.

```zsh
cods
cods /workspace/project
```

기본 별칭을 설정하지 않았거나 이번 호출에서만 다른 원격을 열면 SSH 별칭을 명시적으로 넘깁니다. 원격 경로는 `/`로 시작하는 절대 경로만 받습니다.

```zsh
cods remote-dev /workspace/project
```

`gd`는 macOS `~/Library/CloudStorage`에 mount된 Google Drive가 하나이면 자동으로 찾습니다. 여러 계정이 있으면 임의의 항목을 고르지 않고 `DOTFILES_GOOGLE_DRIVE_DIR`를 설정하라고 안내합니다.

```zsh
gd
```

## 검증

```bash
zsh -n zsh/.zshrc zsh/.zshrc.local.*
bash tests/privacy/run.sh
```

검사는 tracked Zsh profile에 email 형식의 경로, macOS 사용자 절대 경로, literal 원격 endpoint, `AWS_PROFILE`/`DEFAULT_USER` 대입이 다시 들어오는지 확인합니다.
