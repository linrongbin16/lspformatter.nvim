# lspformatter.nvim

A code formatter using lsp for Neovim.

Note: this plugin will not install any formatter for you, we suggest install
formatters via a lsp installer, e.g. [mason.nvim](https://github.com/williamboman/mason.nvim).

Thanks to [lsp-format.nvim](https://github.com/lukas-reineke/lsp-format.nvim)
and [null-ls's wiki - Format on save](https://github.com/jose-elias-alvarez/null-ls.nvim/wiki/Formatting-on-save),
I read most of their source code and write this plugin.

## Requirement

- Neovim &ge; 0.8.
- [logger.nvim](https://github.com/linrongbin16/logger.nvim).

## Installation

### Lazy

```lua
{
    "linrongbin16/lspformatter.nvim",
    dependencies = "linrongbin16/logger.nvim",
    config = function()
        require('lspformatter').setup()
    end,
},
```

## Usage

Attach when setup lsp client:

```lua
lspconfig.tsserver.setup({on_attach = require("lspformatter").on_attach})

lspconfig[lsp].setup({
    on_attach = function(client, bufnr)
        require("lspformatter").on_attach(client, bufnr)
    end,
})
```

## Configuration

```lua
require('lspformatter').setup({
    -- Async format.
    async = true,

    -- Only apply null-ls formatting changes.
    null_ls_only = false,

    -- Timeout on wait formatting result in milliseconds.
    timeout = 2000,

    -- Formatting parameters.
    formatting_params = {},

    -- Create auto command.
    create_autocmd = true,

    -- Auto command group name.
    augroup_name = "lspformatter_augroup",

    -- Auto command event.
    autocmd_event = "BufWritePost",

    -- Enable debug.
    debug = false,

    -- Print log to file.
    file_log = false,

    -- Log file name, working with `file_log=true`.
    file_log_name = "lspformatter.log",
})
```
