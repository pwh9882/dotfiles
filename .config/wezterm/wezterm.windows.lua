-- WezTerm configuration for Windows (WSL primary)
-- Managed by dotfiles — synced via .config/init.sh on WSL
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ---- Colors (Catppuccin Mocha Focus) ----
local colors = {
    crust    = '#11111b', -- 탭바/상태바 배경 (가장 어두움)
    mantle   = '#181825', -- 비활성 탭 배경
    base     = '#1e1e2e', -- 터미널 메인 배경
    surface0 = '#313244', -- 비활성 탭 숫자 배지 배경
    fg       = '#cdd6f4', -- 기본 텍스트
    fg_dim   = '#a6adc8', -- 어두운 텍스트
    mauve    = '#cba6f7', -- 포인트 컬러 (활성 탭 등)
    sapphire = '#74c7ec',
    green    = '#a6e3a1',
    lavender = '#b4befe',
    yellow   = '#f9e2af',
}

-- ---- Appearance ----
config.color_scheme = 'Github Dark (Gogh)'
config.font = wezterm.font('JetBrainsMonoNL Nerd Font')
config.font_size = 10
config.window_background_opacity = 0.95
config.window_padding = { left = 16, right = 16, top = 16, bottom = 16 }
config.window_decorations = 'RESIZE'

config.use_fancy_tab_bar = false
config.tab_max_width = 30
config.command_palette_font_size = 10
config.warn_about_missing_glyphs = false

-- 커스텀 탭바 색상
config.colors = {
    tab_bar = {
        background = colors.crust,
        active_tab = { bg_color = colors.mantle, fg_color = colors.fg },
        inactive_tab = { bg_color = colors.mantle, fg_color = colors.fg_dim },
        inactive_tab_hover = { bg_color = colors.base, fg_color = colors.fg },
        new_tab = { bg_color = colors.crust, fg_color = colors.fg_dim },
        new_tab_hover = { bg_color = colors.mauve, fg_color = colors.crust },
    },
}

-- ---- Tab title (Color Badge Style) ----
-- 숫자 부분만 배경색 반전 배지, 디렉토리는 별도 배경
wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
    local cwd = tab.active_pane.current_working_dir
    local dir = cwd and (cwd.file_path or tostring(cwd)):match('([^/\\]+)[/\\]?$') or ''
    local idx = tostring(tab.tab_index + 1)

    if tab.is_active then
        return {
            { Background = { Color = colors.mauve } },
            { Foreground = { Color = colors.crust } },
            { Attribute = { Intensity = 'Bold' } },
            { Text = ' ' .. idx .. ' ' },
            { Background = { Color = colors.base } },
            { Foreground = { Color = colors.fg } },
            { Text = ' ' .. dir .. ' ' },
        }
    end
    return {
        { Background = { Color = colors.surface0 } },
        { Foreground = { Color = colors.fg_dim } },
        { Text = ' ' .. idx .. ' ' },
        { Background = { Color = colors.mantle } },
        { Foreground = { Color = colors.fg_dim } },
        { Text = ' ' .. dir .. ' ' },
    }
end)

-- ---- Status bar (Powerline Style) ----
wezterm.on('update-status', function(window, pane)
    local workspace = window:active_workspace():gsub('%c', '')
    local host = wezterm.hostname():gsub('%.[^%.]+$', '')

    local right = {}

    -- Leader indicator (prepend to right status when active)
    if window:leader_is_active() then
        table.insert(right, { Background = { Color = colors.crust } })
        table.insert(right, { Foreground = { Color = colors.yellow } })
        table.insert(right, { Text = '\u{e0b6}' })
        table.insert(right, { Background = { Color = colors.yellow } })
        table.insert(right, { Foreground = { Color = colors.crust } })
        table.insert(right, { Attribute = { Intensity = 'Bold' } })
        table.insert(right, { Text = ' ^A ' })
        table.insert(right, { Background = { Color = colors.sapphire } })
        table.insert(right, { Foreground = { Color = colors.yellow } })
        table.insert(right, { Text = '\u{e0b4}' })
    else
        table.insert(right, { Background = { Color = colors.crust } })
        table.insert(right, { Foreground = { Color = colors.sapphire } })
        table.insert(right, { Text = '\u{e0b6}' })
    end

    -- Workspace
    table.insert(right, { Background = { Color = colors.sapphire } })
    table.insert(right, { Foreground = { Color = colors.crust } })
    table.insert(right, { Attribute = { Intensity = 'Bold' } })
    table.insert(right, { Text = ' \u{f4bc} ' .. workspace .. ' ' })

    -- Time
    table.insert(right, { Background = { Color = colors.green } })
    table.insert(right, { Foreground = { Color = colors.sapphire } })
    table.insert(right, { Text = '\u{e0b4}' })
    table.insert(right, { Background = { Color = colors.green } })
    table.insert(right, { Foreground = { Color = colors.crust } })
    table.insert(right, { Attribute = { Intensity = 'Bold' } })
    table.insert(right, { Text = ' \u{f0350} ' .. wezterm.strftime('%H:%M') .. ' ' })

    -- Host
    table.insert(right, { Background = { Color = colors.lavender } })
    table.insert(right, { Foreground = { Color = colors.green } })
    table.insert(right, { Text = '\u{e0b4}' })
    table.insert(right, { Background = { Color = colors.lavender } })
    table.insert(right, { Foreground = { Color = colors.crust } })
    table.insert(right, { Attribute = { Intensity = 'Bold' } })
    table.insert(right, { Text = ' \u{f048b} ' .. host .. ' ' })

    window:set_right_status(wezterm.format(right))
end)

-- ---- WSL as default ----
config.default_domain = 'WSL:Ubuntu-24.04'

-- ---- Launch menu ----
config.launch_menu = {
    { label = 'PowerShell', args = { 'powershell.exe' }, domain = { DomainName = 'local' } },
    { label = 'CMD', args = { 'cmd.exe' }, domain = { DomainName = 'local' } },
}

-- ---- Key Bindings ----
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
    { key = '"', mods = 'LEADER|SHIFT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '%', mods = 'LEADER|SHIFT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'a', mods = 'LEADER|CTRL', action = wezterm.action.SendKey { key = 'a', mods = 'CTRL' } },

    move_pane('phys:h', 'Left'),
    move_pane('phys:j', 'Down'),
    move_pane('phys:k', 'Up'),
    move_pane('phys:l', 'Right'),
    move_pane('LeftArrow', 'Left'),
    move_pane('DownArrow', 'Down'),
    move_pane('UpArrow', 'Up'),
    move_pane('RightArrow', 'Right'),

    { key = 'r', mods = 'LEADER', action = wezterm.action.ActivateKeyTable {
        name = 'resize_panes', one_shot = false, timeout_milliseconds = 1000,
    }},

    { key = 'LeftArrow', mods = 'CTRL|ALT', action = wezterm.action.ActivateTabRelative(-1) },
    { key = 'RightArrow', mods = 'CTRL|ALT', action = wezterm.action.ActivateTabRelative(1) },
    { key = 'p', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateCommandPalette },
    { key = 'l', mods = 'ALT', action = wezterm.action.ShowLauncherArgs {
        flags = 'FUZZY|TABS|LAUNCH_MENU_ITEMS|DOMAINS|WORKSPACES',
    }},
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
