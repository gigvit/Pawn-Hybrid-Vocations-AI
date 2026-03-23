local state = require("PawnHybridVocationsAI/state")
local config = require("PawnHybridVocationsAI/config")
local log = require("PawnHybridVocationsAI/core/log")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local correlation = {}

local function extract_latest_talk_event(runtime)
    local trace = runtime.talk_event_trace_data
    return trace and trace.last_entry or nil
end

local function extract_latest_progression_event(runtime, job_id)
    local trace = runtime.progression_trace_data
    for _, event in ipairs(trace and trace.recent_events or {}) do
        if tonumber(event.job_id) == tonumber(job_id) then
            return event
        end
    end
    return nil
end

local function extract_latest_progression_event_for_target(runtime, job_id, target)
    local trace = runtime.progression_trace_data
    for _, event in ipairs(trace and trace.recent_events or {}) do
        if tonumber(event.job_id) == tonumber(job_id) and tostring(event.target) == tostring(target) then
            return event
        end
    end
    return nil
end

local function observed_job_info_hint(runtime)
    local guild = runtime.guild_flow_research_data
    if guild == nil then
        return "unobserved"
    end

    local override = guild.job_info_pawn_override
    if override ~= nil and override.attempted then
        return tostring(override.reason or "attempted")
    end

    return "unobserved"
end

function correlation.update()
    local runtime = state.runtime
    local progression = runtime.progression_state_data
    if progression == nil or progression.player == nil or progression.main_pawn == nil then
        runtime.job_gate_correlation_data = nil
        return nil
    end

    local latest_talk = extract_latest_talk_event(runtime)
    local data = {
        summary = {
            dominant_gap = progression.summary and progression.summary.dominant_gap or "unresolved",
            latest_talk_event_id = latest_talk and latest_talk.event_id or nil,
            latest_talk_event_label = latest_talk and latest_talk.event_label or nil,
            latest_job_info_hint = observed_job_info_hint(runtime),
        },
        by_job = {},
    }

    for _, key in ipairs(hybrid_jobs.keys) do
        local job_id = hybrid_jobs.by_key[key] and hybrid_jobs.by_key[key].id or nil
        local diff = progression.alignment and progression.alignment.hybrid and progression.alignment.hybrid[key] or nil
        local runtime_event = extract_latest_progression_event(runtime, job_id)
        local player_runtime_event = extract_latest_progression_event_for_target(runtime, job_id, "player")
        local pawn_runtime_event = extract_latest_progression_event_for_target(runtime, job_id, "main_pawn")
        data.by_job[key] = {
            id = job_id,
            qualified_match = diff and diff.qualified_match or nil,
            viewed_match = diff and diff.viewed_match or nil,
            changed_match = diff and diff.changed_match or nil,
            player_is_job_qualified = diff and diff.player_is_job_qualified or nil,
            pawn_is_job_qualified = diff and diff.pawn_is_job_qualified or nil,
            player_viewed = diff and diff.player_viewed or nil,
            pawn_viewed = diff and diff.pawn_viewed or nil,
            player_changed = diff and diff.player_changed or nil,
            pawn_changed = diff and diff.pawn_changed or nil,
            latest_runtime_event = runtime_event and runtime_event.name or nil,
            latest_runtime_target = runtime_event and runtime_event.target or nil,
            latest_runtime_method = runtime_event and runtime_event.method or nil,
            player_runtime_result = player_runtime_event and player_runtime_event.result_bool or nil,
            player_runtime_code = player_runtime_event and player_runtime_event.result_code or nil,
            player_runtime_hex = player_runtime_event and player_runtime_event.result_hex or nil,
            player_runtime_snapshot_direct = player_runtime_event and player_runtime_event.snapshot_direct_is_job_qualified or nil,
            player_runtime_snapshot_direct_code = player_runtime_event and player_runtime_event.snapshot_direct_code or nil,
            player_runtime_snapshot_direct_hex = player_runtime_event and player_runtime_event.snapshot_direct_hex or nil,
            pawn_runtime_result = pawn_runtime_event and pawn_runtime_event.result_bool or nil,
            pawn_runtime_code = pawn_runtime_event and pawn_runtime_event.result_code or nil,
            pawn_runtime_hex = pawn_runtime_event and pawn_runtime_event.result_hex or nil,
            pawn_runtime_snapshot_direct = pawn_runtime_event and pawn_runtime_event.snapshot_direct_is_job_qualified or nil,
            pawn_runtime_snapshot_direct_code = pawn_runtime_event and pawn_runtime_event.snapshot_direct_code or nil,
            pawn_runtime_snapshot_direct_hex = pawn_runtime_event and pawn_runtime_event.snapshot_direct_hex or nil,
        }
    end

    runtime.job_gate_correlation_data = data

    local signature_parts = {
        tostring(data.summary.dominant_gap),
        tostring(data.summary.latest_talk_event_id),
        tostring(data.summary.latest_job_info_hint),
    }
    for _, key in ipairs(hybrid_jobs.keys) do
        table.insert(signature_parts, tostring(data.by_job[key] and data.by_job[key].qualified_match))
    end
    local signature = table.concat(signature_parts, "|")

    if runtime.last_job_gate_correlation_signature ~= signature then
        runtime.last_job_gate_correlation_signature = signature
        log.session_marker(runtime, "progression", "job_gate_correlation_changed", {
            dominant_gap = data.summary.dominant_gap,
            latest_talk_event_id = data.summary.latest_talk_event_id,
            latest_talk_event_label = data.summary.latest_talk_event_label,
            latest_job_info_hint = data.summary.latest_job_info_hint,
        }, string.format(
            "gap=%s talk=%s hint=%s",
            tostring(data.summary.dominant_gap),
            tostring(data.summary.latest_talk_event_label),
            tostring(data.summary.latest_job_info_hint)
        ))
    end

    return data
end

return correlation
