local logger = require("logger")

local Defaults = {
    async = true,
    timeout = 2000,
    formatting_params = {},
    create_autocmd = true,
    augroup_name = "lspformatter_augroup",
    autocmd_event = "BufWritePre",
    debug = false,
}
local Configs = {}

local FORMATTING_METHOD = "textDocument/formatting"

local function get_client_name(client)
    if client then
        return tostring(client.name) .. "-" .. tostring(client.id)
    else
        return "unknown-?"
    end
end

local function setup(option)
    Configs = vim.tbl_deep_extend("force", vim.deepcopy(Defaults), option or {})
    logger.setup({
        name = "lspformatter",
        level = Configs.debug and "DEBUG" or "WARN",
    })
    vim.api.nvim_create_augroup(Configs.augroup_name, {})
end

local function async_format(bufnr, option)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    vim.lsp.buf_request(
        bufnr,
        FORMATTING_METHOD,
        vim.lsp.util.make_formatting_params(option.formatting_params or {}),
        function(err, res, ctx)
            if err then
                local err_msg = type(err) == "string" and err or err.message
                logger.error("Failed to format code with error %s", err_msg)
                return
            end

            local bufnr_not_found = not vim.api.nvim_buf_is_loaded(bufnr)
            local bufnr_modified =
                vim.api.nvim_buf_get_option(bufnr, "modified")
            local in_insert_mode =
                vim.startswith(vim.api.nvim_get_mode().mode, "i")

            -- don't apply results if buffer is unloaded or has been modified
            if bufnr_not_found or bufnr_modified or in_insert_mode then
                logger.debug(
                    "Ignore code format for bufnr not found(%s), modified(%s), inserting(%s)",
                    vim.inspect(bufnr_not_found),
                    vim.inspect(bufnr_modified),
                    vim.inspect(in_insert_mode)
                )
                return
            end

            local client = vim.lsp.get_client_by_id(ctx.client_id)
            if res then
                logger.debug(
                    "Apply code format result on client %s",
                    get_client_name(client)
                )
                vim.lsp.util.apply_text_edits(
                    res,
                    bufnr,
                    client and client.offset_encoding or "utf-16"
                )
                vim.api.nvim_buf_call(bufnr, function()
                    vim.cmd("silent noautocmd update")
                end)
            else
                logger.debug(
                    "Empty code format result on client %s",
                    get_client_name(client)
                )
            end
        end
    )
end

local function sync_format(bufnr, option)
    vim.lsp.buf.format({ async = false, bufnr = bufnr })
end

local function on_attach(client, bufnr, option)
    option = vim.tbl_deep_extend("force", vim.deepcopy(Configs), option or {})

    logger.debug("Client %s enter bufnr %d", get_client_name(client), bufnr)
    if client.supports_method(FORMATTING_METHOD) then
        logger.debug(
            "Client %s on attach bufnr %d",
            get_client_name(client),
            bufnr
        )
        vim.api.nvim_clear_autocmds({
            group = option.augroup_name,
            buffer = bufnr,
        })
        vim.api.nvim_create_autocmd(option.autocmd_event, {
            group = option.augroup_name,
            buffer = bufnr,
            callback = function()
                if option.async then
                    async_format(bufnr, option)
                else
                    sync_format(bufnr, option)
                end
            end,
        })
    end
end

local M = {
    setup = setup,
    on_attach = on_attach,
}

return M
