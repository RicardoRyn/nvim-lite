vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    -- UI
    vim.g.diagnostics_visible = true
    vim.diagnostic.config({
      virtual_text = true,
      underline = true,
      update_in_insert = true,
      signs = false,
    })

    -- complete
    vim.opt.completeopt = { "fuzzy", "menu", "menuone", "noinsert", "noselect", "popup" }
    vim.opt.complete:append("o")
    vim.api.nvim_create_autocmd({ "BufEnter", "InsertEnter", "FileType" }, {
      group = vim.api.nvim_create_augroup("AutocompleteFilter", { clear = true }),
      callback = function()
        local buftype = vim.bo.buftype
        local filetype = vim.bo.filetype
        if buftype == "prompt" or buftype == "nofile" or filetype == "snacks_picker_input" then
          vim.o.autocomplete = false
        else
          vim.o.autocomplete = true
        end
      end,
    })
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client:supports_method("textDocument/completion") and vim.lsp.completion then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end
    vim.opt.pumblend = 0 -- menu transparency
    vim.opt.pumborder = "single"

    -- cmdline complete
    vim.opt.wildoptions = "fuzzy,pum"
    vim.opt.wildmode = "noselect:lastused"
    local cmdline_cmp_group = vim.api.nvim_create_augroup("NativeCmdlineCmp", { clear = true })
    vim.api.nvim_create_autocmd("CmdlineChanged", {
      group = cmdline_cmp_group,
      pattern = { ":", "/", "?" },
      callback = function()
        vim.fn.wildtrigger()
      end,
    })

    -- mapping
    vim.keymap.set("n", "<leader>lR", function()
      vim.notify("Restarting LSP...", vim.log.levels.INFO)
      vim.cmd("lsp restart")
      vim.notify("LSP restarted", vim.log.levels.INFO)
    end, { desc = "Restart LSP" })
    vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { desc = "Code Actions" })
    vim.keymap.set("n", "<leader>ld", function()
      vim.diagnostic.open_float()
    end, { desc = "Show Diagnostics (line)" })
    vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { desc = "Rename Symbol" })
    vim.keymap.set("n", "<leader>ls", function()
      vim.lsp.buf.document_symbol()
    end, { desc = "Document Symbols" })
    vim.keymap.set("i", "<C-k>", function()
      vim.lsp.buf.signature_help()
    end, { desc = "Show Signature Help" })
  end,
})
