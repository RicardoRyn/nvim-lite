require("utils.lazy").load({
  setup = function()
    require("hunk").setup()
  end,
  cmd = { "DiffEditor", "MergeEditor" },
})
