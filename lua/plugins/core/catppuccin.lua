require("catppuccin").setup({
  flavour = "auto", -- latte, frappe, macchiato, mocha, auto
  background = {
    light = "latte",
    dark = "mocha",
  },
  transparent_background = false,
  float = {
    transparent = true,
    solid = true,
  },
  auto_integrations = true,
  integrations = {
    avante = false,
  },
})

vim.cmd.colorscheme("catppuccin")
