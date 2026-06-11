require("vim._core.ui2").enable({})

_G.SYSTEM = require("utils.system")

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.pack")
require("config.lsp")

require("utils.autopair")
require("utils.debug")
require("utils.sessions")
