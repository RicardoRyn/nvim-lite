local special_mode = require("utils.special_mode")

local session_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "sessions")
vim.fn.mkdir(session_dir, "p")

local fname = vim.fn.substitute(vim.fn.getcwd(), "[/\\\\:]", "%%", "g") .. ".vim"
local session_file = vim.fs.joinpath(session_dir, fname)

vim.api.nvim_create_autocmd("VimEnter", {
  nested = true,
  callback = function()
    if special_mode.is_active() then
      return
    end
    if vim.fn.argc() == 0 and vim.fn.filereadable(session_file) == 1 then
      vim.cmd("source " .. vim.fn.fnameescape(session_file))
    end
  end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("SetupSession", { clear = true }),
  callback = function()
    if special_mode.is_active() then
      return
    end
    vim.cmd("mksession! " .. vim.fn.fnameescape(session_file))
  end,
})
