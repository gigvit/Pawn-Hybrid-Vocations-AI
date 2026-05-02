local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/core/runtime")
local log = require("PawnHybridVocationsAI/core/log")
local main_pawn_properties = require("PawnHybridVocationsAI/game/main_pawn_properties")
local progression_state = require("PawnHybridVocationsAI/game/progression/state")
local hybrid_unlock = require("PawnHybridVocationsAI/game/hybrid_unlock")
local hybrid_combat = require("PawnHybridVocationsAI/game/hybrid_combat")
local combat_telemetry = require("PawnHybridVocationsAI/game/combat_telemetry")

local bootstrap = {}
local content_editor_capture = nil

local function install_content_editor_capture()
    local ok, module = pcall(require, "PawnHybridVocationsAI/dev/content_editor_capture")
    if not ok or type(module) ~= "table" or type(module.install) ~= "function" then
        return false, tostring(module)
    end

    content_editor_capture = module
    return module.install()
end

local function run_update(label, fn)
    return state.run_guarded(label, fn, function(_, err)
        log.error(string.format("Runtime update failed for %s: %s", tostring(label), tostring(err)))
    end)
end

local function run_scheduled(runtime, key, interval_seconds, fn)
    state.run_scheduled(key, interval_seconds, fn, function(_, run_err)
        log.error(string.format("Scheduled update failed for %s: %s", tostring(key), tostring(run_err)))
    end, runtime)
end

local function on_late_update()
    local runtime = state.runtime
    state.begin_frame(runtime)

    run_update("main_pawn_properties.update", main_pawn_properties.update)
    run_scheduled(runtime, "progression_state.update", config.runtime.progression_refresh_interval_seconds, progression_state.update)
    run_scheduled(runtime, "hybrid_unlock.update", config.runtime.hybrid_unlock_refresh_interval_seconds, hybrid_unlock.update)
    run_scheduled(runtime, "hybrid_combat.update", config.runtime.combat_refresh_interval_seconds, hybrid_combat.update)
    if type(content_editor_capture) == "table" and type(content_editor_capture.update) == "function" then
        run_update("content_editor_capture.update", content_editor_capture.update)
    end
end

local function on_script_reset()
    log.info("Script reset")
    log.shutdown()
end

if state.initialized then
    return bootstrap
end

state.initialized = true
log.init()
combat_telemetry.install_hooks()
log.info(string.format("Bootstrapping %s %s", config.mod_name, config.version))

local ce_ok, ce_reason = install_content_editor_capture()
log.info(string.format("Content Editor capture helper %s reason=%s", ce_ok and "ready" or "skipped", tostring(ce_reason)))

re.on_application_entry("LateUpdateBehavior", on_late_update)
re.on_script_reset(on_script_reset)

return bootstrap
