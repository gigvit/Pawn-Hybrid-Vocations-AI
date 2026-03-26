-- Purpose:
-- Capture current main_pawn DecisionEvaluationModule decision lists in a stable compare format.
-- Run once with main_pawn Job01 and once with main_pawn Job07, then compare the two JSON files.
-- Output:
--   reframework/data/ce_dump/main_pawn_decision_list_screen_job<job>_<timestamp>.json

local SHALLOW_FIELD_LIMIT = 16
local ENTRY_SHALLOW_FIELD_LIMIT = 10
local MAX_LIST_ITEMS = 80

local DECISION_LIST_SPECS = {
    {
        key = "main_decisions",
        label = "MainDecisions",
        fields = { "<MainDecisions>k__BackingField", "_MainDecisions", "MainDecisions" },
        methods = { "get_MainDecisions()" },
    },
    {
        key = "pre_decisions",
        label = "PreDecisions",
        fields = { "<PreDecisions>k__BackingField", "_PreDecisions", "PreDecisions" },
        methods = { "get_PreDecisions()" },
    },
    {
        key = "post_decisions",
        label = "PostDecisions",
        fields = { "<PostDecisions>k__BackingField", "_PostDecisions", "PostDecisions" },
        methods = { "get_PostDecisions()" },
    },
}

local DECISION_NAME_FIELDS = {
    "<Name>k__BackingField",
    "_Name",
    "Name",
    "<DecisionName>k__BackingField",
    "_DecisionName",
    "DecisionName",
}

local DECISION_NAME_METHODS = {
    "get_Name()",
    "get_DecisionName()",
    "ToString()",
}

local PACK_DATA_FIELDS = {
    "<ActionPackData>k__BackingField",
    "_ActionPackData",
    "ActionPackData",
    "<ActInterPackData>k__BackingField",
    "_ActInterPackData",
    "ActInterPackData",
    "<PackData>k__BackingField",
    "_PackData",
    "PackData",
}

local PACK_DATA_METHODS = {
    "get_ActionPackData()",
    "get_ActInterPackData()",
    "get_PackData()",
}

local PATH_FIELDS = {
    "<Path>k__BackingField",
    "_Path",
    "Path",
}

local PATH_METHODS = {
    "get_Path()",
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

    if type(value) == "string" then
        return value
    end

    local value_type = type(value)
    if value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end

    return nil
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

local function resolve_pack_path(obj)
    local direct_path, direct_path_source = resolve_string_field_or_method(obj, PATH_FIELDS, PATH_METHODS)
    if direct_path ~= nil then
        return direct_path, "decision:" .. tostring(direct_path_source)
    end

    local pack_data, pack_data_source = safe_field(obj, PACK_DATA_FIELDS)
    if not is_present(pack_data) then
        pack_data, pack_data_source = safe_call_method0(obj, PACK_DATA_METHODS)
    end

    local pack_path, pack_path_source = resolve_string_field_or_method(pack_data, PATH_FIELDS, PATH_METHODS)
    if pack_path ~= nil then
        return pack_path, "pack_data:" .. tostring(pack_path_source)
    end

    return nil, "unresolved"
end

local function normalize_text(value)
    if value == nil then
        return nil
    end

    return string.lower(tostring(value))
end

local function has_job_marker(job_marker, values)
    if job_marker == nil then
        return false
    end

    local marker = normalize_text(job_marker)
    for _, value in ipairs(values) do
        local text = normalize_text(value)
        if text ~= nil and string.find(text, marker, 1, true) ~= nil then
            return true
        end
    end

    return false
end

local function increment_counter(counter, key)
    local resolved_key = key
    if resolved_key == nil or resolved_key == "" then
        resolved_key = "nil"
    end

    counter[resolved_key] = (counter[resolved_key] or 0) + 1
end

local function build_decision_entry(item, index, item_source, job_marker)
    local decision_name, decision_name_source = resolve_string_field_or_method(item, DECISION_NAME_FIELDS, DECISION_NAME_METHODS)
    local pack_path, pack_path_source = resolve_pack_path(item)
    local item_type_name = get_type_name(item)
    local item_description = describe(item)
    local signature = table.concat({
        item_type_name or "nil",
        decision_name or "nil",
        pack_path or "nil",
    }, " | ")

    return {
        index = index,
        item = serialize_object(item, item_source),
        decision_name = serialize_scalar(decision_name, decision_name_source),
        pack_path = serialize_scalar(pack_path, pack_path_source),
        signature = signature,
        matches_current_job_marker = has_job_marker(job_marker, {
            item_type_name,
            item_description,
            decision_name,
            pack_path,
        }),
        shallow_fields = snapshot_shallow_fields(item, ENTRY_SHALLOW_FIELD_LIMIT),
    }
end

local function capture_decision_list(decision_module, spec, job_marker)
    local list_obj, list_source = safe_field(decision_module, spec.fields)
    if not is_present(list_obj) then
        list_obj, list_source = safe_call_method0(decision_module, spec.methods)
    end

    local count, count_source = get_collection_count(list_obj)
    local entries = {}
    local type_counts = {}
    local name_counts = {}
    local pack_path_counts = {}
    local signature_counts = {}
    local job_marker_hits = 0

    if count ~= nil then
        local max_items = math.min(count, MAX_LIST_ITEMS)
        for index = 0, max_items - 1 do
            local item, item_source = get_collection_item(list_obj, index)
            local entry = build_decision_entry(item, index, item_source, job_marker)
            entries[#entries + 1] = entry
            increment_counter(type_counts, entry.item.type_name)
            increment_counter(name_counts, entry.decision_name.value)
            increment_counter(pack_path_counts, entry.pack_path.value)
            increment_counter(signature_counts, entry.signature)
            if entry.matches_current_job_marker then
                job_marker_hits = job_marker_hits + 1
            end
        end
    end

    return {
        label = spec.label,
        collection = serialize_object(list_obj, list_source),
        count = serialize_scalar(count, count_source),
        truncated = count ~= nil and count > MAX_LIST_ITEMS or false,
        job_marker_hits = job_marker_hits,
        type_counts = type_counts,
        name_counts = name_counts,
        pack_path_counts = pack_path_counts,
        signature_counts = signature_counts,
        entries = entries,
    }
end

local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
local PawnManager = sdk.get_managed_singleton("app.PawnManager")

local main_pawn, main_pawn_source = resolve_main_pawn(PawnManager, CharacterManager)
local runtime_character, runtime_character_source = resolve_runtime_character_from_pawn(main_pawn)
local human, human_source = safe_call_method0(runtime_character, { "get_Human()" })
local game_object, game_object_source = safe_call_method0(runtime_character, { "get_GameObject()" })
local chara_id, chara_id_source = safe_call_method0(runtime_character, { "get_CharaID()" })
local current_job, current_job_source, job_context, job_context_source = resolve_current_job(human, runtime_character)
local chain = resolve_decision_chain(runtime_character)

local current_job_number = tonumber(current_job)
local job_marker = current_job_number ~= nil and string.format("job%02d", current_job_number) or nil
local decision_lists = {}
local total_job_marker_hits = 0

for _, spec in ipairs(DECISION_LIST_SPECS) do
    local captured = capture_decision_list(chain.decision_module, spec, job_marker)
    decision_lists[spec.key] = captured
    total_job_marker_hits = total_job_marker_hits + captured.job_marker_hits
end

local output = {
    tag = "main_pawn_decision_list_screen",
    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
    output_note = "Capture current main_pawn DecisionEvaluationModule decision lists. Run once in Job01 and once in Job07, then compare the JSON files.",
    actor = {
        actor_mode = "main_pawn",
        actor_root = serialize_object(main_pawn, main_pawn_source),
        runtime_character = serialize_object(runtime_character, runtime_character_source),
        human = serialize_object(human, human_source),
        game_object = serialize_object(game_object, game_object_source),
        chara_id = serialize_scalar(chara_id, chara_id_source),
        current_job = serialize_scalar(current_job, current_job_source),
        job_context = serialize_object(job_context, job_context_source),
    },
    decision_chain = {
        decision_maker = serialize_object(chain.decision_maker, chain.decision_maker_source),
        decision_module = serialize_object(chain.decision_module, chain.decision_module_source),
        decision_executor = serialize_object(chain.decision_executor, chain.decision_executor_source),
        decision_module_shallow_fields = snapshot_shallow_fields(chain.decision_module, SHALLOW_FIELD_LIMIT),
    },
    summary = {
        current_job = current_job_number,
        decision_module_type = get_type_name(chain.decision_module),
        decision_executor_live = is_present(chain.decision_executor),
        job_marker = job_marker,
        total_job_marker_hits = total_job_marker_hits,
        main_decision_count = decision_lists.main_decisions.count.value,
        pre_decision_count = decision_lists.pre_decisions.count.value,
        post_decision_count = decision_lists.post_decisions.count.value,
    },
    decision_lists = decision_lists,
}

local job_suffix = current_job_number ~= nil and string.format("job%02d", current_job_number) or "job_unknown"
local output_path = "ce_dump/main_pawn_decision_list_screen_" .. job_suffix .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
json.dump_file(output_path, output)
print("[main_pawn_decision_list_screen] wrote " .. output_path)
return output_path
