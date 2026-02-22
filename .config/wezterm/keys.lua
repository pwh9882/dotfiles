-- keys.lua — Keybindings (shared + platform-specific, excluding plugins)
local wezterm = require 'wezterm'
local M = {}

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

function M.apply(config, is_macos)
    -- Leader key
    config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

    -- Shared keybindings
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

        -- tmux prefix indicator (Ctrl+B → pass through + show badge)
        { key = 'b', mods = 'CTRL', action = wezterm.action.Multiple({
            wezterm.action.SendKey { key = 'b', mods = 'CTRL' },
            wezterm.action.ActivateKeyTable {
                name = 'tmux_prefix', timeout_milliseconds = 2000,
            },
        })},
    }

    -- Platform-specific keybindings
    if is_macos then
        -- Pane splits
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
        local projects_ok, projects = pcall(require, 'projects')
        if projects_ok then
            table.insert(config.keys, { key = 'p', mods = 'LEADER', action = projects.choose_project() })
        end
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

    -- Key tables (shared)
    config.key_tables = {
        resize_panes = {
            resize_pane('j', 'Down'),
            resize_pane('k', 'Up'),
            resize_pane('h', 'Left'),
            resize_pane('l', 'Right'),
        },
        tmux_prefix = {},  -- empty: all keys pass through to tmux, badge shown until timeout
    }
end

return M
