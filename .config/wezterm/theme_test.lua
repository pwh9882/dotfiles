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

local LOCAL = 'woohyeok-MacBookPro'

test('detect_remote: local pane returns nil', function()
    is_nil(logic.detect_remote('~', {}, LOCAL))
    is_nil(logic.detect_remote('', {}, LOCAL))
    is_nil(logic.detect_remote('zsh', {}, LOCAL))
end)

test('detect_remote: Linux SSH title (user@host: path)', function()
    eq(logic.detect_remote('whpark@ddps-srv-2: ~', {}, LOCAL), 'ddps-srv-2')
    eq(logic.detect_remote('user@my-server.local: /home/user', {}, LOCAL), 'my-server.local')
end)

test('detect_remote: Oh My Tmux title (host ❐ session)', function()
    eq(logic.detect_remote('ddps-srv-2 ❐ main ● 1 vim', {}, LOCAL), 'ddps-srv-2')
end)

test('detect_remote: user_vars WEZTERM_HOST fallback', function()
    eq(logic.detect_remote('~', { WEZTERM_HOST = 'wini' }, LOCAL), 'wini')
end)

test('detect_remote: title has priority over user_vars (nested SSH)', function()
    -- MacBook → wini → pi: title shows pi, user_vars stuck at wini
    eq(logic.detect_remote('user@pi: ~', { WEZTERM_HOST = 'wini' }, LOCAL), 'pi')
end)

test('detect_remote: local hostname in title returns nil', function()
    is_nil(logic.detect_remote('user@woohyeok-MacBookPro: ~', {}, LOCAL))
end)

test('detect_remote: local hostname in user_vars returns nil', function()
    is_nil(logic.detect_remote('~', { WEZTERM_HOST = LOCAL }, LOCAL))
end)

test('detect_remote: empty WEZTERM_HOST ignored', function()
    is_nil(logic.detect_remote('~', { WEZTERM_HOST = '' }, LOCAL))
end)

-- ========== hash_idx ==========

test('hash_idx: returns 1-based index within range', function()
    for _, name in ipairs({'alpha', 'beta', 'gamma', 'ddps-srv-2', 'wini', 'pi'}) do
        local idx = logic.hash_idx(name, 6)
        assert(idx >= 1 and idx <= 6,
            string.format('%s: idx %d out of range [1,6]', name, idx))
    end
end)

test('hash_idx: deterministic', function()
    eq(logic.hash_idx('ddps-srv-2', 6), logic.hash_idx('ddps-srv-2', 6))
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
    eq(logic.strip_title('ddps-srv-2 ❐ main ● 1 vim'), 'main ● 1 vim')
end)

test('strip_title: SSH user@host: path', function()
    eq(logic.strip_title('whpark@ddps-srv-2: ~/projects'), '~/projects')
end)

test('strip_title: SSH user@host without colon', function()
    eq(logic.strip_title('woohyeok@wini'), '')
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
    eq(logic.extract_cwd_from_title('whpark@ddps-srv-2: ~'), '~')
    eq(logic.extract_cwd_from_title('user@host: /home/user/projects'), '/home/user/projects')
end)

test('extract_cwd: no colon returns nil', function()
    is_nil(logic.extract_cwd_from_title('woohyeok@wini'))
    is_nil(logic.extract_cwd_from_title('~'))
    is_nil(logic.extract_cwd_from_title(''))
end)

test('extract_cwd: tmux format returns nil', function()
    is_nil(logic.extract_cwd_from_title('ddps-srv-2 ❐ main ● 1 vim'))
end)

-- ========== is_linux_title ==========

test('is_linux_title: user@host: is Linux', function()
    assert(logic.is_linux_title('whpark@ddps-srv-2: ~'))
    assert(logic.is_linux_title('user@server.example.com: /home'))
end)

test('is_linux_title: no colon is not Linux', function()
    assert(not logic.is_linux_title('woohyeok@wini'))
    assert(not logic.is_linux_title('~'))
    assert(not logic.is_linux_title('ddps-srv-2 ❐ main'))
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
        'ddps-srv-2',
        'whpark@ddps-srv-2: /home/whpark',
        { WEZTERM_HOST = 'ddps-srv-2', WEZTERM_CWD = '~/stale' },
        nil, 'ws')
    eq(cwd, '/home/whpark')
end)

test('resolve_cwd: remote falls back to WEZTERM_CWD if host matches', function()
    local cwd = logic.resolve_cwd(
        'wini',
        '~',  -- macOS: no user@host in title
        { WEZTERM_HOST = 'wini', WEZTERM_CWD = '~/code' },
        nil, 'ws')
    eq(cwd, '~/code')
end)

test('resolve_cwd: remote ignores WEZTERM_CWD if host mismatch (stale)', function()
    local cwd = logic.resolve_cwd(
        'ddps-srv-2',
        'ddps-srv-2 ❐ main',  -- tmux, no path in title
        { WEZTERM_HOST = 'woohyeok-MacBookPro', WEZTERM_CWD = '~/dotfiles' },
        nil, 'ws')
    -- No title path, host mismatch, no cache → falls through
    eq(cwd, nil)  -- caller should use fallback
end)

test('resolve_cwd: remote uses cache when title changes (tmux)', function()
    local cwd = logic.resolve_cwd(
        'ddps-srv-2',
        'ddps-srv-2 ❐ main ● 1 vim',  -- tmux title, no path
        {},
        '/home/whpark',  -- cached from before tmux
        'ws')
    eq(cwd, '/home/whpark')
end)

test('resolve_cwd: remote caches extracted CWD', function()
    local cwd, cache = logic.resolve_cwd(
        'ddps-srv-2',
        'whpark@ddps-srv-2: /opt/app',
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

test('detect_os: remote macOS via WEZTERM_OS', function()
    eq(logic.detect_os('wini', '~', { WEZTERM_OS = 'Darwin' }, true), 'darwin')
end)

test('detect_os: remote without WEZTERM_OS defaults to Linux', function()
    eq(logic.detect_os('wini', '~', {}, true), 'linux')
end)

test('detect_os: remote with stale Darwin but Linux title → Linux wins', function()
    eq(logic.detect_os('srv', 'user@srv: ~', { WEZTERM_OS = 'Darwin' }, true), 'linux')
end)

-- ========== Summary ==========

io.write(string.format('\n%d passed, %d failed\n', passed, failed))
os.exit(failed > 0 and 1 or 0)
