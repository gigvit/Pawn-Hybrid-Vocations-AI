local state = require("PawnHybridVocationsAI/state")
local config = require("PawnHybridVocationsAI/config")
local util = require("PawnHybridVocationsAI/core/util")
local log = require("PawnHybridVocationsAI/core/log")
local hybrid_jobs = require("PawnHybridVocationsAI/data/hybrid_jobs")

local action_research = {}
local tracked_targets = { "player", "main_pawn" }
local resolve_target_from_decision_slots
local resolve_target_from_decision_slots_any

local function build_actor_summary_defaults(target)
    local summary = {
        [target .. "_job"] = nil,
        [target .. "_human_address"] = "nil",
        [target .. "_runtime_character_address"] = "nil",
        [target .. "_action_manager"] = "nil",
        [target .. "_action_manager_address"] = "nil",
        [target .. "_action_manager_source"] = "unresolved",
        [target .. "_current_job_action_ctrl"] = "nil",
        [target .. "_current_job_action_ctrl_source"] = "unresolved",
        [target .. "_common_action_selector"] = "nil",
        [target .. "_common_action_selector_source"] = "unresolved",
        [target .. "_ai_blackboard_controller"] = "nil",
        [target .. "_ai_blackboard_address"] = "nil",
        [target .. "_ai_blackboard_source"] = "unresolved",
        [target .. "_ai_decision_maker"] = "nil",
        [target .. "_decision_module"] = "nil",
        [target .. "_decision_executor"] = "nil",
        [target .. "_executing_decision"] = "nil",
        [target .. "_executing_decision_target"] = "nil",
        [target .. "_current_execute_actinter"] = "nil",
        [target .. "_current_execute_actinter_pack"] = "nil",
        [target .. "_current_execute_actinter_pack_path"] = "nil",
        [target .. "_last_decision_snapshot_pack_path"] = "nil",
        [target .. "_last_observed_actinter_pack"] = "nil",
        [target .. "_last_observed_actinter_pack_path"] = "nil",
        [target .. "_job07_decision_packhandler_snapshot"] = "nil",
        [target .. "_full_node"] = "nil",
        [target .. "_upper_node"] = "nil",
        [target .. "_in_job_action_node"] = false,
        [target .. "_actinter_requests"] = 0,
        [target .. "_request_action_calls"] = 0,
        [target .. "_last_requested_action"] = "nil",
        [target .. "_last_requested_priority"] = "nil",
        [target .. "_observed_request_action_count"] = 0,
    }

    if target == "main_pawn" then
        summary.main_pawn_pawn_address = "nil"
    end

    return summary
end

local function build_initial_summary()
    local summary = {}
    for _, target in ipairs(tracked_targets) do
        local defaults = build_actor_summary_defaults(target)
        for key, value in pairs(defaults) do
            summary[key] = value
        end
    end

    summary.decision_probe_hits = 0
    summary.last_decision_probe_action = "nil"
    summary.last_decision_probe_priority = "nil"
    summary.last_decision_probe_nodes = "nil|nil"
    summary.last_decision_probe_decision = "nil"
    summary.last_decision_probe_decision_target = "nil"
    summary.last_decision_probe_pack_path = "nil"
    summary.last_decision_probe_actions = "nil,nil"
    summary.decision_snapshot_hits = 0
    summary.last_decision_snapshot_target = "none"
    summary.last_decision_snapshot_action = "nil"
    summary.last_decision_snapshot_fields = ""
    summary.ai_decision_snapshot_hits = 0
    summary.last_ai_decision_snapshot_action = "nil"
    summary.last_ai_decision_snapshot_fields = ""
    summary.ai_target_snapshot_hits = 0
    summary.last_ai_target_snapshot_action = "nil"
    summary.last_ai_target_snapshot_fields = ""
    summary.decision_actionpack_snapshot_hits = 0
    summary.last_decision_actionpack_snapshot_action = "nil"
    summary.last_decision_actionpack_snapshot_fields = ""
    summary.decision_producer_snapshot_hits = 0
    summary.last_decision_producer_snapshot_action = "nil"
    summary.last_decision_producer_snapshot_fields = ""
    summary.last_actinter_target = "none"
    summary.last_actinter_pack = "nil"
    summary.last_actinter_pack_path = "nil"
    summary.last_actinter_controller = "nil"
    summary.last_actinter_controller_address = "nil"
    summary.observed_pack_count = 0
    summary.current_job_gap = "unresolved"

    return summary
end

local function classify_pack_path(path)
    local text = tostring(path or "nil")
    if text == "nil" or text == "" then
        return "nil"
    end
    if text:find("NPC/Job07/", 1, true) then
        return "npc_job07"
    end
    if text:find("/Job01_Fighter/", 1, true) then
        return "job01"
    end
    if text:find("/Job07/", 1, true) then
        return "job07"
    end
    if text:find("/GenericJob/", 1, true) then
        return "generic_job"
    end
    if text:find("/Common/", 1, true) then
        return "common"
    end
    if text:find("/ch1/", 1, true) then
        return "ch1"
    end
    return "other"
end

local function classify_action_name(action_name)
    local text = tostring(action_name or "nil")
    if text == "nil" or text == "" then
        return "nil"
    end
    if text:find("^Job01_") then
        return "job01"
    end
    if text:find("^Job07_") then
        return "job07"
    end
    return "generic"
end

local function classify_decision_phase(pack_path, nodes, action_name)
    local pack_family = classify_pack_path(pack_path)
    local action_family = classify_action_name(action_name)
    local node_text = tostring(nodes or "nil|nil")
    local has_job_node = node_text:find("Job01_", 1, true) ~= nil
        or node_text:find("Job07_", 1, true) ~= nil

    if action_family == "job01" or action_family == "job07" then
        return "combat_job"
    end

    if has_job_node then
        return "combat_job"
    end

    if pack_family == "npc_job07" or pack_family == "job01" or pack_family == "job07" or pack_family == "generic_job" then
        return "combat_job"
    end

    if pack_family == "common" or pack_family == "ch1" then
        if node_text:find("HighFive", 1, true)
            or node_text:find("Liv", 1, true)
            or node_text:find("Greeting", 1, true)
            or node_text:find("Chilling", 1, true)
            or node_text:find("SortItem", 1, true)
            or node_text:find("TreasureBox", 1, true)
            or node_text:find("Idle", 1, true) then
            return "social_idle"
        end

        if node_text:find("Move", 1, true)
            or node_text:find("Run", 1, true)
            or node_text:find("NormalLocomotion", 1, true)
            or node_text:find("DrawWeapon", 1, true)
            or node_text:find("Strafe", 1, true) then
            return "generic_runtime"
        end
    end

    if pack_family == "other" then
        return "other_runtime"
    end

    return "unknown"
end

local function should_emit_decision_transition_signal(target, old_phase, new_phase, old_pack_family, new_pack_family)
    if target ~= "main_pawn" then
        return false
    end

    if old_phase == new_phase then
        return false
    end

    if old_phase == "combat_job"
        and (new_phase == "generic_runtime" or new_phase == "social_idle" or new_phase == "other_runtime") then
        return true
    end

    if (old_pack_family == "npc_job07" or old_pack_family == "common" or old_pack_family == "ch1")
        and (new_pack_family == "common" or new_pack_family == "ch1" or new_pack_family == "other")
        and old_phase ~= "social_idle"
        and new_phase ~= "combat_job" then
        return true
    end

    return false
end

local function is_combat_pack_family(pack_family)
    return pack_family == "npc_job07"
        or pack_family == "job01"
        or pack_family == "job07"
        or pack_family == "generic_job"
end

local function is_generic_overwrite_phase(phase, pack_family, pack_path)
    if phase == "generic_runtime" or phase == "social_idle" then
        return true
    end

    if (pack_family == "common" or pack_family == "ch1") and phase ~= "combat_job" then
        return true
    end

    return tostring(pack_path or "nil") == "nil" and phase ~= "combat_job"
end

local function should_arm_main_pawn_overwrite_tracker(pack_family, nodes)
    local node_text = tostring(nodes or "nil|nil")
    if pack_family == "job01" or pack_family == "job07" or pack_family == "npc_job07" or pack_family == "generic_job" then
        return true
    end

    if (pack_family == "common" or pack_family == "ch1")
        and (node_text:find("Job01_", 1, true) ~= nil or node_text:find("Job07_", 1, true) ~= nil) then
        return true
    end

    return false
end

local function is_job07_specific_pack_family(pack_family)
    return pack_family == "job07" or pack_family == "npc_job07"
end

local function is_low_signal_unknown_request_action(action_name)
    local text = tostring(action_name or "nil")
    if text == "NormalLocomotion" or text == "WaitToFall" or text == "RolKidsIdle" then
        return true
    end
    return text:find("^LivIdle") ~= nil
end

local function is_low_signal_unknown_pack(pack_path)
    local text = tostring(pack_path or "nil")
    return text == "nil"
        or text:find("Common/Liv_Idel.user", 1, true) ~= nil
        or text:find("Common/Liv_Idel_Talk.user", 1, true) ~= nil
end

local function should_suppress_unknown_request_action(action_name)
    return config.action_research ~= nil
        and config.action_research.filter_unknown_social_spam == true
        and is_low_signal_unknown_request_action(action_name)
end

local function should_suppress_unknown_actinter(pack_path)
    return config.action_research ~= nil
        and config.action_research.filter_unknown_social_spam == true
        and is_low_signal_unknown_pack(pack_path)
end

local function build_job07_packhandler_snapshot(context)
    if context == nil or context.decision_module == nil then
        return "nil"
    end

    local handler =
        util.safe_direct_method(context.decision_module, "get_DecisionPackHandler")
        or util.safe_method(context.decision_module, "get_DecisionPackHandler()")
    if handler == nil then
        return "nil"
    end

    local limit = (config.action_research and config.action_research.packhandler_snapshot_limit) or 6
    return table.concat({
        "active=" .. build_collection_snapshot_text(
            util.safe_direct_method(handler, "get_ActiveDecisionPacks")
                or util.safe_method(handler, "get_ActiveDecisionPacks()"),
            { "pack", "decision", "active", "target", "action" },
            limit
        ),
        "main=" .. build_collection_snapshot_text(
            util.safe_direct_method(handler, "get_MainDecisionList")
                or util.safe_method(handler, "get_MainDecisionList()"),
            { "decision", "pack", "target", "action", "combat" },
            limit
        ),
        "pre=" .. build_collection_snapshot_text(
            util.safe_direct_method(handler, "get_PreDecisionList")
                or util.safe_method(handler, "get_PreDecisionList()"),
            { "decision", "pack", "target", "action", "combat" },
            limit
        ),
        "post=" .. build_collection_snapshot_text(
            util.safe_direct_method(handler, "get_PostDecisionList")
                or util.safe_method(handler, "get_PostDecisionList()"),
            { "decision", "pack", "target", "action", "combat" },
            limit
        ),
    }, "; ")
end

local function resolve_decision_pack_data(executing_decision)
    if executing_decision == nil then
        return nil, "nil"
    end

    local decision_pack = util.safe_field(executing_decision, "<ActionPackData>k__BackingField")
        or util.safe_field(executing_decision, "_ActionPackData")
        or util.safe_direct_method(executing_decision, "get_ActionPackData")
        or util.safe_method(executing_decision, "get_ActionPackData()")
    if decision_pack == nil then
        return nil, "nil"
    end

    local pack_path = util.safe_direct_method(decision_pack, "get_Path")
        or util.safe_method(decision_pack, "get_Path()")
    return decision_pack, pack_path ~= nil and tostring(pack_path) or "nil"
end

local function get_data(runtime)
    runtime.action_research_data = runtime.action_research_data or {
        hooks_installed = false,
        installed_methods = {},
        registration_errors = {},
        recent_events = {},
        observed_packs = {},
        observed_request_actions = {
            player = {},
            main_pawn = {},
            sigurd = {},
        },
        observed_decision_probes = {},
        observed_decision_snapshots = {
            player = {},
            main_pawn = {},
        },
        observed_ai_decision_snapshots = {},
        observed_ai_target_snapshots = {},
        observed_decision_actionpack_snapshots = {},
        observed_decision_producer_snapshots = {},
        last_pair_probe_trigger = {},
        last_summary_signature = nil,
        stats = {
            summary_changes = 0,
            actinter_requests = 0,
            reqmain_pack_requests = 0,
            request_action_calls = 0,
            decision_probe_hits = 0,
            decision_snapshot_hits = 0,
            decision_hook_events = 0,
            decision_hook_raw_hits = 0,
            decision_overwrite_events = 0,
        },
        decision_actor_index_generation = 0,
        decision_actor_index_cache_generation = -1,
        decision_actor_index_cache = nil,
        last_decision_hook_signatures = {},
        decision_hook_raw_counts = {},
        decision_hook_unmatched_counts = {},
        job07_carrier_trace_last_signature = "nil",
        main_pawn_overwrite_tracker = {
            active = false,
            generation = 0,
            transition_count = 0,
            armed_by_hook = "nil",
            armed_method = "nil",
            armed_reason = "unresolved",
            combat_pack_path = "nil",
            combat_pack_family = "nil",
            combat_nodes = "nil|nil",
            combat_decision = "nil",
            combat_target = "nil",
            last_request_action = "nil",
            last_request_priority = "nil",
            last_request_nodes = "nil|nil",
            last_request_reason = "unresolved",
            last_actinter_pack_path = "nil",
            last_actinter_target = "none",
            last_actinter_target_reason = "unresolved",
            last_actinter_nodes = "nil|nil",
            last_emitted_signature = "nil",
        },
        summary = build_initial_summary(),
    }
    return runtime.action_research_data
end

local function get_main_pawn_overwrite_tracker(data)
    if data.main_pawn_overwrite_tracker == nil then
        data.main_pawn_overwrite_tracker = {
            active = false,
            generation = 0,
            transition_count = 0,
            armed_by_hook = "nil",
            armed_method = "nil",
            armed_reason = "unresolved",
            combat_pack_path = "nil",
            combat_pack_family = "nil",
            combat_nodes = "nil|nil",
            combat_decision = "nil",
            combat_target = "nil",
            last_request_action = "nil",
            last_request_priority = "nil",
            last_request_nodes = "nil|nil",
            last_request_reason = "unresolved",
            last_actinter_pack_path = "nil",
            last_actinter_target = "none",
            last_actinter_target_reason = "unresolved",
            last_actinter_nodes = "nil|nil",
            last_emitted_signature = "nil",
        }
    end
    return data.main_pawn_overwrite_tracker
end

local function arm_main_pawn_overwrite_tracker(data, hook_name, method_label, reason, actor_job, new_pack_path, new_pack_family, new_nodes, new_decision, new_target)
    local tracker = get_main_pawn_overwrite_tracker(data)
    tracker.active = true
    tracker.generation = (tracker.generation or 0) + 1
    tracker.transition_count = 0
    tracker.armed_by_hook = tostring(hook_name or "nil")
    tracker.armed_method = tostring(method_label or "nil")
    tracker.armed_reason = tostring(reason or "unresolved")
    tracker.actor_job = actor_job
    tracker.combat_pack_path = tostring(new_pack_path or "nil")
    tracker.combat_pack_family = tostring(new_pack_family or "nil")
    tracker.combat_nodes = tostring(new_nodes or "nil|nil")
    tracker.combat_decision = tostring(new_decision or "nil")
    tracker.combat_target = tostring(new_target or "nil")
    tracker.last_request_action = tostring(data.summary and data.summary.main_pawn_last_requested_action or "nil")
    tracker.last_request_priority = tostring(data.summary and data.summary.main_pawn_last_requested_priority or "nil")
    tracker.last_request_nodes = string.format(
        "%s|%s",
        tostring(data.summary and data.summary.main_pawn_full_node or "nil"),
        tostring(data.summary and data.summary.main_pawn_upper_node or "nil")
    )
    tracker.last_request_reason = "summary_snapshot"
    tracker.last_actinter_pack_path = tostring(data.summary and data.summary.main_pawn_last_observed_actinter_pack_path or "nil")
    tracker.last_actinter_target = tostring(data.summary and data.summary.last_actinter_target or "none")
    tracker.last_actinter_target_reason = "summary_snapshot"
    tracker.last_actinter_nodes = tracker.last_request_nodes
    return tracker
end

local function track_main_pawn_request_action(data, target_reason, action_name, priority, full_node, upper_node)
    local tracker = get_main_pawn_overwrite_tracker(data)
    if tracker.active ~= true then
        return
    end
    tracker.last_request_action = tostring(action_name or "nil")
    tracker.last_request_priority = tostring(priority or "nil")
    tracker.last_request_nodes = string.format("%s|%s", tostring(full_node or "nil"), tostring(upper_node or "nil"))
    tracker.last_request_reason = tostring(target_reason or "unresolved")
end

local function track_main_pawn_actinter(data, target, target_reason, pack_path, full_node, upper_node)
    local tracker = get_main_pawn_overwrite_tracker(data)
    if tracker.active ~= true then
        return
    end
    tracker.last_actinter_pack_path = tostring(pack_path or "nil")
    tracker.last_actinter_target = tostring(target or "none")
    tracker.last_actinter_target_reason = tostring(target_reason or "unresolved")
    tracker.last_actinter_nodes = string.format("%s|%s", tostring(full_node or "nil"), tostring(upper_node or "nil"))
end

local function action_research_bool_setting(key, default_value)
    local settings = config.action_research or {}
    local value = settings[key]
    if value == nil then
        return default_value
    end
    return value == true
end

local function action_research_number_setting(key, default_value)
    local settings = config.action_research or {}
    local value = tonumber(settings[key])
    if value == nil then
        return default_value
    end
    return value
end

local function action_research_string_setting(key, default_value)
    local settings = config.action_research or {}
    local value = settings[key]
    if value == nil or tostring(value) == "" then
        return default_value
    end
    return tostring(value)
end

local function job_equals(value, expected_job)
    if value == nil or expected_job == nil then
        return false
    end

    local expected_number = tonumber(expected_job)
    local value_number = tonumber(value)
    if expected_number ~= nil and value_number ~= nil then
        return value_number == expected_number
    end

    return tostring(value) == tostring(expected_job)
end

local function list_to_string(values)
    if values == nil or #values == 0 then
        return ""
    end

    local parts = {}
    for _, value in ipairs(values) do
        table.insert(parts, tostring(value))
    end
    return table.concat(parts, ",")
end

local function build_typed_snapshot_text(obj, method_patterns, method_limit)
    local summary = util.get_type_member_summary(obj, method_patterns, method_limit or 16)
    return string.format(
        "type=%s; field_count=%s; methods=%s",
        tostring(summary.type_name or "nil"),
        tostring(summary.field_count or 0),
        list_to_string(summary.methods or {})
    )
end

local function build_collection_snapshot_text(obj, method_patterns, method_limit)
    if obj == nil then
        return "type=nil; count=nil; field_count=0; methods="
    end

    local count = util.safe_direct_method(obj, "get_Count")
        or util.safe_method(obj, "get_Count()")
    local summary = util.get_type_member_summary(obj, method_patterns, method_limit or 16)
    return string.format(
        "type=%s; count=%s; field_count=%s; methods=%s",
        tostring(summary.type_name or util.get_type_full_name(obj) or "nil"),
        tostring(count),
        tostring(summary.field_count or 0),
        list_to_string(summary.methods or {})
    )
end

local function is_hybrid_job_action_request(current_job, action_name)
    if current_job == nil or action_name == nil then
        return false
    end

    local job_info = hybrid_jobs.get_by_id(current_job)
    if job_info == nil or job_info.action_prefix == nil then
        return false
    end

    local action_text = tostring(action_name)
    local prefix = tostring(job_info.action_prefix) .. "_"
    return string.find(action_text, prefix, 1, true) ~= nil
end

local function is_job_specific_action_request(action_name)
    if action_name == nil then
        return false
    end

    return string.find(tostring(action_name), "Job", 1, true) == 1
end

local function resolve_named_context(obj, direct_name, method_name, field_name)
    if obj == nil then
        return nil, "unresolved"
    end

    if direct_name ~= nil then
        local direct = util.safe_direct_method(obj, direct_name)
        if direct ~= nil then
            return direct, tostring(direct_name) .. "()"
        end
    end

    if (method_name or direct_name) ~= nil then
        local method = util.safe_method(obj, method_name or direct_name)
        if method ~= nil then
            return method, tostring(method_name or direct_name)
        end
    end

    if field_name ~= nil then
        local field = util.safe_field(obj, field_name)
        if field ~= nil then
            return field, tostring(field_name)
        end
    end

    return nil, "unresolved"
end

local function format_address(obj)
    local addr = util.get_address(obj)
    if addr == nil then
        return "nil"
    end

    return string.format("0x%X", addr)
end

local function resolve_current_job_action_ctrl(actor)
    if actor == nil then
        return nil, "unresolved"
    end

    local current_job = actor.current_job or actor.raw_job
    local job_info = hybrid_jobs.get_by_id(current_job)
    if job_info == nil then
        return nil, "job_not_supported"
    end

    local direct_name = job_info.controller_getter
    local method_name = direct_name .. "()"
    local field_name = job_info.controller_field

    local ctrl, source = resolve_named_context(actor.human, direct_name, method_name, field_name)
    if ctrl ~= nil then
        return ctrl, "human:" .. source
    end

    return nil, source
end

local function resolve_ai_blackboard_controller(actor, fallback_runtime_character, fallback_pawn)
    local candidates = {
        { obj = fallback_pawn, label = "fallback_pawn" },
        { obj = fallback_runtime_character, label = "runtime_character" },
        { obj = actor and actor.runtime_character or nil, label = "actor.runtime_character" },
        { obj = actor and actor.human or nil, label = "actor.human" },
    }

    for _, candidate in ipairs(candidates) do
        if candidate.obj ~= nil then
            local controller, source = resolve_named_context(
                candidate.obj,
                "get_AIBlackBoardController",
                "get_AIBlackBoardController()",
                "<AIBlackBoardController>k__BackingField"
            )
            if controller ~= nil then
                return controller, candidate.label .. ":" .. source
            end
        end
    end

    return nil, "unresolved"
end

local function resolve_common_action_selector(actor, fallback_runtime_character, fallback_pawn)
    local candidates = {
        { obj = actor and actor.human or nil, label = "actor.human" },
        { obj = actor and actor.runtime_character or nil, label = "actor.runtime_character" },
        { obj = fallback_runtime_character, label = "runtime_character" },
        { obj = fallback_pawn, label = "fallback_pawn" },
    }

    for _, candidate in ipairs(candidates) do
        if candidate.obj ~= nil then
            local selector, source = resolve_named_context(candidate.obj, nil, nil, "<CommonActionSelector>k__BackingField")
            if selector ~= nil then
                return selector, candidate.label .. ":" .. source
            end

            selector, source = resolve_named_context(candidate.obj, nil, nil, "<HumanActionSelector>k__BackingField")
            if selector ~= nil then
                return selector, candidate.label .. ":" .. source
            end
        end
    end

    return nil, "unresolved"
end

local function resolve_action_manager(actor, fallback_runtime_character, fallback_pawn)
    if actor == nil then
        return nil, "unresolved"
    end

    if actor.action_manager ~= nil then
        return actor.action_manager, "actor.action_manager"
    end

    local candidates = {
        { obj = actor.human, label = "actor.human" },
        { obj = actor.runtime_character, label = "actor.runtime_character" },
        { obj = fallback_runtime_character, label = "runtime_character" },
        { obj = fallback_pawn, label = "fallback_pawn" },
    }

    for _, candidate in ipairs(candidates) do
        if candidate.obj ~= nil then
            local manager, source = resolve_named_context(
                candidate.obj,
                "get_ActionManager",
                "get_ActionManager()",
                "<ActionManager>k__BackingField"
            )
            if manager ~= nil then
                return manager, candidate.label .. ":" .. source
            end

            manager = util.safe_field(candidate.obj, "_ActionManager")
            if manager ~= nil then
                return manager, candidate.label .. ":_ActionManager"
            end
        end
    end

    return nil, "unresolved"
end

local function contains_job_action_node(node_name, current_job)
    if type(node_name) ~= "string" or current_job == nil then
        return false
    end

    local prefix = hybrid_jobs.get_action_prefix(current_job)
    if prefix == nil then
        return false
    end

    return string.find(node_name, prefix .. "_", 1, true) ~= nil
end

local function get_current_node_name(action_manager, layer_index)
    if action_manager == nil then
        return nil
    end

    local fsm = util.safe_field(action_manager, "Fsm")
    if fsm == nil then
        return nil
    end

    local node_name = util.safe_method(fsm, "getCurrentNodeName(System.UInt32)", layer_index)
        or util.safe_method(fsm, "getCurrentNodeName", layer_index)
    if type(node_name) ~= "string" then
        return nil
    end

    return node_name:match("([^%.]+)$") or node_name
end

local function resolve_actor_human(runtime_character, fallback_human)
    if util.is_valid_obj(fallback_human) then
        return fallback_human
    end

    if runtime_character == nil then
        return nil
    end

    if util.is_a(runtime_character, "app.Human") then
        return runtime_character
    end

    return util.safe_direct_method(runtime_character, "get_Human")
        or util.safe_method(runtime_character, "get_Human")
        or util.safe_field(runtime_character, "<Human>k__BackingField")
end

local function resolve_actor_job(actor, runtime_character, human)
    if actor ~= nil then
        local actor_job = actor.current_job or actor.raw_job
        if actor_job ~= nil then
            return actor_job
        end
    end

    local job_context = human
        and (util.safe_direct_method(human, "get_JobContext")
            or util.safe_method(human, "get_JobContext()")
            or util.safe_method(human, "get_JobContext")
            or util.safe_field(human, "<JobContext>k__BackingField"))
        or nil
    local context_job = job_context and (util.safe_field(job_context, "CurrentJob")
        or util.safe_field(job_context, "<CurrentJob>k__BackingField"))
    if context_job ~= nil then
        return context_job
    end

    return runtime_character
        and (util.safe_direct_method(runtime_character, "get_CurrentJob")
            or util.safe_method(runtime_character, "get_CurrentJob()")
            or util.safe_method(runtime_character, "get_CurrentJob"))
        or nil
end

local function collect_actor_runtime_context(actor, fallback_runtime_character, fallback_pawn)
    if actor == nil then
        return {
            current_job = nil,
            action_manager = nil,
            action_manager_source = "unresolved",
            action_ctrl = nil,
            action_ctrl_source = "unresolved",
            common_action_selector = nil,
            common_action_selector_source = "unresolved",
            ai_blackboard = nil,
            ai_blackboard_source = "unresolved",
            ai_decision_maker = nil,
            decision_module = nil,
            decision_evaluator = nil,
            decision_executor = nil,
            executing_decision = nil,
            executing_decision_target = nil,
            execute_actinter = nil,
            execute_actinter_pack = nil,
            execute_actinter_pack_path = "nil",
            full_node = "nil",
            upper_node = "nil",
            human = nil,
            runtime_character = nil,
            pawn = fallback_pawn,
        }
    end

    local action_manager, action_manager_source = resolve_action_manager(actor, fallback_runtime_character, fallback_pawn)
    local action_ctrl, action_ctrl_source = resolve_current_job_action_ctrl(actor)
    local common_action_selector, common_action_selector_source = resolve_common_action_selector(actor, fallback_runtime_character, fallback_pawn)
    local ai_blackboard, ai_blackboard_source = resolve_ai_blackboard_controller(actor, fallback_runtime_character, fallback_pawn)
    local ai_decision_maker = nil
    local decision_module = nil
    local decision_evaluator = nil
    local decision_executor = nil
    local executing_decision = nil
    local executing_decision_target = nil
    local execute_actinter = nil
    local execute_actinter_pack = nil
    local execute_actinter_pack_path = "nil"
    local runtime_character = actor.runtime_character or fallback_runtime_character
    local human = resolve_actor_human(runtime_character, actor.human)
    local current_job = resolve_actor_job(actor, runtime_character, human)
    local full_node = actor.full_node
    local upper_node = actor.upper_node
    if runtime_character ~= nil then
        ai_decision_maker = resolve_named_context(runtime_character, "get_AIDecisionMaker", "get_AIDecisionMaker()", "<AIDecisionMaker>k__BackingField")
        if ai_decision_maker ~= nil then
            decision_module = resolve_named_context(ai_decision_maker, "get_DecisionModule", "get_DecisionModule()", "<DecisionModule>k__BackingField")
            if decision_module ~= nil then
                decision_evaluator = util.safe_direct_method(decision_module, "get_DecisionEvaluator")
                    or util.safe_method(decision_module, "get_DecisionEvaluator()")
                decision_executor = util.safe_field(decision_module, "<DecisionExecutor>k__BackingField")
                    or util.safe_field(decision_module, "_DecisionExecutor")
                if decision_executor ~= nil then
                    executing_decision = util.safe_field(decision_executor, "<ExecutingDecision>k__BackingField")
                        or util.safe_field(decision_executor, "_ExecutingDecision")
                    local target = executing_decision and util.safe_field(executing_decision, "<Target>k__BackingField") or nil
                    local target_chara = target and util.safe_field(target, "<Character>k__BackingField") or nil
                    executing_decision_target = target_chara or target
                end
                execute_actinter = util.safe_field(decision_module, "_ExecuteActInter")
                if execute_actinter ~= nil then
                    execute_actinter_pack = util.safe_direct_method(execute_actinter, "get_ActInterPackData")
                        or util.safe_method(execute_actinter, "get_ActInterPackData()")
                    local pack_path = execute_actinter_pack
                        and (util.safe_direct_method(execute_actinter_pack, "get_Path")
                            or util.safe_method(execute_actinter_pack, "get_Path()"))
                    if pack_path ~= nil then
                        execute_actinter_pack_path = tostring(pack_path)
                    end
                end
                if execute_actinter_pack == nil or execute_actinter_pack_path == "nil" then
                    local decision_pack, decision_pack_path = resolve_decision_pack_data(executing_decision)
                    if decision_pack ~= nil then
                        execute_actinter_pack = decision_pack
                    end
                    if decision_pack_path ~= nil and decision_pack_path ~= "nil" then
                        execute_actinter_pack_path = decision_pack_path
                    end
                end
            end
        end
    end

    if full_node == nil then
        full_node = get_current_node_name(action_manager, 0)
    end
    if upper_node == nil then
        upper_node = get_current_node_name(action_manager, 1)
    end
    full_node = full_node or "nil"
    upper_node = upper_node or "nil"

    return {
        current_job = current_job,
        action_manager = action_manager,
        action_manager_source = action_manager_source,
        action_ctrl = action_ctrl,
        action_ctrl_source = action_ctrl_source,
        common_action_selector = common_action_selector,
        common_action_selector_source = common_action_selector_source,
        ai_blackboard = ai_blackboard,
        ai_blackboard_source = ai_blackboard_source,
        ai_decision_maker = ai_decision_maker,
        decision_module = decision_module,
        decision_evaluator = decision_evaluator,
        decision_executor = decision_executor,
        executing_decision = executing_decision,
        executing_decision_target = executing_decision_target,
        execute_actinter = execute_actinter,
        execute_actinter_pack = execute_actinter_pack,
        execute_actinter_pack_path = execute_actinter_pack_path,
        full_node = full_node,
        upper_node = upper_node,
        human = human,
        runtime_character = actor.runtime_character or fallback_runtime_character,
        pawn = fallback_pawn,
    }
end

local function summarize_actor(actor, fallback_runtime_character, fallback_pawn)
    local context = collect_actor_runtime_context(actor, fallback_runtime_character, fallback_pawn)
    return {
        job = context.current_job,
        action_manager = util.describe_obj(context.action_manager),
        action_manager_address = format_address(context.action_manager),
        action_manager_source = context.action_manager_source,
        current_job_action_ctrl = util.describe_obj(context.action_ctrl),
        current_job_action_ctrl_source = context.action_ctrl_source,
        common_action_selector = util.describe_obj(context.common_action_selector),
        common_action_selector_source = context.common_action_selector_source,
        ai_blackboard_controller = util.describe_obj(context.ai_blackboard),
        ai_blackboard_address = format_address(context.ai_blackboard),
        ai_blackboard_source = context.ai_blackboard_source,
        ai_decision_maker = util.describe_obj(context.ai_decision_maker),
        decision_module = util.describe_obj(context.decision_module),
        decision_executor = util.describe_obj(context.decision_executor),
        executing_decision = util.describe_obj(context.executing_decision),
        executing_decision_target = util.describe_obj(context.executing_decision_target),
        current_execute_actinter = util.describe_obj(context.execute_actinter),
        current_execute_actinter_pack = util.describe_obj(context.execute_actinter_pack),
        current_execute_actinter_pack_path = context.execute_actinter_pack_path,
        human_address = format_address(context.human),
        runtime_character_address = format_address(context.runtime_character),
        pawn_address = format_address(context.pawn),
        full_node = context.full_node,
        upper_node = context.upper_node,
        in_job_action_node = contains_job_action_node(context.full_node, context.current_job)
            or contains_job_action_node(context.upper_node, context.current_job),
    }
end

local function compute_gap(player_summary, pawn_summary)
    if player_summary.job == nil or pawn_summary.job == nil then
        return "unresolved"
    end
    if player_summary.job ~= pawn_summary.job then
        return "job_mismatch"
    end
    if player_summary.current_job_action_ctrl ~= "nil" and pawn_summary.current_job_action_ctrl == "nil" then
        return "pawn_action_ctrl_missing"
    end
    if player_summary.common_action_selector ~= "nil" and pawn_summary.common_action_selector == "nil" then
        return "pawn_common_action_selector_missing"
    end
    if player_summary.ai_blackboard_controller ~= "nil" and pawn_summary.ai_blackboard_controller == "nil" then
        return "pawn_ai_blackboard_missing"
    end
    if player_summary.common_action_selector_source ~= pawn_summary.common_action_selector_source then
        return "common_action_selector_source_diverges"
    end
    if player_summary.in_job_action_node and not pawn_summary.in_job_action_node then
        return "pawn_not_entering_job_action_nodes"
    end
    if player_summary.current_job_action_ctrl_source ~= pawn_summary.current_job_action_ctrl_source then
        return "action_ctrl_source_diverges"
    end
    return "aligned_or_other"
end

local function find_actor_by_target(runtime, target)
    local progression = runtime.progression_state_data
    if target == "player" then
        return progression and progression.player or nil
    end
    if target == "main_pawn" then
        return progression and progression.main_pawn or nil
    end
    return nil
end

local function resolve_target_from_action_manager(runtime, action_manager)
    local summary = get_data(runtime).summary or {}
    local action_manager_address = format_address(action_manager)

    if action_manager ~= nil then
        if action_manager_address ~= "nil" and action_manager_address == tostring(summary.player_action_manager_address or "nil") then
            return "player", find_actor_by_target(runtime, "player"), "action_manager_address"
        end

        if action_manager_address ~= "nil" and action_manager_address == tostring(summary.main_pawn_action_manager_address or "nil") then
            return "main_pawn", find_actor_by_target(runtime, "main_pawn"), "action_manager_address"
        end

    end

    return "unknown", nil, "action_manager_unmatched"
end

local function resolve_target_from_ai_blackboard(runtime, controller)
    local summary = get_data(runtime).summary or {}
    local controller_address = format_address(controller)

    if controller ~= nil then
        if controller_address ~= "nil" and controller_address == tostring(summary.player_ai_blackboard_address or "nil") then
            return "player", find_actor_by_target(runtime, "player"), "controller_address"
        end

        if controller_address ~= "nil" and controller_address == tostring(summary.main_pawn_ai_blackboard_address or "nil") then
            return "main_pawn", find_actor_by_target(runtime, "main_pawn"), "controller_address"
        end

    end

    return "unknown", nil, "controller_unmatched"
end

local function resolve_target_from_ai_target(runtime, ai_target)
    local summary = get_data(runtime).summary or {}
    local ai_target_address = format_address(ai_target)

    if ai_target == nil then
        return "unknown", nil, "ai_target_missing"
    end

    local player_addresses = {
        tostring(summary.player_human_address or "nil"),
        tostring(summary.player_runtime_character_address or "nil"),
    }
    local pawn_addresses = {
        tostring(summary.main_pawn_human_address or "nil"),
        tostring(summary.main_pawn_runtime_character_address or "nil"),
        tostring(summary.main_pawn_pawn_address or "nil"),
    }
    for _, address in ipairs(player_addresses) do
        if ai_target_address ~= "nil" and ai_target_address == address then
            return "player", find_actor_by_target(runtime, "player"), "ai_target_address"
        end
    end

    for _, address in ipairs(pawn_addresses) do
        if ai_target_address ~= "nil" and ai_target_address == address then
            return "main_pawn", find_actor_by_target(runtime, "main_pawn"), "ai_target_address"
        end
    end

    return "unknown", nil, "ai_target_unmatched"
end

local function resolve_actinter_target(runtime, controller, ai_target)
    local target, actor, reason = resolve_target_from_ai_blackboard(runtime, controller)
    if target ~= "unknown" then
        return target, actor, reason
    end

    target, actor, reason = resolve_target_from_ai_target(runtime, ai_target)
    if target ~= "unknown" then
        return target, actor, reason
    end

    return "unknown", nil, "unmatched"
end

local function get_target_runtime_context(runtime, target)
    local actor = find_actor_by_target(runtime, target)
    if target == "player" then
        return actor, collect_actor_runtime_context(actor, runtime.player, nil)
    end
    if target == "main_pawn" then
        return actor, collect_actor_runtime_context(
            actor,
            runtime.main_pawn_data and runtime.main_pawn_data.runtime_character or nil,
            runtime.main_pawn_data and runtime.main_pawn_data.pawn or nil
        )
    end
    if target == "sigurd" then
        return actor, collect_actor_runtime_context(actor, actor and actor.runtime_character or nil, nil)
    end
    return nil, collect_actor_runtime_context(nil, nil, nil)
end

local DECISION_ACTOR_ADDRESS_KEYS = {
    "ai_decision_maker",
    "decision_module",
    "decision_evaluator",
    "decision_executor",
    "executing_decision",
    "runtime_character",
    "human",
    "ai_blackboard",
    "action_manager",
}

local function normalize_address_key(text)
    if text == nil then
        return "nil"
    end

    local value = tostring(text)
    if value == "" or value == "nil" then
        return "nil"
    end

    local normalized = value:gsub("^0[xX]", ""):gsub("[^0-9A-Fa-f]", ""):upper()
    normalized = normalized:gsub("^0+", "")
    if normalized == "" then
        normalized = "0"
    end

    return "0x" .. normalized
end

local function extract_address_key_from_text(value)
    local text = tostring(value or "")
    local direct_hex = text:match("0[xX]([0-9A-Fa-f]+)")
    if direct_hex ~= nil then
        return normalize_address_key(direct_hex)
    end

    local trailing_hex = text:match(":%s*([0-9A-Fa-f]+)%s*$")
    if trailing_hex ~= nil then
        return normalize_address_key(trailing_hex)
    end

    return "nil"
end

local function get_runtime_address_key(value)
    local direct_address = format_address(value)
    if direct_address ~= "nil" then
        return normalize_address_key(direct_address)
    end

    return extract_address_key_from_text(value)
end

local function build_decision_actor_index(runtime)
    local index = {
        by_address = {},
        by_target = {},
    }

    local decision_targets = { "main_pawn", "player" }
    for _, target in ipairs(decision_targets) do
        local actor, context = get_target_runtime_context(runtime, target)
        local target_entry = {
            target = target,
            actor = actor,
            context = context,
            addresses = {},
        }
        index.by_target[target] = target_entry

        for _, key in ipairs(DECISION_ACTOR_ADDRESS_KEYS) do
            local candidate = context and context[key] or nil
            local address_key = get_runtime_address_key(candidate)
            if address_key ~= "nil" then
                target_entry.addresses[key] = address_key
                index.by_address[address_key] = index.by_address[address_key] or {}
                table.insert(index.by_address[address_key], {
                    target = target,
                    actor = actor,
                    context = context,
                    key = key,
                    address_key = address_key,
                })
            end
        end
    end

    return index
end

local function get_decision_actor_index(runtime, force_refresh)
    local data = get_data(runtime)
    if force_refresh == true then
        data.decision_actor_index_cache = nil
        data.decision_actor_index_cache_generation = -1
    end

    local generation = tonumber(data.decision_actor_index_generation) or 0
    if data.decision_actor_index_cache == nil
        or data.decision_actor_index_cache_generation ~= generation then
        data.decision_actor_index_cache = build_decision_actor_index(runtime)
        data.decision_actor_index_cache_generation = generation
    end

    return data.decision_actor_index_cache
end

local function resolve_target_from_decision_address(runtime, address_key, preferred_key, force_refresh)
    local normalized = normalize_address_key(address_key)
    if normalized == "nil" then
        return "unknown", nil, nil, tostring(preferred_key or "component") .. "_address_nil", nil
    end

    local matches = get_decision_actor_index(runtime, force_refresh).by_address[normalized]
    if matches == nil or #matches == 0 then
        return "unknown", nil, nil, tostring(preferred_key or "component") .. "_address_unmatched", nil
    end

    local chosen = matches[1]
    if preferred_key ~= nil then
        for _, match in ipairs(matches) do
            if match.key == preferred_key then
                chosen = match
                break
            end
        end
    end

    return chosen.target, chosen.actor, chosen.context, tostring(chosen.key) .. "_address", chosen.key
end

local function resolve_target_from_decision_component(runtime, component, component_key, force_refresh)
    if component == nil then
        return "unknown", nil, nil, tostring(component_key or "component") .. "_missing"
    end

    local component_address = get_runtime_address_key(component)
    if component_address == "nil" then
        return "unknown", nil, nil, tostring(component_key or "component") .. "_address_nil"
    end

    local target, actor, context, reason =
        resolve_target_from_decision_address(runtime, component_address, component_key, force_refresh)
    if target ~= "unknown" then
        return target, actor, context, reason
    end

    return "unknown", nil, nil, tostring(component_key or "component") .. "_unmatched"
end

local function to_managed_safe(value)
    if value == nil then
        return nil
    end

    if type(value) == "userdata" then
        return value
    end

    local ok, managed = pcall(sdk.to_managed_object, value)
    if ok and managed ~= nil then
        return managed
    end

    return nil
end

local function get_hook_arg_dump_limit()
    local settings = config.action_research or {}
    local value = tonumber(settings.decision_hook_arg_dump_limit)
    if value == nil or value < 1 then
        return 5
    end
    return math.floor(value)
end

local function build_hook_arg_entry(index, value)
    local managed = to_managed_safe(value)
    return {
        slot = index,
        raw_type = type(value),
        raw_value = tostring(value),
        raw = value,
        managed = managed,
        managed_desc = util.describe_obj(managed),
        managed_type = util.get_type_full_name(managed) or "nil",
        managed_address = format_address(managed),
        address_key = managed ~= nil and get_runtime_address_key(managed) or get_runtime_address_key(value),
    }
end

local function collect_hook_arg_entries(args)
    local entries = {}
    local limit = get_hook_arg_dump_limit()
    for index = 1, limit do
        table.insert(entries, build_hook_arg_entry(index, args[index]))
    end
    return entries
end

local function decision_hook_strict_target_mode_enabled()
    return config.action_research ~= nil
        and config.action_research.decision_hook_strict_target_mode == true
end

local function collect_fast_hook_entries(args, slots)
    local entries = {}
    for _, index in ipairs(slots or {}) do
        table.insert(entries, build_hook_arg_entry(index, args[index]))
    end
    return entries
end

local function resolve_target_from_decision_fast(runtime, hook_name, component_key, args)
    local fast_entries = collect_fast_hook_entries(args, { 2, 3 })
    local target, actor, context, reason, component, matched_slot =
        resolve_target_from_decision_slots(runtime, component_key, fast_entries, false)
    local matched_key = component_key

    if target == "unknown" and hook_name == "set_executing_decision" then
        local fallback_target, fallback_actor, fallback_context, fallback_reason, fallback_component, fallback_slot, fallback_key =
            resolve_target_from_decision_slots_any(
                runtime,
                fast_entries,
                { "decision_executor", "executing_decision", "decision_module", "decision_evaluator" },
                false
            )
        if fallback_target ~= "unknown" then
            target = fallback_target
            actor = fallback_actor
            context = fallback_context
            reason = fallback_reason
            component = fallback_component
            matched_slot = fallback_slot
            matched_key = fallback_key or component_key
        end
    end

    return target, actor, context, reason, component, matched_slot, matched_key, fast_entries
end

local function format_hook_arg_entries(entries)
    local parts = {}
    for _, entry in ipairs(entries or {}) do
        table.insert(parts, string.format(
            "arg%d=%s[%s] managed=%s type=%s addr=%s",
            tonumber(entry.slot) or -1,
            tostring(entry.raw_value or "nil"),
            tostring(entry.raw_type or "nil"),
            tostring(entry.managed_desc or "nil"),
            tostring(entry.managed_type or "nil"),
            tostring(entry.address_key or entry.managed_address or "nil")
        ))
    end
    return table.concat(parts, "; ")
end

local function serialize_hook_arg_entries(entries)
    local payload = {}
    for _, entry in ipairs(entries or {}) do
        table.insert(payload, string.format(
            "arg%d=%s[%s] managed=%s type=%s addr=%s",
            tonumber(entry.slot) or -1,
            tostring(entry.raw_value or "nil"),
            tostring(entry.raw_type or "nil"),
            tostring(entry.managed_desc or "nil"),
            tostring(entry.managed_type or "nil"),
            tostring(entry.address_key or entry.managed_address or "nil")
        ))
    end
    return payload
end

local function resolve_target_from_decision_entry(runtime, component_key, entry, force_refresh)
    if entry == nil then
        return "unknown", nil, nil, tostring(component_key or "component") .. "_entry_missing", nil
    end

    if entry.managed ~= nil then
        local target, actor, context, reason =
            resolve_target_from_decision_component(runtime, entry.managed, component_key, force_refresh)
        if target ~= "unknown" then
            return target, actor, context, reason, entry.managed
        end
    end

    local address_key = entry.address_key or "nil"
    local target, actor, context, reason =
        resolve_target_from_decision_address(runtime, address_key, component_key, force_refresh)
    if target ~= "unknown" then
        return target, actor, context, reason, entry.managed or entry.raw
    end

    return "unknown", nil, nil, tostring(component_key or "component") .. "_entry_unmatched", entry.managed or entry.raw
end

resolve_target_from_decision_slots = function(runtime, component_key, entries, force_refresh)
    for _, entry in ipairs(entries or {}) do
        local target, actor, context, reason, component =
            resolve_target_from_decision_entry(runtime, component_key, entry, force_refresh)
        if target ~= "unknown" then
            return target, actor, context, reason .. ":slot" .. tostring(entry.slot), component, entry.slot
        end
    end

    return "unknown", nil, nil, tostring(component_key or "component") .. "_arg_slots_unmatched", nil, nil
end

resolve_target_from_decision_slots_any = function(runtime, entries, preferred_keys, force_refresh)
    for _, preferred_key in ipairs(preferred_keys or {}) do
        local target, actor, context, reason, component, slot =
            resolve_target_from_decision_slots(runtime, preferred_key, entries, force_refresh)
        if target ~= "unknown" then
            return target, actor, context, reason, component, slot, preferred_key
        end
    end

    return "unknown", nil, nil, "decision_actor_arg_slots_unmatched", nil, nil, nil
end

local function resolve_target_from_decision_candidate(runtime, candidate, force_refresh)
    if candidate == nil then
        return "unknown", nil, nil, "candidate_missing"
    end

    local candidate_address = get_runtime_address_key(candidate)
    if candidate_address == "nil" then
        return "unknown", nil, nil, "candidate_address_nil"
    end

    local target, actor, context, reason =
        resolve_target_from_decision_address(runtime, candidate_address, "executing_decision", force_refresh)
    if target ~= "unknown" then
        return target, actor, context, reason
    end

    return "unknown", nil, nil, "candidate_unmatched"
end

local function build_decision_candidate_snapshot(candidate)
    local target = candidate and util.safe_field(candidate, "<Target>k__BackingField") or nil
    local target_character = target and util.safe_field(target, "<Character>k__BackingField") or nil
    local chosen_target = target_character or target
    local ai_decision = candidate and util.safe_field(candidate, "<Decision>k__BackingField") or nil
    local pack_data, pack_path = resolve_decision_pack_data(candidate)

    return {
        decision = util.describe_obj(candidate),
        decision_address = get_runtime_address_key(candidate),
        decision_type = util.get_type_full_name(candidate) or "nil",
        ai_decision = util.describe_obj(ai_decision),
        ai_decision_type = util.get_type_full_name(ai_decision) or "nil",
        ai_target = util.describe_obj(target),
        ai_target_type = util.get_type_full_name(target) or "nil",
        target = util.describe_obj(chosen_target),
        target_type = util.get_type_full_name(chosen_target) or "nil",
        pack = util.describe_obj(pack_data),
        pack_type = util.get_type_full_name(pack_data) or "nil",
        pack_path = tostring(pack_path or "nil"),
        pack_family = classify_pack_path(pack_path),
    }
end

local function get_decision_hook_log_limit(key, fallback)
    local settings = config.action_research or {}
    local value = tonumber(settings[key])
    if value == nil or value < 0 then
        return fallback
    end
    return math.floor(value)
end

local function build_method_label(method, matched_by)
    local parts = {}

    local ok_name, name = pcall(function()
        return method:get_name()
    end)
    if ok_name and name ~= nil and tostring(name) ~= "" then
        table.insert(parts, tostring(name))
    end

    local ok_params, num_params = pcall(function()
        return method:get_num_params()
    end)
    if ok_params and num_params ~= nil then
        table.insert(parts, string.format("argc=%s", tostring(num_params)))
    end

    if matched_by ~= nil and tostring(matched_by) ~= "" then
        table.insert(parts, string.format("match=%s", tostring(matched_by)))
    end

    table.insert(parts, string.format("id=%s", tostring(method)))
    return table.concat(parts, " ")
end

local function append_decision_hook_raw_event(runtime, hook_name, method_label, component_key, component, target, reason, candidate, arg_entries, matched_slot)
    local data = get_data(runtime)
    local raw_key = table.concat({
        tostring(hook_name),
        tostring(method_label),
        tostring(component_key),
    }, "|")
    data.decision_hook_raw_counts[raw_key] = (data.decision_hook_raw_counts[raw_key] or 0) + 1
    data.stats.decision_hook_raw_hits = (data.stats.decision_hook_raw_hits or 0) + 1

    local limit = get_decision_hook_log_limit("decision_hook_raw_log_limit", 6)
    if data.decision_hook_raw_counts[raw_key] > limit then
        return
    end

    log.session_marker(runtime, "decision", "decision_hook_raw_hit", {
        hook = tostring(hook_name),
        method = tostring(method_label),
        component_key = tostring(component_key),
        component = util.describe_obj(component),
        component_type = util.get_type_full_name(component) or "nil",
        component_address = get_runtime_address_key(component),
        actor = tostring(target or "unknown"),
        target_reason = tostring(reason or "unresolved"),
        candidate = util.describe_obj(candidate),
        candidate_type = util.get_type_full_name(candidate) or "nil",
        matched_slot = matched_slot ~= nil and tostring(matched_slot) or "nil",
        arg_layout = serialize_hook_arg_entries(arg_entries),
        raw_hit_count = data.decision_hook_raw_counts[raw_key],
    }, string.format(
        "hook=%s method=%s component=%s actor=%s reason=%s slot=%s candidate=%s args=%s count=%s",
        tostring(hook_name),
        tostring(method_label),
        tostring(get_runtime_address_key(component)),
        tostring(target or "unknown"),
        tostring(reason or "unresolved"),
        matched_slot ~= nil and tostring(matched_slot) or "nil",
        tostring(util.describe_obj(candidate)),
        format_hook_arg_entries(arg_entries),
        tostring(data.decision_hook_raw_counts[raw_key])
    ))
end

local function append_decision_hook_unmatched_event(runtime, hook_name, method_label, component_key, component, reason, candidate, arg_entries)
    local data = get_data(runtime)
    local unmatched_key = table.concat({
        tostring(hook_name),
        tostring(method_label),
        tostring(component_key),
        tostring(reason or "unresolved"),
    }, "|")
    data.decision_hook_unmatched_counts[unmatched_key] = (data.decision_hook_unmatched_counts[unmatched_key] or 0) + 1

    local limit = get_decision_hook_log_limit("decision_hook_unmatched_log_limit", 6)
    if data.decision_hook_unmatched_counts[unmatched_key] > limit then
        return
    end

    log.session_marker(runtime, "decision", "decision_hook_unmatched", {
        hook = tostring(hook_name),
        method = tostring(method_label),
        component_key = tostring(component_key),
        component = util.describe_obj(component),
        component_type = util.get_type_full_name(component) or "nil",
        component_address = get_runtime_address_key(component),
        target_reason = tostring(reason or "unresolved"),
        candidate = util.describe_obj(candidate),
        candidate_type = util.get_type_full_name(candidate) or "nil",
        arg_layout = serialize_hook_arg_entries(arg_entries),
        unmatched_count = data.decision_hook_unmatched_counts[unmatched_key],
    }, string.format(
        "hook=%s method=%s component=%s reason=%s candidate=%s args=%s count=%s",
        tostring(hook_name),
        tostring(method_label),
        tostring(get_runtime_address_key(component)),
        tostring(reason or "unresolved"),
        tostring(util.describe_obj(candidate)),
        format_hook_arg_entries(arg_entries),
        tostring(data.decision_hook_unmatched_counts[unmatched_key])
    ))
end

local function process_main_pawn_overwrite_tracker(
    runtime,
    data,
    hook_name,
    method_label,
    reason,
    actor_job,
    after_context,
    old_pack_path,
    old_pack_family,
    new_pack_path,
    new_pack_family,
    old_phase,
    new_phase,
    old_nodes,
    new_nodes,
    old_decision,
    new_decision,
    old_target,
    new_target,
    candidate
)
    local tracker = get_main_pawn_overwrite_tracker(data)

    if new_phase == "combat_job" and should_arm_main_pawn_overwrite_tracker(new_pack_family, new_nodes) then
        local should_rearm = tracker.active ~= true
            or tracker.combat_pack_path ~= tostring(new_pack_path or "nil")
            or tracker.combat_nodes ~= tostring(new_nodes or "nil|nil")
        if should_rearm then
            tracker = arm_main_pawn_overwrite_tracker(
                data,
                hook_name,
                method_label,
                reason,
                actor_job,
                new_pack_path,
                new_pack_family,
                new_nodes,
                new_decision,
                new_target
            )
        end
    end

    if tracker.active ~= true then
        return
    end

    tracker.transition_count = (tracker.transition_count or 0) + 1

    if not is_generic_overwrite_phase(new_phase, new_pack_family, new_pack_path) then
        return
    end

    local overwrite_signature = table.concat({
        tostring(hook_name),
        tostring(method_label),
        tostring(old_pack_path),
        tostring(new_pack_path),
        tostring(old_nodes),
        tostring(new_nodes),
        tostring(new_decision),
    }, "|")
    if tracker.last_emitted_signature == overwrite_signature then
        return
    end
    tracker.last_emitted_signature = overwrite_signature
    tracker.active = false
    data.stats.decision_overwrite_events = (data.stats.decision_overwrite_events or 0) + 1

    log.session_marker(runtime, "decision", "decision_overwrite_attributed", {
        actor = "main_pawn",
        actor_job = actor_job,
        source_hook = tostring(hook_name),
        source_method = tostring(method_label),
        source_reason = tostring(reason or "unresolved"),
        tracker_generation = tracker.generation or 0,
        tracker_transition_count = tracker.transition_count or 0,
        combat_pack_path = tostring(tracker.combat_pack_path or "nil"),
        combat_pack_family = tostring(tracker.combat_pack_family or "nil"),
        combat_nodes = tostring(tracker.combat_nodes or "nil|nil"),
        combat_decision = tostring(tracker.combat_decision or "nil"),
        combat_target = tostring(tracker.combat_target or "nil"),
        old_phase = tostring(old_phase),
        new_phase = tostring(new_phase),
        old_pack_path = tostring(old_pack_path),
        old_pack_family = tostring(old_pack_family),
        new_pack_path = tostring(new_pack_path),
        new_pack_family = tostring(new_pack_family),
        old_nodes = tostring(old_nodes),
        new_nodes = tostring(new_nodes),
        old_decision = tostring(old_decision),
        new_decision = tostring(new_decision),
        old_target = tostring(old_target),
        new_target = tostring(new_target),
        last_request_action = tostring(tracker.last_request_action or "nil"),
        last_request_priority = tostring(tracker.last_request_priority or "nil"),
        last_request_nodes = tostring(tracker.last_request_nodes or "nil|nil"),
        last_request_reason = tostring(tracker.last_request_reason or "unresolved"),
        last_actinter_pack_path = tostring(tracker.last_actinter_pack_path or "nil"),
        last_actinter_target = tostring(tracker.last_actinter_target or "none"),
        last_actinter_target_reason = tostring(tracker.last_actinter_target_reason or "unresolved"),
        last_actinter_nodes = tostring(tracker.last_actinter_nodes or "nil|nil"),
    }, string.format(
        "actor=main_pawn src=%s phase=%s->%s combat_pack=%s overwrite=%s->%s last_req=%s/%s last_actinter=%s",
        tostring(hook_name),
        tostring(old_phase),
        tostring(new_phase),
        tostring(tracker.combat_pack_path),
        tostring(old_pack_path),
        tostring(new_pack_path),
        tostring(tracker.last_request_action),
        tostring(tracker.last_request_priority),
        tostring(tracker.last_actinter_pack_path)
    ))
end

local function emit_main_pawn_job07_carrier_trace(
    runtime,
    data,
    hook_name,
    method_label,
    reason,
    actor_job,
    before_context,
    after_context,
    candidate_snapshot
)
    if action_research_bool_setting("enable_main_pawn_job07_carrier_trace", true) ~= true then
        return
    end

    if not job_equals(actor_job, 7) then
        return
    end

    local context = after_context or before_context
    if context == nil then
        return
    end

    local new_pack_path = after_context and tostring(after_context.execute_actinter_pack_path or "nil") or "nil"
    local new_nodes = string.format(
        "%s|%s",
        tostring(after_context and after_context.full_node or "nil"),
        tostring(after_context and after_context.upper_node or "nil")
    )
    local selector_source = tostring(context.common_action_selector_source or "unresolved")
    local blackboard_source = tostring(context.ai_blackboard_source or "unresolved")
    local signature = table.concat({
        tostring(hook_name),
        tostring(method_label),
        tostring(candidate_snapshot and candidate_snapshot.pack_path or "nil"),
        tostring(candidate_snapshot and candidate_snapshot.target or "nil"),
        tostring(new_pack_path),
        tostring(new_nodes),
        tostring(selector_source),
        tostring(blackboard_source),
        tostring(util.describe_obj(context.execute_actinter_pack) or "nil"),
        tostring(util.describe_obj(context.executing_decision) or "nil"),
    }, "|")
    if data.job07_carrier_trace_last_signature == signature then
        return
    end
    data.job07_carrier_trace_last_signature = signature

    log.session_marker(runtime, "decision", "job07_carrier_context_signal", {
        actor = "main_pawn",
        actor_job = actor_job,
        hook = tostring(hook_name),
        method = tostring(method_label),
        target_reason = tostring(reason or "unresolved"),
        candidate_pack_path = tostring(candidate_snapshot and candidate_snapshot.pack_path or "nil"),
        candidate_pack_family = tostring(candidate_snapshot and candidate_snapshot.pack_family or "nil"),
        candidate_is_job07_specific = candidate_snapshot ~= nil
            and is_job07_specific_pack_family(candidate_snapshot.pack_family) or false,
        candidate_target = tostring(candidate_snapshot and candidate_snapshot.target or "nil"),
        candidate_target_type = tostring(candidate_snapshot and candidate_snapshot.target_type or "nil"),
        current_pack_path = tostring(new_pack_path),
        current_pack_family = classify_pack_path(new_pack_path),
        current_nodes = tostring(new_nodes),
        current_phase = classify_decision_phase(new_pack_path, new_nodes, after_context and after_context.last_requested_action or nil),
        executing_decision = util.describe_obj(context.executing_decision),
        executing_target = util.describe_obj(context.executing_decision_target),
        executing_target_type = util.get_type_full_name(context.executing_decision_target) or "nil",
        execute_actinter = util.describe_obj(context.execute_actinter),
        execute_actinter_pack = util.describe_obj(context.execute_actinter_pack),
        execute_actinter_pack_path = tostring(context.execute_actinter_pack_path or "nil"),
        ai_blackboard = util.describe_obj(context.ai_blackboard),
        ai_blackboard_source = blackboard_source,
        selector = util.describe_obj(context.common_action_selector),
        selector_source = selector_source,
        selector_context = build_typed_snapshot_text(
            context.common_action_selector,
            { "select", "target", "decision", "combat", "move", "action" },
            12
        ),
        action_ctrl = util.describe_obj(context.action_ctrl),
        action_ctrl_source = tostring(context.action_ctrl_source or "unresolved"),
    }, string.format(
        "actor=main_pawn job=7 hook=%s candidate=%s[%s] current=%s nodes=%s selector=%s bb=%s exec=%s",
        tostring(hook_name),
        tostring(candidate_snapshot and candidate_snapshot.pack_path or "nil"),
        tostring(candidate_snapshot and candidate_snapshot.pack_family or "nil"),
        tostring(new_pack_path),
        tostring(new_nodes),
        tostring(selector_source),
        tostring(blackboard_source),
        tostring(context.execute_actinter_pack_path or "nil")
    ))
end

local function append_decision_hook_event(runtime, hook_name, method_label, target, actor, reason, before_context, after_context, candidate)
    if target ~= "main_pawn" and target ~= "player" then
        return
    end

    local data = get_data(runtime)
    local actor_job = actor and (actor.current_job or actor.raw_job) or (after_context and after_context.current_job) or (before_context and before_context.current_job) or nil
    local selector = (after_context and after_context.common_action_selector) or (before_context and before_context.common_action_selector) or nil
    local selector_source = (after_context and after_context.common_action_selector_source) or (before_context and before_context.common_action_selector_source) or "unresolved"
    local selector_context = build_typed_snapshot_text(
        selector,
        { "select", "target", "decision", "combat", "move", "action" },
        12
    )
    local candidate_snapshot = build_decision_candidate_snapshot(candidate)
    local old_pack_path = before_context and before_context.execute_actinter_pack_path or "nil"
    local new_pack_path = after_context and after_context.execute_actinter_pack_path or "nil"
    local old_target = before_context and util.describe_obj(before_context.executing_decision_target) or "nil"
    local new_target = after_context and util.describe_obj(after_context.executing_decision_target) or "nil"
    local old_decision = before_context and util.describe_obj(before_context.executing_decision) or "nil"
    local new_decision = after_context and util.describe_obj(after_context.executing_decision) or "nil"
    local old_nodes = string.format(
        "%s|%s",
        tostring(before_context and before_context.full_node or "nil"),
        tostring(before_context and before_context.upper_node or "nil")
    )
    local new_nodes = string.format(
        "%s|%s",
        tostring(after_context and after_context.full_node or "nil"),
        tostring(after_context and after_context.upper_node or "nil")
    )
    local old_action = before_context and before_context.last_requested_action or nil
    local new_action = after_context and after_context.last_requested_action or nil
    local old_pack_family = classify_pack_path(old_pack_path)
    local new_pack_family = classify_pack_path(new_pack_path)
    local old_phase = classify_decision_phase(old_pack_path, old_nodes, old_action)
    local new_phase = classify_decision_phase(new_pack_path, new_nodes, new_action)
    local signature = table.concat({
        tostring(hook_name),
        tostring(method_label),
        tostring(target),
        tostring(actor_job),
        tostring(candidate_snapshot.decision_address),
        tostring(candidate_snapshot.pack_path),
        tostring(old_pack_path),
        tostring(new_pack_path),
        tostring(old_nodes),
        tostring(new_nodes),
        tostring(candidate_snapshot.target),
    }, "|")
    local dedupe_key = tostring(hook_name) .. ":" .. tostring(method_label) .. ":" .. tostring(target)
    if data.last_decision_hook_signatures[dedupe_key] == signature then
        return
    end
    data.last_decision_hook_signatures[dedupe_key] = signature
    data.stats.decision_hook_events = (data.stats.decision_hook_events or 0) + 1

    log.session_marker(runtime, "decision", "decision_hook_" .. tostring(hook_name), {
        hook = tostring(hook_name),
        method = tostring(method_label),
        actor = tostring(target),
        actor_job = actor_job,
        target_reason = tostring(reason or "unresolved"),
        chosen_decision = candidate_snapshot.decision,
        chosen_decision_type = candidate_snapshot.decision_type,
        chosen_ai_decision = candidate_snapshot.ai_decision,
        chosen_ai_decision_type = candidate_snapshot.ai_decision_type,
        chosen_target = candidate_snapshot.target,
        chosen_target_type = candidate_snapshot.target_type,
        chosen_ai_target = candidate_snapshot.ai_target,
        chosen_ai_target_type = candidate_snapshot.ai_target_type,
        chosen_pack = candidate_snapshot.pack,
        chosen_pack_type = candidate_snapshot.pack_type,
        chosen_pack_path = candidate_snapshot.pack_path,
        chosen_pack_family = candidate_snapshot.pack_family,
        old_pack_path = tostring(old_pack_path),
        old_pack_family = old_pack_family,
        new_pack_path = tostring(new_pack_path),
        new_pack_family = new_pack_family,
        old_executing_decision = tostring(old_decision),
        new_executing_decision = tostring(new_decision),
        old_target = tostring(old_target),
        new_target = tostring(new_target),
        old_nodes = tostring(old_nodes),
        new_nodes = tostring(new_nodes),
        old_phase = tostring(old_phase),
        new_phase = tostring(new_phase),
        selector = util.describe_obj(selector),
        selector_source = tostring(selector_source),
        selector_context = tostring(selector_context),
        decision_module = after_context and util.describe_obj(after_context.decision_module) or "nil",
        decision_evaluator = after_context and util.describe_obj(after_context.decision_evaluator) or "nil",
        decision_executor = after_context and util.describe_obj(after_context.decision_executor) or "nil",
    }, string.format(
        "hook=%s method=%s actor=%s job=%s chosen_pack=%s old_pack=%s new_pack=%s target=%s nodes=%s->%s",
        tostring(hook_name),
        tostring(method_label),
        tostring(target),
        tostring(actor_job),
        tostring(candidate_snapshot.pack_path),
        tostring(old_pack_path),
        tostring(new_pack_path),
        tostring(candidate_snapshot.target_type),
        tostring(old_nodes),
        tostring(new_nodes)
    ))

    if target == "main_pawn" then
        emit_main_pawn_job07_carrier_trace(
            runtime,
            data,
            hook_name,
            method_label,
            reason,
            actor_job,
            before_context,
            after_context,
            candidate_snapshot
        )

        process_main_pawn_overwrite_tracker(
            runtime,
            data,
            hook_name,
            method_label,
            reason,
            actor_job,
            after_context,
            old_pack_path,
            old_pack_family,
            new_pack_path,
            new_pack_family,
            old_phase,
            new_phase,
            old_nodes,
            new_nodes,
            old_decision,
            new_decision,
            old_target,
            new_target,
            candidate
        )
    end

    if should_emit_decision_transition_signal(target, old_phase, new_phase, old_pack_family, new_pack_family) then
        log.session_marker(runtime, "decision", "decision_transition_signal", {
            hook = tostring(hook_name),
            method = tostring(method_label),
            actor = tostring(target),
            actor_job = actor_job,
            old_phase = tostring(old_phase),
            new_phase = tostring(new_phase),
            old_pack_path = tostring(old_pack_path),
            old_pack_family = tostring(old_pack_family),
            new_pack_path = tostring(new_pack_path),
            new_pack_family = tostring(new_pack_family),
            old_nodes = tostring(old_nodes),
            new_nodes = tostring(new_nodes),
            old_executing_decision = tostring(old_decision),
            new_executing_decision = tostring(new_decision),
        }, string.format(
            "actor=%s phase=%s->%s old_pack=%s new_pack=%s nodes=%s->%s",
            tostring(target),
            tostring(old_phase),
            tostring(new_phase),
            tostring(old_pack_path),
            tostring(new_pack_path),
            tostring(old_nodes),
            tostring(new_nodes)
        ))
    end
end

local function append_resolved_method(results, seen, method, matched_by)
    if method == nil then
        return
    end

    local key = tostring(method)
    if seen[key] then
        return
    end
    seen[key] = true

    table.insert(results, {
        method = method,
        label = build_method_label(method, matched_by),
    })
end

local function resolve_typedef_methods(td, candidate_signatures, candidate_names)
    if td == nil then
        return {}
    end

    local results = {}
    local seen = {}

    for _, signature in ipairs(candidate_signatures or {}) do
        local ok, method = pcall(function()
            return td:get_method(signature)
        end)
        if ok and method ~= nil then
            append_resolved_method(results, seen, method, signature)
        end
    end

    local ok_methods, methods = pcall(function()
        return td:get_methods()
    end)
    if not ok_methods or methods == nil then
        return results
    end

    for _, candidate_name in ipairs(candidate_names or {}) do
        for _, method in ipairs(methods) do
            local ok_name, name = pcall(function()
                return method:get_name()
            end)
            if ok_name and tostring(name) == tostring(candidate_name) then
                append_resolved_method(results, seen, method, candidate_name)
            end
        end
    end

    return results
end

local function install_decision_runtime_hook(runtime, data, type_name, component_key, hook_name, candidate_signatures, candidate_names, candidate_from)
    local td = util.safe_sdk_typedef(type_name)
    if td == nil then
        table.insert(data.registration_errors, string.format("%s typedef missing", tostring(type_name)))
        return false
    end

    local methods = resolve_typedef_methods(td, candidate_signatures, candidate_names)
    if #methods == 0 then
        table.insert(data.registration_errors, string.format(
            "%s method missing: %s",
            tostring(type_name),
            table.concat(candidate_names or candidate_signatures or {}, " | ")
        ))
        return false
    end

    local installed = 0

    for _, entry in ipairs(methods) do
        local ok_hook, hook_error = pcall(function()
            sdk.hook(
                entry.method,
                function(args)
                    local storage = thread.get_hook_storage()
                    local target, actor, before_context, reason, component, matched_slot, matched_key, fast_entries =
                        resolve_target_from_decision_fast(runtime, hook_name, component_key, args)
                    local candidate = candidate_from == "arg" and to_managed_safe(args[3]) or nil

                    if target == "unknown" and decision_hook_strict_target_mode_enabled() then
                        storage.skip = true
                        return
                    end

                    local arg_entries = fast_entries
                    if target ~= "unknown" or not decision_hook_strict_target_mode_enabled() then
                        arg_entries = collect_hook_arg_entries(args)
                        if target == "unknown" then
                            target, actor, before_context, reason, component, matched_slot =
                                resolve_target_from_decision_slots(runtime, component_key, arg_entries, false)
                            matched_key = component_key
                            if target == "unknown" and hook_name == "set_executing_decision" then
                                local fallback_target, fallback_actor, fallback_context, fallback_reason, fallback_component, fallback_slot, fallback_key =
                                    resolve_target_from_decision_slots_any(
                                        runtime,
                                        arg_entries,
                                        { "decision_executor", "executing_decision", "decision_module", "decision_evaluator" },
                                        false
                                    )
                                if fallback_target ~= "unknown" then
                                    target = fallback_target
                                    actor = fallback_actor
                                    before_context = fallback_context
                                    reason = fallback_reason
                                    component = fallback_component
                                    matched_slot = fallback_slot
                                    matched_key = fallback_key or component_key
                                end
                            end
                        end
                    end

                    storage.target = target
                    storage.actor = actor
                    storage.reason = reason
                    storage.before_context = before_context
                    storage.candidate = candidate
                    storage.component = component
                    storage.component_key = matched_key
                    storage.method_label = entry.label
                    storage.arg_entries = arg_entries
                    storage.matched_slot = matched_slot

                    append_decision_hook_raw_event(
                        runtime,
                        hook_name,
                        entry.label,
                        matched_key,
                        component,
                        target,
                        reason,
                        candidate,
                        arg_entries,
                        matched_slot
                    )
                end,
                function(retval)
                    local storage = thread.get_hook_storage()
                    if storage.skip == true then
                        return retval
                    end
                    local target = storage.target or "unknown"
                    local actor = storage.actor
                    local reason = storage.reason
                    local candidate = storage.candidate
                    if candidate_from == "retval" then
                        candidate = to_managed_safe(retval)
                    end

                    local after_context = nil
                    if target ~= "unknown" then
                        local _, resolved_context = get_target_runtime_context(runtime, target)
                        after_context = resolved_context
                    end

                    if target == "unknown" then
                        local resolved_target, resolved_actor, resolved_context, resolved_reason =
                            resolve_target_from_decision_candidate(
                                runtime,
                                candidate,
                                hook_name == "set_executing_decision"
                            )
                        if resolved_target ~= "unknown" then
                            target = resolved_target
                            actor = resolved_actor
                            after_context = resolved_context
                            reason = resolved_reason
                        end
                    end

                    if target == "unknown" and hook_name == "set_executing_decision" then
                        local fallback_target, fallback_actor, fallback_context, fallback_reason =
                            resolve_target_from_decision_slots_any(
                                runtime,
                                storage.arg_entries,
                                { "decision_executor", "executing_decision", "decision_module", "decision_evaluator" },
                                true
                            )
                        if fallback_target ~= "unknown" then
                            target = fallback_target
                            actor = fallback_actor
                            after_context = fallback_context
                            reason = fallback_reason
                        end
                    end

                    if target == "unknown" then
                        append_decision_hook_unmatched_event(
                            runtime,
                            hook_name,
                            storage.method_label or entry.label,
                            storage.component_key or component_key,
                            storage.component,
                            reason,
                            candidate,
                            storage.arg_entries
                        )
                        return retval
                    end

                    if candidate == nil and after_context ~= nil then
                        candidate = after_context.executing_decision
                    end

                    append_decision_hook_event(
                        runtime,
                        hook_name,
                        storage.method_label or entry.label,
                        target,
                        actor,
                        reason,
                        storage.before_context,
                        after_context,
                        candidate
                    )
                    return retval
                end
            )
        end)

        if ok_hook then
            installed = installed + 1
            table.insert(data.installed_methods, string.format("%s::%s", tostring(type_name), tostring(entry.label)))
        else
            table.insert(data.registration_errors, string.format(
                "%s hook install failed: %s (%s)",
                tostring(type_name),
                tostring(entry.label),
                tostring(hook_error)
            ))
        end
    end

    return installed > 0
end

local function update_job07_actor_runtime_probe(runtime, data, target, actor, action_name)
    if target ~= "main_pawn" or actor == nil then
        return
    end

    local current_job = actor.current_job or actor.raw_job
    if tostring(current_job) ~= "7" then
        return
    end

    local fallback_runtime_character = runtime.main_pawn_data and runtime.main_pawn_data.runtime_character or nil
    local fallback_pawn = runtime.main_pawn_data and runtime.main_pawn_data.pawn or nil

    local context = collect_actor_runtime_context(actor, fallback_runtime_character, fallback_pawn)
    local trigger_signature = table.concat({
        tostring(action_name or "nil"),
        tostring(context.full_node or "nil"),
        tostring(context.upper_node or "nil"),
        tostring(context.execute_actinter_pack_path or "nil"),
    }, "|")

    if data.last_pair_probe_trigger[target] == trigger_signature then
        return
    end
    data.last_pair_probe_trigger[target] = trigger_signature
    data.summary[target .. "_job07_decision_packhandler_snapshot"] = build_job07_packhandler_snapshot(context)
end

local function append_request_action_event(runtime, action_manager, priority, action_name)
    local data = get_data(runtime)
    local target, actor, target_reason = resolve_target_from_action_manager(runtime, action_manager)
    if target == "unknown" and config.action_research
        and config.action_research.observe_unknown_request_actions ~= true then
        return
    end
    local current_job = actor and (actor.current_job or actor.raw_job) or nil

    local event = {
        player_job = data.summary and data.summary.player_job or nil,
        player_runtime_character_address = data.summary and data.summary.player_runtime_character_address or "nil",
        player_current_job_action_ctrl_source = data.summary and data.summary.player_current_job_action_ctrl_source or "unresolved",
        player_common_action_selector_source = data.summary and data.summary.player_common_action_selector_source or "unresolved",
        player_ai_blackboard_address = data.summary and data.summary.player_ai_blackboard_address or "nil",
        player_executing_decision = data.summary and data.summary.player_executing_decision or "nil",
        player_executing_decision_target = data.summary and data.summary.player_executing_decision_target or "nil",
        player_full_node = data.summary and data.summary.player_full_node or "nil",
        player_upper_node = data.summary and data.summary.player_upper_node or "nil",
        main_pawn_job = data.summary and data.summary.main_pawn_job or nil,
        main_pawn_runtime_character_address = data.summary and data.summary.main_pawn_runtime_character_address or "nil",
        main_pawn_current_job_action_ctrl_source = data.summary and data.summary.main_pawn_current_job_action_ctrl_source or "unresolved",
        main_pawn_common_action_selector_source = data.summary and data.summary.main_pawn_common_action_selector_source or "unresolved",
        main_pawn_ai_blackboard_address = data.summary and data.summary.main_pawn_ai_blackboard_address or "nil",
        main_pawn_executing_decision = data.summary and data.summary.main_pawn_executing_decision or "nil",
        main_pawn_executing_decision_target = data.summary and data.summary.main_pawn_executing_decision_target or "nil",
        main_pawn_full_node = data.summary and data.summary.main_pawn_full_node or "nil",
        main_pawn_upper_node = data.summary and data.summary.main_pawn_upper_node or "nil",
        current_job_gap = data.summary and data.summary.current_job_gap or "unresolved",
        request_action_target = target,
        request_action_target_reason = target_reason,
        request_action_job = current_job,
        request_action_manager = util.describe_obj(action_manager),
        request_action_manager_address = format_address(action_manager),
        request_action_priority = tostring(priority),
        request_action_name = tostring(action_name),
        request_action_full_node = actor and actor.full_node or "nil",
        request_action_upper_node = actor and actor.upper_node or "nil",
    }

    if target == "unknown" and should_suppress_unknown_request_action(action_name) then
        return
    end

    data.stats.request_action_calls = (data.stats.request_action_calls or 0) + 1
    if target == "player" then
        data.summary.player_request_action_calls = (data.summary.player_request_action_calls or 0) + 1
        data.summary.player_last_requested_action = tostring(action_name)
        data.summary.player_last_requested_priority = tostring(priority)
    elseif target == "main_pawn" then
        data.summary.main_pawn_request_action_calls = (data.summary.main_pawn_request_action_calls or 0) + 1
        data.summary.main_pawn_last_requested_action = tostring(action_name)
        data.summary.main_pawn_last_requested_priority = tostring(priority)
        track_main_pawn_request_action(
            data,
            target_reason,
            action_name,
            priority,
            event.request_action_full_node,
            event.request_action_upper_node
        )
    end

    update_job07_actor_runtime_probe(runtime, data, target, actor, action_name)

    if target == "player" or target == "main_pawn" then
        local bucket = data.observed_request_actions[target]
        if bucket ~= nil then
            local key = string.format("%s|%s", tostring(current_job), tostring(action_name))
            local observed = bucket[key]
            if observed == nil then
                observed = {
                    target = target,
                    job = current_job,
                    action = tostring(action_name),
                    count = 0,
                    priorities = {},
                    first_nodes = string.format("%s|%s", tostring(event.request_action_full_node), tostring(event.request_action_upper_node)),
                }
                bucket[key] = observed
                log.session_marker(runtime, "skill", "request_action_first_seen", {
                    request_action_target = target,
                    request_action_job = current_job,
                    request_action_name = tostring(action_name),
                    request_action_priority = tostring(priority),
                    request_action_nodes = observed.first_nodes,
                }, string.format(
                    "target=%s job=%s action=%s priority=%s nodes=%s",
                    tostring(target),
                    tostring(current_job),
                    tostring(action_name),
                    tostring(priority),
                    tostring(observed.first_nodes)
                ))
            end
            observed.count = (observed.count or 0) + 1
            observed.priorities[tostring(priority)] = true

            local observed_count = 0
            for _ in pairs(bucket) do
                observed_count = observed_count + 1
            end
            if target == "player" then
                data.summary.player_observed_request_action_count = observed_count
            else
                data.summary.main_pawn_observed_request_action_count = observed_count
            end
        end
    end

    table.insert(data.recent_events, 1, event)
    while #data.recent_events > (config.action_research.trace_history_limit or 24) do
        table.remove(data.recent_events)
    end

    log.session_marker(runtime, "skill", "request_action_observed", event, string.format(
        "target=%s via=%s job=%s action=%s priority=%s nodes=%s|%s gap=%s",
        tostring(target),
        tostring(target_reason),
        tostring(current_job),
        tostring(action_name),
        tostring(priority),
        tostring(event.request_action_full_node),
        tostring(event.request_action_upper_node),
        tostring(event.current_job_gap)
    ))

    local function snapshot_decision_fields(snapshot_target, snapshot_actor, snapshot_action)
        if snapshot_actor == nil then
            return
        end

        local fallback_runtime_character = nil
        local fallback_pawn = nil
        if snapshot_target == "player" then
            fallback_runtime_character = runtime.player
        else
            fallback_runtime_character = runtime.main_pawn_data and runtime.main_pawn_data.runtime_character or nil
            fallback_pawn = runtime.main_pawn_data and runtime.main_pawn_data.pawn or nil
        end

        local snapshot_context = collect_actor_runtime_context(snapshot_actor, fallback_runtime_character, fallback_pawn)
        local decision_obj = snapshot_context.executing_decision
        local decision_desc = util.describe_obj(decision_obj)
        if decision_obj == nil or decision_desc == "nil" then
            return
        end

        local fields = util.get_fields_snapshot(decision_obj, config.action_research.pack_snapshot_field_limit or 12)
        local field_parts = {}
        for _, field in ipairs(fields or {}) do
            table.insert(field_parts, string.format("%s=%s", tostring(field.name), tostring(field.value)))
        end
        local fields_text = table.concat(field_parts, "; ")
        local bucket = data.observed_decision_snapshots[snapshot_target]
        if bucket == nil then
            return
        end

        local signature = table.concat({
            tostring(snapshot_actor.current_job or snapshot_actor.raw_job),
            tostring(snapshot_action),
            tostring(snapshot_context.full_node),
            tostring(snapshot_context.upper_node),
            tostring(decision_desc),
            tostring(util.describe_obj(snapshot_context.executing_decision_target)),
            tostring(snapshot_context.execute_actinter_pack_path),
            tostring(fields_text),
        }, "|")

        local observed = bucket[signature]
        if observed == nil then
            observed = {
                target = snapshot_target,
                job = snapshot_actor.current_job or snapshot_actor.raw_job,
                action = tostring(snapshot_action),
                nodes = string.format("%s|%s", tostring(snapshot_context.full_node), tostring(snapshot_context.upper_node)),
                decision = tostring(decision_desc),
                decision_target = tostring(util.describe_obj(snapshot_context.executing_decision_target)),
                pack_path = tostring(snapshot_context.execute_actinter_pack_path),
                fields = fields,
                count = 0,
            }
            bucket[signature] = observed
            log.session_marker(runtime, "skill", "decision_snapshot_first_seen", {
                decision_snapshot_target = snapshot_target,
                decision_snapshot_job = observed.job,
                decision_snapshot_action = observed.action,
                decision_snapshot_nodes = observed.nodes,
                decision_snapshot = observed.decision,
                decision_snapshot_target_obj = observed.decision_target,
                decision_snapshot_pack_path = observed.pack_path,
                decision_snapshot_fields = fields_text,
            }, string.format(
                "target=%s action=%s nodes=%s decision=%s target_obj=%s pack=%s fields=%s",
                tostring(snapshot_target),
                tostring(observed.action),
                tostring(observed.nodes),
                tostring(observed.decision),
                tostring(observed.decision_target),
                tostring(observed.pack_path),
                tostring(fields_text)
            ))
        end

        observed.count = (observed.count or 0) + 1
        data.stats.decision_snapshot_hits = (data.stats.decision_snapshot_hits or 0) + 1
        data.summary.decision_snapshot_hits = (data.summary.decision_snapshot_hits or 0) + 1
        data.summary.last_decision_snapshot_target = tostring(snapshot_target)
        data.summary.last_decision_snapshot_action = tostring(snapshot_action)
        data.summary.last_decision_snapshot_fields = tostring(fields_text)
        if observed.pack_path ~= nil and observed.pack_path ~= "nil" then
            data.summary[snapshot_target .. "_last_decision_snapshot_pack_path"] = tostring(observed.pack_path)
        end

        if snapshot_target == "main_pawn" then
            local ai_decision = nil
            local ai_target = nil
            local decision_pack = nil
            if fields ~= nil then
                for _, field in ipairs(fields) do
                    if tostring(field.name) == "<Decision>k__BackingField" then
                        ai_decision = field.value
                    elseif tostring(field.name) == "<Target>k__BackingField" then
                        ai_target = field.value
                    elseif tostring(field.name) == "<ActionPackData>k__BackingField" then
                        decision_pack = field.value
                    end
                end
            end

            local ai_decision_desc = util.describe_obj(ai_decision)
            if ai_decision ~= nil and ai_decision_desc ~= "nil" then
                local ai_fields = util.get_fields_snapshot(ai_decision, config.action_research.pack_snapshot_field_limit or 12)
                local ai_field_parts = {}
                for _, field in ipairs(ai_fields or {}) do
                    table.insert(ai_field_parts, string.format("%s=%s", tostring(field.name), tostring(field.value)))
                end
                local ai_fields_text = table.concat(ai_field_parts, "; ")
                local ai_type_text = build_typed_snapshot_text(
                    ai_decision,
                    { "target", "pack", "action", "decision", "combat", "move", "follow", "task" },
                    16
                )
                if ai_fields_text == "" then
                    ai_fields_text = ai_type_text
                else
                    ai_fields_text = ai_type_text .. "; " .. ai_fields_text
                end
                local ai_signature = table.concat({
                    tostring(snapshot_actor.current_job or snapshot_actor.raw_job),
                    tostring(snapshot_action),
                    tostring(ai_decision_desc),
                    tostring(ai_fields_text),
                }, "|")

                local ai_observed = data.observed_ai_decision_snapshots[ai_signature]
                if ai_observed == nil then
                    ai_observed = {
                        job = snapshot_actor.current_job or snapshot_actor.raw_job,
                        action = tostring(snapshot_action),
                        decision = tostring(ai_decision_desc),
                        fields = ai_fields,
                        fields_text = tostring(ai_fields_text),
                        count = 0,
                    }
                    data.observed_ai_decision_snapshots[ai_signature] = ai_observed
                    log.session_marker(runtime, "skill", "ai_decision_snapshot_first_seen", {
                        ai_decision_snapshot_job = ai_observed.job,
                        ai_decision_snapshot_action = ai_observed.action,
                        ai_decision_snapshot = ai_observed.decision,
                        ai_decision_snapshot_fields = ai_fields_text,
                    }, string.format(
                        "action=%s decision=%s fields=%s",
                        tostring(ai_observed.action),
                        tostring(ai_observed.decision),
                        tostring(ai_fields_text)
                    ))
                end

                ai_observed.count = (ai_observed.count or 0) + 1
                ai_observed.fields_text = tostring(ai_fields_text)
                data.summary.ai_decision_snapshot_hits = (data.summary.ai_decision_snapshot_hits or 0) + 1
                data.summary.last_ai_decision_snapshot_action = tostring(snapshot_action)
                data.summary.last_ai_decision_snapshot_fields = tostring(ai_fields_text)
            end

            local ai_target_desc = util.describe_obj(ai_target)
            if ai_target ~= nil and ai_target_desc ~= "nil" then
                local ai_target_fields_text = build_typed_snapshot_text(
                    ai_target,
                    { "target", "position", "point", "gameobject", "character", "distance", "type" },
                    16
                )
                local ai_target_signature = table.concat({
                    tostring(snapshot_actor.current_job or snapshot_actor.raw_job),
                    tostring(snapshot_action),
                    tostring(ai_target_desc),
                    tostring(ai_target_fields_text),
                }, "|")
                local target_observed = data.observed_ai_target_snapshots[ai_target_signature]
                if target_observed == nil then
                    target_observed = {
                        job = snapshot_actor.current_job or snapshot_actor.raw_job,
                        action = tostring(snapshot_action),
                        target = tostring(ai_target_desc),
                        fields_text = tostring(ai_target_fields_text),
                        count = 0,
                    }
                    data.observed_ai_target_snapshots[ai_target_signature] = target_observed
                    log.session_marker(runtime, "skill", "ai_target_snapshot_first_seen", {
                        ai_target_snapshot_job = target_observed.job,
                        ai_target_snapshot_action = target_observed.action,
                        ai_target_snapshot = target_observed.target,
                        ai_target_snapshot_fields = target_observed.fields_text,
                    }, string.format(
                        "action=%s target=%s fields=%s",
                        tostring(target_observed.action),
                        tostring(target_observed.target),
                        tostring(target_observed.fields_text)
                    ))
                end

                target_observed.count = (target_observed.count or 0) + 1
                data.summary.ai_target_snapshot_hits = (data.summary.ai_target_snapshot_hits or 0) + 1
                data.summary.last_ai_target_snapshot_action = tostring(snapshot_action)
                data.summary.last_ai_target_snapshot_fields = tostring(ai_target_fields_text)
            end

            local decision_pack_desc = util.describe_obj(decision_pack)
            if decision_pack ~= nil and decision_pack_desc ~= "nil" then
                local pack_path = util.safe_direct_method(decision_pack, "get_Path")
                    or util.safe_method(decision_pack, "get_Path()")
                local pack_fields_text = build_typed_snapshot_text(
                    decision_pack,
                    { "path", "action", "pack", "inter", "target", "request", "move" },
                    16
                )
                if pack_path ~= nil then
                    pack_fields_text = string.format("path=%s; %s", tostring(pack_path), tostring(pack_fields_text))
                    data.summary.main_pawn_last_decision_snapshot_pack_path = tostring(pack_path)
                end
                local pack_signature = table.concat({
                    tostring(snapshot_actor.current_job or snapshot_actor.raw_job),
                    tostring(snapshot_action),
                    tostring(decision_pack_desc),
                    tostring(pack_fields_text),
                }, "|")
                local pack_observed = data.observed_decision_actionpack_snapshots[pack_signature]
                if pack_observed == nil then
                    pack_observed = {
                        job = snapshot_actor.current_job or snapshot_actor.raw_job,
                        action = tostring(snapshot_action),
                        pack = tostring(decision_pack_desc),
                        fields_text = tostring(pack_fields_text),
                        count = 0,
                    }
                    data.observed_decision_actionpack_snapshots[pack_signature] = pack_observed
                    log.session_marker(runtime, "skill", "decision_actionpack_snapshot_first_seen", {
                        decision_actionpack_snapshot_job = pack_observed.job,
                        decision_actionpack_snapshot_action = pack_observed.action,
                        decision_actionpack_snapshot = pack_observed.pack,
                        decision_actionpack_snapshot_fields = pack_observed.fields_text,
                    }, string.format(
                        "action=%s pack=%s fields=%s",
                        tostring(pack_observed.action),
                        tostring(pack_observed.pack),
                        tostring(pack_observed.fields_text)
                    ))
                end

                pack_observed.count = (pack_observed.count or 0) + 1
                data.summary.decision_actionpack_snapshot_hits = (data.summary.decision_actionpack_snapshot_hits or 0) + 1
                data.summary.last_decision_actionpack_snapshot_action = tostring(snapshot_action)
                data.summary.last_decision_actionpack_snapshot_fields = tostring(pack_fields_text)
            end

            local producer_parts = {}

            local function add_producer_part(label, obj, patterns)
                local desc = util.describe_obj(obj)
                if obj == nil or desc == "nil" then
                    return
                end

                local typed_text = build_typed_snapshot_text(obj, patterns, 16)
                table.insert(producer_parts, string.format("%s=%s {%s}", tostring(label), tostring(desc), tostring(typed_text)))
            end

            add_producer_part("decision_module", snapshot_context.decision_module, {
                "decision", "module", "execute", "target", "pack", "action", "combat", "move",
            })
            add_producer_part("decision_executor", snapshot_context.decision_executor, {
                "decision", "executor", "execute", "target", "pack", "action", "combat", "move",
            })
            add_producer_part("execute_actinter", snapshot_context.execute_actinter, {
                "decision", "execute", "pack", "target", "action", "inter", "request", "combat", "move",
            })

            local decision_module = snapshot_context.decision_module
            if decision_module ~= nil then
                add_producer_part("decision_evaluator",
                    util.safe_direct_method(decision_module, "get_DecisionEvaluator")
                        or util.safe_method(decision_module, "get_DecisionEvaluator()"),
                    { "decision", "evaluate", "target", "pack", "action", "combat", "move" }
                )
                add_producer_part("decision_pack_handler",
                    util.safe_direct_method(decision_module, "get_DecisionPackHandler")
                        or util.safe_method(decision_module, "get_DecisionPackHandler()"),
                    { "decision", "pack", "target", "action", "combat", "move", "request" }
                )
                add_producer_part("setup_target_section",
                    util.safe_direct_method(decision_module, "get_SetupTargetSection")
                        or util.safe_method(decision_module, "get_SetupTargetSection()"),
                    { "target", "setup", "section", "decision", "combat", "move" }
                )
                add_producer_part("use_target_section",
                    util.safe_direct_method(decision_module, "get_UseTargetSection")
                        or util.safe_method(decision_module, "get_UseTargetSection()"),
                    { "target", "use", "section", "decision", "combat", "move" }
                )
                add_producer_part("valid_target_section",
                    util.safe_direct_method(decision_module, "get_ValidTargetSection")
                        or util.safe_method(decision_module, "get_ValidTargetSection()"),
                    { "target", "valid", "section", "decision", "combat", "move" }
                )

                local decision_pack_handler =
                    util.safe_direct_method(decision_module, "get_DecisionPackHandler")
                    or util.safe_method(decision_module, "get_DecisionPackHandler()")
                if decision_pack_handler ~= nil then
                    table.insert(producer_parts, string.format(
                        "active_decision_packs=%s",
                        build_collection_snapshot_text(
                            util.safe_direct_method(decision_pack_handler, "get_ActiveDecisionPacks")
                                or util.safe_method(decision_pack_handler, "get_ActiveDecisionPacks()"),
                            { "pack", "decision", "active", "target", "action" },
                            16
                        )
                    ))
                    table.insert(producer_parts, string.format(
                        "main_decision_list=%s",
                        build_collection_snapshot_text(
                            util.safe_direct_method(decision_pack_handler, "get_MainDecisionList")
                                or util.safe_method(decision_pack_handler, "get_MainDecisionList()"),
                            { "decision", "pack", "target", "action", "combat" },
                            16
                        )
                    ))
                    table.insert(producer_parts, string.format(
                        "pre_decision_list=%s",
                        build_collection_snapshot_text(
                            util.safe_direct_method(decision_pack_handler, "get_PreDecisionList")
                                or util.safe_method(decision_pack_handler, "get_PreDecisionList()"),
                            { "decision", "pack", "target", "action", "combat" },
                            16
                        )
                    ))
                    table.insert(producer_parts, string.format(
                        "post_decision_list=%s",
                        build_collection_snapshot_text(
                            util.safe_direct_method(decision_pack_handler, "get_PostDecisionList")
                                or util.safe_method(decision_pack_handler, "get_PostDecisionList()"),
                            { "decision", "pack", "target", "action", "combat" },
                            16
                        )
                    ))
                end
            end

            if #producer_parts > 0 then
                local producer_text = table.concat(producer_parts, "; ")
                local producer_signature = table.concat({
                    tostring(snapshot_actor.current_job or snapshot_actor.raw_job),
                    tostring(snapshot_action),
                    tostring(producer_text),
                }, "|")

                local producer_observed = data.observed_decision_producer_snapshots[producer_signature]
                if producer_observed == nil then
                    producer_observed = {
                        job = snapshot_actor.current_job or snapshot_actor.raw_job,
                        action = tostring(snapshot_action),
                        fields_text = tostring(producer_text),
                        count = 0,
                    }
                    data.observed_decision_producer_snapshots[producer_signature] = producer_observed
                    log.session_marker(runtime, "skill", "decision_producer_snapshot_first_seen", {
                        decision_producer_snapshot_job = producer_observed.job,
                        decision_producer_snapshot_action = producer_observed.action,
                        decision_producer_snapshot_fields = producer_observed.fields_text,
                    }, string.format(
                        "action=%s fields=%s",
                        tostring(producer_observed.action),
                        tostring(producer_observed.fields_text)
                    ))
                end

                producer_observed.count = (producer_observed.count or 0) + 1
                data.summary.decision_producer_snapshot_hits = (data.summary.decision_producer_snapshot_hits or 0) + 1
                data.summary.last_decision_producer_snapshot_action = tostring(snapshot_action)
                data.summary.last_decision_producer_snapshot_fields = tostring(producer_text)
            end
        end
    end

    local probe_actions = (config.action_research and config.action_research.decision_probe_actions) or { "Strafe", "NormalLocomotion" }
    local should_probe = target == "main_pawn" and job_equals(current_job, 7)
    if should_probe then
        local matched = false
        for _, probe_action in ipairs(probe_actions) do
            if tostring(action_name) == tostring(probe_action) then
                matched = true
                break
            end
        end

        if matched then
            local current_action_list = util.safe_field(action_manager, "CurrentActionList")
                or util.safe_field(action_manager, "_CurrentActionList")
            local current_actions = util.collection_to_lua(current_action_list, 2)
            local current_action_names = {}
            for index = 1, 2 do
                local item = current_actions[index]
                local name = item and (
                    util.safe_direct_method(item, "get_Name")
                    or util.safe_method(item, "get_Name()")
                    or util.safe_field(item, "Name")
                    or util.safe_field(item, "_Name")
                ) or nil
                current_action_names[index] = tostring(name or util.describe_obj(item))
            end

            local summary = data.summary or {}
            local decision_event = {
                request_action_target = target,
                request_action_target_reason = target_reason,
                request_action_job = current_job,
                request_action_name = tostring(action_name),
                request_action_priority = tostring(priority),
                request_action_full_node = actor and actor.full_node or "nil",
                request_action_upper_node = actor and actor.upper_node or "nil",
                request_action_manager_address = format_address(action_manager),
                main_pawn_decision_module = tostring(summary.main_pawn_decision_module or "nil"),
                main_pawn_decision_executor = tostring(summary.main_pawn_decision_executor or "nil"),
                main_pawn_executing_decision = tostring(summary.main_pawn_executing_decision or "nil"),
                main_pawn_executing_decision_target = tostring(summary.main_pawn_executing_decision_target or "nil"),
                main_pawn_current_execute_actinter_pack_path = tostring(summary.main_pawn_current_execute_actinter_pack_path or "nil"),
                main_pawn_current_execute_actinter_pack = tostring(summary.main_pawn_current_execute_actinter_pack or "nil"),
                current_action_0 = tostring(current_action_names[1] or "nil"),
                current_action_1 = tostring(current_action_names[2] or "nil"),
            }

            local signature = table.concat({
                tostring(decision_event.request_action_name),
                tostring(decision_event.request_action_full_node),
                tostring(decision_event.request_action_upper_node),
                tostring(decision_event.main_pawn_executing_decision),
                tostring(decision_event.main_pawn_executing_decision_target),
                tostring(decision_event.main_pawn_current_execute_actinter_pack_path),
                tostring(decision_event.current_action_0),
                tostring(decision_event.current_action_1),
            }, "|")

            local observed = data.observed_decision_probes[signature]
            if observed == nil then
                observed = {
                    action = tostring(decision_event.request_action_name),
                    nodes = string.format("%s|%s", tostring(decision_event.request_action_full_node), tostring(decision_event.request_action_upper_node)),
                    decision = tostring(decision_event.main_pawn_executing_decision),
                    decision_target = tostring(decision_event.main_pawn_executing_decision_target),
                    pack_path = tostring(decision_event.main_pawn_current_execute_actinter_pack_path),
                    current_actions = {
                        tostring(decision_event.current_action_0),
                        tostring(decision_event.current_action_1),
                    },
                    count = 0,
                }
                data.observed_decision_probes[signature] = observed
                log.session_marker(runtime, "skill", "decision_probe_first_seen", decision_event, string.format(
                    "action=%s nodes=%s|%s decision=%s target=%s pack=%s actions=%s,%s",
                    tostring(decision_event.request_action_name),
                    tostring(decision_event.request_action_full_node),
                    tostring(decision_event.request_action_upper_node),
                    tostring(decision_event.main_pawn_executing_decision),
                    tostring(decision_event.main_pawn_executing_decision_target),
                    tostring(decision_event.main_pawn_current_execute_actinter_pack_path),
                    tostring(decision_event.current_action_0),
                    tostring(decision_event.current_action_1)
                ))
            end

            observed.count = (observed.count or 0) + 1
            data.stats.decision_probe_hits = (data.stats.decision_probe_hits or 0) + 1
            data.summary.decision_probe_hits = (data.summary.decision_probe_hits or 0) + 1
            data.summary.last_decision_probe_action = tostring(action_name)
            data.summary.last_decision_probe_priority = tostring(priority)
            data.summary.last_decision_probe_nodes = string.format("%s|%s", tostring(event.request_action_full_node), tostring(event.request_action_upper_node))
            data.summary.last_decision_probe_decision = tostring(summary.main_pawn_executing_decision or "nil")
            data.summary.last_decision_probe_decision_target = tostring(summary.main_pawn_executing_decision_target or "nil")
            data.summary.last_decision_probe_pack_path = tostring(summary.main_pawn_current_execute_actinter_pack_path or "nil")
            data.summary.last_decision_probe_actions = string.format("%s,%s", tostring(current_action_names[1] or "nil"), tostring(current_action_names[2] or "nil"))
            snapshot_decision_fields("main_pawn", actor, action_name)
        end
    end

    local player_should_snapshot = target == "player" and is_hybrid_job_action_request(current_job, action_name)
    if player_should_snapshot then
        local player_context = collect_actor_runtime_context(actor, runtime.player, nil)
        local current_action_list = util.safe_field(action_manager, "CurrentActionList")
            or util.safe_field(action_manager, "_CurrentActionList")
        local current_actions = util.collection_to_lua(current_action_list, 2)
        local current_action_names = {}
        for index = 1, 2 do
            local item = current_actions[index]
            local name = item and (
                util.safe_direct_method(item, "get_Name")
                or util.safe_method(item, "get_Name()")
                or util.safe_field(item, "Name")
                or util.safe_field(item, "_Name")
            ) or nil
            current_action_names[index] = tostring(name or util.describe_obj(item))
        end

        local player_probe_signature = table.concat({
            "player",
            tostring(current_job),
            tostring(action_name),
            tostring(player_context.full_node),
            tostring(player_context.upper_node),
            tostring(util.describe_obj(player_context.executing_decision)),
            tostring(util.describe_obj(player_context.executing_decision_target)),
            tostring(player_context.execute_actinter_pack_path),
            tostring(current_action_names[1] or "nil"),
            tostring(current_action_names[2] or "nil"),
        }, "|")

        if data.observed_decision_probes[player_probe_signature] == nil then
            data.observed_decision_probes[player_probe_signature] = {
                target = "player",
                action = tostring(action_name),
                nodes = string.format("%s|%s", tostring(player_context.full_node), tostring(player_context.upper_node)),
                decision = tostring(util.describe_obj(player_context.executing_decision)),
                decision_target = tostring(util.describe_obj(player_context.executing_decision_target)),
                pack_path = tostring(player_context.execute_actinter_pack_path),
                current_actions = {
                    tostring(current_action_names[1] or "nil"),
                    tostring(current_action_names[2] or "nil"),
                },
                count = 0,
            }
            log.session_marker(runtime, "skill", "player_decision_probe_first_seen", {
                request_action_target = "player",
                request_action_target_reason = target_reason,
                request_action_job = current_job,
                request_action_name = tostring(action_name),
                request_action_priority = tostring(priority),
                request_action_full_node = tostring(player_context.full_node),
                request_action_upper_node = tostring(player_context.upper_node),
                request_action_manager_address = format_address(action_manager),
                player_executing_decision = tostring(util.describe_obj(player_context.executing_decision)),
                player_executing_decision_target = tostring(util.describe_obj(player_context.executing_decision_target)),
                player_current_execute_actinter_pack_path = tostring(player_context.execute_actinter_pack_path),
                current_action_0 = tostring(current_action_names[1] or "nil"),
                current_action_1 = tostring(current_action_names[2] or "nil"),
            }, string.format(
                "action=%s nodes=%s|%s decision=%s target=%s pack=%s actions=%s,%s",
                tostring(action_name),
                tostring(player_context.full_node),
                tostring(player_context.upper_node),
                tostring(util.describe_obj(player_context.executing_decision)),
                tostring(util.describe_obj(player_context.executing_decision_target)),
                tostring(player_context.execute_actinter_pack_path),
                tostring(current_action_names[1] or "nil"),
                tostring(current_action_names[2] or "nil")
            ))
        end
        snapshot_decision_fields("player", actor, action_name)
    end

    local pawn_baseline_should_snapshot =
        target == "main_pawn"
        and current_job ~= nil
        and not job_equals(current_job, 7)
        and is_job_specific_action_request(action_name)

    if pawn_baseline_should_snapshot then
        snapshot_decision_fields("main_pawn", actor, action_name)
        local baseline_context = collect_actor_runtime_context(
            actor,
            runtime.main_pawn_data and runtime.main_pawn_data.runtime_character or nil,
            runtime.main_pawn_data and runtime.main_pawn_data.pawn or nil
        )
        local producer_parts = {}

        local function add_baseline_producer_part(label, obj, patterns)
            local desc = util.describe_obj(obj)
            if obj == nil or desc == "nil" then
                return
            end

            local typed_text = build_typed_snapshot_text(obj, patterns, 16)
            table.insert(producer_parts, string.format("%s=%s {%s}", tostring(label), tostring(desc), tostring(typed_text)))
        end

        add_baseline_producer_part("decision_module", baseline_context.decision_module, {
            "decision", "module", "execute", "target", "pack", "action", "combat", "move",
        })
        add_baseline_producer_part("decision_executor", baseline_context.decision_executor, {
            "decision", "executor", "execute", "target", "pack", "action", "combat", "move",
        })

        local baseline_module = baseline_context.decision_module
        if baseline_module ~= nil then
            add_baseline_producer_part("decision_evaluator",
                util.safe_direct_method(baseline_module, "get_DecisionEvaluator")
                    or util.safe_method(baseline_module, "get_DecisionEvaluator()"),
                { "decision", "evaluate", "target", "pack", "action", "combat", "move" }
            )
            local baseline_pack_handler =
                util.safe_direct_method(baseline_module, "get_DecisionPackHandler")
                or util.safe_method(baseline_module, "get_DecisionPackHandler()")
            add_baseline_producer_part("decision_pack_handler",
                baseline_pack_handler,
                { "decision", "pack", "target", "action", "combat", "move", "request" }
            )
            add_baseline_producer_part("setup_target_section",
                util.safe_direct_method(baseline_module, "get_SetupTargetSection")
                    or util.safe_method(baseline_module, "get_SetupTargetSection()"),
                { "target", "setup", "section", "decision", "combat", "move" }
            )
            add_baseline_producer_part("use_target_section",
                util.safe_direct_method(baseline_module, "get_UseTargetSection")
                    or util.safe_method(baseline_module, "get_UseTargetSection()"),
                { "target", "use", "section", "decision", "combat", "move" }
            )
            add_baseline_producer_part("valid_target_section",
                util.safe_direct_method(baseline_module, "get_ValidTargetSection")
                    or util.safe_method(baseline_module, "get_ValidTargetSection()"),
                { "target", "valid", "section", "decision", "combat", "move" }
            )

            if baseline_pack_handler ~= nil then
                table.insert(producer_parts, string.format(
                    "active_decision_packs=%s",
                    build_collection_snapshot_text(
                        util.safe_direct_method(baseline_pack_handler, "get_ActiveDecisionPacks")
                            or util.safe_method(baseline_pack_handler, "get_ActiveDecisionPacks()"),
                        { "pack", "decision", "active", "target", "action" },
                        16
                    )
                ))
                table.insert(producer_parts, string.format(
                    "main_decision_list=%s",
                    build_collection_snapshot_text(
                        util.safe_direct_method(baseline_pack_handler, "get_MainDecisionList")
                            or util.safe_method(baseline_pack_handler, "get_MainDecisionList()"),
                        { "decision", "pack", "target", "action", "combat" },
                        16
                    )
                ))
                table.insert(producer_parts, string.format(
                    "pre_decision_list=%s",
                    build_collection_snapshot_text(
                        util.safe_direct_method(baseline_pack_handler, "get_PreDecisionList")
                            or util.safe_method(baseline_pack_handler, "get_PreDecisionList()"),
                        { "decision", "pack", "target", "action", "combat" },
                        16
                    )
                ))
                table.insert(producer_parts, string.format(
                    "post_decision_list=%s",
                    build_collection_snapshot_text(
                        util.safe_direct_method(baseline_pack_handler, "get_PostDecisionList")
                            or util.safe_method(baseline_pack_handler, "get_PostDecisionList()"),
                        { "decision", "pack", "target", "action", "combat" },
                        16
                    )
                ))
            end
        end

        if #producer_parts > 0 then
            local producer_text = table.concat(producer_parts, "; ")
            local producer_signature = table.concat({
                tostring(current_job),
                tostring(action_name),
                tostring(producer_text),
            }, "|")
            local producer_observed = data.observed_decision_producer_snapshots[producer_signature]
            if producer_observed == nil then
                producer_observed = {
                    job = current_job,
                    action = tostring(action_name),
                    fields_text = tostring(producer_text),
                    count = 0,
                }
                data.observed_decision_producer_snapshots[producer_signature] = producer_observed
                log.session_marker(runtime, "skill", "decision_producer_snapshot_first_seen", {
                    decision_producer_snapshot_job = producer_observed.job,
                    decision_producer_snapshot_action = producer_observed.action,
                    decision_producer_snapshot_fields = producer_observed.fields_text,
                }, string.format(
                    "action=%s fields=%s",
                    tostring(producer_observed.action),
                    tostring(producer_observed.fields_text)
                ))
            end
            producer_observed.count = (producer_observed.count or 0) + 1
            data.summary.decision_producer_snapshot_hits = (data.summary.decision_producer_snapshot_hits or 0) + 1
            data.summary.last_decision_producer_snapshot_action = tostring(action_name)
            data.summary.last_decision_producer_snapshot_fields = tostring(producer_text)
        end
    end
end

local function append_actinter_event(runtime, controller, pack_data, ai_target, method_name)
    local data = get_data(runtime)
    local target, actor, target_reason = resolve_actinter_target(runtime, controller, ai_target)
    if target == "unknown" and config.action_research
        and config.action_research.observe_unknown_actinter ~= true then
        return
    end
    local current_job = actor and (actor.current_job or actor.raw_job) or nil
    local pack_path = pack_data and (util.safe_direct_method(pack_data, "get_Path") or util.safe_method(pack_data, "get_Path()")) or nil
    local pack_snapshot = nil

    if target == "main_pawn" and job_equals(current_job, 7) and pack_data ~= nil then
        pack_snapshot = util.get_fields_snapshot(pack_data, config.action_research.pack_snapshot_field_limit or 12)
    end

    local event = {
        player_job = data.summary and data.summary.player_job or nil,
        player_human_address = data.summary and data.summary.player_human_address or "nil",
        player_runtime_character_address = data.summary and data.summary.player_runtime_character_address or "nil",
        player_current_job_action_ctrl_source = data.summary and data.summary.player_current_job_action_ctrl_source or "unresolved",
        player_common_action_selector_source = data.summary and data.summary.player_common_action_selector_source or "unresolved",
        player_full_node = data.summary and data.summary.player_full_node or "nil",
        player_upper_node = data.summary and data.summary.player_upper_node or "nil",
        main_pawn_job = data.summary and data.summary.main_pawn_job or nil,
        main_pawn_human_address = data.summary and data.summary.main_pawn_human_address or "nil",
        main_pawn_runtime_character_address = data.summary and data.summary.main_pawn_runtime_character_address or "nil",
        main_pawn_pawn_address = data.summary and data.summary.main_pawn_pawn_address or "nil",
        main_pawn_current_job_action_ctrl_source = data.summary and data.summary.main_pawn_current_job_action_ctrl_source or "unresolved",
        main_pawn_common_action_selector_source = data.summary and data.summary.main_pawn_common_action_selector_source or "unresolved",
        main_pawn_full_node = data.summary and data.summary.main_pawn_full_node or "nil",
        main_pawn_upper_node = data.summary and data.summary.main_pawn_upper_node or "nil",
        current_job_gap = data.summary and data.summary.current_job_gap or "unresolved",
        actinter_target = target,
        actinter_target_reason = target_reason,
        actinter_method = method_name,
        actinter_controller = util.describe_obj(controller),
        actinter_controller_address = format_address(controller),
        actinter_pack = util.describe_obj(pack_data),
        actinter_pack_address = format_address(pack_data),
        actinter_pack_path = pack_path ~= nil and tostring(pack_path) or "nil",
        actinter_pack_snapshot = pack_snapshot or {},
        actinter_ai_target = util.describe_obj(ai_target),
        actinter_ai_target_address = format_address(ai_target),
        actinter_job = current_job,
        actinter_full_node = actor and actor.full_node or "nil",
        actinter_upper_node = actor and actor.upper_node or "nil",
    }

    if target == "unknown" and should_suppress_unknown_actinter(event.actinter_pack_path) then
        return
    end

    if target == "player" then
        data.summary.player_actinter_requests = (data.summary.player_actinter_requests or 0) + 1
    elseif target == "main_pawn" then
        data.summary.main_pawn_actinter_requests = (data.summary.main_pawn_actinter_requests or 0) + 1
    end

    data.summary.last_actinter_target = target
    data.summary.last_actinter_pack = util.describe_obj(pack_data)
    data.summary.last_actinter_pack_path = event.actinter_pack_path
    data.summary.last_actinter_controller = util.describe_obj(controller)
    data.summary.last_actinter_controller_address = format_address(controller)
    data.stats.actinter_requests = (data.stats.actinter_requests or 0) + 1
    if target == "main_pawn" then
        data.summary[target .. "_last_observed_actinter_pack"] = util.describe_obj(pack_data)
        data.summary[target .. "_last_observed_actinter_pack_path"] = event.actinter_pack_path
    end

    if target == "main_pawn" and job_equals(current_job, 7) and event.actinter_pack_address ~= "nil" then
        local key = tostring(event.actinter_pack_address)
        local observed = data.observed_packs[key]
        if observed == nil then
            observed = {
                address = key,
                path = event.actinter_pack_path,
                type_name = util.get_type_full_name(pack_data) or "unknown",
                target_reason = target_reason,
                fields = pack_snapshot or {},
                count = 0,
                methods = {},
            }
            data.observed_packs[key] = observed
            log.session_marker(runtime, "skill", "actinter_pack_first_seen", {
                actinter_target = target,
                actinter_target_reason = target_reason,
                actinter_pack_address = observed.address,
                actinter_pack_path = observed.path,
                actinter_pack_type = observed.type_name,
                actinter_pack_fields = observed.fields,
            }, string.format(
                "target=%s via=%s pack=%s path=%s type=%s",
                tostring(target),
                tostring(target_reason),
                tostring(observed.address),
                tostring(observed.path),
                tostring(observed.type_name)
            ))
        end
        observed.count = (observed.count or 0) + 1
        observed.path = observed.path == "nil" and event.actinter_pack_path or observed.path
        observed.methods[method_name or "unknown"] = true
        local observed_count = 0
        for _ in pairs(data.observed_packs) do
            observed_count = observed_count + 1
        end
        data.summary.observed_pack_count = observed_count
    end

    if target == "main_pawn" then
        track_main_pawn_actinter(
            data,
            target,
            target_reason,
            event.actinter_pack_path,
            event.actinter_full_node,
            event.actinter_upper_node
        )
    end

    table.insert(data.recent_events, 1, event)
    while #data.recent_events > (config.action_research.trace_history_limit or 24) do
        table.remove(data.recent_events)
    end

    log.session_marker(runtime, "skill", "actinter_request_observed", event, string.format(
        "target=%s via=%s job=%s nodes=%s|%s ctrl=%s ai_target=%s pack=%s gap=%s",
        tostring(target),
        tostring(target_reason),
        tostring(current_job),
        tostring(event.actinter_full_node),
        tostring(event.actinter_upper_node),
        tostring(event.actinter_controller_address),
        tostring(event.actinter_ai_target_address),
        tostring(event.actinter_pack_path),
        tostring(event.current_job_gap)
    ))
end

local function append_event(runtime, event)
    local data = get_data(runtime)
    table.insert(data.recent_events, 1, event)
    while #data.recent_events > (config.action_research.trace_history_limit or 24) do
        table.remove(data.recent_events)
    end
    data.stats.summary_changes = (data.stats.summary_changes or 0) + 1

    log.session_marker(runtime, "skill", "action_execution_state_summary_changed", event, string.format(
        "player_job=%s ctrl=%s nodes=%s|%s pawn_job=%s ctrl=%s nodes=%s|%s gap=%s",
        tostring(event.player_job),
        tostring(event.player_current_job_action_ctrl_source),
        tostring(event.player_full_node),
        tostring(event.player_upper_node),
        tostring(event.main_pawn_job),
        tostring(event.main_pawn_current_job_action_ctrl_source),
        tostring(event.main_pawn_full_node),
        tostring(event.main_pawn_upper_node),
        tostring(event.current_job_gap)
    ))
end

local function build_summary(runtime)
    local existing_summary = (get_data(runtime).summary or {})
    local progression = runtime.progression_state_data
    local main_pawn_data = runtime.main_pawn_data
    local player_summary = summarize_actor(progression and progression.player or nil, runtime.player, nil)
    local pawn_summary = summarize_actor(
        progression and progression.main_pawn or nil,
        main_pawn_data and main_pawn_data.runtime_character or nil,
        main_pawn_data and main_pawn_data.pawn or nil
    )

    local summary = {
        player_job = player_summary.job,
        player_human_address = player_summary.human_address,
        player_runtime_character_address = player_summary.runtime_character_address,
        player_action_manager = player_summary.action_manager,
        player_action_manager_address = player_summary.action_manager_address,
        player_action_manager_source = player_summary.action_manager_source,
        player_current_job_action_ctrl = player_summary.current_job_action_ctrl,
        player_current_job_action_ctrl_source = player_summary.current_job_action_ctrl_source,
        player_common_action_selector = player_summary.common_action_selector,
        player_common_action_selector_source = player_summary.common_action_selector_source,
        player_ai_blackboard_controller = player_summary.ai_blackboard_controller,
        player_ai_blackboard_address = player_summary.ai_blackboard_address,
        player_ai_blackboard_source = player_summary.ai_blackboard_source,
        player_ai_decision_maker = player_summary.ai_decision_maker,
        player_decision_module = player_summary.decision_module,
        player_decision_executor = player_summary.decision_executor,
        player_executing_decision = player_summary.executing_decision,
        player_executing_decision_target = player_summary.executing_decision_target,
        player_current_execute_actinter = player_summary.current_execute_actinter,
        player_current_execute_actinter_pack = player_summary.current_execute_actinter_pack,
        player_current_execute_actinter_pack_path = player_summary.current_execute_actinter_pack_path,
        player_actinter_requests = existing_summary.player_actinter_requests or 0,
        player_request_action_calls = existing_summary.player_request_action_calls or 0,
        player_last_requested_action = existing_summary.player_last_requested_action or "nil",
        player_last_requested_priority = existing_summary.player_last_requested_priority or "nil",
        player_observed_request_action_count = existing_summary.player_observed_request_action_count or 0,
        player_full_node = player_summary.full_node,
        player_upper_node = player_summary.upper_node,
        player_in_job_action_node = player_summary.in_job_action_node,
        main_pawn_job = pawn_summary.job,
        main_pawn_human_address = pawn_summary.human_address,
        main_pawn_runtime_character_address = pawn_summary.runtime_character_address,
        main_pawn_pawn_address = pawn_summary.pawn_address,
        main_pawn_action_manager = pawn_summary.action_manager,
        main_pawn_action_manager_address = pawn_summary.action_manager_address,
        main_pawn_action_manager_source = pawn_summary.action_manager_source,
        main_pawn_current_job_action_ctrl = pawn_summary.current_job_action_ctrl,
        main_pawn_current_job_action_ctrl_source = pawn_summary.current_job_action_ctrl_source,
        main_pawn_common_action_selector = pawn_summary.common_action_selector,
        main_pawn_common_action_selector_source = pawn_summary.common_action_selector_source,
        main_pawn_ai_blackboard_controller = pawn_summary.ai_blackboard_controller,
        main_pawn_ai_blackboard_address = pawn_summary.ai_blackboard_address,
        main_pawn_ai_blackboard_source = pawn_summary.ai_blackboard_source,
        main_pawn_ai_decision_maker = pawn_summary.ai_decision_maker,
        main_pawn_decision_module = pawn_summary.decision_module,
        main_pawn_decision_executor = pawn_summary.decision_executor,
        main_pawn_executing_decision = pawn_summary.executing_decision,
        main_pawn_executing_decision_target = pawn_summary.executing_decision_target,
        main_pawn_current_execute_actinter = pawn_summary.current_execute_actinter,
        main_pawn_current_execute_actinter_pack = pawn_summary.current_execute_actinter_pack,
        main_pawn_current_execute_actinter_pack_path = pawn_summary.current_execute_actinter_pack_path,
        main_pawn_actinter_requests = existing_summary.main_pawn_actinter_requests or 0,
        main_pawn_request_action_calls = existing_summary.main_pawn_request_action_calls or 0,
        main_pawn_last_requested_action = existing_summary.main_pawn_last_requested_action or "nil",
        main_pawn_last_requested_priority = existing_summary.main_pawn_last_requested_priority or "nil",
        main_pawn_observed_request_action_count = existing_summary.main_pawn_observed_request_action_count or 0,
        decision_probe_hits = existing_summary.decision_probe_hits or 0,
        decision_snapshot_hits = existing_summary.decision_snapshot_hits or 0,
        ai_decision_snapshot_hits = existing_summary.ai_decision_snapshot_hits or 0,
        ai_target_snapshot_hits = existing_summary.ai_target_snapshot_hits or 0,
        decision_actionpack_snapshot_hits = existing_summary.decision_actionpack_snapshot_hits or 0,
        decision_producer_snapshot_hits = existing_summary.decision_producer_snapshot_hits or 0,
        last_decision_probe_action = existing_summary.last_decision_probe_action or "nil",
        last_decision_probe_priority = existing_summary.last_decision_probe_priority or "nil",
        last_decision_probe_nodes = existing_summary.last_decision_probe_nodes or "nil|nil",
        last_decision_probe_decision = existing_summary.last_decision_probe_decision or "nil",
        last_decision_probe_decision_target = existing_summary.last_decision_probe_decision_target or "nil",
        last_decision_probe_pack_path = existing_summary.last_decision_probe_pack_path or "nil",
        last_decision_probe_actions = existing_summary.last_decision_probe_actions or "nil,nil",
        last_decision_snapshot_target = existing_summary.last_decision_snapshot_target or "none",
        last_decision_snapshot_action = existing_summary.last_decision_snapshot_action or "nil",
        last_decision_snapshot_fields = existing_summary.last_decision_snapshot_fields or "",
        main_pawn_last_decision_snapshot_pack_path = existing_summary.main_pawn_last_decision_snapshot_pack_path or "nil",
        last_ai_decision_snapshot_action = existing_summary.last_ai_decision_snapshot_action or "nil",
        last_ai_decision_snapshot_fields = existing_summary.last_ai_decision_snapshot_fields or "",
        last_ai_target_snapshot_action = existing_summary.last_ai_target_snapshot_action or "nil",
        last_ai_target_snapshot_fields = existing_summary.last_ai_target_snapshot_fields or "",
        last_decision_actionpack_snapshot_action = existing_summary.last_decision_actionpack_snapshot_action or "nil",
        last_decision_actionpack_snapshot_fields = existing_summary.last_decision_actionpack_snapshot_fields or "",
        last_decision_producer_snapshot_action = existing_summary.last_decision_producer_snapshot_action or "nil",
        last_decision_producer_snapshot_fields = existing_summary.last_decision_producer_snapshot_fields or "",
        main_pawn_full_node = pawn_summary.full_node,
        main_pawn_upper_node = pawn_summary.upper_node,
        main_pawn_in_job_action_node = pawn_summary.in_job_action_node,
        last_actinter_target = existing_summary.last_actinter_target or "none",
        last_actinter_pack = existing_summary.last_actinter_pack or "nil",
        last_actinter_pack_path = existing_summary.last_actinter_pack_path or "nil",
        last_actinter_controller = existing_summary.last_actinter_controller or "nil",
        last_actinter_controller_address = existing_summary.last_actinter_controller_address or "nil",
        observed_pack_count = existing_summary.observed_pack_count or 0,
        current_job_gap = compute_gap(player_summary, pawn_summary),
    }
    return summary
end

function action_research.install_hooks(runtime)
    local data = get_data(runtime)
    if data.hooks_installed or not config.action_research.enabled then
        return
    end

    local ai_extensions = util.safe_sdk_typedef("app.AIBlackBoardExtensions")
    if ai_extensions ~= nil then
        local method = nil
        local ok, resolved = pcall(function()
            return ai_extensions:get_method("setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)")
        end)
        if ok and resolved ~= nil then
            method = resolved
        end

        if method ~= nil then
            sdk.hook(
                method,
                function(args)
                    local storage = thread.get_hook_storage()
                    storage.controller = sdk.to_managed_object(args[2])
                    storage.pack_data = sdk.to_managed_object(args[3])
                    storage.ai_target = sdk.to_managed_object(args[4])
                    storage.method_name = "setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)"
                end,
                function(retval)
                    local storage = thread.get_hook_storage()
                    append_actinter_event(runtime, storage.controller, storage.pack_data, storage.ai_target, storage.method_name)
                    return retval
                end
            )
            table.insert(data.installed_methods, "app.AIBlackBoardExtensions::setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)")
        else
            table.insert(data.registration_errors, "app.AIBlackBoardExtensions method missing: setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)")
        end
    else
        table.insert(data.registration_errors, "app.AIBlackBoardExtensions typedef missing")
    end

    local ai_blackboard_controller_td = util.safe_sdk_typedef("app.AIBlackBoardController")
    if ai_blackboard_controller_td ~= nil then
        local reqmain_method = nil
        local ok, resolved = pcall(function()
            return ai_blackboard_controller_td:get_method("set_ReqMainActInterPackData(app.ActInterPackData)")
        end)
        if ok and resolved ~= nil then
            reqmain_method = resolved
        end

        if reqmain_method ~= nil then
            sdk.hook(
                reqmain_method,
                function(args)
                    local storage = thread.get_hook_storage()
                    storage.controller = sdk.to_managed_object(args[2])
                    storage.pack_data = sdk.to_managed_object(args[3])
                    storage.ai_target = nil
                    storage.method_name = "set_ReqMainActInterPackData(app.ActInterPackData)"
                end,
                function(retval)
                    local storage = thread.get_hook_storage()
                    data.stats.reqmain_pack_requests = (data.stats.reqmain_pack_requests or 0) + 1
                    append_actinter_event(runtime, storage.controller, storage.pack_data, storage.ai_target, storage.method_name)
                    return retval
                end
            )
            table.insert(data.installed_methods, "app.AIBlackBoardController::set_ReqMainActInterPackData(app.ActInterPackData)")
        else
            table.insert(data.registration_errors, "app.AIBlackBoardController method missing: set_ReqMainActInterPackData(app.ActInterPackData)")
        end
    else
        table.insert(data.registration_errors, "app.AIBlackBoardController typedef missing")
    end

    local action_manager_td = util.safe_sdk_typedef("app.ActionManager")
    if action_manager_td ~= nil then
        local request_action_method = nil
        local ok, resolved = pcall(function()
            return action_manager_td:get_method("requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)")
        end)
        if ok and resolved ~= nil then
            request_action_method = resolved
        end

        if request_action_method ~= nil then
            sdk.hook(
                request_action_method,
                function(args)
                    local storage = thread.get_hook_storage()
                    storage.action_manager = sdk.to_managed_object(args[2])
                    storage.priority = sdk.to_int64(args[3]) & 0xffffffff
                    local action_arg = sdk.to_managed_object(args[4])
                    storage.action_name = action_arg and action_arg:ToString() or tostring(args[4])
                end,
                function(retval)
                    local storage = thread.get_hook_storage()
                    append_request_action_event(runtime, storage.action_manager, storage.priority, storage.action_name)
                    return retval
                end
            )
            table.insert(data.installed_methods, "app.ActionManager::requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)")
        else
            table.insert(data.registration_errors, "app.ActionManager method missing: requestActionCore(app.ActionManager.Priority, System.String, System.UInt32)")
        end
    else
        table.insert(data.registration_errors, "app.ActionManager typedef missing")
    end

    install_decision_runtime_hook(
        runtime,
        data,
        "app.DecisionEvaluationCore",
        "decision_evaluator",
        "choose_decision",
        {},
        { "chooseDecision" },
        "retval"
    )

    install_decision_runtime_hook(
        runtime,
        data,
        "app.DecisionExecutor",
        "decision_executor",
        "execute_decision",
        {},
        { "executeDecision" },
        "arg"
    )

    install_decision_runtime_hook(
        runtime,
        data,
        "app.DecisionExecutor",
        "decision_executor",
        "start_decision",
        {},
        { "startDecision" },
        "arg"
    )

    install_decision_runtime_hook(
        runtime,
        data,
        "app.DecisionExecutor",
        "decision_executor",
        "set_executing_decision",
        {},
        { "set_ExecutingDecision" },
        "arg"
    )

    install_decision_runtime_hook(
        runtime,
        data,
        "app.DecisionExecutor",
        "decision_executor",
        "late_update_decision",
        {},
        { "lateUpdateDecision" },
        nil
    )

    install_decision_runtime_hook(
        runtime,
        data,
        "app.DecisionExecutor",
        "decision_executor",
        "end_decision",
        {},
        { "endDecision" },
        nil
    )

    data.hooks_installed = true
    data.summary = build_summary(runtime)
end

function action_research.update(runtime)
    local data = get_data(runtime)
    data.summary = build_summary(runtime)
    data.decision_actor_index_generation = (tonumber(data.decision_actor_index_generation) or 0) + 1
    data.decision_actor_index_cache = nil
    data.decision_actor_index_cache_generation = -1
    local observed_count = 0
    for _ in pairs(data.observed_packs or {}) do
        observed_count = observed_count + 1
    end
    data.summary.observed_pack_count = observed_count

    local summary = data.summary or {}
    local signature = table.concat({
        tostring(summary.player_job),
        tostring(summary.player_human_address),
        tostring(summary.player_runtime_character_address),
        tostring(summary.player_action_manager_address),
        tostring(summary.player_current_job_action_ctrl),
        tostring(summary.player_common_action_selector),
        tostring(summary.player_ai_blackboard_controller),
        tostring(summary.player_ai_blackboard_address),
        tostring(summary.player_ai_decision_maker),
        tostring(summary.player_decision_module),
        tostring(summary.player_decision_executor),
        tostring(summary.player_executing_decision),
        tostring(summary.player_executing_decision_target),
        tostring(summary.player_current_execute_actinter),
        tostring(summary.player_current_execute_actinter_pack_path),
        tostring(summary.player_last_requested_action),
        tostring(summary.player_last_requested_priority),
        tostring(summary.player_observed_request_action_count),
        tostring(summary.player_full_node),
        tostring(summary.player_upper_node),
        tostring(summary.main_pawn_job),
        tostring(summary.main_pawn_human_address),
        tostring(summary.main_pawn_runtime_character_address),
        tostring(summary.main_pawn_pawn_address),
        tostring(summary.main_pawn_action_manager_address),
        tostring(summary.main_pawn_current_job_action_ctrl),
        tostring(summary.main_pawn_common_action_selector),
        tostring(summary.main_pawn_ai_blackboard_controller),
        tostring(summary.main_pawn_ai_blackboard_address),
        tostring(summary.main_pawn_ai_decision_maker),
        tostring(summary.main_pawn_decision_module),
        tostring(summary.main_pawn_decision_executor),
        tostring(summary.main_pawn_executing_decision),
        tostring(summary.main_pawn_executing_decision_target),
        tostring(summary.main_pawn_current_execute_actinter),
        tostring(summary.main_pawn_current_execute_actinter_pack_path),
        tostring(summary.main_pawn_last_requested_action),
        tostring(summary.main_pawn_last_requested_priority),
        tostring(summary.main_pawn_observed_request_action_count),
        tostring(summary.main_pawn_full_node),
        tostring(summary.main_pawn_upper_node),
        tostring(summary.observed_pack_count),
        tostring(summary.current_job_gap),
    }, "|")

    if data.last_summary_signature ~= signature then
        data.last_summary_signature = signature
        append_event(runtime, summary)
    end

    return data
end

return action_research
