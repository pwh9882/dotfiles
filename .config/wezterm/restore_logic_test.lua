package.path = './.config/wezterm/?.lua;' .. package.path

local logic = require 'restore_logic'

local passed = 0
local failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print('PASS  ' .. name)
  else
    failed = failed + 1
    print('FAIL  ' .. name .. ': ' .. tostring(err))
  end
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or 'values differ') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
  end
end

local function pane(process_name, argv)
  return {
    alt_screen_active = true,
    process = {
      name = process_name,
      argv = argv,
    },
  }
end

test('login shells are not replayed', function()
  local action = logic.restore_action(pane('-zsh', { '-zsh' }))
  assert_equal(action.kind, 'skip')
end)

test('non-alt-screen pane text is never restored', function()
  local action = logic.restore_action({ alt_screen_active = false, text = 'saved scrollback' })
  assert_equal(action.kind, 'skip')
end)

test('named ssht resolver argv becomes a short ssht command', function()
  local remote = "exec ... printf 'create one with: ssht <host> -n %s' ...\nesac ssht find research"
  local action = logic.restore_action(pane('ssh', { 'ssh', '-t', 'lab-host', remote }))
  assert_equal(action.kind, 'command')
  assert_equal(#action.argv, 3)
  assert_equal(action.argv[1], 'ssht')
  assert_equal(action.argv[2], 'lab-host')
  assert_equal(action.argv[3], 'research')
end)

test('default ssht resolver argv becomes a short host command', function()
  local action = logic.restore_action(pane('ssh', { 'ssh', '-t', 'lab-host', "exec ... ssht default ''" }))
  assert_equal(action.kind, 'command')
  assert_equal(#action.argv, 2)
  assert_equal(action.argv[1], 'ssht')
  assert_equal(action.argv[2], 'lab-host')
end)

test('new ssht sessions reconnect without trying to create again', function()
  local action = logic.restore_action(pane('ssh', { 'ssh', '-t', 'lab-host', 'exec ... ssht new research' }))
  assert_equal(action.kind, 'command')
  assert_equal(action.argv[3], 'research')
end)

test('ssht SSH options are preserved in the short command', function()
  local action = logic.restore_action(pane('ssh', {
    'ssh', '-t', '-p', '33022', 'lab-host', 'exec ... ssht find research',
  }))
  assert_equal(action.kind, 'command')
  assert_equal(table.concat(action.argv, ' '), 'ssht -p 33022 lab-host research')
end)

test('unparseable generated ssht argv is skipped instead of replayed raw', function()
  local action = logic.restore_action(pane('ssh', { 'ssh', '-t', 'lab-host', 'exec ... ssht find project\\ name' }))
  assert_equal(action.kind, 'skip')
end)

test('ordinary alt-screen processes keep plugin default restore', function()
  local action = logic.restore_action(pane('btop', { 'btop' }))
  assert_equal(action.kind, 'default')
end)

test('manual workspace and GUI startup restores use the guarded callback', function()
  local file = assert(io.open('.config/wezterm/plugins.lua', 'r'))
  local source = file:read('*a')
  file:close()
  assert(not source:find('resurrect.state_manager.resurrect_on_gui_startup', 1, true),
    'GUI startup must not bypass the guarded pane callback')
  local _, count = source:gsub('on_pane_restore = on_pane_restore', '')
  assert(count >= 3, 'all three restore paths must use the guarded pane callback')
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
