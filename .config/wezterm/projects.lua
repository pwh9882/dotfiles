local wezterm = require 'wezterm'
local module = {}

-- Simple persistent history (LRU) of recently used projects
local config_dir = wezterm.config_dir or (wezterm.home_dir .. "/.config/wezterm")
local history_path = config_dir .. "/project_history.txt"

local function read_lines(path)
  local lines = {}
  local f = io.open(path, 'r')
  if not f then return lines end
  for line in f:lines() do
    if line and #line > 0 then table.insert(lines, line) end
  end
  f:close()
  return lines
end

local function write_lines(path, lines)
  local f = io.open(path, 'w')
  if not f then return end
  for _, l in ipairs(lines) do
    f:write(l)
    f:write('\n')
  end
  f:close()
end

local function url_decode(str)
  if not str then return nil end
  return (str:gsub('%%(%x%x)', function(h)
    return string.char(tonumber(h, 16))
  end))
end

-- The directory that contains all your projects.
local project_dir = wezterm.home_dir .. "/development"
local project_dir_years = {
    wezterm.home_dir .. "/development/2024",
    wezterm.home_dir .. "/development/2025"
  }
-- Additional common project directories
local additional_dirs = {
    wezterm.home_dir .. "/dotfiles",
    wezterm.home_dir .. "/Documents",
    wezterm.home_dir .. "/Desktop",
    wezterm.home_dir .. "/mcps",
    wezterm.home_dir .. "/Library/CloudStorage/GoogleDrive-pwh9882@gmail.com/내 드라이브/GD2025-01/UCI",
    wezterm.home_dir .. "/Library/CloudStorage/GoogleDrive-pwh9882@gmail.com/내 드라이브/GD2025-02/석사수업/ANLP",
    wezterm.home_dir .. "/Library/CloudStorage/GoogleDrive-pwh9882@gmail.com/내 드라이브/GD2025-02/석사수업/DCD"
  }

-- Function to parse SSH config and extract host names
local function get_ssh_hosts()
    local ssh_hosts = {}
    local ssh_config_path = wezterm.home_dir .. "/.ssh/config"
    
    -- Read SSH config file
    local file = io.open(ssh_config_path, "r")
    if file then
        for line in file:lines() do
            -- Look for Host entries, exclude wildcards and comments
            local host = line:match("^Host%s+([^%s*]+)")
            if host and not host:match("[*?]") and not host:match("^#") then
                table.insert(ssh_hosts, host)
            end
        end
        file:close()
    end
    
    return ssh_hosts
end
local function project_dirs()
  -- Start with your home directory as a project, 'cause you might want
  -- to jump straight to it sometimes.
  local projects = { wezterm.home_dir }

  -- WezTerm comes with a glob function! Let's use it to get a lua table
  -- containing all subdirectories of your project folder.
  for _, dir in ipairs(wezterm.glob(project_dir .. '/*')) do
    -- ... and add them to the projects table.
    table.insert(projects, dir)
  end

  for _, project_dir_year in ipairs(project_dir_years) do
    for _, dir in ipairs(wezterm.glob(project_dir_year .. '/*')) do
      table.insert(projects, dir)
    end
  end

  -- Add additional directories
  for _, dir in ipairs(additional_dirs) do
    table.insert(projects, dir)
  end

  -- Add SSH hosts with special prefix
  for _, host in ipairs(get_ssh_hosts()) do
    table.insert(projects, "SSH:" .. host)
  end

  return projects
end

-- Identify the current project id from a pane ("SSH:host" or a project dir)
local function current_project_id(pane)
  if not pane then return nil end
  local uri = pane:get_current_working_dir()
  if not uri then return nil end
  uri = tostring(uri)
  if uri:match('^ssh://') then
    -- ssh://[user@]host/path
    local host = uri:gsub('^ssh://', ''):match('^([^/]+)') or ''
    host = host:gsub('^.+@', '') -- strip user@
    if #host > 0 then
      return 'SSH:' .. host
    end
    return nil
  end
  if uri:match('^file://') then
    -- Examples:
    --  - file:///Users/foo/bar
    --  - file://hostname/Users/foo/bar
    local path = uri:gsub('^file://', '')
    -- Strip host if present (file://host/...) leaving absolute path
    if not path:match('^/') and path:match('^[^/]+/') then
      local _host, rest = path:match('^([^/]+)(/.*)$')
      path = rest or path
    end
    -- Ensure absolute and squish duplicate slashes
    if not path:match('^/') then path = '/' .. path end
    path = path:gsub('//+', '/')
    path = url_decode(path)
    if not path then return nil end
    -- Choose the longest matching project dir as id
    local best
    for _, dir in ipairs(project_dirs()) do
      if not dir:match('^SSH:') then
        if path == dir or path:sub(1, #dir + 1) == (dir .. '/') then
          if not best or #dir > #best then best = dir end
        end
      end
    end
    return best
  end
  return nil
end

local function push_recent(id)
  if not id or #id == 0 then return end
  local recents = read_lines(history_path)
  -- dedupe
  local filtered = {}
  for _, v in ipairs(recents) do
    if v ~= id then table.insert(filtered, v) end
  end
  table.insert(filtered, 1, id)
  -- limit size
  local max = 50
  while #filtered > max do table.remove(filtered) end
  write_lines(history_path, filtered)
end

local function make_label(id)
  if id:match('^SSH:') then
    local host = id:gsub('^SSH:', '')
    return '🔗 ssh ' .. host
  end
  return id
end

local function build_choices_excluding_current(current_id)
  local dirs = project_dirs()
  local set = {}
  for _, d in ipairs(dirs) do set[d] = true end

  local recents = read_lines(history_path)
  local recent_ids = {}
  local rest_ids = {}
  local added = {}

  -- Recent items first (excluding current)
  for _, id in ipairs(recents) do
    if id ~= current_id and (id:match('^SSH:') or set[id]) and not added[id] then
      table.insert(recent_ids, id)
      added[id] = true
    end
  end

  -- Then the rest in original order
  for _, id in ipairs(dirs) do
    if id ~= current_id and not added[id] then
      table.insert(rest_ids, id)
      added[id] = true
    end
  end

  -- Build display list with section headers
  local choices = {}
  if #recent_ids > 0 then
    -- Put the most recent as the very first selectable item
    local top = recent_ids[1]
    table.insert(choices, { label = "⏮ Prev: " .. make_label(top), id = top })
    -- If there are more recents, add a header and the rest
    if #recent_ids > 1 then
      table.insert(choices, { label = "──── Recent ────", id = nil })
      for i = 2, #recent_ids do
        local id = recent_ids[i]
        table.insert(choices, { label = make_label(id), id = id })
      end
    end
  end
  if #rest_ids > 0 then
    if #recent_ids > 0 then
      table.insert(choices, { label = "──── All ────", id = nil })
    end
    for _, id in ipairs(rest_ids) do
      table.insert(choices, { label = make_label(id), id = id })
    end
  end

  return choices
end

-- Expose a helper so wezterm.lua can record recents on other switchers
function module.record_current_as_recent(pane)
  local prev = current_project_id(pane)
  if not prev then
    local uri = pane and pane:get_current_working_dir() or nil
    wezterm.log_info("recent-history: unresolved current project; uri=", tostring(uri))
  else
    wezterm.log_info("recent-history: push ", prev, " -> ", history_path)
  end
  push_recent(prev)
end

function module.choose_project()
  -- Build choices dynamically at invocation time, so recents are up to date
  return wezterm.action_callback(function(win, pane)
    local current_id = current_project_id(pane)
    local choices = build_choices_excluding_current(current_id)

    win:perform_action(wezterm.action.InputSelector({
      title = "Projects & SSH Hosts",
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(win2, pane2, id, _)
        if not id then return end
        -- Push previous project to recents before switching
        module.record_current_as_recent(pane2)

        if id:match('^SSH:') then
          local host = id:gsub('^SSH:', '')
          win2:perform_action(wezterm.action.SwitchToWorkspace({
            name = host,
            spawn = { args = { 'ssh', host }, cwd = wezterm.home_dir },
          }), pane2)
        else
          win2:perform_action(wezterm.action.SwitchToWorkspace({
            name = id:match('([^/]+)$'),
            spawn = { cwd = id },
          }), pane2)
        end
      end),
    }), pane)
  end)
end

-- Search-first picker: no recent pinning; simple case-insensitive substring filter
return module
