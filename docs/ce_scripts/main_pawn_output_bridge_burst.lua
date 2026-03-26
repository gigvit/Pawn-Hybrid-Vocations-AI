-- Purpose:
-- Capture a timed combat burst that links current main_pawn DecisionEvaluationModule population
-- to observed output surfaces such as selected_request, current_action, decision pack, and FSM nodes.
-- Run once in combat with main_pawn Job01 and once in combat with main_pawn Job07, then compare the JSON files.
--
-- Output:
--   reframework/data/ce_dump/main_pawn_output_bridge_burst_<trace_label>_<timestamp>.json
--
-- Presets:
--   by default the script auto-labels the output from the observed current job
--   if you want strict validation, set EXPECTED_JOB manually to 1 or 7 before running

local GLOBAL_KEY = "__main_pawn_output_bridge_burst_state_v1"
local TRACE_LABEL = "main_pawn_output_auto"
local EXPECTED_JOB = nil
local SAMPLE_INTERVAL_SECONDS = 0.5
local DURATION_SECONDS = 12.0
local MAX_SAMPLES = 24
local MAX_MAIN_DECISION_SCAN = 80
local OUTPUT_SHALLOW_FIELD_LIMIT = 10

local MAIN_DECISIONS_FIELDS = {
    "<MainDecisions>k__BackingField",
    "_MainDecisions",
    "MainDecisions",
}

local MAIN_DECISIONS_METHODS = {
    "get_MainDecisions()",
}

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

local function try_eval(fn)
    local ok, value = pcall(fn)
    return ok, value
end

local function round3(value)
    local number = tonumber(value) or 0.0
    return math.floor(number * 1000 + 0.5) / 1000
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

local function safe_present_field(obj, fields)
    if obj == nil then
        return nil, "root_nil"
    end

    local last_source = "unresolved"
    for _, field_name in ipairs(fields) do
        local ok, value = try_eval(function()
            return obj[field_name]
        end)
        if ok then
            last_source = field_name
            if is_present(value) then
                return value, field_name
            end
        end
    end

    return nil, last_source
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

    local max_fields = limit or OUTPUT_SHALLOW_FIELD_LIMIT
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

local function get_collection_item(obj, index)
    return safe_call_method1(obj, {
        "get_Item(System.Int32)",
        "get_Item(System.UInt32)",
        "get_Item",
    }, index)
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

local function resolve_string_field_or_method(obj, fields, methods)
    local field_value, field_source = safe_field(obj, fields)
    local field_string = to_string_or_nil(field_value)
    if field_string ~= nil then
        return field_string, field_source
    end

    local method_value, method_source = safe_call_method0(obj, methods)
    local method_string = to_string_or_nil(method_value)
    if method_string ~= nil then
        return method_string, method_source
    end

    return nil, "unresolved"
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
    for _, needle in ipairs(needles) do
        if contains_text(value, needle) then
            return true
        end
    end

    return false
end

local function bump(map, key)
    local name = tostring(key or "nil")
    map[name] = (map[name] or 0) + 1
end

local function sorted_counter_keys(counter)
    local keys = {}
    for key, _ in pairs(counter) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function counter_keys(counter)
    local result = {}
    for _, key in ipairs(sorted_counter_keys(counter)) do
        result[#result + 1] = key
    end
    return result
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

local function resolve_current_job(human, runtime_character)
    local job_context, job_context_source = safe_field(human, {
        "<JobContext>k__BackingField",
        "JobContext",
    })

    local current_job, current_job_source = safe_field(human, { "<CurrentJob>k__BackingField" })
    if current_job ~= nil then
        return current_job, "human:" .. tostring(current_job_source), job_context, job_context_source
    end

    local job_context_job, job_context_job_source = safe_field(job_context, { "CurrentJob" })
    if job_context_job ~= nil then
        return job_context_job, "job_context:" .. tostring(job_context_job_source), job_context, job_context_source
    end

    local method_job, method_job_source = safe_call_method0(runtime_character, {
        "get_CurrentJob()",
        "get_Job()",
    })
    if method_job ~= nil then
        return method_job, "runtime_character:" .. tostring(method_job_source), job_context, job_context_source
    end

    local field_job, field_job_source = safe_field(runtime_character, { "CurrentJob", "Job" })
    return field_job, "runtime_character:" .. tostring(field_job_source), job_context, job_context_source
end

local function resolve_decision_chain(runtime_character)
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

    return {
        decision_maker = decision_maker,
        decision_maker_source = decision_maker_source,
        decision_module = decision_module,
        decision_module_source = decision_module_source,
        decision_executor = decision_executor,
        decision_executor_source = decision_executor_source,
        executing_decision = executing_decision,
        executing_decision_source = executing_decision_source,
    }
end

local function resolve_decision_pack_path(decision_module, executing_decision)
    local execute_actinter, execute_actinter_source = safe_present_field(decision_module, {
        "_ExecuteActInter",
        "<ExecuteActInter>k__BackingField",
        "ExecuteActInter",
    })
    local execute_pack, execute_pack_source = safe_call_method0(execute_actinter, {
        "get_ActInterPackData()",
    })
    if not is_present(execute_pack) then
        execute_pack, execute_pack_source = safe_present_field(execute_actinter, {
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

    local decision_pack, decision_pack_source = safe_present_field(executing_decision, {
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

local function capture_pack_like_identity(root, root_source)
    local root_object = serialize_object(root, root_source)
    local pack_object, pack_object_source = safe_present_field(root, ACTION_PACK_FIELDS)
    if not is_present(pack_object) then
        pack_object, pack_object_source = safe_call_method0(root, ACTION_PACK_METHODS)
    end

    local target = is_present(pack_object) and pack_object or root
    local target_source = is_present(pack_object) and tostring(pack_object_source) or tostring(root_source)
    local path, path_source = resolve_string_field_or_method(target, PATH_FIELDS, PATH_METHODS)
    local name, name_source = resolve_string_field_or_method(target, NAME_FIELDS, NAME_METHODS)
    local tostring_value, tostring_source = safe_call_method0(target, { "ToString()" })
    local tostring_string = to_string_or_nil(tostring_value)
    local identity = path or name or tostring_string or get_type_name(target)

    return {
        object = root_object,
        pack_object = serialize_object(pack_object, pack_object_source),
        path = serialize_scalar(path, "path:" .. tostring(path_source)),
        name = serialize_scalar(name, "name:" .. tostring(name_source)),
        tostring_value = serialize_scalar(tostring_string, "tostring:" .. tostring(tostring_source)),
        identity = identity,
        identity_source = target_source,
        shallow_fields = snapshot_shallow_fields(root, OUTPUT_SHALLOW_FIELD_LIMIT),
    }
end

local function contains_attackish_text(value)
    return contains_any_text(value, {
        "attack",
        "slash",
        "stab",
        "blink",
        "fullmoon",
        "violent",
        "guard",
        "dashattack",
        "dashheavy",
    })
end

local function is_generic_attack_identity(identity)
    return contains_text(identity, "/genericjob/") and contains_attackish_text(identity)
end

local function is_job_pack_identity(identity, current_job_number)
    if current_job_number == nil then
        return false
    end

    return contains_text(identity, string.format("job%02d", current_job_number))
end

local function is_utility_identity(identity)
    return contains_any_text(identity, {
        "/common/",
        "/ch1/",
        "movetoposition",
        "moveapproach",
        "keepdistance",
        "drawwweapon",
        "drawweapon",
        "carry",
        "cling",
        "talk",
    })
end

local function analyze_main_decisions(decision_module, current_job_number)
    local list_obj, list_source = safe_field(decision_module, MAIN_DECISIONS_FIELDS)
    if not is_present(list_obj) then
        list_obj, list_source = safe_call_method0(decision_module, MAIN_DECISIONS_METHODS)
    end

    local count, count_source = get_collection_count(list_obj)
    local scanned_items = 0
    local total_pack_count = 0
    local current_job_pack_count = 0
    local generic_attack_pack_count = 0
    local attackish_pack_count = 0
    local utility_pack_count = 0
    local keep_distance_pack_count = 0
    local pack_identity_counts = {}
    local current_job_pack_identity_counts = {}
    local generic_attack_identity_counts = {}
    local utility_identity_counts = {}

    if count ~= nil then
        local max_items = math.min(count, MAX_MAIN_DECISION_SCAN)
        for index = 0, max_items - 1 do
            local item, item_source = get_collection_item(list_obj, index)
            local pack_capture = capture_pack_like_identity(item, item_source)
            local identity = tostring(pack_capture.identity or "nil")

            scanned_items = scanned_items + 1
            if pack_capture.pack_object.present then
                total_pack_count = total_pack_count + 1
                bump(pack_identity_counts, identity)

                if is_job_pack_identity(identity, current_job_number) then
                    current_job_pack_count = current_job_pack_count + 1
                    bump(current_job_pack_identity_counts, identity)
                end
                if is_generic_attack_identity(identity) then
                    generic_attack_pack_count = generic_attack_pack_count + 1
                    bump(generic_attack_identity_counts, identity)
                end
                if contains_attackish_text(identity) then
                    attackish_pack_count = attackish_pack_count + 1
                end
                if is_utility_identity(identity) then
                    utility_pack_count = utility_pack_count + 1
                    bump(utility_identity_counts, identity)
                end
                if contains_text(identity, "keepdistance") then
                    keep_distance_pack_count = keep_distance_pack_count + 1
                end
            end
        end
    end

    local population_mode = "population_unresolved"
    if count ~= nil then
        if total_pack_count == 0 then
            population_mode = "no_pack_population"
        elseif current_job_pack_count > 0 or generic_attack_pack_count > 0 or attackish_pack_count > 0 then
            population_mode = "attack_populated"
        elseif utility_pack_count > 0 or keep_distance_pack_count > 0 then
            population_mode = "utility_only_population"
        else
            population_mode = "other_nonattack_population"
        end
    end

    return {
        collection = serialize_object(list_obj, list_source),
        count = serialize_scalar(count, count_source),
        scanned_items = scanned_items,
        total_pack_count = total_pack_count,
        current_job_pack_count = current_job_pack_count,
        generic_attack_pack_count = generic_attack_pack_count,
        attackish_pack_count = attackish_pack_count,
        utility_pack_count = utility_pack_count,
        keep_distance_pack_count = keep_distance_pack_count,
        population_mode = population_mode,
        pack_identity_counts = pack_identity_counts,
        current_job_pack_identities = counter_keys(current_job_pack_identity_counts),
        generic_attack_pack_identities = counter_keys(generic_attack_identity_counts),
        utility_pack_identities = counter_keys(utility_identity_counts),
    }
end

local function classify_output(current_job_number, decision_pack_path, full_node, current_action_identity, selected_request_identity)
    local texts = {
        decision_pack_path,
        full_node,
        current_action_identity,
        selected_request_identity,
    }

    if current_job_number ~= nil then
        local token = string.format("job%02d", current_job_number)
        for _, text in ipairs(texts) do
            if contains_text(text, token) then
                return "job_specific_output_candidate"
            end
        end
    end

    for _, text in ipairs(texts) do
        if is_generic_attack_identity(text) then
            return "generic_attack_output_candidate"
        end
    end

    for _, text in ipairs(texts) do
        if contains_attackish_text(text) then
            return "attackish_output_other"
        end
    end

    for _, text in ipairs(texts) do
        if contains_any_text(text, {
            "/common/",
            "/ch1/",
            "movetoposition",
            "moveapproach",
            "keepdistance",
            "locomotion.",
            "drawweapon",
            "carry",
            "cling",
            "talk",
        }) then
            return "common_utility_output"
        end
    end

    for _, text in ipairs(texts) do
        if text ~= nil and tostring(text) ~= "nil" and tostring(text) ~= "" then
            return "other_output"
        end
    end

    return "no_output_signal"
end

local function build_sample_signature(sample)
    return table.concat({
        tostring(sample.current_job.value or "nil"),
        tostring(sample.main_decisions.population_mode or "nil"),
        tostring(sample.main_decisions.count.value or "nil"),
        tostring(sample.main_decisions.current_job_pack_count or "nil"),
        tostring(sample.main_decisions.generic_attack_pack_count or "nil"),
        tostring(sample.main_decisions.utility_pack_count or "nil"),
        tostring(sample.output.output_mode or "nil"),
        tostring(sample.output.decision_pack_path.value or "nil"),
        tostring(sample.output.current_action.identity or "nil"),
        tostring(sample.output.selected_request.identity or "nil"),
        tostring(sample.output.full_node.value or "nil"),
        tostring(sample.output.upper_node.value or "nil"),
    }, " | ")
end

local function capture_sample(now, started_at, recorder)
    local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
    local PawnManager = sdk.get_managed_singleton("app.PawnManager")
    local main_pawn, main_pawn_source = resolve_main_pawn(PawnManager, CharacterManager)
    local runtime_character, runtime_character_source = resolve_runtime_character_from_pawn(main_pawn)
    local human, human_source = safe_call_method0(runtime_character, { "get_Human()" })
    local chara_id, chara_id_source = safe_call_method0(runtime_character, { "get_CharaID()" })
    local current_job, current_job_source, job_context, job_context_source = resolve_current_job(human, runtime_character)
    local action_manager, action_manager_source = safe_call_method0(runtime_character, { "get_ActionManager()" })
    local chain = resolve_decision_chain(runtime_character)
    local decision_pack_path, decision_pack_path_source = resolve_decision_pack_path(chain.decision_module, chain.executing_decision)
    local full_node, full_node_source = get_fsm_node_name(action_manager, 0)
    local upper_node, upper_node_source = get_fsm_node_name(action_manager, 1)
    local current_action, current_action_source = safe_field(action_manager, { "CurrentAction" })
    local selected_request, selected_request_source = safe_field(action_manager, { "SelectedRequest" })
    local request_info_list, request_info_list_source = safe_field(action_manager, { "RequestInfoList" })
    local request_info_count, request_info_count_source = get_collection_count(request_info_list)
    local current_action_list, current_action_list_source = safe_field(action_manager, { "CurrentActionList" })
    local current_action_count, current_action_count_source = get_collection_count(current_action_list)
    local current_job_number = tonumber(current_job)
    local main_decisions = analyze_main_decisions(chain.decision_module, current_job_number)
    local current_action_capture = capture_pack_like_identity(current_action, current_action_source)
    local selected_request_capture = capture_pack_like_identity(selected_request, selected_request_source)

    local output_mode = classify_output(
        current_job_number,
        decision_pack_path,
        full_node,
        current_action_capture.identity,
        selected_request_capture.identity
    )
    local bridge_mode = tostring(main_decisions.population_mode) .. " -> " .. tostring(output_mode)

    local sample = {
        captured_at = os.date("%Y-%m-%d %H:%M:%S"),
        elapsed_seconds = round3(now - started_at),
        trace_label = recorder.trace_label,
        expected_job = recorder.expected_job,
        actor_root = serialize_object(main_pawn, main_pawn_source),
        runtime_character = serialize_object(runtime_character, runtime_character_source),
        human = serialize_object(human, human_source),
        chara_id = serialize_scalar(chara_id, chara_id_source),
        current_job = serialize_scalar(current_job, current_job_source),
        job_context = serialize_object(job_context, job_context_source),
        action_manager = serialize_object(action_manager, action_manager_source),
        decision_chain = {
            decision_maker = serialize_object(chain.decision_maker, chain.decision_maker_source),
            decision_module = serialize_object(chain.decision_module, chain.decision_module_source),
            decision_executor = serialize_object(chain.decision_executor, chain.decision_executor_source),
            executing_decision = serialize_object(chain.executing_decision, chain.executing_decision_source),
        },
        action_manager_counts = {
            request_info_list = serialize_object(request_info_list, request_info_list_source),
            request_info_count = serialize_scalar(request_info_count, request_info_count_source),
            current_action_list = serialize_object(current_action_list, current_action_list_source),
            current_action_count = serialize_scalar(current_action_count, current_action_count_source),
        },
        main_decisions = main_decisions,
        output = {
            decision_pack_path = serialize_scalar(decision_pack_path, decision_pack_path_source),
            full_node = serialize_scalar(full_node, full_node_source),
            upper_node = serialize_scalar(upper_node, upper_node_source),
            current_action = current_action_capture,
            selected_request = selected_request_capture,
            output_mode = output_mode,
            bridge_mode = bridge_mode,
        },
    }

    sample.signature = build_sample_signature(sample)
    sample.unexpected_job = recorder.expected_job ~= nil and current_job_number ~= recorder.expected_job or false
    return sample
end

local function build_summary(samples, recorder, finish_reason)
    local population_modes = {}
    local output_modes = {}
    local bridge_modes = {}
    local main_decision_counts = {}
    local current_job_pack_counts = {}
    local generic_attack_pack_counts = {}
    local utility_pack_counts = {}
    local keep_distance_pack_counts = {}
    local decision_pack_paths = {}
    local current_action_identities = {}
    local selected_request_identities = {}
    local full_nodes = {}
    local upper_nodes = {}
    local signatures = {}
    local transitions = {}
    local current_jobs = {}
    local attack_populated_samples = 0
    local utility_only_population_samples = 0
    local job_specific_output_samples = 0
    local generic_attack_output_samples = 0
    local common_utility_output_samples = 0
    local unexpected_job_samples = 0

    local previous_signature = nil
    for index, sample in ipairs(samples) do
        bump(population_modes, sample.main_decisions.population_mode)
        bump(output_modes, sample.output.output_mode)
        bump(bridge_modes, sample.output.bridge_mode)
        bump(main_decision_counts, sample.main_decisions.count.value)
        bump(current_job_pack_counts, sample.main_decisions.current_job_pack_count)
        bump(generic_attack_pack_counts, sample.main_decisions.generic_attack_pack_count)
        bump(utility_pack_counts, sample.main_decisions.utility_pack_count)
        bump(keep_distance_pack_counts, sample.main_decisions.keep_distance_pack_count)
        bump(decision_pack_paths, sample.output.decision_pack_path.value)
        bump(current_action_identities, sample.output.current_action.identity)
        bump(selected_request_identities, sample.output.selected_request.identity)
        bump(full_nodes, sample.output.full_node.value)
        bump(upper_nodes, sample.output.upper_node.value)
        bump(signatures, sample.signature)
        bump(current_jobs, sample.current_job.value)

        if sample.main_decisions.population_mode == "attack_populated" then
            attack_populated_samples = attack_populated_samples + 1
        elseif sample.main_decisions.population_mode == "utility_only_population" then
            utility_only_population_samples = utility_only_population_samples + 1
        end

        if sample.output.output_mode == "job_specific_output_candidate" then
            job_specific_output_samples = job_specific_output_samples + 1
        elseif sample.output.output_mode == "generic_attack_output_candidate" or sample.output.output_mode == "attackish_output_other" then
            generic_attack_output_samples = generic_attack_output_samples + 1
        elseif sample.output.output_mode == "common_utility_output" then
            common_utility_output_samples = common_utility_output_samples + 1
        end

        if sample.unexpected_job then
            unexpected_job_samples = unexpected_job_samples + 1
        end

        if previous_signature ~= nil and previous_signature ~= sample.signature then
            transitions[#transitions + 1] = {
                sample_index = index,
                elapsed_seconds = sample.elapsed_seconds,
                from_signature = previous_signature,
                to_signature = sample.signature,
            }
        end
        previous_signature = sample.signature
    end

    return {
        trace_label = recorder.trace_label,
        expected_job = recorder.expected_job,
        finish_reason = finish_reason,
        sample_count = #samples,
        attack_populated_samples = attack_populated_samples,
        utility_only_population_samples = utility_only_population_samples,
        job_specific_output_samples = job_specific_output_samples,
        generic_attack_output_samples = generic_attack_output_samples,
        common_utility_output_samples = common_utility_output_samples,
        unexpected_job_samples = unexpected_job_samples,
        population_modes = population_modes,
        output_modes = output_modes,
        bridge_modes = bridge_modes,
        current_jobs = current_jobs,
        main_decision_counts = main_decision_counts,
        current_job_pack_counts = current_job_pack_counts,
        generic_attack_pack_counts = generic_attack_pack_counts,
        utility_pack_counts = utility_pack_counts,
        keep_distance_pack_counts = keep_distance_pack_counts,
        decision_pack_paths = decision_pack_paths,
        current_action_identities = current_action_identities,
        selected_request_identities = selected_request_identities,
        full_nodes = full_nodes,
        upper_nodes = upper_nodes,
        signatures = signatures,
        transitions = transitions,
    }
end

local function get_observed_job_suffix(samples)
    if samples == nil or #samples == 0 then
        return "job_unknown"
    end

    local counts = {}
    for _, sample in ipairs(samples) do
        local value = tonumber(sample.current_job.value)
        local key = value ~= nil and string.format("job%02d", value) or "job_unknown"
        counts[key] = (counts[key] or 0) + 1
    end

    local best_key = "job_unknown"
    local best_count = -1
    for key, count in pairs(counts) do
        if count > best_count then
            best_key = key
            best_count = count
        end
    end

    return best_key
end

local state = rawget(_G, GLOBAL_KEY)
if state == nil then
    state = {
        hook_installed = false,
        recorder = nil,
        last_output_path = nil,
    }
    rawset(_G, GLOBAL_KEY, state)
end

local function finalize_recorder(reason)
    local recorder = state.recorder
    if recorder == nil then
        return nil
    end

    local output = {
        tag = "main_pawn_output_bridge_burst",
        generated_at = os.date("%Y-%m-%d %H:%M:%S"),
        config = {
            trace_label = recorder.trace_label,
            expected_job = recorder.expected_job,
            sample_interval_seconds = recorder.sample_interval_seconds,
            duration_seconds = recorder.duration_seconds,
            max_samples = recorder.max_samples,
            max_main_decision_scan = MAX_MAIN_DECISION_SCAN,
        },
        started_at = recorder.started_at_real,
        summary = build_summary(recorder.samples, recorder, reason),
        samples = recorder.samples,
    }

    local job_suffix = get_observed_job_suffix(recorder.samples)
    local output_path = string.format(
        "ce_dump/main_pawn_output_bridge_burst_%s_%s_%s.json",
        tostring(job_suffix),
        tostring(recorder.trace_label),
        os.date("%Y%m%d_%H%M%S")
    )
    json.dump_file(output_path, output)
    state.last_output_path = output_path
    state.recorder = nil
    print("[main_pawn_output_bridge_burst] wrote " .. output_path)
    return output_path
end

if not state.hook_installed then
    re.on_application_entry("LateUpdateBehavior", function()
        local recorder = state.recorder
        if recorder == nil then
            return
        end

        local now = tonumber(os.clock()) or 0.0
        if recorder.started_at == nil then
            recorder.started_at = now
            recorder.next_sample_at = now
        end

        while recorder.next_sample_at ~= nil and now >= recorder.next_sample_at and #recorder.samples < recorder.max_samples do
            recorder.samples[#recorder.samples + 1] = capture_sample(now, recorder.started_at, recorder)
            recorder.next_sample_at = recorder.next_sample_at + recorder.sample_interval_seconds
        end

        if (now - recorder.started_at) >= recorder.duration_seconds or #recorder.samples >= recorder.max_samples then
            local reason = #recorder.samples >= recorder.max_samples and "max_samples_reached" or "duration_elapsed"
            finalize_recorder(reason)
        end
    end)
    state.hook_installed = true
end

if state.recorder ~= nil then
    finalize_recorder("restarted")
end

state.recorder = {
    trace_label = TRACE_LABEL,
    expected_job = EXPECTED_JOB,
    started_at = nil,
    next_sample_at = nil,
    started_at_real = os.date("%Y-%m-%d %H:%M:%S"),
    sample_interval_seconds = SAMPLE_INTERVAL_SECONDS,
    duration_seconds = DURATION_SECONDS,
    max_samples = MAX_SAMPLES,
    samples = {},
}

print(string.format(
    "[main_pawn_output_bridge_burst] started trace=%s expected_job=%s interval=%.2fs duration=%.2fs max_samples=%d",
    tostring(TRACE_LABEL),
    tostring(EXPECTED_JOB),
    SAMPLE_INTERVAL_SECONDS,
    DURATION_SECONDS,
    MAX_SAMPLES
))
print("[main_pawn_output_bridge_burst] keep fighting; result will be written to ce_dump automatically")
return "main_pawn_output_bridge_burst_started"
