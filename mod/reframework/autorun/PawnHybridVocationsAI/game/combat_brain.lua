local config = require("PawnHybridVocationsAI/config")
local hybrid_executor = require("PawnHybridVocationsAI/game/hybrid_executor")

local combat_brain = {}

local function combat_config()
    return config.combat or {}
end

local function ensure_brain(data)
    if type(data.combat_brain) ~= "table" then
        data.combat_brain = {
            job_id = nil,
            graph_key = "nil",
            stage = "none",
            stage_reason = "init",
            stage_since = nil,
            next_decision_at = nil,
            last_outcome = "none",
            last_outcome_reason = "none",
            last_outcome_move_key = "nil",
            last_outcome_family = "nil",
            last_outcome_bucket = "nil",
            last_outcome_at = nil,
            consecutive_no_damage = 0,
            consecutive_wrong_target = 0,
            consecutive_timeouts = 0,
            hit_streak = 0,
            move_lockouts = {},
        }
    end

    return data.combat_brain
end

local function selection_bucket(move)
    return tostring(move and move.selection and move.selection.bucket or "utility")
end

local function selection_role(move)
    return tostring(move and move.selection and move.selection.role or "attack")
end

local function is_recent(now, timestamp, window_seconds)
    local time = tonumber(timestamp)
    if time == nil then
        return false
    end

    return ((tonumber(now) or 0.0) - time) <= (tonumber(window_seconds) or 0.0)
end

local function has_active_chain(data, now)
    return hybrid_executor.get_chain_phase(data, now) ~= nil
end

local function cadence_for_event(event)
    local move = event and event.move or nil
    local bucket = selection_bucket(move)
    local outcome = tostring(event and event.outcome or event and event.status or "none")
    local cfg = combat_config()

    if bucket == "follow_through" or outcome == "hit_confirmed" then
        return tonumber(cfg.brain_hit_recovery_seconds) or 0.22
    end
    if outcome == "wrong_target" then
        return tonumber(cfg.brain_wrong_target_recovery_seconds) or 0.72
    end
    if outcome == "no_damage_window" or outcome == "output_timeout" then
        return tonumber(cfg.brain_no_damage_recovery_seconds) or 0.52
    end
    if outcome == "timed_out" or outcome == "failed" or outcome == "aborted" then
        return tonumber(cfg.brain_failure_recovery_seconds) or 0.58
    end
    if bucket == "opener" then
        return tonumber(cfg.brain_opener_recovery_seconds) or 0.18
    end
    if bucket == "burst" then
        return tonumber(cfg.brain_burst_recovery_seconds) or 0.38
    end

    return tonumber(cfg.brain_default_recovery_seconds) or 0.32
end

function combat_brain.reset_for_job(data, graph)
    if type(data) ~= "table" then
        return
    end

    data.combat_brain = nil
    local brain = ensure_brain(data)
    brain.job_id = tonumber(graph and graph.job_id)
    brain.graph_key = tostring(graph and graph.key or "nil")
end

function combat_brain.observe_executor_event(data, event, now)
    if type(data) ~= "table" or type(event) ~= "table" or type(event.move) ~= "table" then
        return nil
    end
    if tostring(event.status or "active") == "active" or tostring(event.status or "nil") == "started" then
        return nil
    end

    local brain = ensure_brain(data)
    local outcome = tostring(event.outcome or event.status or "none")
    local move = event.move
    local current_time = tonumber(now) or 0.0

    brain.job_id = tonumber(move.job_id) or tonumber(brain.job_id)
    brain.graph_key = tostring(move.job_key or brain.graph_key or "nil")
    brain.last_outcome = outcome
    brain.last_outcome_reason = tostring(event.reason or "none")
    brain.last_outcome_move_key = tostring(move.key or "nil")
    brain.last_outcome_family = tostring(move.family or "nil")
    brain.last_outcome_bucket = selection_bucket(move)
    brain.last_outcome_at = current_time
    brain.move_lockouts = type(brain.move_lockouts) == "table" and brain.move_lockouts or {}

    local move_brain = type(move.brain) == "table" and move.brain or {}
    local lockout_key = tostring(move_brain.lockout_key or "")
    local lockout_seconds = tonumber(move_brain.lockout_seconds)
    if lockout_key ~= "" and lockout_key ~= "nil" and lockout_seconds ~= nil and lockout_seconds > 0.0 then
        brain.move_lockouts[lockout_key] = current_time + lockout_seconds
    end

    if outcome == "hit_confirmed" then
        brain.hit_streak = (tonumber(brain.hit_streak) or 0) + 1
        brain.consecutive_no_damage = 0
        brain.consecutive_wrong_target = 0
        brain.consecutive_timeouts = 0
    elseif outcome == "wrong_target" then
        brain.consecutive_wrong_target = (tonumber(brain.consecutive_wrong_target) or 0) + 1
        brain.consecutive_no_damage = 0
        brain.consecutive_timeouts = 0
        brain.hit_streak = 0
    elseif outcome == "no_damage_window" or outcome == "output_timeout" then
        brain.consecutive_no_damage = (tonumber(brain.consecutive_no_damage) or 0) + 1
        if outcome == "output_timeout" then
            brain.consecutive_timeouts = (tonumber(brain.consecutive_timeouts) or 0) + 1
        end
        brain.hit_streak = 0
    elseif outcome == "timed_out" or outcome == "failed" or outcome == "aborted" then
        brain.consecutive_timeouts = (tonumber(brain.consecutive_timeouts) or 0) + 1
        brain.hit_streak = 0
    else
        brain.consecutive_no_damage = math.max(0, (tonumber(brain.consecutive_no_damage) or 0) - 1)
        brain.consecutive_wrong_target = math.max(0, (tonumber(brain.consecutive_wrong_target) or 0) - 1)
        brain.consecutive_timeouts = math.max(0, (tonumber(brain.consecutive_timeouts) or 0) - 1)
    end

    brain.next_decision_at = current_time + cadence_for_event(event)
    return brain
end

function combat_brain.get_move_lockout_remaining(data, move, now)
    if type(data) ~= "table" or type(move) ~= "table" or type(move.brain) ~= "table" then
        return 0.0
    end

    local lockout_key = tostring(move.brain.lockout_key or "")
    if lockout_key == "" or lockout_key == "nil" then
        return 0.0
    end

    local brain = ensure_brain(data)
    brain.move_lockouts = type(brain.move_lockouts) == "table" and brain.move_lockouts or {}
    local expires_at = tonumber(brain.move_lockouts[lockout_key])
    if expires_at == nil then
        return 0.0
    end

    local remaining = expires_at - (tonumber(now) or 0.0)
    if remaining <= 0.0 then
        brain.move_lockouts[lockout_key] = nil
        return 0.0
    end

    return remaining
end

local function classify_stage(data, target_info, now)
    local brain = ensure_brain(data)
    local distance = tonumber(target_info and target_info.distance)
    local chain_phase = hybrid_executor.get_chain_phase(data, now)
    local recent_outcome = is_recent(now, brain.last_outcome_at, 1.40)
    local last_outcome = tostring(brain.last_outcome or "none")

    if chain_phase ~= nil then
        return "follow_through", "chain:" .. tostring(chain_phase)
    end

    if distance == nil then
        return "observe", "distance_unresolved"
    end

    if recent_outcome and last_outcome == "wrong_target" then
        return "reorient", "recent_wrong_target"
    end

    if recent_outcome and (last_outcome == "no_damage_window" or last_outcome == "output_timeout") then
        if distance <= 2.35 then
            return "melee_probe", "recent_no_damage_close"
        end
        return "reopen", "recent_no_damage_far"
    end

    if distance <= 2.05 then
        if recent_outcome and last_outcome == "hit_confirmed" then
            return "close_burst", "recent_hit_close"
        end
        return "close_sustain", "close_target"
    end

    if distance <= 3.15 then
        return "close_in", "edge_of_melee"
    end

    if distance >= 4.75 then
        return "ranged_or_gapclose", "far_target"
    end

    return "opener", "mid_target"
end

function combat_brain.plan(graph, data, context, target_info, now)
    if type(data) ~= "table" or type(graph) ~= "table" then
        return {
            enabled = false,
            stage = "legacy",
            stage_reason = "graph_unresolved",
            decision_blocked = false,
        }
    end

    local brain = ensure_brain(data)
    local current_time = tonumber(now) or 0.0
    brain.job_id = tonumber(graph.job_id) or tonumber(brain.job_id)
    brain.graph_key = tostring(graph.key or brain.graph_key or "nil")

    local stage, stage_reason = classify_stage(data, target_info, current_time)
    if brain.stage ~= stage then
        brain.stage = stage
        brain.stage_reason = stage_reason
        brain.stage_since = current_time
    else
        brain.stage_reason = stage_reason
    end

    local chain_active = has_active_chain(data, current_time)
    local next_decision_at = tonumber(brain.next_decision_at)
    local decision_blocked = false
    local decision_reason = "ready"
    if not chain_active and next_decision_at ~= nil and next_decision_at > current_time then
        decision_blocked = true
        decision_reason = string.format("cadence_wait:%.2f", next_decision_at - current_time)
    end

    return {
        enabled = true,
        brain = brain,
        job_id = tonumber(graph.job_id),
        graph_key = tostring(graph.key or "nil"),
        stage = stage,
        stage_reason = stage_reason,
        decision_blocked = decision_blocked,
        decision_reason = decision_reason,
        target_distance = target_info and target_info.distance or nil,
        chain_active = chain_active,
        last_outcome = tostring(brain.last_outcome or "none"),
        last_outcome_move_key = tostring(brain.last_outcome_move_key or "nil"),
        last_outcome_family = tostring(brain.last_outcome_family or "nil"),
        last_outcome_at = brain.last_outcome_at,
        consecutive_no_damage = tonumber(brain.consecutive_no_damage) or 0,
        consecutive_wrong_target = tonumber(brain.consecutive_wrong_target) or 0,
        consecutive_timeouts = tonumber(brain.consecutive_timeouts) or 0,
        hit_streak = tonumber(brain.hit_streak) or 0,
    }
end

local function bucket_bonus(stage, bucket, role, distance)
    if stage == "follow_through" then
        return bucket == "follow_through" and 220 or -80
    end
    if stage == "close_sustain" then
        if bucket == "sustain" then
            return 44
        end
        if bucket == "burst" then
            return 14
        end
        if bucket == "defense" then
            return 4
        end
        if bucket == "opener" or bucket == "ranged" then
            return -42
        end
    elseif stage == "close_burst" then
        if bucket == "burst" then
            return 42
        end
        if bucket == "sustain" then
            return 24
        end
        if bucket == "opener" or bucket == "ranged" then
            return -48
        end
    elseif stage == "melee_probe" then
        if role == "basic_attack" then
            return 58
        end
        if bucket == "sustain" then
            return 30
        end
        if bucket == "burst" then
            return -16
        end
        if bucket == "opener" then
            return -34
        end
    elseif stage == "reorient" then
        if distance ~= nil and distance > 2.65 then
            return bucket == "opener" and 34 or -8
        end
        return bucket == "sustain" and 30 or (bucket == "burst" and 8 or -12)
    elseif stage == "reopen" then
        if bucket == "opener" then
            return 42
        end
        if bucket == "ranged" then
            return 18
        end
        if bucket == "sustain" or bucket == "burst" then
            return -24
        end
    elseif stage == "close_in" then
        if bucket == "opener" then
            return 24
        end
        if bucket == "sustain" then
            return 18
        end
        if bucket == "ranged" then
            return -28
        end
    elseif stage == "ranged_or_gapclose" then
        if bucket == "opener" then
            return 44
        end
        if bucket == "ranged" then
            return 24
        end
        if bucket == "sustain" or bucket == "burst" then
            return -36
        end
    elseif stage == "opener" then
        if bucket == "opener" then
            return 36
        end
        if bucket == "ranged" then
            return 12
        end
        if bucket == "sustain" then
            return -8
        end
        if bucket == "burst" then
            return -20
        end
    end

    return 0
end

function combat_brain.score_move(move, base_score, plan, now)
    if type(plan) ~= "table" or plan.enabled ~= true or type(move) ~= "table" then
        return tonumber(base_score) or 0
    end

    local score = tonumber(base_score) or 0
    local bucket = selection_bucket(move)
    local role = selection_role(move)
    local stage = tostring(plan.stage or "legacy")
    local distance = tonumber(plan.target_distance)
    local last_outcome = tostring(plan.last_outcome or "none")
    local last_key = tostring(plan.last_outcome_move_key or "nil")
    local last_family = tostring(plan.last_outcome_family or "nil")
    local recent = is_recent(now, plan.last_outcome_at, 1.65)

    score = score + bucket_bonus(stage, bucket, role, distance)

    if recent and tostring(move.key or "nil") == last_key then
        if last_outcome == "hit_confirmed" then
            score = score - 8
        elseif last_outcome == "wrong_target" then
            score = score - 54
        elseif last_outcome == "no_damage_window" or last_outcome == "output_timeout" then
            score = score - 44
        elseif last_outcome == "timed_out" or last_outcome == "failed" or last_outcome == "aborted" then
            score = score - 36
        end
    end

    if recent and tostring(move.family or "nil") == last_family then
        if last_outcome == "wrong_target" then
            score = score - 26
        elseif last_outcome == "no_damage_window" or last_outcome == "output_timeout" then
            score = score - 18
        end
    end

    if (tonumber(plan.consecutive_no_damage) or 0) >= 2 then
        if role == "basic_attack" then
            score = score + 34
        elseif bucket == "burst" then
            score = score - 22
        end
    end

    if (tonumber(plan.consecutive_wrong_target) or 0) >= 1 then
        if bucket == "opener" and distance ~= nil and distance > 2.65 then
            score = score + 18
        elseif role == "basic_attack" and distance ~= nil and distance <= 2.35 then
            score = score + 20
        end
    end

    if (tonumber(plan.consecutive_timeouts) or 0) >= 2 and bucket == "ranged" then
        score = score - 18
    end

    if type(move.selection) == "table" and move.selection.required_chain_phase ~= nil then
        score = score + 120
    end

    return score
end

function combat_brain.describe(plan)
    if type(plan) ~= "table" or plan.enabled ~= true then
        return "legacy"
    end

    return string.format(
        "job=%s graph=%s stage=%s reason=%s decision=%s last=%s:%s nd=%s miss=%s wrong=%s timeout=%s hits=%s",
        tostring(plan.job_id or "nil"),
        tostring(plan.graph_key or "nil"),
        tostring(plan.stage or "nil"),
        tostring(plan.stage_reason or "nil"),
        tostring(plan.decision_reason or "ready"),
        tostring(plan.last_outcome_move_key or "nil"),
        tostring(plan.last_outcome or "none"),
        tostring(plan.brain and plan.brain.next_decision_at or "nil"),
        tostring(plan.consecutive_no_damage or 0),
        tostring(plan.consecutive_wrong_target or 0),
        tostring(plan.consecutive_timeouts or 0),
        tostring(plan.hit_streak or 0)
    )
end

return combat_brain
