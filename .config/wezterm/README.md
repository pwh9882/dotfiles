# WezTerm Configuration

This WezTerm configuration provides tmux-like session management with advanced workspace switching and session resurrection capabilities.

## Features

- **Project-based workspace management** with zoxide integration
- **Session resurrection** - automatically save and restore terminal sessions
- **Tmux-like keybindings** with `Ctrl+A` as leader key
- **Automatic session persistence** every 15 minutes
- **Smart workspace switching** with fuzzy finder

## Dependencies

- [zoxide](https://github.com/ajeetdsouza/zoxide) - Smart directory jumper
- [resurrect.wezterm](https://github.com/MLFlexer/resurrect.wezterm) - Session management
- [smart_workspace_switcher.wezterm](https://github.com/MLFlexer/smart_workspace_switcher.wezterm) - Workspace switching

## Installation

1. Install zoxide:
   ```bash
   brew install zoxide
   ```

2. Add zoxide to your shell configuration:
   ```bash
   # For zsh (add to ~/.zshrc)
   eval "$(zoxide init zsh)"
   
   # For fish (add to ~/.config/fish/config.fish)
   zoxide init fish | source
   ```

3. The WezTerm plugins are automatically loaded via the configuration.

## Keybindings

### Leader Key
- **Leader**: `Ctrl+A` (timeout: 1000ms)

### Workspace Management (tmux session equivalent)
| Key | Action | Description |
|-----|--------|-------------|
| `Ctrl+A` + `s` | Switch workspace | Open fuzzy finder to switch to any directory (zoxide-based) |
| `Ctrl+A` + `S` | Previous workspace | Switch to previously active workspace |
| `Ctrl+A` + `f` | Switch workspace | Alternative workspace switcher |

### Session Management
| Key | Action | Description |
|-----|--------|-------------|
| `Alt+w` | Save workspace | Save current workspace state |
| `Alt+W` | Save window | Save current window state |
| `Alt+T` | Save tab | Save current tab state |
| `Alt+s` | Save all | Save both workspace and window state |
| `Alt+o` | Restore session | Open fuzzy finder to restore saved sessions |
| `Alt+d` | Delete session | Open fuzzy finder to delete saved sessions |

### Pane Management
| Key | Action | Description |
|-----|--------|-------------|
| `Ctrl+A` + `"` | Split horizontal | Split current pane horizontally |
| `Ctrl+A` + `%` | Split vertical | Split current pane vertically |
| `Ctrl+A` + `h/j/k/l` | Move pane | Navigate between panes (vim-style) |
| `Ctrl+A` + `←/↓/↑/→` | Move pane | Navigate between panes (arrow keys) |
| `Ctrl+A` + `r` | Resize mode | Enter pane resize mode |

### Resize Mode
After pressing `Ctrl+A` + `r`, use:
- `h/j/k/l` to resize panes
- Mode automatically exits after 1 second of inactivity

### Other Shortcuts
| Key | Action | Description |
|-----|--------|-------------|
| `Ctrl+A` + `Ctrl+A` | Send Ctrl+A | Send literal Ctrl+A to terminal |
| `Ctrl+A` + `p` | Project picker | Open project picker |
| `Cmd+,` | Edit config | Open WezTerm config in nvim |
| `Cmd+Alt+←/→` | Switch tabs | Navigate between tabs |

## Usage Workflow

### 1. Project-based Sessions
```bash
# Navigate to different projects using zoxide
z myproject          # This will be remembered by zoxide
```

Then in WezTerm:
- `Ctrl+A` + `s` → Select "myproject" → Automatically switches to that directory
- Work in that workspace with multiple tabs/panes
- Session is automatically saved every 15 minutes

### 2. Session Restoration
- **Automatic**: Sessions are restored when WezTerm starts
- **Manual**: Use `Alt+o` to restore specific saved sessions
- **Backup**: Use `Alt+s` to manually save current session

### 3. Workspace Switching
- `Ctrl+A` + `s`: Opens fuzzy finder with your most visited directories
- Type to filter, Enter to select
- Previous workspace state is automatically saved
- New workspace state is automatically restored (if available)

## Advanced Features

### Automatic Session Management
- Sessions are automatically saved every 15 minutes
- Workspace state is saved when switching workspaces
- Session is restored on WezTerm startup
- Up to 1000 lines of terminal output are preserved per pane

### Workspace Integration
- When creating new workspace, attempts to restore previous session
- If no saved session exists, opens in the project directory
- Workspace name is displayed in the status bar
- Custom workspace formatting with icons

### Error Handling
- Resurrection errors are shown as toast notifications
- Detailed logging for debugging session issues
- Graceful fallback when saved sessions are corrupted

## SSH Remote Detection System

SSH 접속 시 탭 배지, 상태 바 CWD, 호스트명, OS 아이콘이 원격 호스트에 맞게 자동 변경된다.

### 구조 개요

```
┌─ Shell (zsh precmd) ─────────────────────────────┐
│  OSC 1337 SetUserVar로 매 프롬프트마다 전송:      │
│  • WEZTERM_HOST  — hostname -s                    │
│  • WEZTERM_OS    — uname -s (Darwin/Linux)        │
│  • WEZTERM_CWD   — ${PWD/#$HOME/~}               │
└──────────────────────────────────────────────────-┘
                        ▼
┌─ WezTerm (theme.lua) ────────────────────────────┐
│                                                   │
│  detect_host(pane)  ← 원격 호스트 감지            │
│    1) pane title 패턴 매칭                        │
│       • "host ❐ ..."        (Oh My Tmux)          │
│       • "user@host[: ...]"  (Linux SSH)           │
│    2) user_vars.WEZTERM_HOST (macOS SSH 등)       │
│    3) pane별 캐시 (TUI가 title을 바꿀 때 유지)   │
│                                                   │
│  감지 결과 → 탭 배지 / 상태 바에 반영             │
└───────────────────────────────────────────────────┘
```

### 왜 다단계 감지인가

WezTerm은 일반 `ssh` 명령의 원격 호스트를 직접 알 수 없다:
- `current_working_dir.host` — SSH 후에도 로컬 hostname 유지
- `tab.active_pane.title` — **Linux**는 `user@host: path` 포함, **macOS**는 `~`만 표시

따라서 title 패턴을 먼저, user_vars를 fallback으로 사용한다.
title 우선인 이유: nested SSH (MacBook → A → B)에서 title은 최종 호스트(B)를 반영하지만,
user_vars는 중간 호스트(A)에 머물기 때문.

### 탭 배지 (색상 할당)

| 상태 | 배지 색상 | 스타일 |
|------|----------|--------|
| 로컬 | mauve (기본) | 활성: 색상 배경 + 어두운 글자 |
| 원격 | 호스트별 accent | 비활성: 어두운 배경 + 색상 글자 |

- 자주 쓰는 호스트는 고정 색상 map 사용
- 그 외 호스트는 정규화된 hostname(short/lowercase) 기반 hash fallback

### 상태 바 CWD (4단계 우선순위)

```
원격 pane:
  1) pane title에서 path 추출  ← "user@host: /path" 형식 (가장 신뢰)
  2) WEZTERM_CWD               ← host 일치 시만 (macOS SSH + dotfiles)
  3) pane별 캐시               ← tmux/TUI 진입 등으로 title이 바뀔 때
  4) 원격 hostname             ← 위 값이 모두 없을 때 안전 fallback

로컬 pane:
  → WEZTERM_CWD (precmd가 매번 갱신)

모두 실패 시:
  → 원격 hostname 또는 workspace 이름
```

title 추출을 최우선하는 이유: 원격 기기의 dotfiles가 오래되어
`WEZTERM_CWD`를 전송하지 않더라도 title에서 path를 얻을 수 있기 때문.

### 상태 바 호스트 & OS 아이콘

| 상태 | 호스트명 | OS 아이콘 | 배경색 |
|------|---------|-----------|--------|
| 로컬 | 로컬 hostname | 로컬 OS 기반 | surface0 |
| 원격 + dotfiles | 원격 hostname | WEZTERM_HOST가 일치할 때 WEZTERM_OS 기반 | accent (호스트별) |
| 원격 - dotfiles | 원격 hostname | Linux (기본) | accent (호스트별) |

### 셸 측 설정 (`zsh/.zshrc`)

```zsh
# WezTerm: broadcast host info via user vars on every prompt
# Re-emitting on precmd ensures values reset after exiting SSH
_wezterm_host_b64="$(echo -n "$(hostname -s)" | base64)"
_wezterm_os_b64="$(echo -n "$(uname -s)" | base64)"
_wezterm_user_var() {
    local osc
    osc="$(printf '\033]1337;SetUserVar=%s=%s\007' "$1" "$2")"
    if [[ -n "$TMUX" ]]; then
        printf '\033Ptmux;\033%s\033\\' "$osc"   # tmux passthrough 래핑
    else
        printf '%s' "$osc"
    fi
}
_wezterm_set_vars() {
    _wezterm_user_var WEZTERM_HOST "$_wezterm_host_b64"
    _wezterm_user_var WEZTERM_OS "$_wezterm_os_b64"
    _wezterm_user_var WEZTERM_CWD "$(printf '%s' "${PWD/#$HOME/~}" | base64)"
}
precmd_functions+=(_wezterm_set_vars)
```

- **OSC 1337 SetUserVar**: WezTerm 전용 이스케이프 시퀀스. 다른 터미널에서는 무시됨
- **precmd 훅**: SSH 종료 후 로컬 셸로 돌아올 때 즉시 로컬 값으로 복구
- **base64 사전 계산**: HOST/OS는 셸 시작 시 1회, CWD만 매 프롬프트마다 계산
- **tmux passthrough 래핑**: tmux는 모르는 OSC를 삼키므로, `$TMUX` 안에서는
  `ESC Ptmux; …` DCS로 감싸서 방출한다. tmux 쪽에는 `allow-passthrough on`
  (tmux ≥ 3.3, `tmux.conf.local`)이 필요. 이 둘이 갖춰지면 로컬 tmux는 물론,
  ssh 너머 원격 tmux 안의 셸에서도 user vars가 WezTerm까지 도달한다

### 원격 tmux 직접 attach (`ssht`)

`ssh -t host tmux new -A`처럼 원격 tmux에 바로 붙는 경우, 원격 tmux가
셸과 WezTerm 사이에 끼기 때문에 일반 SSH와 신호 경로가 다르다:

- **원격에 dotfiles 있음**: passthrough 래핑된 user vars가 원격 tmux를 통과해
  도달하고, Oh My Tmux의 title(`#h ❐ #S`)로도 감지된다
- **원격이 stock tmux**: `set-titles off`가 기본이고 raw OSC는 버려지므로
  원격 쪽 신호가 전혀 없다

후자를 위해 `zsh/.zshrc`의 `ssht [ssh-options] <host>` 래퍼는 ssh 접속 **전에**
target host(마지막 인자)를 로컬에서 `WEZTERM_HOST`로 방출한다 (OS/CWD는
stale 값 오인 방지를 위해 비움). 원격 설정과 무관하게 배지가 즉시 원격으로
바뀌고, 종료 시 precmd가 로컬 값으로 복구한다.

한계: 로컬 tmux 안에서 `ssht`로 nested tmux를 만들면 원격 셸의 user vars는
로컬 tmux 층에서 버려진다 (passthrough는 한 층만 벗겨짐). 이 경우에도
`ssht` 래퍼의 사전 방출 덕분에 호스트 배지는 정상 표시되며, CWD만 원격
hostname fallback으로 표시된다.

### 새 기기 추가 시

원격 기기에 dotfiles를 설치하면 자동 적용 (멱등성 보장):
```bash
git clone <repo> ~/dotfiles && bash ~/dotfiles/init.sh
```

dotfiles 없는 서버도 title 패턴 감지로 호스트/CWD가 동작한다 (Linux 한정).

## Configuration Files

- **Main config**: `wezterm.lua`
- **Theme & tab badges**: `theme.lua`
- **Keybindings**: `keys.lua`
- **Plugins**: `plugins.lua`
- **Appearance**: `appearance.lua`
- **Projects**: `projects.lua`

## Troubleshooting

### Sessions not saving/restoring
1. Check if zoxide is properly installed: `which zoxide`
2. Ensure zoxide is initialized in your shell
3. Check WezTerm logs for resurrection errors
4. Try manual save with `Alt+s`

### Workspace switching not working
1. Verify zoxide has indexed directories: `zoxide query -l`
2. Add directories manually: `zoxide add /path/to/project`
3. Check if fuzzy finder opens (should show directory list)

### Performance issues
- Saved sessions are limited to 1000 lines per pane
- Old sessions can be deleted with `Alt+d`
- Consider disabling encryption if not needed

## Customization

### Changing Leader Key
```lua
config.leader = { key = 'b', mods = 'CTRL', timeout_milliseconds = 1000 }
```

### Adjusting Save Interval
```lua
resurrect.state_manager.periodic_save({
    interval_seconds = 30 * 60, -- 30 minutes
    save_workspaces = true,
    save_windows = true,
    save_tabs = true,
})
```

### Custom Workspace Formatter
```lua
workspace_switcher.workspace_formatter = function(label)
    return wezterm.format({
        { Attribute = { Italic = true } },
        { Foreground = { Color = "blue" } },
        { Text = "🚀 " .. label },
    })
end
```

## Tips

1. **Use zoxide regularly**: The more you use `z` command, the better workspace switching becomes
2. **Save before risky operations**: Use `Alt+s` before running potentially destructive commands
3. **Clean up old sessions**: Regularly use `Alt+d` to delete unused saved sessions
4. **Project naming**: Use consistent directory names for better workspace organization
5. **Multiple monitors**: Each window can have its own workspace and session state
