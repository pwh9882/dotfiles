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

## Configuration Files

- **Main config**: `wezterm.lua`
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