-- Import the wezterm module
local wezterm = require 'wezterm'
local appearance = require 'appearance'
local projects = require 'projects'
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")

-- Creates a config object which we will be adding our config to
local config = wezterm.config_builder()

config.set_environment_variables = {
    PATH = '/opt/homebrew/bin:' .. os.getenv('PATH')
}

-- Notification when the configuration is reloaded
local function toast(window, message)
    window:toast_notification('wezterm', message .. ' - ' .. os.date('%I:%M:%S %p'), nil, 1000)
end

--(This is where our config will go)
-- Find them here: https://wezfurlong.org/wezterm/colorschemes/index.html

-- Use it!
-- if appearance.is_not_dark() then
--   config.color_scheme = 'Github'
-- else
--   config.color_scheme = 'Github Dark (Gogh)'
-- end
config.color_scheme = 'Github Dark (Gogh)'

-- Override colors to make text more white (but not harsh)
config.colors = {
    foreground = '#e6edf3',  -- GitHub's soft white (recommended)
    -- Other great options:
    -- '#f0f6fc' - Very soft white (GitHub light)
    -- '#f8f8f2' - Monokai Pro white (warm)
    -- '#eff1f5' - Catppuccin Latte white
    -- '#e5e9f0' - Nord Snow Storm (cool tone)
    -- '#fdf6e3' - Solarized base3 (cream white)
}

config.font = wezterm.font('JetBrainsMonoNL Nerd Font')
config.font_size = 13


-- Slightly transparent and blurred background
config.window_background_opacity = 0.85
config.macos_window_background_blur = 30
-- Removes the title bar, leaving only the tab bar. Keeps
-- the ability to resize by dragging the window's edges.
-- On macOS, 'RESIZE|INTEGRATED_BUTTONS' also looks nice if
-- you want to keep the window controls visible and integrate
-- them into the tab bar.
config.window_decorations = 'RESIZE'
-- Sets the font for the window frame (tab bar)
config.window_frame = {
    -- Berkeley Mono for me again, though an idea could be to try a
    -- serif font here instead of monospace for a nicer look?
    font = wezterm.font({ family = 'Berkeley Mono', weight = 'Bold' }),
    font_size = 11,
}


local function segments_for_right_status(window)
    return {
        window:active_workspace(),
        wezterm.strftime('%a %b %-d %H:%M'),
        wezterm.hostname(),
    }
end

wezterm.on('update-status', function(window, _)
    local SOLID_LEFT_ARROW = utf8.char(0xe0b2)
    local segments = segments_for_right_status(window)

    local color_scheme = window:effective_config().resolved_palette
    -- Note the use of wezterm.color.parse here, this returns
    -- a Color object, which comes with functionality for lightening
    -- or darkening the colour (amongst other things).
    local bg = wezterm.color.parse(color_scheme.background)
    local fg = color_scheme.foreground

    -- Each powerline segment is going to be coloured progressively
    -- darker/lighter depending on whether we're on a dark/light colour
    -- scheme. Let's establish the "from" and "to" bounds of our gradient.
    local gradient_to, gradient_from = bg
    if appearance.is_not_dark() then
        gradient_from = gradient_to:darken(0.2)
    else
        gradient_from = gradient_to:lighten(0.2)
    end

    -- Yes, WezTerm supports creating gradients, because why not?! Although
    -- they'd usually be used for setting high fidelity gradients on your terminal's
    -- background, we'll use them here to give us a sample of the powerline segment
    -- colours we need.
    local gradient = wezterm.color.gradient(
        {
            orientation = 'Horizontal',
            colors = { gradient_from, gradient_to },
        },
        #segments -- only gives us as many colours as we have segments.
    )

    -- We'll build up the elements to send to wezterm.format in this table.
    local elements = {}

    for i, seg in ipairs(segments) do
        local is_first = i == 1

        if is_first then
            table.insert(elements, { Background = { Color = 'none' } })
        end
        table.insert(elements, { Foreground = { Color = gradient[i] } })
        table.insert(elements, { Text = SOLID_LEFT_ARROW })

        table.insert(elements, { Foreground = { Color = fg } })
        table.insert(elements, { Background = { Color = gradient[i] } })
        table.insert(elements, { Text = ' ' .. seg .. ' ' })
    end

    window:set_right_status(wezterm.format(elements))
end)


-- Table mapping keypresses to actions
local bind = function(mods, key, action)
    table.insert(config.keys, {
        key = key,
        mods = mods,
        action = action,
    })
end

local function move_pane(key, direction)
    return {
        key = key,
        mods = 'LEADER',
        action = wezterm.action.ActivatePaneDirection(direction),
    }
end

local function resize_pane(key, direction)
    return {
        key = key,
        action = wezterm.action.AdjustPaneSize { direction, 3 }
    }
end


-- If you're using emacs you probably wanna choose a different leader here,
-- since we're gonna be making it a bit harder to CTRL + A for jumping to
-- the start of a line
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }


config.keys = {
    -- Sends ESC + b and ESC + f sequence, which is used
    -- for telling your shell to jump back/forward.
    {
        -- When the left arrow is pressed
        key = 'LeftArrow',
        -- With the "Option" key modifier held down
        mods = 'OPT',
        -- Perform this action, in this case - sending ESC + B
        -- to the terminal
        action = wezterm.action.SendString '\x1bb',
    },
    {
        key = 'RightArrow',
        mods = 'OPT',
        action = wezterm.action.SendString '\x1bf',
    },
    -- send ctrl + a and ctrl + e to the start and end of the line
    { mods = "CMD",     key = "LeftArrow",  action = wezterm.action.SendKey({ mods = "CTRL", key = "a" }) },
    { mods = "CMD",     key = "RightArrow", action = wezterm.action.SendKey({ mods = "CTRL", key = "e" }) },
    { mods = "CMD",     key = "Backspace",  action = wezterm.action.SendKey({ mods = "CTRL", key = "u" }) },
    -- activate tab relative to the current tab
    { mods = 'CMD|ALT', key = 'LeftArrow',  action = wezterm.action.ActivateTabRelative(-1) },
    { mods = 'CMD|ALT', key = 'RightArrow', action = wezterm.action.ActivateTabRelative(1) },
    -- open nvim in new tab
    {
        key = ',',
        mods = 'SUPER',
        action = wezterm.action.SpawnCommandInNewTab {
            cwd = wezterm.home_dir,
            args = { 'nvim', wezterm.config_file },
        },
    },
    -- split panes
    {
        -- I'm used to tmux bindings, so am using the quotes (") key to
        -- split horizontally, and the percent (%) key to split vertically.
        key = '"',
        -- Note that instead of a key modifier mapped to a key on your keyboard
        -- like CTRL or ALT, we can use the LEADER modifier instead.
        -- This means that this binding will be invoked when you press the leader
        -- (CTRL + A), quickly followed by quotes (").
        mods = 'LEADER',
        action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
    },
    {
        key = '%',
        mods = 'LEADER',
        action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
    },

    {
        key = 'a',
        -- When we're in leader mode _and_ CTRL + A is pressed...
        mods = 'LEADER|CTRL',
        -- Actually send CTRL + A key to the terminal
        action = wezterm.action.SendKey { key = 'a', mods = 'CTRL' },
    },
    -- move_pane('ㅗ', 'Left'),
    -- move_pane('ㅓ', 'Down'),
    -- move_pane('ㅏ', 'Up'),
    -- move_pane('ㅣ', 'Right'),
    move_pane('phys:h', 'Left'),
    move_pane('phys:j', 'Down'),
    move_pane('phys:k', 'Up'),
    move_pane('phys:l', 'Right'),
    move_pane('LeftArrow', 'Left'),
    move_pane('DownArrow', 'Down'),
    move_pane('UpArrow', 'Up'),
    move_pane('RightArrow', 'Right'),

    {
        -- When we push LEADER + R...
        key = 'r',
        mods = 'LEADER',
        -- Activate the `resize_panes` keytable
        action = wezterm.action.ActivateKeyTable {
            name = 'resize_panes',
            -- Ensures the keytable stays active after it handles its
            -- first keypress.
            one_shot = false,
            -- Deactivate the keytable after a timeout.
            timeout_milliseconds = 1000,
        }
    },

    -- project picker
    {
        key = 'p',
        mods = 'LEADER',
        -- Present in to our project picker
        action = projects.choose_project(),
    },
    -- workspace picker using leader+f
    {
        key = 'f',
        mods = 'LEADER',
        -- Change from ShowLauncherArgs to use workspace_switcher instead
        action = workspace_switcher.switch_workspace(),
    },

    -- Smart workspace switcher keybinding
    {
        key = 's',
        mods = 'LEADER',
        action = workspace_switcher.switch_workspace(),
    },
    {
        key = 'S',
        mods = 'LEADER',
        action = workspace_switcher.switch_to_prev_workspace(),
    },

    -- Resurrect keybindings
    -- Save workspace state
    {
        key = 'w',
        mods = 'ALT',
        action = wezterm.action_callback(function(win, pane)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
        end),
    },
    -- Save window state
    {
        key = 'W',
        mods = 'ALT',
        action = resurrect.window_state.save_window_action(),
    },
    -- Save tab state
    {
        key = 'T',
        mods = 'ALT',
        action = resurrect.tab_state.save_tab_action(),
    },
    -- Save both workspace and window state
    {
        key = 's',
        mods = 'ALT',
        action = wezterm.action_callback(function(win, pane)
            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
            resurrect.window_state.save_window_action()
        end),
    },
    -- Restore state with fuzzy finder
    {
        key = 'o',
        mods = 'ALT',
        action = wezterm.action_callback(function(win, pane)
            resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
                local type = string.match(id, "^([^/]+)") -- match before '/'
                id = string.match(id, "([^/]+)$") -- match after '/'
                id = string.match(id, "(.+)%..+$") -- remove file extension
                local opts = {
                    relative = true,
                    restore_text = true,
                    close_open_tabs = true, -- Close existing tabs
                    on_pane_restore = resurrect.tab_state.default_on_pane_restore,
                }
                if type == "workspace" then
                    local state = resurrect.state_manager.load_state(id, "workspace")
                    resurrect.workspace_state.restore_workspace(state, opts)
                elseif type == "window" then
                    local state = resurrect.state_manager.load_state(id, "window")
                    resurrect.window_state.restore_window(pane:window(), state, opts)
                elseif type == "tab" then
                    local state = resurrect.state_manager.load_state(id, "tab")
                    resurrect.tab_state.restore_tab(pane:tab(), state, opts)
                end
            end)
        end),
    },
    -- Delete state with fuzzy finder
    {
        key = 'd',
        mods = 'ALT',
        action = wezterm.action_callback(function(win, pane)
            resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id)
                    resurrect.state_manager.delete_state(id)
                end,
                {
                    title = "Delete State",
                    description = "Select State to Delete and press Enter = accept, Esc = cancel, / = filter",
                    fuzzy_description = "Search State to Delete: ",
                    is_fuzzy = true,
                })
        end),
    },
}


config.key_tables = {
    resize_panes = {
        resize_pane('j', 'Down'),
        resize_pane('k', 'Up'),
        resize_pane('h', 'Left'),
        resize_pane('l', 'Right'),
    },
}

-- Improved integration between workspace_switcher and resurrect
-- Loads the state whenever a new workspace is created
wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
    local base_path = string.gsub(path, "(.*[/\\])(.*)", "%2")
    -- Update the right status
    local gui_window = window:gui_window()
    if gui_window then
        gui_window:set_right_status(wezterm.format({
            { Attribute = { Intensity = "Bold" } },
            { Foreground = { Color = "magenta" } },
            { Text = base_path .. "  " },
        }))
    end

    -- Restore workspace state
    local workspace_state = resurrect.workspace_state
    local state = resurrect.state_manager.load_state(label, "workspace")
    if state then
        workspace_state.restore_workspace(state, {
            window = window,
            relative = true,
            restore_text = true,
            resize_window = false, -- Helps with window sizing issues
            close_open_tabs = true, -- Close existing tabs
            on_pane_restore = resurrect.tab_state.default_on_pane_restore,
        })
    else
        -- If no saved state, create a new tab with the project directory
        local tab = window:active_tab()
        local pane = tab:active_pane()
        pane:send_text("cd " .. path .. "\n")
    end
end)

-- Update the status when a workspace is chosen
wezterm.on("smart_workspace_switcher.workspace_switcher.chosen", function(window, path, label)
    local base_path = string.gsub(path, "(.*[/\\])(.*)", "%2")
    local gui_window = window:gui_window()
    if gui_window then
        gui_window:set_right_status(wezterm.format({
            { Attribute = { Intensity = "Bold" } },
            { Foreground = { Color = "magenta" } },
            { Text = base_path .. "  " },
        }))
    end
end)

-- Save state when a workspace is selected
wezterm.on("smart_workspace_switcher.workspace_switcher.selected", function(window, path, label)
    local workspace_state = resurrect.workspace_state
    resurrect.state_manager.save_state(workspace_state.get_workspace_state())
    -- Write the current state for startup restoration
    resurrect.state_manager.write_current_state(label, "workspace")
end)

-- Add workspace commands to the command palette
wezterm.on("augment-command-palette", function(window, pane)
    local workspace_state = resurrect.workspace_state
    return {
        {
            brief = "Window | Workspace: Switch Workspace",
            icon = "md_briefcase_arrow_up_down",
            action = workspace_switcher.switch_workspace(),
        },
        {
            brief = "Window | Workspace: Switch to Previous Workspace",
            icon = "md_briefcase_restore",
            action = workspace_switcher.switch_to_prev_workspace(),
        },
        {
            brief = "Window | Workspace: Rename Workspace",
            icon = "md_briefcase_edit",
            action = wezterm.action.PromptInputLine({
                description = "Enter new name for workspace",
                action = wezterm.action_callback(function(window, pane, line)
                    if line then
                        wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
                        resurrect.state_manager.save_state(workspace_state.get_workspace_state())
                    end
                end),
            }),
        },
    }
end)

-- Configure resurrect
-- Optional: Enable encryption for saved state (recommended for security)
-- You need to generate a key first with: age-keygen -o key.txt
-- Then uncomment and configure the below:
--[[
resurrect.state_manager.set_encryption({
  enable = true,
  method = "age", -- Default encryption method
  private_key = os.getenv("HOME") .. "/.config/wezterm/age_key.txt", -- Path to your private key
  public_key = "age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", -- Your public key
})
--]]

-- Enable periodic saving with custom options
resurrect.state_manager.periodic_save({
    interval_seconds = 15 * 60, -- 15 minutes
    save_workspaces = true,
    save_windows = true,
    save_tabs = true,
})

-- Enable session restoration on startup with custom handler
wezterm.on("gui-startup", resurrect.state_manager.resurrect_on_gui_startup)

-- Limit the number of lines saved per pane (improves performance)
resurrect.state_manager.set_max_nlines(1000)

-- Handle resurrect errors with notifications
wezterm.on("resurrect.error", function(err)
    wezterm.log_error("Resurrect error: " .. err)
    local windows = wezterm.gui.gui_windows()
    if #windows > 0 then
        windows[1]:toast_notification("Resurrect", err, nil, 3000)
    end
end)

-- Customize workspace_switcher
workspace_switcher.workspace_formatter = function(label)
    return wezterm.format({
        { Attribute = { Italic = true } },
        { Foreground = { Color = "green" } },
        { Text = "󱂬 : " .. label },
    })
end

-- Set default workspace if needed
config.default_workspace = "~"

-- Apply default configuration to workspace_switcher
workspace_switcher.apply_to_config(config)

-- Override specific save/restore behavior for optimal integration
wezterm.on("smart_workspace_switcher.workspace_switcher.start", function(window)
    -- Save current workspace state before switching
    local current_workspace = wezterm.mux.get_active_workspace()
    local workspace_state = resurrect.workspace_state
    resurrect.state_manager.save_state(workspace_state.get_workspace_state(), current_workspace)
    resurrect.state_manager.write_current_state(current_workspace, "workspace")
    wezterm.log_info("Workspace switcher started, saved state for: " .. current_workspace)
end)

-- Log canceled event
wezterm.on("smart_workspace_switcher.workspace_switcher.canceled", function(window)
    wezterm.log_info("Workspace switching canceled")
end)

-- Custom window title formatting
wezterm.on("format-window-title", function(tab, pane, tabs, panes, config)
    local zoomed = ""
    if tab.active_pane.is_zoomed then
        zoomed = " "
    end

    local index = ""
    if #tabs > 1 then
        index = string.format("(%d/%d) ", tab.tab_index + 1, #tabs)
    end

    return zoomed .. index .. tab.active_pane.title
end)

-- Resurrect plugin keybindings documentation:
-- ALT+w - Save workspace state
-- ALT+W - Save window state
-- ALT+T - Save tab state
-- ALT+s - Save both workspace and window state
-- ALT+o - Open (restore) state with fuzzy finder
-- ALT+d - Delete saved state with fuzzy finder
--
-- The plugin also automatically saves workspace state every 15 minutes
-- and restores your session on startup.

-- Smart workspace switcher keybindings:
-- LEADER+s - Switch workspace using fuzzy finder with zoxide integration
-- LEADER+S - Switch to previous workspace
--
-- The smart workspace switcher is integrated with resurrect to automatically
-- save workspace state when switching and restore it when creating new workspaces.

-- Returns our config to be evaluated. We must always do this at the bottom of this file
return config
