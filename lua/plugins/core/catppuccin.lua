require("catppuccin").setup({
  flavour = "auto", -- latte, frappe, macchiato, mocha, auto
  background = {
    light = "latte",
    dark = "mocha",
  },
  auto_integrations = true,
})

vim.cmd.colorscheme("catppuccin")
