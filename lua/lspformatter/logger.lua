--- @type string
local PathSeparator = (vim.fn.has("win32") or vim.fn.has("win64")) and "\\"
    or "/"
--- @type string
local LogFilePath = vim.fn.stdpath("data")
    .. PathSeparator
    .. "lspformatter.log"

--- @alias LogLevelEnum "ERROR"|"WARN"|"INFO"|"DEBUG"
--- @alias EchoHlEnum "ErrorMsg"|"WarningMsg"|"None"|"Comment"
--- @type table<LogLevelEnum, EchoHlEnum>
local EchoHl = {
    ["ERROR"] = "ErrorMsg",
    ["WARN"] = "WarningMsg",
    ["INFO"] = "None",
    ["DEBUG"] = "Comment",
}
--- @type table<string, LogLevelEnum|boolean>
local Defaults = {
    --- @type LogLevelEnum
    level = "INFO",
    --- @type boolean
    console = true,
    --- @type boolean
    file = false,
}
--- @type table<string, LogLevelEnum|boolean>
local Config = {}

--- @param option table<string, LogLevelEnum|boolean>
local function setup(option)
    --- @type table<string, LogLevelEnum|boolean>
    Config = vim.tbl_deep_extend("force", vim.deepcopy(Defaults), option or {})
    assert(type(Config.level) == "string" and EchoHl[Config.level] ~= nil)
end

--- @param level LogLevelEnum
--- @param msg string
--- @return nil
local function log(level, msg)
    if vim.log.levels[level] < vim.log.levels[Config.level] then
        return
    end

    local splited_messages = vim.split(msg, "\n")
    if Config.console then
        vim.cmd("echohl " .. EchoHl[level])
        for _, m in ipairs(splited_messages) do
            vim.cmd(string.format('echom "%s"', vim.fn.escape(m, '"')))
        end
        vim.cmd("echohl None")
    end
    if Config.file then
        local fp = io.open(LogFilePath, "a")
        if fp then
            for _, line in ipairs(splited_messages) do
                fp:write(
                    string.format(
                        "%s [%s] - %s\n",
                        os.date("%Y-%m-%d %H:%M:%S"),
                        level,
                        line
                    )
                )
            end
            fp:close()
        end
    end
end

--- @alias LogApiType fun(fmt:string, ...:any):nil
--- @type LogApiType
local function debug(fmt, ...)
    log("DEBUG", string.format(fmt, ...))
end

--- @type LogApiType
local function info(fmt, ...)
    log("INFO", string.format(fmt, ...))
end

--- @type LogApiType
local function warn(fmt, ...)
    log("WARN", string.format(fmt, ...))
end

--- @type LogApiType
local function error(fmt, ...)
    log("ERROR", string.format(fmt, ...))
end

--- @type table<string, LogApiType|function>
local M = {
    setup = setup,
    debug = debug,
    info = info,
    warn = warn,
    error = error,
}

return M