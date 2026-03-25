-- Purpose:
-- Compare field, getter and recursive resolution paths for main_pawn Job07 runtime.
-- Output:
--   reframework/data/ce_dump/job07_runtime_resolution_screen_<timestamp>.json

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

    local t = type(obj)
    if t == "userdata" then
        return tostring(obj)
    end
    if t == "table" then
        return "<table>"
    end

    return tostring(obj)
end

local function is_present(obj)
    return obj ~= nil and tostring(obj) ~= "nil"
end

local function get_collection_count(obj)
    if obj == nil then
        return nil
    end

    local method_candidates = {
        "get_Count()",
        "get_count()",
        "get_Size()",
        "get_size()",
    }

    for _, method_name in ipairs(method_candidates) do
        local ok, value = try_eval(function()
            return obj:call(method_name)
        end)
        if ok and value ~= nil then
            return value
        end
    end

    local field_candidates = { "Count", "count", "_size", "size" }
    for _, field_name in ipairs(field_candidates) do
        local ok, value = try_eval(function()
            return obj[field_name]
        end)
        if ok and value ~= nil then
            return value
        end
    end

    return nil
end

local function serialize_object(value, source)
    return {
        present = is_present(value),
        description = describe(value),
        type_name = get_type_name(value),
        source = source or "unresolved",
    }
end

local function serialize_collection(value, source)
    return {
        present = is_present(value),
        description = describe(value),
        type_name = get_type_name(value),
        count = get_collection_count(value),
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

local function resolve_decision_target(executing_decision)
    local target, target_source = safe_field(executing_decision, {
        "<Target>k__BackingField",
        "_Target",
        "Target",
    })
    if not is_present(target) then
        local getter_target, getter_target_source = safe_call_method0(executing_decision, {
            "get_Target()",
        })
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
    local execute_pack, execute_pack_source = safe_call_method0(execute_actinter, {
        "get_ActInterPackData()",
    })
    if not is_present(execute_pack) then
        execute_pack, execute_pack_source = safe_field(execute_actinter, {
            "<ActInterPackData>k__BackingField",
            "_ActInterPackData",
            "ActInterPackData",
        })
    end

    local execute_pack_path, execute_pack_path_source = safe_call_method0(execute_pack, {
        "get_Path()",
    })
    if execute_pack_path ~= nil then
        return tostring(execute_pack_path), "execute_actinter:" .. tostring(execute_pack_path_source)
    end

    local decision_pack, decision_pack_source = safe_field(executing_decision, {
        "<ActionPackData>k__BackingField",
        "_ActionPackData",
        "ActionPackData",
    })
    if not is_present(decision_pack) then
        decision_pack, decision_pack_source = safe_call_method0(executing_decision, {
            "get_ActionPackData()",
        })
    end

    local decision_pack_path, decision_pack_path_source = safe_call_method0(decision_pack, {
        "get_Path()",
    })
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

local function get_fsm_node_name(action_manager, layer_index)
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

    local node_to_string, node_to_string_source = safe_call_method0(node_name, {
        "ToString()",
    })
    if type(node_to_string) == "string" then
        return node_to_string, "fsm:" .. tostring(node_to_string_source)
    end

    return node_name, "fsm:" .. tostring(node_name_source)
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

    local limit = field_limit or 24
    for index, field in ipairs(fields) do
        if index > limit then
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

local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
local PawnManager = sdk.get_managed_singleton("app.PawnManager")

local function resolve_main_pawn()
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

    local methods = {
        "get_CachedCharacter()",
        "get_Character()",
        "get_Chara()",
        "get_PawnCharacter()",
    }
    local value, source = safe_call_method0(main_pawn, methods)
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

local function build_action_manager_snapshot(action_manager)
    local current_action, current_action_source = safe_field(action_manager, { "CurrentAction" })
    local prev_action, prev_action_source = safe_field(action_manager, { "PrevAction" })
    local selected_request, selected_request_source = safe_field(action_manager, { "SelectedRequest" })
    local request_info_list, request_info_list_source = safe_field(action_manager, { "RequestInfoList" })
    local current_action_list, current_action_list_source = safe_field(action_manager, { "CurrentActionList" })
    local prev_action_list, prev_action_list_source = safe_field(action_manager, { "PrevActionList" })
    local is_requested_list, is_requested_list_source = safe_field(action_manager, { "IsRequestedList" })
    local is_action_changed_list, is_action_changed_list_source = safe_field(action_manager, { "IsActionChangedList" })
    local default_layer_num, default_layer_num_source = safe_field(action_manager, { "DefaultLayerNum" })

    return {
        current_action = serialize_object(current_action, current_action_source),
        prev_action = serialize_object(prev_action, prev_action_source),
        selected_request = serialize_object(selected_request, selected_request_source),
        request_info_list = serialize_collection(request_info_list, request_info_list_source),
        current_action_list = serialize_collection(current_action_list, current_action_list_source),
        prev_action_list = serialize_collection(prev_action_list, prev_action_list_source),
        is_requested_list = serialize_collection(is_requested_list, is_requested_list_source),
        is_action_changed_list = serialize_collection(is_action_changed_list, is_action_changed_list_source),
        default_layer_num = {
            value = default_layer_num,
            description = describe(default_layer_num),
            source = default_layer_num_source,
        },
    }
end

local function build_decision_state_snapshot(decision_module, decision_executor, executing_decision, action_manager)
    local decision_target, decision_target_source = resolve_decision_target(executing_decision)
    local decision_pack_path, decision_pack_path_source = resolve_decision_pack_path(decision_module, executing_decision)
    local full_node, full_node_source = get_fsm_node_name(action_manager, 0)
    local upper_node, upper_node_source = get_fsm_node_name(action_manager, 1)

    return {
        decision_target = serialize_object(decision_target, decision_target_source),
        decision_pack_path = serialize_scalar(decision_pack_path, decision_pack_path_source),
        executing_decision = serialize_object(executing_decision, "decision_executor"),
        decision_executor = serialize_object(decision_executor, "decision_module"),
        full_node = serialize_scalar(full_node, full_node_source),
        upper_node = serialize_scalar(upper_node, upper_node_source),
    }
end

local main_pawn, main_pawn_source = resolve_main_pawn()
local runtime_character, runtime_character_source = resolve_runtime_character(main_pawn)
local game_object, game_object_source = safe_call_method0(runtime_character, { "get_GameObject()" })
local human, human_source = safe_call_method0(runtime_character, { "get_Human()" })
local action_manager_getter, action_manager_getter_source = safe_call_method0(runtime_character, { "get_ActionManager()" })
local ai_blackboard_getter, ai_blackboard_getter_source = safe_call_method0(runtime_character, { "get_AIBlackBoardController()" })
local human_action_selector_field, human_action_selector_field_source = safe_field(human, { "<HumanActionSelector>k__BackingField" })
local job07_action_ctrl_field, job07_action_ctrl_field_source = safe_field(human, { "<Job07ActionCtrl>k__BackingField" })
local job07_action_ctrl_getter, job07_action_ctrl_getter_source = safe_call_method0(human, { "get_Job07ActionCtrl()" })
local job_context, job_context_source = safe_field(human, { "<JobContext>k__BackingField" })
local current_job, current_job_source = safe_field(job_context, { "CurrentJob" })
if current_job == nil then
    current_job, current_job_source = safe_field(runtime_character, { "Job" })
end

local decision_maker, decision_maker_source = safe_field(runtime_character, { "<AIDecisionMaker>k__BackingField", "AIDecisionMaker" })
local decision_module, decision_module_source = safe_field(decision_maker, { "<DecisionModule>k__BackingField", "DecisionModule" })
local decision_executor, decision_executor_source = safe_field(decision_module, { "<DecisionExecutor>k__BackingField", "DecisionExecutor" })
local executing_decision, executing_decision_source = safe_field(decision_executor, { "<ExecutingDecision>k__BackingField", "ExecutingDecision" })

local human_param_root, human_param_root_source = safe_call_method0(CharacterManager, { "get_HumanParam()" })
local job_param_root, job_param_root_source = safe_field(human_param_root, { "JobParam" })
local global_job07_param, global_job07_param_source = safe_field(job_param_root, { "Job07Parameter" })

local pawn_ai_data, pawn_ai_data_source = safe_call_method0(PawnManager, { "get_AIData()" })

local recursive_roots = {
    { label = "runtime_character", value = runtime_character },
    { label = "main_pawn", value = main_pawn },
    { label = "game_object", value = game_object },
    { label = "PawnManager", value = PawnManager },
    { label = "PawnManager:get_AIData()", value = pawn_ai_data },
    { label = "CharacterManager", value = CharacterManager },
}

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
    ["app.Pawn"] = "pawn",
    ["via.GameObject"] = "game_object",
}

local recursive_results = {}
for _, root in ipairs(recursive_roots) do
    recursive_scan(root.value, wanted_types, 3, 24, recursive_results, {}, root.label)
end

local game_object_name = nil
if is_present(game_object) then
    local ok_name, value_name = try_eval(function()
        return game_object:call("get_Name()")
    end)
    if ok_name then
        game_object_name = value_name
    end
end

local summary = {
    current_job = current_job,
    main_pawn_source = main_pawn_source,
    runtime_character_source = runtime_character_source,
    getter_job07_action_ctrl_live = is_present(job07_action_ctrl_getter),
    field_job07_action_ctrl_live = is_present(job07_action_ctrl_field),
    getter_vs_field_gap = is_present(job07_action_ctrl_getter) and not is_present(job07_action_ctrl_field),
    getter_ai_blackboard_live = is_present(ai_blackboard_getter),
    getter_action_manager_live = is_present(action_manager_getter),
    decision_module_live = is_present(decision_module),
    executing_decision_live = is_present(executing_decision),
    recursive_job07_action_controller_live = recursive_results.job07_action_controller ~= nil,
    interpretation = "unresolved",
}

if tonumber(current_job) ~= 7 then
    summary.interpretation = "main_pawn_not_in_job07"
elseif summary.getter_vs_field_gap then
    summary.interpretation = "getter_live_field_nil"
elseif summary.getter_job07_action_ctrl_live and summary.getter_action_manager_live and summary.getter_ai_blackboard_live then
    summary.interpretation = "controller_live_execution_needs_action_state_check"
elseif not summary.getter_job07_action_ctrl_live and not summary.field_job07_action_ctrl_live then
    summary.interpretation = "job07_action_ctrl_unresolved_in_this_scene"
else
    summary.interpretation = "partial_resolution_only"
end

local output = {
    tag = "job07_runtime_resolution_screen",
    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
    output_note = "Compare field/getter/recursive resolution for main_pawn Job07 runtime.",
    actor = {
        current_job = {
            value = current_job,
            description = describe(current_job),
            source = current_job_source,
        },
        main_pawn = serialize_object(main_pawn, main_pawn_source),
        runtime_character = serialize_object(runtime_character, runtime_character_source),
        human = serialize_object(human, human_source),
        game_object = serialize_object(game_object, game_object_source),
        game_object_name = game_object_name,
        job_context = serialize_object(job_context, job_context_source),
    },
    field_vs_getter = {
        job07_action_ctrl_field = serialize_object(job07_action_ctrl_field, job07_action_ctrl_field_source),
        job07_action_ctrl_getter = serialize_object(job07_action_ctrl_getter, job07_action_ctrl_getter_source),
        human_action_selector_field = serialize_object(human_action_selector_field, human_action_selector_field_source),
        ai_blackboard_getter = serialize_object(ai_blackboard_getter, ai_blackboard_getter_source),
        action_manager_getter = serialize_object(action_manager_getter, action_manager_getter_source),
        decision_maker = serialize_object(decision_maker, decision_maker_source),
        decision_module = serialize_object(decision_module, decision_module_source),
        decision_executor = serialize_object(decision_executor, decision_executor_source),
        executing_decision = serialize_object(executing_decision, executing_decision_source),
        global_job07_param = serialize_object(global_job07_param, global_job07_param_source),
        global_job07_param_root = serialize_object(job_param_root, job_param_root_source),
        global_human_param = serialize_object(human_param_root, human_param_root_source),
    },
    recursive_resolution = recursive_results,
    action_manager_state = build_action_manager_snapshot(action_manager_getter),
    decision_state = build_decision_state_snapshot(decision_module, decision_executor, executing_decision, action_manager_getter),
    roots = {
        pawn_manager = serialize_object(PawnManager, "sdk.get_managed_singleton(app.PawnManager)"),
        pawn_ai_data = serialize_object(pawn_ai_data, pawn_ai_data_source),
        character_manager = serialize_object(CharacterManager, "sdk.get_managed_singleton(app.CharacterManager)"),
    },
    summary = summary,
}

local output_path = "ce_dump/job07_runtime_resolution_screen_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
json.dump_file(output_path, output)
print("[job07_runtime_resolution_screen] wrote " .. output_path)
return output_path
