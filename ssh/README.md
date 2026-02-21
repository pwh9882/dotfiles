# SSH 설정

## 구조

```
ssh/
├── config.common   # 공통 SSH config (ControlMaster 등)
├── init.sh         # 초기화 (config.common을 ~/.ssh/config에 Include)
└── README.md
```

## SSH Agent: Bitwarden

SSH 키는 **Bitwarden Desktop 앱의 SSH Agent**로 관리한다.

### 플랫폼별 동작

| 플랫폼 | 동작 방식 | 설정 파일 |
|--------|----------|----------|
| macOS | Bitwarden → 소켓 직접 제공 | `zsh/.zshrc` |
| Native Linux | Bitwarden → 소켓 직접 제공 | `bash/.bashrc` |
| WSL2 | Windows Bitwarden → npiperelay + socat 브릿지 | `bash/.bashrc` |
| Headless 서버 | Agent 없음. 공개키만 등록 | — |

### macOS / Native Linux
```
Bitwarden Desktop → ~/.bitwarden-ssh-agent.sock → ssh client
```

### WSL2
```
[Windows] Bitwarden Desktop → named pipe
    ↓ npiperelay + socat
[WSL2] ~/.ssh/agent.sock → ssh client
```

WSL2 의존성:
- `socat`: `sudo apt install -y socat`
- `npiperelay`: `go install github.com/jstarks/npiperelay@latest`

### 설정

**1. Bitwarden Desktop 설치**
```bash
# macOS
brew install --cask bitwarden

# Ubuntu (deb)
wget "https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=deb" -O bitwarden.deb
sudo dpkg -i bitwarden.deb

# Windows
# https://bitwarden.com/download/ 에서 다운로드
```

**2. 앱 설정**
- 서버 URL → Vaultwarden 주소 (self-hosted)
- Settings → SSH Agent → Enable

**3. 환경변수** (`zsh/.zshrc`, `bash/.bashrc`에 이미 포함)
```bash
# macOS (dmg) / Native Linux
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"

# macOS (App Store)
export SSH_AUTH_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"

# WSL2 (bash/.bashrc에서 자동 감지)
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"  # + npiperelay 브릿지
```

**4. 검증**
```bash
ssh-add -l        # Bitwarden에 저장된 키 목록
ssh user@host     # 접속 테스트
```

### 새 서버에 공개키 등록
```bash
# 공개키 확인
ssh-add -L

# 서버에 등록
ssh-copy-id user@newserver
# 또는
ssh user@server "echo '$(ssh-add -L | grep keyname)' >> ~/.ssh/authorized_keys"
```

### SSH config에서 IdentityFile

Bitwarden에 키가 있으면 `IdentityFile` 불필요:
```
Host myserver
  HostName 1.2.3.4
  User ubuntu
```

Bitwarden에 없는 키만 `IdentityFile` 지정:
```
Host legacy
  HostName 5.6.7.8
  User admin
  IdentityFile ~/.ssh/legacy_key
```

## config.common

모든 기기에서 공유하는 SSH 설정:
- **ControlMaster**: SSH 연결 다중화 (한 번 접속하면 추가 접속이 빠름)
- **ControlPath**: `~/.ssh/sockets/` 에 소켓 저장
- **ControlPersist**: 세션 종료 후에도 연결 유지
