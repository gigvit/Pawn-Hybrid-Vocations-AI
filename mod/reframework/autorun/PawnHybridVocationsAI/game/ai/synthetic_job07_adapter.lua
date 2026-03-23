local config = require("PawnHybridVocationsAI/config")
local log = require("PawnHybridVocationsAI/core/log")
local util = require("PawnHybridVocationsAI/core/util")
local job07_sigurd_profile = require("PawnHybridVocationsAI/game/ai/job07_sigurd_profile")

local synthetic_job07_adapter = {}

local ACTINTER_EXECUTE_SIGNATURE = "setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)"
local ACTINTER_REQMAIN_SIGNATURE = "set_ReqMainActInterPackData(app.ActInterPackData)"
local REQUEST_SKIP_THINK_SIGNATURE = "requestSkipThink()"
local DEFAULT_ENGAGE_PACK_PATH = job07_sigurd_profile.default_engage_pack_path()
local DEFAULT_IDLE_RELEASE_PACK_PATH = job07_sigurd_profile.default_idle_release_pack_path()
local DEFAULT_ATTACK_PACK_PATH = job07_sigurd_profile.default_attack_pack_path()

local function adapter_config()
    return config.synthetic_job07_adapter or {}
end

local function adapter_enabled()
    local ai = config.ai or {}
    local adapter = adapter_config()
    return ai.enable_runtime_adapters == true
        and ai.enable_synthetic_layer == true
        and adapter.enabled == true
end

local function get_data(runtime)
    runtime.synthetic_job07_adapter_data = runtime.synthetic_job07_adapter_data or {
        enabled = false,
        attempt_count = 0,
        apply_count = 0,
        engage_apply_count = 0,
        skip_count = 0,
        fail_count = 0,
        last_status = "idle",
        last_reason = "idle",
        last_phase = "idle",
        last_pack_path = "nil",
        last_pack_family = "nil",
        last_target = "nil",
        last_target_type = "nil",
        last_target_distance = nil,
        last_signature = "nil",
        last_apply_time = nil,
        last_engage_signature = "nil",
        last_engage_time = nil,
        last_attack_key = "nil",
        last_attack_pack_path = "nil",
        last_skip_think_method_source = "unresolved",
        skip_reason_counts = {},
        observation_active = false,
        observation_ticks_remaining = 0,
        observation_tick = 0,
        observation_pack_path = "nil",
        observation_pack_family = "nil",
        observation_nodes = "nil|nil",
        observation_first_job07_tick = -1,
        observation_first_job07_pack_path = "nil",
        observation_first_job07_nodes = "nil|nil",
        observation_first_generic_tick = -1,
        observation_first_generic_pack_path = "nil",
        observation_first_generic_nodes = "nil|nil",
        hold_active = false,
        hold_since_time = nil,
        hold_target = nil,
        hold_reason = "none",
        methods = {
            exec_method = nil,
            reqmain_method = nil,
            skip_think_method = nil,
        },
    }
    runtime.synthetic_job07_adapter_data.enabled = adapter_enabled()
    return runtime.synthetic_job07_adapter_data
end

local function to_number(value)
    if value == nil then
        return nil
    end

    local direct = tonumber(value)
    if direct ~= nil then
        return direct
    end

    return util.decode_numeric_like(value)
end

local function classify_pack_family(path)
    local text = tostring(path or "nil")
    if text == "nil" or text == "" then
        return "nil"
    end
    if text:find("NPC/Job07/", 1, true) then
        return "npc_job07"
    end
    if text:find("/Job07/", 1, true) then
        return "job07"
    end
    if text:find("/Common/", 1, true) then
        return "common"
    end
    if text:find("/ch1/", 1, true) then
        return "ch1"
    end
    if text:find("/GenericJob/", 1, true) then
        return "generic_job"
    end
    return "other"
end

local function is_social_pack_path(path)
    local text = tostring(path or "nil")
    if text == "nil" then
        return false
    end

    return text:find("HighFive", 1, true) ~= nil
        or text:find("Chilling", 1, true) ~= nil
        or text:find("LookAt", 1, true) ~= nil
        or text:find("Talking", 1, true) ~= nil
        or text:find("SortItem", 1, true) ~= nil
        or text:find("TreasureBox", 1, true) ~= nil
        or text:find("Greeting", 1, true) ~= nil
end

local function resolve_position(obj)
    if not util.is_valid_obj(obj) then
        return nil
    end

    local transform = util.safe_direct_method(obj, "get_Transform")
        or util.safe_method(obj, "get_Transform()")
        or util.safe_method(obj, "get_Transform")
    if transform ~= nil then
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
    if ok then
        return tonumber(distance)
    end

    return nil
end

local function get_phase_entries()
    return job07_sigurd_profile.phase_entries(adapter_config())
end

local function select_phase_entry(distance, last_phase_key)
    if type(distance) ~= "number" then
        return nil, {}
    end

    local entries = get_phase_entries()
    local candidates = {}
    for _, entry in ipairs(entries) do
        if tostring(entry.mode or "attack") ~= "release" then
            local min_distance = tonumber(entry.min_distance) or 0.0
            local max_distance = tonumber(entry.max_distance)
            local in_range = distance >= min_distance
            if max_distance ~= nil then
                in_range = in_range and distance <= max_distance
            end
            if in_range then
                table.insert(candidates, entry)
            end
        end
    end

    if #candidates == 0 then
        return nil, candidates
    end

    local selected_index = 1
    if adapter_config().rotate_attacks ~= false and type(last_phase_key) == "string" and last_phase_key ~= "" and last_phase_key ~= "nil" then
        for index, candidate in ipairs(candidates) do
            if tostring(candidate.key or "nil") == last_phase_key then
                selected_index = index + 1
                if selected_index > #candidates then
                    selected_index = 1
                end
                break
            end
        end
    end

    return candidates[selected_index], candidates
end

local function describe_phase_candidates(candidates)
    local values = {}
    for _, candidate in ipairs(candidates or {}) do
        table.insert(values, tostring(candidate.key or candidate.pack_path or "nil"))
    end

    if #values == 0 then
        return "none"
    end

    return table.concat(values, ",")
end

local function append_skip(runtime, data, reason, payload)
    local limit = tonumber(adapter_config().skip_log_limit) or 8
    data.skip_reason_counts[reason] = (data.skip_reason_counts[reason] or 0) + 1
    data.skip_count = data.skip_count + 1
    data.last_status = "skipped"
    data.last_reason = tostring(reason)

    if data.skip_reason_counts[reason] > limit then
        return
    end

    payload = payload or {}
    payload.reason = tostring(reason)
    payload.skip_count = data.skip_reason_counts[reason]
    log.session_marker(runtime, "adapter", "synthetic_job07_adapter_skipped", payload, string.format(
        "reason=%s count=%s pack=%s target=%s",
        tostring(reason),
        tostring(payload.skip_count),
        tostring(payload.current_pack_path or "nil"),
        tostring(payload.target or "nil")
    ))
end

local function append_failed(runtime, data, reason, payload)
    data.fail_count = data.fail_count + 1
    data.last_status = "failed"
    data.last_reason = tostring(reason)
    payload = payload or {}
    payload.reason = tostring(reason)
    log.session_marker(runtime, "adapter", "synthetic_job07_adapter_failed", payload, string.format(
        "reason=%s pack=%s target=%s",
        tostring(reason),
        tostring(payload.pack_path or payload.current_pack_path or "nil"),
        tostring(payload.target or "nil")
    ))
end

local function resolve_main_pawn_context(runtime)
    local main_pawn = runtime.main_pawn_data
    if main_pawn == nil then
        return nil, "main_pawn_data_unresolved"
    end

    local runtime_character = main_pawn.runtime_character
    if runtime_character == nil then
        return nil, "main_pawn_runtime_character_unresolved"
    end

    local human = main_pawn.human or util.safe_method(runtime_character, "get_Human")
    if human == nil then
        return nil, "main_pawn_human_unresolved"
    end

    local current_job = to_number(main_pawn.current_job or main_pawn.job or util.safe_method(runtime_character, "get_CurrentJob"))
    if current_job ~= tonumber(adapter_config().target_job or 7) then
        return nil, "main_pawn_not_target_job"
    end

    local ai_decision_maker = util.safe_direct_method(runtime_character, "get_AIDecisionMaker")
        or util.safe_method(runtime_character, "get_AIDecisionMaker()")
        or util.safe_method(runtime_character, "get_AIDecisionMaker")
    local decision_module = ai_decision_maker and (
        util.safe_direct_method(ai_decision_maker, "get_DecisionModule")
        or util.safe_method(ai_decision_maker, "get_DecisionModule()")
        or util.safe_field(ai_decision_maker, "<DecisionModule>k__BackingField")
    ) or nil
    local ai_blackboard = util.safe_direct_method(runtime_character, "get_AIBlackBoardController")
        or util.safe_method(runtime_character, "get_AIBlackBoardController()")
        or util.safe_field(runtime_character, "<AIBlackBoardController>k__BackingField")

    return {
        pawn = main_pawn.pawn,
        runtime_character = runtime_character,
        human = human,
        current_job = current_job,
        decision_module = decision_module,
        ai_blackboard = ai_blackboard,
        full_node = main_pawn.full_node,
        upper_node = main_pawn.upper_node,
    }, nil
end

local function resolve_current_pack_path(runtime, context)
    local summary = runtime.action_research_data and runtime.action_research_data.summary or nil
    local pack_path = summary and summary.main_pawn_current_execute_actinter_pack_path or nil
    if pack_path == nil or tostring(pack_path) == "nil" then
        pack_path = summary and summary.main_pawn_last_observed_actinter_pack_path or nil
    end
    if pack_path ~= nil and tostring(pack_path) ~= "nil" then
        return tostring(pack_path)
    end

    local decision_module = context and context.decision_module or nil
    local execute_actinter = decision_module and util.safe_field(decision_module, "_ExecuteActInter") or nil
    local execute_pack = execute_actinter and (
        util.safe_direct_method(execute_actinter, "get_ActInterPackData")
        or util.safe_method(execute_actinter, "get_ActInterPackData()")
    ) or nil
    local direct_pack_path = execute_pack and (
        util.safe_direct_method(execute_pack, "get_Path")
        or util.safe_method(execute_pack, "get_Path()")
    ) or nil
    return direct_pack_path ~= nil and tostring(direct_pack_path) or "nil"
end

local function resolve_decision_target(runtime_character)
    if runtime_character == nil then
        return nil, "runtime_character_unresolved"
    end

    local ai_decision_maker = util.safe_direct_method(runtime_character, "get_AIDecisionMaker")
        or util.safe_method(runtime_character, "get_AIDecisionMaker()")
        or util.safe_method(runtime_character, "get_AIDecisionMaker")
    if ai_decision_maker == nil then
        return nil, "ai_decision_maker_unresolved"
    end

    local decision_module = util.safe_direct_method(ai_decision_maker, "get_DecisionModule")
        or util.safe_method(ai_decision_maker, "get_DecisionModule()")
        or util.safe_field(ai_decision_maker, "<DecisionModule>k__BackingField")
    if decision_module == nil then
        return nil, "decision_module_unresolved"
    end

    local decision_executor = util.safe_direct_method(decision_module, "get_DecisionExecutor")
        or util.safe_method(decision_module, "get_DecisionExecutor()")
        or util.safe_field(decision_module, "<DecisionExecutor>k__BackingField")
        or util.safe_field(decision_module, "_DecisionExecutor")
    if decision_executor == nil then
        return nil, "decision_executor_unresolved"
    end

    local executing_decision = util.safe_direct_method(decision_executor, "get_ExecutingDecision")
        or util.safe_method(decision_executor, "get_ExecutingDecision()")
        or util.safe_field(decision_executor, "<ExecutingDecision>k__BackingField")
        or util.safe_field(decision_executor, "_ExecutingDecision")
    if executing_decision == nil then
        return nil, "executing_decision_unresolved"
    end

    local ai_target = util.safe_field(executing_decision, "<Target>k__BackingField")
    if ai_target == nil then
        return nil, "decision_target_unresolved"
    end

    local target = util.safe_field(ai_target, "<Character>k__BackingField")
        or util.safe_field(ai_target, "<OwnerCharacter>k__BackingField")
        or util.safe_direct_method(ai_target, "get_Character")
        or util.safe_method(ai_target, "get_Character()")
    if not util.is_valid_obj(target) then
        return nil, "decision_target_character_unresolved"
    end

    return target, "executing_decision_target"
end

local function create_ai_target(target)
    if target == nil then
        return nil
    end

    local ok, ai_target = pcall(sdk.create_instance, "app.AITargetGameObject", true)
    if not ok or ai_target == nil then
        return nil
    end

    local game_object = util.safe_method(target, "get_GameObject")
    util.safe_set_field(ai_target, "<GameObject>k__BackingField", game_object)
    util.safe_set_field(ai_target, "<Character>k__BackingField", target)
    util.safe_set_field(ai_target, "<Owner>k__BackingField", game_object)
    util.safe_set_field(ai_target, "<OwnerCharacter>k__BackingField", target)
    util.safe_set_field(ai_target, "<ContextHolder>k__BackingField", util.safe_method(target, "get_Context"))
    util.safe_set_field(ai_target, "<Transform>k__BackingField", util.safe_method(target, "get_Transform"))

    return ai_target
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
                data.last_skip_think_method_source = "app.DecisionEvaluationModule"
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
                data.last_skip_think_method_source = "app.DecisionModule"
            end
        end
    end

    return methods
end

local function call_carrier_bridge(data, context, pack_path, target, skip_think_enabled)
    local pack_data = util.safe_create_userdata("app.ActInterPackData", pack_path)
    if pack_data == nil then
        return false, {
            reason = "actinter_pack_create_failed",
            pack_path = tostring(pack_path or "nil"),
        }
    end

    local ai_target = nil
    if util.is_valid_obj(target) then
        ai_target = create_ai_target(target)
        if ai_target == nil then
            return false, {
                reason = "ai_target_create_failed",
                pack_path = tostring(pack_path or "nil"),
            }
        end
    end

    local methods = ensure_methods(data)
    if methods.exec_method == nil or methods.reqmain_method == nil or context == nil or context.ai_blackboard == nil then
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
    if skip_think_enabled and methods.skip_think_method ~= nil and context.decision_module ~= nil then
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
        skip_think_method_source = tostring(data.last_skip_think_method_source or "unresolved"),
    }
end

local function build_signature(target, pack_family, mode_key)
    return table.concat({
        tostring(util.get_address(target) or "nil"),
        tostring(pack_family or "nil"),
        tostring(mode_key or "nil"),
    }, "|")
end

local function has_job07_node(context)
    local full = tostring(context and context.full_node or "nil")
    local upper = tostring(context and context.upper_node or "nil")
    return full:find("Job07_", 1, true) ~= nil
        or upper:find("Job07_", 1, true) ~= nil
end

local function begin_observation(data)
    local ticks = tonumber(adapter_config().observation_ticks) or 8
    data.observation_active = true
    data.observation_ticks_remaining = ticks
    data.observation_tick = 0
    data.observation_pack_path = "nil"
    data.observation_pack_family = "nil"
    data.observation_nodes = "nil|nil"
    data.observation_first_job07_tick = -1
    data.observation_first_job07_pack_path = "nil"
    data.observation_first_job07_nodes = "nil|nil"
    data.observation_first_generic_tick = -1
    data.observation_first_generic_pack_path = "nil"
    data.observation_first_generic_nodes = "nil|nil"
end

local function emit_observation_complete(runtime, data, reason)
    log.session_marker(runtime, "adapter", "synthetic_job07_adapter_observation_complete", {
        reason = tostring(reason or "window_complete"),
        last_pack_path = data.observation_pack_path,
        last_pack_family = data.observation_pack_family,
        last_nodes = data.observation_nodes,
        first_job07_tick = data.observation_first_job07_tick,
        first_job07_pack_path = data.observation_first_job07_pack_path,
        first_job07_nodes = data.observation_first_job07_nodes,
        first_generic_tick = data.observation_first_generic_tick,
        first_generic_pack_path = data.observation_first_generic_pack_path,
        first_generic_nodes = data.observation_first_generic_nodes,
    }, string.format(
        "reason=%s last_pack=%s first_job07=%s first_generic=%s",
        tostring(reason or "window_complete"),
        tostring(data.observation_pack_path),
        tostring(data.observation_first_job07_tick),
        tostring(data.observation_first_generic_tick)
    ))
end

local function observe_runtime_window(runtime, data)
    if data.observation_active ~= true then
        return
    end

    local context, context_reason = resolve_main_pawn_context(runtime)
    if context == nil then
        data.observation_active = false
        emit_observation_complete(runtime, data, tostring(context_reason or "context_unresolved"))
        return
    end

    data.observation_tick = data.observation_tick + 1
    data.observation_ticks_remaining = data.observation_ticks_remaining - 1

    local pack_path = resolve_current_pack_path(runtime, context)
    local pack_family = classify_pack_family(pack_path)
    local nodes = string.format("%s|%s", tostring(context.full_node or "nil"), tostring(context.upper_node or "nil"))

    data.observation_pack_path = tostring(pack_path)
    data.observation_pack_family = tostring(pack_family)
    data.observation_nodes = nodes

    if data.observation_first_job07_tick < 0 and (pack_family == "job07" or pack_family == "npc_job07" or has_job07_node(context)) then
        data.observation_first_job07_tick = data.observation_tick
        data.observation_first_job07_pack_path = tostring(pack_path)
        data.observation_first_job07_nodes = nodes
    end

    if data.observation_first_generic_tick < 0 and (pack_family == "common" or pack_family == "ch1" or pack_family == "nil") then
        data.observation_first_generic_tick = data.observation_tick
        data.observation_first_generic_pack_path = tostring(pack_path)
        data.observation_first_generic_nodes = nodes
    end

    if data.observation_ticks_remaining > 0 then
        return
    end

    data.observation_active = false
    emit_observation_complete(runtime, data, "window_complete")
end

local function clear_hold(data, reason)
    data.hold_active = false
    data.hold_since_time = nil
    data.hold_target = nil
    data.hold_reason = tostring(reason or "released")
end

local function resolve_release_pack_path(reason)
    local adapter = adapter_config()
    local release_phase = job07_sigurd_profile.release_phase(adapter, reason)
    if reason == "target_lost" or reason == "social_context" then
        return tostring(release_phase.idle_pack_path or adapter.release_idle_pack_path or DEFAULT_IDLE_RELEASE_PACK_PATH)
    end

    return tostring(release_phase.pack_path or adapter.release_combat_pack_path or DEFAULT_ENGAGE_PACK_PATH)
end

local function attempt_release(runtime, data, context, reason)
    local release_pack_path = resolve_release_pack_path(reason)
    local release_target = data.hold_target
    local skip_think_enabled = adapter_config().request_skip_think == true
    local bridge_ok, bridge_info = call_carrier_bridge(data, context, release_pack_path, release_target, skip_think_enabled)
    if not bridge_ok then
        append_failed(runtime, data, "release_call_failed", {
            actor = "main_pawn",
            actor_job = context and context.current_job or nil,
            pack_path = release_pack_path,
            current_pack_path = context and resolve_current_pack_path(runtime, context) or "nil",
            release_reason = tostring(reason),
            exec_ok = bridge_info and bridge_info.exec_ok or false,
            exec_err = bridge_info and bridge_info.exec_err or "nil",
            reqmain_ok = bridge_info and bridge_info.reqmain_ok or false,
            reqmain_err = bridge_info and bridge_info.reqmain_err or "nil",
            skip_think_ok = bridge_info and bridge_info.skip_think_ok or false,
            skip_think_err = bridge_info and bridge_info.skip_think_err or "nil",
            skip_think_method_source = bridge_info and bridge_info.skip_think_method_source or tostring(data.last_skip_think_method_source or "unresolved"),
        })
        clear_hold(data, "release_failed")
        return
    end

    data.last_phase = "release"
    data.last_pack_path = release_pack_path
    data.last_pack_family = classify_pack_family(release_pack_path)

    log.session_marker(runtime, "adapter", "synthetic_job07_adapter_released", {
        actor = "main_pawn",
        actor_job = context and context.current_job or nil,
        profile_key = tostring(adapter_config().profile_key or job07_sigurd_profile.key()),
        release_reason = tostring(reason),
        pack_path = release_pack_path,
        current_pack_path = context and resolve_current_pack_path(runtime, context) or "nil",
        current_nodes = string.format("%s|%s", tostring(context and context.full_node or "nil"), tostring(context and context.upper_node or "nil")),
        target = util.describe_obj(release_target),
        target_type = util.get_type_full_name(release_target) or "nil",
        skip_think_enabled = skip_think_enabled,
        skip_think_ok = bridge_info and bridge_info.skip_think_ok or false,
        skip_think_err = bridge_info and bridge_info.skip_think_err or "nil",
        skip_think_method_source = bridge_info and bridge_info.skip_think_method_source or tostring(data.last_skip_think_method_source or "unresolved"),
    }, string.format(
        "reason=%s pack=%s current=%s skipThink=%s",
        tostring(reason),
        tostring(release_pack_path),
        tostring(context and resolve_current_pack_path(runtime, context) or "nil"),
        tostring(bridge_info and bridge_info.skip_think_ok or false)
    ))

    clear_hold(data, reason)
end

local function attempt_engage(runtime, data, context, current_pack_path, current_pack_family, target, target_desc, target_type, target_reason, target_distance, phase_entry)
    local engage_pack_path = tostring((phase_entry and phase_entry.pack_path) or adapter_config().engage_pack_path or DEFAULT_ENGAGE_PACK_PATH)
    local phase_key = tostring(phase_entry and phase_entry.key or "engage")
    local signature = build_signature(target, current_pack_family, phase_key)
    local now = tonumber(runtime.game_time or os.clock()) or 0.0
    local engage_cooldown_seconds = tonumber(adapter_config().engage_cooldown_seconds) or 0.75

    if data.last_engage_time ~= nil and (now - data.last_engage_time) < engage_cooldown_seconds then
        append_skip(runtime, data, "engage_phase_active", {
            actor = "main_pawn",
            actor_job = context.current_job,
            adapter_phase = "engage",
            selected_attack_key = phase_key,
            current_pack_path = current_pack_path,
            current_pack_family = current_pack_family,
            target = target_desc,
            target_type = target_type,
            target_reason = tostring(target_reason or "nil"),
            target_distance = target_distance,
        })
        return false
    end

    if data.last_engage_signature == signature and current_pack_path == engage_pack_path then
        append_skip(runtime, data, "engage_duplicate_signature", {
            actor = "main_pawn",
            actor_job = context.current_job,
            adapter_phase = "engage",
            selected_attack_key = phase_key,
            current_pack_path = current_pack_path,
            current_pack_family = current_pack_family,
            target = target_desc,
            target_type = target_type,
            target_reason = tostring(target_reason or "nil"),
            target_distance = target_distance,
        })
        return false
    end

    local bridge_ok, bridge_info = call_carrier_bridge(data, context, engage_pack_path, target, false)
    if not bridge_ok then
        append_failed(runtime, data, "engage_bridge_failed", {
            actor = "main_pawn",
            actor_job = context.current_job,
            adapter_phase = "engage",
            selected_attack_key = phase_key,
            pack_path = engage_pack_path,
            current_pack_path = current_pack_path,
            target = target_desc,
            target_type = target_type,
            target_reason = tostring(target_reason or "nil"),
            target_distance = target_distance,
            exec_ok = bridge_info and bridge_info.exec_ok or false,
            exec_err = bridge_info and bridge_info.exec_err or "nil",
            reqmain_ok = bridge_info and bridge_info.reqmain_ok or false,
            reqmain_err = bridge_info and bridge_info.reqmain_err or "nil",
        })
        return false
    end

    data.engage_apply_count = data.engage_apply_count + 1
    data.last_status = "engage_applied"
    data.last_reason = "synthetic_job07_engage_applied"
    data.last_phase = phase_key
    data.last_pack_path = engage_pack_path
    data.last_pack_family = classify_pack_family(engage_pack_path)
    data.last_target = target_desc
    data.last_target_type = target_type
    data.last_target_distance = target_distance
    data.last_engage_signature = signature
    data.last_engage_time = now

    log.session_marker(runtime, "adapter", "synthetic_job07_adapter_engage_applied", {
        actor = "main_pawn",
        actor_job = context.current_job,
        profile_key = tostring(adapter_config().profile_key or job07_sigurd_profile.key()),
        adapter_phase = "engage",
        selected_attack_key = phase_key,
        engage_apply_count = data.engage_apply_count,
        pack_path = engage_pack_path,
        pre_pack_path = current_pack_path,
        pre_pack_family = current_pack_family,
        pre_nodes = string.format("%s|%s", tostring(context.full_node or "nil"), tostring(context.upper_node or "nil")),
        target = target_desc,
        target_type = target_type,
        target_reason = tostring(target_reason or "nil"),
        target_distance = target_distance,
        ai_target = bridge_info and bridge_info.ai_target or "nil",
        ai_target_type = bridge_info and bridge_info.ai_target_type or "nil",
    }, string.format(
        "engage=%s phase=%s pack=%s pre=%s dist=%s target=%s",
        tostring(data.engage_apply_count),
        tostring(phase_key),
        tostring(engage_pack_path),
        tostring(current_pack_path),
        tostring(target_distance),
        tostring(target_desc)
    ))

    return true
end

function synthetic_job07_adapter.install(runtime)
    get_data(runtime)
end

function synthetic_job07_adapter.update(runtime)
    local data = get_data(runtime)
    observe_runtime_window(runtime, data)
    if not adapter_enabled() then
        data.enabled = false
        data.last_status = "disabled"
        data.last_reason = "adapter_disabled"
        return data
    end

    local context, context_reason = resolve_main_pawn_context(runtime)
    if context == nil then
        append_skip(runtime, data, tostring(context_reason), {
            actor = "main_pawn",
            current_pack_path = "nil",
            target = "nil",
        })
        return data
    end

    local current_pack_path = resolve_current_pack_path(runtime, context)
    local current_pack_family = classify_pack_family(current_pack_path)
    local target, target_reason = resolve_decision_target(context.runtime_character)
    local target_type = util.get_type_full_name(target) or "nil"
    local target_desc = util.describe_obj(target)
    local target_distance = compute_distance(context.runtime_character, target)
    local now = tonumber(runtime.game_time or os.clock()) or 0.0

    if data.hold_active == true then
        local hold_elapsed = data.hold_since_time ~= nil and (now - data.hold_since_time) or 0.0
        local release_reason = nil

        if target == nil then
            release_reason = "target_lost"
        elseif is_social_pack_path(current_pack_path) then
            release_reason = "social_context"
        elseif hold_elapsed >= (tonumber(adapter_config().max_hold_seconds) or 1.0) then
            release_reason = "max_hold_elapsed"
        end

        if release_reason ~= nil then
            attempt_release(runtime, data, context, release_reason)
        end

        return data
    end

    if is_social_pack_path(current_pack_path) then
        append_skip(runtime, data, "social_context", {
            actor = "main_pawn",
            actor_job = context.current_job,
            current_pack_path = current_pack_path,
            current_pack_family = current_pack_family,
            target = target_desc,
            target_type = target_type,
            target_reason = tostring(target_reason or "nil"),
            target_distance = target_distance,
        })
        return data
    end

    if current_pack_family == "job07" or current_pack_family == "npc_job07" then
        append_skip(runtime, data, "already_job07_context", {
            actor = "main_pawn",
            actor_job = context.current_job,
            current_pack_path = current_pack_path,
            current_pack_family = current_pack_family,
            target = target_desc,
            target_type = target_type,
            target_reason = tostring(target_reason or "nil"),
            target_distance = target_distance,
        })
        return data
    end

    if target == nil then
        append_skip(runtime, data, tostring(target_reason or "target_unresolved"), {
            actor = "main_pawn",
            actor_job = context.current_job,
            current_pack_path = current_pack_path,
            current_pack_family = current_pack_family,
            target = "nil",
            target_type = "nil",
            target_distance = target_distance,
        })
        return data
    end

    if util.same_object(target, context.runtime_character)
        or (runtime.player ~= nil and util.same_object(target, runtime.player)) then
        append_skip(runtime, data, "invalid_target_identity", {
            actor = "main_pawn",
            actor_job = context.current_job,
            current_pack_path = current_pack_path,
            current_pack_family = current_pack_family,
            target = target_desc,
            target_type = target_type,
            target_reason = tostring(target_reason or "nil"),
            target_distance = target_distance,
        })
        return data
    end

    local selected_phase, phase_candidates = select_phase_entry(target_distance, data.last_attack_key)
    if selected_phase == nil then
        append_skip(runtime, data, "phase_unresolved", {
            actor = "main_pawn",
            actor_job = context.current_job,
            current_pack_path = current_pack_path,
            current_pack_family = current_pack_family,
            target = target_desc,
            target_type = target_type,
            target_reason = tostring(target_reason or "nil"),
            target_distance = target_distance,
        })
        return data
    end

    local selected_phase_key = tostring(selected_phase.key or "nil")
    local selected_phase_mode = tostring(selected_phase.mode or "attack")
    if selected_phase_mode == "engage" then
        attempt_engage(runtime, data, context, current_pack_path, current_pack_family, target, target_desc, target_type, target_reason, target_distance, selected_phase)
        return data
    end

    local cooldown_seconds = tonumber(adapter_config().cooldown_seconds) or 6.0
    if data.last_apply_time ~= nil and (now - data.last_apply_time) < cooldown_seconds then
        append_skip(runtime, data, "cooldown_active", {
            actor = "main_pawn",
            actor_job = context.current_job,
            adapter_phase = "attack",
            current_pack_path = current_pack_path,
            current_pack_family = current_pack_family,
            target = target_desc,
            target_type = target_type,
            target_reason = tostring(target_reason or "nil"),
            target_distance = target_distance,
            selected_attack_key = selected_phase_key,
            attack_candidates = describe_phase_candidates(phase_candidates),
            elapsed_seconds = now - data.last_apply_time,
            cooldown_seconds = cooldown_seconds,
        })
        return data
    end

    local selected_attack_key = selected_phase_key
    local pack_path = tostring(selected_phase.pack_path or adapter_config().pack_path or DEFAULT_ATTACK_PACK_PATH)
    local signature = build_signature(target, current_pack_family, selected_attack_key)
    if data.last_signature == signature and data.last_apply_time ~= nil then
        append_skip(runtime, data, "duplicate_signature", {
            actor = "main_pawn",
            actor_job = context.current_job,
            adapter_phase = "attack",
            current_pack_path = current_pack_path,
            current_pack_family = current_pack_family,
            target = target_desc,
            target_type = target_type,
            target_reason = tostring(target_reason or "nil"),
            target_distance = target_distance,
            selected_attack_key = selected_attack_key,
            attack_candidates = describe_phase_candidates(phase_candidates),
        })
        return data
    end

    data.attempt_count = data.attempt_count + 1

    local skip_think_enabled = adapter_config().request_skip_think == true
    local bridge_ok, bridge_info = call_carrier_bridge(data, context, pack_path, target, skip_think_enabled)
    if not bridge_ok then
        append_failed(runtime, data, "carrier_bridge_call_failed", {
            actor = "main_pawn",
            actor_job = context.current_job,
            adapter_phase = "attack",
            pack_path = pack_path,
            current_pack_path = current_pack_path,
            target = target_desc,
            target_type = target_type,
            target_reason = tostring(target_reason or "nil"),
            target_distance = target_distance,
            selected_attack_key = selected_attack_key,
            attack_candidates = describe_phase_candidates(phase_candidates),
            exec_ok = bridge_info and bridge_info.exec_ok or false,
            exec_err = bridge_info and bridge_info.exec_err or "nil",
            reqmain_ok = bridge_info and bridge_info.reqmain_ok or false,
            reqmain_err = bridge_info and bridge_info.reqmain_err or "nil",
            skip_think_ok = bridge_info and bridge_info.skip_think_ok or false,
            skip_think_err = bridge_info and bridge_info.skip_think_err or "nil",
            skip_think_method_source = bridge_info and bridge_info.skip_think_method_source or tostring(data.last_skip_think_method_source or "unresolved"),
        })
        return data
    end

    data.apply_count = data.apply_count + 1
    data.last_status = "applied"
    data.last_reason = "synthetic_job07_bridge_applied"
    data.last_phase = selected_attack_key
    data.last_pack_path = pack_path
    data.last_pack_family = classify_pack_family(pack_path)
    data.last_target = target_desc
    data.last_target_type = target_type
    data.last_target_distance = target_distance
    data.last_attack_key = selected_attack_key
    data.last_attack_pack_path = pack_path
    data.last_signature = signature
    data.last_apply_time = now
    data.hold_active = true
    data.hold_since_time = now
    data.hold_target = target
    data.hold_reason = "applied"
    begin_observation(data)

    log.session_marker(runtime, "adapter", "synthetic_job07_adapter_applied", {
        actor = "main_pawn",
        actor_job = context.current_job,
        profile_key = tostring(adapter_config().profile_key or job07_sigurd_profile.key()),
        apply_count = data.apply_count,
        attempt_count = data.attempt_count,
        adapter_phase = "attack",
        trigger = "runtime_update",
        selected_attack_key = selected_attack_key,
        attack_candidates = describe_phase_candidates(phase_candidates),
        pack_path = pack_path,
        pre_pack_path = current_pack_path,
        pre_pack_family = current_pack_family,
        pre_nodes = string.format("%s|%s", tostring(context.full_node or "nil"), tostring(context.upper_node or "nil")),
        target = target_desc,
        target_type = target_type,
        target_reason = tostring(target_reason or "nil"),
        target_distance = target_distance,
        ai_target = bridge_info and bridge_info.ai_target or "nil",
        ai_target_type = bridge_info and bridge_info.ai_target_type or "nil",
        skip_think_enabled = skip_think_enabled,
        skip_think_ok = bridge_info and bridge_info.skip_think_ok or false,
        skip_think_err = bridge_info and bridge_info.skip_think_err or "nil",
        skip_think_method_source = bridge_info and bridge_info.skip_think_method_source or tostring(data.last_skip_think_method_source or "unresolved"),
    }, string.format(
        "apply=%s attack=%s pack=%s pre=%s dist=%s skipThink=%s",
        tostring(data.apply_count),
        tostring(selected_attack_key),
        tostring(pack_path),
        tostring(current_pack_path),
        tostring(target_distance),
        tostring(bridge_info and bridge_info.skip_think_ok or false)
    ))

    return data
end

return synthetic_job07_adapter
