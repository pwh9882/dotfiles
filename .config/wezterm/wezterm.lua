-- WezTerm unified configuration (macOS + Windows)
-- Managed by dotfiles — on WSL, synced to Windows via .config/init.sh
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ---- Platform Detection ----
local is_windows = wezterm.target_triple:find('-windows-') ~= nil
local is_macos   = wezterm.target_triple:find('-apple-')   ~= nil

-- ---- Modules ----
local machine = require 'machine_config'
local theme = require 'theme'
local keys = require 'keys'

-- ---- Appearance ----
config.color_scheme = 'Github Dark (Gogh)'
config.font = wezterm.font('JetBrainsMonoNL Nerd Font')
config.window_padding = { left = 16, right = 16, top = 16, bottom = 16 }
config.window_decorations = 'RESIZE'

config.use_fancy_tab_bar = false
config.tab_max_width = 60
config.warn_about_missing_glyphs = false
-- Milliseconds. Keep the status renderer off the hot path; it only renders
-- cached pane metadata and does not need sub-second polling.
config.status_update_interval = 1000

-- ---- Rendering (120Hz 고주사율 대응; 모니터 refresh rate를 안 넘게 자동 캡) ----
config.max_fps = 120
config.animation_fps = 60

if is_macos then
    config.font_size = 13
    config.window_background_opacity = 0.85
    config.macos_window_background_blur = 30
    -- Apple Silicon: Metal 직접 사용 (OpenGL→Metal 변환 레이어 회피)
    config.front_end = 'WebGpu'
    config.set_environment_variables = {
        PATH = '/opt/homebrew/bin:' .. os.getenv('PATH')
    }
else
    config.font_size = 10
    config.window_background_opacity = 0.95
    config.command_palette_font_size = 10
end

-- ---- Apply modules ----
theme.apply(config, is_macos, machine)
keys.apply(config, is_macos)

if is_macos then
    local ok, plugins = pcall(require, 'plugins')
    if ok then plugins.apply(config) end

end

-- SSH domain identity paths in the current overlay are POSIX/macOS-specific.
-- Windows can keep its own machine/local.lua when a Windows schema is added.
if is_macos and machine.ssh_domains and #machine.ssh_domains > 0 then
    config.ssh_domains = machine.ssh_domains
end

-- ---- Windows-only: WSL domain & launch menu ----
if is_windows then
    config.default_domain = 'WSL:Ubuntu-24.04'
    config.launch_menu = {
        { label = 'PowerShell', args = { 'powershell.exe' }, domain = { DomainName = 'local' } },
        { label = 'CMD', args = { 'cmd.exe' }, domain = { DomainName = 'local' } },
    }
end

return config
