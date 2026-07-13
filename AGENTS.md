# AGENTS.md

AI 코딩 에이전트를 위한 상세 기술 레퍼런스.

## Repository Structure

```
dotfiles/
├── CONTEXT.md                 # 저장소 도메인 모델과 공통 용어
├── bin/                       # dotfiles CLI + 사용자 실행 스크립트
├── lib/dotfiles/              # 트랜잭션 런타임, 모듈, legacy 링크 helper
├── tests/dotfiles/            # 설치·rollback 회귀 테스트
├── tests/legacy-links/        # legacy init의 fail-closed 링크 회귀 테스트
├── init.sh                    # 전체 초기화 오케스트레이터
├── zsh/                       # Zsh 셸 설정
│   ├── .zshrc                 # 공통 설정 (모든 기기 공유)
│   ├── update-check.zsh       # background fetch와 업데이트 알림
│   └── init.sh                # 공통 링크 + XDG local 파일 migration
├── tmux/                      # tmux 설정 (Oh My Tmux)
│   ├── tmux.conf.local        # 커스텀 설정
│   ├── init.sh                # tmux 설치 + Oh My Tmux 클론 + 심볼릭 링크
│   └── README.md
├── claude/                    # Claude Code CLI 커스텀 상태 바
│   ├── statusline-command.sh  # Catppuccin Mocha 테마 상태 바 스크립트
│   └── init.sh                # ~/.claude/에 심볼릭 링크 + settings.json 설정
├── .config/
│   ├── wezterm/               # WezTerm 터미널 (leader: Ctrl+A)
│   │   ├── wezterm.lua        # 플랫폼 감지와 모듈 조합
│   │   ├── appearance.lua     # 다크모드 감지
│   │   ├── keys.lua           # 공통/플랫폼별 키 바인딩
│   │   ├── plugins.lua        # macOS 세션 복원과 워크스페이스 전환
│   │   ├── theme.lua          # 탭과 상태 바 렌더링
│   │   └── projects.lua       # 프로젝트 디렉토리 목록
│   ├── nvim/                  # Neovim (LazyVim + lazy.nvim)
│   │   ├── init.lua           # lazy.nvim과 LazyVim 부트스트랩
│   │   └── lua/plugins/*.lua  # 플러그인 설정 (대부분 비활성 템플릿)
│   ├── starship.toml          # Starship 프롬프트 (Catppuccin Mocha)
│   ├── karabiner/             # 키보드 리매핑 (Caps Lock→F17, HJKL→방향키)
│   ├── zed/                   # Zed 에디터 (SSH 원격, AI 어시스턴트)
│   ├── fish/                  # Fish 셸 (최소 설정)
│   └── neofetch/              # 시스템 정보 표시
└── docs/                      # ADR, 아키텍처, runbook, 도구 문서
    ├── adr/                   # 장기 설계 결정
    ├── agents/                # 이슈 트래커와 에이전트 작업 규칙
    ├── architecture/          # 현재 구조와 경계
    ├── runbooks/              # 운영 절차
    └── wezterm-mux.md         # WezTerm 원격 멀티플렉싱 가이드
```

## Multi-Machine Architecture

Machine identity는 다음 경로로 해석한다.

- `llm-instance --details`가 현재 Instance 문서의 ID와 Role을 검증한다.
- 머신 목록과 private topology는 저장소가 아니라 LLM-WIKI의 현재 Instance 문서에서 확인한다.
- dotfiles Module 선택은 Instance와 Role에 의존하지 않는다. 기본 순서는 `bin agents-links`로 고정한다.

Shell 설정은 공통 파일과 checkout 밖의 Local Adapter로 분리한다.

- `zsh/.zshrc` — 모든 기기에서 공유하는 설정
- `~/.config/dotfiles/zsh.local` — 기기별 interactive Zsh 설정
- `~/.config/dotfiles/zshenv.local` — 기기별 Zsh 환경 설정
- `~/.config/dotfiles/bash.local` — 기기별 interactive Bash 설정
- `~/.zshenv.secrets` — secret, 사설 endpoint, 개인 경로

`zsh/init.sh`와 `bash/init.sh`는 package 설치 전에 XDG Local Adapter가 readable regular file인지 검사하고, 기존 `~/.zshrc.local`, `~/.zshenv.local`, `~/.bashrc.local`을 한 번 복사한다. migration 전 머신에서는 공통 shell 파일이 기존 경로를 읽는다. 새 머신별 값을 tracked hostname 파일에 추가하지 않는다.

## Init System

각 모듈의 `init.sh`는 멱등(idempotent)해야 한다.
루트 `init.sh`가 지원 모듈을 `bin → zsh → bash → agents → claude → ssh → tmux → .config` 순서로 정확히 한 번 실행한다. macOS에서는 마지막에 Karabiner helper를 컴파일한다.
`bin/init.sh`와 `agents/init.sh`의 native link 단계는 각각 `bin`, `agents-links` Transaction Module에 위임하며, 충돌 시 기본적으로 중단한다. Hermes/OpenClaw 후처리는 아직 rollback 범위 밖이다.

새 머신에서는 Transaction Module을 먼저 계획하고 적용한다.

```bash
./bin/dotfiles plan              # bin과 agents-links 변경을 읽기 전용으로 확인
./bin/dotfiles apply             # 두 Module을 고정 순서로 적용
./bin/dotfiles doctor --quick    # 저장소와 설정의 빠른 검사
```

전체 legacy bootstrap은 package 설치가 필요한 경우에 명시적으로 실행한다.

```bash
./init.sh --list   # 현재 플랫폼에서 실행할 모듈 경로만 출력
./init.sh          # package/network/sudo/chsh를 포함할 수 있는 전체 설치
bash zsh/init.sh   # zsh만 설치
bash tmux/init.sh  # tmux만 설치 (brew/apt/pacman 지원)
./bin/dotfiles doctor --only bin  # bin 링크와 트랜잭션 상태 검증
./bin/dotfiles doctor --only agents-links  # Claude/Codex 공통 지침 링크 검증
```

아직 Transaction Module로 이전하지 않은 Zsh, Bash, Claude statusline, tmux, `.config`의 파일 링크는 `lib/dotfiles/legacy_links.sh`를 사용한다. 정확한 symlink는 no-op, 없는 경로는 새 링크, 일반 파일·디렉터리·다른 symlink는 충돌이다. 모든 대상의 preflight가 끝나기 전에는 링크를 만들지 않는다. Starship override와 Claude settings regular file은 임시 파일을 거쳐 원자적으로 갱신하고, 기존 Zed 설정은 보존한 채 로컬 병합 안내와 함께 중단한다. Legacy bootstrap의 package 설치, 외부 download, `sudo`, `chsh`는 rollback 대상이 아니다.

## Design Conventions

- **테마**: Catppuccin Mocha 통일 (WezTerm, Starship, tmux, Claude statusline)
- **폰트**: JetBrainsMonoNL Nerd Font (터미널), Berkeley Mono (탭 바)
- **XDG 준수**: 설정은 `~/.config/` 하위에 배치
- **심볼릭 링크 기반**: init.sh가 dotfiles → 홈 디렉토리로 심볼릭 링크 생성
- **Lua 우선**: WezTerm, Neovim 모두 Lua 기반 설정
- **세션 내용 보호**: WezTerm과 tmux는 레이아웃·프로세스 메타데이터만 복원하며 패인 텍스트는 저장하지 않음

## Key Keybindings

| 컨텍스트 | 키 | 동작 |
|---|---|---|
| WezTerm | `Ctrl+A` | Leader key |
| WezTerm | `Leader + "` / `%` | 패인 수평/수직 분할 |
| WezTerm | `Leader + h/j/k/l` | 패인 이동 |
| WezTerm (macOS) | `Leader + s` / `f` | 워크스페이스 전환 |
| tmux | `Ctrl+b` | Prefix key |
| tmux | `Prefix + _` / `-` | 패인 분할 |
| Neovim | `Space` | Leader key |
| Karabiner | `Caps Lock` | F17 (프로필 전환) |

## Security

### .gitignore 적용 항목
- `.config/zed/conversations/` — AI 대화 (API 토큰 노출 위험)
- `.config/zed/prompts/` — 커스텀 프롬프트

### 주의 사항
- tracked shell 파일에 민감한 값(비밀번호, 토큰)을 직접 넣지 않는다
- 과거 Zed 대화에서 Docker/GitHub PAT가 노출되어 히스토리 전체 정리한 이력이 있음
- 커밋 전 반드시 `git status` + `git diff` 확인
- 민감 데이터가 커밋되면: `git filter-repo`로 히스토리 정리 + force push

### 커밋하면 안 되는 파일
- API 키, 토큰, 비밀번호가 포함된 파일
- 에디터 AI 대화 기록
- 임시 파일, 런타임 생성 파일 (embeddings, AppSupport 등)

## LLM-WIKI Git Wrappers

- 원본은 `bin/llm-instance`와 `bin/llm-wiki-*`에 둔다.
- `bin/init.sh`가 트랜잭션 `bin` Module을 실행해 `dotfiles`, `dotfiles-check`, `llm-instance`, `llm-wiki-*`를 `~/.local/bin/`으로 연결한다.
- `agents/init.sh`는 `agents-links` Module을 먼저 적용하고, 성공한 경우에만 Hermes/OpenClaw legacy post-config를 실행한다.
- wrapper는 `LLM_WIKI_DIR`이 있으면 그 값을 우선하고, 없으면 `~/llm-wiki`, `~/obsidian-vault/LLM-WIKI`, `~/Documents/Obsidian Vault/LLM-WIKI` 순서로 Git checkout을 찾는다.
- 프로젝트 Codex 세션에서 wiki Git을 다룰 때는 raw `git -C` 대신 이 wrapper를 사용한다.
