-- WezTerm unified configuration (macOS + Windows)
-- Managed by dotfiles — on WSL, synced to Windows via .config/init.sh
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ---- Platform Detection ----
local is_windows = wezterm.target_triple:find('-windows-') ~= nil
local is_macos   = wezterm.target_triple:find('-apple-')   ~= nil

-- ---- Modules ----
local theme = require 'theme'
local keys = require 'keys'

-- ---- Appearance ----
config.color_scheme = 'Github Dark (Gogh)'
config.font = wezterm.font('JetBrainsMonoNL Nerd Font')
config.window_padding = { left = 16, right = 16, top = 16, bottom = 16 }
config.window_decorations = 'RESIZE'

config.use_fancy_tab_bar = false
config.tab_max_width = 30
config.warn_about_missing_glyphs = false

if is_macos then
    config.font_size = 13
    config.window_background_opacity = 0.85
    config.macos_window_background_blur = 30
    config.set_environment_variables = {
        PATH = '/opt/homebrew/bin:' .. os.getenv('PATH')
    }
else
    config.font_size = 10
    config.window_background_opacity = 0.95
    config.command_palette_font_size = 10
end

-- ---- Apply modules ----
theme.apply(config, is_macos)
keys.apply(config, is_macos)

if is_macos then
    local ok, plugins = pcall(require, 'plugins')
    if ok then plugins.apply(config) end

    config.ssh_domains = {
        {
            name = 'ddps',
            remote_address = 'ddpssrv1.ddps.cloud:33021',
            username = 'whpark',
            ssh_option = { identityfile = '~/.ssh/ddps-srv-1_ed25519' },
            connect_automatically = false,
        },
        {
            name = 'ddps0',
            remote_address = 'srv2.ddps.cloud:33022',
            username = 'whpark',
            ssh_option = { identityfile = '~/.ssh/ddps-srv-1_ed25519' },
            connect_automatically = false,
        },
        {
            name = 'norm',
            remote_address = 'normalize.duckdns.org',
            ssh_option = { identityfile = '/Users/woohyeok/local/oracleA1/ssh-key-2024-09-04.key' },
            username = 'ubuntu',
        },
        {
            name = 'mini-ts',
            remote_address = '100.74.23.65',
            username = 'woohyeok',
            remote_wezterm_path = '/opt/homebrew/bin/wezterm',
        },
        {
            name = 'uci-gpu',
            remote_address = '100.114.244.128',
            username = 'hyunwooo',
        },
    }
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
