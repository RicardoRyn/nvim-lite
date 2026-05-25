---@class KeyLoaderSpec
---@field setup fun()  Called once, on first keypress
---@field keys? { [1]: string|string[], [2]: string, [3]: function, [4]: table }[]
---   Positional: mode, lhs, rhs, opts.
---   opts is a table forwarded directly to vim.keymap.set (desc, expr, silent, etc.).

---@param spec KeyLoaderSpec
---@return fun() ensure
return function(spec)
  local loaded = false

  local function ensure()
    if loaded then return end
    spec.setup()
    loaded = true
  end

  for _, key in ipairs(spec.keys or {}) do
    vim.keymap.set(key[1], key[2], function()
      ensure()
      return key[3]()
    end, key[4] or {})
  end

  return ensure
end
