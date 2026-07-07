-- theme_logic.lua — Testable pure functions for theme.lua
local M = {}

--- Shorten path: ~/projects/myapp/src → ~/p/m/src
function M.shorten_path(path)
    if not path or path == '' then return '' end
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

--- Normalize hostnames for comparison.
--- Keeps display values unchanged elsewhere, but compares case-insensitively
--- and treats short hostnames and FQDNs as the same machine.
function M.normalize_host(host)
    if not host or host == '' then return '' end
    host = tostring(host):lower():gsub('^%s+', ''):gsub('%s+$', '')
    return host:match('^([^%.]+)') or host
end

function M.is_same_host(a, b)
    local na = M.normalize_host(a)
    local nb = M.normalize_host(b)
    return na ~= '' and nb ~= '' and na == nb
end

--- Infer remote host from a WezTerm domain name.
--- SSH domains are remote even before the remote shell has emitted user vars.
function M.detect_domain_remote(domain_name, local_host)
    if not domain_name or domain_name == '' then return nil end
    local domain = tostring(domain_name)
    if domain == 'local' or M.is_same_host(domain, local_host) then return nil end

    local host = domain:gsub('^SSH:', ''):gsub('^SSHMUX:', '')
    if host ~= '' and not M.is_same_host(host, local_host) then return host end
    return nil
end

--- Detect remote hostname from title + user_vars.
--- Returns hostname string if remote, nil if local.
---   1) title patterns: "host ❐ ..." (Oh My Tmux), "user@host[: ...]" (Linux SSH)
---   2) user_vars.WEZTERM_HOST fallback (macOS SSH where title has no hostname)
function M.detect_remote(title, uv, local_host)
    title = title or ''
    local h = title:match('^(%S+)%s+❐')
          or title:match('^%S+@([%w%-%._]+)')
    if h and not M.is_same_host(h, local_host) then return h end
    h = uv and uv.WEZTERM_HOST or nil
    if h and h ~= '' and not M.is_same_host(h, local_host) then return h end
    return nil
end

--- Hash hostname to accent color index (1-based).
function M.hash_idx(s, num_accents)
    -- djb2 keeps stable colors while reducing trivial anagram collisions.
    local h = 5381
    s = M.normalize_host(s)
    for i = 1, #s do
        h = (h * 33 + string.byte(s, i)) % 4294967296
    end
    return (h % num_accents) + 1
end

--- Strip hostname prefixes from pane title.
function M.strip_title(title)
    title = title or ''
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
            return cached_cwd or remote or workspace or '', nil
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
        if uv and M.is_same_host(uv.WEZTERM_HOST, remote) then
            local os_val = uv.WEZTERM_OS or ''
            if os_val == 'Darwin' then return 'darwin' end
            if os_val == 'Linux' then return 'linux' end
        end
        if M.is_linux_title(title) then return 'linux' end
        return 'linux'
    end
    return is_macos and 'darwin' or 'linux'
end

return M
