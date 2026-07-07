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
    local host_color_map = {
        ['ddps'] = c.sapphire,
        ['ddps0'] = c.green,
        ['ddps-srv-1'] = c.sapphire,
        ['ddps-srv-2'] = c.green,
        ['wini'] = c.lavender,
        ['mini-ts'] = c.peach,
        ['uci-gpu'] = c.flamingo,
        ['norm'] = c.yellow,
        ['woopc'] = c.green,
    }
    local host_os_map = {
        ['ddps'] = 'linux',
        ['ddps0'] = 'linux',
        ['ddps-srv-1'] = 'linux',
        ['ddps-srv-2'] = 'linux',
        ['norm'] = 'linux',
        ['uci-gpu'] = 'linux',
        ['wini'] = 'darwin',
        ['mini-ts'] = 'darwin',
        ['woopc'] = 'linux',
    }
    local local_host = wezterm.hostname():match('^([^%.]+)') or ''
    local pane_cwd_cache = {}
    local pane_host_cache = {}
    local pane_os_cache = {}
    local mode_labels = {
        tmux_prefix  = { text = ' ^B ',     color = c.flamingo },
        resize_panes = { text = ' RESIZE ', color = c.peach },
    }

    local function detect_remote(title, uv)
        return logic.detect_remote(title, uv, local_host)
    end

    local function host_color(host)
        local key = logic.normalize_host(host)
        return host_color_map[key] or accents[logic.hash_idx(host, #accents)]
    end

    local function host_os(host)
        return host_os_map[logic.normalize_host(host)]
    end

    local function resolve_remote(title, uv, pid, domain_name)
        local fresh_remote = detect_remote(title, uv)
        if fresh_remote then
            pane_host_cache[pid] = fresh_remote
            return fresh_remote
        end

        local domain_remote = logic.detect_domain_remote(domain_name, local_host)
        if domain_remote then
            pane_host_cache[pid] = domain_remote
            return domain_remote
        end

        local uv_host = uv and uv.WEZTERM_HOST or ''
        if logic.is_same_host(uv_host, local_host) then
            pane_host_cache[pid] = nil
            pane_os_cache[pid] = nil
            pane_cwd_cache[pid] = nil
            return nil
        end

        return pane_host_cache[pid]
    end

    local function tab_title(tab)
        local title = tab.tab_title
        if title and #title > 0 then return title end
        title = logic.strip_title(tab.active_pane.title or '')
        if title and #title > 0 then return title end
        return tab.active_pane.title or ''
    end

    -- Tab title (Color Badge Style)
    wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
        local pane = tab.active_pane
        local raw_title = pane.title or ''
        local pid = tostring(pane.pane_id or tab.tab_id)
        local remote = resolve_remote(raw_title, pane.user_vars or {}, pid, pane.domain_name)
        local badge = remote and host_color(remote) or c.mauve

        local title = tab_title(tab)
        if max_width and max_width > 4 then
            title = wezterm.truncate_right(title, max_width - 4)
        end
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
        local pid = tostring(pane:pane_id())

        -- Host detection with cache:
        -- Once a remote host is detected, cache it. Only clear when
        -- positively identified as local (WEZTERM_HOST matches local).
        local remote = resolve_remote(title, uv, pid, pane:get_domain_name())

        -- OS detection with cache:
        -- Title-based Linux detection is definitive. Cache it so
        -- running programs (claude, vim) that change the title don't
        -- revert the icon to Apple.
        if remote then
            local os_kind = host_os(remote) or logic.detect_os(remote, title, uv, is_macos)
            if logic.is_linux_title(title) then
                pane_os_cache[pid] = 'linux'
            elseif host_os(remote) then
                pane_os_cache[pid] = host_os(remote)
            elseif logic.is_same_host(uv.WEZTERM_HOST, remote) and (uv.WEZTERM_OS or '') ~= '' then
                pane_os_cache[pid] = os_kind
            end
            -- pane_os_cache[pid] keeps previous value if no strong signal
        end

        local workspace = window:active_workspace():gsub('%c', '')
        local cwd, cache_val = logic.resolve_cwd(
            remote, title, uv, pane_cwd_cache[pid], workspace)
        if cache_val then
            pane_cwd_cache[pid] = cache_val
        elseif not remote then
            pane_cwd_cache[pid] = nil
        end
        cwd = logic.shorten_path(cwd or workspace or remote or '')

        local right = {}

        -- Mode indicator (leader / key table)
        local key_table = window:active_key_table()

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

        -- Host + OS icon (use cached values)
        local display_host = remote or local_host
        local os_kind = pane_os_cache[pid]
            or (remote and host_os(remote))
            or (remote and logic.detect_os(remote, title, uv, is_macos))
            or (is_macos and 'darwin' or 'linux')
        local os_icon = os_kind == 'darwin' and '\u{f0035}' or '\u{f17c}'
        if remote then
            table.insert(right, { Background = { Color = host_color(remote) } })
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
