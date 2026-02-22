-- WezTerm configuration for Windows (WSL primary)
-- Managed by dotfiles — synced via .config/init.sh on WSL
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ---- Colors (Catppuccin Mocha Focus) ----
-- 기존 Github Dark 대신 탭바와 상태바의 색상 대비를 극대화
local colors = {
    crust    = '#11111b', -- 탭바/상태바 배경 (가장 어두움)
    bg       = '#1e1e2e', -- 터미널 메인 배경
    bg_tab   = '#181825', -- 비활성 탭 배경
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
-- 모던한 느낌을 주는 가장 중요한 요소 중 하나인 윈도우 여백 추가
config.window_padding = { left = 16, right = 16, top = 16, bottom = 16 }
config.window_decorations = 'RESIZE'

config.use_fancy_tab_bar = false
config.tab_max_width = 30
config.command_palette_font_size = 10
config.warn_about_missing_glyphs = false

-- 커스텀 탭바 색상 적용
config.colors = {
    tab_bar = {
        background = colors.crust,
        active_tab = { bg_color = colors.mauve, fg_color = colors.crust },
        inactive_tab = { bg_color = colors.bg_tab, fg_color = colors.fg_dim },
        inactive_tab_hover = { bg_color = colors.bg, fg_color = colors.fg },
        new_tab = { bg_color = colors.crust, fg_color = colors.fg_dim },
        new_tab_hover = { bg_color = colors.mauve, fg_color = colors.crust },
    },
}

-- ---- Tab title (Circled Numbers: ①②③ → ❶❷❸) ----
local circled = {'①','②','③','④','⑤','⑥','⑦','⑧'}
local filled  = {'❶','❷','❸','❹','❺','❻','❼','❽'}
wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
    local cwd = tab.active_pane.current_working_dir
    local dir = cwd and (cwd.file_path or tostring(cwd)):match('([^/\\]+)[/\\]?$') or ''
    local idx = tab.tab_index + 1
    local is_last = tab.tab_index == #tabs - 1
    local num
    if idx <= 8 then
        num = tab.is_active and filled[idx] or circled[idx]
    elseif is_last then
        num = tab.is_active and '❾' or '⑨'
    else
        num = tab.is_active and '\u{f192}' or '\u{f10c}'
    end
    local gap = tab.is_active and idx <= 8 and '  ' or ' '
    local title = ' ' .. num .. gap .. dir .. ' '

    if tab.is_active then
        return {
            { Background = { Color = colors.mauve } },
            { Foreground = { Color = colors.crust } },
            { Attribute = { Intensity = 'Bold' } },
            { Text = title },
        }
    end
    return {
        { Background = { Color = colors.bg_tab } },
        { Foreground = { Color = colors.fg_dim } },
        { Text = title },
    }
end)

-- ---- Status bar (Powerline Style Integration) ----
wezterm.on('update-status', function(window, pane)
    -- Left: Leader Key
    if window:leader_is_active() then
        window:set_left_status(wezterm.format {
            { Background = { Color = colors.yellow } },
            { Foreground = { Color = colors.crust } },
            { Attribute = { Intensity = 'Bold' } },
            { Text = ' 󰠠 LDR ' },
            { Background = { Color = colors.crust } },
            { Foreground = { Color = colors.yellow } },
            { Text = '' },
        })
    else
        window:set_left_status('')
    end

    -- Right: Workspace < Time < Host (Powerline style blocks)
    local workspace = window:active_workspace():gsub('%c', '')
    local host = wezterm.hostname():gsub('%.[^%.]+$', '') -- 호스트명 짧게 표시

    window:set_right_status(wezterm.format {
        -- Workspace
        { Background = { Color = colors.crust } },
        { Foreground = { Color = colors.sapphire } },
        { Text = '' },
        { Background = { Color = colors.sapphire } },
        { Foreground = { Color = colors.crust } },
        { Attribute = { Intensity = 'Bold' } },
        { Text = '  ' .. workspace .. ' ' },

        -- Time
        { Background = { Color = colors.sapphire } },
        { Foreground = { Color = colors.green } },
        { Text = '' },
        { Background = { Color = colors.green } },
        { Foreground = { Color = colors.crust } },
        { Attribute = { Intensity = 'Bold' } },
        { Text = ' 󰃰 ' .. wezterm.strftime('%H:%M') .. ' ' },

        -- Host
        { Background = { Color = colors.green } },
        { Foreground = { Color = colors.lavender } },
        { Text = '' },
        { Background = { Color = colors.lavender } },
        { Foreground = { Color = colors.crust } },
        { Attribute = { Intensity = 'Bold' } },
        { Text = ' 󰒋 ' .. host .. ' ' },
    })
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
    { key = '"', mods = 'LEADER', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '%', mods = 'LEADER', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
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