---@class LazySpec
---@field setup fun()                     Called once, on first trigger.
---@field keys? table[]                   Key specs: { mode, lhs, rhs, opts? }.
---@field cmd? string[]|table[]           Command specs.
---   String form:  "Telescope"           -- shadow cmd, triggers load then replays
---   Table form:   { "Telescope", fun(args), opts? }

local M = {}

local function key_loader(spec)
  for _, key in ipairs(spec.keys or {}) do
    vim.keymap.set(key[1], key[2], function()
      spec.load()
      return key[3]()
    end, key[4] or {})
  end
end

local function cmd_loader(spec)
  for _, cmd in ipairs(spec.cmd or {}) do
    if type(cmd) == "string" then
      -- shadow command: catches the first invocation, loads the plugin, then replays.
      vim.api.nvim_create_user_command(cmd, function(args)
        spec.load()
        pcall(vim.api.nvim_del_user_command, cmd)
        vim.cmd(cmd .. (args.args ~= "" and " " .. args.args or ""))
      end, { desc = "[lazy] " .. cmd })
    else
      -- table form: { name, handler, opts }
      local name = cmd[1]
      local handler = cmd[2]
      local opts = cmd[3] or {}
      vim.api.nvim_create_user_command(name, function(args)
        spec.load()
        return handler(args)
      end, opts)
    end
  end
end

--- Load a plugin lazily via keys and/or commands.
--- All triggers share a single `load` guard so setup() only runs once.
---
--- Usage:
---   require("utils.lazy").load({
---     setup = function() require("telescope").setup({ ... }) end,
---     keys  = { { "n", "<leader>ff", function() ... end, { desc = "Find files" } } },
---     cmd   = { "Telescope", "FindFiles" },  -- or: { { "Telescope", handler, opts } }
---   })
---
---@param spec LazySpec
---@return fun() load  Call this to force eager-loading.
function M.load(spec)
  local loaded = false

  local function load()
    if loaded then
      return
    end
    spec.setup()
    loaded = true
  end

  if spec.keys then
    key_loader({ load = load, keys = spec.keys })
  end

  if spec.cmd then
    cmd_loader({ load = load, cmd = spec.cmd })
  end

  return load
end

return M
