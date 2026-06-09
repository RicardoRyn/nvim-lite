local specs = {
  { src = "https://github.com/catppuccin/nvim" },
  { src = "https://github.com/neovim-treesitter/nvim-treesitter" },
  { src = "https://github.com/neovim-treesitter/treesitter-parser-registry" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
  { src = "https://github.com/mason-org/mason.nvim.git" },
  { src = "https://github.com/neovim/nvim-lspconfig" },
  { src = "https://github.com/folke/snacks.nvim" },
  { src = "https://github.com/nvim-mini/mini.icons" },
  { src = "https://github.com/nvim-mini/mini.surround" },
  { src = "https://github.com/kevinhwang91/nvim-ufo.git" },
  { src = "https://github.com/kevinhwang91/promise-async" },
  { src = "https://github.com/rebelot/heirline.nvim" },
  { src = "https://github.com/nvim-mini/mini.diff" },
  { src = "https://github.com/folke/todo-comments.nvim" },
  { src = "https://github.com/mfussenegger/nvim-dap" },
  { src = "https://github.com/mfussenegger/nvim-dap-python" },
  { src = "https://github.com/igorlfs/nvim-dap-view" },
  { src = "https://github.com/jbyuki/one-small-step-for-vimkind" },
  { src = "https://github.com/zbirenbaum/copilot.lua" },
  { src = "https://github.com/nvim-mini/mini.files" },
  { src = "https://github.com/stevearc/conform.nvim" },
  { src = "https://github.com/folke/sidekick.nvim" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/folke/flash.nvim" },
  { src = "https://github.com/nicolasgb/jj.nvim" },
  { src = "https://github.com/julienvincent/hunk.nvim" },
}

vim.pack.add(specs)

local function get_plugin_names(arg_lead)
  local installed = vim.pack.get(nil, { info = false })
  local names = {}
  for _, p in ipairs(installed) do
    local name = p.spec.name
    if name:lower():find(arg_lead:lower(), 1, true) == 1 then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

local function load_plugins()
  local files = vim.api.nvim_get_runtime_file("lua/plugins/**/*.lua", true)
  for _, file in ipairs(files) do
    local normalized_file = file:gsub("\\", "/")
    local module_path = normalized_file:match("lua/(plugins/.*)%.lua$")
    if module_path then
      local module_name = module_path:gsub("/", ".")
      local ok, err = pcall(require, module_name)
      if not ok then
        vim.notify("Failed load module: " .. module_name .. "\n" .. tostring(err), vim.log.levels.ERROR)
      end
    end
  end
end

vim.api.nvim_create_user_command("PackUpdate", function(opts)
  local targets = #opts.fargs > 0 and opts.fargs or nil
  local force = opts.bang
  if targets then
    vim.notify("Checking updates for: " .. table.concat(targets, ", "), vim.log.levels.INFO)
  else
    vim.notify("Checking updates for all plugins...", vim.log.levels.INFO)
  end
  vim.pack.update(targets, { force = force })
end, {
  nargs = "*",
  bang = true, -- support ! for force update
  complete = get_plugin_names,
  desc = "Update plugins (use ! to skip confirmation)",
})

vim.api.nvim_create_user_command("PackDel", function(opts)
  vim.pack.del(opts.fargs)
end, { nargs = "+", complete = get_plugin_names, desc = "Delete plugins" })

vim.api.nvim_create_user_command("PackStatus", function(opts)
  local targets = #opts.fargs > 0 and opts.fargs or nil
  vim.pack.update(targets, { offline = true })
end, {
  nargs = "*",
  complete = get_plugin_names,
  desc = "Check plugins status without downloading",
})

vim.keymap.set("n", "<leader>P", "<cmd>PackStatus<cr>", { desc = "Pack status" })

load_plugins()
