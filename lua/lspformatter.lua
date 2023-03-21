local logger = require("logger")

local Defaults = {
    async = true,
    null_ls_only = false,
    timeout = 2000,
    formatting_params = {},
    create_autocmd = true,
    augroup_name = "lspformatter_augroup",
    debug = false,
    file_log = false,
    file_log_name = "lspformatter.log",
}
local Configs = {}

local FORMATTING_METHOD = "textDocument/formatting"
local CHANGEDTICK = "changedtick"
local LSPFORMATTER_CHANGEDTICK = "lspformatter_changedtick"
local NULL_LS = "null-ls"

local function get_client_name(client)
    return client and tostring(client.name) or "unknown"
end

local function get_client_id(client)
    return client and tostring(client.id) or "?"
end

local function get_client_title(client)
    return string.format(
        "[%s-%d]",
        get_client_name(client),
        get_client_id(client)
    )
end

local function setup(option)
    Configs = vim.tbl_deep_extend("force", vim.deepcopy(Defaults), option or {})
    logger.setup({
        name = "lspformatter",
        level = Configs.debug and "DEBUG" or "WARN",
        file = Configs.file_log,
        file_name = Configs.file_log_name,
    })
    vim.api.nvim_create_augroup(Configs.augroup_name, {})
end

local function async_format(bufnr, option)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    -- save changedtick
    vim.api.nvim_buf_set_var(
        bufnr,
        LSPFORMATTER_CHANGEDTICK,
        vim.api.nvim_buf_get_var(bufnr, CHANGEDTICK)
    )

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

            local client = vim.lsp.get_client_by_id(ctx.client_id)

            local bufnr_not_found = not vim.api.nvim_buf_is_loaded(bufnr)
            local bufnr_modified =
                vim.api.nvim_buf_get_option(bufnr, "modified")
            local in_insert_mode =
                vim.startswith(vim.api.nvim_get_mode().mode, "i")
            local changedtick_not_match = vim.api.nvim_buf_get_var(
                ctx.bufnr,
                LSPFORMATTER_CHANGEDTICK
            ) ~= vim.api.nvim_buf_get_var(ctx.bufnr, CHANGEDTICK)
            local filter_null_ls = option.null_ls_only
                and get_client_name(client) ~= NULL_LS

            -- don't apply results if buffer is unloaded or has been modified
            if
                bufnr_not_found
                or bufnr_modified
                or in_insert_mode
                or changedtick_not_match
                or filter_null_ls
            then
                logger.debug(
                    "Ignore code format for bufnr not found(%s), modified(%s), inserting(%s), changedtick not match(%s), filter null-ls(%s)",
                    vim.inspect(bufnr_not_found),
                    vim.inspect(bufnr_modified),
                    vim.inspect(in_insert_mode),
                    vim.inspect(changedtick_not_match),
                    vim.inspect(filter_null_ls)
                )
                return
            end

            if res then
                logger.debug(
                    "Apply code format result on client %s",
                    get_client_title(client)
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
                    get_client_title(client)
                )
            end
        end
    )
end

local function sync_format(bufnr, option)
    vim.lsp.buf.format({
        async = false,
        bufnr = bufnr,
        timeout_ms = option.timeout,
        formatting_options = vim.lsp.util.make_formatting_params(
            option.formatting_params or {}
        ),
    })
end

local function on_attach(client, bufnr, option)
    option = vim.tbl_deep_extend("force", vim.deepcopy(Configs), option or {})

    logger.debug(
        "Client %s attach bufnr %d with option %s",
        get_client_title(client),
        bufnr,
        vim.inspect(option)
    )
    if client.supports_method(FORMATTING_METHOD) then
        logger.debug(
            "Client %s on attach bufnr %d",
            get_client_title(client),
            bufnr
        )
        vim.api.nvim_clear_autocmds({
            group = option.augroup_name,
            buffer = bufnr,
        })
        if option.async then
            vim.api.nvim_create_autocmd("BufWritePost", {
                group = option.augroup_name,
                buffer = bufnr,
                callback = function()
                    async_format(bufnr, option)
                end,
            })
        else
            vim.api.nvim_create_autocmd("BufWritePre", {
                group = option.augroup_name,
                buffer = bufnr,
                callback = function()
                    sync_format(bufnr, option)
                end,
            })
        end
    end
end

local M = {
    setup = setup,
    on_attach = on_attach,
}

return M
