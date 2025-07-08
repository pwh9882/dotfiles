local wezterm = require 'wezterm'
local module = {}

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
    wezterm.home_dir .. "/Library/CloudStorage/GoogleDrive-pwh9882@gmail.com/내 드라이브/GD2025-01/UCI"
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

function module.choose_project()
    local choices = {}
    for _, value in ipairs(project_dirs()) do
      -- Format SSH entries with emoji for easy identification
      local display_label = value
      if value:match("^SSH:") then
        local host = value:gsub("^SSH:", "")
        display_label = "🔗 ssh " .. host  -- Add "ssh" prefix for fuzzy matching
      end
      table.insert(choices, { label = display_label, id = value })
    end
  
    return wezterm.action.InputSelector {
      title = "Projects & SSH Hosts",
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(win, pane, id, label)
        -- "id" may be empty if nothing was selected. Don't bother doing anything
        -- when that happens.
        if not id then return end
  
        -- Check if this is an SSH host
        if id:match("^SSH:") then
          local host = id:gsub("^SSH:", "")
          -- Create workspace with SSH connection
          win:perform_action(wezterm.action.SwitchToWorkspace {
            name = host,
            spawn = {
              args = { "ssh", host },
              cwd = wezterm.home_dir,
            },
          }, pane)
        else
          -- Regular local directory
          win:perform_action(wezterm.action.SwitchToWorkspace {
            -- We'll give our new workspace a nice name, like the last path segment
            -- of the directory we're opening up.
            name = id:match("([^/]+)$"),
            -- Here's the meat. We'll spawn a new terminal with the current working
            -- directory set to the directory that was picked.
            spawn = { cwd = id },
          }, pane)
        end
      end),
    }
  end

return module
