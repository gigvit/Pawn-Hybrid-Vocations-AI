local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local discovery = require("PawnHybridVocationsAI/game/discovery")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local hybrid_unlock = {}

local function current_actor_job(actor_state, fallback)
    if actor_state ~= nil then
        return actor_state.current_job or actor_state.raw_job
    end

    if fallback ~= nil then
        return fallback.current_job or fallback.job
    end

    return nil
end

local function build_target(label, job_id, progression, main_pawn_data)
    local qualified_map = progression and progression.qualified_job_map or nil
    local qualified_entry = qualified_map and qualified_map[label] or nil
    local player_current_job = progression and progression.current_job or nil
    local pawn_current_job = main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or nil

    local progression_allowed = qualified_entry and qualified_entry.bit_job_minus_one or false

    return {
        label = label,
        job_id = job_id,
        player_current_job = player_current_job,
        pawn_current_job = pawn_current_job,
        progression_allowed = progression_allowed,
        progression_rule = "QualifiedJobBits -> bit(job-1)",
        unlock_layer_ready = progression_allowed and main_pawn_data ~= nil or false,
        notes = progression_allowed
            and "Progression gate passed. Safe candidate for unlock research."
            or "Progression gate not passed yet. Do not unlock.",
    }
end

local function build_target_vocations(progression, main_pawn_data)
    local target_vocations = {}
    for _, job in hybrid_jobs.each() do
        target_vocations[job.key] = build_target(job.key, job.id, progression, main_pawn_data)
    end
    return target_vocations
end

local function build_research_state(runtime)
    local progression = runtime.progression_gate_data
    local main_pawn_data = runtime.main_pawn_data

    return {
        main_pawn_only_guard = main_pawn_data ~= nil,
        progression_source = "QualifiedJobBits -> bit(job-1)",
        current_player_job = progression and progression.current_job or nil,
        current_main_pawn_job = main_pawn_data and (main_pawn_data.current_job or main_pawn_data.job) or nil,
        target_vocations = build_target_vocations(progression, main_pawn_data),
    }
end

local function resolve_target(target_job)
    local target = hybrid_jobs.get_by_id(target_job)
    if target ~= nil then
        return target, "supported_target_job"
    end

    return nil, "unsupported_target_job"
end

local function resolve_target_research(target, research_state)
    if target == nil then
        return nil
    end

    local vocations = research_state and research_state.target_vocations or nil
    if vocations == nil then
        return nil
    end

    return vocations[target.key]
end

local function resolve_request_reason(base)
    if base.enabled ~= true then
        return "prototype_disabled"
    end
    if base.target_reason ~= "supported_target_job" then
        return base.target_reason
    end
    if base.runtime_character == nil then
        return "main_pawn_runtime_unresolved"
    end
    if base.job_context == nil then
        return "job_context_unresolved"
    end
    if base.job_changer == nil then
        return "job_changer_unresolved"
    end
    if base.qualified_before == false then
        return "progression_gate_not_passed"
    end
    if tonumber(base.current_main_pawn_job) == tonumber(base.target_job) then
        return "already_on_target_job"
    end

    return "request_possible_runtime_write_disabled"
end

local function resolve_qualification_reason(base)
    if base.enabled ~= true then
        return "prototype_disabled"
    end
    if base.auto_qualify_target_job ~= true then
        return "auto_qualify_disabled"
    end
    if base.target_reason ~= "supported_target_job" then
        return base.target_reason
    end
    if base.job_context == nil then
        return "job_context_unresolved"
    end
    if base.qualified_before == true then
        return "already_qualified"
    end

    return "qualification_possible_runtime_write_disabled"
end

local function resolve_notice_reason(base)
    if base.enabled ~= true then
        return "prototype_disabled"
    end
    if base.request_job_notice ~= true then
        return "request_job_notice_disabled"
    end
    if base.target_reason ~= "supported_target_job" then
        return base.target_reason
    end

    return "notice_pending_runtime_write_disabled"
end

local function resolve_equipment_cleanup_reason(base)
    if base.enabled ~= true then
        return "prototype_disabled"
    end
    if base.cleanup_equipment_after_apply ~= true then
        return "cleanup_disabled"
    end
    if base.target_reason ~= "supported_target_job" then
        return base.target_reason
    end

    return "cleanup_pending_runtime_write_disabled"
end

local function resolve_overall_reason(base)
    if base.enabled ~= true then
        return "prototype_disabled"
    end
    if base.target_reason ~= "supported_target_job" then
        return base.target_reason
    end
    if base.runtime_character == nil then
        return "main_pawn_runtime_unresolved"
    end
    if base.current_main_pawn_job == nil then
        return "main_pawn_job_unresolved"
    end
    if base.qualified_before == false then
        return "progression_gate_not_passed"
    end
    if tonumber(base.current_main_pawn_job) == tonumber(base.target_job) then
        return "already_on_target_job"
    end

    return "ready_for_unlock_research"
end

local function build_prototype_state(runtime, research_state)
    local target_job = config.hybrid_unlock.target_job
    local main_pawn_data = runtime.main_pawn_data
    local progression_state = runtime.progression_state_data
    local player_state = progression_state and progression_state.player or nil
    local main_pawn_state = progression_state and progression_state.main_pawn or nil
    local target, target_reason = resolve_target(target_job)
    local target_research = resolve_target_research(target, research_state)

    discovery.refresh(false)

    local data = {
        enabled = config.hybrid_unlock.prototype_enabled == true,
        prototype_mode = config.hybrid_unlock.prototype_mode,
        activation_mode = config.hybrid_unlock.prototype_mode or "vanilla_guild_only",
        auto_apply_target_job = config.hybrid_unlock.auto_apply_target_job == true,
        auto_qualify_target_job = config.hybrid_unlock.auto_qualify_target_job == true,
        request_job_notice = config.hybrid_unlock.request_job_notice == true,
        cleanup_equipment_after_apply = config.hybrid_unlock.cleanup_equipment_after_apply == true,
        current_player_job = current_actor_job(player_state, runtime.progression_gate_data),
        current_main_pawn_job = current_actor_job(main_pawn_state, main_pawn_data),
        target_job = target_job,
        configured_target_job = target_job,
        supported_target_name = target and target.label or nil,
        target_reason = target_reason,
        can_attempt = false,
        attempted = false,
        request_allowed = false,
        request_ok = false,
        request_reason = "prototype_disabled",
        requested_job = nil,
        qualification_attempted = false,
        qualification_ok = false,
        qualification_reason = "prototype_disabled",
        qualified_before = target_research and target_research.progression_allowed or nil,
        qualified_after = target_research and target_research.progression_allowed or nil,
        notice_attempted = false,
        notice_ok = false,
        notice_reason = "prototype_disabled",
        equipment_cleanup_attempted = false,
        equipment_cleanup_ok = false,
        equipment_cleanup_reason = "prototype_disabled",
        removed_equipped_items = 0,
        apply_equip_change_ok = false,
        reason = "prototype_disabled",
        job_context = main_pawn_state and main_pawn_state.job_context or main_pawn_data and main_pawn_data.job_context or nil,
        job_changer = main_pawn_state and main_pawn_state.job_changer or nil,
        gui_manager = discovery.get_manager("GuiManager"),
        runtime_character = main_pawn_data and main_pawn_data.runtime_character or main_pawn_state and main_pawn_state.runtime_character or nil,
        chara_id = main_pawn_data and main_pawn_data.chara_id or main_pawn_state and main_pawn_state.chara_id or nil,
    }

    data.request_reason = resolve_request_reason(data)
    data.qualification_reason = resolve_qualification_reason(data)
    data.notice_reason = resolve_notice_reason(data)
    data.equipment_cleanup_reason = resolve_equipment_cleanup_reason(data)
    data.reason = resolve_overall_reason(data)
    data.can_attempt = data.reason == "ready_for_unlock_research"
    data.request_allowed = data.request_reason == "request_possible_runtime_write_disabled"

    return data
end

function hybrid_unlock.update()
    local runtime = state.runtime
    local research = build_research_state(runtime)
    local prototype = build_prototype_state(runtime, research)

    local data = {
        research = research,
        prototype = prototype,
        current_player_job = research.current_player_job,
        current_main_pawn_job = research.current_main_pawn_job,
        target_vocations = research.target_vocations,
        target_job = prototype.target_job,
        supported_target_name = prototype.supported_target_name,
        reason = prototype.reason,
        can_attempt = prototype.can_attempt,
    }

    runtime.hybrid_unlock_data = data
    runtime.hybrid_unlock_research_data = research
    runtime.hybrid_unlock_prototype_data = prototype

    return data
end

return hybrid_unlock
