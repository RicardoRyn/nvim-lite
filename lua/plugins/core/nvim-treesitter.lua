local languages = {
  "lua",
  "python",
  "bash",
  "rust",
  "diff",
  "json",
  "markdown",
  "markdown_inline",
  "css",
  "html",
  "javascript",
  "latex",
  "scss",
  "svelte",
  "tsx",
  "typst",
  "vue",
  "regex",
}

vim.schedule(function()
  require("nvim-treesitter").setup()
  require("nvim-treesitter").install(languages)
end)

vim.api.nvim_create_autocmd("FileType", {
  pattern = languages,
  callback = function()
    vim.treesitter.start()
  end,
})
