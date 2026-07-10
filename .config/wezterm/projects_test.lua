#!/usr/bin/env lua
-- projects_test.lua — Unit tests for project state paths and workspace names.
-- Run: lua .config/wezterm/projects_test.lua

package.path = '.config/wezterm/?.lua;' .. package.path
local logic = require 'projects_logic'

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

local function eq(actual, expected)
  assert(actual == expected, string.format('expected %q, got %q', tostring(expected), tostring(actual)))
end

test('history uses XDG_STATE_HOME when set', function()
  local paths = logic.history_paths('/home/user', '/home/user/.config/wezterm', '/state/user')
  eq(paths.dir, '/state/user/wezterm')
  eq(paths.path, '/state/user/wezterm/project_history.txt')
  eq(paths.legacy_path, '/home/user/.config/wezterm/project_history.txt')
end)

test('history falls back to HOME local state', function()
  local paths = logic.history_paths('/home/user', '/home/user/.config/wezterm', '')
  eq(paths.dir, '/home/user/.local/state/wezterm')
  eq(paths.path, '/home/user/.local/state/wezterm/project_history.txt')
end)

test('local workspace names include the path instead of only the basename', function()
  local first = logic.workspace_name('/home/user/work/client/app', '/home/user')
  local second = logic.workspace_name('/home/user/work/personal/app', '/home/user')
  eq(first, 'local:~/work/client/app')
  eq(second, 'local:~/work/personal/app')
  assert(first ~= second, 'same basename under different parents must not collide')
end)

test('home workspace has a short stable name', function()
  eq(logic.workspace_name('/home/user/', '/home/user'), 'local:~')
end)

test('SSH and local workspace namespaces are distinct', function()
  eq(logic.workspace_name('SSH:build-host', '/home/user'), 'ssh:build-host')
  eq(logic.workspace_name('/home/user/build-host', '/home/user'), 'local:~/build-host')
end)

test('Windows separators are normalized in local workspace names', function()
  eq(logic.workspace_name('C:\\Users\\user\\work\\app', 'C:\\Users\\user'), 'local:~/work/app')
end)

test('literal plus signs remain distinct after resurrect filename mapping', function()
  local first = logic.workspace_name('/home/user/a+b/c', '/home/user')
  local second = logic.workspace_name('/home/user/a/b+c', '/home/user')
  eq(first, 'local:~/a%2Bb/c')
  eq(second, 'local:~/a/b%2Bc')
  assert(first:gsub('/', '+') ~= second:gsub('/', '+'), 'resurrect state filenames must remain distinct')
end)

if failed > 0 then
  io.write(string.format('\n%d passed, %d failed\n', passed, failed))
  os.exit(1)
end

io.write(string.format('All %d project logic tests passed\n', passed))
