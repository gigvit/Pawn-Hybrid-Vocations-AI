local config = require("PawnHybridVocationsAI/config")
local state = require("PawnHybridVocationsAI/state")
local log = require("PawnHybridVocationsAI/core/log")
local util = require("PawnHybridVocationsAI/core/util")
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

    return target, "executing_decision_target"
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

local function create_ai_target(target)
    if not util.is_valid_obj(target) then
        return nil
    end

    local ok, ai_target = pcall(sdk.create_instance, "app.AITargetGameObject", true)
    if not ok or ai_target == nil then
        return nil
    end

    local game_object = call_first(target, "get_GameObject")
    util.safe_set_field(ai_target, "<GameObject>k__BackingField", game_object)
    util.safe_set_field(ai_target, "<Character>k__BackingField", target)
    util.safe_set_field(ai_target, "<Owner>k__BackingField", game_object)
    util.safe_set_field(ai_target, "<OwnerCharacter>k__BackingField", target)
    util.safe_set_field(ai_target, "<ContextHolder>k__BackingField", call_first(target, "get_Context"))
    util.safe_set_field(ai_target, "<Transform>k__BackingField", call_first(target, "get_Transform"))
    return ai_target
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
        last_pack_path = "nil",
        last_target = "nil",
        last_target_type = "nil",
        last_target_distance = nil,
        last_output_signature = "nil",
        last_apply_time = nil,
        last_failure_reason = "nil",
        last_failure_log_time = nil,
        last_observe_only_log_time = nil,
        last_observe_only_job = nil,
        last_blocked_phase_summary = "none",
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

local function apply_carrier_bridge(data, context, pack_path, target)
    local pack_data = util.safe_create_userdata("app.ActInterPackData", pack_path)
    if pack_data == nil then
        return false, {
            reason = "actinter_pack_create_failed",
            pack_path = tostring(pack_path or "nil"),
        }
    end

    local ai_target = create_ai_target(target)
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

local function build_output_texts(context)
    return {
        tostring(context.decision_pack_path or "nil"),
        tostring(context.current_action_identity or "nil"),
        tostring(context.selected_request_identity or "nil"),
        tostring(context.full_node or "nil"),
        tostring(context.upper_node or "nil"),
    }
end

local function has_profile_output(context)
    return contains_any_text(table.concat(build_output_texts(context), " | "), context.profile.output_tokens)
end

local function is_utility_locked_output(context)
    return contains_any_text(table.concat(build_output_texts(context), " | "), UTILITY_TOKENS)
end

local function is_special_skip_output(context)
    return contains_any_text(table.concat(build_output_texts(context), " | "), SPECIAL_SKIP_TOKENS)
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

local function resolve_current_job_level(runtime, context)
    local progression = runtime.progression_state_data and runtime.progression_state_data.main_pawn or nil
    if progression ~= nil then
        local direct = decode_small_int(progression.current_job_level)
        if direct ~= nil then
            return direct
        end

        local key = context.profile and context.profile.key or nil
        local job_item = key and progression.job_diagnostic_table and progression.job_diagnostic_table[key] or nil
        local item_level = job_item and decode_small_int(job_item.job_level) or nil
        if item_level ~= nil then
            return item_level
        end
    end

    return nil
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
    return {
        current_job = context.current_job,
        current_job_level = resolve_current_job_level(runtime, context),
        skill_context = skill_context,
        skill_availability = progression and progression.skill_availability or nil,
        custom_skill_state = progression and progression.custom_skill_state or context.main_pawn.skill_state or nil,
        equipped_skill_ids = equipped_skill_ids,
        equipped_skill_map = equipped_skill_map,
    }
end

local function evaluate_phase_gate(phase_entry, gate_state)
    local meta = {
        phase_key = tostring(phase_entry.key or "nil"),
        current_job_level = gate_state.current_job_level,
        required_skill_name = tostring(phase_entry.required_skill_name or "nil"),
        required_skill_id = decode_small_int(phase_entry.required_skill_id),
        skill_context = util.describe_obj(gate_state.skill_context),
        skill_availability = util.describe_obj(gate_state.skill_availability),
        equipped_skill_ids = describe_skill_ids(gate_state.equipped_skill_ids),
    }

    local min_job_level = decode_small_int(phase_entry.min_job_level)
    if min_job_level ~= nil and (gate_state.current_job_level == nil or gate_state.current_job_level < min_job_level) then
        return false, "job_level_too_low", meta
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

    if requires_equipped then
        local listed = gate_state.equipped_skill_map[required_skill_id] == true
        local equipped = decode_truthy(call_has_equipped_skill(gate_state.skill_context, gate_state.current_job, required_skill_id))
        if equipped == nil then
            equipped = listed
        end
        meta.required_skill_equipped = equipped
        if equipped ~= true then
            return false, "skill_not_equipped", meta
        end
    end

    if requires_enabled then
        local enabled = decode_truthy(call_is_custom_skill_enable(gate_state.skill_context, required_skill_id))
        meta.required_skill_enabled = enabled
        if enabled ~= nil and enabled ~= true then
            return false, "skill_not_enabled", meta
        end
    end

    if requires_available then
        local available = decode_truthy(call_is_custom_skill_available(gate_state.skill_availability, required_skill_id))
        meta.required_skill_available = available
        if available ~= nil and available ~= true then
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

    table.sort(candidates, function(left, right)
        local left_priority = tonumber(left.priority) or 0
        local right_priority = tonumber(right.priority) or 0
        if left_priority ~= right_priority then
            return left_priority > right_priority
        end
        return tostring(left.key or "") < tostring(right.key or "")
    end)

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

local function describe_phase_candidates(candidates)
    local values = {}
    for _, phase in ipairs(candidates or {}) do
        values[#values + 1] = string.format(
            "%s:%s:lvl%s:prio%s",
            tostring(phase.key or "nil"),
            tostring(phase.mode or "nil"),
            tostring(phase.min_job_level or 0),
            tostring(phase.priority or 0)
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
        values[#values + 1] = string.format(
            "%s:%s:%s:%s",
            tostring(phase.key or "nil"),
            tostring(phase.reason or "blocked"),
            tostring(phase.required_skill_name or "nil"),
            tostring(phase.min_job_level or "nil")
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

    if has_profile_output(context) then
        set_status(data, "native_hybrid_output", "job_output_already_present")
        return data
    end

    if is_special_skip_output(context) then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "special_output_state")
        return data
    end

    local target, target_reason = resolve_decision_target(context.executing_decision)
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

    if not util.is_valid_obj(target) then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", target_reason)
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
    local selected_phase = allowed_phase_candidates[1]
    data.last_blocked_phase_summary = describe_blocked_phases(blocked_phase_candidates)

    if selected_phase == nil then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", #blocked_phase_candidates > 0 and "phase_blocked" or "phase_unresolved")
        return data
    end

    local now = tonumber(runtime.game_time or os.clock()) or 0.0
    local cooldown_seconds = tonumber(selected_phase.cooldown_seconds) or tonumber(fix_config().cooldown_seconds) or 2.5
    if data.last_apply_time ~= nil and (now - data.last_apply_time) < cooldown_seconds then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "cooldown_active")
        return data
    end

    local output_signature = build_output_signature(context, target, selected_phase.key)
    if data.last_output_signature == output_signature and data.last_apply_time ~= nil then
        data.skip_count = data.skip_count + 1
        set_status(data, "skipped", "duplicate_signature")
        return data
    end

    local bridge_ok, bridge_info = apply_carrier_bridge(data, context, selected_phase.pack_path, target)
    if not bridge_ok then
        data.fail_count = data.fail_count + 1
        set_status(data, "failed", bridge_info and bridge_info.reason or "carrier_bridge_failed")
        if should_log_failure(data, data.last_reason, now) then
            log.warn(string.format(
                "Hybrid combat fix failed job=%s profile=%s phase=%s reason=%s pack=%s current=%s target=%s exec=%s req=%s skipThink=%s",
                tostring(context.current_job),
                tostring(context.profile.key),
                tostring(selected_phase.key),
                tostring(data.last_reason),
                tostring(selected_phase.pack_path),
                tostring(context.decision_pack_path or "nil"),
                tostring(util.describe_obj(target)),
                tostring(bridge_info and bridge_info.exec_ok or false),
                tostring(bridge_info and bridge_info.reqmain_ok or false),
                tostring(bridge_info and bridge_info.skip_think_ok or false)
            ))
        end
        return data
    end

    data.apply_count = data.apply_count + 1
    data.last_apply_time = now
    data.last_phase_key = tostring(selected_phase.key or "nil")
    data.last_pack_path = tostring(selected_phase.pack_path or "nil")
    data.last_target = util.describe_obj(target)
    data.last_target_type = util.get_type_full_name(target) or "nil"
    data.last_target_distance = target_distance
    data.last_output_signature = output_signature
    set_status(data, "applied", "utility_output_bridged_to_hybrid_profile")

    log.info(string.format(
        "Hybrid combat fix applied job=%s profile=%s phase=%s mode=%s lvl=%s pack=%s current=%s dist=%s target=%s allowed=%s blocked=%s skills=%s skipThink=%s",
        tostring(context.current_job),
        tostring(context.profile.key),
        tostring(selected_phase.key),
        tostring(selected_phase.mode or "nil"),
        tostring(gate_state.current_job_level),
        tostring(selected_phase.pack_path),
        tostring(context.decision_pack_path or "nil"),
        tostring(target_distance),
        tostring(data.last_target),
        tostring(describe_phase_candidates(allowed_phase_candidates)),
        tostring(describe_blocked_phases(blocked_phase_candidates)),
        tostring(describe_skill_ids(gate_state.equipped_skill_ids)),
        tostring(bridge_info and bridge_info.skip_think_ok or false)
    ))

    return data
end

return hybrid_combat_fix
