-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- LazyVim은 SSH_CONNECTION이 있으면 clipboard를 비활성화하지만,
-- Tailscale 등으로 SSH_CONNECTION이 세팅된 환경에서도 클립보드 사용
vim.opt.clipboard = "unnamedplus"

-- OSC 52: tmux/SSH를 통해 로컬 터미널(WezTerm)의 시스템 클립보드로 전달
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
    ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
  },
}
