-- WezTerm configuration for Windows (WSL primary)
-- Managed by dotfiles — synced via .config/init.sh on WSL
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ---- Appearance ----
config.color_scheme = 'Github Dark (Gogh)'
config.colors = {
    foreground = '#e6edf3',
    tab_bar = {
        background = '#0d1117',
        active_tab = {
            bg_color = '#1f6feb',
            fg_color = '#f0f6fc',
            intensity = 'Bold',
        },
        inactive_tab = {
            bg_color = '#161b22',
            fg_color = '#8b949e',
        },
        inactive_tab_hover = {
            bg_color = '#21262d',
            fg_color = '#c9d1d9',
        },
        new_tab = {
            bg_color = '#0d1117',
            fg_color = '#8b949e',
        },
        new_tab_hover = {
            bg_color = '#21262d',
            fg_color = '#c9d1d9',
        },
    },
}
config.font = wezterm.font('JetBrainsMonoNL Nerd Font')
config.font_size = 9
config.window_background_opacity = 0.9

-- No system title bar — tab bar doubles as title bar (same as Mac)
config.window_decorations = 'RESIZE'
config.window_frame = {
    font = wezterm.font({ family = 'JetBrainsMonoNL Nerd Font', weight = 'Bold' }),
    font_size = 8,
    active_titlebar_bg = '#0d1117',
    inactive_titlebar_bg = '#0d1117',
}
config.use_fancy_tab_bar = true
config.tab_max_width = 32
config.command_palette_font_size = 9
config.char_select_font_size = 9
-- Command palette internally renders ESC key labels as literal U+001B glyphs,
-- which no font contains. This is a known WezTerm issue, not a config problem.
-- https://github.com/wez/wezterm/issues/6591
config.warn_about_missing_glyphs = false

-- ---- Tab title: icon + directory name ----
local process_icons = {
    ['zsh']        = ' ',
    ['bash']       = ' ',
    ['fish']       = '󰈺 ',
    ['nvim']       = ' ',
    ['vim']        = ' ',
    ['node']       = '󰎙 ',
    ['python']     = '󰌠 ',
    ['python3']    = '󰌠 ',
    ['git']        = '󰊢 ',
    ['ssh']        = '󰣀 ',
    ['claude']     = '󰚩 ',
    ['docker']     = '󰡨 ',
    ['cargo']      = '󱘗 ',
    ['go']         = '󰟓 ',
    ['lazygit']    = ' ',
    ['htop']       = '󰍛 ',
    ['btop']       = '󰍛 ',
    ['tmux']       = ' ',
    ['powershell'] = '󰨊 ',
    ['cmd']        = ' ',
}

local function get_process_icon(tab)
    local name = tab.active_pane.foreground_process_name or ''
    local process = name:match('([^/\\]+)$') or ''
    process = process:gsub('%.exe$', ''):gsub('%c', '')
    return process_icons[process] or '󰞷 '
end

local function get_directory(tab)
    local cwd = tab.active_pane.current_working_dir
    if cwd then
        local path = cwd.file_path or tostring(cwd)
        -- Show last directory component
        local dir = path:match('([^/\\]+)[/\\]?$') or path
        return dir
    end
    return ''
end

wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
    local icon = get_process_icon(tab)
    local dir = get_directory(tab)
    local title = icon .. dir

    -- Truncate if needed
    if #title > max_width - 2 then
        title = wezterm.truncate_right(title, max_width - 3) .. '…'
    end

    return ' ' .. title .. ' '
end)

-- ---- Right status bar (powerline: workspace + time + hostname) ----
wezterm.on('update-status', function(window, pane)
    local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

    -- Left status: leader indicator
    local leader = ''
    if window:leader_is_active() then
        leader = wezterm.format {
            { Foreground = { Color = '#1f6feb' } },
            { Text = '  LEADER ' },
        }
    end
    window:set_left_status(leader)

    -- Right status: workspace + time + hostname
    -- gsub: strip any control characters that might leak into display
    local workspace = window:active_workspace():gsub('%c', '')
    local host = wezterm.hostname():gsub('%c', '')
    local segments = {
        { text = ' ' .. workspace, color = '#1f6feb' },
        { text = '󰃰 ' .. wezterm.strftime('%H:%M'), color = '#238636' },
        { text = '󰒋 ' .. host, color = '#8957e5' },
    }

    local elements = {}
    for i, seg in ipairs(segments) do
        if i == 1 then
            table.insert(elements, { Background = { Color = 'none' } })
        end
        table.insert(elements, { Foreground = { Color = seg.color } })
        table.insert(elements, { Text = SOLID_LEFT_ARROW })
        table.insert(elements, { Foreground = { Color = '#f0f6fc' } })
        table.insert(elements, { Background = { Color = seg.color } })
        table.insert(elements, { Text = ' ' .. seg.text .. ' ' })
    end

    window:set_right_status(wezterm.format(elements))
end)

-- ---- WSL as default ----
config.default_domain = 'WSL:Ubuntu-24.04'

-- ---- Launch menu (PowerShell, CMD without Windows Terminal) ----
config.launch_menu = {
    { label = '󰨊 PowerShell', args = { 'powershell.exe' }, domain = { DomainName = 'local' } },
    { label = ' CMD', args = { 'cmd.exe' }, domain = { DomainName = 'local' } },
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
