# 🏠 Dotfiles

> 여러 macOS, Linux, WSL2 머신에서 공유하는 개인 개발 환경 설정

## 📦 구성 요소

### 🖥️ 터미널 & 셸
- **[WezTerm](/.config/wezterm/)** - 고성능 터미널 (SSH workspace 통합, 레이아웃·프로세스 기반 세션 복원)
- **[tmux](/tmux/)** - Oh My Tmux + Catppuccin Mocha 테마 + 세션 복원 (패인 내용 제외)
- **[Zsh](/zsh/)** - Oh-my-zsh + zoxide + 생산성 alias 모음
- **[Starship](/.config/starship.toml)** - 아름다운 프롬프트 (Catppuccin Mocha 테마)

### ✏️ 에디터
- **[Neovim](/.config/nvim/)** - LazyVim + lazy.nvim 플러그인 관리
- **[Zed](/.config/zed/)** - 모던 에디터 (SSH 원격 개발 지원)

### 🛠️ 시스템 도구
- **[bin](/bin/)** - `bin`·agent 링크의 트랜잭션 적용/검증 CLI와 LLM-WIKI 사용자 스크립트
- **[Karabiner](/.config/karabiner/)** - 키보드 리매핑
- **[Git](/git/)** - Git 전역 설정
- **[Neofetch](/.config/neofetch/)** - 시스템 정보 표시

## 🔀 Git Pull 전략

이 레포는 `pull.rebase = true` + `rebase.autoStash = true`로 설정되어 있다.

```bash
git config pull.rebase true
git config rebase.autoStash true
```

**왜 rebase인가?**
- dotfiles는 단일 사용자 레포이므로 merge commit(`Merge branch 'main' of ...`)이 의미 없다
- 여러 기기(Mac Mini, MacBook, WSL 등)에서 push/pull을 반복하면 불필요한 merge commit이 빠르게 쌓인다
- rebase는 로컬 커밋을 remote 위에 올려놓아 히스토리를 선형으로 유지한다

**왜 autoStash인가?**
- 기기 간 동기화 시 uncommitted 변경사항이 있는 상태에서 pull하는 경우가 잦다
- autoStash가 pull 전 자동 stash → pull 후 자동 unstash를 처리해준다

## 🚀 빠른 시작

### 안전한 링크 적용 (권장)

```bash
git clone https://github.com/pwh9882/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bin/dotfiles profile
./bin/dotfiles plan
./bin/dotfiles apply
./bin/dotfiles doctor --profile
./bin/dotfiles tour
```

`profile`은 현재 Instance와 Role을 검증한다. `plan`은 선택된 Transaction Module의 변경과 충돌을 읽기 전용으로 보여준다. `apply`는 같은 계획을 transaction receipt와 rollback 정보와 함께 적용한다. 현재 이 경로는 `bin`과 `agents-links`를 관리한다.

### 전체 legacy bootstrap (필요할 때 명시적으로 실행)

```bash
./init.sh --list
./init.sh
```

`--list`는 실행할 모듈 순서만 출력한다. 전체 bootstrap은 package 설치, 외부 download, `sudo`, 기본 셸 변경(`chsh`)을 수행할 수 있으며 이 단계들은 transaction rollback 범위 밖이다. 목록을 확인한 뒤 새 머신의 package와 나머지 설정이 필요할 때 실행한다.

Legacy init의 파일 링크도 기존 경로를 자동으로 덮어쓰지 않는다. 정확한 symlink는 그대로 두고, 일반 파일·디렉터리·다른 symlink를 만나면 원본을 보존한 채 중단한다. 기존 Zed 설정은 로컬에서 공통 값을 수동 병합한다.

## ✨ 주요 기능

- **🔗 SSH 통합**: WezTerm에서 `Ctrl+A` → `p` → `ssh`로 SSH 호스트 바로 연결
- **📁 스마트 디렉토리 점프**: `j project_name`으로 빠른 이동 (zoxide)
- **💾 세션 복원**: WezTerm workspace의 레이아웃과 프로세스를 자동 저장/복원 (패인 텍스트 제외)
- **🎨 통일된 테마**: 전체 도구에 걸친 다크 테마 일관성
- **⚡ 생산성 최적화**: 터미널 중심 워크플로우 + 현대적 플러그인
- **🩺 상태 확인**: `dotfiles tour`, `dotfiles profile`, `dotfiles doctor`로 현재 기능과 머신 계약 확인

WezTerm의 상태 바, 프로젝트·SSH picker, session 복원은 [5분 온보딩](docs/runbooks/use-wezterm-workflows.md)에서 실제 키 입력 순서로 확인할 수 있다. `dotfiles tour wezterm-context-status`처럼 Feature ID를 지정하면 지원 Role, platform, 개인정보 경계, 검증 명령도 함께 나온다.

## 📁 디렉토리 구조

```
dotfiles/
├── .config/          # XDG 준수 설정 파일
│   ├── wezterm/      # 터미널 설정
│   ├── nvim/         # Neovim 설정
│   ├── zed/          # Zed 에디터 설정
│   └── starship.toml # 프롬프트 설정
├── bin/              # dotfiles CLI와 사용자 실행 스크립트
├── lib/dotfiles/     # 트랜잭션 적용 런타임과 모듈
├── tests/dotfiles/   # 설치·rollback 회귀 테스트
├── bash/             # Bash 셸 설정
├── claude/           # Claude Code 상태 바 설정
├── ssh/              # SSH 공통 설정
├── tmux/             # tmux 설정 (Oh My Tmux)
├── zsh/              # Zsh 셸 설정
├── git/              # Git 설정
├── docs/             # ADR, 아키텍처, runbook, 도구 문서
└── init.sh           # 설치 스크립트
```

## 🔧 Dependencies

- macOS, Linux 또는 WSL2 (일부 GUI 기능은 플랫폼별 적용)
- Homebrew 또는 지원되는 Linux 패키지 관리자
- JetBrainsMonoNL Nerd Font
- Zsh + Oh-my-zsh
- Mamba/Conda (선택 사항, 머신별 Python 환경 관리)

---

> 💡 **Tip**: 각 디렉토리에는 해당 도구의 상세 설정과 init 스크립트가 포함되어 있습니다.
