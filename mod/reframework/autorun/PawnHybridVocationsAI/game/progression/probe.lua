local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local util = require("PawnHybridVocationsAI/core/util")
local log = require("PawnHybridVocationsAI/core/log")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local progression_probe = {}

local function get_probe(runtime)
    runtime.progression_probe_data = runtime.progression_probe_data or {
        enabled = config.progression_research.enable_progression_bit_mirror_probe == true,
        attempts = 0,
        applied = 0,
        last_reason = "not_attempted",
        last_target = "none",
        last_job_id = nil,
        last_fields = "",
        last_before_qualified = nil,
        last_after_qualified = nil,
        last_before_viewed = nil,
        last_after_viewed = nil,
        last_before_changed = nil,
        last_after_changed = nil,
    }
    return runtime.progression_probe_data
end

local function get_hybrid_entry(actor_state, key)
    return actor_state and actor_state.hybrid_gate_status and actor_state.hybrid_gate_status[key] or nil
end

local function add_missing_bit(source_mask, target_mask, bit_index)
    if type(source_mask) ~= "number" or type(target_mask) ~= "number" or type(bit_index) ~= "number" or bit_index < 0 then
        return target_mask, false
    end

    if not util.has_bit(source_mask, bit_index) or util.has_bit(target_mask, bit_index) then
        return target_mask, false
    end

    return target_mask + (2 ^ bit_index), true
end

local function build_field_list(changes)
    local labels = {}
    for _, label in ipairs(changes) do
        table.insert(labels, label)
    end
    table.sort(labels)
    return table.concat(labels, ",")
end

local function apply_probe(runtime)
    local probe = get_probe(runtime)
    probe.attempts = probe.attempts + 1
    probe.last_target = "main_pawn"

    if probe.enabled ~= true then
        probe.last_reason = "probe_disabled"
        return probe
    end

    local progression = runtime.progression_state_data
    local player_state = progression and progression.player or nil
    local pawn_state = progression and progression.main_pawn or nil
    local player_context = player_state and player_state.job_context or nil
    local pawn_context = pawn_state and pawn_state.job_context or nil

    if player_state == nil or pawn_state == nil or player_context == nil or pawn_context == nil then
        probe.last_reason = "state_unresolved"
        return probe
    end

    local before_qualified = pawn_state.qualified_job_bits
    local before_viewed = pawn_state.viewed_new_job_bits
    local before_changed = pawn_state.changed_job_bits
    local after_qualified = before_qualified
    local after_viewed = before_viewed
    local after_changed = before_changed

    local changed_fields = {}
    local last_job_id = nil

    for _, key in ipairs(hybrid_jobs.keys) do
        local job_id = hybrid_jobs.by_key[key] and hybrid_jobs.by_key[key].id or nil
        local bit_index = job_id and (job_id - 1) or nil
        local player_entry = get_hybrid_entry(player_state, key)
        local pawn_entry = get_hybrid_entry(pawn_state, key)
        if job_id ~= nil and player_entry ~= nil and pawn_entry ~= nil then
            local next_qualified, qualified_changed = add_missing_bit(
                player_state.qualified_job_bits,
                after_qualified,
                bit_index
            )
            after_qualified = next_qualified
            if qualified_changed then
                table.insert(changed_fields, string.format("qualified:%s", key))
                last_job_id = job_id
            end

        end
    end

    probe.last_before_qualified = before_qualified
    probe.last_before_viewed = before_viewed
    probe.last_before_changed = before_changed
    probe.last_after_qualified = after_qualified
    probe.last_after_viewed = after_viewed
    probe.last_after_changed = after_changed
    probe.last_job_id = last_job_id
    probe.last_fields = build_field_list(changed_fields)

    if #changed_fields == 0 then
        probe.last_reason = "no_missing_hybrid_access_bits"
        return probe
    end

    local qualified_ok = util.safe_set_field(pawn_context, "QualifiedJobBits", after_qualified)

    if not qualified_ok then
        probe.last_reason = string.format(
            "field_write_failed:q=%s",
            tostring(qualified_ok)
        )
        return probe
    end

    probe.applied = probe.applied + 1
    probe.last_reason = "hybrid_access_bit_mirror_applied"
    log.session_marker(runtime, "progression", "progression_bit_mirror_applied", {
        target = "main_pawn",
        last_job_id = last_job_id,
        changed_fields = changed_fields,
        before_qualified = before_qualified,
        after_qualified = after_qualified,
        before_viewed = before_viewed,
        after_viewed = after_viewed,
        before_changed = before_changed,
        after_changed = after_changed,
        player_qualified = player_state.qualified_job_bits,
        player_viewed = player_state.viewed_new_job_bits,
        player_changed = player_state.changed_job_bits,
    }, string.format(
        "target=main_pawn job_id=%s fields=%s qualified:%s->%s viewed:%s->%s changed:%s->%s",
        tostring(last_job_id),
        probe.last_fields,
        tostring(before_qualified),
        tostring(after_qualified),
        tostring(before_viewed),
        tostring(after_viewed),
        tostring(before_changed),
        tostring(after_changed)
    ))

    return probe
end

function progression_probe.update(runtime)
    local probe = apply_probe(runtime or state.runtime)
    probe.summary = {
        enabled = probe.enabled,
        attempts = probe.attempts,
        applied = probe.applied,
        last_reason = probe.last_reason,
        last_target = probe.last_target,
        last_job_id = probe.last_job_id,
        last_fields = probe.last_fields,
        last_before_qualified = probe.last_before_qualified,
        last_after_qualified = probe.last_after_qualified,
        last_before_viewed = probe.last_before_viewed,
        last_after_viewed = probe.last_after_viewed,
        last_before_changed = probe.last_before_changed,
        last_after_changed = probe.last_after_changed,
    }
    return probe
end

return progression_probe
