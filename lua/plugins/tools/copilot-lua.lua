vim.api.nvim_create_autocmd("InsertEnter", {
  group = vim.api.nvim_create_augroup("SetupCopilot", { clear = true }),
  callback = function()
    require("copilot").setup({
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<C-y>",
          accept_word = "<C-w>",
          accept_line = false,
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<Esc>",
        },
      },
      -- 由sidekick接管NES
      nes = { enabled = false },
    })
  end,
})
