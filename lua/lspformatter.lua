local logger = require("lspformatter.logger")

local FORMATTING_METHOD = "textDocument/formatting"
local CHANGEDTICK = "changedtick"
local LSPFORMATTER_CHANGEDTICK = "lspformatter_changedtick"
local NULL_LS = "null-ls"

-- configs {

--- @type table<string, any>
local Defaults = {
    async = true,
    null_ls_only = false,
    timeout = 2000,
    formatting_params = {},
    augroup = "lspformatter_augroup",
    debug = false,
    console_log = true,
    file_log = false,
}
--- @type table<string, any>
local Configs = {}

-- }

-- utils {

--- @class LspClient
--- @field name string
--- @field id integer
--- @field supports_method fun(method:string):boolean

--- @param client LspClient
--- @return string
local function client_util_get_name(client)
    return client and tostring(client.name) or "unknown"
end

--- @param client LspClient
--- @return string
local function client_util_get_id(client)
    return client and tostring(client.id) or "?"
end

--- @param client LspClient
--- @return string
local function client_util_get_symbol(client)
    return string.format(
        "[%s-%d]",
        client_util_get_name(client),
        client_util_get_id(client)
    )
end

--- @type table<string, function>
local ClientUtil = {
    get_name = client_util_get_name,
    get_id = client_util_get_id,
    get_symbol = client_util_get_symbol,
}

--- @type table<string, function>
local BufferUtil = {
    --- @param bufnr integer
    --- @return string
    get_name = function(bufnr)
        return bufnr and string.format("buffer-%d", bufnr)
            or string.format("buffer-?")
    end,
}

-- }

--- @param option table<string, any>
--- @return nil
local function setup(option)
    Configs = vim.tbl_deep_extend("force", vim.deepcopy(Defaults), option or {})
    logger.setup({
        level=Configs.debug and "DEBUG" or "WARN",
        console=Configs.console_log,
        file=Configs.file_log,
    })
    vim.api.nvim_create_augroup(Configs.augroup, {})
end

--- @param bufnr integer
--- @param option table<string, any>
--- @return nil
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
                logger.error(
                    "Failed to format code on %s with error %s",
                    BufferUtil.get_name(bufnr),
                    err_msg
                )
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
                and ClientUtil.get_name(client) ~= NULL_LS

            -- don't apply results if buffer is unloaded or has been modified
            if
                bufnr_not_found
                or bufnr_modified
                or in_insert_mode
                or changedtick_not_match
                or filter_null_ls
            then
                logger.debug(
                    "Ignore code format because bufnr not found(%s), modified(%s), inserting(%s), changedtick not match(%s), filter null-ls(%s)",
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
                    "Apply code format result on %s, %s",
                    ClientUtil.get_symbol(client),
                    BufferUtil.get_name(bufnr)
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
                    "Empty code format result on %s, %s",
                    ClientUtil.get_symbol(client),
                    BufferUtil.get_name(bufnr)
                )
            end
        end
    )
end

--- @param bufnr integer
--- @param option table<string, any>
--- @return nil
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

--- @param client LspClient
--- @param bufnr integer
--- @param option table<string, any>
--- @return nil
local function on_attach(client, bufnr, option)
    option = vim.tbl_deep_extend("force", vim.deepcopy(Configs), option or {})

    logger.debug(
        "%s attach %s with option %s",
        ClientUtil.get_symbol(client),
        BufferUtil.get_name(bufnr),
        vim.inspect(option)
    )
    if client.supports_method(FORMATTING_METHOD) then
        logger.debug(
            "%s attach %s on protocol %s",
            ClientUtil.get_symbol(client),
            BufferUtil.get_name(bufnr),
            FORMATTING_METHOD
        )
        vim.api.nvim_clear_autocmds({
            group = option.augroup,
            buffer = bufnr,
        })
        if option.async then
            vim.api.nvim_create_autocmd("BufWritePost", {
                group = option.augroup,
                buffer = bufnr,
                callback = function()
                    async_format(bufnr, option)
                end,
            })
        else
            vim.api.nvim_create_autocmd("BufWritePre", {
                group = option.augroup,
                buffer = bufnr,
                callback = function()
                    sync_format(bufnr, option)
                end,
            })
        end
    else
        logger.debug(
            "%s failed to attach %s on protocol %s",
            ClientUtil.get_symbol(client),
            BufferUtil.get_name(bufnr),
            FORMATTING_METHOD
        )
    end
end

--- @type table<string, function>
local M = {
    setup = setup,
    on_attach = on_attach,
}

return M