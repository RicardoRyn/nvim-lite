require("utils.lazy").load({
  setup = function()
    dd("outline loaded")
    require("outline").setup()
  end,
  keys = {
    { "n", "<leader>o", function () vim.cmd("Outline") end, { desc = "Toggle Outline" } },
  },
  cmd = { "Outline" }
})
