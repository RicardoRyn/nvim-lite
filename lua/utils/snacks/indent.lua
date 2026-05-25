local M = {
  enabled = true,
  indent = {
    char = "▏",
    hl = {
      "DiagnosticError",
      "Function",
      "String",
      "Special",
      "Constant",
      "Statement",
      "DiffDelete",
    },
  },
  scope = { char = "▍", hl = "" },
}

return M
