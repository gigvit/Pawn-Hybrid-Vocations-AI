local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/core/runtime")
local log = require("PawnHybridVocationsAI/core/log")
local main_pawn_properties = require("PawnHybridVocationsAI/game/main_pawn_properties")
local progression_state = require("PawnHybridVocationsAI/game/progression/state")
local hybrid_unlock = require("PawnHybridVocationsAI/game/hybrid_unlock")
local hybrid_combat_fix = require("PawnHybridVocationsAI/game/hybrid_combat_fix")
local nickcore_trace = config.debug.nickcore_trace_enabled == true
    and require("PawnHybridVocationsAI/dev/nickcore_trace")
    or nil

local bootstrap = {}

local function run_update(label, fn)
    return state.run_guarded(label, fn, function(_, err)
        log.error(string.format("Runtime update failed for %s: %s", tostring(label), tostring(err)))
    end)
end

local function run_scheduled(runtime, key, interval_seconds, fn)
    local ran, _, err = state.run_scheduled(key, interval_seconds, fn, function(_, run_err)
        log.error(string.format("Scheduled update failed for %s: %s", tostring(key), tostring(run_err)))
    end, runtime)
    if ran and err ~= nil then
        log.error(string.format("Scheduled update failed for %s: %s", tostring(key), tostring(err)))
    end
end

local function on_late_update()
    local runtime = state.runtime
    state.begin_frame(runtime)

    run_update("main_pawn_properties.update", main_pawn_properties.update)
    run_scheduled(runtime, "progression_state.update", config.runtime.progression_refresh_interval_seconds, progression_state.update)
    run_scheduled(runtime, "hybrid_unlock.update", config.runtime.hybrid_unlock_refresh_interval_seconds, hybrid_unlock.update)
    run_scheduled(runtime, "hybrid_combat_fix.update", config.runtime.hybrid_combat_fix_refresh_interval_seconds, hybrid_combat_fix.update)
end

local function on_script_reset()
    log.info("Script reset")
    if nickcore_trace ~= nil then
        nickcore_trace.shutdown()
    end
    log.shutdown()
end

if state.initialized then
    return bootstrap
end

state.initialized = true
log.init()
log.info(string.format("Bootstrapping %s %s", config.mod_name, config.version))
if nickcore_trace ~= nil then
    nickcore_trace.init()
end

re.on_application_entry("LateUpdateBehavior", on_late_update)
re.on_script_reset(on_script_reset)

return bootstrap
