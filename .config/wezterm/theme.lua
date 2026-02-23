-- theme.lua — Colors, tab badge, status bar, window title
local wezterm = require 'wezterm'
local logic = require 'theme_logic'
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

    local accents = { c.sapphire, c.green, c.lavender, c.peach, c.flamingo, c.yellow }
    local local_host = wezterm.hostname():match('^([^%.]+)') or ''
    local pane_cwd_cache = {}

    local function detect_remote(title, uv)
        return logic.detect_remote(title, uv, local_host)
    end

    -- Tab title (Color Badge Style)
    wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
        local title = tab.active_pane.title or ''

        -- Assign unique badge colors per hostname (hash + collision avoidance)
        -- Also find current tab's host in the same pass
        local host_colors = {}
        local used = {}
        local my_host
        for _, t in ipairs(tabs) do
            local h = detect_remote(t.active_pane.title or '', t.active_pane.user_vars or {})
            if t.tab_id == tab.tab_id then my_host = h end
            if h and not host_colors[h] then
                local idx = logic.hash_idx(h, #accents)
                for _ = 1, #accents do
                    if not used[idx] then break end
                    idx = (idx % #accents) + 1
                end
                used[idx] = true
                host_colors[h] = accents[idx]
            end
        end
        local badge = my_host and host_colors[my_host] or c.mauve

        title = logic.strip_title(title)
        local idx = tostring(tab.tab_index + 1)

        if tab.is_active then
            return {
                { Background = { Color = badge } },
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
            { Foreground = { Color = badge } },
            { Text = ' ' .. idx .. ' ' },
            { Background = { Color = c.mantle } },
            { Foreground = { Color = c.fg_dim } },
            { Text = ' ' .. title .. ' ' },
        }
    end)

    -- Status bar (flat blocks)
    wezterm.on('update-status', function(window, pane)
        local title = pane:get_title() or ''
        local uv = pane:get_user_vars() or {}
        local remote = detect_remote(title, uv)
        local pid = tostring(pane:pane_id())

        local workspace = window:active_workspace():gsub('%c', '')
        local cwd, cache_val = logic.resolve_cwd(
            remote, title, uv, pane_cwd_cache[pid], workspace)
        if cache_val then
            pane_cwd_cache[pid] = cache_val
        elseif not remote then
            pane_cwd_cache[pid] = nil
        end
        cwd = logic.shorten_path(cwd)

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

        -- CWD
        table.insert(right, { Background = { Color = c.surface0 } })
        table.insert(right, { Foreground = { Color = c.fg } })
        table.insert(right, { Attribute = { Intensity = 'Bold' } })
        table.insert(right, { Text = ' \u{eb45} ' .. cwd .. ' ' })

        -- Time
        table.insert(right, { Background = { Color = c.mantle } })
        table.insert(right, { Foreground = { Color = c.fg_dim } })
        table.insert(right, { Attribute = { Intensity = 'Normal' } })
        table.insert(right, { Text = ' ' .. wezterm.strftime('%H:%M') .. ' ' })

        -- Host + OS icon
        local display_host = remote or local_host
        local os_kind = logic.detect_os(remote, title, uv, is_macos)
        local os_icon = os_kind == 'darwin' and '\u{f0035}' or '\u{f17c}'
        if remote then
            local host_color = accents[logic.hash_idx(remote, #accents)]
            table.insert(right, { Background = { Color = host_color } })
            table.insert(right, { Foreground = { Color = c.crust } })
        else
            table.insert(right, { Background = { Color = c.surface0 } })
            table.insert(right, { Foreground = { Color = c.fg } })
        end
        table.insert(right, { Attribute = { Intensity = 'Bold' } })
        table.insert(right, { Text = ' ' .. os_icon .. ' ' .. display_host .. ' ' })

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
