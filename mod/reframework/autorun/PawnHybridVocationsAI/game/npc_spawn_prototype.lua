local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local log = require("PawnHybridVocationsAI/core/log")
local sigurd_observer = require("PawnHybridVocationsAI/game/sigurd_observer")

local npc_spawn_prototype = {}

local SIGURD_CHARA_ID = config.npc_spawn.sigurd_chara_id or 1108605478
local UNSAFE_SPAWN_REASON = "unsafe_spawn_disabled_use_sigurd_lookup"

local function get_data(runtime)
    -- Legacy runtime key retained for backward compatibility with existing accessors and logs.
    runtime.npc_spawn_prototype_data = runtime.npc_spawn_prototype_data or {
        enabled = true,
        prototype_label = "Sigurd/NPC Observer",
        template_character_id = config.npc_spawn.template_character_id,
        template_prefab_id = config.npc_spawn.template_prefab_id,
        spawn_job = config.npc_spawn.spawn_job,
        human_enemy_combat_param_id = config.npc_spawn.human_enemy_combat_param_id,
        last_status = "idle",
        last_error = "<none>",
        spawn_ui_enabled = config.npc_spawn.spawn_ui_enabled == true,
        sigurd_chara_id = SIGURD_CHARA_ID,
        sigurd_lookup_count = 0,
        sigurd_found_count = 0,
        sigurd_last_status = "idle",
        sigurd_last_error = "<none>",
        sigurd_last_seen_address = nil,
        sigurd_last_seen_character = nil,
        sigurd_last_seen_npc_data = nil,
        sigurd_last_seen_name = nil,
        sigurd_last_seen_job = nil,
        sigurd_last_seen_distance = nil,
        sigurd_last_seen_source = nil,
        sigurd_last_seen_holder = nil,
        sigurd_character_obj = nil,
        sigurd_game_object_obj = nil,
        sigurd_human_obj = nil,
        follow_npc_dump_count = 0,
        follow_npc_last_count = 0,
    }

    sigurd_observer.bind_runtime_data(runtime, runtime.npc_spawn_prototype_data)
    return runtime.npc_spawn_prototype_data
end

local function sync_config_fields(data)
    data.template_character_id = config.npc_spawn.template_character_id
    data.template_prefab_id = config.npc_spawn.template_prefab_id
    data.spawn_job = config.npc_spawn.spawn_job
    data.human_enemy_combat_param_id = config.npc_spawn.human_enemy_combat_param_id
    data.spawn_ui_enabled = config.npc_spawn.spawn_ui_enabled == true
    data.sigurd_chara_id = config.npc_spawn.sigurd_chara_id or SIGURD_CHARA_ID
end

function npc_spawn_prototype.queue_human_job07_spawn()
    local runtime = state.runtime
    local data = get_data(runtime)
    sync_config_fields(data)

    data.last_status = "disabled"
    data.last_error = UNSAFE_SPAWN_REASON

    log.warn("NPC spawn prototype disabled: unsafe spawn path disabled, use Sigurd lookup instead")
    log.session_marker(runtime, "npc", "npc_spawn_request_blocked", {
        reason = UNSAFE_SPAWN_REASON,
        template_character_id = data.template_character_id,
        prefab_id = data.template_prefab_id,
        job = data.spawn_job,
    }, "unsafe spawn disabled; use Sigurd lookup")
    return false
end

function npc_spawn_prototype.lookup_sigurd_loaded()
    local runtime = state.runtime
    return sigurd_observer.lookup_loaded(runtime, get_data(runtime))
end

function npc_spawn_prototype.lookup_sigurd_npc_manager()
    local runtime = state.runtime
    return sigurd_observer.lookup_npc_manager(runtime, get_data(runtime))
end

function npc_spawn_prototype.dump_npc_manager_holders()
    local runtime = state.runtime
    return sigurd_observer.dump_npc_manager_holders(runtime, get_data(runtime))
end

function npc_spawn_prototype.clear_sigurd_tracking()
    local runtime = state.runtime
    return sigurd_observer.clear_tracking(runtime, get_data(runtime))
end

function npc_spawn_prototype.clear_last_spawn()
    local runtime = state.runtime
    local data = get_data(runtime)
    data.last_status = "disabled"
    data.last_error = UNSAFE_SPAWN_REASON
    return false
end

function npc_spawn_prototype.update(runtime)
    local data = get_data(runtime)
    sync_config_fields(data)
    return data
end

return npc_spawn_prototype
