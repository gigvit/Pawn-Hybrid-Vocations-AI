local config = require("PawnHybridVocationsAI/config")
local access = require("PawnHybridVocationsAI/core/access")
local hybrid_payloads = require("PawnHybridVocationsAI/game/hybrid_payloads")
local hybrid_targeting = require("PawnHybridVocationsAI/game/hybrid_targeting")

local hybrid_interrupt_guard = {}

local function combat_config()
    return config.combat or {}
end

local function resolve_target_signature(target_info, character)
    return tostring(target_info and target_info.character_signature or access.describe_obj(character))
end

function hybrid_interrupt_guard.activate(active_state, move, target_info, now)
    if type(active_state) ~= "table" then
        return nil
    end

    active_state.guard = {
        policy = tostring(move and move.execution and move.execution.interrupt_policy or "guarded_owned"),
        target_signature = resolve_target_signature(target_info, target_info and target_info.character),
        activated_at = tonumber(now) or 0.0,
        last_skip_think_at = nil,
        clear_reason = "nil",
    }
    return active_state.guard
end

function hybrid_interrupt_guard.clear(active_state, reason, now)
    if type(active_state) ~= "table" or type(active_state.guard) ~= "table" then
        return
    end

    active_state.guard.clear_reason = tostring(reason or "cleared")
    active_state.guard.cleared_at = tonumber(now) or 0.0
end

function hybrid_interrupt_guard.pulse(active_state, context, target_info, now)
    if type(active_state) ~= "table" or type(active_state.guard) ~= "table" then
        return true, {
            reason = "guard_inactive",
        }
    end

    local guard = active_state.guard
    local character = target_info and target_info.character or nil
    if not access.is_valid_obj(character) then
        return false, {
            reason = "guard_target_missing",
        }
    end

    local current_target_signature = resolve_target_signature(target_info, character)
    if tostring(guard.target_signature or "nil") ~= "nil"
        and tostring(guard.target_signature) ~= tostring(current_target_signature) then
        return false, {
            reason = "guard_target_changed",
            target_signature = current_target_signature,
        }
    end

    local step = active_state.current_step or {}
    local max_distance = tonumber(step.max_distance)
    local distance = target_info and target_info.distance
        or hybrid_targeting.compute_distance(context and context.runtime_character, character)
    if step.abort_on_out_of_range ~= false and max_distance ~= nil and distance ~= nil and distance > max_distance then
        return false, {
            reason = "guard_target_out_of_range",
            distance = distance,
            max_distance = max_distance,
        }
    end

    local interval = tonumber(combat_config().skip_think_interval_seconds) or 0.18
    if combat_config().request_skip_think == true
        and (guard.last_skip_think_at == nil or ((tonumber(now) or 0.0) - guard.last_skip_think_at) >= interval) then
        guard.last_skip_think_at = tonumber(now) or 0.0
        local _, skip_meta = hybrid_payloads.request_skip_think(context)
        return true, {
            reason = tostring(skip_meta and skip_meta.reason or "guard_ok"),
            distance = distance,
            target_signature = current_target_signature,
        }
    end

    return true, {
        reason = "guard_ok",
        distance = distance,
        target_signature = current_target_signature,
    }
end

return hybrid_interrupt_guard
