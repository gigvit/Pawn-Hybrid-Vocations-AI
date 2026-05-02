local config = require("PawnHybridVocationsAI/config")
local log = require("PawnHybridVocationsAI/core/log")
local access = require("PawnHybridVocationsAI/core/access")

local direct_damage = {}

local function combat_config()
    return config.combat or {}
end

local function fallback_enabled()
    return combat_config().direct_damage_fallback_enabled == true
end

local function resolve_hit_controller(character)
    return access.field_first(character, {
        "<Hit>k__BackingField",
        "Hit",
        "<HitController>k__BackingField",
        "HitController",
    })
end

local function set_first_field(obj, names, value)
    for _, name in ipairs(names or {}) do
        if access.safe_set_field(obj, name, value) then
            return true
        end
    end

    return false
end

local function make_damage_info(hit_controller, damage, context)
    if type(sdk) ~= "table" or type(sdk.create_instance) ~= "function" then
        return nil, "sdk_create_instance_unavailable"
    end

    local ok, damage_info = pcall(sdk.create_instance, "app.HitController.DamageInfo")
    if not ok or not access.is_valid_obj(damage_info) then
        return nil, "damage_info_create_failed:" .. tostring(damage_info)
    end

    set_first_field(damage_info, { "Damage", "<Damage>k__BackingField" }, damage)
    set_first_field(damage_info, { "IsDirectDamage", "<IsDirectDamage>k__BackingField" }, true)
    set_first_field(damage_info, {
        "<DamageHitController>k__BackingField",
        "DamageHitController",
    }, hit_controller)

    local attacker_object = access.resolve_game_object(context and context.runtime_character, true)
    if access.is_valid_obj(attacker_object) then
        set_first_field(damage_info, {
            "<AttackOwnerObject>k__BackingField",
            "AttackOwnerObject",
        }, attacker_object)
    end

    return damage_info, "ready"
end

local function apply_update_damage_hp(hit_controller, damage_info, damage)
    local ok, value = pcall(function()
        return hit_controller:updateDamageHp(damage_info, damage, false)
    end)
    if ok then
        return true, "direct_method"
    end

    local call_ok, call_value = pcall(function()
        return hit_controller:call(
            "updateDamageHp(app.HitController.DamageInfo, System.Single, System.Boolean)",
            damage_info,
            damage,
            false
        )
    end)
    if call_ok then
        return true, "signature_call"
    end

    return false, tostring(value or call_value or "updateDamageHp_failed")
end

local function mark_active_as_damaged(active_state, damage)
    active_state.damage_events = (tonumber(active_state.damage_events) or 0) + 1
    active_state.damage_value_hits = (tonumber(active_state.damage_value_hits) or 0) + 1
    active_state.damage_target_hits = (tonumber(active_state.damage_target_hits) or 0) + 1
    active_state.damage_total = (tonumber(active_state.damage_total) or 0.0) + damage
    active_state.damage_assist_hits = (tonumber(active_state.damage_assist_hits) or 0) + 1
    active_state.direct_damage_hits = (tonumber(active_state.direct_damage_hits) or 0) + 1
    active_state.direct_damage_applied = true
end

function direct_damage.apply_fallback(active_state, context, target_info, now)
    if not fallback_enabled() then
        return false, "disabled"
    end
    if type(active_state) ~= "table" or type(active_state.move) ~= "table" then
        return false, "active_move_unresolved"
    end
    if active_state.direct_damage_applied == true then
        return false, "already_applied"
    end
    if active_state.output_confirmed ~= true then
        return false, "output_unconfirmed"
    end

    local move = active_state.move
    local profile = type(move.damage) == "table" and move.damage or {}
    if profile.direct_fallback ~= true then
        return false, "move_disabled"
    end

    local character = target_info and target_info.character or nil
    if not access.is_valid_obj(character) then
        return false, "target_unresolved"
    end

    local current_distance = target_info and tonumber(target_info.distance) or nil
    local closest_distance = tonumber(active_state.closest_target_distance)
    local distance = current_distance
    if closest_distance ~= nil and (distance == nil or closest_distance < distance) then
        distance = closest_distance
    end
    local max_distance = tonumber(profile.direct_fallback_max_distance)
        or tonumber(profile.direct_fallback_range)
        or tonumber(combat_config().direct_damage_fallback_max_distance)
        or 3.25
    if distance ~= nil and distance > max_distance then
        return false, string.format("target_out_of_range:%.2f>%.2f", distance, max_distance)
    end

    local hit_controller = resolve_hit_controller(character)
    if not access.is_valid_obj(hit_controller) then
        return false, "hit_controller_unresolved"
    end

    local damage = tonumber(profile.direct_fallback_damage)
        or tonumber(profile.minimum_damage)
        or tonumber(combat_config().direct_damage_fallback_minimum_damage)
        or 1.0
    if damage <= 0.0 then
        return false, "damage_not_positive"
    end

    local damage_info, info_reason = make_damage_info(hit_controller, damage, context)
    if not access.is_valid_obj(damage_info) then
        return false, info_reason
    end

    local ok, reason = apply_update_damage_hp(hit_controller, damage_info, damage)
    if not ok then
        return false, reason
    end

    mark_active_as_damaged(active_state, damage)
    log.info(string.format(
        "Job%02d direct_damage_fallback move=%s damage=%.1f target=%s distance=%s current_distance=%s closest_distance=%s method=%s at=%.2f",
        tonumber(move.job_id) or 0,
        tostring(move.key or "nil"),
        damage,
        tostring(access.describe_obj(character)),
        distance ~= nil and string.format("%.2f", distance) or "nil",
        current_distance ~= nil and string.format("%.2f", current_distance) or "nil",
        closest_distance ~= nil and string.format("%.2f", closest_distance) or "nil",
        tostring(reason),
        tonumber(now) or 0.0
    ))
    return true, reason
end

return direct_damage
