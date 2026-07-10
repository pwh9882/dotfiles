local M = {}

local function normalize_path(path)
  path = tostring(path or ''):gsub('\\', '/')
  if path ~= '/' and not path:match('^%a:/$') then
    path = path:gsub('/+$', '')
  end
  return path
end

function M.history_paths(home_dir, config_dir, xdg_state_home)
  local home = normalize_path(home_dir)
  local state_home = normalize_path(xdg_state_home)
  if state_home == '' then
    state_home = home .. '/.local/state'
  end

  local state_dir = state_home .. '/wezterm'
  return {
    dir = state_dir,
    path = state_dir .. '/project_history.txt',
    legacy_path = normalize_path(config_dir) .. '/project_history.txt',
  }
end

function M.workspace_name(project_id, home_dir)
  local ssh_host = tostring(project_id or ''):match('^SSH:(.+)$')
  if ssh_host then
    return 'ssh:' .. ssh_host
  end

  local path = normalize_path(project_id)
  local home = normalize_path(home_dir)
  if path == home then
    path = '~'
  elseif home ~= '' and path:sub(1, #home + 1) == home .. '/' then
    path = '~' .. path:sub(#home + 1)
  end
  -- resurrect.wezterm maps path separators to '+'. Escape literal '%' and '+'
  -- first so two different paths cannot collapse to the same state filename.
  path = path:gsub('%%', '%%25'):gsub('%+', '%%2B')
  return 'local:' .. path
end

return M
