local colors = require("utils.heirline.colors")

local M = {}

M = {
  condition = function()
    return vim.bo.filetype == "python"
  end,

  init = function(self)
    local ok, vs = pcall(require, "venv-selector")
    if not ok then
      self.source = nil
      self.python = nil
      self.workspace_path = nil
      return
    end

    self.source = vs.source()
    self.python = vs.python()
    local paths = vs.workspace_paths()
    self.workspace_path = paths and paths[1] or nil
  end,

  provider = function(self)
    if self.source == "workspace" or self.source == "cwd" then
      if self.workspace_path == nil then
        return ""
      end
      return " " .. vim.fs.basename(vim.fs.normalize(self.workspace_path)) .. " "
    elseif self.source == "anaconda_base" then
      return " " .. vim.fs.basename(vim.fs.dirname(vim.fs.normalize(self.python))) .. " "
    end

    return self.python or ""
  end,

  hl = function(self)
    if self.source == "workspace" or self.source == "cwd" then
      return { fg = colors.yellow }
    elseif self.source == "anaconda_base" then
      return { fg = colors.green }
    end
  end,
}

return M
