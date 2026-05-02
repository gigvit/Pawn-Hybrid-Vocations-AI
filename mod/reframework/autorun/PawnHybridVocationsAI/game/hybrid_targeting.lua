local config = require("PawnHybridVocationsAI/config")
local access = require("PawnHybridVocationsAI/core/access")

local hybrid_targeting = {}

local TARGET_FIELDS = {
    "<Target>k__BackingField",
    "_Target",
    "Target",
    "CurrentTarget",
    "AttackTarget",
    "LockOnTarget",
    "OrderTarget",
}

local TARGET_METHODS = {
    "get_Target",
    "get_CurrentTarget",
    "get_AttackTarget",
    "get_LockOnTarget",
    "get_OrderTarget",
}

local ORDER_TARGET_COLLECTION_FIELDS = {
    "_EnemyList",
    "_FrontTargetList",
    "_InCameraTargetList",
    "_SensorHitResult",
}

local ORDER_TARGET_CONTROLLER_FIELDS = {
    "<OrderTargetController>k__BackingField",
    "_OrderTargetController",
    "OrderTargetController",
}

local BATTLE_CONTROLLER_FIELDS = {
    "<BattleController>k__BackingField",
    "_BattleController",
    "BattleController",
}

local ORDER_CONTROLLER_FIELDS = {
    "<OrderController>k__BackingField",
    "_OrderController",
    "OrderController",
}

local AIMETA_CONTROLLER_FIELDS = {
    "<AIMetaController>k__BackingField",
    "AIMetaController",
}

local CACHED_PAWN_ORDER_TARGET_CONTROLLER_FIELDS = {
    "<CachedPawnOrderTargetController>k__BackingField",
    "CachedPawnOrderTargetController",
}

local function combat_config()
    return config.combat or {}
end

local function is_character(obj)
    return access.is_valid_obj(obj) and access.is_a(obj, "app.Character")
end

local function is_invalid_target_identity(context, runtime, character)
    return not access.is_valid_obj(character)
        or access.same_object(character, context and context.runtime_character)
        or access.same_object(character, runtime and runtime.player)
end

local function resolve_position(obj)
    if not access.is_valid_obj(obj) then
        return nil
    end

    local transform = access.call_first(obj, "get_Transform")
    if access.is_valid_obj(transform) then
        local position = access.safe_method(transform, "get_Position")
            or access.safe_method(transform, "get_UniversalPosition")
        if position ~= nil then
            return position
        end
    end

    return access.safe_method(obj, "get_UniversalPosition")
end

function hybrid_targeting.compute_distance(left, right)
    local left_position = resolve_position(left)
    local right_position = resolve_position(right)
    if left_position == nil or right_position == nil then
        return nil
    end

    local ok, distance = pcall(function()
        return (left_position - right_position):length()
    end)
    return ok and tonumber(distance) or nil
end

local function build_target_info(character, source_root, source_label)
    local game_object = access.resolve_game_object(source_root, true)
        or access.resolve_game_object(character, true)
    local transform = access.call_first(source_root, "get_Transform")
        or access.call_first(character, "get_Transform")
    local context_holder = access.field_first(source_root, {
        "<ContextHolder>k__BackingField",
        "ContextHolder",
    }) or access.call_first(source_root, "get_ContextHolder")

    return {
        character = character,
        character_signature = access.describe_obj(character),
        game_object = game_object,
        transform = transform,
        context_holder = context_holder,
        source_label = tostring(source_label or "target"),
    }
end

local function clear_cached_target(data, reason)
    if type(data) ~= "table" then
        return
    end

    data.cached_target_info = nil
    data.cached_target_reason = tostring(reason or "cached_target_unresolved")
    data.cached_target_time = nil
end

local function extract_character_candidate(candidate, context, runtime)
    if not access.is_valid_obj(candidate) then
        return nil, nil
    end

    if is_character(candidate) and not is_invalid_target_identity(context, runtime, candidate) then
        return candidate, candidate
    end

    local game_object = access.resolve_game_object(candidate, true)
    local component_character = access.safe_get_component(game_object, "app.Character", false)
    if is_character(component_character) and not is_invalid_target_identity(context, runtime, component_character) then
        return component_character, game_object
    end

    return nil, candidate
end

local function extract_character_from_target_like(target_like, context, runtime)
    if not access.is_valid_obj(target_like) then
        return nil, nil
    end

    local candidates = { target_like }
    for _, field_name in ipairs(TARGET_FIELDS) do
        candidates[#candidates + 1] = access.field_first(target_like, field_name)
    end
    for _, method_name in ipairs(TARGET_METHODS) do
        candidates[#candidates + 1] = access.call_first(target_like, method_name)
    end

    local obj = access.field_first(target_like, {
        "<Obj>k__BackingField",
        "Obj",
        "<GameObject>k__BackingField",
        "GameObject",
    }) or access.call_first(target_like, "get_Obj")
    candidates[#candidates + 1] = obj

    local owner = access.field_first(target_like, {
        "<Owner>k__BackingField",
        "Owner",
        "<OwnerObject>k__BackingField",
        "OwnerObject",
    }) or access.call_first(target_like, {
        "get_Owner",
        "get_OwnerObject",
    })
    candidates[#candidates + 1] = owner

    for _, candidate in ipairs(candidates) do
        local character, source_root = extract_character_candidate(candidate, context, runtime)
        if access.is_valid_obj(character) then
            return character, source_root or candidate
        end
    end

    return nil, target_like
end

local function resolve_order_target_controller(root, label, context, runtime)
    if not access.is_valid_obj(root) then
        return nil, tostring(label or "order_target_controller") .. "_unresolved"
    end

    for _, field_name in ipairs(ORDER_TARGET_COLLECTION_FIELDS) do
        local collection = access.field_first(root, field_name)
        local count = access.read_collection_count(collection) or 0
        local max_items = math.min(count, 6)
        for index = 0, max_items - 1 do
            local item = access.read_collection_item(collection, index)
            local character, source_root = extract_character_from_target_like(item, context, runtime)
            if access.is_valid_obj(character) then
                return build_target_info(
                    character,
                    source_root or item,
                    string.format("%s:%s#%d", tostring(label or "order_target_controller"), tostring(field_name), index)
                ), string.format("%s:%s", tostring(label or "order_target_controller"), tostring(field_name))
            end
        end
    end

    return nil, tostring(label or "order_target_controller") .. "_collections_empty"
end

local function resolve_surface_target(root, label, context, runtime)
    if not access.is_valid_obj(root) then
        return nil, tostring(label or "surface") .. "_unresolved"
    end

    local root_type = access.get_type_full_name(root)
    if root_type == "app.PawnOrderTargetController" then
        return resolve_order_target_controller(root, label, context, runtime)
    end

    local direct_order_target = access.present_field(root, ORDER_TARGET_CONTROLLER_FIELDS)
    if access.is_valid_obj(direct_order_target) then
        local info, reason = resolve_order_target_controller(
            direct_order_target,
            tostring(label or "surface") .. ":order_target_controller",
            context,
            runtime
        )
        if info ~= nil then
            return info, reason
        end
    end

    local ai_meta_controller = access.present_field(root, AIMETA_CONTROLLER_FIELDS)
    if access.is_valid_obj(ai_meta_controller) then
        local cached_pawn_order_target = access.present_field(ai_meta_controller, CACHED_PAWN_ORDER_TARGET_CONTROLLER_FIELDS)
        if access.is_valid_obj(cached_pawn_order_target) then
            local info, reason = resolve_order_target_controller(
                cached_pawn_order_target,
                tostring(label or "surface") .. ":cached_pawn_order_target_controller",
                context,
                runtime
            )
            if info ~= nil then
                return info, reason
            end
        end
    end

    local target_like = access.present_field(root, TARGET_FIELDS)
        or access.present_method(root, TARGET_METHODS)
        or root
    local character, source_root = extract_character_from_target_like(target_like, context, runtime)
    if access.is_valid_obj(character) then
        return build_target_info(character, source_root or target_like, label), tostring(label or "surface")
    end

    return nil, tostring(label or "surface") .. "_character_unresolved"
end

local function cache_target_info(data, target_info, reason, now)
    data.cached_target_info = {
        character = target_info.character,
        character_signature = target_info.character_signature,
        game_object = target_info.game_object,
        transform = target_info.transform,
        context_holder = target_info.context_holder,
        source_label = target_info.source_label,
    }
    data.cached_target_reason = tostring(reason or "cached_target")
    data.cached_target_time = tonumber(now) or 0.0
end

local function get_cached_target_info(data, context, runtime, now, ttl_seconds_override)
    if type(data.cached_target_info) ~= "table" then
        return nil, "cached_target_unresolved"
    end

    local ttl_seconds = tonumber(ttl_seconds_override)
        or tonumber(combat_config().target_cache_ttl_seconds)
        or 0.85
    local cached_time = tonumber(data.cached_target_time)
    if cached_time == nil or tonumber(now) == nil or (now - cached_time) > ttl_seconds then
        clear_cached_target(data, "cached_target_expired")
        return nil, "cached_target_expired"
    end

    local character = data.cached_target_info.character
    if is_invalid_target_identity(context, runtime, character) then
        clear_cached_target(data, "cached_target_invalid")
        return nil, "cached_target_invalid"
    end

    return data.cached_target_info, tostring(data.cached_target_reason or "cached_target")
end

local function build_root_candidates(context)
    local roots = {
        {
            label = "executing_decision",
            root = context and context.executing_decision,
        },
    }

    if combat_config().use_lock_on_target == true then
        roots[#roots + 1] = {
            label = "lock_on_ctrl",
            root = context and context.lock_on_ctrl,
        }
    end

    if combat_config().use_order_target_controller == true then
        roots[#roots + 1] = {
            label = "cached_pawn_order_target_controller",
            root = context and context.cached_pawn_order_target_controller,
        }
        roots[#roots + 1] = {
            label = "pawn_manager_order_target_controller",
            root = context and context.pawn_manager_order_target_controller,
        }
        roots[#roots + 1] = {
            label = "human_action_selector_order_target_controller",
            root = context and context.human_order_target_controller,
        }
        roots[#roots + 1] = {
            label = "common_action_selector_order_target_controller",
            root = context and context.common_order_target_controller,
        }
        roots[#roots + 1] = {
            label = "ai_blackboard_order_target_controller",
            root = context and context.ai_blackboard_order_target_controller,
        }
        roots[#roots + 1] = {
            label = "ai_blackboard_battle_controller",
            root = context and context.ai_blackboard_battle_controller,
        }
        roots[#roots + 1] = {
            label = "ai_blackboard_order_controller",
            root = context and context.ai_blackboard_order_controller,
        }
        roots[#roots + 1] = {
            label = "ai_blackboard",
            root = context and context.ai_blackboard,
        }
    end

    return roots
end

function hybrid_targeting.describe_probes(probes)
    if type(probes) ~= "table" or #probes == 0 then
        return "none"
    end

    return table.concat(probes, " ; ")
end

function hybrid_targeting.resolve(context, runtime, data, now)
    data = type(data) == "table" and data or {}
    local probes = {}
    local roots = build_root_candidates(context)

    if type(data.active) == "table" and combat_config().lock_target_while_active ~= false then
        local active_ttl_seconds = tonumber(combat_config().active_target_cache_ttl_seconds)
            or math.max((tonumber(combat_config().target_cache_ttl_seconds) or 0.85) * 3.0, 2.50)
        local cached_target_info, cached_reason = get_cached_target_info(
            data,
            context,
            runtime,
            now,
            active_ttl_seconds
        )
        if cached_target_info ~= nil then
            cached_target_info.distance = hybrid_targeting.compute_distance(
                context.runtime_character,
                cached_target_info.character
            )
            probes[#probes + 1] = string.format(
                "active_cached_target=%s:%s",
                tostring(cached_reason or "cached_target"),
                tostring(cached_target_info.character_signature or access.describe_obj(cached_target_info.character))
            )
            return cached_target_info, "active_cached_target", probes
        end
        probes[#probes + 1] = string.format(
            "active_cached_target=%s",
            tostring(cached_reason or "cached_target_unresolved")
        )
    end

    for _, item in ipairs(roots) do
        local target_info, reason = resolve_surface_target(item.root, item.label, context, runtime)
        probes[#probes + 1] = string.format(
            "%s=%s:%s",
            tostring(item.label or "surface"),
            tostring(reason or "unresolved"),
            tostring(target_info and target_info.character_signature or access.describe_obj(target_info and target_info.character))
        )
        if target_info ~= nil and access.is_valid_obj(target_info.character) then
            target_info.distance = hybrid_targeting.compute_distance(context.runtime_character, target_info.character)
            cache_target_info(data, target_info, reason, now)
            return target_info, reason, probes
        end
    end

    local cached_target_info, cached_reason = get_cached_target_info(data, context, runtime, now)
    if cached_target_info ~= nil then
        cached_target_info.distance = hybrid_targeting.compute_distance(context.runtime_character, cached_target_info.character)
        probes[#probes + 1] = string.format(
            "cached_target=%s:%s",
            tostring(cached_reason or "cached_target"),
            tostring(cached_target_info.character_signature or access.describe_obj(cached_target_info.character))
        )
        return cached_target_info, "cached_target", probes
    end

    probes[#probes + 1] = string.format("cached_target=%s", tostring(cached_reason or "cached_target_unresolved"))
    return nil, "target_unresolved", probes
end

return hybrid_targeting
