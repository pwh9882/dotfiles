-- WezTerm configuration for Windows (WSL primary)
-- Managed by dotfiles — synced via .config/init.sh on WSL
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ---- Appearance ----
config.color_scheme = 'Github Dark (Gogh)'
config.colors = {
    foreground = '#e6edf3',
}
config.font = wezterm.font('JetBrainsMonoNL Nerd Font')
config.font_size = 9
config.window_background_opacity = 0.9

-- No system title bar — tab bar doubles as title bar (same as Mac)
config.window_decorations = 'RESIZE'
config.window_frame = {
    font = wezterm.font({ family = 'JetBrainsMonoNL Nerd Font', weight = 'Bold' }),
    font_size = 8,
}
config.use_fancy_tab_bar = true
config.tab_max_width = 25
config.command_palette_font_size = 9
config.char_select_font_size = 9

-- ---- Right status bar (workspace + time + hostname) ----
wezterm.on('update-status', function(window, _)
    local SOLID_LEFT_ARROW = utf8.char(0xe0b2)
    local segments = {
        window:active_workspace(),
        wezterm.strftime('%a %b %-d %H:%M'),
        wezterm.hostname(),
    }

    local color_scheme = window:effective_config().resolved_palette
    local bg = wezterm.color.parse(color_scheme.background)
    local fg = color_scheme.foreground
    local gradient_from = bg:lighten(0.2)

    local gradient = wezterm.color.gradient(
        { orientation = 'Horizontal', colors = { gradient_from, bg } },
        #segments
    )

    local elements = {}
    for i, seg in ipairs(segments) do
        if i == 1 then
            table.insert(elements, { Background = { Color = 'none' } })
        end
        table.insert(elements, { Foreground = { Color = gradient[i] } })
        table.insert(elements, { Text = SOLID_LEFT_ARROW })
        table.insert(elements, { Foreground = { Color = fg } })
        table.insert(elements, { Background = { Color = gradient[i] } })
        table.insert(elements, { Text = ' ' .. seg .. ' ' })
    end

    window:set_right_status(wezterm.format(elements))
end)

-- ---- WSL as default ----
config.default_domain = 'WSL:Ubuntu-24.04'

-- ---- Launch menu (PowerShell, CMD without Windows Terminal) ----
config.launch_menu = {
    { label = ' PowerShell', args = { 'powershell.exe' } },
    { label = ' CMD', args = { 'cmd.exe' } },
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

    -- Command palette (Ctrl+Shift+P, like VS Code)
    { key = 'p', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateCommandPalette },

    -- Launcher with fuzzy search (Alt+L — tabs, domains, launch menu)
    { key = 'l', mods = 'ALT', action = wezterm.action.ShowLauncherArgs {
        flags = 'FUZZY|TABS|LAUNCH_MENU_ITEMS|DOMAINS|WORKSPACES',
    }},

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
