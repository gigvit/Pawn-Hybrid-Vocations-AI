local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local log = require("PawnHybridVocationsAI/core/log")
local scheduler = require("PawnHybridVocationsAI/core/scheduler")
local main_pawn_properties = require("PawnHybridVocationsAI/game/main_pawn_properties")
local progression_state = require("PawnHybridVocationsAI/game/progression/state")
local hybrid_unlock = require("PawnHybridVocationsAI/game/hybrid_unlock")
local hybrid_combat_fix = require("PawnHybridVocationsAI/game/hybrid_combat_fix")

local bootstrap = {}

local function on_late_update()
    local runtime = state.runtime
    local previous_time = runtime.game_time

    runtime.game_time = os.clock()
    runtime.delta_time = previous_time == 0 and 0 or (runtime.game_time - previous_time)

    main_pawn_properties.update()
    scheduler.run(runtime, "progression_state.update", config.runtime.progression_refresh_interval_seconds, progression_state.update)
    scheduler.run(runtime, "hybrid_unlock.update", config.runtime.hybrid_unlock_refresh_interval_seconds, hybrid_unlock.update)
    scheduler.run(runtime, "hybrid_combat_fix.update", config.runtime.hybrid_combat_fix_refresh_interval_seconds, hybrid_combat_fix.update)
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
log.info(string.format("Bootstrapping %s %s", config.mod_name, config.version))

re.on_application_entry("LateUpdateBehavior", on_late_update)
re.on_script_reset(on_script_reset)

return bootstrap
