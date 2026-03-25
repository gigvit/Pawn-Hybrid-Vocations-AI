-- Purpose:
-- Capture a timed burst for compare scenarios:
--   1. main_pawn Job01
--   2. main_pawn Job07
--   3. Sigurd Job07
-- Output:
--   reframework/data/ce_dump/actor_burst_combat_trace_<trace_label>_<timestamp>.json
--
-- Presets:
--   main_pawn Job01:
--     TRACE_LABEL = "main_pawn_job01"
--     ACTOR_MODE = "main_pawn"
--     EXPECTED_JOB = 1
--
--   main_pawn Job07:
--     TRACE_LABEL = "main_pawn_job07"
--     ACTOR_MODE = "main_pawn"
--     EXPECTED_JOB = 7
--
--   Sigurd Job07:
--     TRACE_LABEL = "sigurd_job07"
--     ACTOR_MODE = "sigurd"
--     EXPECTED_JOB = 7

local GLOBAL_KEY = "__actor_burst_combat_trace_state_v2"
local TRACE_LABEL = "main_pawn_job01"
local ACTOR_MODE = "main_pawn"
local EXPECTED_JOB = 1
local SIGURD_CHARA_ID = 1108605478
local SAMPLE_INTERVAL_SECONDS = 0.75
local DURATION_SECONDS = 15.0
local MAX_SAMPLES = 24

local JOB_CONTROLLER_MAP = {
    [7] = {
        getter = "get_Job07ActionCtrl()",
        field = "<Job07ActionCtrl>k__BackingField",
    },
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

local function get_game_object_name(game_object)
    if not is_present(game_object) then
        return nil
    end

    local name, _ = safe_call_method0(game_object, { "get_Name()" })
    return name
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
    local all_characters, all_characters_source = safe_call_method0(holder, {
        "getAllCharacters()",
    })
    local count = get_collection_count(all_characters)
    if count == nil then
        return nil, "character_list_unresolved"
    end

    for index = 0, count - 1 do
        local character, item_source = get_collection_item(all_characters, index)
        local chara_id, chara_id_source = safe_call_method0(character, {
            "get_CharaID()",
        })
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
    local current_job, current_job_source = safe_field(actor.human, {
        "<CurrentJob>k__BackingField",
    })
    if current_job ~= nil then
        return current_job, "human:" .. tostring(current_job_source)
    end

    local job_context, job_context_source = safe_field(actor.human, {
        "<JobContext>k__BackingField",
        "JobContext",
    })
    local job_context_job, job_context_job_source = safe_field(job_context, {
        "CurrentJob",
    })
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

    local ctrl_field, ctrl_field_source = safe_field(human, {
        mapping.field,
    })
    if is_present(ctrl_field) then
        return ctrl_field, "human:" .. tostring(ctrl_field_source)
    end

    if mapping.getter ~= nil then
        local ctrl_getter, ctrl_getter_source = safe_call_method0(human, {
            mapping.getter,
        })
        if is_present(ctrl_getter) then
            return ctrl_getter, "human:" .. tostring(ctrl_getter_source)
        end
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

local function classify_sample(sample, expected_job)
    local current_job = tonumber(sample.current_job.value)
    local pack_path = tostring(sample.decision_pack_path.value or "nil")
    local target_type = tostring(sample.decision_target.type_name or "nil")
    local full_node = tostring(sample.full_node.value or "nil")
    local job_token = current_job ~= nil and string.format("Job%02d", current_job) or nil

    if not sample.runtime_character.present then
        return "actor_unresolved"
    end
    if expected_job ~= nil and current_job ~= expected_job then
        return "unexpected_job"
    end
    if not sample.executing_decision.present then
        return "no_executing_decision"
    end
    if string.find(pack_path, "Common/InForcedAnimation.user", 1, true) ~= nil or string.find(full_node, "Damage.", 1, true) ~= nil then
        return "common_forced_damage"
    end
    if job_token ~= nil then
        if string.find(pack_path, job_token, 1, true) ~= nil or string.find(full_node, job_token .. "_", 1, true) ~= nil then
            return "job_specific_candidate"
        end
    end
    if target_type == "app.AITargetPosition" then
        return "position_target_navigation"
    end
    if target_type == "app.Character" and string.find(pack_path, "Common/MoveToPosition_Walk_Target.user", 1, true) ~= nil then
        return "character_common_move"
    end
    if target_type == "app.Character" and string.find(full_node, "Locomotion.", 1, true) ~= nil then
        return "character_locomotion_other"
    end
    if target_type == "app.Character" then
        return "character_non_generic_candidate"
    end

    return "other"
end

local function build_signature(sample)
    return table.concat({
        tostring(sample.current_job.value or "nil"),
        tostring(sample.decision_target.type_name or "nil"),
        tostring(sample.decision_pack_path.value or "nil"),
        tostring(sample.full_node.value or "nil"),
        tostring(sample.upper_node.value or "nil"),
    }, " | ")
end

local function bump(map, key)
    local name = tostring(key or "nil")
    map[name] = (map[name] or 0) + 1
end

local function capture_sample(now, started_at, recorder)
    local actor = resolve_actor(recorder.actor_mode)
    local current_job, current_job_source, job_context, job_context_source = resolve_current_job(actor)
    local action_manager, action_manager_source = safe_call_method0(actor.runtime_character, { "get_ActionManager()" })
    local ai_blackboard, ai_blackboard_source = safe_call_method0(actor.runtime_character, { "get_AIBlackBoardController()" })
    local human_action_selector, human_action_selector_source = safe_field(actor.human, {
        "<HumanActionSelector>k__BackingField",
        "<CommonActionSelector>k__BackingField",
    })
    local job_specific_action_ctrl, job_specific_action_ctrl_source = resolve_job_specific_action_ctrl(actor.human, current_job)
    local decision_maker, decision_maker_source = safe_field(actor.runtime_character, { "<AIDecisionMaker>k__BackingField", "AIDecisionMaker" })
    local decision_module, decision_module_source = safe_field(decision_maker, { "<DecisionModule>k__BackingField", "DecisionModule" })
    local decision_executor, decision_executor_source = safe_field(decision_module, { "<DecisionExecutor>k__BackingField", "DecisionExecutor" })
    local executing_decision, executing_decision_source = safe_field(decision_executor, { "<ExecutingDecision>k__BackingField", "ExecutingDecision" })
    local decision_target, decision_target_source = resolve_decision_target(executing_decision)
    local decision_pack_path, decision_pack_path_source = resolve_decision_pack_path(decision_module, executing_decision)
    local full_node, full_node_source = get_fsm_node_name(action_manager, 0)
    local upper_node, upper_node_source = get_fsm_node_name(action_manager, 1)
    local current_action, current_action_source = safe_field(action_manager, { "CurrentAction" })
    local selected_request, selected_request_source = safe_field(action_manager, { "SelectedRequest" })

    local sample = {
        captured_at = os.date("%Y-%m-%d %H:%M:%S"),
        elapsed_seconds = round3(now - started_at),
        trace_label = recorder.trace_label,
        actor_mode = recorder.actor_mode,
        expected_job = recorder.expected_job,
        actor_root = serialize_object(actor.actor_root, actor.actor_root_source),
        runtime_character = serialize_object(actor.runtime_character, actor.runtime_character_source),
        human = serialize_object(actor.human, actor.human_source),
        game_object = serialize_object(actor.game_object, actor.game_object_source),
        game_object_name = actor.game_object_name,
        current_job = serialize_scalar(current_job, current_job_source),
        job_context = serialize_object(job_context, job_context_source),
        human_action_selector = serialize_object(human_action_selector, human_action_selector_source),
        job_specific_action_ctrl = serialize_object(job_specific_action_ctrl, job_specific_action_ctrl_source),
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
    }

    sample.classification = classify_sample(sample, recorder.expected_job)
    sample.signature = build_signature(sample)
    return sample
end

local function build_summary(samples, recorder, finish_reason)
    local classifications = {}
    local pack_paths = {}
    local target_types = {}
    local full_nodes = {}
    local upper_nodes = {}
    local signatures = {}
    local transitions = {}
    local current_jobs = {}
    local actor_names = {}
    local common_move_samples = 0
    local common_forced_damage_samples = 0
    local job_specific_candidate_samples = 0
    local unexpected_job_samples = 0
    local decision_pack_source_samples = 0
    local execute_actinter_source_samples = 0
    local executing_decision_live_any = false

    local previous_signature = nil
    for index, sample in ipairs(samples) do
        local target_type = tostring(sample.decision_target.type_name or "nil")
        local pack_path = tostring(sample.decision_pack_path.value or "nil")
        local full_node = tostring(sample.full_node.value or "nil")
        local upper_node = tostring(sample.upper_node.value or "nil")
        local pack_source = tostring(sample.decision_pack_path.source or "nil")
        local current_job = tostring(sample.current_job.value or "nil")

        bump(classifications, sample.classification)
        bump(pack_paths, pack_path)
        bump(target_types, target_type)
        bump(full_nodes, full_node)
        bump(upper_nodes, upper_node)
        bump(signatures, sample.signature)
        bump(current_jobs, current_job)
        bump(actor_names, sample.game_object_name or "nil")

        if sample.classification == "character_common_move" then
            common_move_samples = common_move_samples + 1
        elseif sample.classification == "common_forced_damage" then
            common_forced_damage_samples = common_forced_damage_samples + 1
        elseif sample.classification == "job_specific_candidate" then
            job_specific_candidate_samples = job_specific_candidate_samples + 1
        elseif sample.classification == "unexpected_job" then
            unexpected_job_samples = unexpected_job_samples + 1
        end

        if string.find(pack_source, "execute_actinter:", 1, true) == 1 then
            execute_actinter_source_samples = execute_actinter_source_samples + 1
        elseif string.find(pack_source, "decision_pack:", 1, true) == 1 then
            decision_pack_source_samples = decision_pack_source_samples + 1
        end

        if sample.executing_decision.present then
            executing_decision_live_any = true
        end

        if previous_signature ~= nil and previous_signature ~= sample.signature then
            table.insert(transitions, {
                sample_index = index,
                elapsed_seconds = sample.elapsed_seconds,
                from_signature = previous_signature,
                to_signature = sample.signature,
            })
        end
        previous_signature = sample.signature
    end

    return {
        trace_label = recorder.trace_label,
        actor_mode = recorder.actor_mode,
        expected_job = recorder.expected_job,
        finish_reason = finish_reason,
        sample_count = #samples,
        common_move_samples = common_move_samples,
        common_forced_damage_samples = common_forced_damage_samples,
        job_specific_candidate_samples = job_specific_candidate_samples,
        unexpected_job_samples = unexpected_job_samples,
        decision_pack_source_samples = decision_pack_source_samples,
        execute_actinter_source_samples = execute_actinter_source_samples,
        executing_decision_live_any = executing_decision_live_any,
        classifications = classifications,
        current_jobs = current_jobs,
        actor_names = actor_names,
        pack_paths = pack_paths,
        target_types = target_types,
        full_nodes = full_nodes,
        upper_nodes = upper_nodes,
        signatures = signatures,
        transitions = transitions,
    }
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
        tag = "actor_burst_combat_trace",
        generated_at = os.date("%Y-%m-%d %H:%M:%S"),
        config = {
            trace_label = recorder.trace_label,
            actor_mode = recorder.actor_mode,
            expected_job = recorder.expected_job,
            sample_interval_seconds = recorder.sample_interval_seconds,
            duration_seconds = recorder.duration_seconds,
            max_samples = recorder.max_samples,
            sigurd_chara_id = SIGURD_CHARA_ID,
        },
        started_at = recorder.started_at_real,
        summary = build_summary(recorder.samples, recorder, reason),
        samples = recorder.samples,
    }

    local output_path = string.format(
        "ce_dump/actor_burst_combat_trace_%s_%s.json",
        tostring(recorder.trace_label),
        os.date("%Y%m%d_%H%M%S")
    )
    json.dump_file(output_path, output)
    state.last_output_path = output_path
    state.recorder = nil
    print("[actor_burst_combat_trace] wrote " .. output_path)
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
            table.insert(recorder.samples, capture_sample(now, recorder.started_at, recorder))
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
    actor_mode = ACTOR_MODE,
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
    "[actor_burst_combat_trace] started trace=%s actor=%s expected_job=%s interval=%.2fs duration=%.2fs max_samples=%d",
    tostring(TRACE_LABEL),
    tostring(ACTOR_MODE),
    tostring(EXPECTED_JOB),
    SAMPLE_INTERVAL_SECONDS,
    DURATION_SECONDS,
    MAX_SAMPLES
))
print("[actor_burst_combat_trace] keep playing; result will be written to ce_dump automatically")
return "actor_burst_combat_trace_started"
