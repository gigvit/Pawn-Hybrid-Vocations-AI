local config = require("PawnHybridVocationsAI/config")

local log = {}

local level_order = {
    DEBUG = 10,
    INFO = 20,
    WARN = 30,
    ERROR = 40,
}

local session = {
    initialized = false,
    session_id = nil,
    relative_path = nil,
    file_handle = nil,
    init_error_logged = false,
}

local function current_log_level()
    local configured = string.upper(tostring(config.debug.log_level or "INFO"))
    return level_order[configured] ~= nil and configured or "INFO"
end

local function escape_regex(text)
    return tostring(text):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function build_session_glob_pattern()
    local directory = tostring(config.debug.file_log_directory or "PawnHybridVocationsAI/logs"):gsub("/", "\\")
    local prefix = tostring(config.debug.file_log_prefix or "PawnHybridVocationsAI.session")
    return "^" .. escape_regex(directory) .. [[\\]] .. escape_regex(prefix) .. [[_.*$]]
end

local function extract_session_sort_key(relative_path)
    local stamp = tostring(relative_path):match("session_(%d%d%d%d%d%d%d%d_%d%d%d%d%d%d)")
    if stamp ~= nil then
        return stamp
    end

    return tostring(relative_path)
end

local function close_file()
    if session.file_handle ~= nil then
        pcall(function()
            session.file_handle:flush()
            session.file_handle:close()
        end)
        session.file_handle = nil
    end
end

local function remove_relative_file(relative_path)
    if type(relative_path) ~= "string" or relative_path == "" then
        return false
    end

    local normalized = relative_path:gsub("/", "\\")
    if not normalized:match("^PawnHybridVocationsAI\\logs\\") then
        return false
    end

    local game_relative_path = "reframework\\data\\" .. normalized
    local ok, result = pcall(os.remove, game_relative_path)
    return ok and result == true
end

local function prune_old_logs()
    local max_files = tonumber(config.debug.max_file_logs) or 20
    if max_files <= 0 or fs == nil or type(fs.glob) ~= "function" then
        return
    end

    local existing = {}
    local glob_pattern = build_session_glob_pattern()
    local matched = fs.glob(glob_pattern)

    for _, relative_path in ipairs(matched or {}) do
        existing[#existing + 1] = tostring(relative_path)
    end

    local keep_existing = math.max(max_files - 1, 0)
    if #existing <= keep_existing then
        return
    end

    table.sort(existing, function(a, b)
        local key_a = extract_session_sort_key(a)
        local key_b = extract_session_sort_key(b)
        if key_a == key_b then
            return a < b
        end
        return key_a < key_b
    end)

    for index = 1, (#existing - keep_existing) do
        remove_relative_file(existing[index])
    end
end

local function open_session_file()
    if not config.debug.file_logging_enabled then
        return
    end

    prune_old_logs()

    session.session_id = os.date("%Y%m%d_%H%M%S")
    session.relative_path = string.format(
        "%s/%s_%s.log",
        tostring(config.debug.file_log_directory or "PawnHybridVocationsAI/logs"),
        tostring(config.debug.file_log_prefix or "PawnHybridVocationsAI.session"),
        tostring(session.session_id)
    )

    local handle = io.open(session.relative_path, "a")
    if handle == nil then
        if not session.init_error_logged then
            print(string.format("[%s][WARN] Failed to open session log file: %s", config.mod_name, tostring(session.relative_path)))
            session.init_error_logged = true
        end
        session.relative_path = nil
        return
    end

    session.file_handle = handle
    session.file_handle:write(string.format("[%s][INFO] Session started %s\n", config.mod_name, os.date("%Y-%m-%d %H:%M:%S")))
    session.file_handle:flush()
end

local function ensure_initialized()
    if session.initialized then
        return
    end

    session.initialized = true
    open_session_file()
end

local function emit(level, message)
    ensure_initialized()

    local normalized_level = string.upper(tostring(level or "INFO"))
    local target = level_order[normalized_level] or level_order.INFO
    local minimum = level_order[current_log_level()] or level_order.INFO
    if target < minimum then
        return
    end

    local line = string.format("[%s][%s] %s", config.mod_name, normalized_level, tostring(message))
    print(line)

    if session.file_handle ~= nil then
        session.file_handle:write(line .. "\n")
        session.file_handle:flush()
    end
end

function log.init()
    ensure_initialized()
end

function log.shutdown()
    if session.file_handle ~= nil then
        session.file_handle:write(string.format("[%s][INFO] Session closed %s\n", config.mod_name, os.date("%Y-%m-%d %H:%M:%S")))
        session.file_handle:flush()
    end
    close_file()
end

function log.get_session_relative_path()
    ensure_initialized()
    return session.relative_path
end

function log.info(message)
    emit("INFO", message)
end

function log.warn(message)
    emit("WARN", message)
end

function log.debug(message)
    emit("DEBUG", message)
end

function log.error(message)
    emit("ERROR", message)
end

return log
