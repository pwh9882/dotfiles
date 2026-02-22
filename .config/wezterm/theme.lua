-- theme.lua — Colors, tab badge, status bar, window title
local wezterm = require 'wezterm'
local M = {}

-- ---- Catppuccin Mocha palette ----
M.colors = {
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

function M.apply(config)
    local c = M.colors

    -- Tab bar colors
    config.colors = {
        foreground = '#e6edf3',
        tab_bar = {
            background = c.crust,
            active_tab = { bg_color = c.mantle, fg_color = c.fg },
            inactive_tab = { bg_color = c.mantle, fg_color = c.fg_dim },
            inactive_tab_hover = { bg_color = c.base, fg_color = c.fg },
            new_tab = { bg_color = c.crust, fg_color = c.fg_dim },
            new_tab_hover = { bg_color = c.mauve, fg_color = c.crust },
        },
    }

    -- Tab title (Color Badge Style)
    wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
        local cwd = tab.active_pane.current_working_dir
        local dir = cwd and (cwd.file_path or tostring(cwd)):match('([^/\\]+)[/\\]?$') or ''
        local idx = tostring(tab.tab_index + 1)

        if tab.is_active then
            return {
                { Background = { Color = c.mauve } },
                { Foreground = { Color = c.crust } },
                { Attribute = { Intensity = 'Bold' } },
                { Text = ' ' .. idx .. ' ' },
                { Background = { Color = c.base } },
                { Foreground = { Color = c.fg } },
                { Text = ' ' .. dir .. ' ' },
            }
        end
        return {
            { Background = { Color = c.surface0 } },
            { Foreground = { Color = c.fg_dim } },
            { Text = ' ' .. idx .. ' ' },
            { Background = { Color = c.mantle } },
            { Foreground = { Color = c.fg_dim } },
            { Text = ' ' .. dir .. ' ' },
        }
    end)

    -- Status bar (Powerline + Leader)
    wezterm.on('update-status', function(window, pane)
        local workspace = window:active_workspace():gsub('%c', '')
        local host = wezterm.hostname():gsub('%.[^%.]+$', '')

        local right = {}

        -- Leader indicator
        if window:leader_is_active() then
            table.insert(right, { Background = { Color = c.crust } })
            table.insert(right, { Foreground = { Color = c.yellow } })
            table.insert(right, { Text = '\u{e0b6}' })
            table.insert(right, { Background = { Color = c.yellow } })
            table.insert(right, { Foreground = { Color = c.crust } })
            table.insert(right, { Attribute = { Intensity = 'Bold' } })
            table.insert(right, { Text = ' ^A ' })
            table.insert(right, { Background = { Color = c.sapphire } })
            table.insert(right, { Foreground = { Color = c.yellow } })
            table.insert(right, { Text = '\u{e0b4}' })
        else
            table.insert(right, { Background = { Color = c.crust } })
            table.insert(right, { Foreground = { Color = c.sapphire } })
            table.insert(right, { Text = '\u{e0b6}' })
        end

        -- Workspace
        table.insert(right, { Background = { Color = c.sapphire } })
        table.insert(right, { Foreground = { Color = c.crust } })
        table.insert(right, { Attribute = { Intensity = 'Bold' } })
        table.insert(right, { Text = ' \u{f4bc} ' .. workspace .. ' ' })

        -- Time
        table.insert(right, { Background = { Color = c.green } })
        table.insert(right, { Foreground = { Color = c.sapphire } })
        table.insert(right, { Text = '\u{e0b4}' })
        table.insert(right, { Background = { Color = c.green } })
        table.insert(right, { Foreground = { Color = c.crust } })
        table.insert(right, { Attribute = { Intensity = 'Bold' } })
        table.insert(right, { Text = ' \u{f0350} ' .. wezterm.strftime('%H:%M') .. ' ' })

        -- Host
        table.insert(right, { Background = { Color = c.lavender } })
        table.insert(right, { Foreground = { Color = c.green } })
        table.insert(right, { Text = '\u{e0b4}' })
        table.insert(right, { Background = { Color = c.lavender } })
        table.insert(right, { Foreground = { Color = c.crust } })
        table.insert(right, { Attribute = { Intensity = 'Bold' } })
        table.insert(right, { Text = ' \u{f048b} ' .. host .. ' ' })

        window:set_right_status(wezterm.format(right))
    end)

    -- Window title
    wezterm.on("format-window-title", function(tab, pane, tabs, panes, config)
        local zoomed = tab.active_pane.is_zoomed and " " or ""
        local index = #tabs > 1 and string.format("(%d/%d) ", tab.tab_index + 1, #tabs) or ""
        return zoomed .. index .. tab.active_pane.title
    end)
end

return M
