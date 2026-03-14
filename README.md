# 🏠 Dotfiles

> 현대적이고 생산적인 macOS 개발 환경을 위한 개인 설정 모음

## 📦 구성 요소

### 🖥️ 터미널 & 셸
- **[WezTerm](/.config/wezterm/)** - 고성능 터미널 (SSH workspace 통합, 세션 복원)
- **[tmux](/tmux/)** - Oh My Tmux + Catppuccin Mocha 테마 + 세션 복원
- **[Zsh](/zsh/)** - Oh-my-zsh + zoxide + 생산성 alias 모음
- **[Starship](/.config/starship.toml)** - 아름다운 프롬프트 (Catppuccin Mocha 테마)

### ✏️ 에디터
- **[Neovim](/.config/nvim/)** - AstroNvim v4 + Lazy.nvim 플러그인 관리
- **[Zed](/.config/zed/)** - 모던 에디터 (SSH 원격 개발 지원)

### 🛠️ 시스템 도구
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

## 🚀 빠른 설치

```bash
git clone https://github.com/pwh9882/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./init.sh
```

## ✨ 주요 기능

- **🔗 SSH 통합**: WezTerm에서 `Ctrl+A` → `p` → `ssh`로 SSH 호스트 바로 연결
- **📁 스마트 디렉토리 점프**: `j project_name`으로 빠른 이동 (zoxide)
- **💾 세션 복원**: WezTerm workspace 자동 저장/복원
- **🎨 통일된 테마**: 전체 도구에 걸친 다크 테마 일관성
- **⚡ 생산성 최적화**: 터미널 중심 워크플로우 + 현대적 플러그인

## 📁 디렉토리 구조

```
dotfiles/
├── .config/          # XDG 준수 설정 파일
│   ├── wezterm/      # 터미널 설정
│   ├── nvim/         # Neovim 설정
│   ├── zed/          # Zed 에디터 설정
│   └── starship.toml # 프롬프트 설정
├── tmux/             # tmux 설정 (Oh My Tmux)
├── zsh/              # Zsh 셸 설정
├── git/              # Git 설정
└── init.sh           # 설치 스크립트
```

## 🔧 Dependencies

- macOS
- Homebrew
- JetBrainsMonoNL Nerd Font
- Zsh + Oh-my-zsh
- Mamba/Conda (Python 환경 관리)

---

> 💡 **Tip**: 각 디렉토리에는 해당 도구의 상세 설정과 init 스크립트가 포함되어 있습니다.
