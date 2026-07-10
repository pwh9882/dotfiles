-- Public loader for optional, machine-local WezTerm data.
-- Copy machine/local.example.lua to machine/local.lua and keep the latter
-- untracked. Shared config must remain useful when no local overlay exists.
local wezterm = require 'wezterm'

local ok, value = pcall(require, 'machine.local')
if not ok then
    local message = tostring(value)
    if not message:match("module 'machine%.local' not found") then
        wezterm.log_error('machine/local.lua could not be loaded: ' .. message)
    end
    return {}
end

if type(value) ~= 'table' then
    wezterm.log_error('machine/local.lua must return a table')
    return {}
end

return value
