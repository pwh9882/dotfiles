-- WezTerm configuration for Windows (WSL primary)
-- Managed by dotfiles — synced via .config/init.sh on WSL
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ---- Appearance ----
config.color_scheme = 'Github Dark (Gogh)'
config.colors = {
    foreground = '#e6edf3',
}
config.font = wezterm.font('JetBrainsMono Nerd Font')
config.font_size = 11
config.window_decorations = 'RESIZE'
config.window_background_opacity = 0.9

-- ---- WSL as default ----
config.default_domain = 'WSL:Ubuntu-24.04'

-- ---- Launch menu (PowerShell, CMD without Windows Terminal) ----
config.launch_menu = {
    { label = 'PowerShell', args = { 'powershell.exe' } },
    { label = 'CMD', args = { 'cmd.exe' } },
}

-- ---- Leader key (Ctrl+A, same as Mac) ----
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

local function move_pane(key, direction)
    return {
        key = key,
        mods = 'LEADER',
        action = wezterm.action.ActivatePaneDirection(direction),
    }
end

local function resize_pane(key, direction)
    return {
        key = key,
        action = wezterm.action.AdjustPaneSize { direction, 3 },
    }
end

config.keys = {
    -- Split panes (same as Mac: Leader + " / %)
    { key = '"', mods = 'LEADER', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '%', mods = 'LEADER', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },

    -- Send Ctrl+A when pressed twice
    { key = 'a', mods = 'LEADER|CTRL', action = wezterm.action.SendKey { key = 'a', mods = 'CTRL' } },

    -- Move panes (Leader + hjkl / arrows)
    move_pane('phys:h', 'Left'),
    move_pane('phys:j', 'Down'),
    move_pane('phys:k', 'Up'),
    move_pane('phys:l', 'Right'),
    move_pane('LeftArrow', 'Left'),
    move_pane('DownArrow', 'Down'),
    move_pane('UpArrow', 'Up'),
    move_pane('RightArrow', 'Right'),

    -- Resize panes (Leader + r, then hjkl)
    { key = 'r', mods = 'LEADER', action = wezterm.action.ActivateKeyTable {
        name = 'resize_panes', one_shot = false, timeout_milliseconds = 1000,
    }},

    -- Tab switching (Ctrl+Alt+Arrow, Mac uses Cmd+Alt)
    { key = 'LeftArrow', mods = 'CTRL|ALT', action = wezterm.action.ActivateTabRelative(-1) },
    { key = 'RightArrow', mods = 'CTRL|ALT', action = wezterm.action.ActivateTabRelative(1) },

    -- Launcher (Alt+L)
    { key = 'l', mods = 'ALT', action = wezterm.action.ShowLauncher },

    -- Shift+Enter for newline (without executing command)
    { key = 'Enter', mods = 'SHIFT', action = wezterm.action { SendString = "\x1b\r" } },
}

config.key_tables = {
    resize_panes = {
        resize_pane('j', 'Down'),
        resize_pane('k', 'Up'),
        resize_pane('h', 'Left'),
        resize_pane('l', 'Right'),
    },
}

return config
