-- theme_logic.lua — Testable pure functions for theme.lua
local M = {}

--- Shorten path: ~/projects/myapp/src → ~/p/m/src
function M.shorten_path(path)
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

--- Detect remote hostname from title + user_vars.
--- Returns hostname string if remote, nil if local.
---   1) title patterns: "host ❐ ..." (Oh My Tmux), "user@host[: ...]" (Linux SSH)
---   2) user_vars.WEZTERM_HOST fallback (macOS SSH where title has no hostname)
function M.detect_remote(title, uv, local_host)
    local h = title:match('^(%S+)%s+❐')
          or title:match('^%S+@([%w%-%._]+)')
    if h and h ~= local_host then return h end
    h = uv and uv.WEZTERM_HOST or nil
    if h and h ~= '' and h ~= local_host then return h end
    return nil
end

--- Hash hostname to accent color index (1-based).
function M.hash_idx(s, num_accents)
    local h = 0
    for i = 1, #s do h = h + string.byte(s, i) end
    return (h % num_accents) + 1
end

--- Strip hostname prefixes from pane title.
function M.strip_title(title)
    title = title:gsub('^%S+%s+❐%s*', '')           -- Oh My Tmux: #h ❐ #S ● #I #W
    title = title:gsub('^%S+@[%w%-%._]+[:%s]*', '') -- SSH shell: user@host[: path]
    return title
end

--- Extract CWD path from "user@host: /path" title format.
--- Returns path string or nil.
function M.extract_cwd_from_title(title)
    return title:match('^%S+@[%w%-%._]+:%s*(.+)')
end

--- Determine if title indicates a Linux SSH session.
--- "user@host:" format is exclusive to Linux shells.
function M.is_linux_title(title)
    return title:match('^%S+@[%w%-%._]+:') ~= nil
end

--- Assign unique accent colors to hostnames with collision avoidance.
--- Returns { hostname = color_value, ... }
function M.assign_host_colors(hosts, accents)
    local host_colors = {}
    local used = {}
    for _, h in ipairs(hosts) do
        if not host_colors[h] then
            local idx = M.hash_idx(h, #accents)
            for _ = 1, #accents do
                if not used[idx] then break end
                idx = (idx % #accents) + 1
            end
            used[idx] = true
            host_colors[h] = accents[idx]
        end
    end
    return host_colors
end

--- Resolve CWD for status bar display.
--- Returns { cwd = string, cache_update = value_or_nil }
function M.resolve_cwd(remote, title, uv, cached_cwd, workspace)
    if remote then
        -- 1) Title path extraction
        local cwd = M.extract_cwd_from_title(title)
        -- 2) WEZTERM_CWD if host matches
        if not cwd or cwd == '' then
            local uv_host = uv and uv.WEZTERM_HOST or ''
            if uv_host == remote and uv.WEZTERM_CWD and uv.WEZTERM_CWD ~= '' then
                cwd = uv.WEZTERM_CWD
            end
        end
        -- 3) Cache fallback
        if cwd and cwd ~= '' then
            return cwd, cwd  -- cwd, new_cache
        else
            return cached_cwd, nil  -- use cache, no update
        end
    else
        local cwd = uv and uv.WEZTERM_CWD or nil
        if cwd and cwd ~= '' then
            return cwd, nil
        end
        return workspace or '', nil
    end
end

--- Determine OS icon for a pane.
--- Returns 'darwin' or 'linux'.
function M.detect_os(remote, title, uv, is_macos)
    if remote then
        if M.is_linux_title(title) then return 'linux' end
        local os_val = uv and uv.WEZTERM_OS or ''
        return os_val == 'Darwin' and 'darwin' or 'linux'
    end
    return is_macos and 'darwin' or 'linux'
end

return M
