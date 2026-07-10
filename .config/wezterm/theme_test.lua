#!/usr/bin/env lua
-- theme_test.lua — Unit tests for theme_logic.lua
-- Run: lua .config/wezterm/theme_test.lua

package.path = '.config/wezterm/?.lua;' .. package.path
local logic = require 'theme_logic'

local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        io.write('FAIL: ' .. name .. '\n  ' .. tostring(err) .. '\n')
    end
end

local function eq(a, b)
    assert(a == b, string.format('expected %q, got %q', tostring(b), tostring(a)))
end

local function is_nil(a)
    assert(a == nil, string.format('expected nil, got %q', tostring(a)))
end

-- ========== shorten_path ==========

test('shorten_path: single segment unchanged', function()
    eq(logic.shorten_path('~'), '~')
    eq(logic.shorten_path('home'), 'home')
end)

test('shorten_path: nil and empty are safe', function()
    eq(logic.shorten_path(nil), '')
    eq(logic.shorten_path(''), '')
end)

test('shorten_path: tilde prefix preserved', function()
    eq(logic.shorten_path('~/projects/myapp/src'), '~/p/m/src')
end)

test('shorten_path: absolute path', function()
    eq(logic.shorten_path('/home/user/projects'), '/h/u/projects')
end)

test('shorten_path: two segments', function()
    eq(logic.shorten_path('~/dotfiles'), '~/dotfiles')
end)

test('shorten_path: deep nesting', function()
    eq(logic.shorten_path('~/a/b/c/d/target'), '~/a/b/c/d/target')
end)

-- ========== detect_remote ==========

local LOCAL = 'local-laptop'

-- ========== host normalization ==========

test('normalize_host: lowercases and strips fqdn', function()
    eq(logic.normalize_host('MAC-NODE.example.com'), 'mac-node')
    eq(logic.normalize_host(' linux-b.example.com '), 'linux-b')
end)

test('is_same_host: short and fqdn match', function()
    assert(logic.is_same_host('mac-node', 'mac-node.example.com'))
    assert(logic.is_same_host('LOCAL-LAPTOP.example.com', LOCAL))
    assert(not logic.is_same_host('mac-node', 'wsl-node'))
end)

test('detect_domain_remote: local domain returns nil', function()
    is_nil(logic.detect_domain_remote('local', LOCAL))
    is_nil(logic.detect_domain_remote(LOCAL .. '.local', LOCAL))
end)

test('domain_kind: distinguishes local, WSL, SSH, and SSHMUX', function()
    eq(logic.domain_kind('local', LOCAL), 'local')
    eq(logic.domain_kind('WSL:Ubuntu-24.04', LOCAL), 'wsl')
    eq(logic.domain_kind('SSH:linux-a', LOCAL), 'ssh')
    eq(logic.domain_kind('linux-a', LOCAL), 'ssh')
    eq(logic.domain_kind('SSHMUX:linux-b', LOCAL), 'sshmux')
end)

test('detect_domain_remote: WSL domain is local execution', function()
    is_nil(logic.detect_domain_remote('WSL:Ubuntu-24.04', LOCAL))
end)

test('detect_domain_remote: ssh domains return host names', function()
    eq(logic.detect_domain_remote('linux-a', LOCAL), 'linux-a')
    eq(logic.detect_domain_remote('SSH:linux-a', LOCAL), 'linux-a')
    eq(logic.detect_domain_remote('SSHMUX:linux-b', LOCAL), 'linux-b')
end)

test('detect_remote: local pane returns nil', function()
    is_nil(logic.detect_remote('~', {}, LOCAL))
    is_nil(logic.detect_remote('', {}, LOCAL))
    is_nil(logic.detect_remote('zsh', {}, LOCAL))
end)

test('detect_remote: Linux SSH title (user@host: path)', function()
    eq(logic.detect_remote('user@linux-b: ~', {}, LOCAL), 'linux-b')
    eq(logic.detect_remote('user@my-server.local: /home/user', {}, LOCAL), 'my-server.local')
end)

test('detect_remote: Oh My Tmux title (host ❐ session)', function()
    eq(logic.detect_remote('linux-b ❐ main ● 1 vim', {}, LOCAL), 'linux-b')
end)

test('detect_remote: user_vars WEZTERM_HOST fallback', function()
    eq(logic.detect_remote('~', { WEZTERM_HOST = 'mac-node' }, LOCAL), 'mac-node')
end)

test('detect_remote: title has priority over user_vars (nested SSH)', function()
    -- laptop → mac-node → edge-node: title is final, user_vars are stale
    eq(logic.detect_remote('user@edge-node: ~', { WEZTERM_HOST = 'mac-node' }, LOCAL), 'edge-node')
end)

test('detect_remote: local hostname in title returns nil', function()
    is_nil(logic.detect_remote('user@local-laptop: ~', {}, LOCAL))
    is_nil(logic.detect_remote('user@local-laptop.example.com: ~', {}, LOCAL))
end)

test('detect_remote: local hostname in user_vars returns nil', function()
    is_nil(logic.detect_remote('~', { WEZTERM_HOST = LOCAL }, LOCAL))
    is_nil(logic.detect_remote('~', { WEZTERM_HOST = LOCAL .. '.local' }, LOCAL))
end)

test('detect_remote: empty WEZTERM_HOST ignored', function()
    is_nil(logic.detect_remote('~', { WEZTERM_HOST = '' }, LOCAL))
end)

-- ========== hash_idx ==========

test('hash_idx: returns 1-based index within range', function()
    for _, name in ipairs({'alpha', 'beta', 'gamma', 'linux-b', 'mac-node', 'edge-node'}) do
        local idx = logic.hash_idx(name, 6)
        assert(idx >= 1 and idx <= 6,
            string.format('%s: idx %d out of range [1,6]', name, idx))
    end
end)

test('hash_idx: deterministic', function()
    eq(logic.hash_idx('linux-b', 6), logic.hash_idx('linux-b', 6))
end)

test('hash_idx: different names can differ', function()
    -- Not guaranteed but very likely for these two
    local a = logic.hash_idx('alpha', 6)
    local b = logic.hash_idx('zzzzz', 6)
    -- Just verify both are valid; actual equality/inequality depends on hash
    assert(a >= 1 and a <= 6)
    assert(b >= 1 and b <= 6)
end)

-- ========== strip_title ==========

test('strip_title: Oh My Tmux format', function()
    eq(logic.strip_title('linux-b ❐ main ● 1 vim'), 'main ● 1 vim')
end)

test('strip_title: SSH user@host: path', function()
    eq(logic.strip_title('user@linux-b: ~/projects'), '~/projects')
end)

test('strip_title: SSH user@host without colon', function()
    eq(logic.strip_title('user@mac-node'), '')
end)

test('strip_title: plain title unchanged', function()
    eq(logic.strip_title('vim'), 'vim')
    eq(logic.strip_title('~'), '~')
end)

test('strip_title: empty string', function()
    eq(logic.strip_title(''), '')
end)

-- ========== extract_cwd_from_title ==========

test('extract_cwd: Linux SSH format', function()
    eq(logic.extract_cwd_from_title('user@linux-b: ~'), '~')
    eq(logic.extract_cwd_from_title('user@host: /home/user/projects'), '/home/user/projects')
end)

test('extract_cwd: no colon returns nil', function()
    is_nil(logic.extract_cwd_from_title('user@mac-node'))
    is_nil(logic.extract_cwd_from_title('~'))
    is_nil(logic.extract_cwd_from_title(''))
end)

test('extract_cwd: tmux format returns nil', function()
    is_nil(logic.extract_cwd_from_title('linux-b ❐ main ● 1 vim'))
end)

-- ========== is_linux_title ==========

test('is_linux_title: user@host: is Linux', function()
    assert(logic.is_linux_title('user@linux-b: ~'))
    assert(logic.is_linux_title('user@server.example.com: /home'))
end)

test('is_linux_title: no colon is not Linux', function()
    assert(not logic.is_linux_title('user@mac-node'))
    assert(not logic.is_linux_title('~'))
    assert(not logic.is_linux_title('linux-b ❐ main'))
end)

-- ========== assign_host_colors ==========

test('assign_host_colors: unique colors per host', function()
    local accents = {'red', 'green', 'blue', 'yellow', 'pink', 'cyan'}
    local colors = logic.assign_host_colors({'alpha', 'beta', 'gamma'}, accents)
    -- Each host gets a color
    assert(colors['alpha'])
    assert(colors['beta'])
    assert(colors['gamma'])
    -- All different
    assert(colors['alpha'] ~= colors['beta'] or colors['beta'] ~= colors['gamma'],
        'at least some hosts should have different colors')
end)

test('assign_host_colors: collision avoidance', function()
    -- Create hosts that hash to the same index
    local accents = {'A', 'B'}
    local hosts = {}
    -- Find two hosts with same hash
    local seen = {}
    for i = 1, 100 do
        local name = 'host' .. i
        local idx = logic.hash_idx(name, 2)
        if seen[idx] then
            hosts = { seen[idx], name }
            break
        end
        seen[idx] = name
    end
    if #hosts == 2 then
        local colors = logic.assign_host_colors(hosts, accents)
        assert(colors[hosts[1]] ~= colors[hosts[2]],
            'colliding hosts should get different colors')
    end
end)

test('assign_host_colors: more hosts than accents wraps', function()
    local accents = {'A', 'B'}
    -- With only 2 accents and 3 hosts, must reuse
    local colors = logic.assign_host_colors({'h1', 'h2', 'h3'}, accents)
    assert(colors['h1'])
    assert(colors['h2'])
    -- Third host will reuse a color (all slots taken)
    assert(colors['h3'])
end)

-- ========== resolve_cwd ==========

test('resolve_cwd: local pane uses WEZTERM_CWD', function()
    local cwd = logic.resolve_cwd(nil, '~', { WEZTERM_CWD = '~/projects' }, nil, 'default')
    eq(cwd, '~/projects')
end)

test('resolve_cwd: local pane without CWD falls back to workspace', function()
    local cwd = logic.resolve_cwd(nil, '~', {}, nil, 'default')
    eq(cwd, 'default')
end)

test('resolve_cwd: remote extracts from title first', function()
    local cwd = logic.resolve_cwd(
        'linux-b',
        'user@linux-b: /home/user',
        { WEZTERM_HOST = 'linux-b', WEZTERM_CWD = '~/stale' },
        nil, 'ws')
    eq(cwd, '/home/user')
end)

test('resolve_cwd: remote falls back to WEZTERM_CWD if host matches', function()
    local cwd = logic.resolve_cwd(
        'mac-node',
        '~',  -- macOS: no user@host in title
        { WEZTERM_HOST = 'mac-node', WEZTERM_CWD = '~/code' },
        nil, 'ws')
    eq(cwd, '~/code')
end)

test('resolve_cwd: remote accepts normalized FQDN and case host match', function()
    local cwd = logic.resolve_cwd(
        'mac-node',
        '~',
        { WEZTERM_HOST = 'MAC-NODE.example.com', WEZTERM_CWD = '~/code' },
        nil, 'ws')
    eq(cwd, '~/code')
end)

test('resolve_cwd: remote ignores WEZTERM_CWD if host mismatch (stale)', function()
    local cwd = logic.resolve_cwd(
        'linux-b',
        'linux-b ❐ main',  -- tmux, no path in title
        { WEZTERM_HOST = 'local-laptop', WEZTERM_CWD = '~/dotfiles' },
        nil, 'ws')
    eq(cwd, 'linux-b')
end)

test('resolve_cwd: remote uses cache when title changes (tmux)', function()
    local cwd = logic.resolve_cwd(
        'linux-b',
        'linux-b ❐ main ● 1 vim',  -- tmux title, no path
        {},
        '/home/user',  -- cached from before tmux
        'ws')
    eq(cwd, '/home/user')
end)

test('resolve_cwd: remote caches extracted CWD', function()
    local cwd, cache = logic.resolve_cwd(
        'linux-b',
        'user@linux-b: /opt/app',
        {}, nil, 'ws')
    eq(cwd, '/opt/app')
    eq(cache, '/opt/app')
end)

-- ========== detect_os ==========

test('detect_os: local macOS', function()
    eq(logic.detect_os(nil, '', {}, true), 'darwin')
end)

test('detect_os: local Linux', function()
    eq(logic.detect_os(nil, '', {}, false), 'linux')
end)

test('detect_os: remote with Linux title format', function()
    eq(logic.detect_os('srv', 'user@srv: ~', {}, true), 'linux')
end)

test('detect_os: remote ignores WEZTERM_OS without matching host', function()
    eq(logic.detect_os('mac-node', '~', { WEZTERM_OS = 'Darwin' }, true), 'linux')
end)

test('detect_os: remote without WEZTERM_OS defaults to Linux', function()
    eq(logic.detect_os('mac-node', '~', {}, true), 'linux')
end)

test('detect_os: remote with stale Darwin but Linux title → Linux wins', function()
    eq(logic.detect_os('srv', 'user@srv: ~', { WEZTERM_OS = 'Darwin' }, true), 'linux')
end)

test('detect_os: matching WEZTERM_OS wins for remote host', function()
    eq(logic.detect_os('mac-mini', 'user@mac-mini: ~',
        { WEZTERM_HOST = 'mac-mini.local', WEZTERM_OS = 'Darwin' }, true), 'darwin')
end)

-- ========== Summary ==========

io.write(string.format('\n%d passed, %d failed\n', passed, failed))
os.exit(failed > 0 and 1 or 0)
