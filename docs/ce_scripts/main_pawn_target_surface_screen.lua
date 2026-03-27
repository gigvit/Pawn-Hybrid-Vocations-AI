-- Purpose:
-- Capture current main_pawn target-bearing surfaces during runtime.
-- Focus on roots that already appeared in logs, git history, and CE compare screens:
--   - ExecutingDecision.Target
--   - LockOnCtrl
--   - AIBlackBoardController
--   - AIMetaController and cached pawn controllers
--   - Human/Common selectors
--   - JobXXActionCtrl
--   - CurrentAction / SelectedRequest
--
-- Output:
--   reframework/data/ce_dump/main_pawn_target_surface_<timestamp>.json

local SHALLOW_FIELD_LIMIT = 16

local TARGET_FIELD_NAMES = {
    "<Target>k__BackingField",
    "_Target",
    "Target",
    "CurrentTarget",
    "AttackTarget",
    "LockOnTarget",
    "OrderTarget",
}

local TARGET_METHOD_NAMES = {
    "get_Target()",
    "get_CurrentTarget()",
    "get_AttackTarget()",
    "get_LockOnTarget()",
    "get_OrderTarget()",
}

local TARGET_CHARACTER_FIELD_NAMES = {
    "<Character>k__BackingField",
    "<OwnerCharacter>k__BackingField",
    "<TargetCharacter>k__BackingField",
    "<CachedCharacter>k__BackingField",
    "Character",
    "OwnerCharacter",
    "TargetCharacter",
    "CachedCharacter",
    "TargetChara",
    "Chara",
}

local TARGET_CHARACTER_METHOD_NAMES = {
    "get_Character()",
    "get_OwnerCharacter()",
    "get_TargetCharacter()",
    "get_Chara()",
}

local GAME_OBJECT_FIELD_NAMES = {
    "<GameObject>k__BackingField",
    "_GameObject",
    "GameObject",
    "<Obj>k__BackingField",
    "Obj",
    "<Owner>k__BackingField",
    "_Owner",
    "Owner",
}

local GAME_OBJECT_METHOD_NAMES = {
    "get_GameObject()",
    "get_Owner()",
}

local JOB_CONTROLLER_FIELD_TEMPLATE = "<Job%02dActionCtrl>k__BackingField"
local JOB_CONTROLLER_METHOD_TEMPLATE = "get_Job%02dActionCtrl()"

local CONTROLLER_FIELDS = {
    ai_blackboard_controller = {
        "<AIBlackBoardController>k__BackingField",
        "AIBlackBoardController",
        "<BlackBoardController>k__BackingField",
        "BlackBoardController",
    },
    ai_meta_controller = {
        "<AIMetaController>k__BackingField",
        "AIMetaController",
    },
    cached_pawn_battle_controller = {
        "<CachedPawnBattleController>k__BackingField",
        "CachedPawnBattleController",
    },
    cached_pawn_order_controller = {
        "<CachedPawnOrderController>k__BackingField",
        "CachedPawnOrderController",
    },
    cached_pawn_order_target_controller = {
        "<CachedPawnOrderTargetController>k__BackingField",
        "CachedPawnOrderTargetController",
    },
    cached_pawn_update_controller = {
        "<CachedPawnUpdateController>k__BackingField",
        "CachedPawnUpdateController",
    },
    human_action_selector = {
        "<HumanActionSelector>k__BackingField",
        "HumanActionSelector",
    },
    common_action_selector = {
        "<CommonActionSelector>k__BackingField",
        "CommonActionSelector",
    },
}

local AI_BLACKBOARD_SPECIAL_TARGET_FIELDS = {
    player_ai_target = {
        "<PlayerOfAITarget>k__BackingField",
        "PlayerOfAITarget",
    },
    self_ai_target = {
        "<SelfAITarget>k__BackingField",
        "SelfAITarget",
    },
}

local ORDER_TARGET_COLLECTION_FIELDS = {
    "_EnemyList",
    "_FrontTargetList",
    "_InCameraTargetList",
    "_SensorHitResult",
}

local function try_eval(fn)
    local ok, value = pcall(fn)
    return ok, value
end

local function safe_call_method0(obj, methods)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, method_name in ipairs(methods or {}) do
        local ok, value = try_eval(function()
            return obj:call(method_name)
        end)
        if ok then
            return value, method_name
        end
    end

    return nil, "unresolved"
end

local function safe_field(obj, fields)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, field_name in ipairs(fields or {}) do
        local ok, value = try_eval(function()
            return obj[field_name]
        end)
        if ok then
            return value, field_name
        end
    end

    return nil, "unresolved"
end

local function safe_call_method1(obj, methods, arg1)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, method_name in ipairs(methods or {}) do
        local ok, value = try_eval(function()
            return obj:call(method_name, arg1)
        end)
        if ok then
            return value, method_name
        end
    end

    return nil, "unresolved"
end

local function is_present(value)
    return value ~= nil and tostring(value) ~= "nil"
end

local function get_type_name(obj)
    if obj == nil then
        return "nil"
    end

    local ok, value = try_eval(function()
        return obj:get_type_definition():get_full_name()
    end)
    if ok and value ~= nil then
        return tostring(value)
    end

    return type(obj)
end

local function describe(obj)
    if obj == nil then
        return "nil"
    end

    local t = type(obj)
    if t == "userdata" then
        return tostring(obj)
    end
    if t == "table" then
        return "<table>"
    end

    return tostring(obj)
end

local function serialize_object(value, source)
    return {
        present = is_present(value),
        description = describe(value),
        type_name = get_type_name(value),
        source = source or "unresolved",
    }
end

local function serialize_scalar(value, source)
    return {
        present = value ~= nil,
        description = describe(value),
        type_name = type(value),
        source = source or "unresolved",
        value = value,
    }
end

local function snapshot_shallow_fields(obj, limit)
    local result = {}
    if obj == nil or type(obj) ~= "userdata" then
        return result
    end

    local ok_td, td = try_eval(function()
        return obj:get_type_definition()
    end)
    if not ok_td or td == nil then
        return result
    end

    local ok_fields, fields = try_eval(function()
        return td:get_fields()
    end)
    if not ok_fields or fields == nil then
        return result
    end

    local max_fields = limit or SHALLOW_FIELD_LIMIT
    for index, field in ipairs(fields) do
        if index > max_fields then
            break
        end

        local name = "field_" .. tostring(index)
        local ok_name, resolved_name = try_eval(function()
            return field:get_name()
        end)
        if ok_name and resolved_name ~= nil then
            name = tostring(resolved_name)
        end

        local ok_value, value = try_eval(function()
            return field:get_data(obj)
        end)

        result[#result + 1] = {
            index = index,
            name = name,
            value = ok_value and serialize_object(value, "field:" .. name) or {
                present = false,
                description = "<read_error>",
                type_name = "error",
                source = "field:" .. name,
            },
        }
    end

    return result
end

local function get_collection_count(obj)
    if obj == nil then
        return nil, "root_nil"
    end

    local count, count_source = safe_call_method0(obj, {
        "get_Count()",
        "get_count()",
        "get_Size()",
        "get_size()",
    })
    if count ~= nil then
        return tonumber(count), count_source
    end

    local field_count, field_count_source = safe_field(obj, {
        "Count",
        "count",
        "_size",
        "size",
    })
    if field_count ~= nil then
        return tonumber(field_count), field_count_source
    end

    return nil, "unresolved"
end

local function get_collection_item(obj, index)
    return safe_call_method1(obj, {
        "get_Item(System.Int32)",
        "get_Item(System.UInt32)",
        "get_Item",
    }, index)
end

local function append_unique(out, source_map, value, source)
    if not is_present(value) then
        return
    end

    local key = tostring(value)
    if source_map[key] ~= nil then
        return
    end

    source_map[key] = source or "unresolved"
    out[#out + 1] = value
end

local function resolve_main_pawn()
    local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
    local PawnManager = sdk.get_managed_singleton("app.PawnManager")
    local candidates = {
        { source = "PawnManager:get_MainPawn()", value = function() return PawnManager:call("get_MainPawn()") end },
        { source = "PawnManager._MainPawn", value = function() return PawnManager["_MainPawn"] end },
        { source = "PawnManager.<MainPawn>k__BackingField", value = function() return PawnManager["<MainPawn>k__BackingField"] end },
        { source = "CharacterManager:get_MainPawn()", value = function() return CharacterManager:call("get_MainPawn()") end },
        { source = "CharacterManager.<MainPawn>k__BackingField", value = function() return CharacterManager["<MainPawn>k__BackingField"] end },
        { source = "CharacterManager:get_ManualPlayerPawn()", value = function() return CharacterManager:call("get_ManualPlayerPawn()") end },
        { source = "CharacterManager:get_ManualPlayerMainPawn()", value = function() return CharacterManager:call("get_ManualPlayerMainPawn()") end },
    }

    for _, candidate in ipairs(candidates) do
        local ok, value = try_eval(candidate.value)
        if ok and is_present(value) then
            return value, candidate.source
        end
    end

    return nil, "unresolved"
end

local function resolve_runtime_character(main_pawn)
    if main_pawn == nil then
        return nil, "main_pawn_nil"
    end

    if get_type_name(main_pawn) == "app.Character" then
        return main_pawn, "main_pawn_is_character"
    end

    local value, source = safe_call_method0(main_pawn, {
        "get_CachedCharacter()",
        "get_Character()",
        "get_Chara()",
        "get_PawnCharacter()",
    })
    if is_present(value) then
        return value, source
    end

    local field_value, field_source = safe_field(main_pawn, {
        "<CachedCharacter>k__BackingField",
        "<Character>k__BackingField",
        "<Chara>k__BackingField",
        "Character",
        "Chara",
    })
    if is_present(field_value) then
        return field_value, field_source
    end

    return nil, "unresolved"
end

local function resolve_player()
    local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
    if CharacterManager == nil then
        return nil, "character_manager_nil"
    end

    local player, source = safe_field(CharacterManager, {
        "<ManualPlayer>k__BackingField",
        "_ManualPlayer",
    })
    if is_present(player) then
        return player, source
    end

    return safe_call_method0(CharacterManager, {
        "get_ManualPlayer()",
    })
end

local function resolve_current_job(human, runtime_character)
    local current_job, current_job_source = safe_field(human, {
        "<CurrentJob>k__BackingField",
        "CurrentJob",
    })
    if current_job ~= nil then
        return current_job, current_job_source
    end

    local job_context, job_context_source = safe_field(human, {
        "<JobContext>k__BackingField",
        "JobContext",
    })
    if is_present(job_context) then
        local context_job, context_job_source = safe_field(job_context, { "CurrentJob" })
        if context_job ~= nil then
            return context_job, "job_context:" .. tostring(context_job_source)
        end
        return nil, "job_context:" .. tostring(job_context_source)
    end

    return safe_call_method0(runtime_character, {
        "get_CurrentJob()",
        "get_Job()",
    })
end

local function resolve_position(obj)
    if obj == nil then
        return nil
    end

    local transform, _ = safe_call_method0(obj, { "get_Transform()" })
    if transform ~= nil then
        local position, _ = safe_call_method0(transform, {
            "get_Position()",
            "get_UniversalPosition()",
        })
        if position ~= nil then
            return position
        end
    end

    local direct_position, _ = safe_call_method0(obj, {
        "get_UniversalPosition()",
    })
    return direct_position
end

local function resolve_vector_component(vector, names)
    if vector == nil then
        return nil
    end

    local value, _ = safe_field(vector, names)
    return tonumber(value)
end

local function compute_distance(left, right)
    local left_position = resolve_position(left)
    local right_position = resolve_position(right)
    if left_position == nil or right_position == nil then
        return nil
    end

    local lx = resolve_vector_component(left_position, { "x", "X" })
    local ly = resolve_vector_component(left_position, { "y", "Y" })
    local lz = resolve_vector_component(left_position, { "z", "Z" })
    local rx = resolve_vector_component(right_position, { "x", "X" })
    local ry = resolve_vector_component(right_position, { "y", "Y" })
    local rz = resolve_vector_component(right_position, { "z", "Z" })
    if lx == nil or ly == nil or lz == nil or rx == nil or ry == nil or rz == nil then
        return nil
    end

    local dx = lx - rx
    local dy = ly - ry
    local dz = lz - rz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function resolve_component_character(source)
    local component_type = sdk.typeof("app.Character")
    if component_type == nil or source == nil then
        return nil, "component_type_unresolved"
    end

    local game_object = nil
    if get_type_name(source) == "via.GameObject" then
        game_object = source
    else
        game_object, _ = safe_field(source, GAME_OBJECT_FIELD_NAMES)
        if not is_present(game_object) then
            game_object, _ = safe_call_method0(source, GAME_OBJECT_METHOD_NAMES)
        end
    end

    if not is_present(game_object) then
        return nil, "game_object_unresolved"
    end

    local component, source_name = safe_call_method1(game_object, {
        "getComponent(System.Type)",
        "getComponent",
    }, component_type)
    return component, source_name
end

local function classify_identity(runtime_character, player, candidate)
    if not is_present(candidate) then
        return "none"
    end

    if runtime_character ~= nil and tostring(candidate) == tostring(runtime_character) then
        return "self"
    end
    if player ~= nil and tostring(candidate) == tostring(player) then
        return "player"
    end
    return "other"
end

local function collect_candidate_characters(target_like)
    local candidates = {}
    local sources = {}

    if get_type_name(target_like) == "app.Character" then
        append_unique(candidates, sources, target_like, "target_like:self")
    end

    for _, field_name in ipairs(TARGET_CHARACTER_FIELD_NAMES) do
        local value, source = safe_field(target_like, { field_name })
        append_unique(candidates, sources, value, "field:" .. tostring(source))
    end

    for _, method_name in ipairs(TARGET_CHARACTER_METHOD_NAMES) do
        local value, source = safe_call_method0(target_like, { method_name })
        append_unique(candidates, sources, value, "method:" .. tostring(source))
    end

    local component_character, component_source = resolve_component_character(target_like)
    append_unique(candidates, sources, component_character, "component:" .. tostring(component_source))

    return candidates, sources
end

local function choose_character_candidate(runtime_character, player, candidates)
    for _, candidate in ipairs(candidates or {}) do
        local identity = classify_identity(runtime_character, player, candidate)
        if identity == "other" then
            return candidate, identity
        end
    end

    local first = candidates and candidates[1] or nil
    return first, classify_identity(runtime_character, player, first)
end

local function resolve_target_like(root)
    if not is_present(root) then
        return nil, "root_nil"
    end

    local root_type_name = get_type_name(root)
    if root_type_name == "app.AITargetGameObject"
        or root_type_name == "app.Character"
        or root_type_name == "via.GameObject" then
        return root, "root_direct"
    end

    local field_value, field_source = safe_field(root, TARGET_FIELD_NAMES)
    if is_present(field_value) then
        return field_value, "field:" .. tostring(field_source)
    end

    local method_value, method_source = safe_call_method0(root, TARGET_METHOD_NAMES)
    if is_present(method_value) then
        return method_value, "method:" .. tostring(method_source)
    end

    return nil, "target_unresolved"
end

local function resolve_game_object(target_like, chosen_character)
    local value, source = safe_field(target_like, GAME_OBJECT_FIELD_NAMES)
    if is_present(value) then
        return value, "field:" .. tostring(source)
    end

    local method_value, method_source = safe_call_method0(target_like, GAME_OBJECT_METHOD_NAMES)
    if is_present(method_value) then
        return method_value, "method:" .. tostring(method_source)
    end

    if chosen_character ~= nil then
        local char_value, char_source = safe_field(chosen_character, GAME_OBJECT_FIELD_NAMES)
        if is_present(char_value) then
            return char_value, "character_field:" .. tostring(char_source)
        end

        local char_method_value, char_method_source = safe_call_method0(chosen_character, GAME_OBJECT_METHOD_NAMES)
        if is_present(char_method_value) then
            return char_method_value, "character_method:" .. tostring(char_method_source)
        end
    end

    return nil, "unresolved"
end

local function capture_game_object_paths(label, target_like, chosen_character)
    local direct_value = nil
    if get_type_name(target_like) == "via.GameObject" then
        direct_value = target_like
    end

    local target_field_value, target_field_source = safe_field(target_like, GAME_OBJECT_FIELD_NAMES)
    local target_method_value, target_method_source = safe_call_method0(target_like, GAME_OBJECT_METHOD_NAMES)

    local character_field_value = nil
    local character_field_source = "character_nil"
    local character_method_value = nil
    local character_method_source = "character_nil"
    if chosen_character ~= nil then
        character_field_value, character_field_source = safe_field(chosen_character, GAME_OBJECT_FIELD_NAMES)
        character_method_value, character_method_source = safe_call_method0(chosen_character, GAME_OBJECT_METHOD_NAMES)
    end

    local preferred_value, preferred_source = resolve_game_object(target_like, chosen_character)

    return {
        preferred = serialize_object(preferred_value, label .. ":preferred:" .. tostring(preferred_source)),
        direct = serialize_object(direct_value, label .. ":direct"),
        target_field = serialize_object(target_field_value, label .. ":target_field:" .. tostring(target_field_source)),
        target_method = serialize_object(target_method_value, label .. ":target_method:" .. tostring(target_method_source)),
        character_field = serialize_object(character_field_value, label .. ":character_field:" .. tostring(character_field_source)),
        character_method = serialize_object(character_method_value, label .. ":character_method:" .. tostring(character_method_source)),
    }
end

local function capture_collection_sample(label, root, field_name, runtime_character, player, max_items)
    local collection, collection_source = safe_field(root, { field_name })
    local count, count_source = get_collection_count(collection)
    local entries = {}
    local limit = math.min(tonumber(count) or 0, max_items or 4)

    for index = 0, limit - 1 do
        local item, item_source = get_collection_item(collection, index)
        local target_like, target_like_source = resolve_target_like(item)
        local probe_target = is_present(target_like) and target_like or item
        local probe_target_source = is_present(target_like) and target_like_source or "item_direct"
        local candidates, candidate_sources = collect_candidate_characters(probe_target)
        local chosen_character, identity = choose_character_candidate(runtime_character, player, candidates)
        local game_object, game_object_source = resolve_game_object(probe_target, chosen_character)
        local game_object_paths = capture_game_object_paths(
            label .. ":" .. field_name .. ":" .. tostring(index),
            probe_target,
            chosen_character
        )

        local candidate_entries = {}
        for _, candidate in ipairs(candidates) do
            candidate_entries[#candidate_entries + 1] = {
                object = serialize_object(candidate, candidate_sources[tostring(candidate)]),
                identity = classify_identity(runtime_character, player, candidate),
                distance = compute_distance(runtime_character, candidate),
            }
        end

        entries[#entries + 1] = {
            index = index,
            item = serialize_object(item, item_source),
            item_fields = snapshot_shallow_fields(item, SHALLOW_FIELD_LIMIT),
            target_like = serialize_object(target_like, target_like_source),
            probe_target = serialize_object(probe_target, probe_target_source),
            chosen_character = serialize_object(chosen_character, label .. ":" .. field_name .. ":chosen_character"),
            chosen_identity = identity,
            chosen_distance = serialize_scalar(compute_distance(runtime_character, chosen_character), label .. ":" .. field_name .. ":chosen_distance"),
            game_object = serialize_object(game_object, game_object_source),
            game_object_paths = game_object_paths,
            candidate_count = #candidate_entries,
            candidates = candidate_entries,
        }
    end

    return {
        label = label,
        field_name = field_name,
        collection = serialize_object(collection, collection_source),
        count = serialize_scalar(count, count_source),
        entries = entries,
    }
end

local function capture_target_root(label, root, runtime_character, player)
    local target_like, target_like_source = resolve_target_like(root)
    local candidates, candidate_sources = collect_candidate_characters(target_like)
    local chosen_character, identity = choose_character_candidate(runtime_character, player, candidates)
    local game_object, game_object_source = resolve_game_object(target_like, chosen_character)
    local game_object_paths = capture_game_object_paths(label, target_like, chosen_character)
    local distance = compute_distance(runtime_character, chosen_character)

    local candidate_entries = {}
    for _, candidate in ipairs(candidates) do
        candidate_entries[#candidate_entries + 1] = {
            object = serialize_object(candidate, candidate_sources[tostring(candidate)]),
            identity = classify_identity(runtime_character, player, candidate),
            distance = distance ~= nil and tostring(candidate) == tostring(chosen_character) and distance or compute_distance(runtime_character, candidate),
        }
    end

    return {
        label = label,
        root = serialize_object(root, label .. ":root"),
        root_fields = snapshot_shallow_fields(root, SHALLOW_FIELD_LIMIT),
        target_like = serialize_object(target_like, target_like_source),
        target_like_fields = snapshot_shallow_fields(target_like, SHALLOW_FIELD_LIMIT),
        chosen_character = serialize_object(chosen_character, label .. ":chosen_character"),
        chosen_identity = identity,
        chosen_distance = serialize_scalar(distance, label .. ":chosen_distance"),
        game_object = serialize_object(game_object, game_object_source),
        game_object_paths = game_object_paths,
        candidate_count = #candidate_entries,
        candidates = candidate_entries,
    }
end

local function get_job_action_ctrl(human, current_job)
    local numeric_job = tonumber(current_job)
    if human == nil or numeric_job == nil then
        return nil, "unresolved"
    end

    local field_name = string.format(JOB_CONTROLLER_FIELD_TEMPLATE, numeric_job)
    local value, source = safe_field(human, { field_name })
    if is_present(value) then
        return value, "field:" .. tostring(source)
    end

    local method_name = string.format(JOB_CONTROLLER_METHOD_TEMPLATE, numeric_job)
    local method_value, method_source = safe_call_method0(human, { method_name })
    if is_present(method_value) then
        return method_value, "method:" .. tostring(method_source)
    end

    return nil, "unresolved"
end

local function capture()
    local main_pawn, main_pawn_source = resolve_main_pawn()
    local runtime_character, runtime_character_source = resolve_runtime_character(main_pawn)
    local player, player_source = resolve_player()
    local human, human_source = safe_call_method0(runtime_character, { "get_Human()" })
    local action_manager, action_manager_source = safe_call_method0(runtime_character, { "get_ActionManager()" })
    local current_job, current_job_source = resolve_current_job(human, runtime_character)
    local ai_blackboard, ai_blackboard_source = safe_call_method0(runtime_character, {
        "get_AIBlackBoardController()",
    })
    local lock_on_ctrl, lock_on_ctrl_source = safe_call_method0(runtime_character, {
        "get_LockOnCtrl()",
    })

    local decision_maker, decision_maker_source = safe_field(runtime_character, {
        "<AIDecisionMaker>k__BackingField",
        "AIDecisionMaker",
    })
    if not is_present(decision_maker) then
        decision_maker, decision_maker_source = safe_call_method0(runtime_character, {
            "get_AIDecisionMaker()",
        })
    end

    local decision_module, decision_module_source = safe_field(decision_maker, {
        "<DecisionModule>k__BackingField",
        "DecisionModule",
    })
    if not is_present(decision_module) then
        decision_module, decision_module_source = safe_call_method0(decision_maker, {
            "get_DecisionModule()",
        })
    end

    local decision_executor, decision_executor_source = safe_field(decision_module, {
        "<DecisionExecutor>k__BackingField",
        "DecisionExecutor",
    })
    if not is_present(decision_executor) then
        decision_executor, decision_executor_source = safe_call_method0(decision_module, {
            "get_DecisionExecutor()",
        })
    end

    local executing_decision, executing_decision_source = safe_field(decision_executor, {
        "<ExecutingDecision>k__BackingField",
        "ExecutingDecision",
    })
    if not is_present(executing_decision) then
        executing_decision, executing_decision_source = safe_call_method0(decision_executor, {
            "get_ExecutingDecision()",
        })
    end

    local ai_meta_controller, ai_meta_controller_source = safe_field(ai_blackboard, CONTROLLER_FIELDS.ai_meta_controller)
    local cached_pawn_battle_controller, cached_pawn_battle_controller_source = safe_field(ai_meta_controller, CONTROLLER_FIELDS.cached_pawn_battle_controller)
    local cached_pawn_order_controller, cached_pawn_order_controller_source = safe_field(ai_meta_controller, CONTROLLER_FIELDS.cached_pawn_order_controller)
    local cached_pawn_order_target_controller, cached_pawn_order_target_controller_source = safe_field(ai_meta_controller, CONTROLLER_FIELDS.cached_pawn_order_target_controller)
    local cached_pawn_update_controller, cached_pawn_update_controller_source = safe_field(ai_meta_controller, CONTROLLER_FIELDS.cached_pawn_update_controller)
    local human_action_selector, human_action_selector_source = safe_field(human, CONTROLLER_FIELDS.human_action_selector)
    local common_action_selector, common_action_selector_source = safe_field(human, CONTROLLER_FIELDS.common_action_selector)
    local job_action_ctrl, job_action_ctrl_source = get_job_action_ctrl(human, current_job)
    local selected_request, selected_request_source = safe_field(action_manager, { "SelectedRequest" })
    local current_action, current_action_source = safe_field(action_manager, { "CurrentAction" })
    local ai_blackboard_player_target, ai_blackboard_player_target_source = safe_field(ai_blackboard, AI_BLACKBOARD_SPECIAL_TARGET_FIELDS.player_ai_target)
    local ai_blackboard_self_target, ai_blackboard_self_target_source = safe_field(ai_blackboard, AI_BLACKBOARD_SPECIAL_TARGET_FIELDS.self_ai_target)

    local roots = {
        capture_target_root("executing_decision", executing_decision, runtime_character, player),
        capture_target_root("lock_on_ctrl", lock_on_ctrl, runtime_character, player),
        capture_target_root("ai_blackboard_controller", ai_blackboard, runtime_character, player),
        capture_target_root("ai_blackboard_player_target", ai_blackboard_player_target, runtime_character, player),
        capture_target_root("ai_blackboard_self_target", ai_blackboard_self_target, runtime_character, player),
        capture_target_root("ai_meta_controller", ai_meta_controller, runtime_character, player),
        capture_target_root("cached_pawn_battle_controller", cached_pawn_battle_controller, runtime_character, player),
        capture_target_root("cached_pawn_order_controller", cached_pawn_order_controller, runtime_character, player),
        capture_target_root("cached_pawn_order_target_controller", cached_pawn_order_target_controller, runtime_character, player),
        capture_target_root("cached_pawn_update_controller", cached_pawn_update_controller, runtime_character, player),
        capture_target_root("human_action_selector", human_action_selector, runtime_character, player),
        capture_target_root("common_action_selector", common_action_selector, runtime_character, player),
        capture_target_root("job_action_ctrl", job_action_ctrl, runtime_character, player),
        capture_target_root("selected_request", selected_request, runtime_character, player),
        capture_target_root("current_action", current_action, runtime_character, player),
    }

    local order_target_collection_samples = {
        capture_collection_sample("cached_pawn_order_target_controller", cached_pawn_order_target_controller, "_EnemyList", runtime_character, player, 5),
        capture_collection_sample("cached_pawn_order_target_controller", cached_pawn_order_target_controller, "_FrontTargetList", runtime_character, player, 5),
        capture_collection_sample("cached_pawn_order_target_controller", cached_pawn_order_target_controller, "_InCameraTargetList", runtime_character, player, 5),
        capture_collection_sample("cached_pawn_order_target_controller", cached_pawn_order_target_controller, "_SensorHitResult", runtime_character, player, 5),
    }

    return {
        tag = "main_pawn_target_surface",
        generated_at = os.date("%Y-%m-%d %H:%M:%S"),
        actor = {
            main_pawn = serialize_object(main_pawn, main_pawn_source),
            runtime_character = serialize_object(runtime_character, runtime_character_source),
            player = serialize_object(player, player_source),
            human = serialize_object(human, human_source),
            action_manager = serialize_object(action_manager, action_manager_source),
            current_job = serialize_scalar(current_job, current_job_source),
        },
        decision_chain = {
            decision_maker = serialize_object(decision_maker, decision_maker_source),
            decision_module = serialize_object(decision_module, decision_module_source),
            decision_executor = serialize_object(decision_executor, decision_executor_source),
            executing_decision = serialize_object(executing_decision, executing_decision_source),
        },
        roots = {
            ai_blackboard = serialize_object(ai_blackboard, ai_blackboard_source),
            ai_meta_controller = serialize_object(ai_meta_controller, ai_meta_controller_source),
            cached_pawn_battle_controller = serialize_object(cached_pawn_battle_controller, cached_pawn_battle_controller_source),
            cached_pawn_order_controller = serialize_object(cached_pawn_order_controller, cached_pawn_order_controller_source),
            cached_pawn_order_target_controller = serialize_object(cached_pawn_order_target_controller, cached_pawn_order_target_controller_source),
            cached_pawn_update_controller = serialize_object(cached_pawn_update_controller, cached_pawn_update_controller_source),
            human_action_selector = serialize_object(human_action_selector, human_action_selector_source),
            common_action_selector = serialize_object(common_action_selector, common_action_selector_source),
            job_action_ctrl = serialize_object(job_action_ctrl, job_action_ctrl_source),
            lock_on_ctrl = serialize_object(lock_on_ctrl, lock_on_ctrl_source),
            ai_blackboard_player_target = serialize_object(ai_blackboard_player_target, ai_blackboard_player_target_source),
            ai_blackboard_self_target = serialize_object(ai_blackboard_self_target, ai_blackboard_self_target_source),
            selected_request = serialize_object(selected_request, selected_request_source),
            current_action = serialize_object(current_action, current_action_source),
        },
        target_roots = roots,
        order_target_collection_samples = order_target_collection_samples,
    }
end

local output = capture()
local output_path = string.format(
    "ce_dump/main_pawn_target_surface_%s.json",
    os.date("%Y%m%d_%H%M%S")
)
json.dump_file(output_path, output)
print("[main_pawn_target_surface] wrote " .. output_path)
return output_path
