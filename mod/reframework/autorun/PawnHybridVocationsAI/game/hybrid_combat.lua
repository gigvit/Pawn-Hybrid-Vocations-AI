local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/core/runtime")
local log = require("PawnHybridVocationsAI/core/log")
local access = require("PawnHybridVocationsAI/core/access")
local hybrid_context = require("PawnHybridVocationsAI/game/hybrid_context")
local hybrid_targeting = require("PawnHybridVocationsAI/game/hybrid_targeting")
local hybrid_executor = require("PawnHybridVocationsAI/game/hybrid_executor")
local combat_telemetry = require("PawnHybridVocationsAI/game/combat_telemetry")
local attack_graphs = require("PawnHybridVocationsAI/data/attack_graphs")
local combat_brain = require("PawnHybridVocationsAI/game/combat_brain")

local hybrid_combat = {}

local SPECIAL_SKIP_TOKENS = {
    "talk",
    "greeting",
    "highfive",
    "chilling",
    "perform_chilling",
    "lookat",
    "sortitem",
    "treasurebox",
    "carry",
    "cling",
    "winbattle",
    "dmgstandup",
    "damage.damage_root",
    "damage_root.dmg",
    "damage.statuscondition_root",
    "dmgdown",
    "dmgblow",
    "dmgknock",
    "dmgstatus",
    "statussleep",
    "sleepdown",
    "moveintohealingspot",
    "healing_spot",
}

local function combat_config()
    return config.combat or {}
end

local function log_prefix(context)
    return string.format("Job%02d", tonumber(context and context.current_job) or 0)
end

local function is_job_supported(job_id)
    local cfg = combat_config()
    if type(cfg.supported_job_ids) == "table" then
        for _, supported_job_id in ipairs(cfg.supported_job_ids) do
            if tonumber(supported_job_id) == tonumber(job_id) then
                return true
            end
        end
        return false
    end

    if cfg.supported_job_id ~= nil then
        return tonumber(cfg.supported_job_id) == tonumber(job_id)
    end

    return attack_graphs.has(job_id)
end

local function is_present_text(value)
    return type(value) == "string" and value ~= "" and value ~= "nil" and value ~= "none"
end

local function contains_any_text(text, tokens)
    local haystack = tostring(text or "")
    for _, token in ipairs(tokens or {}) do
        local needle = string.lower(tostring(token or ""))
        if needle ~= "" and haystack:find(needle, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function find_any_text(text, tokens)
    local haystack = tostring(text or "")
    for _, token in ipairs(tokens or {}) do
        local needle = string.lower(tostring(token or ""))
        if needle ~= "" and haystack:find(needle, 1, true) ~= nil then
            return true, needle
        end
    end
    return false, nil
end

local function distance_log_bucket(distance)
    local value = tonumber(distance)
    if value == nil then
        return "nil"
    end

    return string.format("%.1f", math.floor((value * 10.0) + 0.5) / 10.0)
end

local function describe_target_signature(target_info)
    return tostring(target_info and target_info.character_signature or access.describe_obj(target_info and target_info.character))
end

local function is_crash_prone_move(move)
    if type(move) ~= "table" then
        return false
    end

    local selection = move.selection or {}
    return tostring(move.stability or selection.stability or "stable") == "crash_prone"
end

local function summarize_skill_ids(lifecycle, skill_ids)
    if type(lifecycle) ~= "table" or type(skill_ids) ~= "table" then
        return "none"
    end

    local values = {}
    for _, skill_id in ipairs(skill_ids) do
        local item = lifecycle.skills_by_id and lifecycle.skills_by_id[skill_id] or nil
        values[#values + 1] = string.format(
            "%s:%s",
            tostring(skill_id),
            tostring(item and item.name or ("skill_" .. tostring(skill_id)))
        )
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function summarize_combat_ready_skills(pawn_state)
    local lifecycle = pawn_state and pawn_state.current_job_skill_lifecycle or nil
    local groups = lifecycle and lifecycle.groups or nil
    return summarize_skill_ids(lifecycle, groups and groups.combat_ready or nil)
end

local function summarize_equipped_skills(pawn_state)
    local lifecycle = pawn_state and pawn_state.current_job_skill_lifecycle or nil
    return summarize_skill_ids(lifecycle, lifecycle and lifecycle.equipped_skill_ids or nil)
end

local function summarize_equipped_slots(pawn_state)
    local lifecycle = pawn_state and pawn_state.current_job_skill_lifecycle or nil
    local values = {}

    for _, entry in ipairs(lifecycle and lifecycle.equipped_slots or {}) do
        local skill_id = access.decode_small_int(entry and entry.id)
        local slot = access.decode_small_int(entry and entry.slot)
        if skill_id ~= nil and skill_id ~= 0 then
            local item = lifecycle.skills_by_id and lifecycle.skills_by_id[skill_id] or nil
            values[#values + 1] = string.format(
                "%s:%s:%s",
                tostring(slot),
                tostring(skill_id),
                tostring(item and item.name or ("skill_" .. tostring(skill_id)))
            )
        else
            values[#values + 1] = string.format("%s:empty", tostring(slot))
        end
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function get_pawn_state(runtime)
    local progression = runtime and runtime.progression_state_data or nil
    return progression and progression.main_pawn or nil
end

local function get_current_job_level(pawn_state)
    local lifecycle = pawn_state and pawn_state.current_job_skill_lifecycle or nil
    return access.decode_small_int(pawn_state and pawn_state.current_job_level)
        or access.decode_small_int(lifecycle and lifecycle.current_job_level)
end

local function is_required_skill_ready(pawn_state, skill_id)
    if skill_id == nil then
        return true
    end

    local lifecycle = pawn_state and pawn_state.current_job_skill_lifecycle or nil
    local item = lifecycle and lifecycle.skills_by_id and lifecycle.skills_by_id[tonumber(skill_id)] or nil
    return item ~= nil and item.combat_ready == true
end

local function describe_candidates(candidates)
    if type(candidates) ~= "table" or #candidates == 0 then
        return "none"
    end

    local values = {}
    for index = 1, math.min(#candidates, 5) do
        local item = candidates[index]
        values[#values + 1] = string.format(
            "%s=%s",
            tostring(item.move and item.move.key or "nil"),
            tostring(item.score or 0)
        )
    end
    return table.concat(values, ",")
end

local function describe_blocked(blocked)
    if type(blocked) ~= "table" or #blocked == 0 then
        return "none"
    end

    local values = {}
    for index = 1, math.min(#blocked, 8) do
        local item = blocked[index]
        values[#values + 1] = string.format("%s:%s", tostring(item.key or "nil"), tostring(item.reason or "blocked"))
    end
    return table.concat(values, ",")
end

local function evaluate_move(move, context, pawn_state, target_distance, data, now)
    local selection = move.selection or {}
    local availability = move.availability or {}
    local current_job_level = get_current_job_level(pawn_state)
    local required_job_level = tonumber(selection.min_job_level)
    local required_skill_id = selection.required_skill_id or availability.skill_id
    local stability = tostring(move.stability or selection.stability or "stable")
    local target_signature = tostring(data and data.last_target_signature or "nil")

    if selection.disabled == true then
        return false, "selection_disabled"
    end
    if target_distance == nil then
        return false, "distance_unresolved"
    end
    if selection.min_distance ~= nil and target_distance < tonumber(selection.min_distance) then
        return false, "distance_too_close"
    end
    if selection.max_distance ~= nil and target_distance > tonumber(selection.max_distance) then
        return false, "distance_too_far"
    end
    if not is_required_skill_ready(pawn_state, required_skill_id) then
        return false, "required_skill_not_ready"
    end
    if required_job_level ~= nil and required_job_level > 0 then
        if current_job_level == nil then
            local availability_kind = tostring(availability.kind or "core")
            local allow_unresolved = selection.allow_unresolved_job_level == true
                or (
                    combat_config().allow_unresolved_job_level_for_core_moves == true
                    and availability_kind ~= "custom_skill"
                )
            if not allow_unresolved then
                return false, "job_level_unresolved"
            end
        end
        if current_job_level ~= nil and current_job_level < required_job_level then
            return false, "job_level_blocked"
        end
    end
    if stability == "crash_prone" and combat_config().allow_crash_prone_moves ~= true then
        return false, "crash_prone_blocked"
    end
    local brain_lockout_remaining = combat_brain.get_move_lockout_remaining(data, move, now)
    if brain_lockout_remaining > 0.0 then
        return false, string.format("brain_lockout_active:%.2f", brain_lockout_remaining)
    end
    if selection.required_chain_phase ~= nil then
        local ok, current_phase = hybrid_executor.chain_matches(
            data,
            selection.required_chain_phase,
            now,
            target_signature,
            selection.required_chain_target == true
        )
        if not ok then
            return false, "chain_phase_missing:" .. tostring(current_phase or "none")
        end

        local min_chain_age = tonumber(selection.required_chain_min_age_seconds)
        if min_chain_age ~= nil and min_chain_age > 0.0 then
            local chain_state = hybrid_executor.get_chain_state(data, now)
            local chain_age = (tonumber(now) or 0.0) - (tonumber(chain_state and chain_state.granted_at) or 0.0)
            if chain_age < min_chain_age then
                return false, string.format("chain_too_young:%.2f", min_chain_age - chain_age)
            end
        end
    end
    if selection.forbidden_chain_phase ~= nil then
        local forbidden, current_phase = hybrid_executor.chain_matches(
            data,
            selection.forbidden_chain_phase,
            now,
            target_signature,
            false
        )
        if forbidden then
            return false, "chain_phase_forbidden:" .. tostring(current_phase or "none")
        end
    end
    local active_chain_phase = hybrid_executor.get_chain_phase(data, now)
    if is_present_text(active_chain_phase)
        and tostring(move.family or "nil") ~= "job07_bind"
        and selection.allow_during_chain ~= true then
        return false, "chain_active:" .. tostring(active_chain_phase)
    end
    if type(selection.required_current_output_tokens) == "table"
        and #selection.required_current_output_tokens > 0
        and not hybrid_context.output_has_any_token(context, selection.required_current_output_tokens) then
        return false, "required_output_missing"
    end
    if type(selection.forbidden_current_output_tokens) == "table"
        and #selection.forbidden_current_output_tokens > 0
        and hybrid_context.output_has_any_token(context, selection.forbidden_current_output_tokens) then
        return false, "forbidden_output_present"
    end

    local cooldown_remaining = hybrid_executor.get_cooldown_remaining(data, move.key, now)
    if cooldown_remaining > 0.0 then
        return false, string.format("cooldown_active:%.2f", cooldown_remaining)
    end

    return true, "eligible"
end

local function score_move(move, target_distance, data, brain_plan, now)
    local selection = move.selection or {}
    local availability = move.availability or {}
    local bucket = tostring(selection.bucket or "utility")
    local score = tonumber(selection.priority) or 0
    local last_bucket = tostring(data.last_move_bucket or "nil")
    local last_family = tostring(data.last_move_family or "nil")
    local stability = tostring(move.stability or selection.stability or "stable")
    local recent_same_key = 0
    local recent_same_family = 0
    local recent_same_bucket = 0
    local history = type(data.move_history) == "table" and data.move_history or {}
    local inspected = 0

    if bucket == "opener" then
        score = score + (target_distance >= 3.50 and 12 or -4)
    elseif bucket == "sustain" then
        score = score + (target_distance <= 2.80 and 14 or -8)
    elseif bucket == "burst" then
        score = score + (target_distance <= 2.90 and 8 or -3)
    elseif bucket == "ranged" then
        score = score + (target_distance >= 4.00 and 10 or -10)
    end

    if last_bucket == "opener" then
        if bucket == "sustain" then
            score = score + 18
        elseif bucket == "burst" then
            score = score + 8
        elseif bucket == "opener" then
            score = score - 16
        end
    elseif last_bucket == "sustain" then
        if bucket == "burst" then
            score = score + 6
        elseif bucket == "opener" then
            score = score - 6
        end
    elseif last_bucket == "ranged" then
        if bucket == "opener" then
            score = score + 10
        end
    end

    if (selection.required_skill_id or availability.skill_id) ~= nil then
        score = score + 28
        if bucket == "ranged" and target_distance >= 5.00 then
            score = score + 12
        elseif bucket == "opener" and target_distance >= 4.50 then
            score = score + 8
        end
    end
    if stability == "crash_prone" then
        score = score - 14
    end
    if selection.required_chain_phase ~= nil then
        score = score + 82
    end

    for index = #history, 1, -1 do
        local entry = history[index]
        if type(entry) == "table" then
            inspected = inspected + 1
            if tostring(entry.key or "nil") == tostring(move.key or "nil") then
                recent_same_key = recent_same_key + 1
            end
            if tostring(entry.family or "nil") == tostring(move.family or "nil") then
                recent_same_family = recent_same_family + 1
            end
            if tostring(entry.bucket or "nil") == bucket then
                recent_same_bucket = recent_same_bucket + 1
            end
            if inspected >= 4 then
                break
            end
        end
    end

    if last_family == tostring(move.family or "nil") then
        score = score - 10
    end
    if tostring(data.last_move_key or "nil") == tostring(move.key or "nil") then
        score = score - 12
    end
    score = score - (recent_same_family * 12)
    score = score - (recent_same_key * 20)
    if recent_same_bucket >= 2 then
        score = score - 10
    end
    if tostring(data.last_move_result or "none") ~= "completed"
        and tostring(data.last_move_key or "nil") == tostring(move.key or "nil") then
        score = score - 8
    end

    return combat_brain.score_move(move, score, brain_plan, now)
end

local function choose_move(graph, runtime, context, target_info, data, now, brain_plan)
    local pawn_state = get_pawn_state(runtime)
    local target_distance = target_info and target_info.distance or nil
    local candidates = {}
    local blocked = {}

    for _, move in graph.each() do
        local ok, reason = evaluate_move(move, context, pawn_state, target_distance, data, now)
        if ok then
            candidates[#candidates + 1] = {
                move = move,
                score = score_move(move, target_distance, data, brain_plan, now),
            }
        else
            blocked[#blocked + 1] = {
                key = move.key,
                reason = reason,
            }
        end
    end

    table.sort(candidates, function(left, right)
        if tonumber(left.score) == tonumber(right.score) then
            return tostring(left.move.key) < tostring(right.move.key)
        end
        return tonumber(left.score) > tonumber(right.score)
    end)

    return candidates[1] and candidates[1].move or nil, candidates, blocked
end

local function should_skip_for_special_output(context)
    return find_any_text(
        context and context.output_blob_lower or string.lower(hybrid_context.build_output_blob(context)),
        SPECIAL_SKIP_TOKENS
    )
end

local function should_handoff_to_native_output(data, context, target_info, now, graph)
    if combat_config().respect_native_job_output ~= true or not hybrid_context.has_native_job_output(context) then
        data.native_output_signature = "nil"
        data.native_output_since = nil
        return false
    end

    if hybrid_executor.get_chain_phase(data, now) ~= nil then
        return false
    end

    local output_blob_lower = context and context.output_blob_lower or string.lower(hybrid_context.build_output_blob(context))
    local override_tokens = graph and graph.native_output_override_tokens or combat_config().basic_chain_native_output_tokens or {}
    if type(override_tokens) ~= "table" or #override_tokens == 0 then
        override_tokens = combat_config().basic_chain_native_output_tokens or {}
    end
    local override_max_distance = tonumber(combat_config().basic_chain_override_max_distance) or 3.35
    local takeover_delay = tonumber(combat_config().native_basic_chain_takeover_delay_seconds) or 0.28
    local distance = target_info and target_info.distance or nil
    local can_override = distance ~= nil
        and distance <= override_max_distance
        and contains_any_text(output_blob_lower, override_tokens)

    if data.native_output_signature ~= output_blob_lower then
        data.native_output_signature = output_blob_lower
        data.native_output_since = tonumber(now) or 0.0
    end

    if not can_override then
        return true
    end

    local elapsed = (tonumber(now) or 0.0) - (tonumber(data.native_output_since) or 0.0)
    return elapsed < takeover_delay
end

local function maybe_log_target(data, context, target_info, target_reason, probes, now)
    local interval = tonumber(combat_config().target_log_interval_seconds) or 1.25
    local target_signature = describe_target_signature(target_info)
    local probes_summary = hybrid_targeting.describe_probes(probes)
    local signature = table.concat({
        tostring(target_reason or "nil"),
        tostring(target_signature),
        distance_log_bucket(target_info and target_info.distance),
        tostring(probes_summary),
    }, " | ")

    if data.last_target_log_signature == signature
        and data.last_target_log_time ~= nil
        and ((tonumber(now) or 0.0) - data.last_target_log_time) < interval then
        return
    end

    data.last_target_log_signature = signature
    data.last_target_log_time = tonumber(now) or 0.0

    log.info(string.format(
        "%s target reason=%s target=%s dist=%s probes=%s",
        log_prefix(context),
        tostring(target_reason or "nil"),
        tostring(target_signature),
        tostring(target_info and target_info.distance or "nil"),
        tostring(probes_summary)
    ))
end

local function maybe_log_selection(data, runtime, context, target_info, move, candidate_summary, blocked_summary, brain_summary, now)
    local interval = tonumber(combat_config().selection_log_interval_seconds) or 1.25
    local pawn_state = get_pawn_state(runtime)
    local current_job_level = get_current_job_level(pawn_state)
    local target_signature = describe_target_signature(target_info)
    local equipped_summary = summarize_equipped_skills(pawn_state)
    local equipped_slots_summary = summarize_equipped_slots(pawn_state)
    local combat_ready_summary = summarize_combat_ready_skills(pawn_state)
    local chain_summary = hybrid_executor.describe_chain(data, now)
    local chain_log_key = tostring(hybrid_executor.get_chain_phase(data, now) or "inactive")
    local signature = table.concat({
        tostring(move and move.key or "none"),
        tostring(target_signature),
        distance_log_bucket(target_info and target_info.distance),
        tostring(current_job_level or "nil"),
        tostring(candidate_summary),
        tostring(equipped_summary),
        tostring(equipped_slots_summary),
        tostring(combat_ready_summary),
        chain_log_key,
        tostring(brain_summary or "legacy"),
    }, " | ")

    if data.last_selection_log_signature == signature
        and data.last_selection_log_time ~= nil
        and ((tonumber(now) or 0.0) - data.last_selection_log_time) < interval then
        return
    end

    data.last_selection_log_signature = signature
    data.last_selection_log_time = tonumber(now) or 0.0

    log.info(string.format(
        "%s selector move=%s target=%s dist=%s job_level=%s candidates=%s blocked=%s equipped=%s slots=%s combat_ready=%s chain=%s brain=%s",
        log_prefix(context),
        tostring(move and move.key or "none"),
        tostring(target_signature),
        tostring(target_info and target_info.distance or "nil"),
        tostring(current_job_level or "nil"),
        tostring(candidate_summary),
        tostring(blocked_summary),
        tostring(equipped_summary),
        tostring(equipped_slots_summary),
        tostring(combat_ready_summary),
        tostring(chain_summary),
        tostring(brain_summary or "legacy")
    ))
end

local function maybe_log_no_target(data, context, now, reason)
    local interval = tonumber(combat_config().no_target_log_interval_seconds) or 2.50
    if data.last_no_target_log_time ~= nil
        and ((tonumber(now) or 0.0) - data.last_no_target_log_time) < interval then
        return
    end

    data.last_no_target_log_time = tonumber(now) or 0.0
    log.info(string.format("%s no target reason=%s", log_prefix(context), tostring(reason or "target_unresolved")))
end

local function maybe_log_snapshot(data, context, target_info, now)
    local interval = tonumber(combat_config().snapshot_log_interval_seconds) or 2.00
    if data.last_snapshot_time ~= nil
        and ((tonumber(now) or 0.0) - data.last_snapshot_time) < interval then
        return
    end

    data.last_snapshot_time = tonumber(now) or 0.0
    log.info(string.format(
        "%s snapshot status=%s reason=%s active=%s chain=%s brain=%s output=%s target=%s dist=%s damage=%s",
        log_prefix(context),
        tostring(data.status or "nil"),
        tostring(data.reason or "nil"),
        tostring(hybrid_executor.describe_active(data)),
        tostring(hybrid_executor.describe_chain(data, now)),
        tostring(combat_brain.describe(combat_brain.plan(data.current_graph, data, context, target_info, now))),
        tostring(hybrid_context.build_output_blob(context)),
        tostring(describe_target_signature(target_info)),
        tostring(target_info and target_info.distance or "nil"),
        tostring(combat_telemetry.describe_recent(now))
    ))
end

local function log_executor_event(event, context)
    if type(event) ~= "table" or type(event.move) ~= "table" then
        return
    end

    if tostring(event.status or "active") == "active" then
        return
    end

    log.info(string.format(
        "%s executor move=%s status=%s outcome=%s reason=%s damage=%s",
        log_prefix(context),
        tostring(event.move.key or "nil"),
        tostring(event.status or "nil"),
        tostring(event.outcome or "nil"),
        tostring(event.reason or "nil"),
        tostring(event.damage_summary or "none")
    ))
end

function hybrid_combat.update()
    local runtime = state.runtime
    local data = hybrid_executor.ensure_state(runtime)
    local now = tonumber(runtime and runtime.game_time or os.clock()) or 0.0

    if combat_config().enabled ~= true then
        data.status = "disabled"
        data.reason = "combat_disabled"
        return data
    end

    local context, context_reason = hybrid_context.resolve(runtime)
    if context == nil then
        data.status = "skipped"
        data.reason = tostring(context_reason or "context_unresolved")
        return data
    end

    local graph = attack_graphs.get(context.current_job)
    if graph == nil then
        data.status = "observe_only"
        data.reason = "attack_graph_unresolved"
        return data
    end
    if not is_job_supported(context.current_job) then
        data.status = "observe_only"
        data.reason = "unsupported_job"
        return data
    end
    if tonumber(data.current_job_id) ~= tonumber(context.current_job) then
        if type(data.active) == "table" then
            local executor_event = hybrid_executor.abort(data, "job_changed", now)
            combat_brain.observe_executor_event(data, executor_event, now)
            log_executor_event(executor_event, context)
        end
        data.current_job_id = tonumber(context.current_job)
        data.current_graph_key = tostring(graph.key or "unknown")
        data.move_cooldowns = {}
        data.chain_state = nil
        combat_brain.reset_for_job(data, graph)
    end
    data.current_graph = graph

    local target_info, target_reason, probes = hybrid_targeting.resolve(context, runtime, data, now)
    data.last_target_signature = describe_target_signature(target_info)
    data.last_target_reason = tostring(target_reason or "nil")
    data.last_target_distance = target_info and target_info.distance or nil
    maybe_log_target(data, context, target_info, target_reason, probes, now)

    local skip_special, special_token = should_skip_for_special_output(context)
    if skip_special then
        local reason = "special_output_state:" .. tostring(special_token or "unknown")
        local executor_event = hybrid_executor.abort(data, reason, now)
        combat_brain.observe_executor_event(data, executor_event, now)
        log_executor_event(executor_event, context)
        data.status = "skipped"
        data.reason = reason
        maybe_log_snapshot(data, context, target_info, now)
        return data
    end

    local executor_event = hybrid_executor.update(data, context, target_info, now)
    combat_brain.observe_executor_event(data, executor_event, now)
    log_executor_event(executor_event, context)
    if type(data.active) == "table" then
        maybe_log_snapshot(data, context, target_info, now)
        return data
    end

    if target_info == nil or not access.is_valid_obj(target_info.character) then
        data.status = "idle"
        data.reason = "no_enemy_target"
        maybe_log_no_target(data, context, now, target_reason)
        maybe_log_snapshot(data, context, target_info, now)
        return data
    end

    if should_handoff_to_native_output(data, context, target_info, now, data.current_graph) then
        data.status = "native_output"
        data.reason = "native_job_output_present"
        maybe_log_snapshot(data, context, target_info, now)
        return data
    end

    local brain_plan = combat_brain.plan(data.current_graph, data, context, target_info, now)
    local brain_summary = combat_brain.describe(brain_plan)
    if brain_plan.decision_blocked == true then
        data.status = "skipped"
        data.reason = tostring(brain_plan.decision_reason or "brain_cadence_wait")
        maybe_log_selection(data, runtime, context, target_info, nil, "none", data.last_blocked_summary, brain_summary, now)
        maybe_log_snapshot(data, context, target_info, now)
        return data
    end

    local move, candidates, blocked = choose_move(data.current_graph, runtime, context, target_info, data, now, brain_plan)
    local candidate_summary = describe_candidates(candidates)
    local blocked_summary = describe_blocked(blocked)
    data.last_selection_summary = candidate_summary
    data.last_blocked_summary = blocked_summary
    maybe_log_selection(data, runtime, context, target_info, move, candidate_summary, blocked_summary, brain_summary, now)
    if is_crash_prone_move(move) then
        log.warn(string.format(
            "%s crash-prone candidate selected move=%s target=%s dist=%s candidates=%s blocked=%s",
            log_prefix(context),
            tostring(move.key or "nil"),
            tostring(describe_target_signature(target_info)),
            tostring(target_info and target_info.distance or "nil"),
            tostring(candidate_summary),
            tostring(blocked_summary)
        ))
    end

    if move == nil then
        data.status = "skipped"
        data.reason = "no_move_candidate"
        maybe_log_snapshot(data, context, target_info, now)
        return data
    end

    local started, start_meta = hybrid_executor.start(data, context, move, target_info, now)
    if not started then
        data.status = "failed"
        data.reason = tostring(start_meta and start_meta.reason or "executor_start_failed")
        maybe_log_snapshot(data, context, target_info, now)
        return data
    end

    log.info(string.format(
        "%s start move=%s target=%s dist=%s brain=%s output=%s",
        log_prefix(context),
        tostring(move.key or "nil"),
        tostring(describe_target_signature(target_info)),
        tostring(target_info.distance),
        tostring(brain_summary),
        tostring(hybrid_context.build_output_blob(context))
    ))
    if is_crash_prone_move(move) then
        log.warn(string.format(
            "%s crash-prone start flushed move=%s output=%s",
            log_prefix(context),
            tostring(move.key or "nil"),
            tostring(hybrid_context.build_output_blob(context))
        ))
        log.flush()
    end

    executor_event = hybrid_executor.update(data, context, target_info, now)
    combat_brain.observe_executor_event(data, executor_event, now)
    log_executor_event(executor_event, context)
    maybe_log_snapshot(data, context, target_info, now)
    return data
end

return hybrid_combat
