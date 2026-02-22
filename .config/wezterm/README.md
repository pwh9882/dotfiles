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

## SSH Host Color-Coded Tab Badges

SSH로 원격 서버에 접속하면 탭 배지(번호 부분)가 호스트별 고유 색상으로 표시된다.
로컬 탭은 기본 mauve, 원격 탭은 Catppuccin accent 6색 중 하나.

### 문제

WezTerm은 일반 `ssh` 명령으로 접속한 원격 호스트를 직접 알 수 없다:
- `current_working_dir.host` — SSH 후에도 로컬 hostname 유지
- `tab.active_pane.title` — macOS 타겟은 `~`만 표시 (hostname 없음)
- Linux 타겟만 `user@host: path` 또는 Oh My Tmux `host ❐ session ● ...` 형태로 hostname 포함

### 해결: 2단계 감지

```
detect_host(pane_info)
  1) pane title 패턴 매칭 (Linux SSH / tmux에서 동작)
     - "host ❐ ..."       → Oh My Tmux 타이틀
     - "user@host[: ...]" → 일반 SSH 셸 타이틀
  2) user_vars.WEZTERM_HOST (macOS 등 title에 hostname 없는 경우)
     → .zshrc의 precmd 훅이 매 프롬프트마다 hostname을 user var로 전송
```

title 패턴을 먼저 확인하는 이유: nested SSH (MacBook → wini → pi)에서
title은 최종 호스트(pi)를 반영하지만, user_vars는 중간 호스트(wini)에 머물기 때문.

### 셸 측 설정 (`zsh/.zshrc`)

```zsh
# WezTerm: broadcast hostname via user var on every prompt
_wezterm_host_b64="$(echo -n "$(hostname -s)" | base64)"
_wezterm_set_host() { printf "\033]1337;SetUserVar=%s=%s\007" WEZTERM_HOST "$_wezterm_host_b64"; }
precmd_functions+=(_wezterm_set_host)
```

- **OSC 1337 SetUserVar**: WezTerm이 인식하는 이스케이프 시퀀스. 다른 터미널에서는 무시됨
- **precmd 훅**: SSH 종료 후 로컬 셸로 돌아올 때 즉시 로컬 hostname으로 복구
- **base64 사전 계산**: 셸 시작 시 한 번만 계산, precmd에서는 가벼운 printf만 실행

### 색상 할당 (`theme.lua`)

- 6색 팔레트: sapphire, green, lavender, peach, flamingo, yellow
- 호스트별 해시 → 선호 색상 선택 → 중복 시 다음 색상으로 이동
- 활성 탭: 색상 배경 + 어두운 글자 (눈에 띔)
- 비활성 탭: 어두운 배경 + 색상 글자 (은은하게 유지)

### 새 기기 추가 시

원격 기기에 dotfiles를 설치하면 자동 적용 (멱등성 보장):
```bash
git clone <repo> ~/dotfiles && bash ~/dotfiles/init.sh
```

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