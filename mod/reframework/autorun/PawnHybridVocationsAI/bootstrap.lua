local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local log = require("PawnHybridVocationsAI/core/log")
local scheduler = require("PawnHybridVocationsAI/core/scheduler")
local main_pawn_properties = require("PawnHybridVocationsAI/game/main_pawn_properties")
local progression_state = require("PawnHybridVocationsAI/game/progression/state")
local hybrid_unlock = require("PawnHybridVocationsAI/game/hybrid_unlock")
local hybrid_combat_fix = require("PawnHybridVocationsAI/game/hybrid_combat_fix")
local nickcore_trace = require("PawnHybridVocationsAI/dev/nickcore_trace")

local bootstrap = {}

local function capture_traceback(err)
    if type(debug) == "table" and type(debug.traceback) == "function" then
        return debug.traceback(tostring(err), 2)
    end

    return tostring(err)
end

local function run_update(label, fn)
    local ok, result_or_error = xpcall(fn, capture_traceback)
    if not ok then
        state.runtime.scheduler_errors = state.runtime.scheduler_errors or {}
        state.runtime.scheduler_errors[label] = {
            at = state.runtime.game_time or os.clock(),
            message = tostring(result_or_error),
        }
        log.error(string.format("Runtime update failed for %s: %s", tostring(label), tostring(result_or_error)))
        return nil, tostring(result_or_error)
    end

    if state.runtime.scheduler_errors ~= nil then
        state.runtime.scheduler_errors[label] = nil
    end
    return result_or_error, nil
end

local function run_scheduled(runtime, key, interval_seconds, fn)
    local ran, _, err = scheduler.run(runtime, key, interval_seconds, fn)
    if ran and err ~= nil then
        log.error(string.format("Scheduled update failed for %s: %s", tostring(key), tostring(err)))
    end
end

local function on_late_update()
    local runtime = state.runtime
    local previous_time = runtime.game_time

    runtime.game_time = os.clock()
    runtime.delta_time = previous_time == 0 and 0 or (runtime.game_time - previous_time)

    run_update("main_pawn_properties.update", main_pawn_properties.update)
    run_scheduled(runtime, "progression_state.update", config.runtime.progression_refresh_interval_seconds, progression_state.update)
    run_scheduled(runtime, "hybrid_unlock.update", config.runtime.hybrid_unlock_refresh_interval_seconds, hybrid_unlock.update)
    run_scheduled(runtime, "hybrid_combat_fix.update", config.runtime.hybrid_combat_fix_refresh_interval_seconds, hybrid_combat_fix.update)
end

local function on_script_reset()
    log.info("Script reset")
    nickcore_trace.shutdown()
    log.shutdown()
end

if state.initialized then
    return bootstrap
end

state.initialized = true
log.init()
log.info(string.format("Bootstrapping %s %s", config.mod_name, config.version))
nickcore_trace.init()

re.on_application_entry("LateUpdateBehavior", on_late_update)
re.on_script_reset(on_script_reset)

return bootstrap
