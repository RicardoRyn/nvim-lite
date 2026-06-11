vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.keymap.set({ "n", "v" }, "x", "<Nop>", { desc = "Reserved for hop.nvim" })
vim.keymap.set({ "n", "v" }, "s", "<Nop>", { desc = "Reserved for persistence.nvim" })
vim.keymap.set("v", "U", "<Nop>", { desc = "Disable U in visual mode" })
vim.keymap.set("v", "u", "<Nop>", { desc = "Disable u in visual mode" })

vim.keymap.set("v", "<", "<gv", { desc = "Outdent and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent and reselect" })
vim.keymap.set({ "n", "v" }, "E", "$", { desc = "Go to end of line" })
vim.keymap.set({ "n", "v" }, "B", "^", { desc = "Go to beginning of line" })

vim.keymap.set(
  "n",
  "<leader>ur",
  "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>",
  { desc = "UI redraw" }
)
vim.keymap.set({ "i" }, "jk", "<Esc>", { desc = "Exit insert mode" })
vim.keymap.set({ "n", "v" }, "j", "gj", { desc = "Next visual line" })
vim.keymap.set({ "n", "v" }, "k", "gk", { desc = "Previous visual line" })
vim.keymap.set({ "n", "v" }, "gj", "j", { desc = "Next actual line" })
vim.keymap.set({ "n", "v" }, "gk", "k", { desc = "Previous actual line" })

vim.keymap.set("v", "<C-c>", '"+y', { desc = "Copy to system clipboard" })
vim.keymap.set("i", "<C-v>", "<C-r>+", { noremap = true, silent = true, desc = "Paste from system clipboard" })

vim.keymap.set("n", "<C-Up>", "<Cmd>resize -2<CR>", { desc = "Decrease window height" })
vim.keymap.set("n", "<C-Down>", "<Cmd>resize +2<CR>", { desc = "Increase window height" })
vim.keymap.set("n", "<C-Left>", "<Cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", "<Cmd>vertical resize +2<CR>", { desc = "Increase window width" })
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Navigate Left", remap = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Navigate Down", remap = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Navigate Up", remap = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Navigate Right", remap = true })

-- -- replace by snacks
-- vim.keymap.set("n", "<leader>su", function()
--   vim.cmd([[packadd nvim.undotree]])
--   require("undotree").open()
-- end, { desc = "Undotree" })

if vim.g.neovide then
  -- Paste from system clipboard (works in all modes)
  vim.keymap.set({ "n", "v", "s", "x", "o", "i", "l", "c", "t" }, "<C-S-v>", function()
    vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
  end, { noremap = true, silent = true, desc = "Paste from system clipboard" })
end
