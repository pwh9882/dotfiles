local function get_backend()
  local term = vim.env.TERM_PROGRAM or ""
  -- WezTerm, Kitty, Ghostty 등 Kitty graphics protocol 지원 터미널
  if term:match("WezTerm") or term:match("kitty") or term:match("ghostty") then
    return "kitty"
  end
  -- Linux에서 위 터미널이 아니면 ueberzug 폴백
  if vim.fn.has("linux") == 1 then
    return "ueberzug"
  end
  return "kitty"
end

return {
  {
    "3rd/image.nvim",
    ft = { "markdown", "norg", "png", "jpg", "jpeg", "gif", "bmp", "webp" },
    event = "BufReadPre *.png,*.jpg,*.jpeg,*.gif,*.bmp,*.webp",
    opts = {
      backend = get_backend(),
      integrations = {
        markdown = { enabled = true },
      },
    },
  },
}
