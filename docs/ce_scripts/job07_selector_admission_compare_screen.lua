-- Purpose:
-- Compare selector/admission/context surfaces for:
--   1. main_pawn Job07
--   2. Sigurd Job07
-- Output:
--   reframework/data/ce_dump/job07_selector_admission_compare_<timestamp>.json

local SIGURD_CHARA_ID = 1108605478
local SHALLOW_FIELD_LIMIT = 20
local RECURSIVE_DEPTH = 3
local RECURSIVE_FIELD_LIMIT = 24

local JOB_CONTROLLER_MAP = {
    [7] = {
        getter = "get_Job07ActionCtrl()",
        field = "<Job07ActionCtrl>k__BackingField",
    },
}

local JOB_CONTEXT_FIELD_NAMES = {
    "<CurrentJob>k__BackingField",
    "CurrentJob",
    "PrevJob",
    "QualifiedJobBits",
    "ViewedNewJobBits",
    "ChangedJobBits",
}

local HUMAN_ACTION_SELECTOR_FIELD_NAMES = {
    "<Target>k__BackingField",
    "_Target",
    "Target",
    "CurrentTarget",
    "AttackTarget",
    "SelectedRequest",
    "CurrentAction",
    "ActionManager",
    "DecisionModule",
    "BattleController",
    "OrderController",
    "OrderTargetController",
}

local AI_BLACKBOARD_FIELD_NAMES = {
    "<Target>k__BackingField",
    "_Target",
    "Target",
    "CurrentTarget",
    "AttackTarget",
    "LockOnTarget",
    "OrderTarget",
    "BattleController",
    "OrderController",
    "OrderTargetController",
    "UpdateController",
    "ActionManager",
}

local JOB07_CTRL_FIELD_NAMES = {
    "<Target>k__BackingField",
    "_Target",
    "Target",
    "CurrentTarget",
    "SelectedRequest",
    "CurrentAction",
    "ActionManager",
    "AIBlackBoardController",
    "BlackBoardController",
    "HumanActionSelector",
    "JobContext",
}

local ACTION_MANAGER_FIELD_NAMES = {
    "CurrentAction",
    "PrevAction",
    "SelectedRequest",
    "RequestInfoList",
    "CurrentActionList",
    "PrevActionList",
    "IsRequestedList",
    "IsActionChangedList",
    "DefaultLayerNum",
}

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

local DECISION_POOL_FIELD_NAMES = {
    "_CurrentGoalList",
    "CurrentGoalList",
    "_CurrentAddDecisionList",
    "CurrentAddDecisionList",
    "MainDecisions",
    "PreDecisions",
    "PostDecisions",
    "ActiveDecisionPacks",
    "_BattleAIData",
    "BattleAIData",
    "OrderData",
    "AIGoalActionData",
}

local CONTROLLER_FIELD_MAP = {
    battle_controller = {
        "<BattleController>k__BackingField",
        "_BattleController",
        "BattleController",
    },
    order_controller = {
        "<OrderController>k__BackingField",
        "_OrderController",
        "OrderController",
    },
    order_target_controller = {
        "<OrderTargetController>k__BackingField",
        "_OrderTargetController",
        "OrderTargetController",
    },
    update_controller = {
        "<UpdateController>k__BackingField",
        "_UpdateController",
        "UpdateController",
    },
}

local function try_eval(fn)
    local ok, value = pcall(fn)
    return ok, value
end

local function safe_call_method0(obj, methods)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, method_name in ipairs(methods) do
        local ok, value = try_eval(function()
            return obj:call(method_name)
        end)
        if ok then
            return value, method_name
        end
    end

    return nil, "unresolved"
end

local function safe_call_method1(obj, methods, arg1)
    if obj == nil then
        return nil, "root_nil"
    end

    for _, method_name in ipairs(methods) do
        local ok, value = try_eval(function()
            return obj:call(method_name, arg1)
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

    for _, field_name in ipairs(fields) do
        local ok, value = try_eval(function()
            return obj[field_name]
        end)
        if ok then
            return value, field_name
        end
    end

    return nil, "unresolved"
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

    local value_type = type(obj)
    if value_type == "userdata" then
        return tostring(obj)
    end
    if value_type == "table" then
        return "<table>"
    end

    return tostring(obj)
end

local function is_present(obj)
    return obj ~= nil and tostring(obj) ~= "nil"
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

    local field_count, field_count_source = safe_field(obj, { "Count", "count", "_size", "size" })
    if field_count ~= nil then
        return tonumber(field_count), field_count_source
    end

    return nil, "unresolved"
end

local function serialize_collection(value, source)
    local count, count_source = get_collection_count(value)
    return {
        present = is_present(value),
        description = describe(value),
        type_name = get_type_name(value),
        source = source or "unresolved",
        count = count,
        count_source = count_source,
    }
end

local function get_collection_item(obj, index)
    return safe_call_method1(obj, {
        "get_Item(System.Int32)",
        "get_Item(System.UInt32)",
        "get_Item",
    }, index)
end

local function get_game_object_name(game_object)
    if not is_present(game_object) then
        return nil
    end

    local name, _ = safe_call_method0(game_object, { "get_Name()" })
    return name
end

local function get_current_node_name(action_manager, layer_index)
    local fsm, fsm_source = safe_field(action_manager, { "Fsm" })
    if not is_present(fsm) then
        return nil, "fsm:" .. tostring(fsm_source)
    end

    local node_name, node_name_source = safe_call_method1(fsm, {
        "getCurrentNodeName(System.UInt32)",
        "getCurrentNodeName",
    }, layer_index)
    if type(node_name) == "string" then
        return node_name, "fsm:" .. tostring(node_name_source)
    end

    local node_to_string, node_to_string_source = safe_call_method0(node_name, { "ToString()" })
    if type(node_to_string) == "string" then
        return node_to_string, "fsm:" .. tostring(node_to_string_source)
    end

    return node_name, "fsm:" .. tostring(node_name_source)
end

local function snapshot_named_fields(obj, field_names)
    local result = {}

    for _, field_name in ipairs(field_names) do
        local value, source = safe_field(obj, { field_name })
        result[field_name] = serialize_object(value, source)
    end

    return result
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

        local field_name = "field_" .. tostring(index)
        local ok_name, resolved_name = try_eval(function()
            return field:get_name()
        end)
        if ok_name and resolved_name ~= nil then
            field_name = tostring(resolved_name)
        end

        local ok_value, value = try_eval(function()
            return field:get_data(obj)
        end)

        result[#result + 1] = {
            index = index,
            name = field_name,
            value = ok_value and serialize_object(value, "field:" .. field_name) or {
                present = false,
                description = "<read_error>",
                type_name = "error",
                source = "field:" .. field_name,
            },
        }
    end

    return result
end

local function extract_character_target(target)
    local character, character_source = safe_field(target, {
        "<Character>k__BackingField",
        "<OwnerCharacter>k__BackingField",
        "Character",
        "OwnerCharacter",
    })
    if is_present(character) then
        return character, "target:" .. tostring(character_source)
    end

    local getter_character, getter_character_source = safe_call_method0(target, {
        "get_Character()",
        "get_OwnerCharacter()",
    })
    if is_present(getter_character) then
        return getter_character, "target:" .. tostring(getter_character_source)
    end

    return target, "target"
end

local function resolve_surface_target(root)
    local target, target_source = safe_field(root, TARGET_FIELD_NAMES)
    if not is_present(target) then
        target, target_source = safe_call_method0(root, TARGET_METHOD_NAMES)
    end

    if not is_present(target) then
        return nil, target_source
    end

    return extract_character_target(target)
end

local function resolve_controller(actor, field_names, human_action_selector, ai_blackboard, job07_action_ctrl)
    local surfaces = {
        { label = "job07_action_ctrl", value = job07_action_ctrl },
        { label = "ai_blackboard", value = ai_blackboard },
        { label = "human_action_selector", value = human_action_selector },
        { label = "human", value = actor.human },
        { label = "runtime_character", value = actor.runtime_character },
    }

    for _, surface in ipairs(surfaces) do
        local value, source = safe_field(surface.value, field_names)
        if is_present(value) then
            return value, surface.label .. ":" .. tostring(source)
        end
    end

    return nil, "unresolved"
end

local function build_decision_pool_snapshot(root)
    local result = {}

    for _, field_name in ipairs(DECISION_POOL_FIELD_NAMES) do
        local value, source = safe_field(root, { field_name })
        result[field_name] = serialize_collection(value, source)
    end

    return result
end

local function recursive_scan(root, wanted, depth, field_limit, out, seen, label)
    if root == nil or type(root) ~= "userdata" then
        return
    end

    local key = tostring(root)
    if seen[key] then
        return
    end
    seen[key] = true

    local type_name = get_type_name(root)
    local wanted_key = wanted[type_name]
    if wanted_key ~= nil and out[wanted_key] == nil then
        out[wanted_key] = {
            description = describe(root),
            type_name = type_name,
            source = label,
        }
    end

    if depth <= 0 then
        return
    end

    local ok_td, td = try_eval(function()
        return root:get_type_definition()
    end)
    if not ok_td or td == nil then
        return
    end

    local ok_fields, fields = try_eval(function()
        return td:get_fields()
    end)
    if not ok_fields or fields == nil then
        return
    end

    local max_fields = field_limit or RECURSIVE_FIELD_LIMIT
    for index, field in ipairs(fields) do
        if index > max_fields then
            break
        end

        local field_name = "field_" .. tostring(index)
        local ok_name, resolved_name = try_eval(function()
            return field:get_name()
        end)
        if ok_name and resolved_name ~= nil then
            field_name = tostring(resolved_name)
        end

        local ok_value, value = try_eval(function()
            return field:get_data(root)
        end)
        if ok_value and type(value) == "userdata" then
            recursive_scan(value, wanted, depth - 1, field_limit, out, seen, label .. "." .. field_name)
        end
    end
end

local function resolve_main_pawn(PawnManager, CharacterManager)
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

local function resolve_runtime_character_from_pawn(main_pawn)
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
        return value, "main_pawn:" .. source
    end

    local field_value, field_source = safe_field(main_pawn, {
        "<CachedCharacter>k__BackingField",
        "<Character>k__BackingField",
        "<Chara>k__BackingField",
        "Character",
        "Chara",
    })
    if is_present(field_value) then
        return field_value, "main_pawn:" .. field_source
    end

    return nil, "unresolved"
end

local function resolve_sigurd_runtime_character()
    local holder = sdk.get_managed_singleton("app.CharacterListHolder")
    local all_characters, all_characters_source = safe_call_method0(holder, { "getAllCharacters()" })
    local count = get_collection_count(all_characters)
    if count == nil then
        return nil, "character_list_unresolved"
    end

    for index = 0, count - 1 do
        local character, item_source = get_collection_item(all_characters, index)
        local chara_id, chara_id_source = safe_call_method0(character, { "get_CharaID()" })
        if tonumber(chara_id) == SIGURD_CHARA_ID then
            return character, string.format(
                "CharacterListHolder:%s:%s:%s",
                tostring(all_characters_source),
                tostring(item_source),
                tostring(chara_id_source)
            )
        end
    end

    return nil, "sigurd_not_loaded"
end

local function resolve_actor(actor_mode)
    local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
    local PawnManager = sdk.get_managed_singleton("app.PawnManager")

    if actor_mode == "sigurd" then
        local runtime_character, runtime_character_source = resolve_sigurd_runtime_character()
        local human, human_source = safe_call_method0(runtime_character, { "get_Human()" })
        local game_object, game_object_source = safe_call_method0(runtime_character, { "get_GameObject()" })

        return {
            actor_mode = "sigurd",
            actor_root = runtime_character,
            actor_root_source = runtime_character_source,
            runtime_character = runtime_character,
            runtime_character_source = runtime_character_source,
            human = human,
            human_source = human_source,
            game_object = game_object,
            game_object_source = game_object_source,
            game_object_name = get_game_object_name(game_object),
        }
    end

    local main_pawn, main_pawn_source = resolve_main_pawn(PawnManager, CharacterManager)
    local runtime_character, runtime_character_source = resolve_runtime_character_from_pawn(main_pawn)
    local human, human_source = safe_call_method0(runtime_character, { "get_Human()" })
    local game_object, game_object_source = safe_call_method0(runtime_character, { "get_GameObject()" })

    return {
        actor_mode = "main_pawn",
        actor_root = main_pawn,
        actor_root_source = main_pawn_source,
        runtime_character = runtime_character,
        runtime_character_source = runtime_character_source,
        human = human,
        human_source = human_source,
        game_object = game_object,
        game_object_source = game_object_source,
        game_object_name = get_game_object_name(game_object),
    }
end

local function resolve_current_job(actor)
    local job_context, job_context_source = safe_field(actor.human, {
        "<JobContext>k__BackingField",
        "JobContext",
    })

    local current_job, current_job_source = safe_field(actor.human, { "<CurrentJob>k__BackingField" })
    if current_job ~= nil then
        return current_job, "human:" .. tostring(current_job_source), job_context, job_context_source
    end

    local job_context_job, job_context_job_source = safe_field(job_context, { "CurrentJob" })
    if job_context_job ~= nil then
        return job_context_job, "job_context:" .. tostring(job_context_job_source), job_context, job_context_source
    end

    local method_job, method_job_source = safe_call_method0(actor.runtime_character, {
        "get_CurrentJob()",
        "get_Job()",
    })
    if method_job ~= nil then
        return method_job, "runtime_character:" .. tostring(method_job_source), job_context, job_context_source
    end

    local field_job, field_job_source = safe_field(actor.runtime_character, {
        "CurrentJob",
        "Job",
    })
    return field_job, "runtime_character:" .. tostring(field_job_source), job_context, job_context_source
end

local function resolve_job_specific_action_ctrl(human, current_job)
    local job_number = tonumber(current_job)
    local mapping = job_number ~= nil and JOB_CONTROLLER_MAP[job_number] or nil
    if mapping == nil then
        return nil, "job_without_known_controller_mapping"
    end

    local ctrl_field, ctrl_field_source = safe_field(human, { mapping.field })
    if is_present(ctrl_field) then
        return ctrl_field, "human:" .. tostring(ctrl_field_source)
    end

    local ctrl_getter, ctrl_getter_source = safe_call_method0(human, { mapping.getter })
    if is_present(ctrl_getter) then
        return ctrl_getter, "human:" .. tostring(ctrl_getter_source)
    end

    return nil, "unresolved"
end

local function resolve_decision_target(executing_decision)
    local target, target_source = safe_field(executing_decision, {
        "<Target>k__BackingField",
        "_Target",
        "Target",
    })
    if not is_present(target) then
        local getter_target, getter_target_source = safe_call_method0(executing_decision, { "get_Target()" })
        target = getter_target
        target_source = getter_target_source
    end

    local target_character, target_character_source = safe_field(target, {
        "<Character>k__BackingField",
        "Character",
    })
    if is_present(target_character) then
        return target_character, "target:" .. tostring(target_character_source)
    end

    return target, target_source
end

local function resolve_decision_pack_path(decision_module, executing_decision)
    local execute_actinter, execute_actinter_source = safe_field(decision_module, {
        "_ExecuteActInter",
        "<ExecuteActInter>k__BackingField",
        "ExecuteActInter",
    })
    local execute_pack, execute_pack_source = safe_call_method0(execute_actinter, { "get_ActInterPackData()" })
    if not is_present(execute_pack) then
        execute_pack, execute_pack_source = safe_field(execute_actinter, {
            "<ActInterPackData>k__BackingField",
            "_ActInterPackData",
            "ActInterPackData",
        })
    end

    local execute_pack_path, execute_pack_path_source = safe_call_method0(execute_pack, { "get_Path()" })
    if execute_pack_path ~= nil then
        return tostring(execute_pack_path), "execute_actinter:" .. tostring(execute_pack_path_source)
    end

    local decision_pack, decision_pack_source = safe_field(executing_decision, {
        "<ActionPackData>k__BackingField",
        "_ActionPackData",
        "ActionPackData",
    })
    if not is_present(decision_pack) then
        decision_pack, decision_pack_source = safe_call_method0(executing_decision, { "get_ActionPackData()" })
    end

    local decision_pack_path, decision_pack_path_source = safe_call_method0(decision_pack, { "get_Path()" })
    if decision_pack_path ~= nil then
        return tostring(decision_pack_path), "decision_pack:" .. tostring(decision_pack_path_source)
    end

    if is_present(execute_pack) then
        return describe(execute_pack), "execute_actinter_pack:" .. tostring(execute_pack_source)
    end
    if is_present(decision_pack) then
        return describe(decision_pack), "decision_pack:" .. tostring(decision_pack_source)
    end

    return nil, "unresolved"
end

local function build_action_manager_snapshot(action_manager)
    local snapshot = {}

    for _, field_name in ipairs(ACTION_MANAGER_FIELD_NAMES) do
        local value, source = safe_field(action_manager, { field_name })
        snapshot[field_name] = serialize_object(value, source)
    end

    local request_info_list, request_info_list_source = safe_field(action_manager, { "RequestInfoList" })
    local request_info_count, request_info_source = get_collection_count(request_info_list)
    snapshot.request_info_list = serialize_object(request_info_list, request_info_list_source)
    snapshot.request_info_count = serialize_scalar(request_info_count, request_info_source)

    local current_action_list, current_action_list_source = safe_field(action_manager, { "CurrentActionList" })
    local current_action_count, current_action_count_source = get_collection_count(current_action_list)
    snapshot.current_action_list = serialize_object(current_action_list, current_action_list_source)
    snapshot.current_action_count = serialize_scalar(current_action_count, current_action_count_source)

    local prev_action_list, prev_action_list_source = safe_field(action_manager, { "PrevActionList" })
    local prev_action_count, prev_action_count_source = get_collection_count(prev_action_list)
    snapshot.prev_action_list = serialize_object(prev_action_list, prev_action_list_source)
    snapshot.prev_action_count = serialize_scalar(prev_action_count, prev_action_count_source)

    return snapshot
end

local function build_controller_bundle(actor, human_action_selector, ai_blackboard, job07_action_ctrl)
    local battle_controller, battle_controller_source = resolve_controller(
        actor,
        CONTROLLER_FIELD_MAP.battle_controller,
        human_action_selector,
        ai_blackboard,
        job07_action_ctrl
    )
    local order_controller, order_controller_source = resolve_controller(
        actor,
        CONTROLLER_FIELD_MAP.order_controller,
        human_action_selector,
        ai_blackboard,
        job07_action_ctrl
    )
    local order_target_controller, order_target_controller_source = resolve_controller(
        actor,
        CONTROLLER_FIELD_MAP.order_target_controller,
        human_action_selector,
        ai_blackboard,
        job07_action_ctrl
    )
    local update_controller, update_controller_source = resolve_controller(
        actor,
        CONTROLLER_FIELD_MAP.update_controller,
        human_action_selector,
        ai_blackboard,
        job07_action_ctrl
    )

    return {
        battle_controller = serialize_object(battle_controller, battle_controller_source),
        order_controller = serialize_object(order_controller, order_controller_source),
        order_target_controller = serialize_object(order_target_controller, order_target_controller_source),
        update_controller = serialize_object(update_controller, update_controller_source),
        decision_pools = {
            battle_controller = build_decision_pool_snapshot(battle_controller),
            order_controller = build_decision_pool_snapshot(order_controller),
            order_target_controller = build_decision_pool_snapshot(order_target_controller),
            update_controller = build_decision_pool_snapshot(update_controller),
        },
    }
end

local function is_job07_pack(path)
    if type(path) ~= "string" then
        return false
    end

    return string.find(path, "/NPC/Job07/", 1, true) ~= nil
        or string.find(path, "/Job07/", 1, true) ~= nil
        or string.find(path, "/Job07_", 1, true) ~= nil
        or string.find(string.lower(path), "job07_", 1, true) ~= nil
end

local function is_generic_pack(path)
    if type(path) ~= "string" then
        return false
    end

    return string.find(path, "/Common/", 1, true) ~= nil
        or string.find(path, "/ch1/", 1, true) ~= nil
        or string.find(path, "/NPC/NPC_CombatMove.user", 1, true) ~= nil
end

local function is_job07_node(node_name)
    return type(node_name) == "string" and string.find(node_name, "Job07_", 1, true) ~= nil
end

local function is_generic_node(node_name)
    if type(node_name) ~= "string" then
        return false
    end

    return string.find(node_name, "Locomotion", 1, true) ~= nil
        or string.find(node_name, "Damage.", 1, true) ~= nil
        or string.find(node_name, "Caught.", 1, true) ~= nil
end

local function build_recursive_resolution(actor)
    local wanted_types = {
        ["app.ActionManager"] = "action_manager",
        ["app.AIBlackBoardController"] = "ai_blackboard_controller",
        ["app.HumanActionSelector"] = "human_action_selector",
        ["app.Job07ActionController"] = "job07_action_controller",
        ["app.DecisionEvaluationModule"] = "decision_module",
        ["app.DecisionExecutor"] = "decision_executor",
        ["app.PawnBattleController"] = "pawn_battle_controller",
        ["app.PawnOrderController"] = "pawn_order_controller",
        ["app.PawnOrderTargetController"] = "pawn_order_target_controller",
        ["app.PawnUpdateController"] = "pawn_update_controller",
        ["app.Character"] = "character",
        ["via.GameObject"] = "game_object",
    }

    local out = {}
    for _, root_spec in ipairs({
        { label = actor.actor_mode .. ":actor_root", value = actor.actor_root },
        { label = actor.actor_mode .. ":runtime_character", value = actor.runtime_character },
        { label = actor.actor_mode .. ":game_object", value = actor.game_object },
    }) do
        recursive_scan(root_spec.value, wanted_types, RECURSIVE_DEPTH, RECURSIVE_FIELD_LIMIT, out, {}, root_spec.label)
    end

    return out
end

local function capture_actor_screen(actor_mode)
    local actor = resolve_actor(actor_mode)
    local current_job, current_job_source, job_context, job_context_source = resolve_current_job(actor)
    local chara_id, chara_id_source = safe_call_method0(actor.runtime_character, { "get_CharaID()" })
    local action_manager, action_manager_source = safe_call_method0(actor.runtime_character, { "get_ActionManager()" })
    local ai_blackboard, ai_blackboard_source = safe_call_method0(actor.runtime_character, { "get_AIBlackBoardController()" })
    local human_action_selector, human_action_selector_source = safe_field(actor.human, {
        "<HumanActionSelector>k__BackingField",
        "<CommonActionSelector>k__BackingField",
    })
    local job07_action_ctrl, job07_action_ctrl_source = resolve_job_specific_action_ctrl(actor.human, current_job)
    local decision_maker, decision_maker_source = safe_field(actor.runtime_character, { "<AIDecisionMaker>k__BackingField", "AIDecisionMaker" })
    local decision_module, decision_module_source = safe_field(decision_maker, { "<DecisionModule>k__BackingField", "DecisionModule" })
    local decision_executor, decision_executor_source = safe_field(decision_module, { "<DecisionExecutor>k__BackingField", "DecisionExecutor" })
    local executing_decision, executing_decision_source = safe_field(decision_executor, { "<ExecutingDecision>k__BackingField", "ExecutingDecision" })
    local decision_target, decision_target_source = resolve_decision_target(executing_decision)
    local decision_pack_path, decision_pack_path_source = resolve_decision_pack_path(decision_module, executing_decision)
    local full_node, full_node_source = get_current_node_name(action_manager, 0)
    local upper_node, upper_node_source = get_current_node_name(action_manager, 1)
    local current_action, current_action_source = safe_field(action_manager, { "CurrentAction" })
    local selected_request, selected_request_source = safe_field(action_manager, { "SelectedRequest" })
    local selector_target, selector_target_source = resolve_surface_target(human_action_selector)
    local blackboard_target, blackboard_target_source = resolve_surface_target(ai_blackboard)
    local job07_ctrl_target, job07_ctrl_target_source = resolve_surface_target(job07_action_ctrl)
    local controllers = build_controller_bundle(actor, human_action_selector, ai_blackboard, job07_action_ctrl)

    return {
        actor_mode = actor_mode,
        actor_root = serialize_object(actor.actor_root, actor.actor_root_source),
        runtime_character = serialize_object(actor.runtime_character, actor.runtime_character_source),
        human = serialize_object(actor.human, actor.human_source),
        game_object = serialize_object(actor.game_object, actor.game_object_source),
        game_object_name = actor.game_object_name,
        chara_id = serialize_scalar(chara_id, chara_id_source),
        current_job = serialize_scalar(current_job, current_job_source),
        job_context = serialize_object(job_context, job_context_source),
        human_action_selector = serialize_object(human_action_selector, human_action_selector_source),
        job07_action_ctrl = serialize_object(job07_action_ctrl, job07_action_ctrl_source),
        action_manager = serialize_object(action_manager, action_manager_source),
        ai_blackboard = serialize_object(ai_blackboard, ai_blackboard_source),
        decision_maker = serialize_object(decision_maker, decision_maker_source),
        decision_module = serialize_object(decision_module, decision_module_source),
        decision_executor = serialize_object(decision_executor, decision_executor_source),
        executing_decision = serialize_object(executing_decision, executing_decision_source),
        decision_target = serialize_object(decision_target, decision_target_source),
        decision_pack_path = serialize_scalar(decision_pack_path, decision_pack_path_source),
        full_node = serialize_scalar(full_node, full_node_source),
        upper_node = serialize_scalar(upper_node, upper_node_source),
        current_action = serialize_object(current_action, current_action_source),
        selected_request = serialize_object(selected_request, selected_request_source),
        surface_targets = {
            human_action_selector = serialize_object(selector_target, selector_target_source),
            ai_blackboard = serialize_object(blackboard_target, blackboard_target_source),
            job07_action_ctrl = serialize_object(job07_ctrl_target, job07_ctrl_target_source),
        },
        controllers = controllers,
        action_manager_state = build_action_manager_snapshot(action_manager),
        named_context_fields = {
            job_context = snapshot_named_fields(job_context, JOB_CONTEXT_FIELD_NAMES),
            human_action_selector = snapshot_named_fields(human_action_selector, HUMAN_ACTION_SELECTOR_FIELD_NAMES),
            ai_blackboard = snapshot_named_fields(ai_blackboard, AI_BLACKBOARD_FIELD_NAMES),
            job07_action_ctrl = snapshot_named_fields(job07_action_ctrl, JOB07_CTRL_FIELD_NAMES),
        },
        shallow_field_snapshots = {
            job_context = snapshot_shallow_fields(job_context, SHALLOW_FIELD_LIMIT),
            human_action_selector = snapshot_shallow_fields(human_action_selector, SHALLOW_FIELD_LIMIT),
            ai_blackboard = snapshot_shallow_fields(ai_blackboard, SHALLOW_FIELD_LIMIT),
            job07_action_ctrl = snapshot_shallow_fields(job07_action_ctrl, SHALLOW_FIELD_LIMIT),
        },
        recursive_resolution = build_recursive_resolution(actor),
    }
end

local function pool_has_present_value(snapshot, field_names)
    for _, field_name in ipairs(field_names) do
        local item = snapshot and snapshot[field_name] or nil
        if item ~= nil and item.present == true then
            return true
        end
    end

    return false
end

local function actor_has_decision_pool_signal(actor)
    local decision_pools = actor.controllers and actor.controllers.decision_pools or nil
    if decision_pools == nil then
        return false
    end

    return pool_has_present_value(decision_pools.battle_controller, {
        "_CurrentGoalList",
        "CurrentGoalList",
        "_CurrentAddDecisionList",
        "CurrentAddDecisionList",
        "_BattleAIData",
        "BattleAIData",
    }) or pool_has_present_value(decision_pools.order_controller, {
        "MainDecisions",
        "PreDecisions",
        "PostDecisions",
        "ActiveDecisionPacks",
        "OrderData",
    }) or pool_has_present_value(decision_pools.update_controller, {
        "AIGoalActionData",
    })
end

local function build_compare_summary(main_pawn, sigurd)
    local main_pawn_job = tonumber(main_pawn.current_job.value)
    local sigurd_job = tonumber(sigurd.current_job.value)
    local main_pawn_pack = main_pawn.decision_pack_path.value
    local sigurd_pack = sigurd.decision_pack_path.value
    local main_pawn_node = main_pawn.full_node.value
    local sigurd_node = sigurd.full_node.value
    local main_pawn_pack_is_job07 = is_job07_pack(main_pawn_pack)
    local sigurd_pack_is_job07 = is_job07_pack(sigurd_pack)
    local main_pawn_node_is_job07 = is_job07_node(main_pawn_node)
    local sigurd_node_is_job07 = is_job07_node(sigurd_node)
    local main_pawn_selector_target_type = main_pawn.surface_targets.human_action_selector.type_name
    local sigurd_selector_target_type = sigurd.surface_targets.human_action_selector.type_name
    local main_pawn_blackboard_target_type = main_pawn.surface_targets.ai_blackboard.type_name
    local sigurd_blackboard_target_type = sigurd.surface_targets.ai_blackboard.type_name
    local main_pawn_has_decision_pools = actor_has_decision_pool_signal(main_pawn)
    local sigurd_has_decision_pools = actor_has_decision_pool_signal(sigurd)
    local interpretation = "unresolved"

    if not main_pawn.runtime_character.present or not sigurd.runtime_character.present then
        interpretation = "actor_missing_in_scene"
    elseif main_pawn_job ~= 7 or sigurd_job ~= 7 then
        interpretation = "actor_not_in_job07"
    elseif sigurd.controllers.battle_controller.present and not main_pawn.controllers.battle_controller.present then
        interpretation = "main_pawn_missing_battle_controller_surface"
    elseif sigurd.controllers.order_controller.present and not main_pawn.controllers.order_controller.present then
        interpretation = "main_pawn_missing_order_controller_surface"
    elseif sigurd.controllers.order_target_controller.present and not main_pawn.controllers.order_target_controller.present then
        interpretation = "main_pawn_missing_order_target_controller_surface"
    elseif sigurd.controllers.update_controller.present and not main_pawn.controllers.update_controller.present then
        interpretation = "main_pawn_missing_update_controller_surface"
    elseif sigurd_selector_target_type == "app.Character" and main_pawn_selector_target_type ~= "app.Character" then
        interpretation = "main_pawn_selector_target_surface_gap"
    elseif sigurd_blackboard_target_type == "app.Character" and main_pawn_blackboard_target_type ~= "app.Character" then
        interpretation = "main_pawn_blackboard_target_surface_gap"
    elseif sigurd_has_decision_pools and not main_pawn_has_decision_pools then
        interpretation = "main_pawn_missing_decision_pool_surface"
    elseif sigurd_pack_is_job07 and not main_pawn_pack_is_job07 then
        interpretation = "main_pawn_stuck_before_job07_pack_selection"
    elseif sigurd_node_is_job07 and not main_pawn_node_is_job07 then
        interpretation = "main_pawn_stuck_before_job07_node_transition"
    elseif not sigurd_pack_is_job07 and not sigurd_node_is_job07 then
        interpretation = "sigurd_not_in_job07_combat_phase"
    elseif main_pawn_pack_is_job07 and sigurd_pack_is_job07 then
        interpretation = "no_pack_gap_in_this_scene"
    end

    return {
        main_pawn_loaded = main_pawn.runtime_character.present,
        sigurd_loaded = sigurd.runtime_character.present,
        both_loaded = main_pawn.runtime_character.present and sigurd.runtime_character.present,
        main_pawn_job = main_pawn_job,
        sigurd_job = sigurd_job,
        main_pawn_job07_action_ctrl_live = main_pawn.job07_action_ctrl.present,
        sigurd_job07_action_ctrl_live = sigurd.job07_action_ctrl.present,
        main_pawn_executing_decision_live = main_pawn.executing_decision.present,
        sigurd_executing_decision_live = sigurd.executing_decision.present,
        main_pawn_target_type = main_pawn.decision_target.type_name,
        sigurd_target_type = sigurd.decision_target.type_name,
        main_pawn_selector_target_type = main_pawn_selector_target_type,
        sigurd_selector_target_type = sigurd_selector_target_type,
        main_pawn_blackboard_target_type = main_pawn_blackboard_target_type,
        sigurd_blackboard_target_type = sigurd_blackboard_target_type,
        main_pawn_pack_path = main_pawn_pack,
        sigurd_pack_path = sigurd_pack,
        main_pawn_full_node = main_pawn_node,
        sigurd_full_node = sigurd_node,
        main_pawn_upper_node = main_pawn.upper_node.value,
        sigurd_upper_node = sigurd.upper_node.value,
        main_pawn_pack_is_job07_specific = main_pawn_pack_is_job07,
        sigurd_pack_is_job07_specific = sigurd_pack_is_job07,
        main_pawn_node_is_job07_specific = main_pawn_node_is_job07,
        sigurd_node_is_job07_specific = sigurd_node_is_job07,
        main_pawn_generic_pack = is_generic_pack(main_pawn_pack),
        sigurd_generic_pack = is_generic_pack(sigurd_pack),
        main_pawn_generic_node = is_generic_node(main_pawn_node),
        sigurd_generic_node = is_generic_node(sigurd_node),
        main_pawn_battle_controller_live = main_pawn.controllers.battle_controller.present,
        sigurd_battle_controller_live = sigurd.controllers.battle_controller.present,
        main_pawn_order_controller_live = main_pawn.controllers.order_controller.present,
        sigurd_order_controller_live = sigurd.controllers.order_controller.present,
        main_pawn_order_target_controller_live = main_pawn.controllers.order_target_controller.present,
        sigurd_order_target_controller_live = sigurd.controllers.order_target_controller.present,
        main_pawn_update_controller_live = main_pawn.controllers.update_controller.present,
        sigurd_update_controller_live = sigurd.controllers.update_controller.present,
        main_pawn_has_decision_pool_signals = main_pawn_has_decision_pools,
        sigurd_has_decision_pool_signals = sigurd_has_decision_pools,
        pack_gap_job07_specific_vs_generic = sigurd_pack_is_job07 and not main_pawn_pack_is_job07,
        node_gap_job07_specific_vs_generic = sigurd_node_is_job07 and not main_pawn_node_is_job07,
        interpretation = interpretation,
    }
end

local main_pawn = capture_actor_screen("main_pawn")
local sigurd = capture_actor_screen("sigurd")

local output = {
    tag = "job07_selector_admission_compare",
    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
    output_note = "Compare selector/admission/context surfaces for main_pawn Job07 versus Sigurd Job07.",
    compare = {
        main_pawn = main_pawn,
        sigurd = sigurd,
    },
    summary = build_compare_summary(main_pawn, sigurd),
}

local output_path = "ce_dump/job07_selector_admission_compare_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
json.dump_file(output_path, output)
print("[job07_selector_admission_compare] wrote " .. output_path)
return output_path
