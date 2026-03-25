local config = require("PawnHybridVocationsAI/config")

local log = {}

local level_order = {
    DEBUG = 10,
    INFO = 20,
    WARN = 30,
    ERROR = 40,
}

local function current_log_level()
    local configured = string.upper(tostring(config.debug.log_level or "INFO"))
    return level_order[configured] ~= nil and configured or "INFO"
end

local function emit(level, message)
    local target = level_order[string.upper(tostring(level or "INFO"))] or level_order.INFO
    local minimum = level_order[current_log_level()] or level_order.INFO
    if target >= minimum then
        print(string.format("[%s][%s] %s", config.mod_name, string.upper(level), tostring(message)))
    end
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
