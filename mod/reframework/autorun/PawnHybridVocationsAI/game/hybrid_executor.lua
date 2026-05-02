local config = require("PawnHybridVocationsAI/config")
local log = require("PawnHybridVocationsAI/core/log")
local access = require("PawnHybridVocationsAI/core/access")
local hybrid_context = require("PawnHybridVocationsAI/game/hybrid_context")
local hybrid_payloads = require("PawnHybridVocationsAI/game/hybrid_payloads")
local hybrid_interrupt_guard = require("PawnHybridVocationsAI/game/hybrid_interrupt_guard")
local hybrid_targeting = require("PawnHybridVocationsAI/game/hybrid_targeting")
local direct_damage = require("PawnHybridVocationsAI/game/direct_damage")

local hybrid_executor = {}

local function combat_config()
    return config.combat or {}
end

local function is_crash_prone_move(move)
    if type(move) ~= "table" then
        return false
    end

    local selection = move.selection or {}
    return tostring(move.stability or selection.stability or "stable") == "crash_prone"
end

local function is_present_phase(phase)
    return type(phase) == "string" and phase ~= "" and phase ~= "nil" and phase ~= "none"
end

local function phase_in_list(phase, phases)
    if not is_present_phase(phase) or type(phases) ~= "table" then
        return false
    end

    local current_phase = tostring(phase)
    for _, item in ipairs(phases) do
        if tostring(item or "nil") == current_phase then
            return true
        end
    end

    return false
end

local function summarize_bridge_info(info)
    if type(info) ~= "table" then
        return "nil"
    end

    local results = {}
    for _, item in ipairs(info.results or {}) do
        results[#results + 1] = string.format(
            "%s:%s",
            tostring(item.bridge_kind or "bridge"),
            tostring(item.reason or "nil")
        )
    end

    return string.format(
        "reason=%s kind=%s pack=%s action=%s results=%s",
        tostring(info.reason or "nil"),
        tostring(info.bridge_kind or "nil"),
        tostring(info.pack_path or "nil"),
        tostring(info.action_name or "nil"),
        #results > 0 and table.concat(results, ",") or "none"
    )
end

local function set_step(active_state, step_index, now)
    active_state.step_index = tonumber(step_index) or 1
    active_state.current_step = active_state.move.sequence[active_state.step_index]
    active_state.step_started_at = tonumber(now) or 0.0
    active_state.step_reissue_at = nil
    active_state.step_reissue_count = 0
    active_state.step_damage_events_at = tonumber(active_state.damage_events) or 0
end

local function summarize_damage_state(active_state)
    if type(active_state) ~= "table" then
        return "none"
    end

    return string.format(
        "events=%s value=%s target=%s wrong=%s total=%.1f assists=%s direct=%s",
        tostring(active_state.damage_events or 0),
        tostring(active_state.damage_value_hits or 0),
        tostring(active_state.damage_target_hits or 0),
        tostring(active_state.damage_wrong_target_hits or 0),
        tonumber(active_state.damage_total or 0.0) or 0.0,
        tostring(active_state.damage_assist_hits or 0),
        tostring(active_state.direct_damage_hits or 0)
    )
end

local function damage_expected(move)
    local damage_kind = tostring(move and move.damage and move.damage.kind or "none")
    if damage_kind == "none"
        or damage_kind == "control_shell"
        or damage_kind == "mobility_followup"
        or damage_kind == "utility_defense"
        or damage_kind == "utility_counter"
        or damage_kind == "support" then
        return false
    end

    return true
end

local function resolve_move_outcome(active_state, status, reason)
    local normalized_status = tostring(status or "none")
    local normalized_reason = tostring(reason or "none")
    if normalized_status == "completed" then
        if (tonumber(active_state.damage_target_hits) or 0) > 0
            or (tonumber(active_state.damage_assist_hits) or 0) > 0 then
            return "hit_confirmed"
        end
        if (tonumber(active_state.damage_wrong_target_hits) or 0) > 0 then
            return "wrong_target"
        end
        if (tonumber(active_state.damage_events) or 0) > 0 then
            return "hit_unmatched"
        end
        if active_state.output_confirmed == true then
            if damage_expected(active_state.move) then
                return "no_damage_window"
            end
            return "output_confirmed"
        end
        if (tonumber(active_state.output_timeout_count) or 0) > 0 then
            return "output_timeout"
        end
        return "sequence_completed"
    end

    if normalized_status == "failed" and normalized_reason:find("timeout", 1, true) ~= nil then
        return "timed_out"
    end
    if normalized_status == "failed" then
        return "failed"
    end
    if normalized_status == "aborted" then
        return "aborted"
    end

    return normalized_status
end

local function chain_allows_outcome(chain, move_outcome)
    if type(chain) ~= "table" or type(chain.grant_on_completed_outcomes) ~= "table" then
        return true
    end

    local normalized = tostring(move_outcome or "nil")
    for _, allowed in ipairs(chain.grant_on_completed_outcomes) do
        if tostring(allowed or "nil") == normalized then
            return true
        end
    end

    return false
end

local function finish_active_move(data, outcome, reason, now)
    local active_state = data.active
    if type(active_state) ~= "table" then
        return nil
    end

    local move = active_state.move
    local move_outcome = resolve_move_outcome(active_state, outcome, reason)
    local cooldown_seconds = outcome == "completed"
        and (tonumber(move.cooldown_seconds) or tonumber(combat_config().default_move_cooldown_seconds) or 1.10)
        or (tonumber(move.failure_cooldown_seconds) or tonumber(combat_config().failed_move_cooldown_seconds) or 0.55)

    data.move_cooldowns = type(data.move_cooldowns) == "table" and data.move_cooldowns or {}
    local cooldown_until = (tonumber(now) or 0.0) + cooldown_seconds
    if tonumber(active_state.extra_cooldown_until) ~= nil then
        cooldown_until = math.max(cooldown_until, tonumber(active_state.extra_cooldown_until))
    end
    data.move_cooldowns[tostring(move.key or "nil")] = cooldown_until
    data.last_move_key = tostring(move.key or "nil")
    data.last_move_family = tostring(move.family or "nil")
    data.last_move_bucket = tostring(move.selection and move.selection.bucket or "nil")
    data.last_move_result = tostring(outcome or "none")
    data.last_move_outcome = move_outcome
    data.last_move_reason = tostring(reason or "none")
    data.last_move_finished_at = tonumber(now) or 0.0
    data.move_history = type(data.move_history) == "table" and data.move_history or {}
    data.move_history[#data.move_history + 1] = {
        key = tostring(move.key or "nil"),
        family = tostring(move.family or "nil"),
        bucket = tostring(move.selection and move.selection.bucket or "nil"),
        result = tostring(outcome or "none"),
        outcome = tostring(move_outcome or "none"),
        reason = tostring(reason or "none"),
        finished_at = tonumber(now) or 0.0,
    }
    while #data.move_history > 6 do
        table.remove(data.move_history, 1)
    end
    data.last_executor_summary = string.format(
        "%s:%s:%s:%s:%s",
        tostring(move.key or "nil"),
        tostring(outcome or "none"),
        tostring(move_outcome or "none"),
        tostring(reason or "none"),
        summarize_damage_state(active_state)
    )
    data.status = tostring(outcome or "none")
    data.reason = tostring(reason or "none")

    local chain = move and move.chain or nil
    local current_chain_phase = hybrid_executor.get_chain_phase(data, now)
    local should_grant_chain = true
    if type(chain) == "table" and chain.grant_on_completed_if_chain_absent == true and is_present_phase(current_chain_phase) then
        should_grant_chain = false
    end
    if type(chain) == "table" and phase_in_list(current_chain_phase, chain.grant_on_completed_unless_phase) then
        should_grant_chain = false
    end

    if outcome == "completed"
        and should_grant_chain
        and chain_allows_outcome(chain, move_outcome)
        and type(chain) == "table"
        and is_present_phase(chain.grant_on_completed) then
        hybrid_executor.grant_chain_state(
            data,
            chain.grant_on_completed,
            active_state.target_signature,
            now,
            chain.grant_duration_seconds,
            "move_completed:" .. tostring(move.key or "nil")
        )
    end
    if outcome == "completed" and type(chain) == "table" and chain.clear_on_completed == true then
        hybrid_executor.clear_chain_state(data, "move_completed:" .. tostring(move.key or "nil"))
    end

    hybrid_interrupt_guard.clear(active_state, reason, now)
    data.active = nil

    return {
        status = tostring(outcome or "none"),
        outcome = tostring(move_outcome or "none"),
        reason = tostring(reason or "none"),
        move = move,
        damage_summary = summarize_damage_state(active_state),
    }
end

function hybrid_executor.ensure_state(runtime)
    if type(runtime.combat_data) ~= "table" then
        runtime.combat_data = {
            status = "idle",
            reason = "idle",
            active = nil,
            move_cooldowns = {},
            last_move_key = "nil",
            last_move_family = "nil",
            last_move_bucket = "nil",
            last_move_result = "none",
            last_move_reason = "nil",
            last_move_finished_at = nil,
            move_history = {},
            last_executor_summary = "idle",
            last_target_signature = "nil",
            last_target_reason = "nil",
            last_target_distance = nil,
            last_selection_summary = "none",
            last_blocked_summary = "none",
            cached_target_info = nil,
            cached_target_reason = "nil",
            cached_target_time = nil,
            last_target_log_signature = "nil",
            last_target_log_time = nil,
            last_selection_log_signature = "nil",
            last_selection_log_time = nil,
            last_snapshot_time = nil,
            last_no_target_log_time = nil,
            native_output_signature = "nil",
            native_output_since = nil,
            chain_state = nil,
        }
    end

    return runtime.combat_data
end

function hybrid_executor.get_chain_state(data, now)
    local chain_state = type(data) == "table" and data.chain_state or nil
    if type(chain_state) ~= "table" then
        return nil
    end

    local expires_at = tonumber(chain_state.expires_at)
    if expires_at ~= nil and expires_at <= (tonumber(now) or 0.0) then
        data.chain_state = nil
        return nil
    end

    return chain_state
end

function hybrid_executor.get_chain_phase(data, now)
    local chain_state = hybrid_executor.get_chain_state(data, now)
    return chain_state and chain_state.phase or nil
end

function hybrid_executor.chain_matches(data, phases, now, target_signature, require_target_match)
    local chain_state = hybrid_executor.get_chain_state(data, now)
    if type(chain_state) ~= "table" then
        return false, "none"
    end

    local current_phase = tostring(chain_state.phase or "nil")
    local phase_match = false
    if type(phases) == "table" then
        for _, phase in ipairs(phases) do
            if tostring(phase or "nil") == current_phase then
                phase_match = true
                break
            end
        end
    elseif tostring(phases or "nil") == current_phase then
        phase_match = true
    end

    if not phase_match then
        return false, current_phase
    end

    local expected_target = tostring(target_signature or "nil")
    local chain_target = tostring(chain_state.target_signature or "nil")
    if require_target_match == true
        and is_present_phase(expected_target)
        and is_present_phase(chain_target)
        and chain_target ~= expected_target then
        return false, current_phase .. ":target_mismatch"
    end

    return true, current_phase
end

function hybrid_executor.grant_chain_state(data, phase, target_signature, now, duration_seconds, reason)
    if type(data) ~= "table" or not is_present_phase(phase) then
        return nil
    end

    local current_time = tonumber(now) or 0.0
    local duration = tonumber(duration_seconds) or 0.75
    data.chain_state = {
        phase = tostring(phase),
        target_signature = tostring(target_signature or "nil"),
        granted_at = current_time,
        expires_at = current_time + duration,
        reason = tostring(reason or "chain_grant"),
    }

    return data.chain_state
end

function hybrid_executor.clear_chain_state(data, reason)
    if type(data) ~= "table" then
        return
    end

    data.last_chain_clear_reason = tostring(reason or "chain_clear")
    data.chain_state = nil
end

function hybrid_executor.describe_chain(data, now)
    local chain_state = hybrid_executor.get_chain_state(data, now)
    if type(chain_state) ~= "table" then
        return "inactive"
    end

    local current_time = tonumber(now) or 0.0
    local remaining = math.max(0.0, (tonumber(chain_state.expires_at) or current_time) - current_time)
    return string.format(
        "%s target=%s remaining=%.2f reason=%s",
        tostring(chain_state.phase or "nil"),
        tostring(chain_state.target_signature or "nil"),
        remaining,
        tostring(chain_state.reason or "nil")
    )
end

function hybrid_executor.get_cooldown_remaining(data, move_key, now)
    local expires_at = type(data.move_cooldowns) == "table" and data.move_cooldowns[tostring(move_key or "nil")] or nil
    if expires_at == nil then
        return 0.0
    end

    return math.max(0.0, tonumber(expires_at) - (tonumber(now) or 0.0))
end

function hybrid_executor.abort(data, reason, now)
    if type(data) ~= "table" or type(data.active) ~= "table" then
        return nil
    end

    return finish_active_move(data, "aborted", tostring(reason or "external_abort"), now)
end

function hybrid_executor.start(data, context, move, target_info, now)
    if type(data.active) == "table" then
        return false, {
            reason = "executor_busy",
        }
    end

    local active_state = {
        move = move,
        started_at = tonumber(now) or 0.0,
        target_signature = access.describe_obj(target_info and target_info.character),
        target_distance_at_start = tonumber(target_info and target_info.distance),
        closest_target_distance = tonumber(target_info and target_info.distance),
        bridge_info = nil,
        reissue_count = 0,
        damage_events = 0,
        damage_value_hits = 0,
        damage_target_hits = 0,
        damage_wrong_target_hits = 0,
        damage_total = 0.0,
        damage_assist_hits = 0,
        direct_damage_hits = 0,
        output_confirmed = false,
        output_timeout_count = 0,
    }

    data.active = active_state
    data.status = "active"
    data.reason = "move_started"
    set_step(active_state, 1, now)
    hybrid_interrupt_guard.activate(active_state, move, target_info, now)

    return true, {
        status = "started",
        outcome = "started",
        move = move,
    }
end

function hybrid_executor.describe_active(data)
    local active_state = data and data.active or nil
    if type(active_state) ~= "table" then
        return "inactive"
    end

    return string.format(
        "%s step=%s:%s target=%s reissues=%s",
        tostring(active_state.move and active_state.move.key or "nil"),
        tostring(active_state.step_index or "nil"),
        tostring(active_state.current_step and active_state.current_step.kind or "nil"),
        tostring(active_state.target_signature or "nil"),
        tostring(active_state.reissue_count or 0)
    )
end

function hybrid_executor.update(data, context, target_info, now)
    local active_state = data.active
    if type(active_state) ~= "table" then
        return nil
    end

    local current_target_distance = tonumber(target_info and target_info.distance)
    if current_target_distance ~= nil then
        active_state.last_target_distance = current_target_distance
        if active_state.closest_target_distance == nil
            or current_target_distance < tonumber(active_state.closest_target_distance) then
            active_state.closest_target_distance = current_target_distance
        end
    end

    local step = active_state.current_step
    if type(step) ~= "table" then
        return finish_active_move(data, "completed", "sequence_completed", now)
    end

    local guard_ok, guard_meta = hybrid_interrupt_guard.pulse(active_state, context, target_info, now)
    if not guard_ok then
        return finish_active_move(data, "aborted", tostring(guard_meta and guard_meta.reason or "guard_failed"), now)
    end

    if step.kind == "bridge" then
        if active_state.bridge_info == nil then
            if is_crash_prone_move(active_state.move) then
                log.warn(string.format(
                    "Job07 crash-prone bridge before apply move=%s entry_pack=%s entry_action=%s",
                    tostring(active_state.move and active_state.move.key or "nil"),
                    tostring(active_state.move and active_state.move.entry and active_state.move.entry.pack_path or "nil"),
                    tostring(active_state.move and active_state.move.entry and active_state.move.entry.action_name or "nil")
                ))
                log.flush()
            end
            local bridge_ok, bridge_info = hybrid_payloads.apply_entry(context, target_info, active_state.move.entry)
            active_state.bridge_info = bridge_info
            active_state.last_bridge_at = tonumber(now) or 0.0
            if is_crash_prone_move(active_state.move) then
                log.warn(string.format(
                    "Job07 crash-prone bridge after apply move=%s ok=%s %s",
                    tostring(active_state.move and active_state.move.key or "nil"),
                    tostring(bridge_ok),
                    tostring(summarize_bridge_info(bridge_info))
                ))
                log.flush()
            end
            if not bridge_ok then
                return finish_active_move(data, "failed", tostring(bridge_info and bridge_info.reason or "bridge_failed"), now)
            end
            set_step(active_state, active_state.step_index + 1, now)
        end

        return {
            status = "active",
            reason = "bridge_applied",
            move = active_state.move,
        }
    end

    if step.kind == "wait_output" then
        if hybrid_context.output_has_any_token(context, step.tokens or active_state.move.output_tokens) then
            active_state.output_confirmed = true
            active_state.output_confirmed_at = tonumber(now) or 0.0
            set_step(active_state, active_state.step_index + 1, now)
            return {
                status = "active",
                outcome = "output_confirmed",
                reason = "wait_output_confirmed",
                move = active_state.move,
            }
        end

        local timeout_seconds = tonumber(step.timeout_seconds) or 0.35
        local elapsed = (tonumber(now) or 0.0) - (tonumber(active_state.step_started_at) or 0.0)
        if elapsed >= timeout_seconds then
            if step.allow_continue_on_timeout == true then
                active_state.output_timeout_count = (tonumber(active_state.output_timeout_count) or 0) + 1
                set_step(active_state, active_state.step_index + 1, now)
                return {
                    status = "active",
                    outcome = "output_timeout_continue",
                    reason = "wait_output_timeout_continue",
                    move = active_state.move,
                }
            end

            return finish_active_move(data, "failed", "wait_output_timeout", now)
        end

        return {
            status = "active",
            reason = "wait_output_pending",
            move = active_state.move,
        }
    end

    if step.kind == "hold_target" then
        local character = target_info and target_info.character or nil
        if not access.is_valid_obj(character) then
            return finish_active_move(data, "aborted", "hold_target_missing", now)
        end

        local distance = target_info and target_info.distance
            or hybrid_targeting.compute_distance(context.runtime_character, character)
        if step.abort_on_out_of_range ~= false
            and step.max_distance ~= nil
            and distance ~= nil
            and distance > tonumber(step.max_distance) then
            return finish_active_move(data, "aborted", "hold_target_out_of_range", now)
        end

        local output_matches = hybrid_context.output_has_any_token(
            context,
            step.expected_output_tokens or active_state.move.output_tokens
        )
        local reissue_interval = tonumber(step.reissue_interval_seconds)
            or tonumber(combat_config().hold_reissue_interval_seconds)
            or 0.24
        local max_reissues = tonumber(combat_config().max_reissue_count) or 3
        if step.reissue_entry == true
            and not output_matches
            and active_state.step_reissue_count < max_reissues
            and (
                active_state.step_reissue_at == nil
                or ((tonumber(now) or 0.0) - active_state.step_reissue_at) >= reissue_interval
            ) then
            local bridge_ok, bridge_info = hybrid_payloads.apply_entry(context, target_info, active_state.move.entry)
            active_state.step_reissue_at = tonumber(now) or 0.0
            active_state.step_reissue_count = active_state.step_reissue_count + 1
            active_state.reissue_count = (tonumber(active_state.reissue_count) or 0) + 1
            active_state.bridge_info = bridge_info
            if not bridge_ok and step.abort_on_reissue_failure == true then
                return finish_active_move(
                    data,
                    "failed",
                    "hold_target_reissue_failed:" .. tostring(bridge_info and bridge_info.reason or "bridge_failed"),
                    now
                )
            end
        end

        local duration_seconds = tonumber(step.duration_seconds) or 0.40
        local elapsed = (tonumber(now) or 0.0) - (tonumber(active_state.step_started_at) or 0.0)
        if elapsed >= duration_seconds then
            set_step(active_state, active_state.step_index + 1, now)
            return {
                status = "active",
                reason = "hold_target_complete",
                move = active_state.move,
            }
        end

        return {
            status = "active",
            reason = "hold_target_active",
            move = active_state.move,
        }
    end

    if step.kind == "wait_damage" then
        local character = target_info and target_info.character or nil
        if step.require_target ~= false and not access.is_valid_obj(character) then
            return finish_active_move(data, "aborted", "wait_damage_target_missing", now)
        end

        local distance = target_info and target_info.distance
            or hybrid_targeting.compute_distance(context.runtime_character, character)
        if step.abort_on_out_of_range == true
            and step.max_distance ~= nil
            and distance ~= nil
            and distance > tonumber(step.max_distance) then
            return finish_active_move(data, "aborted", "wait_damage_out_of_range", now)
        end

        local damage_delta = (tonumber(active_state.damage_events) or 0)
            - (tonumber(active_state.step_damage_events_at) or 0)
        if step.complete_on_damage == true and damage_delta > 0 then
            set_step(active_state, active_state.step_index + 1, now)
            return {
                status = "active",
                reason = "wait_damage_confirmed",
                move = active_state.move,
            }
        end

        local duration_seconds = tonumber(step.duration_seconds) or 0.35
        local elapsed = (tonumber(now) or 0.0) - (tonumber(active_state.step_started_at) or 0.0)
        if elapsed >= duration_seconds then
            if damage_delta <= 0 then
                local fallback_ok, fallback_reason = direct_damage.apply_fallback(
                    active_state,
                    context,
                    target_info,
                    now
                )
                if fallback_ok then
                    damage_delta = (tonumber(active_state.damage_events) or 0)
                        - (tonumber(active_state.step_damage_events_at) or 0)
                elseif fallback_reason ~= "disabled" and fallback_reason ~= "move_disabled" then
                    log.info(string.format(
                        "Job%02d direct_damage_fallback skipped move=%s reason=%s",
                        tonumber(active_state.move and active_state.move.job_id) or 0,
                        tostring(active_state.move and active_state.move.key or "nil"),
                        tostring(fallback_reason or "nil")
                    ))
                end
            end
            set_step(active_state, active_state.step_index + 1, now)
            return {
                status = "active",
                reason = "wait_damage_complete",
                move = active_state.move,
            }
        end

        return {
            status = "active",
            reason = "wait_damage_active",
            move = active_state.move,
        }
    end

    if step.kind == "end" then
        return finish_active_move(data, "completed", "sequence_completed", now)
    end

    log.warn(string.format(
        "Job%02d executor encountered unknown step kind move=%s step=%s",
        tonumber(active_state.move and active_state.move.job_id) or 0,
        tostring(active_state.move and active_state.move.key or "nil"),
        tostring(step.kind or "nil")
    ))
    return finish_active_move(data, "failed", "unknown_step_kind", now)
end

return hybrid_executor
