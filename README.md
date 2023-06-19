# lspformatter.nvim

A Neovim code formatter using lsp.

Note: this plugin will not install any formatter for you, we suggest install
formatters via a lsp installer, e.g. [mason.nvim](https://github.com/williamboman/mason.nvim).
And register formatters via [null-ls](https://github.com/jose-elias-alvarez/null-ls.nvim).

**Thanks to [lsp-format.nvim](https://github.com/lukas-reineke/lsp-format.nvim)
and [null-ls's wiki - Format on save](https://github.com/jose-elias-alvarez/null-ls.nvim/wiki/Formatting-on-save),
I learned everything from them and also copied their source code to this plugin.**

## Requirement

- Neovim &ge; 0.8.

## Installation

### Lazy

```lua
{
    "linrongbin16/lspformatter.nvim",
    config = function()
        require('lspformatter').setup()
    end,
},
```

## Usage

Attach lspformatter to lsp setup handler with API
`require('lspformatter').on_attach(client, bufnr, option)`:

```lua
-- for specific lsp: tsserver
lspconfig.tsserver.setup({on_attach = require("lspformatter").on_attach})

-- for any lsp
lspconfig["tsserver"].setup({
    on_attach = function(client, bufnr)
        require("lspformatter").on_attach(client, bufnr)
    end,
})
```

Notice: `client` and `bufnr` are standard lsp `on_attach` function parameters.
And there's an optional parameter `option` (lua table), share the same schema
with `setup` (See [Configuration](#configuration)) function. So you can use
different configuration for different lsp setup handlers.

## Configuration

```lua
require('lspformatter').setup({
    -- Async format.
    async = true,

    -- Only apply null-ls formatting changes.
    null_ls_only = false,

    -- Timeout on wait formatting result in milliseconds.
    -- This config only apply to sync format.
    timeout = 2000,

    -- Formatting parameters.
    formatting_params = {},

    -- Auto command group name.
    augroup = "lspformatter_augroup",

    -- Enable debug.
    debug = false,

    -- Print log to console, e.g. command line.
    console_log = true,

    -- Print log to file.
    file_log = false,
})
```
