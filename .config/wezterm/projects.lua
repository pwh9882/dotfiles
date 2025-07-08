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
    wezterm.home_dir .. "/Desktop"
  }
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

  return projects
end

function module.choose_project()
    local choices = {}
    for _, value in ipairs(project_dirs()) do
      table.insert(choices, { label = value })
    end
  
    return wezterm.action.InputSelector {
      title = "Projects",
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(win, pane, id, label)
        -- "label" may be empty if nothing was selected. Don't bother doing anything
        -- when that happens.
        if not label then return end
  
        -- The SwitchToWorkspace action will switch us to a workspace if it already exists,
        -- otherwise it will create it for us.
        win:perform_action(wezterm.action.SwitchToWorkspace {
          -- We'll give our new workspace a nice name, like the last path segment
          -- of the directory we're opening up.
          name = label:match("([^/]+)$"),
          -- Here's the meat. We'll spawn a new terminal with the current working
          -- directory set to the directory that was picked.
          spawn = { cwd = label },
        }, pane)
      end),
    }
  end

return module