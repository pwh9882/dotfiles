# AGENTS.md

AI 코딩 에이전트를 위한 상세 기술 레퍼런스.

## Repository Structure

```
dotfiles/
├── bin/                       # 사용자 실행 스크립트 + ~/.local/bin 링크
├── init.sh                    # 전체 초기화 오케스트레이터
├── zsh/                       # Zsh 셸 설정
│   ├── .zshrc                 # 공통 설정 (모든 기기 공유)
│   ├── .zshrc.local.*         # 기기별 설정 (hostname 기반)
│   └── init.sh                # ~/.zshrc, ~/.zshrc.local 심볼릭 링크
├── tmux/                      # tmux 설정 (Oh My Tmux)
│   ├── tmux.conf.local        # 커스텀 설정 (510줄)
│   ├── init.sh                # tmux 설치 + Oh My Tmux 클론 + 심볼릭 링크
│   └── README.md
├── claude/                    # Claude Code CLI 커스텀 상태 바
│   ├── statusline-command.sh  # Catppuccin Mocha 테마 상태 바 스크립트
│   └── init.sh                # ~/.claude/에 심볼릭 링크 + settings.json 설정
├── .config/
│   ├── wezterm/               # WezTerm 터미널 (leader: Ctrl+A)
│   │   ├── wezterm.lua        # 메인 설정 (21KB, 세션 복원, 워크스페이스)
│   │   ├── appearance.lua     # 다크모드 감지
│   │   └── projects.lua       # 프로젝트 디렉토리 목록
│   ├── nvim/                  # Neovim (AstroNvim v4 + Lazy.nvim)
│   │   ├── init.lua           # Lazy.nvim 부트스트랩
│   │   └── lua/plugins/*.lua  # 플러그인 설정 (대부분 비활성 템플릿)
│   ├── starship.toml          # Starship 프롬프트 (262줄, Catppuccin Mocha)
│   ├── karabiner/             # 키보드 리매핑 (Caps Lock→F17, HJKL→방향키)
│   ├── zed/                   # Zed 에디터 (SSH 원격, AI 어시스턴트)
│   ├── fish/                  # Fish 셸 (최소 설정)
│   └── neofetch/              # 시스템 정보 표시
└── docs/                      # 문서
    └── wezterm-mux.md         # WezTerm 원격 멀티플렉싱 가이드
```

## Multi-Machine Architecture

Zsh 설정은 공통/기기별로 분리되어 있다:

- `zsh/.zshrc` — 모든 기기에서 공유하는 설정
- `zsh/.zshrc.local.<hostname>` — 기기별 설정 (conda 경로, AWS_PROFILE 등)
- `zsh/init.sh`가 `hostname -s` 기반으로 `~/.zshrc.local` 심볼릭 링크를 자동 생성

현재 기기:
| Hostname | 용도 |
|---|---|
| `ddps-mini` | Mac Mini |
| `woohyeok-MacBookPro` | MacBook Pro |
| `wini` | Mac Mini |
| `woopc` | WSL2 (Windows PC) |

새 기기 추가 시: `zsh/.zshrc.local.<새 hostname>` 생성 후 `bash zsh/init.sh` 실행.

## Init System

각 디렉토리의 `init.sh`는 독립적이며 멱등(idempotent)해야 한다.
루트 `init.sh`가 모든 하위 디렉토리를 순회하며 실행한다.

```bash
./init.sh          # 전체 설치
bash zsh/init.sh   # zsh만 설치
bash tmux/init.sh  # tmux만 설치 (brew/apt/pacman 지원)
```

## Design Conventions

- **테마**: Catppuccin Mocha 통일 (WezTerm, Starship, tmux, Claude statusline)
- **폰트**: JetBrainsMonoNL Nerd Font (터미널), Berkeley Mono (탭 바)
- **XDG 준수**: 설정은 `~/.config/` 하위에 배치
- **심볼릭 링크 기반**: init.sh가 dotfiles → 홈 디렉토리로 심볼릭 링크 생성
- **Lua 우선**: WezTerm, Neovim 모두 Lua 기반 설정

## Key Keybindings

| 컨텍스트 | 키 | 동작 |
|---|---|---|
| WezTerm | `Ctrl+A` | Leader key |
| WezTerm | `Leader + "` / `%` | 패인 수평/수직 분할 |
| WezTerm | `Leader + h/j/k/l` | 패인 이동 |
| WezTerm | `Leader + s` / `f` | 워크스페이스 전환 |
| tmux | `Ctrl+b` | Prefix key |
| tmux | `Prefix + _` / `-` | 패인 분할 |
| Neovim | `Space` | Leader key |
| Karabiner | `Caps Lock` | F17 (프로필 전환) |

## Security

### .gitignore 적용 항목
- `.config/zed/conversations/` — AI 대화 (API 토큰 노출 위험)
- `.config/zed/prompts/` — 커스텀 프롬프트

### 주의 사항
- `zsh/.zshrc.local.*` 파일에 민감한 값(비밀번호, 토큰)을 직접 넣지 않는다
- 과거 Zed 대화에서 Docker/GitHub PAT가 노출되어 히스토리 전체 정리한 이력이 있음
- 커밋 전 반드시 `git status` + `git diff` 확인
- 민감 데이터가 커밋되면: `git filter-repo`로 히스토리 정리 + force push

### 커밋하면 안 되는 파일
- API 키, 토큰, 비밀번호가 포함된 파일
- 에디터 AI 대화 기록
- 임시 파일, 런타임 생성 파일 (embeddings, AppSupport 등)

## LLM-WIKI Git Wrappers

- 원본은 `bin/llm-wiki-git`, `bin/llm-wiki-status`, `bin/llm-wiki-commit`에 둔다.
- `bin/init.sh`가 세 명령을 `~/.local/bin/`으로 심볼릭 링크한다.
- wrapper는 `LLM_WIKI_DIR`이 있으면 그 값을 우선하고, 없으면 `~/llm-wiki`, `~/obsidian-vault/LLM-WIKI`, `~/Documents/Obsidian Vault/LLM-WIKI` 순서로 Git checkout을 찾는다.
- 프로젝트 Codex 세션에서 wiki Git을 다룰 때는 raw `git -C` 대신 이 wrapper를 사용한다.
