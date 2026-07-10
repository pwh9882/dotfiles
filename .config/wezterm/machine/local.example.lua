-- Copy this file to local.lua. The destination is gitignored.
-- Keep addresses, usernames, identity paths, personal project paths, and
-- private host labels in local.lua rather than the shared configuration.
local wezterm = require 'wezterm'

return {
    ssh_domains = {
        {
            name = 'example',
            remote_address = 'host.example:22',
            username = 'user',
            ssh_option = { identityfile = '~/.ssh/example_ed25519' },
            connect_automatically = false,
        },
    },

    project_globs = {
        wezterm.home_dir .. '/work/*',
    },

    project_paths = {
        wezterm.home_dir .. '/work/example',
    },

    host_colors = {
        example = '#74c7ec',
    },

    host_os = {
        example = 'linux',
    },
}
