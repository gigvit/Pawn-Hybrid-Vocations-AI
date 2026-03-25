local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local hybrid_unlock = {}

local function current_actor_job(actor_state)
    if actor_state ~= nil then
        return actor_state.current_job or actor_state.raw_job
    end
    return nil
end

local function resolve_reason(target_supported, progression_allowed, runtime_ready, main_pawn_job, target_job)
    if not target_supported then
        return "unsupported_target_job"
    end
    if not progression_allowed then
        return "progression_gate_not_passed"
    end
    if not runtime_ready then
        return "main_pawn_runtime_not_ready"
    end
    if tonumber(main_pawn_job) == tonumber(target_job) then
        return "already_on_target_job"
    end
    return "ready_for_manual_runtime_write"
end

local function build_target_vocations(player_state, main_pawn_state)
    local result = {}

    for _, job in hybrid_jobs.each() do
        local player_entry = player_state and player_state.hybrid_gate_status and player_state.hybrid_gate_status[job.key] or nil
        local progression_allowed = player_entry and player_entry.qualified_bits and player_entry.qualified_bits.bit_job_minus_one or false
        local runtime_ready = main_pawn_state ~= nil
            and main_pawn_state.runtime_character ~= nil
            and main_pawn_state.job_context ~= nil
        local current_main_pawn_job = main_pawn_state and main_pawn_state.current_job or nil
        local reason = resolve_reason(true, progression_allowed, runtime_ready, current_main_pawn_job, job.id)

        result[job.key] = {
            job_id = job.id,
            label = job.label,
            target_supported = true,
            progression_rule = "player.QualifiedJobBits -> bit(job-1)",
            progression_allowed = progression_allowed,
            player_current_job = player_state and player_state.current_job or nil,
            main_pawn_current_job = current_main_pawn_job,
            runtime_ready = runtime_ready,
            ready_for_manual_runtime_write = reason == "ready_for_manual_runtime_write",
            reason = reason,
            direct_player_is_job_qualified = player_entry and player_entry.direct and player_entry.direct.is_job_qualified or nil,
            player_job_level = player_entry and player_entry.direct and player_entry.direct.job_level or nil,
        }
    end

    return result
end

function hybrid_unlock.update()
    local runtime = state.runtime
    local progression = runtime.progression_state_data
    local player_state = progression and progression.player or nil
    local main_pawn_state = progression and progression.main_pawn or nil
    local target_job = config.hybrid_unlock.target_job
    local target = hybrid_jobs.get_by_id(target_job)
    local target_vocations = build_target_vocations(player_state, main_pawn_state)
    local target_status = target and target_vocations[target.key] or nil

    local data = {
        current_player_job = current_actor_job(player_state),
        current_main_pawn_job = current_actor_job(main_pawn_state),
        target_job = target_job,
        target_job_label = target and target.label or nil,
        target_supported = target ~= nil,
        target_progression_allowed = target_status and target_status.progression_allowed or false,
        runtime_ready = target_status and target_status.runtime_ready or false,
        ready_for_manual_runtime_write = target_status and target_status.ready_for_manual_runtime_write or false,
        reason = target_status and target_status.reason or "unsupported_target_job",
        target_vocations = target_vocations,
    }

    runtime.hybrid_unlock_data = data
    return data
end

return hybrid_unlock
