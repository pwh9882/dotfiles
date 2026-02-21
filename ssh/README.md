# SSH 설정

## 구조

```
ssh/
├── config.common         # 공통 SSH config (ControlMaster 등)
├── init.sh               # 초기화 (config.common을 ~/.ssh/config에 Include)
├── ssh-agent-add.sh      # [DEPRECATED] 레거시 ssh-agent 헬퍼
└── README.md
```

## SSH Agent: Bitwarden

SSH 키는 **Bitwarden Desktop 앱의 SSH Agent**로 관리한다.

### 동작 방식
```
Bitwarden vault (SSH 키 저장)
    ↓ vault 잠금 해제
~/.bitwarden-ssh-agent.sock (SSH Agent 소켓)
    ↓ SSH_AUTH_SOCK
ssh client → 서버 접속 (Bitwarden 앱에서 승인)
```

### 설정

**1. Bitwarden Desktop 설치**
```bash
# macOS
brew install --cask bitwarden

# Ubuntu (deb)
wget "https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=deb" -O bitwarden.deb
sudo dpkg -i bitwarden.deb

# Ubuntu (snap)
sudo snap install bitwarden
```

**2. 앱 설정**
- 서버 URL → Vaultwarden 주소 (self-hosted)
- Settings → SSH Agent → Enable

**3. 환경변수** (`zsh/.zshrc`에 이미 포함)
```bash
# macOS (dmg)
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"

# macOS (App Store)
export SSH_AUTH_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"

# Linux
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
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
  # IdentityFile 필요 없음
```

Bitwarden에 없는 키만 `IdentityFile` 지정:
```
Host legacy
  HostName 5.6.7.8
  User admin
  IdentityFile ~/.ssh/legacy_key
```

### Headless 서버 (GUI 없음)

Bitwarden Desktop은 GUI가 필요하므로 headless 서버에서는 Agent 사용 불가.
→ 클라이언트에서 공개키를 서버의 `authorized_keys`에 등록하는 방식으로 사용.

## config.common

모든 기기에서 공유하는 SSH 설정:
- **ControlMaster**: SSH 연결 다중화 (한 번 접속하면 추가 접속이 빠름)
- **ControlPath**: `~/.ssh/sockets/` 에 소켓 저장
- **ControlPersist**: 세션 종료 후에도 연결 유지

## 레거시 (ssh-agent-add.sh)

이전에는 `ssh-agent-add.sh`로 수동으로 키를 agent에 등록했음.
Bitwarden SSH Agent로 대체되어 **deprecated**. Bitwarden이 없는 환경에서만 fallback으로 사용.
