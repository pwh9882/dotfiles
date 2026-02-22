-- plugins.lua — macOS-only: resurrect + workspace_switcher
local wezterm = require 'wezterm'
local M = {}

function M.apply(config)
    local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
    local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
    local projects_ok, projects = pcall(require, 'projects')

    -- ---- Plugin keybindings ----

    -- Workspace switcher
    table.insert(config.keys, { key = 'f', mods = 'LEADER', action = workspace_switcher.switch_workspace() })
    table.insert(config.keys, { key = 's', mods = 'LEADER', action = workspace_switcher.switch_workspace() })
    table.insert(config.keys, { key = 'S', mods = 'LEADER', action = workspace_switcher.switch_to_prev_workspace() })

    -- Resurrect keybindings
    table.insert(config.keys, { key = 'w', mods = 'ALT', action = wezterm.action_callback(function(win, pane)
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
    end)})
    table.insert(config.keys, { key = 'W', mods = 'ALT', action = resurrect.window_state.save_window_action() })
    table.insert(config.keys, { key = 'T', mods = 'ALT', action = resurrect.tab_state.save_tab_action() })
    table.insert(config.keys, { key = 's', mods = 'ALT', action = wezterm.action_callback(function(win, pane)
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
        resurrect.window_state.save_window_action()
    end)})
    table.insert(config.keys, { key = 'o', mods = 'ALT', action = wezterm.action_callback(function(win, pane)
        resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
            local type = string.match(id, "^([^/]+)")
            id = string.match(id, "([^/]+)$")
            id = string.match(id, "(.+)%..+$")
            local opts = {
                relative = true,
                restore_text = true,
                close_open_tabs = true,
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
    end)})
    table.insert(config.keys, { key = 'd', mods = 'ALT', action = wezterm.action_callback(function(win, pane)
        resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id)
                resurrect.state_manager.delete_state(id)
            end,
            {
                title = "Delete State",
                description = "Select State to Delete and press Enter = accept, Esc = cancel, / = filter",
                fuzzy_description = "Search State to Delete: ",
                is_fuzzy = true,
            })
    end)})

    -- ---- Event handlers ----

    wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
        local base_path = string.gsub(path, "(.*[/\\])(.*)", "%2")
        local gui_window = window:gui_window()
        if gui_window then
            gui_window:set_right_status(wezterm.format({
                { Attribute = { Intensity = "Bold" } },
                { Foreground = { Color = "magenta" } },
                { Text = base_path .. "  " },
            }))
        end
        local state = resurrect.state_manager.load_state(label, "workspace")
        if state then
            resurrect.workspace_state.restore_workspace(state, {
                window = window,
                relative = true,
                restore_text = true,
                resize_window = false,
                close_open_tabs = true,
                on_pane_restore = resurrect.tab_state.default_on_pane_restore,
            })
        else
            local tab = window:active_tab()
            local pane = tab:active_pane()
            pane:send_text("cd " .. path .. "\n")
        end
    end)

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

    wezterm.on("smart_workspace_switcher.workspace_switcher.selected", function(window, path, label)
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
        resurrect.state_manager.write_current_state(label, "workspace")
    end)

    wezterm.on("augment-command-palette", function(window, pane)
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
                            resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
                        end
                    end),
                }),
            },
        }
    end)

    wezterm.on("smart_workspace_switcher.workspace_switcher.start", function(window)
        local current_workspace = wezterm.mux.get_active_workspace()
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state(), current_workspace)
        resurrect.state_manager.write_current_state(current_workspace, "workspace")

        local tab = window:active_tab()
        if tab then
            local pane = tab:active_pane()
            if pane and projects_ok and projects.record_current_as_recent then
                pcall(function() projects.record_current_as_recent(pane) end)
            end
        end
    end)

    wezterm.on("smart_workspace_switcher.workspace_switcher.canceled", function(window)
        wezterm.log_info("Workspace switching canceled")
    end)

    -- ---- Resurrect configuration ----
    resurrect.state_manager.periodic_save({
        interval_seconds = 15 * 60,
        save_workspaces = true,
        save_windows = true,
        save_tabs = true,
    })
    wezterm.on("gui-startup", resurrect.state_manager.resurrect_on_gui_startup)
    resurrect.state_manager.set_max_nlines(1000)

    wezterm.on("resurrect.error", function(err)
        wezterm.log_error("Resurrect error: " .. err)
        local windows = wezterm.gui.gui_windows()
        if #windows > 0 then
            windows[1]:toast_notification("Resurrect", err, nil, 3000)
        end
    end)

    -- ---- Workspace switcher configuration ----
    workspace_switcher.workspace_formatter = function(label)
        return wezterm.format({
            { Attribute = { Italic = true } },
            { Foreground = { Color = "green" } },
            { Text = "󱂬 : " .. label },
        })
    end
    config.default_workspace = "~"
    workspace_switcher.apply_to_config(config)
end

return M
