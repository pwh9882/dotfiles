-- WezTerm unified configuration (macOS + Windows)
-- Managed by dotfiles — on WSL, synced to Windows via .config/init.sh
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ---- Platform Detection ----
local is_windows = wezterm.target_triple:find('-windows-') ~= nil
local is_macos   = wezterm.target_triple:find('-apple-')   ~= nil

-- ---- Optional Modules (macOS only, missing on Windows) ----
local _, appearance = pcall(require, 'appearance')
local projects_ok, projects = pcall(require, 'projects')

-- ---- Optional Plugins (macOS only) ----
local resurrect, workspace_switcher
if is_macos then
    resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
    workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
end

-- ---- Colors (Catppuccin Mocha) ----
local colors = {
    crust    = '#11111b',
    mantle   = '#181825',
    base     = '#1e1e2e',
    surface0 = '#313244',
    fg       = '#cdd6f4',
    fg_dim   = '#a6adc8',
    mauve    = '#cba6f7',
    sapphire = '#74c7ec',
    green    = '#a6e3a1',
    lavender = '#b4befe',
    yellow   = '#f9e2af',
}

-- ---- Notification helper ----
local function toast(window, message)
    window:toast_notification('wezterm', message .. ' - ' .. os.date('%I:%M:%S %p'), nil, 1000)
end

-- ---- Appearance ----
config.color_scheme = 'Github Dark (Gogh)'
config.font = wezterm.font('JetBrainsMonoNL Nerd Font')
config.window_padding = { left = 16, right = 16, top = 16, bottom = 16 }
config.window_decorations = 'RESIZE'

config.use_fancy_tab_bar = false
config.tab_max_width = 30
config.warn_about_missing_glyphs = false

if is_macos then
    config.font_size = 13
    config.window_background_opacity = 0.85
    config.macos_window_background_blur = 30
    config.set_environment_variables = {
        PATH = '/opt/homebrew/bin:' .. os.getenv('PATH')
    }
else
    config.font_size = 10
    config.window_background_opacity = 0.95
    config.command_palette_font_size = 10
end

-- ---- Tab bar colors ----
config.colors = {
    foreground = '#e6edf3',
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

-- ---- Status bar (Powerline + Leader) ----
wezterm.on('update-status', function(window, pane)
    local workspace = window:active_workspace():gsub('%c', '')
    local host = wezterm.hostname():gsub('%.[^%.]+$', '')

    local right = {}

    -- Leader indicator
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

-- ---- Window title ----
wezterm.on("format-window-title", function(tab, pane, tabs, panes, config)
    local zoomed = tab.active_pane.is_zoomed and " " or ""
    local index = #tabs > 1 and string.format("(%d/%d) ", tab.tab_index + 1, #tabs) or ""
    return zoomed .. index .. tab.active_pane.title
end)

-- ---- Helper functions ----
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

-- ---- Leader key ----
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

-- ---- Keybindings (shared) ----
config.keys = {
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

    { key = 'Enter', mods = 'SHIFT', action = wezterm.action { SendString = "\x1b\r" } },
}

-- ---- Keybindings (macOS) ----
if is_macos then
    -- Pane splits (LEADER only on macOS)
    table.insert(config.keys, { key = '"', mods = 'LEADER', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } })
    table.insert(config.keys, { key = '%', mods = 'LEADER', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } })

    -- Word/line navigation
    table.insert(config.keys, { key = 'LeftArrow', mods = 'OPT', action = wezterm.action.SendString '\x1bb' })
    table.insert(config.keys, { key = 'RightArrow', mods = 'OPT', action = wezterm.action.SendString '\x1bf' })
    table.insert(config.keys, { mods = 'CMD', key = 'LeftArrow', action = wezterm.action.SendKey({ mods = 'CTRL', key = 'a' }) })
    table.insert(config.keys, { mods = 'CMD', key = 'RightArrow', action = wezterm.action.SendKey({ mods = 'CTRL', key = 'e' }) })
    table.insert(config.keys, { mods = 'CMD', key = 'Backspace', action = wezterm.action.SendKey({ mods = 'CTRL', key = 'u' }) })

    -- Tab navigation
    table.insert(config.keys, { mods = 'CMD|ALT', key = 'LeftArrow', action = wezterm.action.ActivateTabRelative(-1) })
    table.insert(config.keys, { mods = 'CMD|ALT', key = 'RightArrow', action = wezterm.action.ActivateTabRelative(1) })

    -- Open config in nvim
    table.insert(config.keys, { key = ',', mods = 'SUPER', action = wezterm.action.SpawnCommandInNewTab {
        cwd = wezterm.home_dir, args = { 'nvim', wezterm.config_file },
    }})

    -- Project picker
    if projects_ok then
        table.insert(config.keys, { key = 'p', mods = 'LEADER', action = projects.choose_project() })
    end

    -- Workspace switcher
    if workspace_switcher then
        table.insert(config.keys, { key = 'f', mods = 'LEADER', action = workspace_switcher.switch_workspace() })
        table.insert(config.keys, { key = 's', mods = 'LEADER', action = workspace_switcher.switch_workspace() })
        table.insert(config.keys, { key = 'S', mods = 'LEADER', action = workspace_switcher.switch_to_prev_workspace() })
    end

    -- Resurrect keybindings
    if resurrect then
        table.insert(config.keys, { key = 'w', mods = 'ALT', action = wezterm.action_callback(function(win, pane)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
        end)})
        table.insert(config.keys, { key = 'W', mods = 'ALT', action = resurrect.window_state.save_window_action() })
        table.insert(config.keys, { key = 'T', mods = 'ALT', action = resurrect.tab_state.save_tab_action() })
        table.insert(config.keys, { key = 's', mods = 'ALT', action = wezterm.action_callback(function(win, pane)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
            resurrect.window_state.save_window_action()
        end)})
        table.insert(config.keys, { key = 'o', mods = 'ALT', action = wezterm.action_callback(function(win, pane)
            resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
                local type = string.match(id, "^([^/]+)")
                id = string.match(id, "([^/]+)$")
                id = string.match(id, "(.+)%..+$")
                local opts = {
                    relative = true,
                    restore_text = true,
                    close_open_tabs = true,
                    on_pane_restore = resurrect.tab_state.default_on_pane_restore,
                }
                if type == "workspace" then
                    local state = resurrect.state_manager.load_state(id, "workspace")
                    resurrect.workspace_state.restore_workspace(state, opts)
                elseif type == "window" then
                    local state = resurrect.state_manager.load_state(id, "window")
                    resurrect.window_state.restore_window(pane:window(), state, opts)
                elseif type == "tab" then
                    local state = resurrect.state_manager.load_state(id, "tab")
                    resurrect.tab_state.restore_tab(pane:tab(), state, opts)
                end
            end)
        end)})
        table.insert(config.keys, { key = 'd', mods = 'ALT', action = wezterm.action_callback(function(win, pane)
            resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id)
                    resurrect.state_manager.delete_state(id)
                end,
                {
                    title = "Delete State",
                    description = "Select State to Delete and press Enter = accept, Esc = cancel, / = filter",
                    fuzzy_description = "Search State to Delete: ",
                    is_fuzzy = true,
                })
        end)})
    end

-- ---- Keybindings (Windows) ----
else
    -- Pane splits (LEADER|SHIFT needed on Windows)
    table.insert(config.keys, { key = '"', mods = 'LEADER|SHIFT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } })
    table.insert(config.keys, { key = '%', mods = 'LEADER|SHIFT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } })

    -- Tab navigation
    table.insert(config.keys, { key = 'LeftArrow', mods = 'CTRL|ALT', action = wezterm.action.ActivateTabRelative(-1) })
    table.insert(config.keys, { key = 'RightArrow', mods = 'CTRL|ALT', action = wezterm.action.ActivateTabRelative(1) })

    -- Command palette & launcher
    table.insert(config.keys, { key = 'p', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateCommandPalette })
    table.insert(config.keys, { key = 'l', mods = 'ALT', action = wezterm.action.ShowLauncherArgs {
        flags = 'FUZZY|TABS|LAUNCH_MENU_ITEMS|DOMAINS|WORKSPACES',
    }})
end

-- ---- Key tables (shared) ----
config.key_tables = {
    resize_panes = {
        resize_pane('j', 'Down'),
        resize_pane('k', 'Up'),
        resize_pane('h', 'Left'),
        resize_pane('l', 'Right'),
    },
}

-- ======== macOS-only: Plugin event handlers & configuration ========
if is_macos and workspace_switcher and resurrect then
    wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
        local base_path = string.gsub(path, "(.*[/\\])(.*)", "%2")
        local gui_window = window:gui_window()
        if gui_window then
            gui_window:set_right_status(wezterm.format({
                { Attribute = { Intensity = "Bold" } },
                { Foreground = { Color = "magenta" } },
                { Text = base_path .. "  " },
            }))
        end
        local state = resurrect.state_manager.load_state(label, "workspace")
        if state then
            resurrect.workspace_state.restore_workspace(state, {
                window = window,
                relative = true,
                restore_text = true,
                resize_window = false,
                close_open_tabs = true,
                on_pane_restore = resurrect.tab_state.default_on_pane_restore,
            })
        else
            local tab = window:active_tab()
            local pane = tab:active_pane()
            pane:send_text("cd " .. path .. "\n")
        end
    end)

    wezterm.on("smart_workspace_switcher.workspace_switcher.chosen", function(window, path, label)
        local base_path = string.gsub(path, "(.*[/\\])(.*)", "%2")
        local gui_window = window:gui_window()
        if gui_window then
            gui_window:set_right_status(wezterm.format({
                { Attribute = { Intensity = "Bold" } },
                { Foreground = { Color = "magenta" } },
                { Text = base_path .. "  " },
            }))
        end
    end)

    wezterm.on("smart_workspace_switcher.workspace_switcher.selected", function(window, path, label)
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
        resurrect.state_manager.write_current_state(label, "workspace")
    end)

    wezterm.on("augment-command-palette", function(window, pane)
        return {
            {
                brief = "Window | Workspace: Switch Workspace",
                icon = "md_briefcase_arrow_up_down",
                action = workspace_switcher.switch_workspace(),
            },
            {
                brief = "Window | Workspace: Switch to Previous Workspace",
                icon = "md_briefcase_restore",
                action = workspace_switcher.switch_to_prev_workspace(),
            },
            {
                brief = "Window | Workspace: Rename Workspace",
                icon = "md_briefcase_edit",
                action = wezterm.action.PromptInputLine({
                    description = "Enter new name for workspace",
                    action = wezterm.action_callback(function(window, pane, line)
                        if line then
                            wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
                            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
                        end
                    end),
                }),
            },
        }
    end)

    wezterm.on("smart_workspace_switcher.workspace_switcher.start", function(window)
        local current_workspace = wezterm.mux.get_active_workspace()
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state(), current_workspace)
        resurrect.state_manager.write_current_state(current_workspace, "workspace")

        local tab = window:active_tab()
        if tab then
            local pane = tab:active_pane()
            if pane and projects_ok and projects.record_current_as_recent then
                pcall(function() projects.record_current_as_recent(pane) end)
            end
        end
    end)

    wezterm.on("smart_workspace_switcher.workspace_switcher.canceled", function(window)
        wezterm.log_info("Workspace switching canceled")
    end)

    -- Resurrect configuration
    resurrect.state_manager.periodic_save({
        interval_seconds = 15 * 60,
        save_workspaces = true,
        save_windows = true,
        save_tabs = true,
    })
    wezterm.on("gui-startup", resurrect.state_manager.resurrect_on_gui_startup)
    resurrect.state_manager.set_max_nlines(1000)

    wezterm.on("resurrect.error", function(err)
        wezterm.log_error("Resurrect error: " .. err)
        local windows = wezterm.gui.gui_windows()
        if #windows > 0 then
            windows[1]:toast_notification("Resurrect", err, nil, 3000)
        end
    end)

    -- Workspace switcher configuration
    workspace_switcher.workspace_formatter = function(label)
        return wezterm.format({
            { Attribute = { Italic = true } },
            { Foreground = { Color = "green" } },
            { Text = "󱂬 : " .. label },
        })
    end
    config.default_workspace = "~"
    workspace_switcher.apply_to_config(config)
end

-- ======== macOS-only: SSH domains ========
if is_macos then
    config.ssh_domains = {
        {
            name = 'ddps',
            remote_address = 'ddpssrv1.ddps.cloud:33021',
            username = 'whpark',
            ssh_option = { identityfile = '~/.ssh/ddps-srv-1_ed25519' },
            connect_automatically = false,
        },
        {
            name = 'ddps0',
            remote_address = 'srv2.ddps.cloud:33022',
            username = 'whpark',
            ssh_option = { identityfile = '~/.ssh/ddps-srv-1_ed25519' },
            connect_automatically = false,
        },
        {
            name = 'norm',
            remote_address = 'normalize.duckdns.org',
            ssh_option = { identityfile = '/Users/woohyeok/local/oracleA1/ssh-key-2024-09-04.key' },
            username = 'ubuntu',
        },
        {
            name = 'mini-ts',
            remote_address = '100.74.23.65',
            username = 'woohyeok',
            remote_wezterm_path = '/opt/homebrew/bin/wezterm',
        },
        {
            name = 'uci-gpu',
            remote_address = '100.114.244.128',
            username = 'hyunwooo',
        },
    }
end

-- ======== Windows-only: WSL domain & launch menu ========
if is_windows then
    config.default_domain = 'WSL:Ubuntu-24.04'
    config.launch_menu = {
        { label = 'PowerShell', args = { 'powershell.exe' }, domain = { DomainName = 'local' } },
        { label = 'CMD', args = { 'cmd.exe' }, domain = { DomainName = 'local' } },
    }
end

return config
