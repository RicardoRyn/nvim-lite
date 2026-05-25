vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup("SetupHeirline", { clear = true }),
  once = true,
  callback = function()
    local colors = require("utils.heirline.colors")
    local Align = { provider = "%=" }
    local Statusline = require("utils.heirline.statusline")
    local Tabline = require("utils.heirline.tabline")
    local bc = require("utils.buffer_actions")

    require("heirline").setup({
      opts = {
        colors = colors,
      },
      statusline = {
        Statusline.vim_mode,
        Statusline.work_dir.CurrentDir,
        Statusline.file_others,
        Statusline.file_name_block,
        Statusline.jj.Diff,
        Statusline.cmdline.MacroRec,
        Align,
        Align,
        Statusline.cmdline.SelectionCount,
        Statusline.cmdline.SearchCount,
        Statusline.dap_messages,
        Statusline.ai,
        Statusline.lsp.LSPActive,
        Statusline.diagnostics,
        Statusline.cursor_position.Ruler,
        Statusline.cursor_position.ScrollBar,
        Statusline.jj.JjLog,
      },
      tabline = {
        Tabline.tabline_offset,
        Tabline.bufferline,
        Tabline.tabpages,
      },
    })

    vim.keymap.set("n", "<S-h>", function() require("utils.buffer_actions").cycle(-1) end, { desc = "Buffer prev" })
    vim.keymap.set("n", "<S-l>", function() require("utils.buffer_actions").cycle(1) end, { desc = "Buffer next" })

    vim.keymap.set("n", "<leader>ba", function() Snacks.bufdelete.all() end, { desc = "Buffers delete all " })
    vim.keymap.set("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Buffer delete" })
    vim.keymap.set("n", "<leader>bo", function() Snacks.bufdelete.other() end, { desc = "Buffer delete other" })

    vim.keymap.set("n", "<leader>bl", function() require("utils.buffer_actions").close_in_direction("left") end, { desc = "Close buffers to the Left" })
    vim.keymap.set("n", "<leader>br", function() require("utils.buffer_actions").close_in_direction("right") end, { desc = "Close buffers to the Right" })

    vim.keymap.set("n", "<leader>b<", function() require("utils.buffer_actions").move(-1) end, { desc = "Move buffer left" })
    vim.keymap.set("n", "<leader>b>", function() require("utils.buffer_actions").move(1) end, { desc = "Move buffer right" })

  end,
})
