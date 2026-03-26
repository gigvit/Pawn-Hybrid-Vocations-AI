-- Purpose:
-- Capture semantic hints for current main_pawn MainDecisions from DecisionEvaluationModule.
-- Run in combat once with main_pawn Job01 and once with main_pawn Job07, then compare the two JSON files.
-- Output:
--   reframework/data/ce_dump/main_pawn_main_decision_semantic_screen_job<job>_<timestamp>.json

local DECISION_FIELD_LIMIT = 24
local ACTION_PACK_FIELD_LIMIT = 12
local MAX_LIST_ITEMS = 80
local MAX_COLLECTION_SAMPLES = 4

local MAIN_DECISIONS_FIELDS = {
    "<MainDecisions>k__BackingField",
    "_MainDecisions",
    "MainDecisions",
}

local MAIN_DECISIONS_METHODS = {
    "get_MainDecisions()",
}

local DECISION_SEMANTIC_FIELDS = {
    "<UniqueID>k__BackingField",
    "<Stage>k__BackingField",
    "<DisableFlag>k__BackingField",
    "<Priority>k__BackingField",
    "<ControlTags>k__BackingField",
    "<Situation>k__BackingField",
    "<Policy>k__BackingField",
    "<Overwriter>k__BackingField",
    "<Target>k__BackingField",
    "<PositionTarget>k__BackingField",
    "<UniqueTarget>k__BackingField",
    "SetupPreconditionWrappers",
    "<TargetPreconditionsAsCondition>k__BackingField",
    "<CooldownID>k__BackingField",
    "<CooldownTime>k__BackingField",
    "<CooldownTimeOnSuccessfullyEnded>k__BackingField",
}

local SCALAR_PROFILE_FIELDS = {
    "<Stage>k__BackingField",
    "<DisableFlag>k__BackingField",
    "<ControlTags>k__BackingField",
    "<Situation>k__BackingField",
    "<Policy>k__BackingField",
    "<Target>k__BackingField",
    "<PositionTarget>k__BackingField",
}

local ACTION_PACK_FIELDS = {
    "<ActionPack>k__BackingField",
    "_ActionPack",
    "ActionPack",
    "<ActInterPackData>k__BackingField",
    "_ActInterPackData",
    "ActInterPackData",
    "<PackData>k__BackingField",
    "_PackData",
    "PackData",
}

local ACTION_PACK_METHODS = {
    "get_ActionPack()",
    "get_ActInterPackData()",
    "get_PackData()",
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

local COLLECTION_SPECS = {
    {
        key = "preconditions",
        label = "Preconditions",
        fields = { "<Preconditions>k__BackingField", "_Preconditions", "Preconditions" },
        methods = { "get_Preconditions()" },
    },
    {
        key = "precondition_wrappers",
        label = "PreconditionWrappers",
        fields = { "<PreconditionWrappers>k__BackingField", "_PreconditionWrappers", "PreconditionWrappers" },
        methods = { "get_PreconditionWrappers()" },
    },
    {
        key = "target_preconditions",
        label = "TargetPreconditions",
        fields = { "<TargetPreconditions>k__BackingField", "_TargetPreconditions", "TargetPreconditions" },
        methods = { "get_TargetPreconditions()" },
    },
    {
        key = "target_conditions",
        label = "TargetConditions",
        fields = { "<TargetConditions>k__BackingField", "_TargetConditions", "TargetConditions" },
        methods = { "get_TargetConditions()" },
    },
    {
        key = "evaluation_criteria",
        label = "EvaluationCriteria",
        fields = { "<EvaluationCriteria>k__BackingField", "_EvaluationCriteria", "EvaluationCriteria" },
        methods = { "get_EvaluationCriteria()" },
    },
    {
        key = "start_process",
        label = "StartProcess",
        fields = { "<StartProcess>k__BackingField", "_StartProcess", "StartProcess" },
        methods = { "get_StartProcess()" },
    },
    {
        key = "end_process",
        label = "EndProcess",
        fields = { "<EndProcess>k__BackingField", "_EndProcess", "EndProcess" },
        methods = { "get_EndProcess()" },
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

    local max_fields = limit or DECISION_FIELD_LIMIT
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

local function resolve_display_value(value)
    local direct = to_string_or_nil(value)
    if direct ~= nil then
        return direct
    end

    local enum_value, enum_source = safe_field(value, { "value__" })
    if enum_value ~= nil then
        return tostring(enum_value) .. "@" .. tostring(enum_source)
    end

    local to_string, to_string_source = safe_call_method0(value, { "ToString()" })
    local string_value = to_string_or_nil(to_string)
    if string_value ~= nil then
        return string_value .. "@" .. tostring(to_string_source)
    end

    return describe(value)
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

    return {
        decision_maker = decision_maker,
        decision_maker_source = decision_maker_source,
        decision_module = decision_module,
        decision_module_source = decision_module_source,
        decision_executor = decision_executor,
        decision_executor_source = decision_executor_source,
    }
end

local function build_named_field_map(obj, field_names)
    local out = {}

    for _, field_name in ipairs(field_names) do
        local value, source = safe_field(obj, { field_name })
        out[field_name] = {
            value = serialize_object(value, source),
            display = resolve_display_value(value),
        }
    end

    return out
end

local function get_named_display(named_fields, field_name)
    local entry = named_fields[field_name]
    if entry == nil then
        return "nil"
    end

    return entry.display or "nil"
end

local function increment_counter(counter, key)
    local resolved_key = key
    if resolved_key == nil or resolved_key == "" then
        resolved_key = "nil"
    end

    counter[resolved_key] = (counter[resolved_key] or 0) + 1
end

local function sorted_counter_keys(counter)
    local keys = {}
    for key, _ in pairs(counter) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function build_profile_key(named_fields, field_names)
    local parts = {}

    for _, field_name in ipairs(field_names) do
        parts[#parts + 1] = get_named_display(named_fields, field_name)
    end

    return table.concat(parts, " | ")
end

local function build_counter_summary(counter)
    local parts = {}

    for _, key in ipairs(sorted_counter_keys(counter)) do
        parts[#parts + 1] = tostring(key) .. " x" .. tostring(counter[key])
    end

    if #parts == 0 then
        return "none"
    end

    return table.concat(parts, ", ")
end

local function capture_action_pack(item)
    local action_pack, action_pack_source = safe_field(item, ACTION_PACK_FIELDS)
    if not is_present(action_pack) then
        action_pack, action_pack_source = safe_call_method0(item, ACTION_PACK_METHODS)
    end

    local path, path_source = resolve_string_field_or_method(action_pack, PATH_FIELDS, PATH_METHODS)
    local name, name_source = resolve_string_field_or_method(action_pack, NAME_FIELDS, NAME_METHODS)
    local tostring_value, tostring_source = safe_call_method0(action_pack, { "ToString()" })
    local tostring_string = to_string_or_nil(tostring_value)

    local identity = path or name or tostring_string or get_type_name(action_pack)

    return {
        object = serialize_object(action_pack, action_pack_source),
        path = serialize_scalar(path, path_source),
        name = serialize_scalar(name, name_source),
        tostring_value = serialize_scalar(tostring_string, tostring_source),
        identity = identity,
        shallow_fields = snapshot_shallow_fields(action_pack, ACTION_PACK_FIELD_LIMIT),
    }
end

local function capture_collection_summary(root, spec)
    local list_obj, list_source = safe_field(root, spec.fields)
    if not is_present(list_obj) then
        list_obj, list_source = safe_call_method0(root, spec.methods)
    end

    local count, count_source = get_collection_count(list_obj)
    local type_counts = {}
    local samples = {}

    if count ~= nil then
        local max_items = math.min(count, MAX_COLLECTION_SAMPLES)
        for index = 0, max_items - 1 do
            local item, item_source = get_collection_item(list_obj, index)
            local item_type_name = get_type_name(item)
            increment_counter(type_counts, item_type_name)
            samples[#samples + 1] = {
                index = index,
                item = serialize_object(item, item_source),
                display = resolve_display_value(item),
            }
        end

        if count > max_items then
            for index = max_items, count - 1 do
                local item, _ = get_collection_item(list_obj, index)
                increment_counter(type_counts, get_type_name(item))
            end
        end
    end

    return {
        label = spec.label,
        collection = serialize_object(list_obj, list_source),
        count = serialize_scalar(count, count_source),
        type_counts = type_counts,
        type_summary = build_counter_summary(type_counts),
        samples = samples,
    }
end

local function build_entry(item, index, item_source)
    local named_fields = build_named_field_map(item, DECISION_SEMANTIC_FIELDS)
    local action_pack = capture_action_pack(item)
    local collection_summaries = {}

    for _, spec in ipairs(COLLECTION_SPECS) do
        collection_summaries[spec.key] = capture_collection_summary(item, spec)
    end

    local scalar_profile = build_profile_key(named_fields, SCALAR_PROFILE_FIELDS)
    local semantic_signature = table.concat({
        scalar_profile,
        "pack=" .. tostring(action_pack.identity),
        "pre=" .. tostring(collection_summaries.preconditions.type_summary),
        "tpre=" .. tostring(collection_summaries.target_preconditions.type_summary),
        "tcond=" .. tostring(collection_summaries.target_conditions.type_summary),
        "eval=" .. tostring(collection_summaries.evaluation_criteria.type_summary),
        "start=" .. tostring(collection_summaries.start_process.type_summary),
        "end=" .. tostring(collection_summaries.end_process.type_summary),
    }, " || ")

    return {
        index = index,
        item = serialize_object(item, item_source),
        named_fields = named_fields,
        scalar_profile = scalar_profile,
        action_pack = action_pack,
        collection_summaries = collection_summaries,
        semantic_signature = semantic_signature,
        shallow_fields = snapshot_shallow_fields(item, DECISION_FIELD_LIMIT),
    }
end

local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
local PawnManager = sdk.get_managed_singleton("app.PawnManager")

local main_pawn, main_pawn_source = resolve_main_pawn(PawnManager, CharacterManager)
local runtime_character, runtime_character_source = resolve_runtime_character_from_pawn(main_pawn)
local human, human_source = safe_call_method0(runtime_character, { "get_Human()" })
local chara_id, chara_id_source = safe_call_method0(runtime_character, { "get_CharaID()" })
local current_job, current_job_source, job_context, job_context_source = resolve_current_job(human, runtime_character)
local chain = resolve_decision_chain(runtime_character)

local main_decisions, main_decisions_source = safe_field(chain.decision_module, MAIN_DECISIONS_FIELDS)
if not is_present(main_decisions) then
    main_decisions, main_decisions_source = safe_call_method0(chain.decision_module, MAIN_DECISIONS_METHODS)
end

local main_decision_count, main_decision_count_source = get_collection_count(main_decisions)
local entries = {}
local scalar_profile_counts = {}
local semantic_signature_counts = {}
local action_pack_identity_counts = {}
local preconditions_type_signature_counts = {}
local target_preconditions_type_signature_counts = {}
local target_conditions_type_signature_counts = {}
local evaluation_criteria_type_signature_counts = {}
local start_process_type_signature_counts = {}
local end_process_type_signature_counts = {}

if main_decision_count ~= nil then
    local max_items = math.min(main_decision_count, MAX_LIST_ITEMS)
    for index = 0, max_items - 1 do
        local item, item_source = get_collection_item(main_decisions, index)
        local entry = build_entry(item, index, item_source)
        entries[#entries + 1] = entry
        increment_counter(scalar_profile_counts, entry.scalar_profile)
        increment_counter(semantic_signature_counts, entry.semantic_signature)
        increment_counter(action_pack_identity_counts, entry.action_pack.identity)
        increment_counter(preconditions_type_signature_counts, entry.collection_summaries.preconditions.type_summary)
        increment_counter(target_preconditions_type_signature_counts, entry.collection_summaries.target_preconditions.type_summary)
        increment_counter(target_conditions_type_signature_counts, entry.collection_summaries.target_conditions.type_summary)
        increment_counter(evaluation_criteria_type_signature_counts, entry.collection_summaries.evaluation_criteria.type_summary)
        increment_counter(start_process_type_signature_counts, entry.collection_summaries.start_process.type_summary)
        increment_counter(end_process_type_signature_counts, entry.collection_summaries.end_process.type_summary)
    end
end

local current_job_number = tonumber(current_job)
local job_suffix = current_job_number ~= nil and string.format("job%02d", current_job_number) or "job_unknown"

local output = {
    tag = "main_pawn_main_decision_semantic_screen",
    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
    output_note = "Capture semantic hints for current main_pawn MainDecisions. Run in combat once in Job01 and once in Job07, then compare the JSON files.",
    actor = {
        actor_mode = "main_pawn",
        actor_root = serialize_object(main_pawn, main_pawn_source),
        runtime_character = serialize_object(runtime_character, runtime_character_source),
        human = serialize_object(human, human_source),
        chara_id = serialize_scalar(chara_id, chara_id_source),
        current_job = serialize_scalar(current_job, current_job_source),
        job_context = serialize_object(job_context, job_context_source),
    },
    decision_chain = {
        decision_maker = serialize_object(chain.decision_maker, chain.decision_maker_source),
        decision_module = serialize_object(chain.decision_module, chain.decision_module_source),
        decision_executor = serialize_object(chain.decision_executor, chain.decision_executor_source),
    },
    summary = {
        current_job = current_job_number,
        main_decision_count = main_decision_count,
        scalar_profile_counts = scalar_profile_counts,
        semantic_signature_counts = semantic_signature_counts,
        action_pack_identity_counts = action_pack_identity_counts,
        preconditions_type_signature_counts = preconditions_type_signature_counts,
        target_preconditions_type_signature_counts = target_preconditions_type_signature_counts,
        target_conditions_type_signature_counts = target_conditions_type_signature_counts,
        evaluation_criteria_type_signature_counts = evaluation_criteria_type_signature_counts,
        start_process_type_signature_counts = start_process_type_signature_counts,
        end_process_type_signature_counts = end_process_type_signature_counts,
    },
    main_decisions = {
        collection = serialize_object(main_decisions, main_decisions_source),
        count = serialize_scalar(main_decision_count, main_decision_count_source),
        truncated = main_decision_count ~= nil and main_decision_count > MAX_LIST_ITEMS or false,
        entries = entries,
    },
}

local output_path = "ce_dump/main_pawn_main_decision_semantic_screen_" .. job_suffix .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
json.dump_file(output_path, output)
print("[main_pawn_main_decision_semantic_screen] wrote " .. output_path)
return output_path
