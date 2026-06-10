require("utils.lazy").load({
  setup = function()
    require("outline").setup()
  end,
  keys = {
    { "n", "<leader>o", function () vim.cmd("Outline") end, { desc = "Toggle Outline" } },
  },
  cmd = { "Outline" }
})
