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
    peach    = '#fab387',
    flamingo = '#f2cdcd',
}

function M.apply(config, is_macos)
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
        local title = tab.active_pane.title or ''
        -- Strip hostname (already shown in status bar)
        title = title:gsub('^%S+%s+❐%s*', '')  -- Oh My Tmux: #h ❐ #S ● #I #W
        title = title:gsub('^%S+@%S+:%s*', '')  -- SSH shell: user@host: path
        local idx = tostring(tab.tab_index + 1)

        if tab.is_active then
            return {
                { Background = { Color = c.mauve } },
                { Foreground = { Color = c.crust } },
                { Attribute = { Intensity = 'Bold' } },
                { Text = ' ' .. idx .. ' ' },
                { Background = { Color = c.base } },
                { Foreground = { Color = c.fg } },
                { Text = ' ' .. title .. ' ' },
            }
        end
        return {
            { Background = { Color = c.surface0 } },
            { Foreground = { Color = c.fg_dim } },
            { Text = ' ' .. idx .. ' ' },
            { Background = { Color = c.mantle } },
            { Foreground = { Color = c.fg_dim } },
            { Text = ' ' .. title .. ' ' },
        }
    end)

    -- Status bar (flat blocks)
    wezterm.on('update-status', function(window, pane)
        local workspace = window:active_workspace():gsub('%c', '')
        local host = wezterm.hostname():gsub('%.[^%.]+$', '')

        local right = {}

        -- Mode indicator (leader / key table)
        local key_table = window:active_key_table()
        local mode_labels = {
            tmux_prefix  = { text = ' ^B ',     color = c.flamingo },
            resize_panes = { text = ' RESIZE ', color = c.peach },
        }

        if window:leader_is_active() then
            table.insert(right, { Background = { Color = c.yellow } })
            table.insert(right, { Foreground = { Color = c.crust } })
            table.insert(right, { Attribute = { Intensity = 'Bold' } })
            table.insert(right, { Text = ' ^A ' })
        elseif key_table and mode_labels[key_table] then
            local mode = mode_labels[key_table]
            table.insert(right, { Background = { Color = mode.color } })
            table.insert(right, { Foreground = { Color = c.crust } })
            table.insert(right, { Attribute = { Intensity = 'Bold' } })
            table.insert(right, { Text = mode.text })
        end

        -- Workspace
        table.insert(right, { Background = { Color = c.surface0 } })
        table.insert(right, { Foreground = { Color = c.fg } })
        table.insert(right, { Attribute = { Intensity = 'Bold' } })
        table.insert(right, { Text = ' \u{eb45} ' .. workspace .. ' ' })

        -- Time
        table.insert(right, { Background = { Color = c.mantle } })
        table.insert(right, { Foreground = { Color = c.fg_dim } })
        table.insert(right, { Attribute = { Intensity = 'Normal' } })
        table.insert(right, { Text = ' ' .. wezterm.strftime('%H:%M') .. ' ' })

        -- Host (OS icon)
        local os_icon = is_macos and '\u{f0035}' or '\u{f17c}'
        table.insert(right, { Background = { Color = c.surface0 } })
        table.insert(right, { Foreground = { Color = c.fg } })
        table.insert(right, { Attribute = { Intensity = 'Bold' } })
        table.insert(right, { Text = ' ' .. os_icon .. ' ' .. host .. ' ' })

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
