# tmux (Oh My Tmux)

> Catppuccin Mocha 테마 + Powerline + 실용적인 커스터마이징

## 설치

```bash
bash tmux/init.sh
```

tmux 설치 + Oh My Tmux 클론 + 설정 심링크가 자동으로 진행됩니다.

## 키바인딩

prefix: `Ctrl+b`

### 세션

| 키 | 동작 |
|---|---|
| `prefix` `C-c` | 새 세션 생성 |
| `prefix` `C-f` | 이름으로 세션 검색 |
| `prefix` `$` | 세션 이름 변경 |
| `prefix` `s` | 세션 목록/전환 |
| `prefix` `d` | 세션 분리 (detach) |

### 윈도우

| 키 | 동작 |
|---|---|
| `prefix` `c` | 새 윈도우 |
| `prefix` `C-h` | 이전 윈도우 |
| `prefix` `C-l` | 다음 윈도우 |
| `prefix` `Tab` | 마지막 윈도우 토글 |
| `prefix` `,` | 윈도우 이름 변경 |
| `prefix` `w` | 윈도우/패널 트리 |

### 패널

| 키 | 동작 |
|---|---|
| `prefix` `_` | 좌/우 분할 |
| `prefix` `-` | 위/아래 분할 |
| `prefix` `h/j/k/l` | 패널 이동 (vim) |
| `prefix` `H/J/K/L` | 패널 크기 조절 |
| `prefix` `+` | 패널 전체화면 분리 |
| `prefix` `q` | 패널 번호 표시 |
| `prefix` `x` | 패널 닫기 |

### 복사 모드

| 키 | 동작 |
|---|---|
| `prefix` `Enter` | 복사 모드 진입 |
| 마우스 드래그 | 텍스트 선택 (자동 복사 안 됨) |
| `v` | 선택 시작 (키보드) |
| `y` | 선택 복사 |
| `/` | 텍스트 검색 |
| `q` | 복사 모드 종료 |

### 기타

| 키 | 동작 |
|---|---|
| `prefix` `e` | 설정 파일 편집 |
| `prefix` `r` | 설정 리로드 |
| `prefix` `m` | 마우스 모드 토글 |
| `prefix` `I` | TPM 플러그인 설치 |
| `prefix` `u` | TPM 플러그인 업데이트 |

## 커스터마이징 내용

### 테마

Catppuccin Mocha 팔레트 + Powerline 구분자 (Nerd Font 필요)

### 상태바

```
왼쪽:  ❐ 세션명
오른쪽: 실행 명령어 | 현재 경로 | 업타임 | 유저@호스트
```

### 변경된 기본 설정

| 설정 | 값 |
|---|---|
| 새 세션/윈도우 현재 경로 유지 | `true` |
| 마우스 모드 | 기본 ON |
| vi 복사 모드 | ON |
| OS 클립보드 자동 복사 | OFF (`y`로 수동 복사) |
| 마우스 드래그 | 선택만, 자동 복사 안 함 |
| 클릭 후 스크롤 | 선택 확장 안 됨 |

### 플러그인 (TPM)

| 플러그인 | 기능 |
|---|---|
| tmux-resurrect | 세션 저장/복원 (`prefix` `Ctrl+s` 저장, `prefix` `Ctrl+r` 복원) |
| tmux-continuum | 자동 저장 + tmux 시작 시 자동 복원 |
| tmux-copycat | 정규식 텍스트 검색 (`prefix` `/`) |
| tmux-cpu | CPU/RAM 사용량 |

## 터미널 외부 명령어

```bash
tmux                          # 새 세션 시작
tmux new -s <name>            # 이름 지정 세션
tmux ls                       # 세션 목록
tmux attach -t <name>         # 세션 접속
tmux kill-session -t <name>   # 세션 삭제
tmux kill-server              # 전체 종료
```

## 트러블슈팅

### `open terminal failed: not a terminal`

오래된 tmux 서버가 남아있을 때 발생. `tmux kill-server` 후 재시작.

### 설정이 적용 안 될 때

`#!important`를 줄 끝에 붙이면 Oh My Tmux 기본값을 강제로 덮어씁니다:

```bash
bind c new-window -c '#{pane_current_path}' #!important
```
