require("utils.lazy").load({
  setup = function()
    dd("")
    require("venv-selector").setup({
      search = {
        anaconda_base = {
          command = SYSTEM.is_win and "fd python.exe$ E:/python/envs --max-depth 2 --full-path --color never -HI -a -L"
            or "fd /python$ ~/miniforge3/envs --max-depth 3 --full-path --color never -E /proc",
          type = "anaconda",
        },
        cwd = {
          command = SYSTEM.is_win and "fd python.exe$ $CWD/.venv/Scripts --full-path --color never -HI -a -L"
            or "fd '/bin/python$' $CWD --full-path --color never -E /proc -I -a -L",
        },
      },
    })
  end,
  keys = {
    { "n", "<leader>lv", function() vim.cmd("VenvSelect") end, { desc = "Virtual Env" }, },
  },
})
