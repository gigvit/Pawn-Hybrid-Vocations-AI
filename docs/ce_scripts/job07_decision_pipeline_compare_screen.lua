-- Purpose:
-- Compare decision pipeline structure for:
--   1. main_pawn Job07
--   2. Sigurd Job07
-- Output:
--   reframework/data/ce_dump/job07_decision_pipeline_compare_<timestamp>.json

local SIGURD_CHARA_ID = 1108605478
local SHALLOW_FIELD_LIMIT = 24
local RECURSIVE_DEPTH = 3
local RECURSIVE_FIELD_LIMIT = 28

local MODULE_FIELD_NAMES = {
    "_Owner",
    "Owner",
    "<Owner>k__BackingField",
    "_DecisionExecutor",
    "DecisionExecutor",
    "<DecisionExecutor>k__BackingField",
    "_BlackBoardController",
    "BlackBoardController",
    "AIBlackBoardController",
    "<AIBlackBoardController>k__BackingField",
    "_HumanActionSelector",
    "HumanActionSelector",
    "<HumanActionSelector>k__BackingField",
    "_ThinkTable",
    "ThinkTable",
    "<ThinkTable>k__BackingField",
    "_MainDecisions",
    "MainDecisions",
    "_PreDecisions",
    "PreDecisions",
    "_PostDecisions",
    "PostDecisions",
    "_ActiveDecisionPacks",
    "ActiveDecisionPacks",
}

local THINK_TABLE_MODULE_FIELD_NAMES = {
    "<ThinkTableModule>k__BackingField",
    "_ThinkTableModule",
    "ThinkTableModule",
    "<ThinkModule>k__BackingField",
    "_ThinkModule",
    "ThinkModule",
}

local THINK_TABLE_MODULE_METHOD_NAMES = {
    "get_ThinkTableModule()",
    "get_ThinkModule()",
}

local DECISION_EVAL_MODULE_FIELD_NAMES = {
    "<DecisionEvaluationModule>k__BackingField",
    "_DecisionEvaluationModule",
    "DecisionEvaluationModule",
    "<DecisionModule>k__BackingField",
    "_DecisionModule",
    "DecisionModule",
}

local DECISION_EVAL_MODULE_METHOD_NAMES = {
    "get_DecisionEvaluationModule()",
    "get_DecisionModule()",
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

local function get_collection_count(obj)
    if obj == nil then
        return nil
    end

    local count = safe_call_method0(obj, {
        "get_Count()",
        "get_count()",
        "get_Size()",
        "get_size()",
    })
    if count ~= nil then
        return tonumber(count)
    end

    local field_count = safe_field(obj, { "Count", "count", "_size", "size" })
    if field_count ~= nil then
        return tonumber(field_count)
    end

    return nil
end

local function get_collection_item(obj, index)
    return safe_call_method1(obj, {
        "get_Item(System.Int32)",
        "get_Item(System.UInt32)",
        "get_Item",
    }, index)
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

    local field_job, field_job_source = safe_field(actor.runtime_character, { "CurrentJob", "Job" })
    return field_job, "runtime_character:" .. tostring(field_job_source), job_context, job_context_source
end

local function resolve_primary_decision_chain(runtime_character)
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

local function resolve_surface_module(actor, chain, field_names, method_names, expected_type_name)
    local surfaces = {
        { label = "decision_maker", value = chain.decision_maker },
        { label = "runtime_character", value = actor.runtime_character },
        { label = "human", value = actor.human },
        { label = "game_object", value = actor.game_object },
    }

    for _, surface in ipairs(surfaces) do
        local field_value, field_source = safe_field(surface.value, field_names)
        if is_present(field_value) and (expected_type_name == nil or get_type_name(field_value) == expected_type_name) then
            return field_value, surface.label .. ":" .. tostring(field_source)
        end

        local method_value, method_source = safe_call_method0(surface.value, method_names)
        if is_present(method_value) and (expected_type_name == nil or get_type_name(method_value) == expected_type_name) then
            return method_value, surface.label .. ":" .. tostring(method_source)
        end
    end

    return nil, "unresolved"
end

local function build_recursive_pipeline(actor, chain)
    local wanted_types = {
        ["app.AIDecisionMaker"] = "decision_maker",
        ["app.DecisionEvaluationModule"] = "decision_evaluation_module",
        ["app.DecisionExecutor"] = "decision_executor",
        ["app.DecisionEvaluationResult"] = "decision_evaluation_result",
        ["app.ThinkTableModule"] = "think_table_module",
        ["app.ThinkTable"] = "think_table",
        ["app.HumanActionSelector"] = "human_action_selector",
        ["app.AIBlackBoardController"] = "ai_blackboard_controller",
    }

    local out = {}
    for _, root_spec in ipairs({
        { label = actor.actor_mode .. ":runtime_character", value = actor.runtime_character },
        { label = actor.actor_mode .. ":decision_maker", value = chain.decision_maker },
        { label = actor.actor_mode .. ":decision_module", value = chain.decision_module },
    }) do
        recursive_scan(root_spec.value, wanted_types, RECURSIVE_DEPTH, RECURSIVE_FIELD_LIMIT, out, {}, root_spec.label)
    end

    return out
end

local function capture_actor_screen(actor_mode)
    local actor = resolve_actor(actor_mode)
    local current_job, current_job_source, job_context, job_context_source = resolve_current_job(actor)
    local chara_id, chara_id_source = safe_call_method0(actor.runtime_character, { "get_CharaID()" })
    local chain = resolve_primary_decision_chain(actor.runtime_character)
    local think_table_module, think_table_module_source = resolve_surface_module(
        actor,
        chain,
        THINK_TABLE_MODULE_FIELD_NAMES,
        THINK_TABLE_MODULE_METHOD_NAMES,
        "app.ThinkTableModule"
    )
    local decision_evaluation_module, decision_evaluation_module_source = resolve_surface_module(
        actor,
        chain,
        DECISION_EVAL_MODULE_FIELD_NAMES,
        DECISION_EVAL_MODULE_METHOD_NAMES,
        "app.DecisionEvaluationModule"
    )

    return {
        actor_mode = actor_mode,
        actor_root = serialize_object(actor.actor_root, actor.actor_root_source),
        runtime_character = serialize_object(actor.runtime_character, actor.runtime_character_source),
        human = serialize_object(actor.human, actor.human_source),
        game_object = serialize_object(actor.game_object, actor.game_object_source),
        chara_id = serialize_scalar(chara_id, chara_id_source),
        current_job = serialize_scalar(current_job, current_job_source),
        job_context = serialize_object(job_context, job_context_source),
        decision_maker = serialize_object(chain.decision_maker, chain.decision_maker_source),
        decision_module = serialize_object(chain.decision_module, chain.decision_module_source),
        decision_executor = serialize_object(chain.decision_executor, chain.decision_executor_source),
        executing_decision = serialize_object(chain.executing_decision, chain.executing_decision_source),
        think_table_module = serialize_object(think_table_module, think_table_module_source),
        decision_evaluation_module = serialize_object(decision_evaluation_module, decision_evaluation_module_source),
        named_fields = {
            decision_maker = snapshot_named_fields(chain.decision_maker, MODULE_FIELD_NAMES),
            decision_module = snapshot_named_fields(chain.decision_module, MODULE_FIELD_NAMES),
            decision_executor = snapshot_named_fields(chain.decision_executor, MODULE_FIELD_NAMES),
            think_table_module = snapshot_named_fields(think_table_module, MODULE_FIELD_NAMES),
            decision_evaluation_module = snapshot_named_fields(decision_evaluation_module, MODULE_FIELD_NAMES),
        },
        shallow_field_snapshots = {
            decision_maker = snapshot_shallow_fields(chain.decision_maker, SHALLOW_FIELD_LIMIT),
            decision_module = snapshot_shallow_fields(chain.decision_module, SHALLOW_FIELD_LIMIT),
            decision_executor = snapshot_shallow_fields(chain.decision_executor, SHALLOW_FIELD_LIMIT),
            think_table_module = snapshot_shallow_fields(think_table_module, SHALLOW_FIELD_LIMIT),
            decision_evaluation_module = snapshot_shallow_fields(decision_evaluation_module, SHALLOW_FIELD_LIMIT),
        },
        recursive_pipeline = build_recursive_pipeline(actor, chain),
    }
end

local function build_compare_summary(main_pawn, sigurd)
    local main_pawn_job = tonumber(main_pawn.current_job.value)
    local sigurd_job = tonumber(sigurd.current_job.value)
    local main_pawn_primary_type = main_pawn.decision_module.type_name
    local sigurd_primary_type = sigurd.decision_module.type_name
    local main_pawn_has_recursive_thinktable = main_pawn.recursive_pipeline.think_table_module ~= nil
    local sigurd_has_recursive_decision_eval = sigurd.recursive_pipeline.decision_evaluation_module ~= nil
    local main_pawn_has_surface_thinktable = main_pawn.think_table_module.present
    local sigurd_has_surface_thinktable = sigurd.think_table_module.present
    local main_pawn_has_surface_decision_eval = main_pawn.decision_evaluation_module.present
    local sigurd_has_surface_decision_eval = sigurd.decision_evaluation_module.present
    local main_pawn_has_any_thinktable = main_pawn_has_surface_thinktable or main_pawn_has_recursive_thinktable
    local sigurd_has_any_decision_eval = sigurd_has_surface_decision_eval or sigurd_has_recursive_decision_eval
    local interpretation = "unresolved"

    if not main_pawn.runtime_character.present or not sigurd.runtime_character.present then
        interpretation = "actor_missing_in_scene"
    elseif main_pawn_job ~= 7 or sigurd_job ~= 7 then
        interpretation = "actor_not_in_job07"
    elseif sigurd_primary_type == "app.ThinkTableModule" and main_pawn_primary_type ~= "app.ThinkTableModule" then
        if main_pawn_has_any_thinktable then
            interpretation = "main_pawn_not_routed_to_thinktable_module"
        else
            interpretation = "main_pawn_thinktable_module_not_found"
        end
    elseif main_pawn_primary_type == "app.DecisionEvaluationModule" and not main_pawn.decision_executor.present then
        interpretation = "main_pawn_decision_executor_missing"
    elseif sigurd_primary_type == "app.ThinkTableModule" and sigurd_has_any_decision_eval then
        interpretation = "sigurd_has_dual_pipeline_surface"
    elseif main_pawn_primary_type == sigurd_primary_type then
        interpretation = "no_primary_decision_module_gap_in_this_scene"
    end

    return {
        main_pawn_loaded = main_pawn.runtime_character.present,
        sigurd_loaded = sigurd.runtime_character.present,
        both_loaded = main_pawn.runtime_character.present and sigurd.runtime_character.present,
        main_pawn_job = main_pawn_job,
        sigurd_job = sigurd_job,
        main_pawn_primary_module_type = main_pawn_primary_type,
        sigurd_primary_module_type = sigurd_primary_type,
        main_pawn_decision_executor_live = main_pawn.decision_executor.present,
        sigurd_decision_executor_live = sigurd.decision_executor.present,
        main_pawn_executing_decision_live = main_pawn.executing_decision.present,
        sigurd_executing_decision_live = sigurd.executing_decision.present,
        main_pawn_surface_has_thinktable_module = main_pawn_has_surface_thinktable,
        sigurd_surface_has_thinktable_module = sigurd_has_surface_thinktable,
        main_pawn_surface_has_decision_evaluation_module = main_pawn_has_surface_decision_eval,
        sigurd_surface_has_decision_evaluation_module = sigurd_has_surface_decision_eval,
        main_pawn_recursive_has_thinktable_module = main_pawn_has_recursive_thinktable,
        sigurd_recursive_has_thinktable_module = sigurd.recursive_pipeline.think_table_module ~= nil,
        main_pawn_recursive_has_decision_evaluation_module = main_pawn.recursive_pipeline.decision_evaluation_module ~= nil,
        sigurd_recursive_has_decision_evaluation_module = sigurd_has_recursive_decision_eval,
        interpretation = interpretation,
    }
end

local main_pawn = capture_actor_screen("main_pawn")
local sigurd = capture_actor_screen("sigurd")

local output = {
    tag = "job07_decision_pipeline_compare",
    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
    output_note = "Compare decision pipeline structure for main_pawn Job07 versus Sigurd Job07.",
    compare = {
        main_pawn = main_pawn,
        sigurd = sigurd,
    },
    summary = build_compare_summary(main_pawn, sigurd),
}

local output_path = "ce_dump/job07_decision_pipeline_compare_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
json.dump_file(output_path, output)
print("[job07_decision_pipeline_compare] wrote " .. output_path)
return output_path
