-- Purpose:
-- Capture a short timed burst of main_pawn Job07 combat state without manual phase timing.
-- Output:
--   reframework/data/ce_dump/job07_burst_combat_trace_<timestamp>.json

local GLOBAL_KEY = "__job07_burst_combat_trace_state"
local SAMPLE_INTERVAL_SECONDS = 0.75
local DURATION_SECONDS = 15.0
local MAX_SAMPLES = 24

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

local function classify_sample(sample)
    local current_job = tonumber(sample.current_job.value)
    local pack_path = tostring(sample.decision_pack_path.value or "nil")
    local target_type = tostring(sample.decision_target.type_name or "nil")
    local full_node = tostring(sample.full_node.value or "nil")

    if current_job ~= 7 then
        return "not_job07"
    end
    if not sample.job07_action_ctrl_field.present and not sample.job07_action_ctrl_getter.present then
        return "job07_ctrl_missing"
    end
    if not sample.executing_decision.present then
        return "no_executing_decision"
    end
    if string.find(pack_path, "Common/InForcedAnimation.user", 1, true) ~= nil or string.find(full_node, "Damage.", 1, true) ~= nil then
        return "common_forced_damage"
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

local function capture_sample(now, started_at)
    local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
    local PawnManager = sdk.get_managed_singleton("app.PawnManager")

    local main_pawn, main_pawn_source = resolve_main_pawn(PawnManager, CharacterManager)
    local runtime_character, runtime_character_source = resolve_runtime_character(main_pawn)
    local human, human_source = safe_call_method0(runtime_character, { "get_Human()" })
    local action_manager, action_manager_source = safe_call_method0(runtime_character, { "get_ActionManager()" })
    local ai_blackboard, ai_blackboard_source = safe_call_method0(runtime_character, { "get_AIBlackBoardController()" })
    local job_context, job_context_source = safe_field(human, { "<JobContext>k__BackingField" })
    local current_job, current_job_source = safe_field(job_context, { "CurrentJob" })
    if current_job == nil then
        current_job, current_job_source = safe_field(runtime_character, { "Job" })
    end

    local job07_action_ctrl_field, job07_action_ctrl_field_source = safe_field(human, { "<Job07ActionCtrl>k__BackingField" })
    local job07_action_ctrl_getter, job07_action_ctrl_getter_source = safe_call_method0(human, { "get_Job07ActionCtrl()" })
    local decision_maker, decision_maker_source = safe_field(runtime_character, { "<AIDecisionMaker>k__BackingField", "AIDecisionMaker" })
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
        main_pawn = serialize_object(main_pawn, main_pawn_source),
        runtime_character = serialize_object(runtime_character, runtime_character_source),
        human = serialize_object(human, human_source),
        current_job = serialize_scalar(current_job, current_job_source),
        job_context = serialize_object(job_context, job_context_source),
        job07_action_ctrl_field = serialize_object(job07_action_ctrl_field, job07_action_ctrl_field_source),
        job07_action_ctrl_getter = serialize_object(job07_action_ctrl_getter, job07_action_ctrl_getter_source),
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

    sample.classification = classify_sample(sample)
    sample.signature = build_signature(sample)
    return sample
end

local function build_summary(samples, finish_reason)
    local classifications = {}
    local pack_paths = {}
    local target_types = {}
    local full_nodes = {}
    local upper_nodes = {}
    local signatures = {}
    local transitions = {}
    local first_character_sample_index = nil
    local first_non_common_pack_sample_index = nil
    local first_non_locomotion_sample_index = nil
    local character_target_samples = 0
    local position_target_samples = 0
    local common_move_pack_samples = 0
    local non_common_pack_samples = 0
    local execute_actinter_source_samples = 0
    local decision_pack_source_samples = 0
    local controller_live_all_samples = true
    local executing_decision_live_any = false

    local previous_signature = nil
    for index, sample in ipairs(samples) do
        local target_type = tostring(sample.decision_target.type_name or "nil")
        local pack_path = tostring(sample.decision_pack_path.value or "nil")
        local full_node = tostring(sample.full_node.value or "nil")
        local upper_node = tostring(sample.upper_node.value or "nil")
        local pack_source = tostring(sample.decision_pack_path.source or "nil")

        bump(classifications, sample.classification)
        bump(pack_paths, pack_path)
        bump(target_types, target_type)
        bump(full_nodes, full_node)
        bump(upper_nodes, upper_node)
        bump(signatures, sample.signature)

        if target_type == "app.Character" then
            character_target_samples = character_target_samples + 1
            if first_character_sample_index == nil then
                first_character_sample_index = index
            end
        elseif target_type == "app.AITargetPosition" then
            position_target_samples = position_target_samples + 1
        end

        if string.find(pack_path, "Common/MoveToPosition_Walk_Target.user", 1, true) ~= nil then
            common_move_pack_samples = common_move_pack_samples + 1
        elseif pack_path ~= "nil" then
            non_common_pack_samples = non_common_pack_samples + 1
            if first_non_common_pack_sample_index == nil then
                first_non_common_pack_sample_index = index
            end
        end

        if full_node ~= "nil" and string.find(full_node, "Locomotion.", 1, true) == nil then
            if first_non_locomotion_sample_index == nil then
                first_non_locomotion_sample_index = index
            end
        end

        if string.find(pack_source, "execute_actinter:", 1, true) == 1 then
            execute_actinter_source_samples = execute_actinter_source_samples + 1
        end
        if string.find(pack_source, "decision_pack:", 1, true) == 1 then
            decision_pack_source_samples = decision_pack_source_samples + 1
        end

        if not sample.job07_action_ctrl_field.present and not sample.job07_action_ctrl_getter.present then
            controller_live_all_samples = false
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
        finish_reason = finish_reason,
        sample_count = #samples,
        character_target_samples = character_target_samples,
        position_target_samples = position_target_samples,
        common_move_pack_samples = common_move_pack_samples,
        non_common_pack_samples = non_common_pack_samples,
        execute_actinter_source_samples = execute_actinter_source_samples,
        decision_pack_source_samples = decision_pack_source_samples,
        controller_live_all_samples = controller_live_all_samples,
        executing_decision_live_any = executing_decision_live_any,
        first_character_sample_index = first_character_sample_index,
        first_non_common_pack_sample_index = first_non_common_pack_sample_index,
        first_non_locomotion_sample_index = first_non_locomotion_sample_index,
        classifications = classifications,
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
        tag = "job07_burst_combat_trace",
        generated_at = os.date("%Y-%m-%d %H:%M:%S"),
        config = {
            sample_interval_seconds = recorder.sample_interval_seconds,
            duration_seconds = recorder.duration_seconds,
            max_samples = recorder.max_samples,
        },
        started_at = recorder.started_at_real,
        summary = build_summary(recorder.samples, reason),
        samples = recorder.samples,
    }

    local output_path = "ce_dump/job07_burst_combat_trace_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
    json.dump_file(output_path, output)
    state.last_output_path = output_path
    state.recorder = nil
    print("[job07_burst_combat_trace] wrote " .. output_path)
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
            table.insert(recorder.samples, capture_sample(now, recorder.started_at))
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
    started_at = nil,
    next_sample_at = nil,
    started_at_real = os.date("%Y-%m-%d %H:%M:%S"),
    sample_interval_seconds = SAMPLE_INTERVAL_SECONDS,
    duration_seconds = DURATION_SECONDS,
    max_samples = MAX_SAMPLES,
    samples = {},
}

print(string.format(
    "[job07_burst_combat_trace] started interval=%.2fs duration=%.2fs max_samples=%d",
    SAMPLE_INTERVAL_SECONDS,
    DURATION_SECONDS,
    MAX_SAMPLES
))
print("[job07_burst_combat_trace] keep playing; result will be written to ce_dump automatically")
return "job07_burst_combat_trace_started"
