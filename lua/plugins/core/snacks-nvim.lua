local snacks_indent = require("utils.snacks.indent")
local snacks_explorer_preview = require("utils.snacks.explorer_preview")

require("snacks").setup({
  bigfile = { enabled = true },
  debug = { enabled = true },
  explorer = { enabled = true },
  gh = { enabled = true },
  gitbrowse = {
    open = function(url)
      if vim.fn.has("nvim-0.10") == 0 or SYSTEM.is_win then
        require("lazy.util").open(url, { system = true })
        return
      end
      vim.ui.open(url)
    end,
  },
  image = { enabled = not SYSTEM.is_win },
  indent = snacks_indent,
  input = { enabled = false },  -- for uniform ui
  notifier = {
    enabled = true,
    timeout = 3000,
    margin = { top = 0, right = 1, bottom = 0 },
    top_down = false,
    style = "fancy",
    date_format = "%H:%M:%S",
  },
  picker = snacks_explorer_preview,
  quickfile = { enabled = true },
  scope = { enabled = true },
  scroll = { enabled = true },
  statuscolumn = { enabled = true },
  styles = { notification = { wo = { wrap = true }, border = "rounded" } },
  words = { enabled = true },
})

-- file
vim.keymap.set("n", "<leader>ff", function() Snacks.picker.files() end, { desc = "Find Files" })
vim.keymap.set("n", "<leader>fr", function() Snacks.picker.recent() end, { desc = "Recent" })
vim.keymap.set("n", "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, { desc = "Find Config File" })
vim.keymap.set("n", "<leader>fp", function() Snacks.picker.projects() end, { desc = "Projects" })
vim.keymap.set("n", "<leader>fg", function() Snacks.picker.git_files() end, { desc = "Find Git Files" })
vim.keymap.set("n", "<leader>ft", function() Snacks.picker.todo_comments({ buffers = true }) end, { desc = "Todo (Buffers)" })
vim.keymap.set("n", "<leader>fT", function() Snacks.picker.todo_comments({ keywords = { "FIX", "TODO" }, buffers = true }) end, { desc = "Todo/Fix (Buffers)" })
-- grep
vim.keymap.set("n", "<leader>/l", function() Snacks.picker.lines() end, { desc = "Lines" })
vim.keymap.set("n", "<leader>/b", function() Snacks.picker.grep_buffers() end, { desc = "Buffers" })
vim.keymap.set({ "n", "x" }, "<leader>/w", function() Snacks.picker.grep_word() end, { desc = "Word" })
vim.keymap.set("n", "<leader>//", function() Snacks.picker.grep() end, { desc = "Grep" })
-- search
vim.keymap.set("n", "<leader><space>", function() Snacks.picker.smart() end, { desc = "Smart Find Files" })
vim.keymap.set("n", "<leader>.", function() Snacks.scratch() end, { desc = "Scratch" })
vim.keymap.set({ "n", "v" }, "<leader>s:", function() Snacks.picker.command_history() end, { desc = "Command History" })
vim.keymap.set("n", "<leader>z", function() Snacks.picker.zoxide() end, { desc = "Zoxide" })
vim.keymap.set("n", '<leader>s"', function() Snacks.picker.registers() end, { desc = "Registers" })
vim.keymap.set("n", '<leader>s.', function() Snacks.scratch.select() end, { desc = "Scratch" })
vim.keymap.set("n", '<leader>s/', function() Snacks.picker.search_history() end, { desc = "Search History" })
vim.keymap.set("n", "<leader>sb", function() Snacks.picker.buffers() end, { desc = "Buffers" })
vim.keymap.set("n", "<leader>sc", function() Snacks.picker.commands() end, { desc = "Commands" })
vim.keymap.set("n", "<leader>sd", function() Snacks.picker.diagnostics_buffer() end, { desc = "Diagnostics (buffer)" })
vim.keymap.set("n", "<leader>sD", function() Snacks.picker.diagnostics() end, { desc = "Diagnostics" })
vim.keymap.set("n", "<leader>sh", function() Snacks.picker.help() end, { desc = "Help Pages" })
vim.keymap.set("n", "<leader>si", function() Snacks.picker.icons() end, { desc = "Icons" })
vim.keymap.set("n", "<leader>sI", function() Snacks.picker.lsp_incoming_calls() end, { desc = "Incoming Calls" })
vim.keymap.set("n", "<leader>sJ", function() Snacks.picker.jumps() end, { desc = "Jumps" })
vim.keymap.set("n", "<leader>sk", function() Snacks.picker.keymaps() end, { desc = "Keymaps" })
vim.keymap.set("n", "<leader>sl", function() Snacks.picker.lsp_config() end, { desc = "Lsp Info" })
vim.keymap.set("n", "<leader>sL", function() Snacks.picker.lazy() end, { desc = "Search for Plugin Spec" })
vim.keymap.set("n", "<leader>sm", function() Snacks.picker.marks() end, { desc = "Marks" })
vim.keymap.set("n", "<leader>sO", function() Snacks.picker.lsp_outgoing_calls() end, { desc = "Outgoing Calls" })
vim.keymap.set("n", "<leader>sp", function() Snacks.picker.spelling() end, { desc = "Spelling" })
vim.keymap.set("n", "<leader>sP", function() Snacks.picker() end, { desc = "Pickers" })
vim.keymap.set("n", "<leader>sr", function() Snacks.picker.resume() end, { desc = "Resume" })
vim.keymap.set("n", "<leader>st", function() Snacks.picker.todo_comments() end, { desc = "Todo" })
vim.keymap.set("n", "<leader>sT", function() Snacks.picker.todo_comments({ keywords = { "FIX", "TODO" } }) end, { desc = "Todo/Fix" })
vim.keymap.set("n", "<leader>su", function() Snacks.picker.undo() end, { desc = "Undotree" })
vim.keymap.set("n", "<leader>sv", function() Snacks.picker.cliphist() end, { desc = "Clipboard History" })
-- LSP
vim.keymap.set("n", "<leader>ss", function() Snacks.picker.lsp_symbols() end, { desc = "LSP Symbols" })
vim.keymap.set("n", "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, { desc = "LSP Symbols (workspace)" })
vim.keymap.set("n", "gd", function() Snacks.picker.lsp_definitions() end, { desc = "Goto Definition" })
vim.keymap.set("n", "gD", function() Snacks.picker.lsp_declarations() end, { desc = "Goto Declaration" })
vim.keymap.set("n", "gr", function() Snacks.picker.lsp_references() end, { nowait = true, desc = "References" })
vim.keymap.set("n", "gI", function() Snacks.picker.lsp_implementations() end, { desc = "Goto Implementation" })
vim.keymap.set("n", "gy", function() Snacks.picker.lsp_type_definitions() end, { desc = "Goto T[y]pe Definition" })
-- git
vim.keymap.set({ "n", "v" }, "<leader>gg", function() Snacks.gitbrowse.open() end, { desc = "Github Browse" })
vim.keymap.set("n", "<leader>ghi", function() Snacks.picker.gh_issue() end, { desc = "GitHub Issues (open)" })
vim.keymap.set("n", "<leader>ghI", function() Snacks.picker.gh_issue({ state = "all" }) end, { desc = "GitHub Issues (all)" })
vim.keymap.set("n", "<leader>ghp", function() Snacks.picker.gh_pr() end, { desc = "GitHub Pull Requests (open)" })
vim.keymap.set("n", "<leader>ghP", function() Snacks.picker.gh_pr({ state = "all" }) end, { desc = "GitHub Pull Requests (all)" })
-- terminal
vim.keymap.set({ "n", "t" }, "<C-/>", function() Snacks.terminal(nil, { win = { height = 0.3, position = "bottom" } }) end, { desc = "Open Terminal" })
vim.keymap.set({ "n", "t" }, "<C-_>", function() Snacks.terminal(nil, { win = { height = 0.3, position = "bottom" } }) end, { desc = "Open Terminal" })
vim.keymap.set({ "n", "t" }, "<leader>tt", function() Snacks.terminal(nil, { win = { height = 0.3, position = "bottom" } }) end, { desc = "Open Terminal (Bottom)" })
vim.keymap.set({ "n", "t" }, "<leader>tv", function() Snacks.terminal(nil, { win = { position = "right" } }) end, { desc = "Open Terminal (Right)" })
vim.keymap.set({ "n", "t" }, "<leader>tf", function() Snacks.terminal(nil, { win = { position = "float" } }) end, { desc = "Open Terminal (Float)" })
-- ui
vim.keymap.set("n", "<leader>nn", function() Snacks.notifier.show_history() end, { desc = "Notification history" })
vim.keymap.set("n", "<leader>un", function() Snacks.notifier.hide() end, { desc = "Dismiss all notifications" })
vim.keymap.set("n", "<leader>es", function() Snacks.explorer() end, { desc = "File Explorer" })
vim.keymap.set("n", "<leader>uc", function() Snacks.picker.colorschemes() end, { desc = "Colorschemes" })
vim.keymap.set("n", "<leader>h", function() Snacks.dashboard() end, { desc = "Home Page" })
-- dev
vim.keymap.set({ "n", "v" }, "<leader>Dr", function() Snacks.debug.run() end, { desc = "Run Lua" })

-- Create some toggle mappings
Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.dim():map("<leader>uD")
Snacks.toggle.inlay_hints():map("<leader>uh")
Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>ul")
Snacks.toggle.line_number():map("<leader>uL")
Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
Snacks.toggle.zoom():map("<leader>uz")
Snacks.toggle.zen():map("<leader>uZ")
Snacks.toggle({
  name = "Git Signs",
  get = function()
    return vim.g._minidiff_enabled ~= false
  end,
  set = function(state)
    vim.g._minidiff_enabled = state
    require("mini.diff").toggle()
  end,
}):map("<leader>ug")

