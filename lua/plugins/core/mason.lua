local my_languages = {
  -- lua
  "lua-language-server",
  "stylua",
  -- python
  "pyright",
  "debugpy",
  "ruff",
  -- rust
  "rust-analyzer",
  "codelldb",
  -- MARKDOWN
  "marksman", -- LSP (语法高亮、补全、跳转)
  "prettierd", -- 格式化
}

require("mason").setup({
  ensure_installed = my_languages,
})

local mr = require("mason-registry")

local function ensure_installed()
  for _, tool in ipairs(my_languages) do
    local p = mr.get_package(tool)
    if not p:is_installed() then
      p:install()
    end
  end
end

if mr.refresh then
  mr.refresh(ensure_installed)
else
  ensure_installed()
end

vim.lsp.enable("lua_ls")
vim.lsp.enable("pyright")
vim.lsp.enable("rust_analyzer")
