local sep = vim.fn.has("win32") == 1 and "\\" or "/"
local session_dir = vim.fn.stdpath("state") .. sep .. "sessions"
vim.fn.mkdir(session_dir, "p")
local fname = vim.fn.substitute(vim.fn.getcwd(), "[/\\\\:]", "%%", "g") .. ".vim"
local session_file = session_dir .. sep .. fname
vim.api.nvim_create_autocmd("VimEnter", {
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 and vim.fn.filereadable(session_file) == 1 then
      vim.cmd("source " .. vim.fn.fnameescape(session_file))
    end
  end,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("SetupSession", { clear = true }),
  callback = function()
    vim.cmd("mksession! " .. vim.fn.fnameescape(session_file))
  end,
})
