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

    -- Shorten path: ~/projects/myapp/src → ~/p/m/src
    local function shorten_path(path)
        local parts = {}
        for seg in path:gmatch('[^/]+') do table.insert(parts, seg) end
        if #parts <= 1 then return path end
        local prefix = path:sub(1, 1) == '/' and '/' or ''
        for i = 1, #parts - 1 do
            if parts[i] ~= '~' then
                parts[i] = parts[i]:sub(1, 1)
            end
        end
        return prefix .. table.concat(parts, '/')
    end

    local accents = { c.sapphire, c.green, c.lavender, c.peach, c.flamingo, c.yellow }
    local local_host = wezterm.hostname():match('^([^%.]+)') or ''
    local pane_cwd_cache = {}

    -- Detect remote hostname from title + user_vars (nil = local)
    --   1) title patterns: "host ❐ ..." (Oh My Tmux), "user@host[: ...]" (Linux SSH)
    --   2) user_vars.WEZTERM_HOST fallback (macOS SSH where title has no hostname)
    local function detect_remote(title, uv)
        local h = title:match('^(%S+)%s+❐')
              or title:match('^%S+@([%w%-%._]+)')
        if h and h ~= local_host then return h end
        h = uv and uv.WEZTERM_HOST or nil
        if h and h ~= '' and h ~= local_host then return h end
        return nil
    end

    local function hash_idx(s)
        local h = 0
        for i = 1, #s do h = h + string.byte(s, i) end
        return (h % #accents) + 1
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
                local idx = hash_idx(h)
                for _ = 1, #accents do
                    if not used[idx] then break end
                    idx = (idx % #accents) + 1
                end
                used[idx] = true
                host_colors[h] = accents[idx]
            end
        end
        local badge = my_host and host_colors[my_host] or c.mauve

        -- Strip hostname prefixes from title
        title = title:gsub('^%S+%s+❐%s*', '')           -- Oh My Tmux: #h ❐ #S ● #I #W
        title = title:gsub('^%S+@[%w%-%._]+[:%s]*', '') -- SSH shell: user@host[: path]
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
        local cwd

        if remote then
            -- 1) Title path extraction (most reliable: user@host: /path)
            cwd = title:match('^%S+@[%w%-%._]+:%s*(.+)')
            -- 2) Fallback: WEZTERM_CWD if host matches (macOS SSH with dotfiles)
            if not cwd or cwd == '' then
                local uv_host = uv.WEZTERM_HOST or ''
                if uv_host == remote and uv.WEZTERM_CWD and uv.WEZTERM_CWD ~= '' then
                    cwd = uv.WEZTERM_CWD
                end
            end
            -- 3) Cache for tmux etc. where title changes and path disappears
            if cwd and cwd ~= '' then
                pane_cwd_cache[pid] = cwd
            else
                cwd = pane_cwd_cache[pid]
            end
        else
            cwd = uv.WEZTERM_CWD
            pane_cwd_cache[pid] = nil
        end

        if not cwd or cwd == '' then
            cwd = remote or window:active_workspace():gsub('%c', '')
        end
        cwd = shorten_path(cwd)

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

        -- Host + OS icon (reuse remote/title/uv from above)
        local display_host = remote or local_host
        local os_icon
        if remote then
            if title:match('^%S+@[%w%-%._]+:') then
                -- "user@host:" title format is Linux-only
                os_icon = '\u{f17c}'
            else
                os_icon = (uv.WEZTERM_OS or '') == 'Darwin' and '\u{f0035}' or '\u{f17c}'
            end
            local host_color = accents[hash_idx(remote)]
            table.insert(right, { Background = { Color = host_color } })
            table.insert(right, { Foreground = { Color = c.crust } })
        else
            os_icon = is_macos and '\u{f0035}' or '\u{f17c}'
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
