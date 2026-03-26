local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local log = require("PawnHybridVocationsAI/core/log")
local util = require("PawnHybridVocationsAI/core/util")
local execution_contracts = require("PawnHybridVocationsAI/core/execution_contracts")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")
local hybrid_combat_profiles = require("PawnHybridVocationsAI/data/hybrid_combat_profiles")

local hybrid_combat_fix = {}

local ACTINTER_EXECUTE_SIGNATURE = "setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)"
local ACTINTER_REQMAIN_SIGNATURE = "set_ReqMainActInterPackData(app.ActInterPackData)"
local REQUEST_SKIP_THINK_SIGNATURE = "requestSkipThink()"

local ACTION_PACK_FIELDS = {
    "<ActionPackData>k__BackingField",
    "_ActionPackData",
    "ActionPackData",
    "<ActInterPackData>k__BackingField",
    "_ActInterPackData",
    "ActInterPackData",
    "<PackData>k__BackingField",
    "_PackData",
    "PackData",
    "<ActionPack>k__BackingField",
    "_ActionPack",
    "ActionPack",
}

local ACTION_PACK_METHODS = {
    "get_ActionPackData()",
    "get_ActInterPackData()",
    "get_PackData()",
    "get_ActionPack()",
}

local PATH_FIELDS = {
    "<Path>k__BackingField",
    "_Path",
    "Path",
    "<ResourcePath>k__BackingField",
    "_ResourcePath",
    "ResourcePath",
    "<FilePath>k__BackingField",
    "_FilePath",
    "FilePath",
}

local PATH_METHODS = {
    "get_Path()",
    "get_ResourcePath()",
    "get_FilePath()",
}

local NAME_FIELDS = {
    "<Name>k__BackingField",
    "_Name",
    "Name",
    "<ResourceName>k__BackingField",
    "_ResourceName",
    "ResourceName",
}

local NAME_METHODS = {
    "get_Name()",
    "get_ResourceName()",
}

local EQUIPPED_SKILLS_FIELDS = {
    "EquipedSkills",
    "<EquipedSkills>k__BackingField",
    "_EquipedSkills",
}

local SKILLS_LIST_FIELDS = {
    "Skills",
    "<Skills>k__BackingField",
    "_Skills",
}

local UTILITY_TOKENS = {
    "/common/",
    "/ch1/",
    "movetoposition",
    "moveapproach",
    "keepdistance",
    "strafe",
    "locomotion.",
    "normallocomotion",
    "dodge",
    "drawweapon",
}

local SPECIAL_SKIP_TOKENS = {
    "talk",
    "greeting",
    "highfive",
    "lookat",
    "sortitem",
    "treasurebox",
    "carry",
    "cling",
    "catch",
    "winbattle",
}

local function fix_config()
    return config.hybrid_combat_fix or {}
end

local function unsafe_skill_probe_mode()
    local mode = string.lower(tostring(fix_config().unsafe_skill_probe_mode or "off"))
    if mode == "action_only" or mode == "carrier_only" or mode == "carrier_then_action" then
        return mode
    end

    return "off"
end

local function call_first(obj, method_name)
    return util.safe_direct_method(obj, method_name)
        or util.safe_method(obj, method_name .. "()")
        or util.safe_method(obj, method_name)
end

local function field_first(obj, field_name)
    return util.safe_field(obj, field_name)
end

local function is_present_value(value)
    if value == nil then
        return false
    end
    if type(value) == "userdata" then
        return util.is_valid_obj(value)
    end

    return tostring(value) ~= "nil"
end

local function present_field(obj, fields)
    for _, field_name in ipairs(fields or {}) do
        local value = field_first(obj, field_name)
        if is_present_value(value) then
            return value, field_name
        end
    end

    return nil, "unresolved"
end

local function present_method(obj, methods)
    for _, method_name in ipairs(methods or {}) do
        local value = util.safe_method(obj, method_name)
        if is_present_value(value) then
            return value, method_name
        end
    end

    return nil, "unresolved"
end

local function to_string_or_nil(value)
    if value == nil then
        return nil
    end

    local value_type = type(value)
    if value_type == "string" or value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end

    return nil
end

local function describe_value(value)
    if value == nil then
        return "nil"
    end

    local text = to_string_or_nil(value)
    if text ~= nil then
        return text
    end

    if type(value) == "userdata" then
        return util.describe_obj(value)
    end

    return tostring(value)
end

local function decode_small_int(value)
    if type(value) == "number" then
        return value
    end

    local direct = tonumber(value)
    if direct ~= nil then
        return direct
    end

    local text = tostring(value or "")
    local hex_value = text:match("userdata:%s*(%x+)")
    if hex_value == nil then
        return nil
    end

    local parsed = tonumber(hex_value, 16)
    if parsed == nil or parsed < 0 or parsed > 4096 then
        return nil
    end

    return parsed
end

local function decode_truthy(value)
    if type(value) == "boolean" then
        return value
    end

    local numeric = decode_small_int(value)
    if numeric ~= nil then
        return numeric ~= 0
    end

    local text = tostring(value or "")
    if text == "true" then
        return true
    end
    if text == "false" then
        return false
    end

    return nil
end

local function lower_text(value)
    if value == nil then
        return nil
    end

    return string.lower(tostring(value))
end

local function contains_text(value, needle)
    local haystack = lower_text(value)
    local pattern = lower_text(needle)
    if haystack == nil or pattern == nil then
        return false
    end

    return string.find(haystack, pattern, 1, true) ~= nil
end

local function contains_any_text(value, needles)
    for _, needle in ipairs(needles or {}) do
        if contains_text(value, needle) then
            return true
        end
    end

    return false
end

local function resolve_string_field_or_method(obj, fields, methods)
    for _, field_name in ipairs(fields or {}) do
        local field_value = field_first(obj, field_name)
        local field_text = to_string_or_nil(field_value)
        if field_text ~= nil then
            return field_text
        end
    end

    for _, method_name in ipairs(methods or {}) do
        local method_value = util.safe_method(obj, method_name)
        local method_text = to_string_or_nil(method_value)
        if method_text ~= nil then
            return method_text
        end
    end

    return nil
end

local function resolve_pack_like_identity(root)
    local direct = to_string_or_nil(root)
    if direct ~= nil then
        return direct
    end

    local pack_object = present_field(root, ACTION_PACK_FIELDS)
    if not is_present_value(pack_object) then
        pack_object = present_method(root, ACTION_PACK_METHODS)
    end

    local target = is_present_value(pack_object) and pack_object or root
    local path = resolve_string_field_or_method(target, PATH_FIELDS, PATH_METHODS)
    if path ~= nil then
        return path
    end

    local name = resolve_string_field_or_method(target, NAME_FIELDS, NAME_METHODS)
    if name ~= nil then
        return name
    end

    local text = to_string_or_nil(call_first(target, "ToString"))
    if text ~= nil then
        return text
    end

    return util.get_type_full_name(target) or util.describe_obj(target)
end

local function get_current_node(action_manager, layer_index)
    local fsm = field_first(action_manager, "Fsm")
    if not util.is_valid_obj(fsm) then
        return nil
    end

    local node_name = util.safe_method(fsm, "getCurrentNodeName(System.UInt32)", layer_index)
        or util.safe_method(fsm, "getCurrentNodeName", layer_index)
    if type(node_name) == "string" then
        return node_name
    end

    local text = node_name and call_first(node_name, "ToString") or nil
    return type(text) == "string" and text or nil
end

local function resolve_decision_pack_path(decision_module, executing_decision)
    local execute_actinter = present_field(decision_module, {
        "_ExecuteActInter",
        "<ExecuteActInter>k__BackingField",
        "ExecuteActInter",
    })
    local execute_pack = call_first(execute_actinter, "get_ActInterPackData")
    if not is_present_value(execute_pack) then
        execute_pack = present_field(execute_actinter, {
            "<ActInterPackData>k__BackingField",
            "_ActInterPackData",
            "ActInterPackData",
        })
    end

    local execute_pack_path = resolve_string_field_or_method(execute_pack, PATH_FIELDS, PATH_METHODS)
    if execute_pack_path ~= nil then
        return execute_pack_path
    end

    local decision_pack = present_field(executing_decision, {
        "<ActionPackData>k__BackingField",
        "_ActionPackData",
        "ActionPackData",
    })
    if not is_present_value(decision_pack) then
        decision_pack = present_method(executing_decision, {
            "get_ActionPackData()",
            "get_ActionPackData",
        })
    end

    local decision_pack_path = resolve_string_field_or_method(decision_pack, PATH_FIELDS, PATH_METHODS)
    if decision_pack_path ~= nil then
        return decision_pack_path
    end

    return nil
end

local function resolve_decision_target(executing_decision)
    if not util.is_valid_obj(executing_decision) then
        return nil, "executing_decision_unresolved"
    end

    local ai_target = field_first(executing_decision, "<Target>k__BackingField")
        or field_first(executing_decision, "Target")
        or call_first(executing_decision, "get_Target")
    if not is_present_value(ai_target) then
        return nil, "decision_target_unresolved"
    end

    local target = field_first(ai_target, "<Character>k__BackingField")
        or field_first(ai_target, "<OwnerCharacter>k__BackingField")
        or call_first(ai_target, "get_Character")
        or call_first(ai_target, "get_OwnerCharacter")
    if not util.is_valid_obj(target) then
        return nil, "decision_target_character_unresolved"
    end

    local game_object = field_first(ai_target, "<GameObject>k__BackingField")
        or field_first(ai_target, "<Owner>k__BackingField")
        or field_first(ai_target, "GameObject")
        or field_first(ai_target, "Owner")
        or call_first(ai_target, "get_GameObject")
        or call_first(ai_target, "get_Owner")
    local transform = field_first(ai_target, "<Transform>k__BackingField")
        or field_first(ai_target, "Transform")
        or call_first(ai_target, "get_Transform")
    local context_holder = field_first(ai_target, "<ContextHolder>k__BackingField")
        or field_first(ai_target, "ContextHolder")
        or call_first(ai_target, "get_ContextHolder")

    return {
        ai_target = ai_target,
        character = target,
        game_object = game_object,
        transform = transform,
        context_holder = context_holder,
    }, "executing_decision_target"
end

local function resolve_position(obj)
    if not util.is_valid_obj(obj) then
        return nil
    end

    local transform = call_first(obj, "get_Transform")
    if util.is_valid_obj(transform) then
        local position = util.safe_method(transform, "get_Position")
            or util.safe_method(transform, "get_UniversalPosition")
        if position ~= nil then
            return position
        end
    end

    return util.safe_method(obj, "get_UniversalPosition")
end

local function compute_distance(left, right)
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

local function resolve_context(runtime)
    local main_pawn = runtime.main_pawn_data
    if main_pawn == nil then
        return nil, "main_pawn_data_unresolved"
    end

    local runtime_character = main_pawn.runtime_character
    if not util.is_valid_obj(runtime_character) then
        return nil, "runtime_character_unresolved"
    end

    local current_job = decode_small_int(main_pawn.current_job or main_pawn.job or field_first(runtime_character, "Job"))
    if not hybrid_jobs.is_hybrid_job(current_job) then
        return nil, "main_pawn_not_hybrid_job"
    end

    local profile = hybrid_combat_profiles.get_by_job_id(current_job)
    if profile == nil then
        return nil, "hybrid_profile_unresolved"
    end

    local action_manager = main_pawn.action_manager or call_first(runtime_character, "get_ActionManager")
    if not util.is_valid_obj(action_manager) then
        return nil, "action_manager_unresolved"
    end

    local decision_maker = field_first(runtime_character, "<AIDecisionMaker>k__BackingField")
        or field_first(runtime_character, "AIDecisionMaker")
        or call_first(runtime_character, "get_AIDecisionMaker")
    local decision_module = field_first(decision_maker, "<DecisionModule>k__BackingField")
        or field_first(decision_maker, "DecisionModule")
        or call_first(decision_maker, "get_DecisionModule")
    local decision_executor = field_first(decision_module, "<DecisionExecutor>k__BackingField")
        or field_first(decision_module, "DecisionExecutor")
        or field_first(decision_module, "_DecisionExecutor")
        or call_first(decision_module, "get_DecisionExecutor")
    local executing_decision = field_first(decision_executor, "<ExecutingDecision>k__BackingField")
        or field_first(decision_executor, "ExecutingDecision")
        or field_first(decision_executor, "_ExecutingDecision")
        or call_first(decision_executor, "get_ExecutingDecision")
    local ai_blackboard = field_first(runtime_character, "<AIBlackBoardController>k__BackingField")
        or field_first(runtime_character, "AIBlackBoardController")
        or call_first(runtime_character, "get_AIBlackBoardController")

    local current_action = field_first(action_manager, "CurrentAction")
    local selected_request = field_first(action_manager, "SelectedRequest")

    return {
        main_pawn = main_pawn,
        runtime_character = runtime_character,
        current_job = current_job,
        job_entry = hybrid_jobs.get_by_id(current_job),
        profile = profile,
        action_manager = action_manager,
        decision_module = decision_module,
        decision_executor = decision_executor,
        executing_decision = executing_decision,
        ai_blackboard = ai_blackboard,
        current_action = current_action,
        selected_request = selected_request,
        current_action_identity = resolve_pack_like_identity(current_action),
        selected_request_identity = resolve_pack_like_identity(selected_request),
        decision_pack_path = resolve_decision_pack_path(decision_module, executing_decision),
        full_node = main_pawn.full_node or get_current_node(action_manager, 0),
        upper_node = main_pawn.upper_node or get_current_node(action_manager, 1),
    }, nil
end

local function create_ai_target(target_info)
    if type(target_info) ~= "table" or not util.is_valid_obj(target_info.character) then
        return nil
    end

    local ok, ai_target = pcall(sdk.create_instance, "app.AITargetGameObject", true)
    if not ok or ai_target == nil then
        return nil
    end

    if not util.is_valid_obj(target_info.game_object) then
        return nil
    end

    util.safe_set_field(ai_target, "<GameObject>k__BackingField", target_info.game_object)
    util.safe_set_field(ai_target, "<Character>k__BackingField", target_info.character)
    util.safe_set_field(ai_target, "<Owner>k__BackingField", target_info.game_object)
    util.safe_set_field(ai_target, "<OwnerCharacter>k__BackingField", target_info.character)
    util.safe_set_field(ai_target, "<ContextHolder>k__BackingField", target_info.context_holder)
    util.safe_set_field(ai_target, "<Transform>k__BackingField", target_info.transform)
    return ai_target
end

local function get_job_action_ctrl(context, job_id)
    local human = context and context.main_pawn and context.main_pawn.human or nil
    if not util.is_valid_obj(human) then
        human = call_first(context and context.runtime_character, "get_Human")
    end
    if not util.is_valid_obj(human) then
        return nil
    end

    local numeric_job_id = tonumber(job_id)
    if numeric_job_id == nil then
        return nil
    end

    local ctrl_name = string.format("Job%02dActionCtrl", numeric_job_id)
    return field_first(human, string.format("<%s>k__BackingField", ctrl_name))
        or field_first(human, ctrl_name)
        or call_first(human, "get_" .. ctrl_name)
end

local function describe_candidate_values(values)
    local collected = {}
    for _, value in ipairs(values or {}) do
        if type(value) == "string" and value ~= "" then
            collected[#collected + 1] = value
        end
    end

    if #collected == 0 then
        return "none"
    end

    return table.concat(collected, ",")
end

local function read_action_ctrl_state_field(action_ctrl, field_name)
    if not util.is_valid_obj(action_ctrl) or type(field_name) ~= "string" or field_name == "" then
        return "nil"
    end

    return describe_value(
        field_first(action_ctrl, string.format("<%s>k__BackingField", field_name))
            or field_first(action_ctrl, field_name)
            or call_first(action_ctrl, "get_" .. field_name)
    )
end

local function capture_unsafe_skill_probe_snapshot(context, target_info, target_distance, contract)
    local snapshot = {
        contract = tostring(contract and contract.class or "nil"),
        contract_key = tostring(contract and contract.controller_snapshot_key or "nil"),
        node = tostring(context and context.full_node or "nil"),
        current = tostring(context and context.current_action_identity or "nil"),
        request = tostring(context and context.selected_request_identity or "nil"),
        decision = tostring(context and context.decision_pack_path or "nil"),
        target = tostring(target_info and util.describe_obj(target_info.character) or "nil"),
        distance = tostring(target_distance or "nil"),
    }

    local action_ctrl = get_job_action_ctrl(context, context and context.current_job)
    if util.is_valid_obj(action_ctrl) then
        snapshot.action_ctrl = util.describe_obj(action_ctrl)
    else
        snapshot.action_ctrl = "nil"
    end

    local parts = {
        string.format("contract=%s", tostring(snapshot.contract)),
        string.format("contract_key=%s", tostring(snapshot.contract_key)),
        string.format("node=%s", tostring(snapshot.node)),
        string.format("current=%s", tostring(snapshot.current)),
        string.format("request=%s", tostring(snapshot.request)),
        string.format("decision=%s", tostring(snapshot.decision)),
        string.format("target=%s", tostring(snapshot.target)),
        string.format("dist=%s", tostring(snapshot.distance)),
        string.format("ctrl=%s", tostring(snapshot.action_ctrl)),
    }

    for _, field_name in ipairs(contract and contract.controller_state_fields or {}) do
        parts[#parts + 1] = string.format(
            "%s=%s",
            tostring(field_name),
            tostring(read_action_ctrl_state_field(action_ctrl, field_name))
        )
    end

    return table.concat(parts, " ")
end

local function get_data(runtime)
    runtime.hybrid_combat_fix_data = runtime.hybrid_combat_fix_data or {
        enabled = false,
        apply_count = 0,
        fail_count = 0,
        skip_count = 0,
        observe_only_count = 0,
        last_status = "idle",
        last_reason = "idle",
        last_job = nil,
        last_profile_key = "nil",
        last_phase_key = "nil",
        last_phase_mode = "nil",
        last_phase_role = "nil",
        last_pack_path = "nil",
        last_action_name = "nil",
        last_target = "nil",
        last_target_type = "nil",
        last_target_distance = nil,
        last_output_signature = "nil",
        last_output_text_blob = "nil",
        last_apply_time = nil,
        last_effective_phase_score = nil,
        skill_streak_count = 0,
        last_failure_reason = "nil",
        last_failure_log_time = nil,
        last_observe_only_log_time = nil,
        last_observe_only_job = nil,
        last_phase_block_log_time = nil,
        last_phase_block_signature = "nil",
        last_allowed_phase_summary = "none",
        last_blocked_phase_summary = "none",
        last_skill_gate_summary = "none",
        last_selected_phase_note = "nil",
        last_attempt_summary = "none",
        methods = {
            exec_method = nil,
            reqmain_method = nil,
            skip_think_method = nil,
            skip_think_method_source = "unresolved",
        },
    }
    runtime.hybrid_combat_fix_data.enabled = fix_config().enabled == true
    return runtime.hybrid_combat_fix_data
end

local function set_status(data, status, reason)
    data.last_status = tostring(status or "idle")
    data.last_reason = tostring(reason or "idle")
end

local function ensure_methods(data)
    local methods = data.methods

    if methods.exec_method == nil then
        local extensions_td = util.safe_sdk_typedef("app.AIBlackBoardExtensions")
        if extensions_td ~= nil then
            local ok, method = pcall(function()
                return extensions_td:get_method(ACTINTER_EXECUTE_SIGNATURE)
            end)
            methods.exec_method = ok and method or nil
        end
    end

    if methods.reqmain_method == nil then
        local controller_td = util.safe_sdk_typedef("app.AIBlackBoardController")
        if controller_td ~= nil then
            local ok, method = pcall(function()
                return controller_td:get_method(ACTINTER_REQMAIN_SIGNATURE)
            end)
            methods.reqmain_method = ok and method or nil
        end
    end

    if methods.skip_think_method == nil then
        local decision_module_td = util.safe_sdk_typedef("app.DecisionEvaluationModule")
        if decision_module_td ~= nil then
            local ok, method = pcall(function()
                return decision_module_td:get_method(REQUEST_SKIP_THINK_SIGNATURE)
            end)
            if ok and method ~= nil then
                methods.skip_think_method = method
                methods.skip_think_method_source = "app.DecisionEvaluationModule"
            end
        end
    end

    if methods.skip_think_method == nil then
        local decision_module_td = util.safe_sdk_typedef("app.DecisionModule")
        if decision_module_td ~= nil then
            local ok, method = pcall(function()
                return decision_module_td:get_method(REQUEST_SKIP_THINK_SIGNATURE)
            end)
            if ok and method ~= nil then
                methods.skip_think_method = method
                methods.skip_think_method_source = "app.DecisionModule"
            end
        end
    end

    return methods
end

local function apply_carrier_bridge(data, context, pack_path, target_info)
    local pack_data = util.safe_create_userdata("app.ActInterPackData", pack_path)
    if pack_data == nil then
        return false, {
            reason = "actinter_pack_create_failed",
            pack_path = tostring(pack_path or "nil"),
        }
    end

    local ai_target = create_ai_target(target_info)
    if ai_target == nil then
        return false, {
            reason = "ai_target_create_failed",
            pack_path = tostring(pack_path or "nil"),
        }
    end

    local methods = ensure_methods(data)
    if methods.exec_method == nil or methods.reqmain_method == nil or not util.is_valid_obj(context.ai_blackboard) then
        return false, {
            reason = "carrier_methods_unresolved",
            pack_path = tostring(pack_path or "nil"),
            ai_target = util.describe_obj(ai_target),
            ai_target_type = util.get_type_full_name(ai_target) or "nil",
        }
    end

    local exec_ok, exec_err = pcall(function()
        methods.exec_method:call(nil, context.ai_blackboard, pack_data, ai_target)
    end)
    local reqmain_ok, reqmain_err = pcall(function()
        methods.reqmain_method:call(context.ai_blackboard, pack_data)
    end)

    local skip_think_ok = false
    local skip_think_err = nil
    if fix_config().request_skip_think == true
        and methods.skip_think_method ~= nil
        and util.is_valid_obj(context.decision_module) then
        skip_think_ok, skip_think_err = pcall(function()
            methods.skip_think_method:call(context.decision_module)
        end)
    end

    return exec_ok and reqmain_ok, {
        reason = exec_ok and reqmain_ok and "ok" or "carrier_bridge_call_failed",
        bridge_kind = "carrier",
        pack_path = tostring(pack_path or "nil"),
        ai_target = util.describe_obj(ai_target),
        ai_target_type = util.get_type_full_name(ai_target) or "nil",
        exec_ok = exec_ok,
        exec_err = tostring(exec_err),
        reqmain_ok = reqmain_ok,
        reqmain_err = tostring(reqmain_err),
        skip_think_ok = skip_think_ok,
        skip_think_err = tostring(skip_think_err),
        skip_think_method_source = tostring(methods.skip_think_method_source or "unresolved"),
    }
end

local function apply_action_bridge(context, action_name, action_layer, action_priority)
    if not util.is_valid_obj(context.action_manager) then
        return false, {
            reason = "action_manager_unresolved",
            bridge_kind = "action",
            action_name = tostring(action_name or "nil"),
        }
    end

    if type(action_name) ~= "string" or action_name == "" then
        return false, {
            reason = "action_name_unresolved",
            bridge_kind = "action",
            action_name = tostring(action_name or "nil"),
        }
    end

    local request_ok, request_err = pcall(function()
        context.action_manager:requestActionCore(
            tonumber(action_priority) or 0,
            action_name,
            tonumber(action_layer) or 0
        )
    end)

    return request_ok, {
        reason = request_ok and "ok" or "request_action_failed",
        bridge_kind = "action",
        action_name = tostring(action_name),
        action_layer = tonumber(action_layer) or 0,
        action_priority = tonumber(action_priority) or 0,
        request_ok = request_ok,
        request_err = tostring(request_err),
    }
end

local function collect_bridge_candidates(primary_value, extra_values)
    return execution_contracts.collect_named_candidates(primary_value, extra_values)
end

local function resolve_phase_execution_contract(phase_entry)
    return execution_contracts.resolve(phase_entry)
end

local function apply_phase_bridge(data, context, phase_entry, target_info, target_distance)
    local results = {}
    local success = false
    local selected_pack_path = nil
    local selected_action_name = nil
    local contract = resolve_phase_execution_contract(phase_entry)

    local pack_candidates = contract.carrier_candidates
    local action_candidates = contract.action_candidates
    local probe_mode = nil
    local probe_snapshot = nil

    if contract.probe_required then
        probe_mode = unsafe_skill_probe_mode()
        pack_candidates = #contract.probe_pack_candidates > 0 and contract.probe_pack_candidates or contract.carrier_candidates
        if probe_mode == "action_only" then
            pack_candidates = {}
        elseif probe_mode == "carrier_only" then
            action_candidates = {}
        end

        if fix_config().unsafe_skill_probe_log_details == true then
            probe_snapshot = capture_unsafe_skill_probe_snapshot(context, target_info, target_distance, contract)
            log.warn(string.format(
                "Hybrid unsafe skill probe job=%s phase=%s mode=%s packs=%s actions=%s snapshot=%s",
                tostring(context.current_job),
                tostring(phase_entry.key or "nil"),
                tostring(probe_mode),
                tostring(describe_candidate_values(pack_candidates)),
                tostring(describe_candidate_values(action_candidates)),
                tostring(probe_snapshot)
            ))
        end
    end

    local bridge_mode = tostring(contract.bridge_mode or "action_only")
    if probe_mode ~= nil and probe_mode ~= "off" then
        bridge_mode = probe_mode
    end

    if bridge_mode == "selector_owned" then
        return false, {
            reason = "selector_owned_contract_unimplemented",
            bridge_kind = "selector_owned",
            execution_contract_class = contract.class,
            execution_bridge_mode = bridge_mode,
            results = results,
        }
    end

    local function attempt_carriers()
        for _, pack_path in ipairs(pack_candidates) do
            local carrier_ok, carrier_info = apply_carrier_bridge(data, context, pack_path, target_info)
            carrier_info.pack_path = tostring(pack_path)
            results[#results + 1] = carrier_info
            if carrier_ok and selected_pack_path == nil then
                selected_pack_path = tostring(pack_path)
            end
            success = success or carrier_ok
        end
    end

    local function attempt_actions()
        for _, action_name in ipairs(action_candidates) do
            local action_ok, action_info = apply_action_bridge(
                context,
                action_name,
                phase_entry.action_layer,
                phase_entry.action_priority
            )
            action_info.action_name = tostring(action_name)
            results[#results + 1] = action_info
            if action_ok and selected_action_name == nil then
                selected_action_name = tostring(action_name)
            end
            success = success or action_ok
        end
    end

    if bridge_mode == "carrier_only" then
        attempt_carriers()
    elseif bridge_mode == "action_only" then
        attempt_actions()
    else
        attempt_carriers()
        attempt_actions()
    end

    if #results == 0 then
        return false, {
            reason = "phase_bridge_undefined",
            bridge_kind = "none",
            pack_path = tostring(phase_entry.pack_path or "nil"),
            action_name = tostring(phase_entry.action_name or "nil"),
            execution_contract_class = contract.class,
            execution_bridge_mode = bridge_mode,
            results = results,
        }
    end

    local failure_parts = {}
    for _, item in ipairs(results) do
        if tostring(item.reason or "ok") ~= "ok" then
            failure_parts[#failure_parts + 1] = string.format(
                "%s=%s",
                tostring(item.bridge_kind or "bridge"),
                tostring(item.reason or "failed")
            )
        end
    end

    return success, {
        reason = success and "ok" or table.concat(failure_parts, ","),
        bridge_kind = success and "hybrid" or "hybrid_failed",
        pack_path = tostring(selected_pack_path or phase_entry.pack_path or "nil"),
        action_name = tostring(selected_action_name or phase_entry.action_name or "nil"),
        execution_contract_class = contract.class,
        execution_bridge_mode = bridge_mode,
        probe_mode = tostring(probe_mode or "off"),
        probe_snapshot = probe_snapshot,
        results = results,
    }
end

local function build_output_texts(context)
    return {
        tostring(context.decision_pack_path or "nil"),
        tostring(context.current_action_identity or "nil"),
        tostring(context.selected_request_identity or "nil"),
        tostring(context.full_node or "nil"),
        tostring(context.upper_node or "nil"),
    }
end

local function build_output_text_blob(context)
    return table.concat(build_output_texts(context), " | ")
end

local function has_profile_output(context)
    return contains_any_text(build_output_text_blob(context), context.profile.output_tokens)
end

local function is_utility_locked_output(context)
    return contains_any_text(build_output_text_blob(context), UTILITY_TOKENS)
end

local function is_special_skip_output(context)
    return contains_any_text(build_output_text_blob(context), SPECIAL_SKIP_TOKENS)
end

local function describe_skill_ids(ids)
    local values = {}
    for _, value in ipairs(ids or {}) do
        values[#values + 1] = tostring(value)
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function get_collection_count(obj)
    if obj == nil then
        return nil
    end

    local count = util.safe_method(obj, "get_Count()")
        or util.safe_method(obj, "get_count()")
        or util.safe_method(obj, "get_Size()")
        or util.safe_method(obj, "get_size()")
        or field_first(obj, "Count")
        or field_first(obj, "count")
        or field_first(obj, "_size")
        or field_first(obj, "size")

    return tonumber(count)
end

local function get_collection_item(obj, index)
    if obj == nil then
        return nil
    end

    local item = util.safe_method(obj, "get_Item(System.Int32)", index)
        or util.safe_method(obj, "get_Item(System.UInt32)", index)
        or util.safe_method(obj, "get_Item", index)
    if item ~= nil then
        return item
    end

    local ok, raw_item = pcall(function()
        return obj[index]
    end)
    return ok and raw_item or nil
end

local function resolve_job_equip_list(skill_context, job_id)
    if skill_context == nil or job_id == nil then
        return nil
    end

    local equip_list = util.safe_direct_method(skill_context, "getEquipList", job_id)
        or util.safe_method(skill_context, "getEquipList(System.Int32)", job_id)
        or util.safe_method(skill_context, "getEquipList(app.Character.JobEnum)", job_id)
        or util.safe_method(skill_context, "getEquipList", job_id)
    if is_present_value(equip_list) then
        return equip_list
    end

    local equipped_root = present_field(skill_context, EQUIPPED_SKILLS_FIELDS)
    local indexed = get_collection_item(equipped_root, job_id)
    if is_present_value(indexed) then
        return indexed
    end

    local indexed_minus_one = get_collection_item(equipped_root, job_id - 1)
    if is_present_value(indexed_minus_one) then
        return indexed_minus_one
    end

    return nil
end

local function build_equipped_skill_snapshot(skill_context, job_id)
    local equipped_skill_ids = {}
    local equipped_skill_map = {}

    local equip_list = resolve_job_equip_list(skill_context, job_id)
    local skills_root = present_field(equip_list, SKILLS_LIST_FIELDS)
    local skill_count = get_collection_count(skills_root)
    local max_slots = skill_count ~= nil and math.min(skill_count, 8) or 4

    for slot = 0, max_slots - 1 do
        local item = get_collection_item(skills_root, slot)
        local skill_id = decode_small_int(item)
        if skill_id == nil then
            skill_id = decode_small_int(field_first(item, "value__"))
        end
        if skill_id ~= nil and skill_id ~= 0 and not equipped_skill_map[skill_id] then
            equipped_skill_map[skill_id] = true
            equipped_skill_ids[#equipped_skill_ids + 1] = skill_id
        end
    end

    table.sort(equipped_skill_ids)
    return equipped_skill_ids, equipped_skill_map
end

local function describe_required_skill_cache(cache)
    local skill_ids = {}
    for skill_id, _ in pairs(cache or {}) do
        skill_ids[#skill_ids + 1] = skill_id
    end

    table.sort(skill_ids)

    local values = {}
    for _, skill_id in ipairs(skill_ids) do
        local item = cache[skill_id] or {}
        values[#values + 1] = string.format(
            "%s(eq=%s,list=%s,en=%s,av=%s)",
            tostring(skill_id),
            tostring(item.equipped),
            tostring(item.listed),
            tostring(item.enabled),
            tostring(item.available)
        )
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function resolve_current_job_level(runtime, context)
    local progression = runtime.progression_state_data and runtime.progression_state_data.main_pawn or nil
    if progression ~= nil then
        local direct = decode_small_int(progression.current_job_level)
        if direct ~= nil then
            return direct, "progression.current_job_level"
        end

        local key = context.profile and context.profile.key or nil
        local job_item = key and progression.job_diagnostic_table and progression.job_diagnostic_table[key] or nil
        local item_level = job_item and decode_small_int(job_item.job_level) or nil
        if item_level ~= nil then
            return item_level, "progression.job_diagnostic_table"
        end
    end

    local current_job = decode_small_int(context.current_job)
    if current_job ~= nil and context.profile ~= nil then
        return 0, "assumed_minimum_job_level"
    end

    return nil, "unresolved"
end

local function call_has_equipped_skill(skill_context, job_id, skill_id)
    if skill_context == nil or job_id == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_context, "hasEquipedSkill", job_id, skill_id)
        or util.safe_method(skill_context, "hasEquipedSkill(app.Character.JobEnum, app.HumanCustomSkillID)", job_id, skill_id)
        or util.safe_method(skill_context, "hasEquipedSkill", job_id, skill_id)
end

local function call_is_custom_skill_enable(skill_context, skill_id)
    if skill_context == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_context, "isCustomSkillEnable", skill_id)
        or util.safe_method(skill_context, "isCustomSkillEnable(app.HumanCustomSkillID)", skill_id)
        or util.safe_method(skill_context, "isCustomSkillEnable", skill_id)
end

local function call_is_custom_skill_available(skill_availability, skill_id)
    if skill_availability == nil or skill_id == nil then
        return nil
    end

    return util.safe_direct_method(skill_availability, "isCustomSkillAvailable", skill_id)
        or util.safe_method(skill_availability, "isCustomSkillAvailable(app.HumanCustomSkillID)", skill_id)
        or util.safe_method(skill_availability, "isCustomSkillAvailable", skill_id)
end

local function build_skill_gate_state(runtime, context)
    local progression = runtime.progression_state_data and runtime.progression_state_data.main_pawn or nil
    local skill_context = progression and progression.skill_context or context.main_pawn.skill_context or nil
    local equipped_skill_ids, equipped_skill_map = build_equipped_skill_snapshot(skill_context, context.current_job)
    local current_job_level, current_job_level_source = resolve_current_job_level(runtime, context)
    return {
        current_job = context.current_job,
        current_job_level = current_job_level,
        current_job_level_source = current_job_level_source,
        skill_context = skill_context,
        skill_availability = progression and progression.skill_availability or nil,
        custom_skill_state = progression and progression.custom_skill_state or context.main_pawn.skill_state or nil,
        equipped_skill_ids = equipped_skill_ids,
        equipped_skill_map = equipped_skill_map,
        required_skill_state_cache = {},
    }
end

local function resolve_required_skill_state(gate_state, required_skill_id)
    if required_skill_id == nil then
        return {
            listed = nil,
            equipped = nil,
            enabled = nil,
            available = nil,
        }
    end

    local cache = gate_state.required_skill_state_cache or {}
    gate_state.required_skill_state_cache = cache

    if cache[required_skill_id] ~= nil then
        return cache[required_skill_id]
    end

    local listed = gate_state.equipped_skill_map[required_skill_id] == true
    local equipped = decode_truthy(call_has_equipped_skill(gate_state.skill_context, gate_state.current_job, required_skill_id))
    if equipped == nil then
        equipped = listed
    end

    local item = {
        listed = listed,
        equipped = equipped,
        enabled = decode_truthy(call_is_custom_skill_enable(gate_state.skill_context, required_skill_id)),
        available = decode_truthy(call_is_custom_skill_available(gate_state.skill_availability, required_skill_id)),
    }

    cache[required_skill_id] = item
    return item
end

local function evaluate_phase_gate(phase_entry, gate_state)
    local contract = resolve_phase_execution_contract(phase_entry)
    local meta = {
        phase_key = tostring(phase_entry.key or "nil"),
        execution_contract_class = tostring(contract.class or "nil"),
        execution_bridge_mode = tostring(contract.bridge_mode or "nil"),
        current_job_level = gate_state.current_job_level,
        required_skill_name = tostring(phase_entry.required_skill_name or "nil"),
        required_skill_id = decode_small_int(phase_entry.required_skill_id),
        skill_context = util.describe_obj(gate_state.skill_context),
        skill_availability = util.describe_obj(gate_state.skill_availability),
        equipped_skill_ids = describe_skill_ids(gate_state.equipped_skill_ids),
    }

    local min_job_level = decode_small_int(phase_entry.min_job_level)
    if min_job_level ~= nil then
        if gate_state.current_job_level == nil then
            return false, "job_level_unresolved", meta
        end
        if gate_state.current_job_level < min_job_level then
            local level_reason = tostring(gate_state.current_job_level_source or "unresolved") == "assumed_minimum_job_level"
                and "job_level_above_assumed_minimum"
                or "job_level_too_low"
            return false, level_reason, meta
        end
    end

    if contract.class == "selector_owned" then
        return false, "selector_owned_contract_unimplemented", meta
    end

    if contract.probe_required and unsafe_skill_probe_mode() == "off" then
        return false, "unsafe_probe_disabled", meta
    end

    if contract.probe_required and not execution_contracts.supports_probe_mode(contract, unsafe_skill_probe_mode()) then
        return false, "unsupported_probe_mode", meta
    end

    local max_job_level = decode_small_int(phase_entry.max_job_level)
    if max_job_level ~= nil and gate_state.current_job_level ~= nil and gate_state.current_job_level > max_job_level then
        return false, "job_level_too_high", meta
    end

    local requires_equipped = phase_entry.requires_equipped_skill == true
    local requires_enabled = phase_entry.requires_enabled_skill == true
    local requires_available = phase_entry.requires_available_skill == true
    if fix_config().enforce_skill_loadout_gate ~= true or (not requires_equipped and not requires_enabled and not requires_available) then
        return true, "phase_gate_passed", meta
    end

    local required_skill_id = meta.required_skill_id
    if required_skill_id == nil then
        if phase_entry.block_if_unmapped == false or fix_config().allow_unmapped_skill_phases == true then
            return true, "skill_mapping_unresolved_but_allowed", meta
        end

        return false, "skill_mapping_unresolved", meta
    end

    local skill_state = resolve_required_skill_state(gate_state, required_skill_id)
    meta.required_skill_listed = skill_state.listed
    meta.required_skill_equipped = skill_state.equipped
    meta.required_skill_enabled = skill_state.enabled
    meta.required_skill_available = skill_state.available

    if requires_equipped then
        if skill_state.equipped ~= true then
            return false, "skill_not_equipped", meta
        end
    end

    if requires_enabled then
        if skill_state.enabled ~= nil and skill_state.enabled ~= true then
            return false, "skill_not_enabled", meta
        end
    end

    if requires_available then
        if skill_state.available ~= nil and skill_state.available ~= true then
            return false, "skill_not_available", meta
        end
    end

    return true, "skill_gate_passed", meta
end

local function collect_phase_candidates(profile, target_distance)
    local candidates = {}
    for _, phase in ipairs(profile.phases or {}) do
        local min_distance = tonumber(phase.min_distance) or 0.0
        local max_distance = tonumber(phase.max_distance)
        local in_range = type(target_distance) == "number" and target_distance >= min_distance
        if in_range and max_distance ~= nil then
            in_range = target_distance <= max_distance
        end
        if in_range then
            candidates[#candidates + 1] = phase
        end
    end

    return candidates
end

local function filter_phase_candidates(candidates, gate_state)
    local allowed = {}
    local blocked = {}

    for _, phase in ipairs(candidates or {}) do
        local gate_ok, gate_reason, gate_meta = evaluate_phase_gate(phase, gate_state)
        if gate_ok then
            allowed[#allowed + 1] = phase
        else
            blocked[#blocked + 1] = {
                key = tostring(phase.key or "nil"),
                reason = tostring(gate_reason or "blocked"),
                required_skill_name = gate_meta and gate_meta.required_skill_name or "nil",
                required_skill_id = gate_meta and gate_meta.required_skill_id or nil,
                min_job_level = phase.min_job_level,
            }
        end
    end

    return allowed, blocked
end

local function resolve_phase_selection_role(phase)
    return tostring(phase and phase.selection_role or phase and phase.mode or "unknown")
end

local function get_distance_bucket(target_distance)
    local distance = tonumber(target_distance)
    if distance == nil then
        return "unknown"
    end
    if distance <= 2.25 then
        return "close"
    end
    if distance <= 4.25 then
        return "mid"
    end
    return "far"
end

local function get_effective_skill_streak(data, now)
    local streak = tonumber(data and data.skill_streak_count) or 0
    local last_apply_time = tonumber(data and data.last_apply_time)
    local current_time = tonumber(now)
    if streak <= 0 or last_apply_time == nil or current_time == nil then
        return 0
    end
    if (current_time - last_apply_time) > 3.5 then
        return 0
    end
    return streak
end

local function compute_phase_selection_score(phase, gate_state, data, target_distance, now)
    local score = tonumber(phase and phase.priority) or 0
    local role = resolve_phase_selection_role(phase)
    local bucket = get_distance_bucket(target_distance)
    local level_source = tostring(gate_state and gate_state.current_job_level_source or "unresolved")
    local last_phase_key = tostring(data and data.last_phase_key or "nil")
    local last_phase_mode = tostring(data and data.last_phase_mode or "nil")
    local last_phase_role = tostring(data and data.last_phase_role or "nil")
    local effective_skill_streak = get_effective_skill_streak(data, now)

    if role == "basic_attack" then
        score = score + 24
    elseif role == "engage_basic" then
        score = score + 20
    elseif role == "gapclose" then
        score = score + 18
    elseif role == "core_advanced" then
        score = score + 10
    elseif role == "gapclose_skill" then
        score = score + 8
    elseif role == "melee_skill" then
        score = score + 6
    elseif role == "ranged_skill" then
        score = score + 4
    elseif role == "defense_skill" then
        score = score + 2
    end

    if bucket == "close" then
        if role == "basic_attack" then
            score = score + 18
        elseif role == "engage_basic" then
            score = score + 14
        elseif role == "core_advanced" then
            score = score + 8
        elseif role == "melee_skill" then
            score = score - 6
        elseif role == "ranged_skill" then
            score = score - 28
        elseif role == "gapclose" then
            score = score - 14
        elseif role == "gapclose_skill" then
            score = score - 12
        elseif role == "defense_skill" then
            score = score - 4
        end
    elseif bucket == "mid" then
        if role == "basic_attack" then
            score = score + 10
        elseif role == "engage_basic" then
            score = score + 12
        elseif role == "core_advanced" then
            score = score + 14
        elseif role == "melee_skill" then
            score = score + 2
        elseif role == "ranged_skill" then
            score = score - 6
        elseif role == "gapclose" then
            score = score + 4
        elseif role == "gapclose_skill" then
            score = score + 6
        end
    elseif bucket == "far" then
        if role == "gapclose" then
            score = score + 20
        elseif role == "gapclose_skill" then
            score = score + 16
        elseif role == "ranged_skill" then
            score = score + 10
        elseif role == "basic_attack" then
            score = score - 30
        elseif role == "engage_basic" then
            score = score - 16
        elseif role == "melee_skill" then
            score = score - 20
        elseif role == "defense_skill" then
            score = score - 10
        elseif role == "core_advanced" then
            score = score - 8
        end
    end

    if level_source == "assumed_minimum_job_level" then
        if role == "basic_attack" or role == "engage_basic" or role == "gapclose" then
            score = score + 14
        elseif tostring(phase and phase.mode or "nil") == "skill" then
            score = score - 18
        elseif role == "core_advanced" then
            score = score + 4
        end
    end

    if last_phase_key == tostring(phase and phase.key or "nil") then
        score = score - 12
    end

    if effective_skill_streak > 0 and tostring(phase and phase.mode or "nil") == "skill" then
        score = score - (effective_skill_streak * 18)
    end

    if last_phase_mode == "skill" and (role == "basic_attack" or role == "engage_basic" or role == "gapclose") then
        score = score + 16
    elseif (last_phase_role == "basic_attack" or last_phase_role == "engage_basic" or last_phase_role == "gapclose")
        and tostring(phase and phase.mode or "nil") == "skill" then
        score = score + 8
    end

    if last_phase_role == role and role ~= "unknown" then
        score = score - 6
    end

    return score
end

local function sort_allowed_phase_candidates(candidates, gate_state, data, target_distance, now)
    for _, phase in ipairs(candidates or {}) do
        phase.selection_role = resolve_phase_selection_role(phase)
        phase.selection_score = compute_phase_selection_score(phase, gate_state, data, target_distance, now)
    end

    table.sort(candidates, function(left, right)
        local left_score = tonumber(left.selection_score) or 0
        local right_score = tonumber(right.selection_score) or 0
        if left_score ~= right_score then
            return left_score > right_score
        end

        local left_priority = tonumber(left.priority) or 0
        local right_priority = tonumber(right.priority) or 0
        if left_priority ~= right_priority then
            return left_priority > right_priority
        end

        return tostring(left.key or "") < tostring(right.key or "")
    end)

    return candidates
end

local function describe_phase_candidates(candidates)
    local values = {}
    for _, phase in ipairs(candidates or {}) do
        local contract = resolve_phase_execution_contract(phase)
        values[#values + 1] = string.format(
            "%s:%s:%s:%s:%s:lvl%s:prio%s:score%s",
            tostring(phase.key or "nil"),
            tostring(phase.mode or "nil"),
            tostring(resolve_phase_selection_role(phase)),
            tostring(contract.class or "nil"),
            tostring(contract.bridge_mode or "nil"),
            tostring(phase.min_job_level or 0),
            tostring(phase.priority or 0),
            tostring(phase.selection_score or "nil")
        )
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function describe_blocked_phases(blocked)
    local values = {}
    for _, phase in ipairs(blocked or {}) do
        local contract = resolve_phase_execution_contract(phase)
        values[#values + 1] = string.format(
            "%s:%s:%s:%s:%s",
            tostring(phase.key or "nil"),
            tostring(phase.reason or "blocked"),
            tostring(contract.class or "nil"),
            tostring(phase.required_skill_name or "nil"),
            tostring(phase.min_job_level or "nil")
        )
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function apply_phase_summaries(data, selected_phase, allowed_phase_candidates, blocked_phase_candidates, gate_state)
    data.last_allowed_phase_summary = describe_phase_candidates(allowed_phase_candidates)
    data.last_blocked_phase_summary = describe_blocked_phases(blocked_phase_candidates)
    data.last_skill_gate_summary = describe_required_skill_cache(gate_state and gate_state.required_skill_state_cache)
    data.last_selected_phase_note = selected_phase ~= nil and tostring(selected_phase.note or "nil") or "nil"
end

local function describe_attempt_results(results)
    local values = {}
    for _, item in ipairs(results or {}) do
        values[#values + 1] = string.format(
            "%s:%s:%s:%s:%s",
            tostring(item.key or "nil"),
            tostring(item.reason or "nil"),
            tostring(item.bridge or "nil"),
            tostring(item.contract or "nil"),
            tostring(item.bridge_mode or "nil")
        )
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function build_output_signature(context, target, phase_key)
    return table.concat({
        tostring(context.current_job or "nil"),
        tostring(context.decision_pack_path or "nil"),
        tostring(context.current_action_identity or "nil"),
        tostring(context.selected_request_identity or "nil"),
        tostring(context.full_node or "nil"),
        tostring(context.upper_node or "nil"),
        tostring(util.get_address(target) or "nil"),
        tostring(phase_key or "nil"),
    }, " | ")
end

local function maybe_log_phase_blocked(data, context, gate_state, phase_candidates, blocked_phase_candidates, target_distance)
    local now = tonumber(state.runtime.game_time or os.clock()) or 0.0
    local interval = tonumber(fix_config().phase_blocked_log_interval_seconds) or 5.0
    local signature = table.concat({
        tostring(context.current_job or "nil"),
        tostring(target_distance or "nil"),
        tostring(describe_phase_candidates(phase_candidates)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(describe_required_skill_cache(gate_state and gate_state.required_skill_state_cache)),
        tostring(data.last_output_text_blob or "nil"),
    }, " | ")

    if data.last_phase_block_signature == signature
        and data.last_phase_block_log_time ~= nil
        and (now - data.last_phase_block_log_time) < interval then
        return
    end

    data.last_phase_block_signature = signature
    data.last_phase_block_log_time = now

    log.info(string.format(
        "Hybrid combat fix blocked job=%s profile=%s lvl=%s src=%s dist=%s candidates=%s blocked=%s skills=%s output=%s",
        tostring(context.current_job),
        tostring(context.profile and context.profile.key or "nil"),
        tostring(gate_state and gate_state.current_job_level or "nil"),
        tostring(gate_state and gate_state.current_job_level_source or "nil"),
        tostring(target_distance),
        tostring(describe_phase_candidates(phase_candidates)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(describe_required_skill_cache(gate_state and gate_state.required_skill_state_cache)),
        tostring(data.last_output_text_blob or "nil")
    ))
end

local function maybe_log_phase_attempt_failure(data, context, gate_state, attempted_results, blocked_phase_candidates, target_distance)
    local now = tonumber(state.runtime.game_time or os.clock()) or 0.0
    local interval = tonumber(fix_config().phase_blocked_log_interval_seconds) or 5.0
    local signature = table.concat({
        tostring(context.current_job or "nil"),
        tostring(target_distance or "nil"),
        tostring(describe_attempt_results(attempted_results)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(describe_required_skill_cache(gate_state and gate_state.required_skill_state_cache)),
        tostring(data.last_output_text_blob or "nil"),
    }, " | ")

    if data.last_phase_block_signature == signature
        and data.last_phase_block_log_time ~= nil
        and (now - data.last_phase_block_log_time) < interval then
        return
    end

    data.last_phase_block_signature = signature
    data.last_phase_block_log_time = now

    log.warn(string.format(
        "Hybrid combat fix attempted but all phases failed job=%s profile=%s lvl=%s src=%s dist=%s attempts=%s blocked=%s skills=%s output=%s",
        tostring(context.current_job),
        tostring(context.profile and context.profile.key or "nil"),
        tostring(gate_state and gate_state.current_job_level or "nil"),
        tostring(gate_state and gate_state.current_job_level_source or "nil"),
        tostring(target_distance),
        tostring(describe_attempt_results(attempted_results)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(describe_required_skill_cache(gate_state and gate_state.required_skill_state_cache)),
        tostring(data.last_output_text_blob or "nil")
    ))
end

local function should_log_failure(data, reason, now)
    local failure_reason = tostring(reason or "nil")
    if data.last_failure_reason ~= failure_reason then
        data.last_failure_reason = failure_reason
        data.last_failure_log_time = now
        return true
    end

    if data.last_failure_log_time == nil or (now - data.last_failure_log_time) >= 5.0 then
        data.last_failure_log_time = now
        return true
    end

    return false
end

local function maybe_log_observe_only(data, context, target_distance)
    local now = tonumber(state.runtime.game_time or os.clock()) or 0.0
    local interval = tonumber(fix_config().observe_only_log_interval_seconds) or 6.0
    if data.last_observe_only_job == context.current_job
        and data.last_observe_only_log_time ~= nil
        and (now - data.last_observe_only_log_time) < interval then
        return
    end

    data.observe_only_count = data.observe_only_count + 1
    data.last_observe_only_job = context.current_job
    data.last_observe_only_log_time = now
    log.info(string.format(
        "Hybrid combat profile pending job=%s profile=%s current=%s action=%s request=%s node=%s dist=%s",
        tostring(context.current_job),
        tostring(context.profile and context.profile.key or "nil"),
        tostring(context.decision_pack_path or "nil"),
        tostring(context.current_action_identity or "nil"),
        tostring(context.selected_request_identity or "nil"),
        tostring(context.full_node or "nil"),
        tostring(target_distance)
    ))
end

function hybrid_combat_fix.update()
    local runtime = state.runtime
    local data = get_data(runtime)
    if fix_config().enabled ~= true then
        set_status(data, "disabled", "config_disabled")
        return data
    end

    local context, context_reason = resolve_context(runtime)
    if context == nil then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", context_reason)
        return data
    end

    data.last_job = context.current_job
    data.last_profile_key = tostring(context.profile and context.profile.key or "nil")
    data.last_output_text_blob = build_output_text_blob(context)

    if has_profile_output(context) then
        set_status(data, "native_hybrid_output", "job_output_already_present")
        return data
    end

    if is_special_skip_output(context) then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "special_output_state")
        return data
    end

    local target_info, target_reason = resolve_decision_target(context.executing_decision)
    local target = target_info and target_info.character or nil
    local target_distance = util.is_valid_obj(target) and compute_distance(context.runtime_character, target) or nil

    if context.profile.active ~= true then
        set_status(data, "observe_only", context.profile.pending_reason or "profile_pending_research")
        if is_utility_locked_output(context) then
            maybe_log_observe_only(data, context, target_distance)
        end
        return data
    end

    if not is_utility_locked_output(context) then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "output_not_in_confirmed_utility_state")
        return data
    end

    if not util.is_valid_obj(context.decision_module) or not util.is_valid_obj(context.ai_blackboard) then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "decision_bridge_context_unresolved")
        return data
    end

    if type(target_info) ~= "table" or not util.is_valid_obj(target) then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", target_reason)
        return data
    end

    if not util.is_valid_obj(target_info.game_object) then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "target_game_object_unresolved")
        return data
    end

    if util.same_object(target, context.runtime_character)
        or util.same_object(target, runtime.player) then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "invalid_target_identity")
        return data
    end

    local gate_state = build_skill_gate_state(runtime, context)
    local phase_candidates = collect_phase_candidates(context.profile, target_distance)
    local allowed_phase_candidates, blocked_phase_candidates = filter_phase_candidates(phase_candidates, gate_state)
    local selected_phase = nil
    local bridge_info = nil
    local attempted_results = {}

    local now = tonumber(runtime.game_time or os.clock()) or 0.0
    if #allowed_phase_candidates > 0 then
        allowed_phase_candidates = sort_allowed_phase_candidates(allowed_phase_candidates, gate_state, data, target_distance, now)
    end
    apply_phase_summaries(data, nil, allowed_phase_candidates, blocked_phase_candidates, gate_state)

    if #allowed_phase_candidates == 0 then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", #blocked_phase_candidates > 0 and "phase_blocked" or "phase_unresolved")
        if #phase_candidates > 0 then
            maybe_log_phase_blocked(data, context, gate_state, phase_candidates, blocked_phase_candidates, target_distance)
        end
        return data
    end

    for _, phase_entry in ipairs(allowed_phase_candidates) do
        local output_signature = build_output_signature(context, target, phase_entry.key)
        local cooldown_seconds = tonumber(phase_entry.cooldown_seconds) or tonumber(fix_config().cooldown_seconds) or 2.5

        if data.last_output_signature == output_signature
            and data.last_apply_time ~= nil
            and (now - data.last_apply_time) < cooldown_seconds then
            attempted_results[#attempted_results + 1] = {
                key = tostring(phase_entry.key or "nil"),
                reason = "cooldown_active",
                bridge = "skipped",
                contract = tostring(phase_entry.execution_contract_class or "nil"),
                bridge_mode = tostring(phase_entry.execution_bridge_mode or "nil"),
            }
        else
            local bridge_ok, candidate_bridge_info = apply_phase_bridge(data, context, phase_entry, target_info, target_distance)
            attempted_results[#attempted_results + 1] = {
                key = tostring(phase_entry.key or "nil"),
                reason = tostring(candidate_bridge_info and candidate_bridge_info.reason or "phase_bridge_failed"),
                bridge = tostring(candidate_bridge_info and candidate_bridge_info.bridge_kind or "nil"),
                contract = tostring(candidate_bridge_info and candidate_bridge_info.execution_contract_class or phase_entry.execution_contract_class or "nil"),
                bridge_mode = tostring(candidate_bridge_info and candidate_bridge_info.execution_bridge_mode or phase_entry.execution_bridge_mode or "nil"),
            }

            if bridge_ok then
                selected_phase = phase_entry
                bridge_info = candidate_bridge_info
                data.last_output_signature = output_signature
                break
            end
        end
    end

    data.last_attempt_summary = describe_attempt_results(attempted_results)
    apply_phase_summaries(data, selected_phase, allowed_phase_candidates, blocked_phase_candidates, gate_state)

    if selected_phase == nil then
        local had_bridge_failure = false
        local had_attempt_skip = false
        for _, item in ipairs(attempted_results) do
            if item.bridge == "hybrid_failed" then
                had_bridge_failure = true
            elseif item.bridge == "skipped" then
                had_attempt_skip = true
            end
        end

        if had_bridge_failure then
            data.fail_count = data.fail_count + 1
            set_status(data, "failed", "all_allowed_phase_bridges_failed")
            maybe_log_phase_attempt_failure(data, context, gate_state, attempted_results, blocked_phase_candidates, target_distance)
        else
            data.skip_count = data.skip_count + 1
            set_status(data, "skipped", had_attempt_skip and "phase_attempts_skipped" or "phase_bridge_unresolved")
        end
        return data
    end

    if not (bridge_info and tostring(bridge_info.reason or "ok") == "ok") then
        data.fail_count = data.fail_count + 1
        set_status(data, "failed", bridge_info and bridge_info.reason or "phase_bridge_failed")
        if should_log_failure(data, data.last_reason, now) then
            log.warn(string.format(
                "Hybrid combat fix failed job=%s profile=%s phase=%s contract=%s bridge_mode=%s reason=%s pack=%s action=%s current=%s target=%s attempts=%s",
                tostring(context.current_job),
                tostring(context.profile.key),
                tostring(selected_phase.key),
                tostring(bridge_info and bridge_info.execution_contract_class or selected_phase.execution_contract_class or "nil"),
                tostring(bridge_info and bridge_info.execution_bridge_mode or selected_phase.execution_bridge_mode or "nil"),
                tostring(data.last_reason),
                tostring(bridge_info and bridge_info.pack_path or selected_phase.pack_path or "nil"),
                tostring(bridge_info and bridge_info.action_name or selected_phase.action_name or "nil"),
                tostring(context.decision_pack_path or "nil"),
                tostring(util.describe_obj(target)),
                tostring(data.last_attempt_summary)
            ))
        end
        return data
    end

    data.apply_count = data.apply_count + 1
    data.last_apply_time = now
    data.last_phase_key = tostring(selected_phase.key or "nil")
    data.last_phase_mode = tostring(selected_phase.mode or "nil")
    data.last_phase_role = tostring(resolve_phase_selection_role(selected_phase))
    data.last_execution_contract_class = tostring(bridge_info and bridge_info.execution_contract_class or selected_phase.execution_contract_class or "nil")
    data.last_execution_bridge_mode = tostring(bridge_info and bridge_info.execution_bridge_mode or selected_phase.execution_bridge_mode or "nil")
    data.last_pack_path = tostring(bridge_info and bridge_info.pack_path or selected_phase.pack_path or "nil")
    data.last_action_name = tostring(bridge_info and bridge_info.action_name or selected_phase.action_name or "nil")
    data.last_target = util.describe_obj(target)
    data.last_target_type = util.get_type_full_name(target) or "nil"
    data.last_target_distance = target_distance
    data.last_effective_phase_score = tonumber(selected_phase.selection_score)
    if tostring(selected_phase.mode or "nil") == "skill" then
        data.skill_streak_count = get_effective_skill_streak(data, now) + 1
    else
        data.skill_streak_count = 0
    end
    set_status(data, "applied", "utility_output_bridged_to_hybrid_profile")

    log.info(string.format(
        "Hybrid combat fix applied job=%s profile=%s phase=%s mode=%s contract=%s bridge_mode=%s lvl=%s src=%s pack=%s action=%s current=%s dist=%s target=%s allowed=%s blocked=%s attempts=%s skills=%s",
        tostring(context.current_job),
        tostring(context.profile.key),
        tostring(selected_phase.key),
        tostring(selected_phase.mode or "nil"),
        tostring(data.last_execution_contract_class or "nil"),
        tostring(data.last_execution_bridge_mode or "nil"),
        tostring(gate_state.current_job_level),
        tostring(gate_state.current_job_level_source or "nil"),
        tostring(bridge_info and bridge_info.pack_path or selected_phase.pack_path or "nil"),
        tostring(bridge_info and bridge_info.action_name or selected_phase.action_name or "nil"),
        tostring(context.decision_pack_path or "nil"),
        tostring(target_distance),
        tostring(data.last_target),
        tostring(describe_phase_candidates(allowed_phase_candidates)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(data.last_attempt_summary),
        tostring(data.last_skill_gate_summary ~= "none" and data.last_skill_gate_summary or describe_skill_ids(gate_state.equipped_skill_ids))
    ))

    return data
end

return hybrid_combat_fix
